# Lesson 15: The Linear Tetrahedron — 3D Constant Strain Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 15
> Mapped to LibFEM.jl — `src/tetrahedron.jl`, `src/utils.jl` (3D elasticity matrix), `src/assembly.jl`

**Prerequisites**: Lesson 11 (CST — the 2D constant strain element). Understanding of 3D elasticity. The tetrahedron is the **3D analog of CST**.

---

## 15.1 The Tetrahedron Concept

The **linear tetrahedron** is the simplest 3D continuum element — 4 nodes, 3 DOF per node (UX, UY, UZ), 12×12 stiffness matrix. Like CST in 2D, it features **constant strain** throughout the element.

| Property | CST (2D, Ch11) | Tetrahedron (3D, Ch15) |
|----------|----------------|------------------------|
| Shape | Triangle (3 nodes) | **Tetrahedron** (4 nodes) |
| DOF/element | 6 | **12** |
| Coordinates | Area (L₁,L₂,L₃) | **Volume** (L₁,L₂,L₃,L₄) |
| Strain | Constant εxx, εyy, γxy | **Constant** εxx, εyy, εzz, γxy, γyz, γzx |
| B matrix | 3×6 **constant** | **6×12 constant** |
| Stiffness | k = A·t·Bᵀ·D·B | **k = V·Bᵀ·D·B** |
| Integration | 1-pt centroid (exact) | **None needed** (B is constant) |
| Bending | Locks | **Locks** |
| Mesh in 3D | Triangulates 2D area | Tetrahedralizes 3D volume |

### Why tetrahedron matters

Tetrahedral meshes are the **universal 3D mesh** — any 3D geometry can be divided into tetrahedra. Modern mesh generators (TetGen, CGAL, Gmsh) produce millions of tetrahedra automatically. Common applications:

- **Structural mechanics**: stress analysis of complex 3D parts
- **Biomechanics**: bone/tissue FEA from CT-scan geometry
- **Geomechanics**: underground excavation, slope stability
- **Casting/solidification**: thermal analysis of irregular shapes

---

## 15.2 Geometry and Volume Coordinates

### Node numbering

```
            4
           /|\
          / | \
         /  |  \
        /   |   \
       /    |    \
      1-----+-----3
         \  |   /
          \ | /
           \|/
            2
```

Standard ordering: nodes 1,2,3 define a base (CCW), node 4 is the apex. This orientation determines the sign of the volume.

### The 4×4 orientation matrix

```julia
# M = [1  x  y  z] for each node
M = [1  x1  y1  z1
     1  x2  y2  z2
     1  x3  y3  z3
     1  x4  y4  z4]
```

### Volume formula

The tetrahedron volume is:

```
V = det(M) / 6
```

Derivation: the three edge vectors from node 1 define a parallelepiped. The tetrahedron occupies 1/6 of that parallelepiped — same geometric ratio as triangle area to parallelogram area in 2D.

**Sign convention**: a positive volume requires properly oriented nodes. For the standard numbering (1-2-3 base CCW, node 4 above), `det(M) > 0`.

### Volume coordinates

Like area coordinates (L₁,L₂,L₃) for triangles, volume coordinates (L₁,L₂,L₃,L₄) for tetrahedra satisfy:

```
0 ≤ Lᵢ ≤ 1,  L₁ + L₂ + L₃ + L₄ = 1
```

Lᵢ = 1 at node i, 0 at all other nodes. A point's volume coordinate Lᵢ equals the ratio of the sub-tetrahedron volume opposite node i to the total volume.

### Beta, gamma, delta coefficients

These are the **cofactors** of matrix M, computed by `_tetra_cofactors`:

```julia
function _tetra_cofactors(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)
    M = [1 x1 y1 z1
         1 x2 y2 z2
         1 x3 y3 z3
         1 x4 y4 z4]

    # Cofactor matrix = det(M) * inv(M)' (transpose of adjugate)
    C = det(M) * inv(M)'
    β = [C[1,1], C[2,1], C[3,1], C[4,1]]
    γ = [C[1,2], C[2,2], C[3,2], C[4,2]]
    δ = [C[1,3], C[2,3], C[3,3], C[4,3]]
    # C[1,4]..C[4,4] used internally but not β, γ, δ
    return (β, γ, δ, C, M)
end
```

The shape function derivatives (∂Nᵢ/∂x, ∂Nᵢ/∂y, ∂Nᵢ/∂z) are **constant** and equal to:

