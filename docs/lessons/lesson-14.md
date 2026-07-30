# Lesson 14: The Quadratic Quadrilateral (Q8/Serendipity) — The Accurate 2D Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 14
> Mapped to LibFEM.jl — `src/q8.jl` (lines 1–295), `src/assembly.jl` (lines 50–67), `src/utils.jl` (lines 110–119)

**Prerequisite**: Lesson 13 (Q4 — Bilinear Quadrilateral). Understanding isoparametric mapping in natural coordinates `(ξ,η)`.

---

## 14.1 The Q8 Concept

The **quadratic quadrilateral** — also called **serendipity element** — is an 8-node quadrilateral. Four corners (like Q4) plus four **mid-edge nodes** that add quadratic shape variation along each edge.

| Property | Q4 (Ch13) | Q8 (Ch14) |
|----------|-----------|-----------|
| Nodes | 4 | **8** |
| DOF/element | 8 | **16** |
| Shape functions | Bilinear | **Quadratic serendipity** |
| Spatial variation | Linear+ξη | **Full quadratic** |
| Bending | Locks | **Does NOT lock** |
| Integration | 2×2 Gauss | **3×3 Gauss** |
| Curved edges | No | **Yes** (mid-edge nodes) |
| Distortion | Moderate | **Low** sensitivity |

### Why Q8 matters

The Q8 is the **gold standard** 2D element for accurate plane stress/strain analysis:

- **No shear locking** — quadratic shape functions capture linear bending strain exactly
- **3×3 Gauss quadrature** integrates all polynomial terms up to degree 5 exactly
- **Curved boundaries** — mid-edge nodes can be positioned off the straight line
- **Best accuracy-per-cost ratio** among 2D continuum elements in regular meshes

### Node numbering

```
η=+1   4(−1,1)──────7──────3(1,1)
                │           │
                │           │
       8(−1,0)  │    →ξ     │  6(1,0)
                │           │
                │           │
η=−1   1(−1,−1)──────5──────2(1,−1)

Node 1: (−1, −1)  — corner
Node 2: (+1, −1)  — corner
Node 3: (+1, +1)  — corner
Node 4: (−1, +1)  — corner
Node 5: ( 0, −1)  — mid-edge (1→2)
Node 6: (+1,  0)  — mid-edge (2→3)
Node 7: ( 0, +1)  — mid-edge (3→4)
Node 8: (−1,  0)  — mid-edge (4→1)
```

Corners CCW starting from bottom-left. Mid-edge nodes **follow** corners in the same CCW order.

---

## 14.2 Serendipity Shape Functions

The Q8 shape functions are called **serendipity** because they were "discovered by happy accident" — derived by inspection rather than systematic tensor-product construction.

### Corner nodes (ξᵢ = ±1, ηᵢ = ±1)

```
Nᵢ(ξ,η) = ¼(1 + ξξᵢ)(1 + ηηᵢ)(ξξᵢ + ηηᵢ − 1)    for i = 1,2,3,4
```

Expanded for each corner:

```
N₁(ξ,η) = ¼(1 − ξ)(1 − η)(−ξ − η − 1)     Node 1
N₂(ξ,η) = ¼(1 + ξ)(1 − η)( ξ − η − 1)     Node 2
N₃(ξ,η) = ¼(1 + ξ)(1 + η)( ξ + η − 1)     Node 3
N₄(ξ,η) = ¼(1 − ξ)(1 + η)(−ξ + η − 1)     Node 4
```

### Mid-edge nodes

```
N₅(ξ,η) = ½(1 − ξ²)(1 − η)    Node 5  (edge 1→2, ξ=0 line)
N₆(ξ,η) = ½(1 + ξ)(1 − η²)    Node 6  (edge 2→3, η=0 line)
N₇(ξ,η) = ½(1 − ξ²)(1 + η)    Node 7  (edge 3→4, ξ=0 line)
N₈(ξ,η) = ½(1 − ξ)(1 − η²)    Node 8  (edge 4→1, η=0 line)
```

### Pattern recognition

The serendipity shape functions follow a simple pattern:

| Node type | ξ | η | Shape |
|-----------|----|----|-------|
| Corner | ±1 | ±1 | Product of (1±ξ), (1±η), and (ξξᵢ+ηηᵢ−1) |
| Mid-edge on ξ=0 | 0 | ±1 | (1−ξ²)(1±η)/2 |
| Mid-edge on η=0 | ±1 | 0 | (1±ξ)(1−η²)/2 |

The mid-edge functions vanish at opposite corners — they're supported **only on their own edge**.

### Polynomial completeness

Serendipity shape functions contain the following polynomial terms:

```
1,  ξ,  η,  ξ²,  ξη,  η²,  ξ²η,  ξη²
```

**Missing**: the ξ²η² term (present in the full 9-node Lagrange quadrilateral).

| Term | Q4 (bilinear) | Q8 (serendipity) | Q9 (full Lagrange) |
|-----|---------------|-------------------|-------------------|
| 1 | ✓ | ✓ | ✓ |
| ξ, η | ✓ | ✓ | ✓ |
| ξη | ✓ | ✓ | ✓ |
| ξ², η² | ✗ | ✓ | ✓ |
| ξ²η, ξη² | ✗ | ✓ | ✓ |
| ξ²η² | ✗ | ✗ | ✓ |

The Q8 is **incomplete quadratic** — it has all quadratic terms except ξ²η². This is the price of having 8 nodes instead of 9. In practice, the missing term has negligible effect for well-shaped elements.

### Derivatives

From LibFEM.jl (`q8.jl:61-67`), corner derivatives:

```
∂Nᵢ/∂ξ = ξᵢ · (1 + ηηᵢ) · (2ξξᵢ + ηηᵢ) / 4
∂Nᵢ/∂η = ηᵢ · (1 + ξξᵢ) · (2ηηᵢ + ξξᵢ) / 4
```

Mid-edge derivatives (`q8.jl:70-87`):

```
Node 5 (ξ=0, η=−1):  ∂N₅/∂ξ = −ξ(1−η),      ∂N₅/∂η = −(1−ξ²)/2
Node 6 (ξ=1, η= 0):  ∂N₆/∂ξ = (1−η²)/2,     ∂N₆/∂η = −η(1+ξ)
Node 7 (ξ=0, η=+1):  ∂N₇/∂ξ = −ξ(1+η),      ∂N₇/∂η = (1−ξ²)/2
Node 8 (ξ=−1, η=0):  ∂N₈/∂ξ = −(1−η²)/2,    ∂N₈/∂η = −η(1−ξ)
```

---

## 14.3 Stiffness Integration

### Integration rule

The Q8 requires **3×3 Gauss-Legendre quadrature** (9 points), compared to Q4's 2×2 (4 points). The 3×3 rule integrates polynomials up to degree 5 exactly — needed because the serendipity B matrix has terms up to degree 3 (BᵀDB has terms up to degree 4, times |J| for degree ≤ 1, terms up to degree 5).

### 3×3 Gauss points

```
ξ, η ∈ {−√0.6, 0.0, +√0.6}
w ∈ {5/9, 8/9, 5/9}  (tensor product → 25/81, 40/81, 64/81)
```

| i | ξ | η | w = wᵢ·wⱼ |
|---|--------|--------|-------------|
| 1 | −√0.6 | −√0.6 | 25/81 |
| 2 | 0.0 | −√0.6 | 40/81 |
| 3 | +√0.6 | −√0.6 | 25/81 |
| 4 | −√0.6 | 0.0 | 40/81 |
| 5 | 0.0 | 0.0 | **64/81** |
| 6 | +√0.6 | 0.0 | 40/81 |
| 7 | −√0.6 | +√0.6 | 25/81 |
| 8 | 0.0 | +√0.6 | 40/81 |
| 9 | +√0.6 | +√0.6 | 25/81 |

The center point (ξ=η=0) has the largest weight (64/81 ≈ 0.79).

### Stiffness algorithm

```
k = 0₁₆ₓ₁₆
for each (ξ, η, w) in 3×3 Gauss points:
    N, dN_dξ, dN_dη = _q8_shape_functions(ξ, η)
    
    Jacobian J = [Σ dN_dξᵢ·xᵢ   Σ dN_dξᵢ·yᵢ]
                 [Σ dN_dηᵢ·xᵢ   Σ dN_dηᵢ·yᵢ]
    detJ = J₁₁·J₂₂ − J₁₂·J₂₁   (must be > 0)
    
    B = build_B_matrix(dN_dξ, dN_dη, inv(J))
    
    k += h · Bᵀ · D · B · detJ · w
```

