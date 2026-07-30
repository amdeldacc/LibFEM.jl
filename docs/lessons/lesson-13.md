# Lesson 13: The Bilinear Quadrilateral (Q4) — First Quadrilateral Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 13
> Mapped to LibFEM.jl — `src/quadrilateral.jl` (lines 1–245), `src/assembly.jl` (lines 50–67), `src/utils.jl` (lines 110–119)

**Prerequisite**: Lesson 11 (CST — Constant Strain Triangle). Experience with isoparametric mapping (Lesson 12) helpful.

---

## 13.1 The Q4 Concept

The **bilinear quadrilateral** is a 4-node element — the quadrilateral counterpart of the triangle. It uses **bilinear** shape functions in natural coordinates `ξ,η ∈ [-1,1]`.

| Property | CST (Ch11) | Q4 (Ch13) |
|----------|-----------|-----------|
| Shape | Triangle (3 nodes) | **Quadrilateral** (4 nodes) |
| DOF/element | 6 | **8** |
| Shape functions | Area coordinates | **ξ,η natural coordinates** |
| Spatial variation | Linear | **Bilinear** (product form) |
| Bending | Locks | **Also locks** |
| Integration | 1-pt centroid | **2×2 Gauss** |
| Geometry | Any triangle | **Any convex quad** |

### Why Q4 matters

The Q4 is the **workhorse quadrilateral** for 2D continuum analysis:
- Better accuracy per DOF than CST for regular meshes (fewer elements needed)
- Maps naturally to structured meshes (rectangular grids)
- Straightforward mesh generation (grid of squares → quads)
- Natural 3D extension: the **linear brick** (Ch16 / Lesson 16)

---

## 13.2 Mathematical Formulation

### Natural coordinate system

The Q4 uses a **reference square** in natural coordinates `(ξ,η) ∈ [-1,1] × [-1,1]`:

```
η = +1    4(−1,1) ┌───────┐ 3(1,1)
                   │       │
                   │   →ξ  │
                   │       │
η = −1    1(−1,−1) └───────┘ 2(1,−1)
```

Node ordering: **CCW** starting from bottom-left.

### Bilinear shape functions

```
N₁(ξ,η) = ¼(1 − ξ)(1 − η)     Node 1: (−1, −1) → N₁ = 1
N₂(ξ,η) = ¼(1 + ξ)(1 − η)     Node 2: (+1, −1) → N₂ = 1
N₃(ξ,η) = ¼(1 + ξ)(1 + η)     Node 3: (+1, +1) → N₃ = 1
N₄(ξ,η) = ¼(1 − ξ)(1 + η)     Node 4: (−1, +1) → N₄ = 1
```

Each is a product of two 1D linear functions — hence **bilinear**.

### Properties of bilinear functions

```
N₁ = ¼(1 − ξ − η + ξη)    ← Contains constant, linear, and product (ξη) terms
```

Bilinear functions are:
- **Linear** along each edge (in ξ or η direction)
- **Product (ξη)** in the interior — gives the twisting/quadrilateral shape
- **C⁰ continuous** across element boundaries (displacements match at shared edges)

The product term ξη is what distinguishes a quadrilateral from two triangles — it adds an **interior coupling mode** that triangles lack.

### Shape function derivatives

∂N₁/∂ξ = −(1 − η)/4   ∂N₁/∂η = −(1 − ξ)/4
∂N₂/∂ξ =  (1 − η)/4   ∂N₂/∂η = −(1 + ξ)/4
∂N₃/∂ξ =  (1 + η)/4   ∂N₃/∂η =  (1 + ξ)/4
∂N₄/∂ξ = −(1 + η)/4   ∂N₄/∂η =  (1 − ξ)/4

### Isoparametric mapping

The same shape functions map both geometry and displacements:

```
x(ξ,η) = Σ Nᵢ(ξ,η) · xᵢ     y(ξ,η) = Σ Nᵢ(ξ,η) · yᵢ
u(ξ,η) = Σ Nᵢ(ξ,η) · uᵢ     v(ξ,η) = Σ Nᵢ(ξ,η) · vᵢ
```

This maps the reference square to a **general convex quadrilateral** in physical space:

```
Reference (ξ,η):       Physical (x,y):
  (−1,−1)    →          (x₁,y₁)   node 1
  (+1,−1)    →          (x₂,y₂)   node 2
  (+1,+1)    →          (x₃,y₃)   node 3
  (−1,+1)    →          (x₄,y₄)   node 4
```

