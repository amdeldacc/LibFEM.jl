# Lesson 6: The 3D Truss (Space Truss) — Three Dimensions, Three Cosines

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 6
> Mapped to LibFEM.jl — `src/truss.jl` (lines 226–369), `src/utils.jl`, `src/assembly.jl`

**Prerequisites**: Lesson 5 (2D Truss — coordinate transformation, direction cosines)

---

## 6.1 The Leap: 2D → 3D Truss

The 3D truss (also called **space truss**) is a direct extension of the 2D plane truss into three spatial dimensions. Each node now has **3 degrees of freedom** (UX, UY, UZ) instead of 2.

| Property | 2D Truss (Ch5) | 3D Truss (Ch6) |
|----------|---------------|----------------|
| DOF/node | 2 (UX, UY) | **3** (UX, UY, UZ) |
| Element matrix | 4×4 | **6×6** |
| Direction parameters | 1 angle θ | **3 angles** θx, θy, θz |
| Direction cosines | C = cosθ, S = sinθ | **Cx, Cy, Cz** |
| Identity constraint | C² + S² = 1 | **Cx² + Cy² + Cz² = 1** |

The **core concept is identical** to the 2D case: the element carries only axial force along its own axis. The 3D transformation matrix [T] (2×6) projects 6 global DOFs onto 2 local axial displacements:

```
| u'₁ |   =   | Cx  Cy  Cz   0   0   0 | × | UX₁ |
| u'₂ |       |  0   0   0  Cx  Cy  Cz |   | UY₁ |
                                                | UZ₁ |
                                                | UX₂ |
                                                | UY₂ |
                                                | UZ₂ |
```

---

## 6.2 Direction Cosines in 3D

### From node coordinates (the practical way)

```julia
Δx = x₂ − x₁,   Δy = y₂ − y₁,   Δz = z₂ − z₁
L  = √(Δx² + Δy² + Δz²)

Cx = Δx / L    # direction cosine with global X-axis
Cy = Δy / L    # direction cosine with global Y-axis
Cz = Δz / L    # direction cosine with global Z-axis
```

These satisfy the identity: **Cx² + Cy² + Cz² = 1** (the element axis is a unit vector).

In LibFEM.jl (`truss.jl:246-252`):

```julia
function d3_truss_elementlength(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real)
    L = sqrt(
        (x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2,
    )
    validate_positive(L, "L")
    return L
end
```

From which you compute:

```julia
Cx = (x2 - x1) / L
Cy = (y2 - y1) / L
Cz = (z2 - z1) / L
```

### From angles (Kattan's API)

Kattan's MATLAB and LibFEM.jl also accept **three angles** (θx, θy, θz) in degrees — each being the angle between the element axis and the corresponding global axis:

```
θx: angle between element axis and global X-axis
θy: angle between element axis and global Y-axis
θz: angle between element axis and global Z-axis

Cx = cos(θx),  Cy = cos(θy),  Cz = cos(θz)
```

The identity Cx² + Cy² + Cz² = 1 must hold. If it doesn't (e.g. invalid input angles), LibFEM.jl **automatically normalizes** and **warns** (`utils.jl:35-52`):

```julia
function _direction_cosines(thetax_deg::Real, thetay_deg::Real, thetaz_deg::Real)
    x = deg2rad(thetax_deg); Cx = cos(x)
    y = deg2rad(thetay_deg); Cy = cos(y)
    z = deg2rad(thetaz_deg); Cz = cos(z)
    nsq = Cx^2 + Cy^2 + Cz^2
    if abs(nsq - 1) > 1e-12
        @warn "Direction cosines do not form a unit vector: Cx²+Cy²+Cz² = $nsq ≠ 1"
        if nsq > 1e-12
            n = sqrt(nsq)
            return (Cx / n, Cy / n, Cz / n)    # normalize
        end
    end
    return (Cx, Cy, Cz)
end
```

Tested at `runtests.jl:937`:

```julia
# (90°, 90°, 90°) → cos = 0,0,0 → sum = 0 ≠ 1 → warning + degenerate
@test_logs (:warn, r"Direction cosines do not form a unit vector") d3_truss_elementstiffness(1, 1, 1, 90, 90, 90)
```