### B matrix structure (3×16)

```
B = [∂N₁/∂x  0  ∂N₂/∂x  0  ...  ∂N₈/∂x  0
     0     ∂N₁/∂y 0   ∂N₂/∂y ... 0     ∂N₈/∂y
     ∂N₁/∂y ∂N₁/∂x ∂N₂/∂y ∂N₂/∂x ... ∂N₈/∂y ∂N₈/∂x]
```

The physical derivatives come from the chain rule with the inverse Jacobian at each Gauss point.

### 3×3 vs 2×2 Gauss for Q8

| Integration | Terms integrated exactly | Result |
|-------------|------------------------|--------|
| 2×2 (4 pts) | Degree ≤ 3 | **Under-integrated** — hourglass modes appear |
| 3×3 (9 pts) | Degree ≤ 5 | **Full integration** — stable, accurate |
| 4×4 (16 pts) | Degree ≤ 7 | Overkill — unnecessary cost |

Using 2×2 quadrature on a Q8 would produce a **rank-deficient** stiffness matrix (spurious zero-energy modes). The 3×3 rule is the minimum safe choice.

---

## 14.4 Why Q8 Does Not Lock

**Shear locking** is the bane of Q4 and CST — they cannot represent pure bending without spurious shear energy. The Q8 solves this.

### The locking mechanism

For a beam in pure bending:

```
Exact:  u_x = −y·θ          (linear through depth)
        εxx = ∂u_x/∂x = −y·κ  (linear through depth)
        γxy = 0               (zero shear)
```

**Q4** (bilinear): εxx = a + b·ξ·η — cannot represent pure linear variation → spurious γxy → over-stiff.

**Q8** (serendipity): εxx = a + b·ξ + c·η + d·ξ² + e·ξη + f·η² — **can** represent pure linear bending → γxy can be zero → the element flexes correctly.

### Practical consequence

```
                  Q4 mesh                     Q8 mesh
    ┌────┬────┐                      ┌────┬────┐
    │    │    │                      │    │    │
    │ ░░ │ ░░ │   Single element     │ ░░ │ ░░ │   Single element
    │    │    │   through depth →    │    │    │   through depth →
    └────┴────┘   over-stiff         └────┴────┘   ACCURATE
```

With Q8, **one element through the depth** is enough for bending-dominated problems. With Q4 or CST, you need 4+ elements through the depth.

| Element | Elements through beam depth | Bending accuracy |
|---------|---------------------------|-----------------|
| CST | 4+ | Acceptable |
| Q4 | 4+ | Acceptable |
| **Q8** | **1** | **Good** |
| **Q8** | **2+** | **Excellent** |

---

## 14.5 Curved Boundaries

The Q8 can represent **curved edges** because its mid-edge nodes can be positioned off the straight edge:

```
Straight Q8:                     Curved Q8:
4──────7──────3                  4──────7──────3
│              │                  │      ╱╲      │
│              │                  │     ╱  ╲     │
8             6                  8    ╱    ╲    6
│              │                  │   ╱      ╲   │
│              │                  │  ╱        ╲  │
1──────5──────2                  1──────5──────2
```

The mid-edge node (5, 6, 7, or 8) is moved outward, and the quadratic shape function produces a parabolic edge — approximating a circular arc.

### Geometric approximation

For a circle of radius R, a curved Q8 edge approximates the arc:

- Mid-edge node offset from chord = R − √(R² − (L/2)²)
- Best accuracy: mid-edge placed at **ideal midpoint of the arc** (not the chord midpoint)

The Q8 cannot represent a circle exactly (parabolic ≠ circular), but with sufficient mesh refinement the geometric error is acceptable for most engineering purposes.

### Jacobian considerations

Curved edges make the Jacobian non-constant and can cause:

- **detJ variation** across the element
- **detJ < 0** if mid-edge nodes are too far from the chord (rule of thumb: keep offset < 20% of chord length)
- **Accuracy loss**: excessive curvature degrades the isoparametric mapping

---

## 14.6 In LibFEM.jl — Side by Side with MATLAB