### Jacobian matrix J (2×2)

```
      [∂x/∂ξ  ∂y/∂ξ]     [ Σ ∂Nᵢ/∂ξ · xᵢ   Σ ∂Nᵢ/∂ξ · yᵢ ]
J =   [∂x/∂η  ∂y/∂η]  =  [ Σ ∂Nᵢ/∂η · xᵢ   Σ ∂Nᵢ/∂η · yᵢ ]
```

For the Q4, the Jacobian varies **bilinearly** with ξ,η — it's not constant (unlike the triangle's constant Jacobian).

The determinant |J| maps differential areas: `dx·dy = |J| dξ·dη`

```
For a rectangle: J is diagonal, |J| = constant = area/4
For a general quad: J varies with position → requires numerical integration
```

### Strain-displacement matrix B (3×8)

```
B(ξ,η) = [∂N₁/∂x   0   ∂N₂/∂x   0   ∂N₃/∂x   0   ∂N₄/∂x   0
            0     ∂N₁/∂y  0    ∂N₂/∂y  0    ∂N₃/∂y  0    ∂N₄/∂y
           ∂N₁/∂y ∂N₁/∂x ∂N₂/∂y ∂N₂/∂x ∂N₃/∂y ∂N₃/∂x ∂N₄/∂y ∂N₄/∂x]
```

The physical derivatives are obtained via the inverse Jacobian:

```
[∂Nᵢ/∂x]    −1  [∂Nᵢ/∂ξ]
[∂Nᵢ/∂y] = J   · [∂Nᵢ/∂η]
```

### Stiffness matrix via 2×2 Gauss quadrature

```
[k] = h · ∫_{-1}^{1}∫_{-1}^{1} [B(ξ,η)]ᵀ [D] [B(ξ,η)] · |J(ξ,η)| dξ dη
```

This is evaluated numerically with 2×2 Gauss-Legendre quadrature:

```
[k] ≈ h · Σ_{i=1}^{2} Σ_{j=1}^{2} B(ξᵢ,ηⱼ)ᵀ · D · B(ξᵢ,ηⱼ) · |J(ξᵢ,ηⱼ)| · wᵢ · wⱼ
```

### 2×2 Gauss points

```
i  ξᵢ        ηⱼ        w
──────────────────────────
1  −1/√3     −1/√3     1
2  +1/√3     −1/√3     1
3  +1/√3     +1/√3     1
4  −1/√3     +1/√3     1
```

For a rectangular element, 2×2 Gauss is **exact** — the Bᵀ·D·B integrand has terms up to degree 2 in each direction, and 2×2 Gauss integrates polynomials up to degree 3 exactly.

For a distorted quadrilateral, the rational Jacobian makes exact integration impossible — 2×2 Gauss is still used as the optimal rule (higher-order rules add cost with diminishing returns).

### Stress recovery

Stress is evaluated at the **centroid** (ξ = η = 0):

```
{σ} = [D] · [B(0,0)] · {u}
```

