# Lesson 10: The 3D Space Frame — The Most General 1D Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 10
> Mapped to LibFEM.jl — `src/spaceframe.jl` (lines 1–271), `src/assembly.jl` (lines 87–123), `ext/LibFEMPlotsExt.jl`

**Prerequisite**: Lessons 7 (Plane Frame — 3 DOF/node, 6×6) and 9 (Grid — torsion + out-of-plane bending)

---

## 10.1 The Space Frame Concept

The **space frame** is the most general 1D line element — a beam in full 3D. Every node has **6 degrees of freedom** (all 3 translations + all 3 rotations), producing a **12×12 stiffness matrix**. It is the direct 3D generalization of the plane frame (Lesson 7).

| DOF | Name | Meaning | Unit |
|-----|------|---------|------|
| UX | Axial displacement | Stretching along the beam axis | m |
| UY | Lateral displacement (horizontal) | Bending in XY plane | m |
| UZ | Lateral displacement (vertical) | Bending in XZ plane | m |
| RX | Torsional rotation | Twisting about beam axis | rad |
| RY | Rotation about Y-axis | Bending rotation in XZ plane | rad |
| RZ | Rotation about Z-axis | Bending rotation in XY plane | rad |

### What makes it special

The space frame is the **culmination of Chapters 2–10**: every earlier 1D element is a subset or special case.

```
Space Frame (10) ───┬─── Axial DOF (UX₁, UX₂)        → Bar/Truss (Ch3, Ch5, Ch6)
                    ├─── Torsion DOF (RX₁, RX₂)       → Grid (Ch9)
                    ├─── Bending XY (UY₁, RZ₁, ...)   → Plane Frame (Ch7)
                    └─── Bending XZ (UZ₁, RY₁, ...)   → Plane Frame rotated
```

---

## 10.2 The 12×12 Local Stiffness Matrix