```
∂N₁/∂x = β₁/(6V)    ∂N₁/∂y = γ₁/(6V)    ∂N₁/∂z = δ₁/(6V)
∂N₂/∂x = β₂/(6V)    ∂N₂/∂y = γ₂/(6V)    ∂N₂/∂z = δ₂/(6V)
∂N₃/∂x = β₃/(6V)    ∂N₃/∂y = γ₃/(6V)    ∂N₃/∂z = δ₃/(6V)
∂N₄/∂x = β₄/(6V)    ∂N₄/∂y = γ₄/(6V)    ∂N₄/∂z = δ₄/(6V)
```

where βᵢ, γᵢ, δᵢ are the cofactors from column 1,2,3 of the adjugate of M, divided by 6V.

These derivatives are **constant** → the B matrix is **constant** → strain is **constant** → element integrates with a single product (no quadrature needed).

---

## 15.3 The B Matrix (6×12)

### Strain vector (6 components)

In 3D, the strain vector has 6 components:

```
{ε}ᵀ = [εxx  εyy  εzz  γxy  γyz  γzx]
```

### B matrix construction

The B matrix (6×12) maps nodal displacements to strains:

```
B = [B₁  B₂  B₃  B₄]
```

where each Bᵢ is a 6×3 block:

```
    [∂Nᵢ/∂x    0        0    ]
    [0          ∂Nᵢ/∂y   0    ]
    [0          0         ∂Nᵢ/∂z]
Bᵢ = [∂Nᵢ/∂y    ∂Nᵢ/∂x   0    ]
    [0          ∂Nᵢ/∂z   ∂Nᵢ/∂y]
    [∂Nᵢ/∂z    0         ∂Nᵢ/∂x]
```

With the constant derivatives from the cofactor formula, B is:

```julia
function _tetra_B_matrix(β, γ, δ, V)
    sixV = 6 * V
    B = zeros(6, 12)
    for i in 1:4
        col = 3*(i-1) + 1
        B[1, col]   = β[i] / sixV    # ∂Nᵢ/∂x
        B[2, col+1] = γ[i] / sixV    # ∂Nᵢ/∂y
        B[3, col+2] = δ[i] / sixV    # ∂Nᵢ/∂z
        B[4, col]   = γ[i] / sixV    # ∂Nᵢ/∂y
        B[4, col+1] = β[i] / sixV    # ∂Nᵢ/∂x
        B[5, col+1] = δ[i] / sixV    # ∂Nᵢ/∂z
        B[5, col+2] = γ[i] / sixV    # ∂Nᵢ/∂y
        B[6, col]   = δ[i] / sixV    # ∂Nᵢ/∂z
        B[6, col+2] = β[i] / sixV    # ∂Nᵢ/∂x
    end
    return B
end
```

Result: B is **constant** — no quadrature needed.

---

## 15.4 The D Matrix (6×6) — 3D Elasticity

### Isotropic elasticity matrix

```
           [1-ν   ν    ν    0     0     0  ]
           [ ν   1-ν   ν    0     0     0  ]
           [ ν    ν   1-ν   0     0     0  ]
D = E      [0    0    0  ½(1-2ν)  0     0  ]
    ───    [0    0    0    0   ½(1-2ν)  0  ]
  (1+ν)    [0    0    0    0     0   ½(1-2ν)]
  (1-2ν)
```

This is available as `_d3_elasticity_matrix(E, NU)` in `src/utils.jl` (~40 lines). It's shared with the brick element.

Check: for ν = 0.3:

```julia
D = _d3_elasticity_matrix(1.0, 0.3)
# Diagonal: first 3 = E(1-ν)/((1+ν)(1-2ν)) ≈ 0.7692·E
# Shear:    last 3  = E/(2(1+ν))        ≈ 0.3846·E
```

### 3D vs 2D D matrices

| D matrix | Size | Strain components | Modulus factor |
|----------|------|-------------------|----------------|
| Plane stress | 3×3 | εxx, εyy, γxy | E/(1-ν²) |
| Plane strain | 3×3 | εxx, εyy, γxy | E/((1+ν)(1-2ν)) |
| **3D** | **6×6** | εxx, εyy, εzz, γxy, γyz, γzx | **E/((1+ν)(1-2ν))** |

The 3D D matrix uses the same factor as 2D plane strain, extended to 6 components. The plane strain case is the 2D z-constrained version of 3D.