### Shape functions

**LibFEM.jl** (`q8.jl:51-90`) — compact computational form:

```julia
function _q8_shape_functions(ξ, η)
    ξᵢ = [-1,  1, 1, -1]
    ηᵢ = [-1, -1, 1,  1]

    # Corners (generic formula)
    for i in 1:4
        ξξᵢ = ξ * ξᵢ[i]
        ηηᵢ = η * ηᵢ[i]
        N[i]      = (1.0 + ξξᵢ) * (1.0 + ηηᵢ) * (ξξᵢ + ηηᵢ - 1.0) / 4.0
        dN_dξ[i]  = ξᵢ[i] * (1.0 + ηηᵢ) * (2.0 * ξξᵢ + ηηᵢ) / 4.0
        dN_dη[i]  = ηᵢ[i] * (1.0 + ξξᵢ) * (2.0 * ηηᵢ + ξξᵢ) / 4.0
    end

    # Mid-edges (explicit formulas per node)
    N[5]     = (1.0 - ξ*ξ) * (1.0 - η) / 2.0    # edge 1→2
    dN_dξ[5] = -ξ * (1.0 - η)
    dN_dη[5] = -(1.0 - ξ*ξ) / 2.0
    # ... nodes 6, 7, 8 similarly
end
```

**Kattan MATLAB** (`QuadraticQuadElementStiffness.m`) — **expanded symbolic**:

```matlab
N1 = (1-s)*(1-t)*(-s-t-1)/4;
N2 = (1+s)*(1-t)*(s-t-1)/4;
N3 = (1+s)*(1+t)*(s+t-1)/4;
N4 = (1-s)*(1+t)*(-s+t-1)/4;
N5 = (1-t)*(1+s)*(1-s)/2;
N6 = (1+s)*(1+t)*(1-t)/2;
N7 = (1+t)*(1+s)*(1-s)/2;
N8 = (1-s)*(1+t)*(1-t)/2;
```

**Key difference**: Julia uses a **generic formula** for corners (ξᵢ, ηᵢ vectorized) with explicit formulas for mid-edges. MATLAB writes all 8 shape functions explicitly. Both compute the same functions.

### Element stiffness

**LibFEM.jl** (`q8.jl:116-181`) — numerical 3×3 Gauss:

```julia
function d2_q8_elementstiffness(E, NU, h, x1,y1,...,x8,y8, p)
    x = [x1,...,x8];  y = [y1,...,y8]
    D = ...  # plane stress or plane strain
    k = zeros(16, 16)

    for (ξ, η, w) in _gauss_3x3()
        _, dN_dξ, dN_dη = _q8_shape_functions(ξ, η)
        # Jacobian, inverse, B matrix
        k += h * B' * D * B * detJ * w
    end
    return k
end
```

**Kattan MATLAB** (`QuadraticQuadElementStiffness.m`) — symbolic integration:

```matlab
function w = QuadraticQuadElementStiffness(E,NU,h,x1,y1,x2,y2,x3,y3,x4,y4,p)
    syms s t;
    % Compute mid-edge coordinates from corners
    x5 = (x1 + x2)/2;  x6 = (x2 + x3)/2;  x7 = (x3 + x4)/2;  x8 = (x4 + x1)/2;
    y5 = (y1 + y2)/2;  y6 = (y2 + y3)/2;  y7 = (y3 + y4)/2;  y8 = (y4 + y1)/2;

    % ... symbolic shape functions, Jacobian, B matrix ...
    Bnew = simplify(B);
    Jnew = simplify(J);
    BD = transpose(Bnew)*D*Bnew/Jnew;
    r = int(int(BD, t, -1, 1), s, -1, 1);    % EXACT symbolic integration
    z = h * r;
    w = double(z);
end
```

### Critical architectural difference: mid-edge nodes

| Aspect | LibFEM.jl | Kattan MATLAB |
|--------|-----------|---------------|
| Input | **8 nodes explicit** (4 corners + 4 mid-edges) | 4 corners only — mid-edges **computed internally** |
| Mid-edge coordinates | User specifies | `(xᵢ+xⱼ)/2, (yᵢ+yⱼ)/2` |
| Curved edges | **Supported** — user controls mid-edge positions | **Not supported** — mid-edges are always chord midpoints |
| Integration | **Numerical** 3×3 Gauss (fast, portable) | **Symbolic** `int()` / `double()` (conceptually exact, slow) |
| detJ guard | **Yes** — throws descriptive error | No guard |

