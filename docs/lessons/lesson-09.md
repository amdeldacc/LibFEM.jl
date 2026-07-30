# Lesson 9: The Plane Grid Element — Out-of-Plane Bending + Torsion

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 11
> Mapped to LibFEM.jl — `src/grid.jl` (lines 1–162)

**Prerequisite**: Lesson 7 (Plane Frame — 3 DOF/node, 6×6) and Lesson 8 (Pure Beam — bending terms)

---

## 9.1 The Grid Element Concept

A **plane grid** models structures where all members lie in one plane (typically XY) and carry loads **perpendicular** to that plane — like a bridge deck, floor system, or grillage. Each node has 3 DOFs:

| DOF | Meaning | Unit |
|-----|---------|------|
| UZ | Vertical displacement (out-of-plane) | m |
| RX | Rotation about X-axis (torsion) | rad |
| RY | Rotation about Y-axis (bending) | rad |

The 6×6 element matrix superposes two independent physical effects:
- **Torsion** (GJ/L) — resistance to twist about the element axis
- **Out-of-plane bending** (EI/L³) — same beam bending from Lesson 8

### Grid vs Frame vs Beam

| Element | Orientation | DOF/node | DOFs | Load direction | Stiffness |
|---------|-------------|----------|------|----------------|-----------|
| **Plane Frame** (Ch7) | XY plane | 3 | UX, UY, RZ | In-plane | EA + EI |
| **Pure Beam** (Ch8) | Aligned to X | 2 | UY, RZ | Transverse | EI only |
| **Plane Grid** (Ch11) | XY plane | **3** | **UZ, RX, RY** | **Out-of-plane** | **GJ + EI** |

The grid is to out-of-plane loading what the frame is to in-plane loading.

---

## 9.2 The 6×6 Stiffness Matrix

The local stiffness matrix k' combines torsion and bending:

```
k' =  ┌ w₁   0   w₂  -w₁   0   w₂ ┐
      │ 0   w₃   0    0  -w₃   0  │
      │ w₂   0   w₄  -w₂   0   w₅ │
      │-w₁   0  -w₂   w₁   0  -w₂ │
      │ 0  -w₃   0    0   w₃   0  │
      └ w₂   0   w₅  -w₂   0   w₄ ┘

w₁ = 12EI/L³    (shear — from beam bending)
w₂ =  6EI/L²    (shear-rotation coupling — from beam)
w₃ =  GJ/L      (torsion — NEW!)
w₄ =  4EI/L     (rotation stiffness — from beam)
w₅ =  2EI/L     (carry-over rotation — from beam)
```

**DOF order**: [UZ₁, RX₁, RY₁, UZ₂, RX₂, RY₂]

