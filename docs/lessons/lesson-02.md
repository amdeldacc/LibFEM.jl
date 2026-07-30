# Lesson 2: The Spring Element — First Stiffness Matrix & Assembly

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 2
> Mapped to LibFEM.jl — `src/spring.jl`, `src/assembly.jl`

**Prerequisite**: Lesson 1 (the 6-step method, DOF convention)

---

## 2.1 The Spring Element

The spring is the **simplest finite element** — a 1D spring with:

- **2 nodes** (one at each end)
- **1 DOF per node** (axial displacement u)
- **Stiffness k** (force per unit displacement, e.g., N/m)

```
  k
────┳━━━━━━━━━━━┳────
  node 1       node 2
    u₁           u₂
    F₁           F₂
```

### Hooke's Law

For a spring: **F = k · Δu** = k·(u₂ − u₁)

- Positive F = tension (pulling nodes apart)
- Negative F = compression (pushing nodes together)

### Force balance at each node:

```
At node 1:   F₁ = −k·(u₂ − u₁) =  k·u₁ − k·u₂
At node 2:   F₂ =  k·(u₂ − u₁) = −k·u₁ + k·u₂
```

In matrix form:

```
| F₁ |   =   |  k  -k | × | u₁ |
| F₂ |       | -k   k |   | u₂ |
```

The **2×2 matrix is the element stiffness matrix [k]**.

---

## 2.2 The 3-Function Pattern

Every element type in Kattan (and LibFEM.jl) implements three core operations:

| Function | Purpose | Returns |
|----------|---------|---------|
| `*_elementstiffness(...)` | Build the element stiffness matrix | Matrix |
| `*_assemble(K, k, i, j, ...)` | Insert element matrix into global K | Updated K |
| `*_elementforce(...)` or `*_elementstress(...)` | Compute forces/stresses from displacements | Vector or scalar |

### In LibFEM.jl — 1D Spring

**Stiffness** (`src/spring.jl` lines 16-19):

```julia
function d1_spring_elementstiffness(k::Real)
    validate_positive(k, "k")
    return [k -k; -k k]
end
```

That's it. **3 lines**. The `validate_positive(k, "k")` prevents negative stiffness (physically impossible).

In MATLAB (Kattan Ch2), it's the same:

```matlab
function y = SpringElementStiffness(k)
y = [k -k; -k k];
```

**Element force** (`src/spring.jl` lines 33-35):

```julia
function d1_spring_elementforce(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u       # f = k · u
end
```

Just matrix-vector multiplication — Hooke's law in action.

---

## 2.3 The Stiffness Matrix Properties

The spring stiffness matrix has three essential properties that **all** structural element matrices share:

```julia
k = [100  -100
     -100   100]
```

1. **Symmetric**: kᵢⱼ = kⱼᵢ (the structure obeys Maxwell-Betti reciprocal theorem)
2. **Positive semi-definite**: all eigenvalues ≥ 0 (one eigenvalue = 0, corresponding to rigid body motion)
3. **Row sum = 0**: each row sums to zero (unconstrained element can move rigidly without force)

> **Check**: Row 1: 100 + (-100) = 0. Row 2: -100 + 100 = 0. ✓

---

## 2.4 Assembly — The Direct Stiffness Method

**Assembly** = placing each element's stiffness into the right "pigeonhole slots" of the global matrix.

### For 1D elements (1 DOF/node):

```
Element between nodes i and j:

K(i,i) += k(1,1)    ← upper-left corner
K(i,j) += k(1,2)    ← upper-right
K(j,i) += k(2,1)    ← lower-left
K(j,j) += k(2,2)    ← lower-right
```

### LibFEM.jl's generic assembly helper (`src/assembly.jl` lines 21-30):

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
    @views begin
        K[(i-1)*ndofs+1:i*ndofs, (i-1)*ndofs+1:i*ndofs] += k[1:ndofs,     1:ndofs]
        K[(i-1)*ndofs+1:i*ndofs, (j-1)*ndofs+1:j*ndofs] += k[1:ndofs,     ndofs+1:2*ndofs]
        K[(j-1)*ndofs+1:j*ndofs, (i-1)*ndofs+1:i*ndofs] += k[ndofs+1:2*ndofs, 1:ndofs]
        K[(j-1)*ndofs+1:j*ndofs, (j-1)*ndofs+1:j*ndofs] += k[ndofs+1:2*ndofs, ndofs+1:2*ndofs]
    end
    return K
