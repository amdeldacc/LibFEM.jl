# Lesson 5: The 2D Truss Element — Coordinate Transformation

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 5
> Mapped to LibFEM.jl — `src/truss.jl` (lines 97–224), `src/utils.jl`, `src/assembly.jl`

**Prerequisites**: Lesson 3 (Linear Bar), Lesson 2 (Assembly concepts, DOF mapping)

---

## 5.1 The Leap: 1D Bar → 2D Truss

Up to now, every element was 1D — nodes could only move along a single axis. The **2D truss** is a linear bar rotated to lie in a 2D plane. Each node now has **2 degrees of freedom** (UX, UY) instead of 1.

```
Before (1D bar):   node1 ──────── node2      1 DOF/node → 2×2 matrix
                     u₁            u₂

After (2D truss):       ▲ node2 (UX₂, UY₂)
                       ╱
                      ╱ θ = 30°
                     ╱
          node1 ────╴                      2 DOF/node → 4×4 matrix
       (UX₁, UY₁)
```

The **critical insight**: the truss element still only carries **axial force** along its own axis. It has **zero stiffness perpendicular** to its axis. But we need to describe that axial stiffness in global X-Y coordinates.

This requires **coordinate transformation** — the central concept of this lesson and the foundation for all subsequent rotated elements.

---

## 5.2 The Transformation

### Local vs global

| System | Axis | DOFs | Stiffness |
|--------|------|------|-----------|
| Local (along bar) | x' | u'₁, u'₂ | `(EA/L) × [1 -1; -1 1]` |
| Global (world) | X, Y | UX₁, UY₁, UX₂, UY₂ | 4×4 transformed matrix |

### Direction cosines

```
Δx = x₂ − x₁      Δy = y₂ − y₁      L = √(Δx² + Δy²)

C = cos θ = Δx / L     (direction cosine with global X)
S = sin θ = Δy / L     (direction cosine with global Y)
```

In LibFEM.jl (`utils.jl:7-10`):

```julia
@inline function _direction_cosines(theta_deg::Real)
    x = deg2rad(theta_deg)
    return (cos(x), sin(x))
end
```

**Degrees in, radians out** — consistent with the project convention.

### The transformation matrix [T]

A 2×4 matrix projecting global DOFs onto the local bar axis:

```
| u'₁ |   =   | C  S  0  0 | × | UX₁ |
| u'₂ |       | 0  0  C  S |   | UY₁ |
                                | UX₂ |
                                | UY₂ |
```

### Transformed stiffness

```
[k_global] = [T]ᵀ × [k_local] × [T]
```

Carrying out the multiplication:

```
                  ┌                             ┐
                  │  C²     CS    -C²    -CS    │
k_global = EA/L × │  CS     S²    -CS    -S²    │
                  │ -C²    -CS     C²     CS    │
                  │ -CS    -S²     CS     S²    │
                  └                             ┘
```

---

## 5.3 In LibFEM.jl — Side by Side with MATLAB

### Stiffness (`truss.jl:138-144`)

```julia
function d2_truss_elementstiffness(E::Real, A::Real, L::Real, theta::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    w = [C * C C * S; C * S S * S]
    return E * A / L * [w -w; -w w]
end
```

Kattan's MATLAB (`PlaneTrussElementStiffness.m`):

```matlab
function y = PlaneTrussElementStiffness(E, A, L, theta)
    x = theta * pi/180;
    C = cos(x);  S = sin(x);
    y = E*A/L*[C*C C*S -C*C -C*S; C*S S*S -C*S -S*S;
              -C*C -C*S C*C C*S; -C*S -S*S C*S S*S];
end
```

Julia uses a **block-matrix pattern** `[w -w; -w w]` where `w = [C² CS; CS S²]` — elegant expression of the repeating 2×2 sub-blocks. MATLAB writes all 16 entries explicitly.

### Force (`truss.jl:161-166`)

```julia
function d2_truss_elementforces(E::Real, A::Real, L::Real, theta::Real, u::AbstractVector)
    (C, S) = _direction_cosines(theta)
    return E * A / L * _truss_force_component(C, S, u)
end
```

Where `_truss_force_component` (`utils.jl:59-61`) computes the axial projection:

```julia
@inline function _truss_force_component(Cx::Real, Cy::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] + Cx * u[3] + Cy * u[4]
end
```

This is `[-C, -S, C, S] · [UX₁, UY₁, UX₂, UY₂]` — the relative axial displacement in local coordinates.

Kattan's MATLAB (`PlaneTrussElementForce.m`):

```matlab
function y = PlaneTrussElementForce(E, A, L, theta, u)
    x = theta * pi/180;
    C = cos(x);  S = sin(x);
    y = E*A/L*[-C -S C S] * u;
end
```

### Stress (`truss.jl:201-205`)