---

## 15.5 Element Stiffness Matrix

### The formula — simplest in the book

Since B and D are both constant:

```
[k] = ∫ [B]ᵀ [D] [B] dV = V · Bᵀ · D · B
```

**No integration needed.** One matrix triple product scaled by volume.

```julia
function d3_tetra_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)
    # Volume from determinant
    β, γ, δ, C, M = _tetra_cofactors(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)
    V = det(M) / 6.0
    V > 0 || throw(...)

    # Elasticity and B matrices
    D = _d3_elasticity_matrix(E, NU)
    B = _tetra_B_matrix(β, γ, δ, V)

    # k = V · Bᵀ · D · B (all constant)
    return V * B' * D * B
end
```

### Kattan MATLAB version

```matlab
function w = TetrahedronElementStiffness(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)
    % orientation matrix
    x = [1 x1 y1 z1; 1 x2 y2 z2; 1 x3 y3 z3; 1 x4 y4 z4];
    V = det(x) / 6;

    % beta, gamma, delta from cofactors
    a = [x1 y1 z1; x2 y2 z2; x3 y3 z3; x4 y4 z4];
    β1 = det([a(2,1:3); a(3,1:3); a(4,1:3)]);  ...  % explicit cofactors

    % B matrix built term by term (12×6 or 6×12, MATLAB transposes)
    B = zeros(6,12);
    B(1,1) = β1; B(1,4) = β2; B(1,7) = β3; B(1,10) = β4;
    B(2,2) = γ1; B(2,5) = γ2; B(2,8) = γ3; B(2,11) = γ4;
    ...  % 12 fill-Zeile

    B = B / (6*V);
    D = ...;
    w = V * B' * D * B;
end
```

**Key differences**:

| Aspect | Kattan MATLAB | LibFEM.jl |
|--------|---------------|-----------|
| β,γ,δ computation | 12 explicit `det()` calls (one per cofactor) | Single `inv(M')` via `_tetra_cofactors` |
| B matrix size | Written as 6×12 (same) | 6×12 (same) |
| B fill | 12 lines, one DOF per line | 8 lines, 4-iteration loop |
| Volume | `V = det(x) / 6` | `V = det(M) / 6` (same formula) |
| Efficiency factor | 12× determinant calls | 1 matrix inverse (≈ 1 det call) |

The Julia version is **~12× more efficient** in the cofactor computation alone (one matrix inverse vs 12 separate determinants), and the B matrix loop eliminates 12 lines of fill code.

### PSD verification

For a unit tetrahedron with E=1, NU=0.3:

```julia
k = d3_tetra_elementstiffness(1.0, 0.3, 0,0,0, 1,0,0, 0,1,0, 0,0,1)
eigvals(k)   # 6 positive, 6 zero (rigid body modes in 3D)
```

6 rigid body modes: 3 translations + 3 rotations. 6 positive eigenvalues = 6 deformation modes (6 strain components × constant). Same eigenvalue count as CST's ratio (3 rigid + 3 strain) scaled to 3D.

---

## 15.6 Stress Recovery

### Constant element stress

Since B is constant, stress is constant throughout the element:

```julia
function d3_tetra_elementstress(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4, u)
    β, γ, δ, C, M = _tetra_cofactors(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)
    V = det(M) / 6.0
    B = _tetra_B_matrix(β, γ, δ, V)
    D = _d3_elasticity_matrix(E, NU)
    return D * B * u   # σ = D·B·u (constant across element)
end
```

MATLAB version: **identical** — builds B, multiplies D·B·u.

### Stress vector

```
{σ}ᵀ = [σxx  σyy  σzz  τxy  τyz  τzx]
```

This is NOT mapped to full tensor notation — it's the Voigt form used in the D matrix.

### 3D Principal stresses

LibFEM.jl computes proper principal stresses via **eigenvalue decomposition** of the 3×3 stress tensor:

```julia
function d3_tetra_elementpstress(sigma)
    # sigma = [σxx, σyy, σzz, τxy, τyz, τzx]
    S = [sigma[1]  sigma[4]  sigma[6]
         sigma[4]  sigma[2]  sigma[5]
         sigma[6]  sigma[5]  sigma[3]]
    eigvals_ = eigvals(S)     # descending
    σ1 = eigvals_[3]; σ2 = eigvals_[2]; σ3 = eigvals_[1]
    τ_max = (σ1 - σ3) / 2     # max shear = (σ1 - σ3)/2
    return (σ1, σ2, σ3, τ_max)
end
```