end
```

For **ndofs=1** (1D spring), this simplifies to exactly the 4-line pattern above.

The element-specific `d1_spring_assemble` is just a one-liner wrapper:

```julia
function d1_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)   # ndofs=1 for 1D spring
end
```

### Assembly visualized

```
Element 1 (k=100, nodes 1-2):    Element 2 (k=200, nodes 2-3):
     ┌          ┐                    ┌          ┐
     │  100 -100│  ← node 1         │          │
     │ -100  100│  ← node 2         │  200 -200│  ← node 2
     └          ┘                    │ -200  200│  ← node 3
       node1 node2                    └          ┘
                                       node2 node3

After both assembled into K (3×3):
     ┌                 ┐
     │  100 -100    0  │  ← node 1
K =  │ -100  300 -200  │  ← node 2  (100+200 = 300 at the shared DOF!)
     │    0 -200  200  │  ← node 3
     └                 ┘
```

> **Key insight**: The shared node 2 gets stiffness contributions from **both** elements. That's the superposition principle — the total stiffness at a node is the sum of stiffnesses of all elements connected to it.

---

## 2.5 Full Worked Example — Two Springs in Series

**Problem (Kattan Example 2.1)**: Two springs with k₁ = 100 N/m, k₂ = 200 N/m. Node 1 fixed to wall, node 3 pulled with P = 15 N. Find displacements and element forces.

### Step 1: Discretize

```
  ┌────┳━━━━(1)━━━━┳━━━━(2)━━━━┳────┐ P=15 N
 wall  node1       node2       node3
```

3 nodes, 2 elements.

### Step 2: Element stiffness matrices

```julia
k1 = d1_spring_elementstiffness(100)   # [100  -100; -100  100]
k2 = d1_spring_elementstiffness(200)   # [200  -200; -200  200]
```

### Step 3: Assemble global K

```julia
K = zeros(3, 3)
K = d1_spring_assemble(K, k1, 1, 2)   # element 1 between nodes 1-2
K = d1_spring_assemble(K, k2, 2, 3)   # element 2 between nodes 2-3
```

```
K = [100  -100   0
    -100   300  -200
       0  -200   200]
```

### Step 4: Apply boundary conditions

| Node | Known | Unknown |
|------|-------|---------|
| 1 | u₁ = 0 (fixed) | F₁ (reaction) |
| 2 | F₂ = 0 (no external load) | u₂ |
| 3 | F₃ = 15 N (applied) | u₃ |

### Step 5: Partition and solve

Remove row/col 1 (fixed DOF), solve the reduced 2×2 system:

```julia
K_red = K[2:3, 2:3]    # [300  -200; -200  200]
F_red = [0.0, 15.0]
u_red = K_red \ F_red
```

Result: **u₂ = 0.15 m**, **u₃ = 0.225 m**

Full displacement vector: **u = [0, 0.15, 0.225]ᵀ**

### Step 6: Post-process

```julia
# Element forces
f1 = d1_spring_elementforce(k1, u[1:2])   # [-15, 15] N
f2 = d1_spring_elementforce(k2, u[2:3])   # [-15, 15] N
```

Both springs carry 15 N (tension). Check: force flows from the applied load at node 3 through spring 2 into spring 1, then into the wall.

```julia
# Reaction at wall (node 1)
F1 = K[1, :]' * u        # = 100·0 + (-100)·0.15 + 0·0.225 = -15 N
```

Reaction = **-15 N** (equal and opposite to applied load — Newton's 3rd law ✓)

---

## 2.6 Verification Checklist

After assembling, always verify:

- [ ] **Symmetry**: K[i,j] == K[j,i] for all i,j
- [ ] **Positive diagonals**: K[i,i] > 0 for all i
- [ ] **Row sum = 0 for unconstrained**: each row of an unconstrained structure sums to zero

---

## 2.7 Running it in Julia

```julia
$ julia --project=.
julia> using LibFEM

julia> k1 = d1_spring_elementstiffness(100)
2×2 Matrix{Float64}:
  100  -100
 -100   100

julia> k2 = d1_spring_elementstiffness(200);

julia> K = zeros(3,3);
julia> K = d1_spring_assemble(K, k1, 1, 2);
julia> K = d1_spring_assemble(K, k2, 2, 3);

julia> u = [0.0, K[2:2,2:2] \ [10.0]; 0.0]  # Quick solve for F₂=10N
```

---

## Summary

| Concept | Takeaway |
|---------|----------|
| Spring stiffness | `[k -k; -k k]` — symmetric, rows sum to zero |
| Element count | 2 nodes × 1 DOF/node = **2×2** matrix |
| Assembly | Add element k at node indices i,j into global K |
| N nodes, 1 DOF/node | Global K is **N×N** |
| Shared node | Gets stiffness from ALL connected elements (sum) |
| 3-function pattern | `stiffness` → `assemble` → `force` for every element type |

**Coming up in Lesson 3**: The Linear Bar — same 2×2 pattern but with material properties (E, A, L) replacing the abstract spring stiffness k.