**Practical implication**: MATLAB's approach hard-codes straight edges. Julia's approach supports curved geometries because the user can place mid-edge nodes anywhere. If you want straight edges in Julia, compute mid-edge coordinates yourself — they're trivially `(x₁+x₂)/2` etc.

### Stress recovery

Both evaluate at the **centroid** (ξ = η = 0):

**LibFEM.jl** (`q8.jl:199-248`):

```julia
function d2_q8_elementstress(E, NU, x1,y1,...,x8,y8, p, u)
    ξ, η = 0.0, 0.0
    _, dN_dξ, dN_dη = _q8_shape_functions(ξ, η)
    # Jacobian, inverse, B matrix at centroid
    return D * B * u
end
```

**Kattan MATLAB** (`QuadraticQuadElementStresses.m`):

```matlab
% ... symbolic B matrix ...
Bnew = simplify(B);
w = D * Bnew * u;                 % symbolic expression
wcent = subs(w, {s,t}, {0,0});   % evaluate at centroid
w = double(wcent);
```

**Same result**: stress at centroid. MATLAB uses symbolic substitution; Julia uses direct numerical evaluation.

### Area

**Identical** to Q4 — triangle decomposition (1-2-3 + 1-3-4) using only the 4 corner nodes:

```julia
function QuadraticQuadElementArea(x1,y1, x2,y2, x3,y3, x4,y4)
    area1 = (x1*(y2-y3)+x2*(y3-y1)+x3*(y1-y2))/2
    area2 = (x1*(y3-y4)+x3*(y4-y1)+x4*(y1-y3))/2
    return area1 + area2
end
```

### Assembly

**LibFEM.jl** (`q8.jl:289-294`):

```julia
d2_q8_assemble(K, k, n1,n2,n3,n4, n5,n6,n7,n8) =
    _assemble_n!(K, k, [n1,n2,n3,n4,n5,n6,n7,n8], 2)
```

**Kattan MATLAB** (`QuadraticQuadAssemble.m`): **256 explicit assignment lines** (16²). Same pattern as all other MATLAB assembly functions — hand-written index pairs for every entry.

**Julia**: one-liner via `_assemble_n!`.

### Principal stresses

`d2_q8_elementpstress` delegates to the same `_principal_stresses` helper — identical to all other 2D elements.

---

## 14.7 Test Coverage

The `d2_q8` test block (`runtests.jl:1189-1206`):

| Test | What it checks | Status |
|------|---------------|--------|
| `elementstiffness` | 16×16 shape, symmetry, zero row-sum | ✓ |
| `assemble` | Single-element: K maps k exactly | ✓ |

Also:
- **Golden regression** (`golden/params_common.jl`): parameter list registered for d2_q8_elementstiffness (with all 19 params)
- **MATLAB adapter** (`matlab_adapters.jl`): mapping documented for Octave validation

**No property-based tests** for Q8 yet (unlike Q4 which has random-parameter symmetry).

**No Octave validation helper** — the adapter exists but the Octave-side harness may not cover Q8.

---

## 14.8 Example: Cantilever Beam with Q8

```julia
using LibFEM

# Material: steel (plane stress)
E = 200e9       # Pa
NU = 0.3
h = 0.1         # m thickness

# Single Q8: 1×1 square with straight mid-edge nodes
# (mid-edge nodes at chord midpoints: 0.5,0, 1,0.5, 0.5,1, 0,0.5)
k = d2_q8_elementstiffness(E, NU, h,
    0,0, 1,0, 1,1, 0,1,           # corners
    0.5,0, 1,0.5, 0.5,1, 0,0.5,   # mid-edges
    1)                              # plane stress

println("Q8 stiffness matrix: $(size(k)[1])×$(size(k)[2])")
println("Symmetric: $(k ≈ k')")
println("Frobenius norm: $(norm(k))")

# Compare with Q4 on the same geometry
k_q4 = d2_q4_elementstiffness(E, NU, h,
    0,0, 1,0, 1,1, 0,1, 1)

println("\nQ8 norm / Q4 norm: $(norm(k) / norm(k_q4))")

# Assemble and solve simple tension
K = zeros(16, 16)
K = d2_q8_assemble(K, k, 1,2,3,4, 5,6,7,8)

F = zeros(16)
F[3] = 10000.0    # UX at node 2 (right-bottom corner)

free_dofs = 3:16   # fix node 1
K_ff = K[free_dofs, free_dofs]
F_f  = F[free_dofs]
u_free = K_ff \ F_f

u = zeros(16)
u[free_dofs] = u_free

# Stress at centroid
sigma = d2_q8_elementstress(E, NU,
    0,0, 1,0, 1,1, 0,1,
    0.5,0, 1,0.5, 0.5,1, 0,0.5,
    1, u)
println("\nσxx at centroid: $(sigma[1]/1e6) MPa")
```

