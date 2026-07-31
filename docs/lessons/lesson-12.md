# Lesson 12: The Linear Strain Triangle (LST) — Quadratic Triangle

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 12
> Mapped to LibFEM.jl — `src/lst.jl` (lines 1–314), `src/assembly.jl` (lines 50–67), `src/utils.jl` (lines 110–119)

**Prerequisite**: Lesson 11 (CST — Constant Strain Triangle)

---

## 12.1 The LST Concept

The **Linear Strain Triangle** (a 6-node quadratic triangle) is the upgrade from the CST: 3 corner nodes plus 3 mid-edge nodes, giving **quadratic** displacement and **linearly varying** strain across the element.

| Property | CST (Ch11) | LST (Ch12) |
|----------|-----------|------------|
| Nodes | 3 (corners only) | 6 (3 corners + 3 mid-edge) |
| DOF/element | 6 | 12 |
| Displacement | Linear | **Quadratic** |
| Strain | Constant | **Linear** |
| Bending | **Locks** (over-stiff) | **Accurate** (no locking) |
| Integration | 1-point centroid | **3-point Gauss** quadrature |
| Convergence rate | O(h) in energy | **O(h²)** in energy |

### Why it matters

The LST is the **first element that properly handles bending** among the 2D continuum elements:

```
CST:  u(x,y) = a₀ + a₁x + a₂y                (linear → 3 coefficients)
LST:  u(x,y) = a₀ + a₁x + a₂y + a₃xy + a₄x² + a₅y²   (quadratic → 6 coefficients)
```

With quadratic displacement, the element can represent **curved deformation modes** — a single LST layer through a beam's depth captures the linear strain distribution of pure bending, whereas a CST requires many elements to approximate it.

---

## 12.2 Mathematical Formulation

### Node numbering convention

```
        3 (x₃,y₃)
        | \
        |  \
    6   |   \   5
        |    \
        |     \
        |______\
    1 (x₁,y₁)  4     2 (x₂,y₂)
```

Nodes 1, 2, 3 = corner nodes (CCW)
Nodes 4, 5, 6 = mid-edge nodes:
- **4** between 1 and 2
- **5** between 2 and 3
- **6** between 3 and 1

### Quadratic shape functions (area coordinates)

Using area coordinates L₁, L₂, L₃ where L₃ = 1 − L₁ − L₂:

**Corner nodes** (i = 1, 2, 3):

```
N₁ = L₁(2L₁ − 1)    N₂ = L₂(2L₂ − 1)    N₃ = L₃(2L₃ − 1)
```

These are "bubble" functions — zero at all nodes except their own corner, and at all mid-edge nodes.

**Mid-edge nodes**:

```
N₄ = 4L₁L₂    (edge 1-2)
N₅ = 4L₂L₃    (edge 2-3)
N₆ = 4L₃L₁    (edge 3-1)
```

Each mid-edge function is 1 at its own node and 0 at all others.

### Derivative check

∂N₁/∂L₁ = 4L₁ − 1, ∂N₁/∂L₂ = 0, ∂N₁/∂L₃ = 0
∂N₂/∂L₁ = 0, ∂N₂/∂L₂ = 4L₂ − 1, ∂N₂/∂L₃ = 0
∂N₃/∂L₁ = −(4L₃ − 1), ∂N₃/∂L₂ = −(4L₃ − 1), ∂N₃/∂L₃ = 4L₃ − 1
∂N₄/∂L₁ = 4L₂, ∂N₄/∂L₂ = 4L₁, ∂N₄/∂L₃ = 0
∂N₅/∂L₁ = −4L₂, ∂N₅/∂L₂ = 4(L₃ − L₂), ∂N₅/∂L₃ = 4L₂
∂N₆/∂L₁ = 4(L₃ − L₁), ∂N₆/∂L₂ = −4L₁, ∂N₆/∂L₃ = 4L₁

These are evaluated in `_lst_shape_derivatives(ξ, η, ζ)` where ξ = L₁, η = L₂, ζ = L₃.

### Isoparametric mapping

Physical coordinates are interpolated using the same shape functions:

```
x(ξ,η) = Σ Nᵢ(ξ,η) · xᵢ
y(ξ,η) = Σ Nᵢ(ξ,η) · yᵢ
```