---

## 6.3 The 6×6 Stiffness Matrix

Starting from the local 2×2 bar matrix and the 2×6 transformation [T]:

```
k_local = (EA/L) × [1  -1;  -1  1]

k_global = [T]ᵀ × k_local × [T]
```

The result is a 6×6 matrix with a block structure identical to the 2D case:

```
                   ┌                             ┐
                   │  Cx²  CxCy  CxCz │ -Cx² -CxCy -CxCz │
                   │ CxCy  Cy²   CyCz │ -CxCy -Cy²  -CyCz │
k_global = EA/L ×  │ CxCz  CyCz  Cz²  │ -CxCz -CyCz -Cz²  │
                   │──────────────────┼──────────────────│
                   │ -Cx² -CxCy -CxCz │  Cx²  CxCy  CxCz │
                   │-CxCy -Cy²  -CyCz │ CxCy  Cy²   CyCz │
                   │-CxCz -CyCz -Cz²  │ CxCz  CyCz  Cz²  │
                   └                             ┘
```

In block form:

```
k_global = EA/L × [ w   -w ]
                  [ -w   w ]
```

Where `w` is the **3×3 outer product** of the direction cosine vector `{Cx, Cy, Cz}` with itself:

```
w = {C} × {C}ᵀ =  ┌  Cx²   CxCy  CxCz  ┐
                   │ CxCy   Cy²   CyCz  │
                   └ CxCz   CyCz   Cz²  ┘
```

---

## 6.4 In LibFEM.jl — Side by Side with MATLAB

### Stiffness

LibFEM.jl (`truss.jl:273-283`):

```julia
function d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    w = [Cx*Cx  Cx*Cy  Cx*Cz
         Cy*Cx  Cy*Cy  Cy*Cz
         Cz*Cx  Cz*Cy  Cz*Cz]
    return E * A / L * [w -w; -w w]
end
```

Kattan's MATLAB (`SpaceTrussElementStiffness.m`):

```matlab
function y = SpaceTrussElementStiffness(E, A, L, thetax, thetay, thetaz)
    x = thetax*pi/180;  u = thetay*pi/180;  v = thetaz*pi/180;
    Cx = cos(x);  Cy = cos(u);  Cz = cos(v);
    w = [Cx*Cx Cx*Cy Cx*Cz; Cy*Cx Cy*Cy Cy*Cz; Cz*Cx Cz*Cy Cz*Cz];
    y = E*A/L*[w -w; -w w];
end
```

**Julia differences**: type annotations, input validation (`validate_positive`), degree conversion is inside `_direction_cosines` (reused by 2D and 3D versions).

### Force (`truss.jl:302-307`)

```julia
function d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E * A / L * _truss_force_component(Cx, Cy, Cz, u)
end
```

The 3D `_truss_force_component` (`utils.jl:68-70`):

```julia
@inline function _truss_force_component(Cx::Real, Cy::Real, Cz::Real, u::AbstractVector)
    return -Cx*u[1] - Cy*u[2] - Cz*u[3] + Cx*u[4] + Cy*u[5] + Cz*u[6]
end
```

This is `[-Cx, -Cy, -Cz, Cx, Cy, Cz] · [UX₁, UY₁, UZ₁, UX₂, UY₂, UZ₂]`.

Kattan's MATLAB (`SpaceTrussElementForce.m`):

```matlab
function y = SpaceTrussElementForce(E, A, L, thetax, thetay, thetaz, u)
    x = thetax*pi/180;  w = thetay*pi/180;  v = thetaz*pi/180;
    Cx = cos(x);  Cy = cos(w);  Cz = cos(v);
    y = E*A/L*[-Cx -Cy -Cz Cx Cy Cz]*u;
end
```

### Stress (`truss.jl:346-350`)

```julia
function d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E / L * _truss_force_component(Cx, Cy, Cz, u)
end
```

σ = E × ε = E/L × [−Cx, −Cy, −Cz, Cx, Cy, Cz] · u

### Strain (`truss.jl:324-328`) — LibFEM.jl extension