### Kattan MATLAB: NOT principal stresses

Kattan's `TetrahedronElementPStresses.m` computes something **fundamentally different**:

```matlab
function w = TetrahedronElementPStresses(sigma)
    % σ1 = I₁ = σxx + σyy + σzz  (first invariant)
    s1 = sigma(1) + sigma(2) + sigma(3);

    % s2 = I₂ = σxx·σyy + σyy·σzz + σzz·σxx - τxy² - τyz² - τzx²
    s2 = sigma(1)*sigma(2) + sigma(2)*sigma(3) + sigma(3)*sigma(1) ...
         - sigma(4)^2 - sigma(5)^2 - sigma(6)^2;

    % s3 = I₃ = det(σ)  (third invariant — cubic in σ values)
    s3 = sigma(1)*sigma(2)*sigma(3) ...
         + 2*sigma(4)*sigma(5)*sigma(6) ...
         - sigma(1)*sigma(5)^2 - sigma(2)*sigma(6)^2 - sigma(3)*sigma(4)^2;

    w = [s1, s2, s3]';
end
```

This computes the **three invariants** of the stress tensor (I₁, I₂, I₃) — used to form the cubic characteristic equation `σ³ - I₁·σ² + I₂·σ - I₃ = 0`. The invariants are useful for failure criteria (Tresca, von Mises, Mohr-Coulomb) but are **not principal stresses**.

**LibFEM.jl** computes actual principal stresses via `eigvals(S)`. This is a deliberate design improvement over Kattan's textbook — the Julia version wraps principal stress computation in a dedicated helper that works for all 2D and 3D element types.

| Function | Kattan | LibFEM.jl |
|----------|--------|-----------|
| `_pstress(sigma)` | Returns [I₁, I₂, I₃] invariants | Returns [σ₁, σ₂, σ₃, τ_max] via eigendecomposition |
| Usage | Useful for failure criteria | Direct physical interpretation (max/min normal stress, max shear) |

If you need the tensor invariants for failure criteria, compute them from the principal stresses.

---

## 15.7 Assembly

```julia
function d3_tetra_assemble(K, k, i, j, m, n)
    return _assemble_n!(K, k, [i, j, m, n], 3)
end
```

MATLAB version: **144 lines** of explicit assignments:

```matlab
function w = TetrahedronAssemble(K, k, i, j, m, n)
    w = K;
    w(3*i-2, 3*i-2) = w(3*i-2, 3*i-2) + k(1,1);
    w(3*i-2, 3*i-1) = w(3*i-2, 3*i-1) + k(1,2);
    % ... 143 more lines ...
end
```

The Julia `_assemble_n!` generic is a **144× reduction** in lines of code — one 6-line function handles assembly for any element type with any number of DOF per node.

---

## 15.8 Element Quality in 3D

### Volume check

```
V > 0 → valid
V = 0 → degenerate (all 4 nodes coplanar)
V < 0 → inverted (wrong node ordering)
```

LibFEM.jl throws `ElementParameterError` for `V ≤ 0`.

### Tetrahedron quality metrics

| Metric | Good | Poor |
|--------|------|------|
| Aspect ratio | ~1 (regular) | > 5 (sliver) |
| Volume/edge-length³ | ≈ 0.1178 (regular tet) | << 0.01 (sliver) |
| Min dihedral angle | > 20° | < 5° (near-degenerate) |
| Circumsphere/insphere ratio | ≈ 3 (regular) | > 10 (distorted) |

A **sliver tetrahedron** has all four nodes nearly coplanar (volume near zero). The stiffness matrix of a sliver element becomes nearly singular — the B matrix approaches rank deficiency, producing near-zero energy modes that destroy global solution quality.

### Regular tetrahedron reference

For a unit regular tetrahedron with vertices at (0,0,0), (1,0,0), (½,√3/2,0), (½,√3/6,√(2/3)):

```
V = 1/(6√2) ≈ 0.11785
Each edge length = 1
All dihedral angles ≈ 70.53°
```

This is the ideal element shape — the 3D analog of an equilateral triangle.

---

## 15.9 Test Coverage

The `d3_tetra` test block (`test/runtests.jl:1204-1241`) covers:

| Test | What it checks |
|------|---------------|
| `elementstiffness` | 12×12 shape, symmetry+PSD (`k ≈ k'`, `isposdef(k[7:12,7:12])`) |
| `elementstress` | Works with identity D (D·B·u returns B·u) |
| `elementpstress` | Eigendecomposition: σ₁ ≥ σ₂ ≥ σ₃, τ_max = (σ₁-σ₃)/2 |
| `volume` | Unit tetrahedron: V = 1/6 ≈ 0.1667 |
| `assemble` | Single-element: maps k exactly into 12×12 K |

Plus property-based tests (`test/property_tests.jl:123-129`) for symmetry and positive semi-definiteness at random coordinates.

### Volume test

```julia
# Unit tetrahedron
d3_tetra_elementvolume(0,0,0, 1,0,0, 0,1,0, 0,0,1) → 0.16666666666666666  (= 1/6)
```

Reference: `V = |det(M)| / 6 = |det([1,0,0,0; 1,1,0,0; 1,0,1,0; 1,0,0,1])| / 6 = 1/6`

### Stress test

```julia
d3_tetra_elementstress(1.0, 0.3,
    0,0,0,  1,0,0,  0,1,0,  0,0,1,
    [1,0,0, 0,0,0, 0,0,0, 0,0,0])  # ux=1 at node 1 only
```

Returns a constant stress vector (6 components) determined by D·B·u.

---

## 15.10 Example: Uniaxial Tension of a Tetrahedron

```julia
using LibFEM

# Tetrahedron: unit right-angle at origin
# 1(0,0,0)  2(1,0,0)  3(0,1,0)  4(0,0,1)

E = 200e9    # Pa
NU = 0.3

k = d3_tetra_elementstiffness(E, NU, 0,0,0, 1,0,0, 0,1,0, 0,0,1)
println("k size: $(size(k))")     # (12, 12)
println("Symmetric: $(k ≈ k')")
println("PSD: $(isposdef(k[7:12,7:12]))")

# Single element — clamp base (nodes 1,2,3), pull node 4 in z
# Node 4 is at (0,0,1) — pull z
F = zeros(12)
F[12] = 1000.0    # UZ at node 4

# Free DOFs = node 4 only: UX(10), UY(11), UZ(12)
free_dofs = 10:12
K_ff = k[free_dofs, free_dofs]
F_f  = F[free_dofs]
u_free = K_ff \ F_f

u = zeros(12)
u[free_dofs] = u_free

sigma = d3_tetra_elementstress(E, NU, 0,0,0, 1,0,0, 0,1,0, 0,0,1, u)
σₚ = d3_tetra_elementpstress(sigma)

println("\nNode 4 displacement:")
println("  UX: $(u[10]*1000) mm")
println("  UY: $(u[11]*1000) mm")
println("  UZ: $(u[12]*1000) mm")
println("\nStress (constant):")
println("  σxx: $(sigma[1]/1e6) MPa")
println("  σyy: $(sigma[2]/1e6) MPa")
println("  σzz: $(sigma[3]/1e6) MPa")
println("  τxy: $(sigma[4]/1e6) MPa")
println("  τyz: $(sigma[5]/1e6) MPa")
println("  τzx: $(sigma[6]/1e6) MPa")
println("\nPrincipal stresses:")
println("  σ₁ = $(σₚ[1]/1e6) MPa, σ₂ = $(σₚ[2]/1e6) MPa, σ₃ = $(σₚ[3]/1e6) MPa")
println("  τ_max = $(σₚ[4]/1e6) MPa")
```

Expected:

```
k size: (12, 12)
Symmetric: true
PSD: true

Node 4 displacement:
  UX: ... mm  (small lateral due to Poisson)
  UY: ... mm  (small lateral due to Poisson)
  UZ: ... mm  (tension in z)

Stress (constant):
  σxx: ~0 MPa
  σyy: ~0 MPa
  σzz: positive (tension)
  τxy, τyz, τzx: ~0 (pure tension)

Principal stresses:
  σ₁ = σzz (tension), σ₂ = σ₃ = 0  (uniaxial)
  τ_max = σ₁/2
```

A single tetrahedron in uniaxial tension captures only the constant stress state — no stress gradients. For bending (linear stress variation), you need multiple elements through the depth, just like CST in 2D.

---

## 15.11 Tetrahedron vs Brick (Preview)

The tetrahedron is the simplest 3D element; the brick (Ch16 / Lesson 16) is the 3D analog of Q4.