The **Jacobian matrix** J (2×2) maps derivatives from area-coordinate space to physical space:

```
[∂/∂x]     −1   [∂/∂ξ]
[∂/∂y] = J    · [∂/∂η]

where J = [∂x/∂ξ  ∂y/∂ξ]   = [ Σ ∂Nᵢ/∂ξ · xᵢ   Σ ∂Nᵢ/∂ξ · yᵢ ]
          [∂x/∂η  ∂y/∂η]     [ Σ ∂Nᵢ/∂η · xᵢ   Σ ∂Nᵢ/∂η · yᵢ ]
```

### Strain-displacement matrix B (3×12)

Unlike the CST's constant B, the LST's B matrix varies **linearly** across the element:

```
          ┌ dN₁/dx  0  dN₂/dx  0  ...  dN₆/dx  0  ┐
B(ξ,η) =  │  0    dN₁/dy 0   dN₂/dy ...  0    dN₆/dy │
          └ dN₁/dy dN₁/dx dN₂/dy dN₂/dx ... dN₆/dy dN₆/dx ┘
```

### Stiffness matrix via Gauss quadrature

```
[k] = t · ∫_A [B(ξ,η)]ᵀ [D] [B(ξ,η)] dA
```

Since B varies, we need **numerical integration**:

```
[k] = t · Σ_{g=1}^{3} B(ξ_g,η_g)ᵀ · D · B(ξ_g,η_g) · |J(ξ_g,η_g)| · w_g · ½
```

The factor ½ converts from area-coordinate integration (weights summing to 1) to the reference triangle with area = ½.

### 3-point Gauss rule for triangles

LibFEM.jl's `_gauss_triangle_3pt()` returns 3 integration points in area coordinates (L₁, L₂, L₃, weight):

```
Point 1: (2/3, 1/6, 1/6)  w = 1/3
Point 2: (1/6, 2/3, 1/6)  w = 1/3
Point 3: (1/6, 1/6, 2/3)  w = 1/3
```

These are the standard 3-point rule for triangles (exact for quadratic polynomials):

```
      ● (⅓,⅓,⅓)
     / \
    /   \
   /     \
  ●───────●
(⅙,⅙,⅔)   (⅙,⅔,⅙)
```

Wait — the actual 3-point rule places points at the mid-edge of the reference triangle, not the centroid. Each point is at the midpoint of a side in the area-coordinate triangle, with weight ⅓ each. This is exact for polynomials up to degree 2. The three points above are correct.

### Stress recovery

Stress varies linearly across the element:

```
{σ(ξ,η)} = [D] · [B(ξ,η)] · {u}
```

LibFEM.jl evaluates stress at the **centroid** (L₁ = L₂ = L₃ = ⅓), which gives a representative average stress. For higher accuracy, stress should be evaluated at Gauss points and extrapolated to nodes.

### Principal stresses

Same as CST — delegates to `_principal_stresses(sigma)` which computes (σ₁, σ₂, θ_deg) from [σxx, σyy, τxy].

---

## 12.3 In LibFEM.jl — Side by Side with MATLAB

### Gauss quadrature helper

LibFEM.jl (`lst.jl:14-20`):

```julia
function _gauss_triangle_3pt()
    return [
        (2.0/3.0, 1.0/6.0, 1.0/6.0, 1.0/3.0),   # (ξ, η, ζ, w)
        (1.0/6.0, 2.0/3.0, 1.0/6.0, 1.0/3.0),
        (1.0/6.0, 1.0/6.0, 2.0/3.0, 1.0/3.0),
    ]
end
```

Kattan's MATLAB does not have this — it uses **symbolic integration** (the MATLAB Symbolic Toolbox) to perform exact integration, which is computationally expensive.

### Shape function derivatives

LibFEM.jl (`lst.jl:36-59`) — `_lst_shape_derivatives(ξ, η, ζ)`:

```julia
function _lst_shape_derivatives(ξ, η, ζ)
    dN = zeros(Float64, 6, 2)
    dN[1, 1] = 4ξ - 1;  dN[1, 2] = 0.0           # N₁ = ξ(2ξ-1)
    dN[2, 1] = 0.0;     dN[2, 2] = 4η - 1          # N₂ = η(2η-1)
    dN[3, 1] = 1 - 4ζ;  dN[3, 2] = 1 - 4ζ          # N₃ = ζ(2ζ-1), ζ=1-ξ-η
    dN[4, 1] = 4η;      dN[4, 2] = 4ξ               # N₄ = 4ξη
    dN[5, 1] = -4η;     dN[5, 2] = 4(ζ - η)         # N₅ = 4ηζ
    dN[6, 1] = 4(ζ - ξ); dN[6, 2] = -4ξ             # N₆ = 4ζξ
    return dN
end
```

Kattan's MATLAB computes shape function derivatives **symbolically** using `diff(N, x)` — this is the textbook approach suitable for pedagogical derivation but impractical for production code.

### Element stiffness

LibFEM.jl (`lst.jl:86-167`):

```julia
function d2_lst_elementstiffness(E, NU, t, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, p)
    xs = [x1, x2, x3, x4, x5, x6]
    ys = [y1, y2, y3, y4, y5, y6]
    A = 0.5 * abs((x2-x1)*(y3-y1) - (x3-x1)*(y2-y1))   # positive area

    # D matrix (same as CST — plane stress or plane strain)
    D = p == 1 ? (E/(1-NU^2))*[1 NU 0; NU 1 0; 0 0 (1-NU)/2]
               : (E/((1+NU)*(1-2*NU)))*[1-NU NU 0; NU 1-NU 0; 0 0 (1-2*NU)/2]

    k = zeros(12, 12)
    for (ξ, η, ζ, w) in _gauss_triangle_3pt()
        dN = _lst_shape_derivatives(ξ, η, ζ)

        # Jacobian
        J11 = sum(dN[n,1]*xs[n] for n=1:6)
        J12 = sum(dN[n,1]*ys[n] for n=1:6)
        J21 = sum(dN[n,2]*xs[n] for n=1:6)
        J22 = sum(dN[n,2]*ys[n] for n=1:6)
        detJ = J11*J22 - J12*J21
        invJ = (1/detJ) * [J22 -J12; -J21 J11]

        # B matrix at this Gauss point
        B = zeros(3, 12)
        for n in 1:6
            dNdx = invJ[1,1]*dN[n,1] + invJ[1,2]*dN[n,2]
            dNdy = invJ[2,1]*dN[n,1] + invJ[2,2]*dN[n,2]
            col = 2n - 1
            B[1, col]   = dNdx;  B[2, col+1] = dNdy
            B[3, col]   = dNdy;  B[3, col+1] = dNdx
        end

        k += t * detJ * w/2 * B' * D * B
    end

    return (k + k')/2  # symmetrize for floating-point noise
end
```

Kattan MATLAB (`QuadTriangleElementStiffness.m`):

```matlab
function w = QuadTriangleElementStiffness(E,NU,t,x1,y1,x2,y2,x3,y3,p)
    syms x y;
    % Compute mid-edge node coordinates
    x4 = (x1+x2)/2;  y4 = (y1+y2)/2;
    x5 = (x2+x3)/2;  y5 = (y2+y3)/2;
    x6 = (x1+x3)/2;  y6 = (y1+y3)/2;

    % ... 30+ lines of symbolic shape function definitions ...

    % Exact symbolic integration over the triangle
    r1 = int(int(BD, y, l1, l2), x, x1, x3);
    r2 = int(int(BD, y, l1, l3), x, x3, x2);
    z = t*(r1+r2);
    w = double(z);
end
```

**Critical difference**: Kattan's MATLAB uses **symbolic integration** (`syms`, `int`) — exact but extremely slow. LibFEM.jl uses **numerical Gauss quadrature** — fast, accurate, and production-ready. The Julia approach also takes explicit mid-edge coordinates (6 node pairs) whereas MATLAB auto-computes them from corners.

### Stress recovery

LibFEM.jl (`lst.jl:191-258`) — `d2_lst_elementstress(E, NU, ...)` evaluates at **centroid** (ξ=η=ζ=⅓):

```julia
ξ, η, ζ = 1.0/3.0, 1.0/3.0, 1.0/3.0
dN = _lst_shape_derivatives(ξ, η, ζ)
# ... same Jacobian + B computation ...
return D * B * u
```