```julia
function d3_truss_elementstrain(L, thetax, thetay, thetaz, u)
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return _truss_force_component(Cx, Cy, Cz, u) / L
end
```

### Assembly (`truss.jl:367-369`)

```julia
function d3_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
```

With `ndofs=3`, node i maps to slots `[3i−2, 3i−1, 3i]`:

```julia
# _assemble! with ndofs=3 (assembly.jl:21-30)
K[3i-2:3i, 3i-2:3i] += k[1:3, 1:3]   # node i block (3×3)
K[3i-2:3i, 3j-2:3j] += k[1:3, 4:6]   # cross i→j
K[3j-2:3j, 3i-2:3i] += k[4:6, 1:3]   # cross j→i
K[3j-2:3j, 3j-2:3j] += k[4:6, 4:6]   # node j block (3×3)
```

Kattan's MATLAB (`SpaceTrussAssemble.m`) writes all **36 explicit assignments** — the generic `_assemble!` handles it in 4 slice operations.

---

## 6.5 MATLAB ↔ Julia Mapping

| Operation | Kattan MATLAB | LibFEM.jl Julia | Source |
|-----------|--------------|-----------------|--------|
| Length | `SpaceTrussElementLength(x1,y1,z1,x2,y2,z2)` | `d3_truss_elementlength(x1,y1,z1,x2,y2,z2)` | `truss.jl:246-252` |
| Stiffness | `SpaceTrussElementStiffness(E,A,L,θx,θy,θz)` | `d3_truss_elementstiffness(E,A,L,θx,θy,θz)` | `truss.jl:273-283` |
| Force | `SpaceTrussElementForce(E,A,L,θx,θy,θz,u)` | `d3_truss_elementforces(E,A,L,θx,θy,θz,u)` | `truss.jl:302-307` |
| Stress | `SpaceTrussElementStress(E,L,θx,θy,θz,u)` | `d3_truss_elementstress(E,L,θx,θy,θz,u)` | `truss.jl:346-350` |
| Strain | *(not in Kattan)* | `d3_truss_elementstrain(L,θx,θy,θz,u)` | `truss.jl:324-328` |
| Assembly | `SpaceTrussAssemble(K,k,i,j)` | `d3_truss_assemble(K,k,i,j)` | `truss.jl:367-369` |

---

## 6.6 Special Cases

### Aligned with global X (θx=0°, θy=90°, θz=90°)

Only UX coupled. Cx=1, Cy=0, Cz=0:

```
k = EA/L × [w  -w; -w  w],   w = [1 0 0; 0 0 0; 0 0 0]
```

Only the UX row/col is non-zero. Zero stiffness in Y and Z directions.

### The (0°, 0°, 0°) case — automatically normalized

Angles (0°, 0°, 0°) give Cx=Cy=Cz=1, but **1² + 1² + 1² = 3 ≠ 1**. The code normalizes to `(1/√3, 1/√3, 1/√3)` so:

```
k = (EA/L) × (1/3) × [w  -w; -w  w],   w = ones(3,3)
```

This is verified in `runtests.jl:700-704`:

```julia
Ke = d3_truss_elementstiffness(1, 1, 1, 0, 0, 0)
w_ones = ones(3, 3)
@test Ke ≈ (1/3) * [w_ones -w_ones; -w_ones w_ones]
```

### Spring-truss 3D identity

```julia
# Verified in runtests.jl:978
@test d3_spring_elementstiffness(100, 30, 45, 60) ≈ d3_truss_elementstiffness(100, 1, 1, 30, 45, 60)
```

---

## 6.7 DOF Slot Mapping

```
Node n → UX at (3n−2), UY at (3n−1), UZ at (3n)
```

| Node | UX | UY | UZ |
|------|----|----|----|
| 1 | 1 | 2 | 3 |
| 2 | 4 | 5 | 6 |
| 3 | 7 | 8 | 9 |
| n | 3n−2 | 3n−1 | 3n |

When extracting element DOFs for an element between nodes 2 and 3:

```julia
u_elem = U[[3*2-2, 3*2-1, 3*2, 3*3-2, 3*3-1, 3*3]]  # = U[4,5,6,7,8,9]
```

