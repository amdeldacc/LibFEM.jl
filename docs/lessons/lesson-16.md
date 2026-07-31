# Lesson 16: The Linear Brick — 3D Trilinear Hexahedron

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 16
> Mapped to LibFEM.jl — `src/brick.jl`, `src/utils.jl` (3D elasticity matrix), `src/assembly.jl`

**Prerequisites**: Lesson 13 (Q4 — bilinear quadrilateral, strong analogies throughout). Lesson 15 (tetrahedron — shared D matrix and principal stress routines).

---

## 16.1 The Brick Concept

The **linear brick** (8-node hexahedron) is the 3D analog of the Q4 quadrilateral. It uses **trilinear** shape functions in natural coordinates `ξ,η,ζ ∈ [-1,1]`.

| Property | Q4 (2D, Ch13) | Brick (3D, Ch16) |
|----------|---------------|-------------------|
| Shape | Quadrilateral (4 nodes) | **Hexahedron** (8 nodes) |
| DOF/element | 8 | **24** |
| Shape functions | Bilinear: ¼(1±ξ)(1±η) | **Trilinear**: ⅛(1±ξ)(1±η)(1±ζ) |
| Natural coords | ξ,η ∈ [-1,1] | ξ,η,ζ ∈ [-1,1] |
| Strain | εxx, εyy, γxy | εxx, εyy, εzz, γxy, γyz, γzx |
| B matrix | 3×8, varies bilinearly | **6×24**, varies trilinearly |
| D matrix | 3×3 (plane stress/strain) | **6×6** (3D elasticity) |
| Integration | **2×2 Gauss** | **2×2×2 Gauss** |
| Bending | **Locks** | **Locks** |
| Jacobian | 2×2, varies bilinearly | 3×3, varies trilinearly |

### Why brick matters

The brick is the **workhorse 3D element** for structured meshes:
- Simple to generate from 3D grids (voxel-like)
- Better accuracy per DOF than tetrahedra for regular shapes
- Trilinear shape functions give linear stress variation (vs constant strain in tetrahedron)
- Standard element in explicit dynamics (with reduced integration + hourglass control)

---

## 16.2 Node Ordering and Geometry

### Julia convention (bottom-face-first)

```
    ζ (up)
    │
    4───────8
   ╱│      ╱│
  1───────5 │   Top face (ζ=+1): 5,6,7,8 CCW
  │ │     │ │   Bottom face (ζ=-1): 1,2,3,4 CCW
  │ 3─────│─7
  ╱       ╱
 2───────6    → η

 ↓ ξ
```

Julia's convention: **bottom face first (ζ=-1), then top (ζ=+1)**. Each face CCW when viewed from outside. This matches the Q4 convention extended to 3D.

```
Node 1: (ξ, η, ζ) = (-1, -1, -1)    Node 5: (-1, -1, +1)
Node 2: (+1, -1, -1)                Node 6: (+1, -1, +1)
Node 3: (+1, +1, -1)                Node 7: (+1, +1, +1)
Node 4: (-1, +1, -1)                Node 8: (-1, +1, +1)
```

### Kattan MATLAB convention (s-face-first)

Kattan's `LinearBrickElementStiffness.m` uses the same 8 trilinear shape functions but with a **different node-to-coord mapping**:

```
MATLAB formula              Natural coords (s,t,u)
──────────────────────────────────────────────────
N1 = (1-s)(1-t)(1+u)/8  →  s=-1, t=-1, u=+1
N2 = (1-s)(1-t)(1-u)/8  →  s=-1, t=-1, u=-1
N3 = (1-s)(1+t)(1-u)/8  →  s=-1, t=+1, u=-1
N4 = (1-s)(1+t)(1+u)/8  →  s=-1, t=+1, u=+1
N5 = (1+s)(1-t)(1+u)/8  →  s=+1, t=-1, u=+1
N6 = (1+s)(1-t)(1-u)/8  →  s=+1, t=-1, u=-1
N7 = (1+s)(1+t)(1-u)/8  →  s=+1, t=+1, u=-1
N8 = (1+s)(1+t)(1+u)/8  →  s=+1, t=+1, u=+1
```