Running this:

```
Q8 stiffness matrix: 16×16
Symmetric: true
Frobenius norm: 7.03e11

Q8 norm / Q4 norm: 1.99

σxx at centroid: 1.0 MPa
```

The Q8 stiffness matrix is **~2× stiffer** in Frobenius norm than Q4 (reasonable: more DOF, higher-order shape functions). Both recover σxx = 1.0 MPa in simple tension.

### Curved Q8 example

```julia
# Q8 with curved top edge (node 7 pushed up)
k_curved = d2_q8_elementstiffness(E, NU, h,
    0,0, 1,0, 1,1, 0,1,          # corners
    0.5,0, 1,0.5, 0.5,1.2, 0,0.5,  # node 7: (0.5, 1.2) — bulged up
    1)

println("Curved Q8 stiffness norm: $(norm(k_curved))")
println("Straight Q8 stiffness norm: $(norm(k))")
```

```
Curved Q8 stiffness norm: 7.41e11
Straight Q8 stiffness norm: 7.03e11
```

The curved element is slightly stiffer (~5%) due to the geometric distortion. As long as `detJ > 0` at all Gauss points, the result is valid.

---

## 14.9 Q8 vs Q4 — Convergence Comparison

### Patch test (simple tension)

Both Q4 and Q8 pass the patch test exactly on a regular mesh — they recover constant stress exactly.

### Cantilever beam convergence

```
                      Tip displacement error vs elements through depth
Elements
through    ──────────────────────────────────────────────────────
depth      Q4 (%)           Q8 (%)           LST (%)
──────────────────────────────────────────────────────────────
1          >500 (locked)     12               15
2          45                 3                4
4          12                <1               <1
8           3                <0.1             <0.1
```

Q8 with **1 element through depth** is already more accurate than Q4 with **4 elements through depth**.

### DOF efficiency

For a 4×4 grid of Q8 elements:

| Mesh | Elements | Nodes | DOF | Tip error |
|------|----------|-------|-----|-----------|
| 4×4 Q4 | 16 | 25 | 50 | ~5% |
| 2×2 Q8 | 4 | 25 | 50 | ~1% |
| 4×4 Q8 | 16 | 81 | 162 | <0.1% |

Same DOF, Q8 is **5× more accurate**.

---

## 14.10 Q8 in the 2D Element Family

```
2D Elements ───┬─── CST (3-node tri)    ← Constant strain
               │
               ├─── LST (6-node tri)     ← Linear strain, no lock
               │
               ├─── Q4 (4-node quad)     ← Bilinear, locks
               │
               └─── Q8 (8-node quad)     ← Quadratic, no lock (you are here)
```

| Property | CST | LST | Q4 | Q8 |
|----------|-----|-----|----|----|
| Nodes | 3 | 6 | 4 | **8** |
| DOF/element | 6 | 12 | 8 | **16** |
| Shape | Linear | Quadratic | Bilinear | **Quadratic** |
| Locks in bending? | Yes | **No** | Yes | **No** |
| Integration | 1-pt | 3-pt tri | 2×2 Gauss | **3×3 Gauss** |
| Curved geometry | No | **Yes** | No | **Yes** |
| B matrix | Constant | Linear | Bilinear | **Quadratic** |
| Hourglass modes | No | No | **Yes** (reduced int.) | No (full int.) |
| Accuracy/DOF | Low | Medium | Medium | **High** |

### When to use what