The torsion term `w₃ = GJ/L` has the **exact same structural form** as axial stiffness `EA/L` — both are "C/L" where C is a material-geometric constant. The only difference is:
- Axial stiffness uses `EA` (Young's modulus × area)
- Torsional stiffness uses `GJ` (shear modulus × torsional constant)

### Column-by-column interpretation (E=G=I=J=L=1, azi=0)

| Column | Load | Output | Pattern |
|--------|------|--------|---------|
| **Col 1**: UZ₁=1 | +12 vertical at node 1 | +12V₁, +6M₁, −12V₂, +6M₂ | Beam col 1 but UZ instead of UY |
| **Col 2**: RX₁=1 | +1 torque at node 1 | +1T₁, −1T₂ | Pure torsion, no bending coupling |
| **Col 3**: RY₁=1 | +4 moment at node 1 | +6V₁, +4M₁, −6V₂, +2M₂ | Beam col 2 but about Y instead of Z |
| **Col 4**: UZ₂=1 | −12 vertical at node 2 | −12V₁, −6M₁, +12V₂, −6M₂ | Antisymmetric of col 1 |
| **Col 5**: RX₂=1 | +1 torque at node 2 | +0V₁, −1T₁, 0V₂, +1T₂ | Antisymmetric of col 2 |
| **Col 6**: RY₂=1 | +4 moment at node 2 | +6V₁, +2M₁, −6V₂, +4M₂ | Antisymmetric of col 3 |

### The torsion block is diagonal

```
k'(2,2) =  w₃ = GJ/L          torque at node 1 from RX₁=1
k'(5,5) =  w₃ = GJ/L          torque at node 2 from RX₂=1
k'(2,5) = −w₃ = −GJ/L         torque at node 1 from RX₂=1
```

Torsion is completely decoupled from bending — the RX DOFs occupy rows/cols 2 and 5, while UZ/RY occupy the remaining 1/3/4/6 pattern. This is by design: a 1D element cannot couple twist with out-of-plane bending.

---

## 9.3 Coordinate Transformation

Grid members in a plane structure may be oriented at arbitrary angles. The transformation **rotates about the Z-axis** (the normal to the grid plane):

```
   ┌ 1  0  0  0  0  0 ┐
   │ 0  C  S  0  0  0 │
R = │ 0 −S  C  0  0  0 │     C = cos(θ), S = sin(θ)
   │ 0  0  0  1  0  0 │
   │ 0  0  0  0  C  S │
   │ 0  0  0  0 −S  C │
   └                  ┘
```

Notice: **the first DOF (UZ) is unchanged** — vertical deflection is the same regardless of in-plane rotation. Only the rotations (RX, RY) transform.

```
k_global = R' · k' · R      (stiffness)
f_local  = k' · R · u       (forces — transformed to local)
```

### Same transformation as plane frame (but different DOF meaning)

| Element | DOF ordering | T(θ) acts on |
|---------|-------------|--------------|
| Plane Frame | [UX, UY, RZ, UX, UY, RZ] | UX, UY (axial + shear) |
| **Plane Grid** | **[UZ, RX, RY, UZ, RX, RY]** | **RX, RY (torsion + bending)** |

Both use the same 6×6 block-diagonal R matrix with a 1 in the first position and a 2×2 rotation block. But the **physical meaning is different**: for frames it rotates axial/shear forces; for grids it rotates torsion/bending moments.

---

## 9.4 In LibFEM.jl — Side by Side with MATLAB

### Stiffness

LibFEM.jl (`grid.jl:27-65`):

```julia
function d2_grid_elementstiffness(E::Real, G::Real, I::Real, J::Real, L::Real, theta::Real)
    validate_positive(L, "L")
    (C, S) = _direction_cosines(theta)
    w1 = 12 * E * I / (L^3)
    w2 = 6 * E * I / (L^2)
    w3 = G * J / L
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    kprime = [
         w1   0   w2  -w1   0   w2
          0   w3   0    0  -w3   0
         w2   0   w4  -w2   0   w5
        -w1   0  -w2   w1   0  -w2
          0  -w3   0    0   w3   0
         w2   0   w5  -w2   0   w4
    ]
    R = [
        1  0  0  0  0  0
        0  C  S  0  0  0
        0 -S  C  0  0  0
        0  0  0  1  0  0
        0  0  0  0  C  S
        0  0  0  0 -S  C
    ]
    return R' * kprime * R
end
```

Kattan's MATLAB (`GridElementStiffness.m`):

```matlab
function y = GridElementStiffness(E,G,I,J,L,theta)
    x = theta*pi/180;
    C = cos(x); S = sin(x);
    w1 = 12*E*I/(L*L*L); w2 = 6*E*I/(L*L);
    w3 = G*J/L;           w4 = 4*E*I/L; w5 = 2*E*I/L;
    kprime = [w1 0 w2 -w1 0 w2 ; 0 w3 0 0 -w3 0 ;
              w2 0 w4 -w2 0 w5 ; -w1 0 -w2 w1 0 -w2 ;
              0 -w3 0 0 w3 0 ; w2 0 w5 -w2 0 w4];
    R = [1 0 0 0 0 0 ; 0 C S 0 0 0 ; 0 -S C 0 0 0 ;
         0 0 0 1 0 0 ; 0 0 0 0 C S ; 0 0 0 0 -S C];
    y = R'*kprime*R;
end
```

**Identical**. Julia uses `_direction_cosines(theta)` instead of inline `deg2rad`.

### Forces

LibFEM.jl (`grid.jl:83-101`):

```julia
function d2_grid_elementforces(E::Real, G::Real, I::Real, J::Real,
                                L::Real, theta::Real, u::AbstractVector)
    validate_positive(L, "L")
    (C, S) = _direction_cosines(theta)
    kprime = _d2_grid_kprime(E, G, I, J, L)
    R = [1 0 0 0 0 0; 0 C S 0 0 0; 0 -S C 0 0 0;
         0 0 0 1 0 0; 0 0 0 0 C S; 0 0 0 0 -S C]
    return kprime * R * u
end
```

Kattan MATLAB:

```matlab
function y = GridElementForces(E,G,I,J,L,theta,u)
    x = theta*pi/180; C = cos(x); S = sin(x);
    w1 = 12*E*I/(L*L*L); w2 = 6*E*I/(L*L);
    w3 = G*J/L; w4 = 4*E*I/L; w5 = 2*E*I/L;
    kprime = [w1 0 w2 -w1 0 w2 ; 0 w3 0 0 -w3 0 ;
              w2 0 w4 -w2 0 w5 ; -w1 0 -w2 w1 0 -w2 ;
              0 -w3 0 0 w3 0 ; w2 0 w5 -w2 0 w4];
    R = [1 0 0 0 0 0 ; 0 C S 0 0 0 ; 0 -S C 0 0 0 ;
         0 0 0 1 0 0 ; 0 0 0 0 C S ; 0 0 0 0 -S C];
    y = kprime * R * u;
end
```

**Identical**. Both compute `f_local = k' · R · u` — transform global displacements to local, then multiply by local stiffness.

### Length

LibFEM.jl (`grid.jl:110-125`):

```julia
function d2_grid_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    L = sqrt((x2 - x1)^2 + (y2 - y1)^2)
    validate_positive(L, "L")
    return L
end
```

Kattan MATLAB:

```matlab
function y = GridElementLength(x1,y1,x2,y2)
    y = sqrt((x2-x1)*(x2-x1)+(y2-y1)*(y2-y1));
end
```

**Identical** except for the `validate_positive` guard in Julia.

### Assembly

LibFEM.jl (`grid.jl:119-121`):

```julia
function d2_grid_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
```

Kattan MATLAB (`GridAssemble.m`): 36 explicit assignments with `3*i-2, 3*i-1, 3*i` etc.

**Julia**: one-liner via `_assemble!` with `ndofs=3`.

---

## 9.5 The Torsion-Axial Analogy

Torsional stiffness `GJ/L` is structurally identical to axial stiffness `EA/L`. Compare:

| | Axial (bar/truss) | Torsion (grid) |
|---|---|---|
| Constitutive constant | E (Young's modulus) | G (shear modulus) |
| Section property | A (area) | J (torsional constant) |
| Stiffness form | EA/L | GJ/L |
| Governing equation | EA·u'' = 0 | GJ·φ'' = 0 |
| DOF | Displacement u | Rotation φ |
| Force | Axial force P | Torque T |

Both are two-point boundary value problems with the same mathematical structure — hence the same diagonal form in the stiffness matrix.

### Typical values

| Material | E (GPa) | G (GPa) | ν | G/E ratio |
|----------|---------|---------|---|-----------|
| Steel | 200 | 80 | 0.3 | 0.40 |
| Aluminum | 70 | 26 | 0.33 | 0.37 |
| Concrete | 30 | 12.5 | 0.2 | 0.42 |

For isotropic materials: `G = E / (2(1+ν))`.

---

## 9.6 The Relationship: Grid = Beam + Torsion

The grid element's local stiffness matrix is the beam element with:
1. **UZ replaces UY** (vertical displacement, different axis)
2. **RY replaces RZ** (rotation axis, different axis)
3. **Torsion added** in rows/cols 2 and 5 (the RX DOF)

```
Beam (4×4):              Grid k' (6×6):
                          ┌ 12  ─  ─ ─ 6  ─12 ─  ─ ─ 6 ┐
┌ 12  6L  ─12  6L ┐     │ ─   1  ─ ─  ─  ─1  ─ ─ │
│  6L 4L² ─6L  2L²│  →  │ 6   ─  ─ ─ 4  ─6  ─  ─ ─ 2 │
│─12 ─6L  12  ─6L │     │─12  ─  ─ ──6  12  ─  ─ ──6 │
└  6L 2L² ─6L  4L²┘     │ ─  ─1  ─ ─  ─   1  ─ ─ │
                          └ 6   ─  ─ ─ 2  ─6  ─  ─ ─ 4 ┘
```

The beam matrix (UY, RZ DOFs) maps to the grid's UZ, RY DOFs (columns 1,3,4,6). The torsion DOF (RX) is inserted at columns 2 and 5, completely decoupled.

---

## 9.7 Test Coverage

The `d2_grid` test block (`runtests.jl:925-994`) covers:

| Test | What it checks |
|------|---------------|
| `elementlength` | 3-4-5 triangle, L=0 throws, negative coords |
| `elementstiffness` | 6×6 shape, azi=0 matches k' matrix, azi=90 rotated |
| `elementforces` | UZ₁=1 → [12,0,6,−12,0,6], zero displacement → zero |
| `assemble` | Block placement into 6×6 and 9×9 systems |
| `L>0 error paths` | L=0, L<0 throw |
| `@test_physical_invariants` | Symmetry + positive semi-definiteness |

Plus property-based tests (`property_tests.jl`): symmetry for random `(E, G, I, J, L, θ)`.

---

## 9.8 Summary

| Concept | Takeaway |
|---------|----------|
| Structure | All members in one plane, loads perpendicular to it |
| DOF/node | **3** — UZ (vertical), RX (torsion), RY (bending) |
| Matrix | **6×6** — torsion (GJ/L) + out-of-plane bending (EI/L³) |
| Torsion term | w₃ = GJ/L — identical form to axial EA/L |
| Transformation | Rotation **θ about Z-axis** (the grid plane normal) |
| Forces | [V₁, T₁, M₁, V₂, T₂, M₂] — f = k' · R · u |
| Bending decoupled from torsion | RX DOFs (cols 2,5) independent of UZ/RY |
| Assembly | `_assemble!(..., ndofs=3)` — same slot mapping as space truss and plane frame |

### Full API

```julia
d2_grid_elementlength(x1, y1, x2, y2)                    # → scalar
d2_grid_elementstiffness(E, G, I, J, L, theta)           # → 6×6
d2_grid_elementforces(E, G, I, J, L, theta, u)           # → 6-vec [V,T,M,V,T,M]
d2_grid_assemble(K, k, i, j)                             # → updated K
```

### The family so far

| Lesson | Element | DOF/n | Matrix | Governing params |
|--------|---------|-------|--------|-----------------|
| 2 | 1D Spring | 1 | 2×2 | k |
| 3 | 1D Bar | 1 | 2×2 | EA |
| 4 | Quadratic Bar | 1 | 3×3 | EA |
| 5 | 2D Truss | 2 | 4×4 | EA |
| 6 | 3D Truss | 3 | 6×6 | EA |
| 7 | 2D Plane Frame | 3 | 6×6 | EA + EI |
| 8 | 2D Pure Beam | 2 | 4×4 | EI |
| **9** | **2D Plane Grid** | **3** | **6×6** | **GJ + EI** |
| 10 | 3D Space Frame | 6 | 12×12 | EA + EI + GJ |

### The Relationship Diagram

```
                 Axial (EA/L)     Bending (EI/L³)     Torsion (GJ/L)
                 ┌───┐                 │                   │
Bar (Ch3)  ─────►│EA │                 │                   │
                 └───┘                 │                   │
                                       ▼                   │
Beam (Ch8) ──────────────────────────►│EI│                 │
                                      │  │                 │
                                       └──┘                │
                                                           ▼
Grid (Ch9)  ─────── GJ/L ────────────────────────────────►│GJ│
                                                           └──┘
Frame (Ch7) ◄─── EA + EI ─── (in-plane)
Grid  (Ch9) ◄─── GJ + EI ─── (out-of-plane)
```

The grid element (Ch9) is the **out-of-plane counterpart** to the plane frame (Ch7). Where the frame combines axial stiffness and in-plane bending, the grid combines torsional stiffness and out-of-plane bending.

**Coming up in Lesson 10**: The 3D Space Frame — 6 DOF/node, 12×12 matrix, the most general 1D element.