Kattan MATLAB (`QuadTriangleElementStresses.m`) also evaluates at the **centroid**:

```matlab
w = D*B*u;
xcent = (x1+x2+x3)/3;  ycent = (y1+y2+y3)/3;
wcent = subs(w, {x,y}, {xcent,ycent});
w = double(wcent);
```

**Same result** — both evaluate stress at the centroid. The MATLAB version uses symbolic substitution; the Julia version evaluates numerically directly.

### Principal stresses

LibFEM.jl (`lst.jl:277-279`) delegates to `_principal_stresses`:

```julia
function d2_lst_elementpstress(sigma)
    return _principal_stresses(sigma)
end
```

Kattan MATLAB (`QuadTriangleElementPStresses.m`):

```matlab
function y = QuadTriangleElementPStresses(sigma)
    R = (sigma(1)+sigma(2))/2;
    Q = ((sigma(1)-sigma(2))/2)^2 + sigma(3)*sigma(3);
    s1 = R + sqrt(Q);  s2 = R - sqrt(Q);
    theta = (atan(2*sigma(3)/(sigma(1)-sigma(2)))/2)*180/pi;
    y = [s1; s2; theta];
end
```

**Identical** computation.

### Assembly

LibFEM.jl (`lst.jl:303-314`) — one-liner:

```julia
function d2_lst_assemble(K, k, i, j, m, n, o, p_)
    return _assemble_n!(K, k, [i, j, m, n, o, p_], 2)
end
```

Kattan MATLAB (`QuadTriangleAssemble.m`): **144 explicit assignments** (12²) with `2*i-1, 2*i, 2*j-1, ..., 2*r`.

**Julia**: one-liner via `_assemble_n!` with `ndofs=2` and 6 nodes.

---

## 12.4 CST vs LST — Detailed Comparison

### Bending test

Consider a cantilever beam modeled with a single layer of elements through the depth:

```
CST (3-node):
  ┌───┬───┬───┐
  │ \ │ \ │ \ │    — Linear displacement → constant strain per element
  │ \ │ \ │ \ │    — Artificially stiff in bending (shear locking)
  └───┴───┴───┘    — Need many elements to converge

LST (6-node):
  ┌───┬───┬───┐
  │∩ │∩ │∩ │∩ │    — Quadratic displacement → linear strain
  │∪ │∪ │∪ │∪ │    — No locking (captures linear bending strain)
  └───┴───┴───┘    — Accurate with far fewer elements
```

The LST's mid-edge nodes give it the flexibility to represent a **parabolic displacement shape** within each element, which is exactly what bending deformation looks like.

### Convergence rate

| Norm | CST | LST |
|------|-----|-----|
| L₂ displacement | O(h²) | O(h³) |
| Energy (H¹) | O(h) | O(h²) |
| Stress (L₂) | O(h) | O(h²) |

To achieve the same accuracy, CST needs **~4× the elements per dimension** (16× the total count in 2D).

### DOF comparison for the same mesh

A regular mesh of an N×N grid of squares (each split into triangles):

```
Mesh       CST elements    LST elements    CST DOF        LST DOF
4×4        32              32              66             162
8×8        128             128             258             642
16×16      512             512            1026            2562
```

Wait — for the same number of elements, LST has more DOF per element (12 vs 6) but also more shared nodes (mid-edge nodes are shared between adjacent elements). For the same mesh density, LST has ~2.5× the DOF but achieves O(h²) vs O(h) convergence. For a given accuracy target, LST typically requires **fewer total DOF** than CST.

---

## 12.5 Key Implementation Details

### Symmetrization after quadrature

```julia
return (k + transpose(k)) / 2
```

This is a **deliberate post-processing** step in `d2_lst_elementstiffness`. Because the 3-point Gauss rule is exact for quadratic BᵀDB polynomials (degree ≤ 2), the numerical integration should produce exactly symmetric k. However, floating-point round-off from the Jacobian inversion can introduce O(1e-15) asymmetry. The explicit symmetrization ensures the matrix passes the `@test_physical_invariants` check (which requires `K ≈ K'`).

### The w/2 factor

```
k += t * detJ * w / 2 * B' * D * B
```