```julia
function d2_truss_elementstress(E::Real, L::Real, theta::Real, u::AbstractVector)
    (C, S) = _direction_cosines(theta)
    return E / L * _truss_force_component(C, S, u)
end
```

σ = E × ε = **E/L × [−C, −S, C, S] · u**

### Strain (`truss.jl:181-185`) — LibFEM.jl extension, not in Kattan

```julia
function d2_truss_elementstrain(L::Real, theta::Real, u::AbstractVector)
    (C, S) = _direction_cosines(theta)
    return _truss_force_component(C, S, u) / L
end
```

ε = ΔL / L = **1/L × [−C, −S, C, S] · u**

### Length (`truss.jl:115-119`)

```julia
function d2_truss_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    L = sqrt((x2 - x1)^2 + (y2 - y1)^2)
    validate_positive(L, "L")
    return L
end
```

Lets you compute θ from coordinates:

```julia
C = (x2 - x1) / L   # cos θ from coordinates
S = (y2 - y1) / L   # sin θ from coordinates
θ = rad2deg(atan(S, C))
```

### Assembly (`truss.jl:222-224`) — delegates to generic helper with ndofs=2

```julia
function d2_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end
```

With `ndofs=2`, node i maps to slots `[2i−1, 2i]`:

```julia
# _assemble! with ndofs=2 (assembly.jl:21-30)
K[2i-1:2i, 2i-1:2i] += k[1:2, 1:2]   # K(2i-1,2i-1), (2i-1,2i), (2i,2i-1), (2i,2i)
K[2i-1:2i, 2j-1:2j] += k[1:2, 3:4]   # cross terms i→j
K[2j-1:2j, 2i-1:2i] += k[3:4, 1:2]   # cross terms j→i
K[2j-1:2j, 2j-1:2j] += k[3:4, 3:4]   # node j block
```

Kattan's MATLAB (`PlaneTrussAssemble.m`) writes all 16 assignments explicitly — same result, more lines.

---

## 5.4 MATLAB ↔ Julia Mapping

| Operation | Kattan MATLAB | LibFEM.jl Julia | Source |
|-----------|--------------|-----------------|--------|
| Length | `PlaneTrussElementLength(x1,y1,x2,y2)` | `d2_truss_elementlength(x1,y1,x2,y2)` | `truss.jl:115-119` |
| Stiffness | `PlaneTrussElementStiffness(E,A,L,θ)` | `d2_truss_elementstiffness(E,A,L,θ)` | `truss.jl:138-144` |
| Force | `PlaneTrussElementForce(E,A,L,θ,u)` | `d2_truss_elementforces(E,A,L,θ,u)` | `truss.jl:161-166` |
| Stress | `PlaneTrussElementStress(E,L,θ,u)` | `d2_truss_elementstress(E,L,θ,u)` | `truss.jl:201-205` |
| Strain | *(not in Kattan)* | `d2_truss_elementstrain(L,θ,u)` | `truss.jl:181-185` |
| Assembly | `PlaneTrussAssemble(K,k,i,j)` | `d2_truss_assemble(K,k,i,j)` | `truss.jl:222-224` |

---

## 5.5 Special Cases

### Horizontal truss (θ = 0°) — C=1, S=0

```
k = EA/L ×
    ┌              ┐
    │  1   0  -1  0 │
    │  0   0   0  0 │
    │ -1   0   1  0 │
    │  0   0   0  0 │
    └              ┘
```

**Zero stiffness in Y** — only resists horizontal displacement. Verified in tests (`runtests.jl:558-560`).

### Vertical truss (θ = 90°) — C=0, S=1

```
k = EA/L ×
    ┌              ┐
    │  0   0   0  0 │
    │  0   1   0 -1 │
    │  0   0   0  0 │
    │  0  -1   0  1 │
    └              ┘
```

**Zero stiffness in X** — only resists vertical displacement.

### Spring-truss 2D identity

```julia
# Verified in runtests.jl:976
@test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)
```

### Matrix rank

The 4×4 matrix is **rank 1** — only one non-zero eigenvalue (= EA/L). The other 3 eigenvalues are zero (rigid body: 2 translations + 1 rotation):

```julia
julia> k = d2_truss_elementstiffness(1, 1, 1, 30)
julia> eigvals(k)
4-element Vector{Float64}:
  0.0
  0.0
  0.0
  1.0
```

---

## 5.6 Reading the Transformed Matrix

```
k = EA/L ×
    ┌──────────────────────────────────────┐
    │  C²          CS        -C²     -CS   │  UX₁
    │  CS          S²        -CS     -S²   │  UY₁
    │ -C²         -CS         C²      CS   │  UX₂
    │ -CS         -S²         CS      S²   │  UY₂
    └──────────────────────────────────────┘
        UX₁         UY₁       UX₂     UY₂
```