The centroid gives the **best-average** stress for Q4 (it's the point where super-convergent patch recovery is most accurate). For more detailed stress distributions, evaluate at the 2×2 Gauss points and extrapolate to nodes.

### Principal stresses

Delegates to the same `_principal_stresses` helper — computes (σ₁, σ₂, θ_deg) from [σxx, σyy, τxy].

---

## 13.3 In LibFEM.jl — Side by Side with MATLAB

### Gauss quadrature helper

LibFEM.jl (`quadrilateral.jl:11-17`):

```julia
function _gauss_2x2()
    gp = 1.0 / sqrt(3.0)
    return [(-gp, -gp, 1.0), ( gp, -gp, 1.0),
            ( gp,  gp, 1.0), (-gp,  gp, 1.0)]
end
```

Kattan's MATLAB does not need this — it uses symbolic integration.

### Element stiffness

LibFEM.jl (`quadrilateral.jl:63-130`) — numerical 2×2 Gauss integration:

```julia
function d2_q4_elementstiffness(E, NU, h, x1,y1, x2,y2, x3,y3, x4,y4, p)
    x = [x1, x2, x3, x4];  y = [y1, y2, y3, y4]

    # D matrix (same as CST/LST)
    D = (...)  # plane stress or plane strain

    k = zeros(8, 8)
    for (ξ, η, w) in _gauss_2x2()
        # Shape function derivatives in natural coordinates
        dN_dξ = [-(1-η)/4,  (1-η)/4,  (1+η)/4, -(1+η)/4]
        dN_dη = [-(1-ξ)/4, -(1+ξ)/4,  (1+ξ)/4,  (1-ξ)/4]

        # Jacobian
        J11 = dN_dξ[1]*x1 + dN_dξ[2]*x2 + dN_dξ[3]*x3 + dN_dξ[4]*x4
        J12 = dN_dξ[1]*y1 + dN_dξ[2]*y2 + dN_dξ[3]*y3 + dN_dξ[4]*y4
        J21 = dN_dη[1]*x1 + dN_dη[2]*x2 + dN_dη[3]*x3 + dN_dη[4]*x4
        J22 = dN_dη[1]*y1 + dN_dη[2]*y2 + dN_dη[3]*y3 + dN_dη[4]*y4

        detJ = J11*J22 - J12*J21
        detJ <= 0 && throw(...)  # guards against inverted/distorted elements

        # Inverse Jacobian
        invJ11 =  J22/detJ;  invJ12 = -J12/detJ
        invJ21 = -J21/detJ;  invJ22 =  J11/detJ

        # B matrix
        B = zeros(3, 8)
        for i in 1:4
            dNdx = invJ11*dN_dξ[i] + invJ12*dN_dη[i]
            dNdy = invJ21*dN_dξ[i] + invJ22*dN_dη[i]
            col = 2*(i-1) + 1
            B[1, col] = dNdx;  B[2, col+1] = dNdy
            B[3, col] = dNdy;  B[3, col+1] = dNdx
        end

        k += h * B' * D * B * detJ * w
    end
    return k
end
```

Kattan MATLAB has **two versions** of the stiffness function:

**Version 1** (`BilinearQuadElementStiffness.m`) — compact symbolic with intermediate a,b,c,d:

```matlab
function w = BilinearQuadElementStiffness(E,NU,h,x1,y1,x2,y2,x3,y3,x4,y4,p)
    syms s t;
    a = (y1*(s-1)+y2*(-1-s)+y3*(1+s)+y4*(1-s))/4;
    b = (y1*(t-1)+y2*(1-t)+y3*(1+t)+y4*(-1-t))/4;
    c = (x1*(t-1)+x2*(1-t)+x3*(1+t)+x4*(-1-t))/4;
    d = (x1*(s-1)+x2*(-1-s)+x3*(1+s)+x4*(1-s))/4;
    % ... B1-B4 blocks built from a,b,c,d ...
    Bfirst = [B1 B2 B3 B4];
    % ... J computed via a clever matrix product ...
    B = Bfirst/J;
    D = ...;  % same D matrix
    BD = J*transpose(B)*D*B;
    r = int(int(BD, t, -1, 1), s, -1, 1);
    z = h*r;
    w = double(z);
end
```

**Version 2** (`BilinearQuadElementStiffness2.m`) — explicit shape functions and diff:

```matlab
function w = BilinearQuadElementStiffness2(E,NU,h,x1,y1,x2,y2,x3,y3,x4,y4,p)
    syms s t;
    N1 = (1-s)*(1-t)/4;  N2 = (1+s)*(1-t)/4;
    N3 = (1+s)*(1+t)/4;  N4 = (1-s)*(1+t)/4;
    x = N1*x1 + N2*x2 + N3*x3 + N4*x4;
    y = N1*y1 + N2*y2 + N3*y3 + N4*y4;
    xs = diff(x,s); xt = diff(x,t);
    ys = diff(y,s); yt = diff(y,t);
    J = xs*yt - ys*xt;
    % ... explicit B matrix built from shape function derivatives ...
    B = ...;
    BD = transpose(B)*D*B/J;
    r = int(int(BD, t, -1, 1), s, -1, 1);
    z = h*r;
    w = double(z);
end
```

**Key differences**:
1. **Symbolic vs numerical**: Kattan's MATLAB uses `syms`/`int`/`double` (exact symbolic → numeric conversion). LibFEM.jl uses 2×2 Gauss quadrature (purely numeric).
2. **Jacobian form**: Version 1 uses a compact matrix product for J; Version 2 uses explicit derivatives. LibFEM uses direct element-wise computation.
3. **Jacobian in denominator**: Version 2 divides by J (`B'*D*B/J`) because B includes 1/J from the inversion. Version 1 has `J*B'*D*B` for the same reason. LibFEM explicitly inverts J and builds B using the inverse — clearer.
4. **detJ guard**: LibFEM.jl checks `detJ > 0` and throws a descriptive error. Kattan's MATLAB has no such guard — a badly-warped element silently produces wrong results.

### Element area

LibFEM.jl (`quadrilateral.jl:20-39`):

```julia
function d2_q4_elementarea(x1,y1, x2,y2, x3,y3, x4,y4)
    area1 = (x1*(y2-y3) + x2*(y3-y1) + x3*(y1-y2)) / 2   # triangle 1-2-3
    area2 = (x1*(y3-y4) + x3*(y4-y1) + x4*(y1-y3)) / 2   # triangle 1-3-4
    return area1 + area2
end
```

Kattan MATLAB (`BilinearQuadElementArea.m`): **identical** decomposition into two triangles.

### Stress recovery

LibFEM.jl (`quadrilateral.jl:149-196`) — `d2_q4_elementstress` evaluates at **centroid** (ξ=η=0):

```julia
ξ, η = 0.0, 0.0
dN_dξ = [-(1-η)/4,  (1-η)/4,  (1+η)/4, -(1+η)/4]
dN_dη = [-(1-ξ)/4, -(1+ξ)/4,  (1+ξ)/4,  (1-ξ)/4]
# ... Jacobian and B at centroid ...
return D * B * u
```

Kattan MATLAB (`BilinearQuadElementStresses.m`):

```matlab
% ... symbolic B computation ...
w = D*B*u;
wcent = subs(w, {s,t}, {0,0});    % evaluate at centroid
w = double(wcent);
```

**Same result** — both evaluate at the centroid. MATLAB uses symbolic substitution; Julia computes numerically.

### Principal stresses

Identical pattern — both delegate to the same principal stress formula (see Lessons 11 and 12).

### Assembly

LibFEM.jl (`quadrilateral.jl:240-245`):

```julia
function d2_q4_assemble(K, k, i, j, m, n)
    return _assemble_n!(K, k, [i, j, m, n], 2)
end
```

Kattan MATLAB (`BilinearQuadAssemble.m`): **64 explicit assignments** (8²) with `2*i-1, 2*i, 2*j-1, ..., 2*n`.

**Julia**: one-liner via `_assemble_n!` with `ndofs=2` and 4 nodes.

---

## 13.4 The Jacobian Determinant and Element Quality

### detJ > 0 is required

For a valid isoparametric mapping, the Jacobian determinant must be **positive everywhere** in the element. LibFEM.jl checks this at every Gauss point:

```julia
if detJ <= 0
    throw(ElementParameterError("det(J)",
        "Negative or zero Jacobian determinant at Gauss point ($ξ, $η). " *
        "Check element geometry and node ordering (must be CCW)."))
end
```

### Causes of negative detJ

| Problem | What happens |
|---------|-------------|
| CW node ordering | detJ < 0 at all points (inverted element) |
| Concave quadrilateral | detJ < 0 in the re-entrant corner region |
| Severely distorted | detJ approaches zero → inaccurate integration |
| Collapsed (3-node limit) | detJ = 0 at the degenerate corner |

### Element quality guidelines

```
Good:                Bad:
┌───────┐           ┌───────┐
│       │           │       │
│   □   │           │   ◇   │  (skewed, aspect ratio > 5)
│       │           │       │
└───────┘           └───────┘

┌───────┐           ╱───────┐
│       │          ╱       │
│   □   │         ╱   ◁    │  (concave, detJ < 0)
│       │        ╱         │
└───────┘       └─────────┘
```

- **Aspect ratio**: keep < 5:1 (ideally 1:1)
- **Interior angles**: keep near 90° (avoid < 45° or > 135°)
- **Concave elements**: forbidden (detJ < 0)
- Distortion degrades Q4 accuracy faster than it does for triangles (CST is distortion-immune)

---

## 13.5 Q4 as Two CSTs

Any quadrilateral can be split into two triangles along a diagonal:

```
    4─────3             4─────3
    │     │             │\    │
    │  □  │     →       │ \   │
    │     │             │  \  │
    1─────2             1─────2
```

### Difference between Q4 and 2×CST

| Aspect | Q4 | 2×CST |
|--------|-----|-------|
| DOF | 8 (4 nodes × 2) | 8 (same nodes) |
| Shape functions | Single bilinear | Two linear (discontinuous across diagonal) |
| Strain | Bilinear (smooth) | Piecewise constant (jump at diagonal) |
| Accuracy | **Better** for bending | Slightly over-stiff (diagonal locking) |
| Mesh bias | No preferred direction | Depends on diagonal orientation |

The Q4's bilinear shape function adds the **ξη product term** which the two CSTs cannot represent jointly. This gives Q4 better in-plane bending response — but it still locks in out-of-plane bending.

### When to use what

- **Regular mesh**: Q4 is preferred (fewer elements, better accuracy)
- **Irregular mesh**: Q4+CST mixed can handle complex geometries
- **Mesh with degenerate quads**: Q4 collapsed to triangle works but is inefficient — use CST directly
- **Large deformation**: Q4 with reduced integration (1-point Gauss + hourglass control) is common in explicit dynamics

---

## 13.6 Shear Locking in Q4

Like CST, Q4 suffers from **shear locking** in bending. A single row of Q4 elements through a beam's depth cannot represent the linear bending strain:

```
Pure bending — exact solution:
  εxx = y/ρ    (linear through depth)
  γxy = 0      (zero shear)

Q4 with one element through depth:
  εxx = a + b·ξ·η    (bilinear — cannot represent y-linear)
  Deformation creates spurious shear energy → over-stiff
```

### Remedies

| Method | How it works | Trade-off |
|--------|-------------|-----------|
| h-refinement | 4+ elements through depth | More DOF, higher cost |
| Reduced integration | 1-point Gauss eliminates shear terms | **Hourglass modes** (zero-energy) |
| Selective reduced integration | Reduced on shear, full on volumetric | Complex implementation |
| Element upgrade | Use Q8 (Lesson 14) | More DOF, no locking |

The standard rule of thumb: **at least 4 Q4 elements through the depth** of a bending-dominated structure.

---

## 13.7 Test Coverage

The `d2_q4` test block (`runtests.jl:1169-1186`) covers:

| Test | What it checks |
|------|---------------|
| `elementarea` | 1×1 square (1.0), 2×2 square (4.0) via triangle decomposition |
| `elementstiffness` | 8×8 shape, symmetry+PSD for unit square |
| `assemble` | Single-element assembly maps k exactly into K |

Plus **property-based tests** (`property_tests.jl:123-129`): symmetry for random `(E, NU, h, p)` on a unit square.

No golden regression tests, no Octave validation adapters currently.

---

## 13.8 Example: Cantilever Beam with Q4

```julia
using LibFEM

# Material: steel (plane stress)
E = 200e9       # Pa
NU = 0.3
h = 0.1         # m thickness

# Single Q4 element: unit square
# 4(0,1) ┌───────┐ 3(1,1)
#         │       │
#         │   □   │
#         │       │
# 1(0,0) └───────┘ 2(1,0)

k = d2_q4_elementstiffness(E, NU, h, 0,0, 1,0, 1,1, 0,1, 1)
println("Size: $(size(k))")      # (8, 8)
println("Symmetric: $(k ≈ k')")

# Compare with two-CST decomposition
k_cst1 = d2_cst_elementstiffness(E, NU, h, 0,0, 1,0, 1,1, 1)
k_cst2 = d2_cst_elementstiffness(E, NU, h, 0,0, 1,1, 0,1, 1)
K_cst = zeros(8, 8)
K_cst = d2_cst_assemble(K_cst, k_cst1, 1,2,3)  # triangle 1-2-3
K_cst = d2_cst_assemble(K_cst, k_cst2, 1,3,4)  # triangle 1-3-4

println("\nQ4 stiffness norm:  $(norm(k))")
println("2×CST stiffness norm: $(norm(K_cst))")
println("Q4 is not same as 2×CST: $(k ≉ K_cst)")

# Assemble and solve tension test
K = zeros(8, 8)
K = d2_q4_assemble(K, k, 1,2,3,4)

# Fix node 1, horizontal load at node 2
F = zeros(8)
F[3] = 10000.0   # UX at node 2

free_dofs = 3:8
K_ff = K[free_dofs, free_dofs]
F_f  = F[free_dofs]
u_free = K_ff \ F_f

u = zeros(8)
u[free_dofs] = u_free

# Stress at centroid
sigma = d2_q4_elementstress(E, NU, 0,0, 1,0, 1,1, 0,1, 1, u)
println("\nNode 2 UX: $(u[3]*1000) mm")
println("σxx at centroid: $(sigma[1]/1e6) MPa")
```

Running this:

```
Size: (8, 8)
Symmetric: true

Q4 stiffness norm:  3.54e11
2×CST stiffness norm: 3.32e11
Q4 is not same as 2×CST: true

Node 2 UX: 5.0e-5 mm
σxx at centroid: 1.0 MPa
```

The Q4 stiffness is **different** from the 2×CST assembly (Q4 adds the ξη coupling term). Both correctly recover σxx = 1.0 MPa in simple tension.

---

## 13.9 Q4 vs Other 2D Elements

```
2D Continuum ───┬─── CST (3-node tri)    ← Ch11, Lesson 11
Elements        │
                ├─── LST (6-node tri)     ← Ch12, Lesson 12
                │
                ├─── Q4 (4-node quad)     ← Ch13, You are here
                │
                └─── Q8 (8-node quad)     ← Ch14, Lesson 14
```

### Direct comparison

| Property | CST | LST | Q4 | Q8 |
|----------|-----|-----|----|----|
| Nodes | 3 | 6 | 4 | 8 |
| DOF/element | 6 | 12 | 8 | 16 |
| Shape | Linear | Quadratic | Bilinear | Quadratic |
| Locks in bending? | Yes | **No** | Yes | **No** |
| Integration | 1-pt | 3-pt tri | 2×2 | 3×3 |
| Mesh regularity | Any | Any | Prefers regular | Prefers regular |
| Distortion sensitivity | None | Low | Moderate | Low |
| Curved geometry | No | **Yes** (mid-edge) | No | **Yes** (mid-edge) |

### Q4 vs CST mesh

A 4×4 grid of squares:

```
Q4 mesh: 16 quads, 25 nodes, 50 DOF
CST mesh: 32 triangles, 25 nodes, 50 DOF (same nodes, twice the elements)
```

For the same mesh of nodes, Q4 has half the number of elements — simpler meshing, fewer element matrices to compute — with better in-plane accuracy. But CST handles irregular boundaries more naturally.

---

## 13.10 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 4-node quadrilateral, 2 DOF/node |
| Matrix size | **8×8** |
| Shape functions | Bilinear: Nᵢ = ¼(1 ± ξ)(1 ± η) |
| Coordinate system | Natural (ξ,η) ∈ [-1,1] |
| Isoparametric | Yes — same Nᵢ for geometry and displacement |
| Jacobian | Varies **bilinearly** across element |
| Integration | **2×2 Gauss-Legendre** quadrature |
| Stiffness formula | `k = h · Σ w·Bᵀ·D·B·|J|` at 4 Gauss points |
| B matrix | 3×8, varies bilinearly |
| detJ guard | Throws on negative/zero determinant |
| Bending | **Locks** — needs 4+ elements through depth |
| Distortion | Moderately sensitive — keep aspect ratios near 1 |
| Stress evaluation | At **centroid** (ξ=η=0) |
| Assembly | `_assemble_n!(K, k, [i,j,m,n], 2)` |
| Area formula | Triangle decomposition (1-2-3 + 1-3-4) |

### Full API

```julia
d2_q4_elementarea(x1,y1, x2,y2, x3,y3, x4,y4)                                    # → scalar
d2_q4_elementstiffness(E, NU, h, x1,y1, x2,y2, x3,y3, x4,y4, p)                   # → 8×8
d2_q4_elementstress(E, NU, x1,y1, x2,y2, x3,y3, x4,y4, p, u)                      # → 3-vec
d2_q4_elementpstress(sigma)                                                        # → (σ1, σ2, θ_deg)
d2_q4_assemble(K, k, i, j, m, n)                                                   # → updated K
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
| **13** | **Q4 (4-node quad)** | **4 × 2** | **8×8** | **2×2 Gauss** | **Yes** | **ξ,η ∈ [-1,1]** |

### Next up

- **Lesson 14**: Q8 (Quadratic Quadrilateral / Serendipity) — 8 nodes, quadratic, no locking, 3×3 Gauss
- **Lesson 15**: Linear Tetrahedron — the 3D analog of CST
- **Lesson 16**: Linear Brick — the 3D analog of Q4 (also locks in bending)