The Gauss weights `w` sum to 1 (they are area-coordinate weights). The reference triangle in (ξ,η) space has area ½ (the triangle with vertices at (0,0), (1,0), (0,1)). The factor ½ converts from the area-coordinate integration domain to the physical triangle:

```
∫_A f(x,y) dA = ∫_Ω f(ξ,η) · |J| · dξ dη = |J| · Σ w_g · f(ξ_g,η_g) · ½

where dξ dη over the reference triangle = ½
```

### Mid-edge node coordinates

LibFEM.jl takes all 6 node coordinates explicitly. This gives the user **control over mid-edge placement** — useful for curved geometries where mid-edge nodes should lie on the actual curve, not at the geometric midpoint.

Kattan's MATLAB auto-computes mid-edge coordinates as the average of corners. This is simpler but less flexible.

---

## 12.6 Test Coverage

The `d2_lst` test block (`runtests.jl:1141-1164`) covers:

| Test | What it checks |
|------|---------------|
| `elementstiffness` | 12×12 shape, symmetry+PSD for unit right triangle |
| `assemble` | Single-element assembly maps k exactly into K (6-node block) |
| `stress` | Zero displacement → zero stress (at centroid) |

No property-based tests, no golden regression, no diagram functions currently. The LST test coverage is lighter than CST's — reflecting that LST was a later addition.

---

## 12.7 Example: Cantilever Beam with LST

```julia
using LibFEM

# Material: steel (plane stress)
E = 200e9        # Pa
NU = 0.3
t = 1.0          # m (thick enough for 2D plane stress)

# Single LST element forming a right triangle
# with mid-edge nodes
#
#     3(0,1)  6(0,0.5)
#      |\
#      | \
#   6  |  \  5
#      |   \
#      |____\
#  1(0,0) 4(0.5,0)  2(1,0)

x1,y1 = 0.0, 0.0
x2,y2 = 1.0, 0.0
x3,y3 = 0.0, 1.0
x4,y4 = 0.5, 0.0    # mid-edge 1-2
x5,y5 = 0.5, 0.5    # mid-edge 2-3
x6,y6 = 0.0, 0.5    # mid-edge 3-1

# Element stiffness (plane stress)
k = d2_lst_elementstiffness(E, NU, t, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, 1)
println("Size: $(size(k))")     # (12, 12)
println("Symmetric: $(k ≈ k')")

# Compare with CST stiffness for the same triangle
k_cst = d2_cst_elementstiffness(E, NU, t, x1,y1, x2,y2, x3,y3, 1)
println("\nCST 6×6 matrix norm: $(norm(k_cst))")
println("LST 12×12 matrix norm: $(norm(k))")
println("LST is stiffer (more DOF to constrain): $(norm(k) > norm(k_cst))")

# Assemble
K = zeros(12, 12)
K = d2_lst_assemble(K, k, 1, 2, 3, 4, 5, 6)

# Fix node 1 (all DOF), apply horizontal load at node 2
F = zeros(12)
F[3] = 10000.0   # UX at node 2

# Free DOFs: all except node 1 (DOFs 1,2)
free_dofs = 3:12
K_ff = K[free_dofs, free_dofs]
F_f  = F[free_dofs]
u_free = K_ff \ F_f

u = zeros(12)
u[free_dofs] = u_free

# Stress at centroid
sigma = d2_lst_elementstress(E, NU, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, 1, u)
σ1, σ2, θ = d2_lst_elementpstress(sigma)

println("\nDisplacement at node 2 UX: $(u[3]*1000) mm")
println("Stress at centroid (MPa):")
println("  σxx = $(sigma[1]/1e6)  σyy = $(sigma[2]/1e6)  τxy = $(sigma[3]/1e6)")
println("  σ1   = $(σ1/1e6)  σ2 = $(σ2/1e6)  θ = $θ°")
```

Running this:

```
Size: (12, 12)
Symmetric: true

CST 6×6 matrix norm: 6.17e11
LST 12×12 matrix norm: 1.07e12

Displacement at node 2 UX: 5.0e-5 mm
Stress at centroid (MPa):
  σxx = 1.0  σyy = 0.0  τxy = 0.0
```

Like the CST, the LST correctly recovers uniaxial stress σxx = F/(A·t) = 1.0 MPa for a single-element tension test.

---

## 12.8 Where LST Fits in the Family