| Term | Meaning |
|------|---------|
| **C² = cos²θ** | Stiffness along global X from axial stiffness |
| **S² = sin²θ** | Stiffness along global Y from axial stiffness |
| **CS = cosθ·sinθ** | **X-Y coupling** — horizontal force produces vertical displacement |
| − | Off-diagonal blocks negated (same sign pattern as 1D bar) |

---

## 5.7 Full Worked Example — Two-Bar Truss

**Problem (Kattan Example 5.2)**: E = 200 GPa, A = 0.001 m². Bar 1: horizontal (θ=0°, L=4 m) nodes 1→2. Bar 2: at 30° (L=3 m) nodes 2→3. Load P = 25 kN at node 3.

```
              node3
              ▲
         bar2 │
        30°   │
              │
node1 ─────── node2 ────▶ P = 25 kN
      bar1 (θ=0°)
```

### Steps 2-3: Element stiffness and assembly

```julia
using LibFEM
E, A = 200e9, 0.001

k1 = d2_truss_elementstiffness(E, A, 4.0, 0.0)
k2 = d2_truss_elementstiffness(E, A, 3.0, 30.0)

K = zeros(6, 6)
K = d2_truss_assemble(K, k1, 1, 2)
K = d2_truss_assemble(K, k2, 2, 3)
```

### Step 4: BCs

| Node | Known | Unknown |
|------|-------|---------|
| 1 | UX₁=0, UY₁=0 | Fx₁, Fy₁ |
| 2 | Fx₂=0, Fy₂=0 | UX₂, UY₂ |
| 3 | Fx₃=25e3, **UY₃=0** | UX₃, Fy₃ |

Node 3 has a roller — vertical displacement constrained.

### Step 5: Solve

```julia
free_dofs = [3, 4, 5]  # UX₂, UY₂, UX₃
K_red = K[free_dofs, free_dofs]
F_red = [0.0, 0.0, 25e3]
u_red = K_red \ F_red
```

### Step 6: Post-process

```julia
U = zeros(6)
U[free_dofs] = u_red

f1 = d2_truss_elementforces(E, A, 4.0, 0.0, U[[1,2,3,4]])
f2 = d2_truss_elementforces(E, A, 3.0, 30.0, U[[3,4,5,6]])

σ1 = d2_truss_elementstress(E, 4.0, 0.0, U[[1,2,3,4]])
σ2 = d2_truss_elementstress(E, 3.0, 30.0, U[[3,4,5,6]])

# Reactions
F = K * U
@test F[1] ≈ -25e3   # horizontal reaction at node 1
```

The horizontal bar carries more load — it's stiffer in the load direction.

---

## 5.8 DOF Slot Mapping

```
Node n → UX at (2n−1), UY at (2n)
```

| Node | UX slot | UY slot |
|------|---------|---------|
| 1 | 1 | 2 |
| 2 | 3 | 4 |
| 3 | 5 | 6 |

When extracting element DOFs:

```julia
# Element between nodes i=2 and j=3
u_elem = U[[2*2-1, 2*2, 2*3-1, 2*3]]  # = U[3], U[4], U[5], U[6]
```

---

## 5.9 Test Coverage

The `d2_truss` block (`runtests.jl:530-628`) covers:
- Stiffness shape, C²/CS/S² values at θ=30°, horizontal case zeros
- Scalar force return, stress = E/L × projection, strain = projection/L
- Assembly: 4 blocks at correct positions, unused entries zero
- L=0, L<0, A=0, A<0 all throw for all functions
- E=0 → zero matrix, E<0 → negation (not validated)
- `@test_translational_invariants` — symmetry + PSD + **zero row-sum** (all three apply)

---

## Summary

| Concept | Takeaway |
|---------|----------|
| DOF/node | **2** — UX and UY |
| Matrix | **4×4** (2 nodes × 2 DOF) |
| Local stiffness | Still `(EA/L) × [1 -1; -1 1]` |
| Transformation | `k_global = Tᵀ × k_local × T`, C=cosθ, S=sinθ |
| Block pattern | `[w -w; -w w]` where `w = [C² CS; CS S²]` |
| Force/stress | **Scalar** (axial only), returned via `_truss_force_component` |
| Perpendicular | **Zero stiffness** — truss carries only axial load |
| Assembly slot | Node n → `[2n−1, 2n]` |
| Rank | 1 (only EA/L eigenvalue is non-zero) |

### Full API

```julia
d2_truss_elementlength(x1, y1, x2, y2)                        # → L
d2_truss_elementstiffness(E, A, L, theta)                     # → 4×4
d2_truss_elementforces(E, A, L, theta, u)                     # → scalar
d2_truss_elementstress(E, L, theta, u)                        # → scalar
d2_truss_elementstrain(L, theta, u)                           # → scalar
d2_truss_assemble(K, k, i, j)                                 # → updated K
```

**Coming up in Lesson 6**: The 3D Truss (Space Truss, Ch6) — 3 DOF/node, 3 direction cosines, 6×6 matrix.