In the **local** coordinate system (x' along the beam axis), the four physical effects are completely decoupled:

```
k' = ┌ Axial ─ ─ ─ ─ ─ ─ ─   0   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
     │ ─ ─ Bending-XY ─ ─ ─ ─ ─ ─   0   ─ ─ ─ ─ ─ ─ ─ ─ ─ │
     │ ─ ─ ─ ─ Bending-XZ ─ ─ ─ ─ ─ ─   0   ─ ─ ─ ─ ─ ─ ─ │
     │ ─ ─ ─ ─ ─ ─  Torsion ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │
     │ 0 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ Axial ─ ─ ─ ─ ─ ─ ─ ─ ─ │
     │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ Bending-XY ─ ─ ─ ─ │
     │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ Bending-XZ ─ ─ │
     │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ Torsion ┘
```

### Explicit 12×12

```
     UX₁    UY₁    UZ₁    RX₁    RY₁    RZ₁     UX₂     UY₂     UZ₂     RX₂     RY₂     RZ₂
   ┌ w₁    0      0      0      0      0     −w₁     0       0       0       0       0    ┐
   │ 0    w₂     0      0      0     w₃     0     −w₂     0       0       0      w₃    │
   │ 0     0     w₄     0    −w₅    0      0      0     −w₄     0     −w₅     0      │
   │ 0     0      0     w₁₀   0      0      0      0      0     −w₁₀   0       0      │
   │ 0     0     −w₅    0     w₆    0      0      0      w₅     0      w₇     0      │
   │ 0     w₃    0      0      0     w₈     0     −w₃    0       0       0      w₉     │
k'= │−w₁   0      0      0      0      0     w₁     0       0       0       0       0    │
   │ 0    −w₂   0      0      0     −w₃    0      w₂     0       0       0     −w₃    │
   │ 0     0    −w₄    0      w₅    0      0      0      w₄     0      w₅     0      │
   │ 0     0      0    −w₁₀  0      0      0      0      0      w₁₀   0       0      │
   │ 0     0    −w₅    0      w₇    0      0      0      w₅     0      w₆     0      │
   │ 0     w₃    0      0      0      w₉    0     −w₃    0       0       0      w₈     ┘
```

### Parameter definitions

| Parameter | Formula | Physics | Source |
|-----------|---------|---------|--------|
| w₁  | EA/L | Axial stiffness | Bar (Ch3) |
| w₂  | 12EI_z/L³ | Shear — XY bending | Plane frame (Ch7) |
| w₃  | 6EI_z/L² | Shear-rotation coupling — XY | Plane frame (Ch7) |
| w₄  | 12EI_y/L³ | Shear — XZ bending | Plane frame rotated |
| w₅  | 6EI_y/L² | Shear-rotation coupling — XZ | Plane frame rotated |
| w₆  | 4EI_y/L  | Rotation stiffness — XZ | Beam (Ch8) |
| w₇  | 2EI_y/L  | Carry-over rotation — XZ | Beam (Ch8) |
| w₈  | 4EI_z/L  | Rotation stiffness — XY | Plane frame (Ch7) |
| w₉  | 2EI_z/L  | Carry-over rotation — XY | Plane frame (Ch7) |
| w₁₀ | GJ/L     | Torsional stiffness | Grid (Ch9) |

### Block-diagonal structure

Rows/cols are interleaved by DOF type, but four independent blocks are still visible:

```
Block 1 — Axial (UX):          DOFs 1, 7     →  2×2  = [w₁  −w₁; −w₁  w₁]
Block 2 — Bending XY (UY,RZ):  DOFs 2,6,8,12 →  4×4  = beam matrix about Z
Block 3 — Bending XZ (UZ,RY):  DOFs 3,5,9,11 →  4×4  = beam matrix about Y
Block 4 — Torsion (RX):        DOFs 4,10      →  2×2  = [w₁₀ −w₁₀; −w₁₀ w₁₀]
```

**Key insight**: Bending about Y and Z are completely independent in the local frame. They use the same `EI/L³` pattern but with `Iy` vs `Iz`. The only coupling between them comes from the 3D coordinate transformation when the element is rotated in space.

---

## 10.3 3D Coordinate Transformation

The space frame's transformation is more involved than any previous element because the beam axis can point **anywhere in 3D**.

### Direction cosine matrix Lambda (3×3)

Given the element's node coordinates, the local x'-axis unit vector is:

```
v_x = [(x₂−x₁)/L, (y₂−y₁)/L, (z₂−z₁)/L]  =  [Cx, Cy, Cz]
```

The full 3×3 rotation matrix Lambda is constructed from three orthogonal unit vectors:

```
          ┌  Cx       Cy       Cz   ┐  (local x' — along the beam axis)
Lambda =  │ −Cy/D     Cx/D     0    │  (local y' — perpendicular in XY plane)
          └ −Cx·Cz/D −Cy·Cz/D  D   ┘  (local z' — completes right-hand triad)
```

where `D = √(Cx² + Cy²)` (the projection of the beam axis onto the XY plane).

### Special case: vertical element

When the beam is vertical (Cx ≈ Cy ≈ 0 → D ≈ 0), the standard formula breaks. The code handles this explicitly:

```julia
if hypot(Cx, Cy) < 1e-12
    if z2 > z1                     # pointing up:
        Lambda = [0 0 1; 0 1 0; -1 0 0]
    else                           # pointing down:
        Lambda = [0 0 -1; 0 1 0; 1 0 0]
    end
end
```

### Full 12×12 rotation R

R = diag(Lambda, Lambda, Lambda, Lambda) — blocks repeated for each node's 6 DOFs:

```
      ┌ Lambda   0       0       0   ┐
      │   0    Lambda   0       0    │
R =   │   0      0    Lambda   0     │
      └   0      0      0    Lambda  ┘
```

This rotates the 12×1 displacement/force vectors between global and local coordinates.

### Global stiffness assembly

```
k_global = R' · k_local · R        (stiffness — double transform)
f_local  = k_local · R · u         (forces — global→local, then multiply)
```

---

## 10.4 In LibFEM.jl — Side by Side with MATLAB

### Local stiffness

LibFEM.jl (`spaceframe.jl:185-218`) — `_d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)`:

```julia
function _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)
    w1 = E * A / L           w2 = 12 * E * Iz / (L^3)    w3 = 6 * E * Iz / (L^2)
    w4 = 4 * E * Iz / L      w5 = 2 * E * Iz / L          w6 = 12 * E * Iy / (L^3)
    w7 = 6 * E * Iy / (L^2)  w8 = 4 * E * Iy / L          w9 = 2 * E * Iy / L
    w10 = G * J / L
    return [w1  0   0   0    0    0   -w1  0   0   0    0    0
            0   w2  0   0    0    w3   0  -w2  0   0    0    w3
            0   0   w6  0   -w7   0    0   0  -w6  0   -w7   0
            0   0   0  w10   0    0    0   0   0  -w10  0    0
            0   0  -w7  0    w8   0    0   0   w7  0    w9   0
            0   w3  0   0    0    w4   0  -w3  0   0    0    w5
           -w1  0   0   0    0    0    w1  0   0   0    0    0
            0  -w2  0   0    0   -w3   0   w2  0   0    0   -w3
            0   0  -w6  0    w7   0    0   0   w6  0    w7   0
            0   0   0  -w10  0    0    0   0   0   w10  0    0
            0   0  -w7  0    w9   0    0   0   w7  0    w8   0
            0   w3  0   0    0    w5   0  -w3  0   0    0    w4]
end
```

Kattan MATLAB (`SpaceFrameElementStiffness.m`):

```matlab
function y = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, L)
    % ... same w1-w10 calculations ...
    % 12×12 local stiffness matrix (identical structure)
    y = ...
end
```

**Identical** structure. Kattan's MATLAB takes precomputed L as input; Julia computes L from node coordinates inside the top-level function.

### Transformation

LibFEM.jl (`spaceframe.jl:241-271`) — `_spaceframe_transform(x1, y1, z1, x2, y2, z2)`:

```julia
function _spaceframe_transform(x1, y1, z1, x2, y2, z2)
    L = sqrt((x2-x1)^2 + (y2-y1)^2 + (z2-z1)^2)
    Cx = (x2-x1)/L;  Cy = (y2-y1)/L;  Cz = (z2-z1)/L

    if hypot(Cx, Cy) < 1e-12
        # Vertical element
        Lambda = z2 > z1 ? [0 0 1; 0 1 0; -1 0 0] : [0 0 -1; 0 1 0; 1 0 0]
    else
        D = sqrt(Cx^2 + Cy^2)
        Lambda = [ Cx      Cy      Cz
                  -Cy/D    Cx/D    0
                  -Cx*Cz/D -Cy*Cz/D  D ]
    end

    Z33 = zeros(3,3)
    R = [Lambda Z33 Z33 Z33; Z33 Lambda Z33 Z33;
         Z33 Z33 Lambda Z33; Z33 Z33 Z33 Lambda]
    return (Lambda, R)
end
```

Kattan's MATLAB (`SpaceFrameElementStiffness.m`) has the same direction-cosine calculation inline, building Lambda and R identically.

### Forces

LibFEM.jl (`spaceframe.jl:132-155`):

```julia
function d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1,y1,z1, x2,y2,z2, u)
    L = d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)
    kprime = _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)
    (_, R) = _spaceframe_transform(x1, y1, z1, x2, y2, z2)
    return kprime * R * u
end
```

Kattan MATLAB (`SpaceFrameElementForces.m`):

```matlab
function y = SpaceFrameElementForces(k_local, u_local)
    y = k_local * u_local;
end
```

**Difference**: LibFEM.jl takes raw node coordinates and builds the transformation internally; Kattan's MATLAB expects the user to pre-transform u to local coordinates. The Julia version is more ergonomic.

### Assembly

LibFEM.jl (`spaceframe.jl:100-107`):

```julia
function d3_spaceframe_assemble(K, k, i, j)
    return _assemble!(K, k, i, j, 6)
end
```

Kattan MATLAB (`SpaceFrameAssemble.m`): 144 explicit assignments (12²) with `6*i-5, 6*i-4, ..., 6*j`.

**Julia**: one-liner via `_assemble!` with `ndofs=6`.

---

## 10.5 Every Earlier Element is a Subset

The space frame is the **union of all previous 1D elements**:

| Element | DOFs kept | k size | Subset of space frame? |
|---------|-----------|--------|----------------------|
| 1D Spring (Ch2) | UX only | 2×2 | ✓ Cols 1,7 only |
| 1D Bar (Ch3) | UX only | 2×2 | ✓ Same |
| 2D Truss (Ch5) | UX, UY | 4×4 | ✓ Cols 1,2,7,8 |
| 3D Truss (Ch6) | UX, UY, UZ | 6×6 | ✓ Cols 1,2,3,7,8,9 |
| Pure Beam (Ch8) | UY, RZ | 4×4 | ✓ Cols 2,6,8,12 |
| Plane Frame (Ch7) | UX, UY, RZ | 6×6 | ✓ Cols 1,2,6,7,8,12 |
| Grid (Ch9) | UZ, RX, RY | 6×6 | ✓ Cols 3,4,5,9,10,11 |

### Visualizing the subsets

```
Space Frame (12×12):
[1  2  3  4  5  6 | 7  8  9  10 11 12]
 ─────────────────┼─────────────────
 UX UY UZ RX RY RZ | UX UY UZ RX RY RZ
  ↑  ↑           ↑ | ↑  ↑           ↑
  │  └─┴── Plane Frame (6×6): UX₁,UY₁,RZ₁ | UX₂,UY₂,RZ₂
  │                 │
  └──── 3D Truss (6×6): UX₁,UY₁,UZ₁ | UX₂,UY₂,UZ₂

                   └── Grid (6×6): UZ₁,RX₁,RY₁ | UZ₂,RX₂,RY₂
```

**Master-key relationship**: Learn the space frame once, and you implicitly know every simpler 1D element.

---

## 10.6 Iy vs Iz — Which Bending Plane is Which?

A common mistake is swapping Iy and Iz. The convention is:

- **Iz** → moment of inertia about the **local z'-axis** → controls bending in the **XY plane** (UY, RZ DOFs)
- **Iy** → moment of inertia about the **local y'-axis** → controls bending in the **XZ plane** (UZ, RY DOFs)

In local coordinates, the beam axis is x'. The cross-section has two principal axes:
- y' — one principal direction (horizontal in a horizontal beam)
- z' — the other principal direction (vertical in a horizontal beam)

For a standard horizontal beam (along global X):
- Iz = I_zz = the "weak axis" (bending vertically → UZ)
- Iy = I_yy = the "strong axis" (bending laterally → UY)

Wait — this depends on how the cross-section is oriented. For a wide-flange beam with web vertical:
- Iy (about local y') = weak axis (horizontal bending)
- Iz (about local z') = strong axis (vertical bending)

**Always verify your cross-section orientation against your local coordinate convention.**

---

## 10.7 The Six Diagram Functions

The space frame comes with 6 diagram functions for visualizing internal forces (defined in `ext/LibFEMPlotsExt.jl`, requires `Plots.jl`):

| Function | What it plots | Force input |
|----------|--------------|-------------|
| `d3_spaceframe_elementaxialdiagram(f, L)` | Axial force N(x) | f[1], f[7] |
| `d3_spaceframe_elementshearydiagram(f, L)` | Shear in XY plane | f[2], f[8] |
| `d3_spaceframe_elementshearzdiagram(f, L)` | Shear in XZ plane | f[3], f[9] |
| `d3_spaceframe_elementmomentydiagram(f, L)` | Bending moment about Y | f[5], f[11] |
| `d3_spaceframe_elementmomentzdiagram(f, L)` | Bending moment about Z | f[6], f[12] |
| `d3_spaceframe_elementtorsiondiagram(f, L)` | Torsion (torque) | f[4], f[10] |

All use the same `_beamdiagram` helper that draws linear diagrams between end-node values. The plot functions return `Plots.Plot` objects and are only available when `Plots.jl` is loaded alongside LibFEM.

---

## 10.8 Test Coverage

The `d3_spaceframe` test block (`runtests.jl:798-921`) covers:

| Test | What it checks |
|------|---------------|
| `elementstiffness` | 12×12 shape, horizontal beam matches k', physical invariants |
| `elementforces` | Zero displacement → zero force, unit UX₁→compression, unit RZ₁→shear |
| `assemble` | Block placement into 12×12 and 18×18 systems |
| `L>0 error paths` | L=0, L<0 throw for all functions |
| `elementaxialdiagram` | Returns `Plots.Plot` |
| `elementshearydiagram` | Returns `Plots.Plot` |
| `elementshearzdiagram` | Returns `Plots.Plot` |
| `elementmomentydiagram` | Returns `Plots.Plot` |
| `elementmomentzdiagram` | Returns `Plots.Plot` |
| `elementtorsiondiagram` | Returns `Plots.Plot` |
| `vertical beam` | Direction cosines for vertical element |
| `near-vertical beam` | Gradual transition to vertical |
| `backward beam` | Reverse node order preserves stiffness |
| `negative/zero A` | A=0 and A<0 throw |

Plus property-based tests (`property_tests.jl`): symmetry for random `(E, G, A, Iy, Iz, J, L)`.

Plus **Octave validation** (`validate-matlab.jl:490-531`): 3 comparisons against MATLAB reference (length, stiffness, forces).

Plus **golden regression** (`golden/manifests.toml`): 4 stiffness snapshots.

Plus **benchmarks** (`benchmark.jl`): stiffness (12×12), forces, 500-element assembly chain.

---

## 10.9 Example: Cantilever Space Frame

```julia
using LibFEM

# Properties: steel W-section
E = 200e9          # Pa
G = 80e9           # Pa
A = 0.02           # m²
Iy = 2e-4          # m⁴ (bending about local y)
Iz = 1e-4          # m⁴ (bending about local z)
J  = 5e-5          # m⁴ (torsional constant)

# Node coordinates (horizontal along X)
x1, y1, z1 = 0.0, 0.0, 0.0
x2, y2, z2 = 4.0, 0.0, 0.0

# Element stiffness (12×12)
k = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

# Assemble (single element, 2 nodes × 6 DOF)
K = zeros(12, 12)
K = d3_spaceframe_assemble(K, k, 1, 2)

# Apply tip load (vertical at node 2, DOF 3)
F = zeros(12)
F[3] = -10000.0    # 10 kN downward at node 2

# Apply BCs: node 1 fixed (DOFs 1-6 = 0)
free_dofs = 7:12                    # node 2 is free
K_ff = K[free_dofs, free_dofs]
F_f  = F[free_dofs]

# Solve for displacements of node 2
u_free = K_ff \ F_f

# Full displacement vector
u = zeros(12)
u[7:12] = u_free

# Recover internal forces in local frame
f = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

# Visualize
d3_spaceframe_elementaxialdiagram(f, 4.0)
d3_spaceframe_elementshearzdiagram(f, 4.0)
d3_spaceframe_elementmomentzdiagram(f, 4.0)
```

---

## 10.10 Summary

| Concept | Takeaway |
|---------|----------|
| DOF/node | **6** — UX, UY, UZ, RX, RY, RZ |
| Matrix | **12×12** — 4 decoupled physics blocks |
| Axial | EA/L — same as bar/truss |
| Bending XY | EI_z/L³ — same in-plane bending as frame |
| Bending XZ | EI_y/L³ — same as above, perpendicular plane |
| Torsion | GJ/L — same as grid |
| Transformation | Full 3D: Lambda (3×3) → R = diag(Lambda)×4 (12×12) |
| Vertical element | Special case: explicit Lambda assignment |
| Forces | f_local = k' · R · u (6 forces × 6 moments) |
| Assembly | `_assemble!(..., ndofs=6)` |
| Diagrams | 6 functions: axial, shear-Y/Z, moment-Y/Z, torsion |

### Full API

```julia
d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)                          # → scalar
d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1,y1,z1, x2,y2,z2)       # → 12×12
d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1,y1,z1, x2,y2,z2, u)       # → 12-vec
d3_spaceframe_assemble(K, k, i, j)                                            # → updated K
d3_spaceframe_elementaxialdiagram(f, L)                                       # → Plots.Plot
d3_spaceframe_elementshearydiagram(f, L)      d3_spaceframe_elementshearzdiagram(f, L)
d3_spaceframe_elementmomentydiagram(f, L)    d3_spaceframe_elementmomentzdiagram(f, L)
d3_spaceframe_elementtorsiondiagram(f, L)
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
| 9 | 2D Plane Grid | 3 | 6×6 | GJ + EI |
| **10** | **3D Space Frame** | **6** | **12×12** | **EA + EIy + EIz + GJ** |
| 11+ | Continuum elements | 2–3 | 6×6 – 24×24 | E, ν |

### The unification

```
                 ┌─── EA/L ───→ Bars & Trusses (Ch2–Ch6)
                 │
All 1D elements ─┼─── EI/L³ ──→ Beams (Ch8)
                 │
                 ├─── EI/L³ + EA/L ──→ Plane Frame (Ch7)
                 │
                 ├─── EI/L³ + GJ/L ──→ Grid (Ch9)
                 │
                 └─── EA/L + EI_y/L³ + EI_z/L³ + GJ/L ──→ Space Frame (Ch10)
```

The space frame is the **end of the line for 1D elements**. Every combination of axial, bending (about two axes), and torsional stiffness is now available. Starting in Lesson 11, we move to **2D continuum elements** — triangles and quadrilaterals for plane stress/strain analysis.