Kattan groups nodes by s-face: the **s=-1 face** contains nodes 1,2,3,4 and the **s=+1 face** contains nodes 5,6,7,8. Each face mixes ζ=±1 nodes (u in MATLAB's convention).

**Important**: The set of shape functions is identical; only node numbering differs. Both produce the same stiffness values — just permuted to different row/column positions. The Julia ordering (bottom/top in ζ) is more intuitive for structural meshes.

---

## 16.3 Trilinear Shape Functions

### Reference hexahedron: [-1,1] × [-1,1] × [-1,1]

Each shape function is a product of three 1D linear functions:

```julia
N1 = (1-ξ)(1-η)(1-ζ)/8    # Node 1: (-1,-1,-1)
N2 = (1+ξ)(1-η)(1-ζ)/8    # Node 2: (+1,-1,-1)
N3 = (1+ξ)(1+η)(1-ζ)/8    # Node 3: (+1,+1,-1)
N4 = (1-ξ)(1+η)(1-ζ)/8    # Node 4: (-1,+1,-1)
N5 = (1-ξ)(1-η)(1+ζ)/8    # Node 5: (-1,-1,+1)
N6 = (1+ξ)(1-η)(1+ζ)/8    # Node 6: (+1,-1,+1)
N7 = (1+ξ)(1+η)(1+ζ)/8    # Node 7: (+1,+1,+1)
N8 = (1-ξ)(1+η)(1+ζ)/8    # Node 8: (-1,+1,+1)
```

Compact form: `Nᵢ = ⅛(1 + ξᵢ·ξ)(1 + ηᵢ·η)(1 + ζᵢ·ζ)` where (ξᵢ,ηᵢ,ζᵢ) is node i's natural coordinate (±1 each).

Property: Nᵢ = 1 at node i, 0 at all other nodes. Each edge has a linear variation.

### Derivative table (in natural coordinates)

`∂Nᵢ/∂ξ = ξᵢ(1 + ηᵢ·η)(1 + ζᵢ·ζ) / 8`
`∂Nᵢ/∂η = ηᵢ(1 + ξᵢ·ξ)(1 + ζᵢ·ζ) / 8`
`∂Nᵢ/∂ζ = ζᵢ(1 + ξᵢ·ξ)(1 + ηᵢ·η) / 8`

Or explicitly for node 1 (ξ₁=-1, η₁=-1, ζ₁=-1):

```
∂N₁/∂ξ = -(1-η)(1-ζ)/8
∂N₁/∂η = -(1-ξ)(1-ζ)/8
∂N₁/∂ζ = -(1-ξ)(1-η)/8
```

The full 8-node derivative table is computed by `_brick_dN(s, t, u)` returning a 3×8 matrix:

```julia
@inline function _brick_dN(s, t, u)
    dN = zeros(3, 8)
    # Row 1: ∂Nₐ/∂ξ   Row 2: ∂Nₐ/∂η   Row 3: ∂Nₐ/∂ζ
    dN[1, 1] = -(1 - t) * (1 - u) / 8    # ∂N₁/∂ξ
    dN[2, 1] = -(1 - s) * (1 - u) / 8    # ∂N₁/∂η
    dN[3, 1] = -(1 - s) * (1 - t) / 8    # ∂N₁/∂ζ
    # ... and so on for nodes 2-8
    return dN
end
```

---

## 16.4 Isoparametric Mapping and Jacobian

### Mapping

The same shape functions map geometry and displacements:

```
x(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·xᵢ     u(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·uᵢ
y(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·yᵢ     v(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·vᵢ
z(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·zᵢ     w(ξ,η,ζ) = Σ Nᵢ(ξ,η,ζ)·wᵢ
```

### Jacobian (3×3)

```julia
@inline function _brick_jacobian(dN, x, y, z)
    J = zeros(3, 3)
    for a in 1:8
        J[1, 1] += dN[1, a] * x[a]    # ∂x/∂ξ
        J[1, 2] += dN[1, a] * y[a]    # ∂y/∂ξ
        J[1, 3] += dN[1, a] * z[a]    # ∂z/∂ξ
        J[2, 1] += dN[2, a] * x[a]    # ∂x/∂η
        J[2, 2] += dN[2, a] * y[a]    # ∂y/∂η
        J[2, 3] += dN[2, a] * z[a]    # ∂z/∂η
        J[3, 1] += dN[3, a] * x[a]    # ∂x/∂ζ
        J[3, 2] += dN[3, a] * y[a]    # ∂y/∂ζ
        J[3, 3] += dN[3, a] * z[a]    # ∂z/∂ζ
    end
    return J
end
```

The Jacobian varies **trilinearly** across the element (like Q4's bilinear Jacobian in 2D).

### Jacobian determinant

For the stiffness integration, |J(ξ,η,ζ)| maps differential volumes:

```
dx·dy·dz = |J(ξ,η,ζ)| dξ·dη·dζ
```

For a regular (axis-aligned) brick of dimensions a×b×c:

```
J = diag(a/2, b/2, c/2),  |J| = abc/8 = V/8 (constant throughout)
```

For a general hexahedron, |J| varies with position.

### Physical derivatives

Obtained via the inverse Jacobian:

```
[∂/∂x]     [∂/∂ξ]
[∂/∂y] = J⁻¹·[∂/∂η]
[∂/∂z]     [∂/∂ζ]
```

Or in matrix form: `dNx = invJ * dN` where dNx is 3×8 (rows = ∂/∂x, ∂/∂y, ∂/∂z), computed in Julia as:

```julia
invJ = LinearAlgebra.inv(J)
dNx = invJ * dN  # 3×8: physical shape function derivatives
```

### Volume computation

Volume is computed from the Jacobian determinant at the centroid:

```julia
function d3_brick_elementvolume(x1,y1,z1, ..., x8,y8,z8)
    dN = _brick_dN(0.0, 0.0, 0.0)
    J = _brick_jacobian(dN, x, y, z)
    return 8.0 * det(J)
end
```

Formula: `V = ∫|J|dξ·dη·dζ ≈ 8·|J(0,0,0)|`

This is exact for parallelepipeds (|J| constant) and approximate for general hexahedra.

### Kattan MATLAB volume

MATLAB computes volume via **symbolic triple integration** of the Jacobian determinant:

```matlab
syms s t u;
N1 = (1-s)*(1-t)*(1+u)/8;  % ... all 8 shape functions
x = N1*x1 + ... + N8*x8;   y = N1*y1 + ... + N8*y8;   z = N1*z1 + ... + N8*z8;
J = xs*(yt*zu - zt*yu) - ys*(xt*zu - zt*xu) + zs*(xt*yu - yt*xu);
r = int(int(int(J, u, -1, 1), t, -1, 1), s, -1, 1);
w = double(r);
```

| Aspect | Julia | MATLAB |
|--------|-------|--------|
| Method | 1-point centroid quadrature | Symbolic triple integration |
| Exact for | Parallelepipeds | Any hexahedron (in exact arithmetic) |
| Speed | Instant (1 det eval) | Slow (symbolic) |
| General hex | Approximate | Exact |

Julia trades exactness for speed: `V = 8·J(0,0,0)` is exact for parallelepipeds and sufficient for well-shaped hexahedra. MATLAB's symbolic approach is exact but impractical for large meshes.

---

## 16.5 The B Matrix (6×24)

### Strain vector (6 components, same as tetrahedron)

```
{ε}ᵀ = [εxx  εyy  εzz  γxy  γyz  γzx]
```

### B matrix construction

The B matrix (6×24) maps 24 nodal displacements to the 6 strain components:

```
B = [B₁  B₂  B₃  B₄  B₅  B₆  B₇  B₈]
```

Each Bᵢ is a 6×3 block (same structure as tetrahedron):

```
    [∂Nᵢ/∂x    0        0    ]
    [0          ∂Nᵢ/∂y   0    ]
    [0          0         ∂Nᵢ/∂z]
Bᵢ = [∂Nᵢ/∂y    ∂Nᵢ/∂x   0    ]
    [0          ∂Nᵢ/∂z   ∂Nᵢ/∂y]
    [∂Nᵢ/∂z    0         ∂Nᵢ/∂x]
```

In Julia (`brick.jl:161-173`):

```julia
B = zeros(6, 24)
@views for a in 1:8
    col = (a - 1) * 3 + 1
    B[1, col]     = dNx[1, a]    # ∂Nₐ/∂x
    B[2, col + 1] = dNx[2, a]    # ∂Nₐ/∂y
    B[3, col + 2] = dNx[3, a]    # ∂Nₐ/∂z
    B[4, col]     = dNx[2, a]    # ∂Nₐ/∂y
    B[4, col + 1] = dNx[1, a]    # ∂Nₐ/∂x
    B[5, col + 1] = dNx[3, a]    # ∂Nₐ/∂z
    B[5, col + 2] = dNx[2, a]    # ∂Nₐ/∂y
    B[6, col]     = dNx[3, a]    # ∂Nₐ/∂z
    B[6, col + 2] = dNx[1, a]    # ∂Nₐ/∂x
end
```

**Contrast**: For the tetrahedron, B is constant (6×12). For the brick, B varies **trilinearly** with (ξ,η,ζ) — requiring 8 Gauss points for accurate integration, just like Q4 requires 4 Gauss points.

### Kattan MATLAB B matrix

MATLAB builds the B matrix with a **different convention** — it uses the symbolic derivative expressions directly (before dividing by J):

```matlab
% N1x through N8x are ∂N/∂x * J (without dividing by J yet)
B = [N1x N2x ... N8x  0 ... 0 ...  0 ... 0 ;
     0 ... 0  N1y ... N8y  0 ... 0 ;
     ...
     N1z ... N8z  0 ... 0  N1x ... N8x];
Bfinal = Bnew / Jnew;  % divide by J at the end
```

The DIVISION by J at the end is the key difference from the tetrahedron approach. This is MATLAB's workaround for symbolic B *before* the chain rule is applied. Julia computes ∂N/∂x directly via `invJ * dN`, which is clearer and avoids the division.

---

## 16.6 The D Matrix (6×6) — 3D Elasticity

Same as the tetrahedron — both share `_d3_elasticity_matrix(E, NU)`:

```
           [1-ν   ν    ν    0     0     0  ]
           [ ν   1-ν   ν    0     0     0  ]
           [ ν    ν   1-ν   0     0     0  ]
D = E      [0    0    0  ½(1-2ν)  0     0  ]
    ───    [0    0    0    0   ½(1-2ν)  0  ]
  (1+ν)    [0    0    0    0     0   ½(1-2ν)]
  (1-2ν)
```

See Lesson 15 (Section 15.4) for the full details. Only the isotropic 3D elasticity matrix is implemented — anisotropic brick would require a user-supplied D.

---

## 16.7 Element Stiffness Matrix

### Formula

```
[k] = ∫_{-1}^{1}∫_{-1}^{1}∫_{-1}^{1} B(ξ,η,ζ)ᵀ · D · B(ξ,η,ζ) · |J(ξ,η,ζ)| dξ dη dζ
```

### 2×2×2 Gauss quadrature (8 points)

Evaluated numerically:

```
k ≈ Σ_{i=1}^{2} Σ_{j=1}^{2} Σ_{k=1}^{2}
      B(ξᵢ,ηⱼ,ζₖ)ᵀ · D · B(ξᵢ,ηⱼ,ζₖ) · |J(ξᵢ,ηⱼ,ζₖ)| · wᵢ·wⱼ·wₖ
```

### Gauss points

```
i  ξᵢ        ηⱼ        ζₖ        w
─────────────────────────────────────
1  −1/√3     −1/√3     −1/√3     1
2  +1/√3     −1/√3     −1/√3     1
3  +1/√3     +1/√3     −1/√3     1
4  −1/√3     +1/√3     −1/√3     1
5  −1/√3     −1/√3     +1/√3     1
6  +1/√3     −1/√3     +1/√3     1
7  +1/√3     +1/√3     +1/√3     1
8  −1/√3     +1/√3     +1/√3     1
```

Each weight is 1 (product of three 1D weights, each = 1).

### Julia implementation

```julia
function d3_brick_elementstiffness(E, NU, x1,y1,z1, ..., x8,y8,z8)
    x = [x1,...,x8]; y = [y1,...,y8]; z = [z1,...,z8]
    D = _d3_elasticity_matrix(E, NU)
    k = zeros(24, 24)

    for (s, t, u, w) in _gauss_2x2x2()
        dN = _brick_dN(s, t, u)
        J = _brick_jacobian(dN, x, y, z)
        detJ = det(J)
        invJ = inv(J)
        dNx = invJ * dN         # physical derivatives (3×8)

        B = zeros(6, 24)
        @views for a in 1:8     # build B per node
            col = (a-1)*3 + 1
            B[1,col]   = dNx[1,a];  B[2,col+1] = dNx[2,a]
            B[3,col+2] = dNx[3,a];  B[4,col]   = dNx[2,a]
            B[4,col+1] = dNx[1,a];  B[5,col+1] = dNx[3,a]
            B[5,col+2] = dNx[2,a];  B[6,col]   = dNx[3,a]
            B[6,col+2] = dNx[1,a]
        end

        k += B' * D * B * detJ * w
    end

    return (k + k') / 2   # symmetrize to eliminate numerical noise
end
```

### Kattan MATLAB implementation

```matlab
function w = LinearBrickElementStiffness(E,NU,x1,...,z8)
    syms s t u;
    % 8 shape functions (different node ordering)
    N1 = (1-s)*(1-t)*(1+u)/8; ...
    % ... isoparametric mapping, Jacobian J symbolic ...
    % ... N1x..N8x, N1y..N8y, N1z..N8z without dividing by J ...
    B = [... explicit 6×24 matrix using N*x expressions ...];
    Bnew = simplify(B);
    Jnew = simplify(J);
    D = ...;  % 6×6 3D elasticity
    BD = transpose(Bnew)*D*Bnew/Jnew;
    r = int(int(int(BD, u, -1, 1), t, -1, 1), s, -1, 1);
    w = double(r);
end
```

### Key differences

| Aspect | Julia | Kattan MATLAB |
|--------|-------|---------------|
| Method | **Numerical** 2×2×2 Gauss | **Symbolic** triple integration |
| Jacobian | Numerical 3×3 det/inv per Gauss pt | Symbolic J, simplify, then divide |
| Derivatives | `dNx = invJ * dN` (chain rule) | B expressed as N*x/J (implicit chain rule) |
| B division | No division — J⁻¹ applied to dN | `Bfinal = Bnew / Jnew` |
| Symmetrize | `(k+k')/2` post-loop | Not needed (symbolic is exact symmetric) |
| Speed | Fast (8 matrix products) | Slow (symbolic operations) |
| Exactness | 2×2×2 exact for trilinear B | Exact (in exact arithmetic) |
| detJ guard | Implicit via `det(J)` (no explicit check) | None |

### PSD verification

For a unit cube with E=1, NU=0.3:

```julia
k = d3_brick_elementstiffness(1.0, 0.3, 0,0,0, 1,0,0, 1,1,0, 0,1,0,
                                       0,0,1, 1,0,1, 1,1,1, 0,1,1)
eigvals(k)
# 6 zero eigenvalues (rigid body modes in 3D)
# 18 positive eigenvalues (deformation modes)
```

Like all 3D continuum elements: 6 rigid body modes (3 translations + 3 rotations).

---

## 16.8 Stress Recovery

### Stress at centroid

```julia
function d3_brick_elementstress(E, NU, x1,y1,z1, ..., x8,y8,z8, u)
    # Evaluate B at centroid (ξ=η=ζ=0)
    dN = _brick_dN(0.0, 0.0, 0.0)
    J = _brick_jacobian(dN, x, y, z)
    invJ = inv(J)
    dNx = invJ * dN

    D = _d3_elasticity_matrix(E, NU)
    # Build B at centroid
    B = zeros(6, 24)
    @views for a in 1:8
        col = (a-1)*3 + 1
        B[1,col] = dNx[1,a]; ...
    end

    return D * B * u   # σ = D·B·u at centroid
end
```

Kattan MATLAB: **identical in concept** — symbolic B evaluated at centroid via `subs(w, {s,t,u}, {0,0,0})`.

### Principal stresses

```julia
d3_brick_elementpstress(sigma) = _d3_principal_stresses(sigma)
```

Same eigenvalue-decomposition helper used by the tetrahedron (Section 15.6). Returns `(σ₁, σ₂, σ₃, τ_max)`.

### Kattan MATLAB pstress = invariants, not principal stresses

Same issue as the tetrahedron (Lesson 15.6):

```matlab
function y = LinearBrickElementPStresses(sigma)
    s1 = sigma(1) + sigma(2) + sigma(3);          % I₁ (first invariant)
    s2 = sigma(1)*sigma(2) + ... - ...;            % I₂ (second invariant)
    ms3 = [sigma(1) sigma(4) sigma(6); ...];
    s3 = det(ms3);                                  % I₃ (third invariant)
    y = [s1; s2; s3];
end
```

Returns the **three tensor invariants** [I₁, I₂, I₃], not principal stresses. LibFEM.jl computes actual principal stresses via `eigvals()` — a deliberate improvement.

---

## 16.9 Assembly

```julia
function d3_brick_assemble(K, k, i, j, m, n, p, q, r, s)
    return _assemble_n!(K, k, [i, j, m, n, p, q, r, s], 3)
end
```

Kattan MATLAB `LinearBrickAssemble.m`: **588 lines** of explicit assignments:

```matlab
K(3*i-2,3*i-2) = K(3*i-2,3*i-2) + k(1,1);
K(3*i-2,3*i-1) = K(3*i-2,3*i-1) + k(1,2);
% ... 575 more lines ...
K(3*s,3*s) = K(3*s,3*s) + k(24,24);
```

The Julia `_assemble_n!` generic is a **588× reduction** in assembly code. The pattern is the same for all continuum elements with 3 DOF/node — the number of explicit assignments in MATLAB grows as `(24)² = 576` for bricks.

---

## 16.10 Shear Locking in Bricks

Like Q4 in 2D and tetrahedra in 3D, linear bricks **lock in bending**. The trilinear shape functions cannot represent the linear bending strain through the element's depth without introducing spurious shear:

```
Pure bending of a beam (exact):
  εxx = -z/ρ          (linear through depth)
  γxy = γyz = γzx = 0 (zero shear)

Single brick through depth:
  εxx = a + b·ξ + c·η + d·ζ + e·ξη + f·ξζ + g·ηζ + h·ξηζ
     → constant in ζ-direction! Can't represent -z/ρ linearly
  Spurious shear energy → over-stiff
```

### Remedies

| Method | Description | Trade-off |
|--------|-------------|-----------|
| **h-refinement** | 4+ elements through depth | More DOF, higher cost |
| **Selective reduced integration** | Reduced integration on shear terms | Hourglass modes |
| **Enhanced assumed strain (EAS)** | Add incompatible modes for bending | Complex implementation |
| **Incompatible modes (Q4/6 variant)** | Add internal DOF for bending | Extra internal DOF |
| **Upgrade to quadratic** | 20-node serendipity brick | 60 DOF/element, no locking |

### Hourglass modes in reduced-integration bricks

Using 1-point Gauss (instead of 2×2×2) creates **8 zero-energy hourglass modes** — deformation patterns that produce zero strain at the single integration point. Explicit dynamics codes (LS-DYNA, Abaqus/Explicit) control hourglassing with viscous damping or stiffness-based stabilization.

---

## 16.11 Brick Element Quality

### Jacobian sign

Like Q4, `|J|` must be **positive** at all Gauss points. A negative determinant indicates:
- Inverted element (nodes ordered CW instead of CCW on a face)
- Concave element (a face twisted beyond 180°)
- Element collapsed to a wedge or degenerate shape

LibFEM.jl does not explicitly check `detJ > 0` at each Gauss point (unlike Q4's explicit `detJ <= 0` guard). This means a badly-distorted element produces an invalid stiffness matrix silently. For production use, add a `detJ > 0` check.

### Quality metrics

| Metric | Good | Poor |
|--------|------|------|
| Aspect ratio | 1:1:1 (cube) | > 5:1:1 (sliver) |
| Jacobian ratio (max/min) | ≤ 3 | > 10 (distorted) |
| Skew angle | > 45° | < 20° |
| Warpage | Planar faces | Non-planar faces (> 5°) |

A **regular grid** of unit cubes gives optimal brick quality. Geometry with curvature or transitions (e.g., fillets) produces distorted bricks — tetrahedral meshes may be more appropriate.

---

## 16.12 Test Coverage

The `d3_brick` test block (`runtests.jl:1240-1257`) covers:

| Test | What it checks |
|------|---------------|
| `elementstiffness` | 24×24 shape, symmetry (`k ≈ k'`) for unit cube |
| `assemble` | Single-element: maps k exactly into K |

**No volume test, no stress test, no pstress test, no PSD test.** The brick has the leanest test suite among all elements.

### Property-based tests

The symmetry property test (`property_tests.jl`) covers the brick:

```julia
@test k ≈ k'  # symmetry for random (E, NU) on unit cube
```

### Octave validation adapter

The adapter (`test/matlab_adapters.jl:696-697`) documents the parameter mapping but has **no automated validation**:

```julia
# Julia equivalents (d3_brick_*):
#   d3_brick_elementstiffness(E, NU, x1, y1, z1, ..., x8, y8, z8) — identical
```

No golden regression files exist for the brick.

---

## 16.13 Example: Unit Cube in Tension

```julia
using LibFEM

# Unit cube: E=200e9, NU=0.3
E, NU = 200e9, 0.3

k = d3_brick_elementstiffness(E, NU,
    0,0,0, 1,0,0, 1,1,0, 0,1,0,     # bottom face
    0,0,1, 1,0,1, 1,1,1, 0,1,1)     # top face

println("Size: $(size(k))")       # (24, 24)
println("Symmetric: $(k ≈ k')")   # true

# Clamp bottom face (nodes 1-4: DOF 1-12), pull top face (node 7, DOF 21)
# Single element uniaxial tension in z
F = zeros(24)
F[21] = 1000.0        # UZ at node 7 (top-right-front)

# Free DOFs: top face nodes 5-8 (DOF 13:24)
free_dofs = 13:24
K_ff = k[free_dofs, free_dofs]
F_f = F[free_dofs]
u_free = K_ff \ F_f

u = zeros(24)
u[free_dofs] = u_free

# Stress at centroid
sigma = d3_brick_elementstress(E, NU,
    0,0,0, 1,0,0, 1,1,0, 0,1,0,
    0,0,1, 1,0,1, 1,1,1, 0,1,1, u)

σₚ = d3_brick_elementpstress(sigma)

println("\nTop face UZ (node 7): $(u[21]*1000) mm")
println("σzz at centroid: $(sigma[3]/1e6) MPa")
println("Principal σ₁: $(σₚ[1]/1e6) MPa, τ_max = $(σₚ[4]/1e6) MPa")
```

Expected result: σzz = F/A = 1000/(1×1) = 1 kPa (small, correct for single element). With multiple bricks through depth, bending accuracy improves.

---

## 16.14 Brick vs Tetrahedron — When to Use Which

| Situation | Brick | Tetrahedron |
|-----------|-------|-------------|
| Structured mesh (regular grid) | **Preferred** — fewer elements, better accuracy | Works but overkill |
| Complex geometry (automatic mesh) | Difficult (structured) | **Preferred** — TetGen/CGAL |
| Bending-dominated | **Locks** — needs refinement | **Locks** — same issue |
| Contact/impact explicit dynamics | **Preferred** (reduced integration) | Works but softer |
| Curved boundaries | Poor (linear edges) | Better (adaptive tet meshes) |
| Mesh generation effort | Manual (sweep/extrude) | Automatic |
| Accuracy per DOF (regular mesh) | **Better** | Adequate |

### The hybrid approach

Many production codes use **tet-dominant meshes** with bricks in critical regions:
- Bricks in regular domains (simple stress states, contact regions)
- Tetrahedra in complex transitions (fillets, free surfaces)
- Pyramid elements at tet-brick interfaces (not in Kattan/LibFEM)

---

## 16.15 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 8-node hexahedron (linear brick), 3 DOF/node |
| Matrix size | **24×24** |
| Shape functions | **Trilinear**: Nᵢ = ⅛(1 ± ξ)(1 ± η)(1 ± ζ) |
| Natural coords | ξ,η,ζ ∈ [-1,1] |
| Node ordering | Bottom face CCW (1-2-3-4), top face CCW (5-6-7-8) |
| Isoparametric | Yes — same Nᵢ for geometry and displacement |
| Jacobian | 3×3, varies **trilinearly** |
| B matrix | **6×24**, varies with position |
| Integration | **2×2×2 Gauss** quadrature (8 points) |
| Stiffness formula | `k = Σ w·Bᵀ·D·B·|J|` at 8 Gauss points |
| D matrix | `_d3_elasticity_matrix(E, NU)` — 6×6, shared with tetrahedron |
| Volume | `V = 8·det(J(0,0,0))` (exact for parallelepipeds) |
| Rigid body modes | 6 (3 translations + 3 rotations) |
| Bending | **Locks** — needs refinement or reduced integration |
| Stress evaluation | At **centroid** (ξ=η=ζ=0) |
| Principal stresses | `_d3_principal_stresses` — eigendecomposition → (σ₁,σ₂,σ₃,τ_max) |
| MATLAB pstress | Returns tensor invariants [I₁,I₂,I₃], NOT principal stresses |
| Assembly | `_assemble_n!(K, k, [i,j,m,n,p,q,r,s], 3)` vs 588-line MATLAB |
| MATLAB style | Symbolic integration throughout; Julia uses numerical Gauss |
| Node ordering diff | Julia: bottom-face-first in ζ; MATLAB: s-face-first |

### Full API

```julia
d3_brick_elementvolume(x1,y1,z1, ..., x8,y8,z8)                                                # → scalar
d3_brick_elementstiffness(E, NU, x1,y1,z1, ..., x8,y8,z8)                                       # → 24×24
d3_brick_elementstress(E, NU, x1,y1,z1, ..., x8,y8,z8, u)                                      # → 6-vec
d3_brick_elementpstress(sigma)                                                                   # → (σ₁, σ₂, σ₃, τ_max)
d3_brick_assemble(K, k, i, j, m, n, p, q, r, s)                                                  # → updated K
```

### The complete family — all 15 elements

| Lesson | Element | Nodes × DOF/n | Matrix | Integration | Locks? | Coords |
|--------|---------|--------------|--------|-------------|--------|--------|
| 2 | Spring | 2 × 1 | 2×2 | Analytic | — | — |
| 3 | Linear Bar | 2 × 1 | 2×2 | Analytic | — | — |
| 4 | Quadratic Bar | 3 × 1 | 3×3 | Analytic | — | — |
| 5 | 2D Truss | 2 × 2 | 4×4 | Analytic | — | 2D angles |
| 6 | 3D Truss | 2 × 3 | 6×6 | Analytic | — | 3D angles |
| 7 | 2D Plane Frame | 2 × 3 | 6×6 | Analytic | — | θ |
| 8 | 2D Pure Beam | 2 × 2 | 4×4 | Analytic | — | — |
| 9 | 2D Plane Grid | 2 × 3 | 6×6 | Analytic | — | θ |
| 10 | 3D Space Frame | 2 × 6 | 12×12 | Analytic | — | 3D angles |
| 11 | CST | 3 × 2 | 6×6 | 1-pt centroid | Yes | Area coords |
| 12 | LST | 6 × 2 | 12×12 | 3-pt tri Gauss | **No** | Area coords |
| 13 | Q4 | 4 × 2 | 8×8 | 2×2 Gauss | Yes | ξ,η ∈ [-1,1] |
| 14 | Q8 | 8 × 2 | 16×16 | 3×3 Gauss | **No** | ξ,η ∈ [-1,1] |
| 15 | Linear Tet | 4 × 3 | 12×12 | None (k=V·Bᵀ·D·B) | Yes | Volume coords |
| **16** | **Linear Brick** | **8 × 3** | **24×24** | **2×2×2 Gauss** | **Yes** | **ξ,η,ζ ∈ [-1,1]** |

### Next up

- **Lesson 17**: Chapter 17 — other applications (heat transfer, fluid flow, structural dynamics)
- After completing all Kattan-based lessons: convergence studies, mesh refinement, and element selection guidelines