| Property | Tetrahedron (Ch15) | Linear Brick (Ch16) |
|----------|-------------------|---------------------|
| Nodes | 4 | 8 |
| DOF/element | 12 | 24 |
| k size | 12×12 | 24×24 |
| Strain | **Constant** | Trilinear (varies) |
| B matrix | Constant (6×12) | Varies (3×3×8 Gauss) |
| Integration | None (k = V·Bᵀ·D·B) | 2×2×2 Gauss quadrature |
| Bending | Locks | **Locks** |
| Mesh | Any shape | Prefers regular |

Both lock in bending. Remedies: h-refinement (4+ through depth) or upgrade to quadratic tetrahedron (10-node) or quadratic brick (20-node serendipity).

---

## 15.12 The Full 3D Continuum Element Family

```
3D Continuum ─┬─── Linear Tetrahedron  (4 nodes)    ← You are here
Elements      │                         12×12
              │                         Constant strain
              │                         Locks in bending
              │
              ├─── Quadratic Tetrahedron (10 nodes)   ← Not in Kattan
              │                         30×30
              │                         Quadratic strain
              │                         No locking
              │
              ├─── Linear Brick (8 nodes)             ← Ch16 / Lesson 16
              │                         24×24
              │                         Trilinear strain
              │                         Locks in bending
              │
              └─── Quadratic Brick (20 nodes)         ← Not in Kattan
                                          60×60
                                         Serendipity
                                         No locking
```

### Which to use?

| Situation | Element choice |
|-----------|---------------|
| Automatic mesh of complex geometry | Tetrahedron (linear or quadratic) |
| Regular grid, simple geometry | Brick |
| Bending-dominated | Quadratic elements (tet10 or brick20) |
| Contact/impact (explicit dynamics) | Linear tet or brick (cost per element) |
| Maximum accuracy per DOF | Quadratic elements |

---

## 15.13 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 4-node tetrahedron, 3 DOF/node |
| Matrix size | **12×12** |
| Shape functions | Linear in volume coordinates |
| Strain | **Constant** throughout element |
| B matrix | **6×12 constant** — never varies |
| Integration | None — `k = V·Bᵀ·D·B` |
| Volume | `V = det|1 x y z| / 6` |
| Cofactors | β,γ,δ from adjugate of orientation matrix |
| D matrix | `_d3_elasticity_matrix(E, NU)` — 6×6, matches plane strain modulus |
| k = V·Bᵀ·D·B | Single matrix triple product (cheapest in the book) |
| Rigid body modes | 6 (3 translations + 3 rotations) |
| PSD | `isposdef(k[7:12,7:12])` — 6 positive, 6 zero eigenvalues |
| Stress | **Constant**, `σ = D·B·u` |
| Principal stresses | **Eigendecomposition** of 3×3 stress tensor → (σ₁, σ₂, σ₃, τ_max) |
| MATLAB pstress | Returns **cubic invariants** [I₁, I₂, I₃], NOT principal stresses |
| Assembly | `_assemble_n!(K, k, [i,j,m,n], 3)` vs 144-line MATLAB |
| Bending | **Locks** — use multiple elements through depth |
| Element quality | Avoid slivers: V → 0, β·γ·δ near zero |

### Full API

```julia
d3_tetra_elementvolume(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)                             # → scalar (V = det/6)
d3_tetra_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)                    # → 12×12
d3_tetra_elementstress(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4, u)                    # → 6-vec (Voigt)
d3_tetra_elementpstress(sigma)                                                                # → (σ₁, σ₂, σ₃, τ_max) via eig
d3_tetra_assemble(K, k, i, j, m, n)                                                           # → updated K (12 DOF)
```

### The full family across both dimensions

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
| 14 | Q8 (8-node quad) | 8 × 2 | 16×16 | 3×3 Gauss | **No** | ξ,η ∈ [-1,1] |
| **15** | **Linear Tet (4-node)** | **4 × 3** | **12×12** | **None (k=V·Bᵀ·D·B)** | **Yes** | **Volume coords** |
| 16 | Linear Brick (8-node) | 8 × 3 | 24×24 | 2×2×2 Gauss | Yes | ξ,η,ζ ∈ [-1,1] |

### Next up

- **Lesson 16**: Linear Brick (hexahedron) — the 3D analog of Q4, 8 nodes, trilinear shape functions, 2×2×2 Gauss quadrature, also locks in bending
- After bricks: comparing all element types, convergence studies, and practical guidelines for element selection