---

## 6.8 The Unifying Pattern — Across All Trusses

The pattern from 1D → 2D → 3D trusses reveals a beautiful structure:

```
        ┌──────┬────────┬────────┬──────────────────────────────┐
        │ Dim  │ DOF/n  │ Matrix │ Block w                      │
        ├──────┼────────┼────────┼──────────────────────────────┤
        │ 1D   │   1    │  2×2   │ [1]                          │
        │ 2D   │   2    │  4×4   │ [C²  CS;  CS  S²]            │
        │ 3D   │   3    │  6×6   │ 3×3 outer product of {Cx,Cy,Cz} │
        └──────┴────────┴────────┴──────────────────────────────┘
```

All use the same formula: **k = (EA/L) × [w  -w;  -w  w]**

Where `w` is always the **outer product of the direction cosine vector** with itself:

| Dimension | Direction vector | Size of w |
|-----------|-----------------|-----------|
| 1D | `[1]` (no rotation needed) | 1×1 |
| 2D | `[C, S]` | 2×2 |
| 3D | `[Cx, Cy, Cz]` | 3×3 |

And all assemblies use the same `_assemble!` helper with `ndofs` = DOF per node.

---

## 6.9 Test Coverage

The `d3_truss` block (`runtests.jl:689-774`) covers:

| Test | What it checks |
|------|---------------|
| `elementlength` | 3D distance (sqrt(3) for unit cube), zero-length throws |
| `elementstiffness` | 6×6 shape, (0,0,0) normalization to 1/√3, (0,90,0) pattern |
| `elementforces` | Scalar, normalized value for 3D, zero-displacement |
| `elementstrain` | ε = projection/L in 3D |
| `elementstress` | σ = E×ε in 3D |
| `assemble` | Block placement, unused entries zero |
| `L>0 error paths` | L=0, L<0 for all functions |
| `negative/zero parameter` | A=0, A<0 throw; E=0 → zero; E<0 → negation |
| `direction cosine warning` | (90,90,90) → cos² sum = 0 → warning emitted |

Physical invariants via `@test_translational_invariants` (symmetry + PSD + zero row-sum).

---

## Summary

| Concept | Takeaway |
|---------|----------|
| DOF/node | **3** — UX, UY, UZ |
| Matrix | **6×6** (2 nodes × 3 DOF) |
| Direction cosines | **Cx, Cy, Cz** from coordinates ∆x/L, ∆y/L, ∆z/L |
| Identity | **Cx² + Cy² + Cz² = 1** — enforced with normalization + warning |
| Block w | 3×3 outer product of `{Cx, Cy, Cz}` |
| Stiffness formula | `k = EA/L × [w -w; -w w]` (same pattern as 1D/2D!) |
| Force/stress | **Scalar** (axial only), `[−Cx, −Cy, −Cz, Cx, Cy, Cz] · u` |
| Assembly slot | Node n → `[3n−2, 3n−1, 3n]` |
| `_assemble!` | `ndofs=3` — same helper, different block size |

### Full API

```julia
d3_truss_elementlength(x1, y1, z1, x2, y2, z2)                          # → L
d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)              # → 6×6
d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)              # → scalar
d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)                 # → scalar
d3_truss_elementstrain(L, thetax, thetay, thetaz, u)                    # → scalar
d3_truss_assemble(K, k, i, j)                                           # → updated K
```

### The family so far

| Lesson | Element | DOF/n | Matrix | Pattern |
|--------|---------|-------|--------|---------|
| 2 | 1D Spring | 1 | 2×2 | `k × [1 -1; -1 1]` |
| 3 | 1D Bar | 1 | 2×2 | `EA/L × [1 -1; -1 1]` |
| 5 | 2D Truss | 2 | 4×4 | `EA/L × [w -w; -w w]`, w=2×2 |
| **6** | **3D Truss** | **3** | **6×6** | `EA/L × [w -w; -w w]`, w=3×3 |

**Coming up in Lesson 7**: The Plane Frame (Ch7) — adding bending DOFs to the truss concept, producing a 6×6 element with 3 DOF/node (UX, UY, RZ).