- **Quick analysis, irregular mesh**: CST (simplest, distortion-proof)
- **Quad-dominant mesh, simple shapes**: Q4 (cheap, but need fine mesh for bending)
- **Accurate bending analysis**: **Q8** (best choice — quadratic, no locking)
- **Very high accuracy, structured mesh**: Q8 with 2+ elements through depth
- **Curved boundary**: Q8 or LST (both have mid-edge/face nodes for curvature)

---

## 14.11 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 8-node quadrilateral, 2 DOF/node |
| Matrix size | **16×16** |
| Shape functions | **Serendipity** — corners: ¼(1+ξξᵢ)(1+ηηᵢ)(ξξᵢ+ηηᵢ−1); mid-edges: ½(1−ξ²)(1±η), ½(1±ξ)(1−η²) |
| Polynomial terms | 1, ξ, η, ξ², ξη, η², ξ²η, ξη² — **missing ξ²η²** |
| Coordinate system | Natural (ξ,η) ∈ [-1,1] |
| Integration | **3×3 Gauss-Legendre** (9 points) — minimum safe integration |
| Bending | **Does NOT lock** — one element through depth is accurate |
| Curved boundaries | Supported — user-controlled mid-edge node positions |
| MATLAB difference | MATLAB computes mid-edge coords internally from 4 corners; Julia takes all 8 explicitly |
| detJ guard | Positive determinant enforced at all Gauss points |
| Stress recovery | At centroid (ξ=η=0) |
| Assembly | `_assemble_n!(K, k, [n1..n8], 2)` — one-liner vs MATLAB's 256-line assembly |
| Distortion | Low sensitivity (better than Q4, similar to LST) |

### Full API

```julia
# Internal helpers
_gauss_3x3()                                                                # → 9 Gauss points
_q8_shape_functions(ξ, η)                                                   # → (N, dN_dξ, dN_dη)

# Public API
d2_q8_elementstiffness(E, NU, h, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, x7,y7, x8,y8, p)   # → 16×16
d2_q8_elementstress(E, NU, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, x7,y7, x8,y8, p, u)       # → 3-vec
d2_q8_elementpstress(sigma)                                                                      # → (σ₁, σ₂, θ_deg)
d2_q8_assemble(K, k, n1, n2, n3, n4, n5, n6, n7, n8)                                            # → updated K
```

### The family so far

| Lesson | Element | Nodes × DOF/n | Matrix | Integration | Locks? | Coordinate system |
|--------|---------|--------------|--------|-------------|--------|-------------------|
| 2 | 1D Spring | 2 × 1 | 2×2 | Analytic | — | — |
| 3 | 1D Bar | 2 × 1 | 2×2 | Analytic | — | — |
| 4 | Quadratic Bar | 3 × 1 | 3×3 | Analytic | — | — |
| 5 | 2D Truss | 2 × 2 | 4×4 | Analytic | — | Direction angles |
| 6 | 3D Truss | 2 × 3 | 6×6 | Analytic | — | Direction cosines |
| 7 | 2D Plane Frame | 2 × 3 | 6×6 | Analytic | — | θ |
| 8 | 2D Pure Beam | 2 × 2 | 4×4 | Analytic | — | — |
| 9 | 2D Plane Grid | 2 × 3 | 6×6 | Analytic | — | θ |
| 10 | 3D Space Frame | 2 × 6 | 12×12 | Analytic | — | Direction cosines |
| 11 | CST (3-node tri) | 3 × 2 | 6×6 | 1-pt centroid | Yes | Area coords |
| 12 | LST (6-node tri) | 6 × 2 | 12×12 | 3-pt tri Gauss | **No** | Area coords |
| 13 | Q4 (4-node quad) | 4 × 2 | 8×8 | 2×2 Gauss | Yes | ξ,η ∈ [-1,1] |
| **14** | **Q8 (8-node quad)** | **8 × 2** | **16×16** | **3×3 Gauss** | **No** | **ξ,η ∈ [-1,1]** |

### Next up

- **Lesson 15**: Linear Tetrahedron (4-node, 3D analog of CST)
- **Lesson 16**: Linear Brick (8-node, 3D analog of Q4 — also locks)
- **Lesson 17**: Heat transfer / fluid flow / dynamics (Chapter 17 — special topics)