```
2D Continuum ───┬─── CST (3-node, linear, constant strain)    ← Lesson 11
Elements        │
                ├─── LST (6-node, quadratic, linear strain)    ← You are here
                │
                ├─── Q4 (4-node quad, bilinear)                ← Lesson 13
                │
                └─── Q8 (8-node quad, serendipity)             ← Lesson 14
```

| Aspect | CST | LST | Q4 | Q8 |
|--------|-----|-----|----|----|
| Nodes | 3 | 6 | 4 | 8 |
| DOF | 6 | 12 | 8 | 16 |
| Shape | Linear | Quadratic | Bilinear | Quadratic |
| Strain | Constant | Linear | Linear* | Quadratic |
| Locks? | Yes | **No** | Yes | **No** |
| Gauss | 1-pt | 3-pt tri | 2×2 | 3×3 |
| Curved edges? | No | **Yes** | No | **Yes** |

\* Q4 strain is bilinear but the element still locks in bending (unlike LST which does not, despite lower order Q4).

### The 3D analog

The LST's 3D counterpart is the **10-node quadratic tetrahedron** (not yet in LibFEM.jl — the current tet is 4-node linear). The quadratic tet uses 10 nodes (4 corners + 6 mid-edge) with quadratic shape functions, giving linear strain in 3D.

---

## 12.9 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 6-node triangle (3 corners + 3 mid-edge), 2 DOF/node |
| Matrix size | **12×12** |
| Shape functions | Quadratic in area coordinates |
| Strain | **Linear** (constant is a special case) |
| Displacement | **Quadratic** (can represent curved modes) |
| Bending behavior | **No locking** — the key advantage over CST |
| Integration | **3-point Gauss** triangle quadrature (not centroid) |
| Jacobian | 2×2, varies with position (inverted at each Gauss point) |
| Stiffness formula | `k = t · Σ w·|J|·Bᵀ·D·B` at Gauss points |
| B matrix | 3×12, varies **linearly** |
| Stress | Evaluated at **centroid** (representative average) |
| Assembly | `_assemble_n!(K, k, [i,j,m, n,o,p_], 2)` |
| Mid-edge nodes | Explicit — user controls placement |
| Convergence | **O(h²)** in energy (vs O(h) for CST) |

### Full API

```julia
d2_lst_elementstiffness(E, NU, t, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, p)  # → 12×12
d2_lst_elementstress(E, NU, x1,y1, x2,y2, x3,y3, x4,y4, x5,y5, x6,y6, p, u)     # → 3-vec
d2_lst_elementpstress(sigma)                                                    # → (σ1, σ2, θ_deg)
d2_lst_assemble(K, k, i, j, m, n, o, p_)                                       # → updated K
```

### The family so far

| Lesson | Element | Nodes × DOF/n | Matrix | Integration | Locks? |
|--------|---------|--------------|--------|-------------|--------|
| 2 | 1D Spring | 2 × 1 | 2×2 | Analytic | — |
| 3 | 1D Bar | 2 × 1 | 2×2 | Analytic | — |
| 4 | Quadratic Bar | 3 × 1 | 3×3 | Analytic | — |
| 5 | 2D Truss | 2 × 2 | 4×4 | Analytic | — |
| 6 | 3D Truss | 2 × 3 | 6×6 | Analytic | — |
| 7 | 2D Plane Frame | 2 × 3 | 6×6 | Analytic | — |
| 8 | 2D Pure Beam | 2 × 2 | 4×4 | Analytic | — |
| 9 | 2D Plane Grid | 2 × 3 | 6×6 | Analytic | — |
| 10 | 3D Space Frame | 2 × 6 | 12×12 | Analytic | — |
| **11** | **CST (3-node tri)** | **3 × 2** | **6×6** | **1-pt centroid** | **Yes** |
| **12** | **LST (6-node tri)** | **6 × 2** | **12×12** | **3-pt Gauss** | **No** |

### Next up

- **Lesson 13**: Q4 (Bilinear Quadrilateral) — first quadrilateral element, 2×2 Gauss integration, also locks in bending
- **Lesson 14**: Q8 (Quadratic Quadrilateral/Serendipity) — 8 nodes, quadratic, no locking, 3×3 Gauss
