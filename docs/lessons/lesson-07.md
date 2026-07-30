# Lesson 7: The Plane Frame — Axial + Bending in One Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 7
> Mapped to LibFEM.jl — `src/beam.jl` (lines 73–189), `src/assembly.jl` (lines 32–64), `src/utils.jl`

**Prerequisites**: Lesson 5 (2D Truss — coordinate transformation), Lesson 3 (1D Bar — axial stiffness), Lesson 8/Beam (bending stiffness — the pure beam element)

---

## 7.1 The Big Idea: Superposition

The plane frame element is simply **a bar + a beam glued together at 3 DOF per node**:

```
Local DOF order:   [u₁, v₁, θ₁ | u₂, v₂, θ₂]
                     ↑         ↑   ↑         ↑
                    axial  transverse  axial  transverse
                           + rotation         + rotation
```

| Behavior | Source | DOFs | Contribution |
|----------|--------|------|--------------|
| **Axial** (bar, Ch3) | EA/L | u₁, u₂ | 2×2 in corners |
| **Bending** (beam, Ch8) | EI/L³ | v₁, θ₁, v₂, θ₂ | 4×4 in center |
| **Coupling** | — | — | **None in local frame** — axial and bending are orthogonal |

The key insight: **in the local coordinate system, axial stretching and transverse bending are completely independent.** They only mix in the global system via the rotation transformation.

---

## 7.2 Local Stiffness: The 6×6 k'

The local (primal) stiffness matrix is built by stacking:

```
k' =    bar matrix (2×2, EA/L)       +    beam matrix (4×4, EI/L³)
          at DOFs [u₁, u₂]                    at DOFs [v₁, θ₁, v₂, θ₂]

       ┌                               ┐
       │ EA/L    0       0     -EA/L   0       0     │
       │   0    12EI/L³   6EI/L²   0   -12EI/L³  6EI/L²│
       │   0    6EI/L²   4EI/L    0   -6EI/L²   2EI/L │
  k' = │ -EA/L   0       0      EA/L   0       0     │
       │   0   -12EI/L³ -6EI/L²  0    12EI/L³ -6EI/L²│
       │   0    6EI/L²   2EI/L   0   -6EI/L²   4EI/L │
       └                               ┘
```

Or more compactly:

```
k' = diag(bar_2×2, beam_4×4)   (block diagonal)
```

In LibFEM.jl (`assembly.jl:50-64`):

```julia
function _d2_planeframe_kprime(E::Real, A::Real, I::Real, L::Real)
    w1 = E * A / L                              # axial
    w2 = 12 * E * I / (L^3)                     # shear stiffness
    w3 = 6 * E * I / (L^2)                      # cross-coupling
    w4 = 4 * E * I / L                          # moment at node i
    w5 = 2 * E * I / L                          # moment at node j
    return [
        w1  0   0   -w1  0    0
        0   w2  w3   0   -w2  w3
        0   w3  w4   0   -w3  w5
        -w1 0   0    w1  0    0
        0   -w2 -w3  0    w2  -w3
        0   w3  w5   0   -w3  w4
    ]
end
```

---

## 7.3 Transformation to Global Coordinates

The 6×6 transformation matrix T maps local DOFs to global DOFs.

Since rotations (θ = RZ) are **identical** in local and global frames (they measure the same physical rotation about the Z-axis), they pass through unchanged:

```
| u'_1 |   | C   S   0   0   0   0 |   | UX₁ |
| v'_1 |   |-S   C   0   0   0   0 |   | UY₁ |
| θ'_1 | = | 0   0   1   0   0   0 | × | RZ₁ |
| u'_2 |   | 0   0   0   C   S   0 |   | UX₂ |
| v'_2 |   | 0   0   0  -S   C   0 |   | UY₂ |
| θ'_2 |   | 0   0   0   0   0   1 |   | RZ₂ |
```

C = cosθ, S = sinθ. The 3×3 block structure:

```
T = [ R₃   0 ]
    [ 0   R₃ ]

where  R₃ = [C  S  0; -S  C  0; 0  0  1]
```

Then: **k_global = Tᵀ × k' × T**

### The expanded formula (no matrix multiplication needed)

Kattan and LibFEM.jl both use the fully expanded matrix directly (`beam.jl:118-136`):

```julia
function d2_planeframe_elementstiffness(E::Real, A::Real, I::Real, L::Real, theta::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    w1 = A * C * C + 12 * I * S * S / (L * L)
    w2 = A * S * S + 12 * I * C * C / (L * L)
    w3 = (A - 12 * I / (L * L)) * C * S
    w4 = 6 * I * S / L
    w5 = 6 * I * C / L
    return E / L * [
        w1   w3  -w4  -w1  -w3  -w4
        w3   w2   w5  -w3  -w2   w5
       -w4   w5  4*I   w4  -w5  2*I
       -w1  -w3   w4   w1   w3   w4
       -w3  -w2  -w5   w3   w2  -w5
       -w4   w5  2*I   w4  -w5  4*I
    ]
end
```

The five w-terms encode axial-bending coupling introduced by rotation:

| Term | Physical meaning |
|------|-----------------|
| w₁ = A·C² + 12·I·S²/L² | Axial + bending projected to UX |
| w₂ = A·S² + 12·I·C²/L² | Axial + bending projected to UY |
| w₃ = (A − 12I/L²)·C·S | Cross-coupling between UX and UY |
| w₄ = 6·I·S/L | Bending cross-term from rotation (shear) |
| w₅ = 6·I·C/L | Bending cross-term from rotation (moment) |

---

## 7.4 Interpreting the Terms: The Beam Slenderness Factor

The relative magnitude of axial vs bending terms is controlled by:

```
w₁ = A·C² + 12·I·S²/L²

At θ=0 (horizontal beam):  w₁ = A·1² + 0 = A
At θ=90° (vertical beam):  w₁ = 0 + 12·I/L²
```

The ratio `(12·I/L²)/A = 12·(r_g/L)²` where `r_g = √(I/A)` is the **radius of gyration**.

For a rectangular cross-section b×h: `r_g = h/√12`. So `12·I/(A·L²) = (h/L)²` — squaring the slenderness ratio `L/h`.

| L/h ratio | Bending term relative to axial | Behavior |
|-----------|-------------------------------|----------|
| L/h ≫ 10 | Negligible (≤ 1%) | **Frame → truss** (bending is tiny) |
| L/h ≈ 5  | ~4% | Frame with moderate bending |
| L/h ≈ 1  | ~100% | Deep beam — bending dominates |

---

## 7.5 Force Recovery — Back to Local

Element forces are computed in the **local** coordinate system (where they physically make sense):

```julia
function d2_planeframe_elementforces(E, A, I, L, theta, u)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    kprime = _d2_planeframe_kprime(E, A, I, L)
    T = [
        C  S 0 0 0 0
       -S  C 0 0 0 0
        0  0 1 0 0 0
        0  0 0 C S 0
        0  0 0 -S C 0
        0  0 0 0 0 1
    ]
    return kprime * T * u
end
```

Step by step:
1. `u_global = u` (given)
2. `u_local = T × u_global` (transform global → local)
3. `f_local = k' × u_local` (multiply by local stiffness)

Output: `[axial₁, shear₁, moment₁, axial₂, shear₂, moment₂]`

### For a horizontal beam (θ=0):

T = I, so f_local = k' × u. With only axial extension (u₁ = 0, u₂ = δ):

```
f = [EA/L × δ, 0, 0, −EA/L × δ, 0, 0]
```

Only axial forces — no bending (as expected from a purely axial displacement).

### For a cantilever tip deflection (u = [0, 0, 0, 0, −δ, 0]):

```
f = [0, 12EI/L³×(−δ), 6EI/L²×(−δ), 0, −12EI/L³×(−δ), 6EI/L²×(−δ)]
  = [0, −12EIδ/L³, −6EIδ/L², 0, 12EIδ/L³, −6EIδ/L²]
```

Shear at both ends + moment — pure bending response.

---

## 7.6 Assembly: 3 DOF/node

```julia
function d2_planeframe_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
```

Slot mapping: **Node n → [3n−2, 3n−1, 3n]**

| Node n | UX | UY | RZ |
|--------|----|----|----|
| n | 3n−2 | 3n−1 | 3n |

Example: element between nodes 2 and 3 → global DOFs `[4, 5, 6, 7, 8, 9]`.

---

## 7.7 MATLAB ↔ Julia Mapping

| Operation | Kattan MATLAB | LibFEM.jl Julia | Source |
|-----------|--------------|-----------------|--------|
| Length | `PlaneFrameElementLength(x1,y1,x2,y2)` | `d2_planeframe_elementlength(x1,y1,x2,y2)` | `beam.jl:98-100` |
| Stiffness | `PlaneFrameElementStiffness(E,A,I,L,θ)` | `d2_planeframe_elementstiffness(E,A,I,L,θ)` | `beam.jl:118-136` |
| Forces | `PlaneFrameElementForces(E,A,I,L,θ,u)` | `d2_planeframe_elementforces(E,A,I,L,θ,u)` | `beam.jl:155-170` |
| Local k' | *(inline)* | `_d2_planeframe_kprime(E,A,I,L)` | `assembly.jl:50-64` |
| Assembly | `PlaneFrameAssemble(K,k,i,j)` | `d2_planeframe_assemble(K,k,i,j)` | `beam.jl:187-189` |
| Axial diagram | `PlaneFrameElementAxialDiagram(f,L)` | `d2_planeframe_elementaxialdiagram(f,L)` | `ext/LibFEMPlotsExt.jl:72` |
| Shear diagram | `PlaneFrameElementShearDiagram(f,L)` | `d2_planeframe_elementsheardiagram(f,L)` | `ext/LibFEMPlotsExt.jl:88` |
| Moment diagram | `PlaneFrameElementMomentDiagram(f,L)` | `d2_planeframe_elementmomentdiagram(f,L)` | `ext/LibFEMPlotsExt.jl:104` |

The Julia expanded stiffness formula is **identical** to Kattan's MATLAB (`PlaneFrameElementStiffness.m`):

```matlab
% MATLAB (Kattan)
w1 = A*C*C + 12*I*S*S/(L*L);
w2 = A*S*S + 12*I*C*C/(L*L);
w3 = (A-12*I/(L*L))*C*S;
w4 = 6*I*S/L;
w5 = 6*I*C/L;
y = E/L*[w1 w3 -w4 -w1 -w3 -w4 ; ...];
```

---

## 7.8 Diagram Functions

Three plotting functions (Julia extension, requires `Plots.jl`):

```julia
d2_planeframe_elementaxialdiagram(f, L)   # axial force along element
d2_planeframe_elementsheardiagram(f, L)   # shear force along element
d2_planeframe_elementmomentdiagram(f, L)  # bending moment along element
```

Each takes the 6-element force vector `f = [axial₁, shear₁, moment₁, axial₂, shear₂, moment₂]` from `d2_planeframe_elementforces` and plots the corresponding diagram over length L.

The diagram functions extract from f:
```
axial value  = -f[1] at start,  f[4] at end
shear value  =  f[2] at start, -f[5] at end
moment value = -f[3] at start,  f[6] at end
```

---

## 7.9 Special Cases

### θ = 0° (horizontal beam aligned with X-axis)

T = I, so the global matrix equals the local matrix:

```
k = k' = diag(EA/L × [1 -1; -1 1],  EI/L³ × beam_4×4)
```

**No coupling between UX and UY/RZ.** A horizontal force only produces axial displacement; a vertical force only produces bending.

### θ = 90° (vertical beam aligned with Y-axis)

C=0, S=1. The expanded matrix couples UX with bending:

```
w₁ = A·0 + 12·I·1/L² = 12I/L²       # UX stiffness from bending
w₂ = A·1 + 12·I·0/L² = A             # UY stiffness from axial
w₃ = (A − 12I/L²)·0·1 = 0           # no UX-UY coupling
w₄ = 6·I·1/L = 6I/L                  # shear from rotation (UX→RZ)
w₅ = 6·I·0/L = 0                     # no moment coupling (UX→RZ)
```

A vertical force produces both axial extension **and** bending at the rotated section!

---

## 7.10 Worked Example: Two-Bar Frame

Consider an L-shaped frame:

```
(0,0) ──── L₁ ──── (L₁,0)   E, A, I (same both)
                    │
                    │ L₂
                    │
                  (L₁,−L₂)
```

Using the same assembly pattern as trusses:

```julia
using LibFEM

E, A, I = 200e9, 0.01, 2e-4
L1, L2 = 4.0, 3.0

# Element 1: horizontal (θ=0°)
k1 = d2_planeframe_elementstiffness(E, A, I, L1, 0)
# Element 2: vertical (θ=−90° or 270°)
k2 = d2_planeframe_elementstiffness(E, A, I, L2, -90)

K = zeros(9, 9)    # 3 nodes × 3 DOF
K = d2_planeframe_assemble(K, k1, 1, 2)
K = d2_planeframe_assemble(K, k2, 2, 3)

# Apply BCs and solve K·U = F ...
```

---

## 7.11 Test Coverage

The `d2_planeframe` test block (`runtests.jl:377-472`) covers:

| Test | What it checks |
|------|---------------|
| `elementlength` | 3-4-5 triangle, zero-length throws |
| `elementstiffness` | 6×6, θ=0 known values (w₁=1, w₂=12, w₄=0, w₅=6, I=1) |
| `elementforces` | Axial-only displacement → only axial forces |
| `elementaxialdiagram` | Returns `Plots.Plot` |
| `elementsheardiagram` | Returns `Plots.Plot` |
| `elementmomentdiagram` | Returns `Plots.Plot` |
| `assemble` | Block placement, non-symmetric verification |
| `L>0 error paths` | L=0, L<0 throw |
| `negative/zero A` | A=0, A<0 throw |

Plus property-based tests (`property_tests.jl:67-74`): symmetry check for random `(E, A, I, L, θ)`.

---

## 7.12 Summary

| Concept | Takeaway |
|---------|----------|
| Physics | **Axial + bending superposition** — 2 elements in one |
| DOF/node | **3** — UX, UY, RZ |
| Local k' | 6×6, block diagonal (bar ⊕ beam) |
| Global k | **Expanded formula** w₁–w₅ (Tᵀk'T, no matrix multiply) |
| Axial terms | w₁, w₂, w₃ (involve A only if θ=0, else mix with I/L²) |
| Bending terms | w₄, w₅ (involve I/L only) |
| Rotation coupling | The RZ DOF is **not rotated** — same in local and global |
| Force output | `[axial₁, shear₁, moment₁, axial₂, shear₂, moment₂]` **in local frame** |
| Assembly | `_assemble!(..., ndofs=3)` — same as 3D truss |
| Diagrams | Axial, shear, moment (Plots.jl extension) |

### The family so far

| Lesson | Element | DOF/n | Matrix | Governing params |
|--------|---------|-------|--------|-----------------|
| 2 | 1D Spring | 1 | 2×2 | k |
| 3 | 1D Bar | 1 | 2×2 | EA |
| 4 | Quadratic Bar | 1 | 3×3 | EA |
| 5 | 2D Truss | 2 | 4×4 | EA |
| 6 | 3D Truss | 3 | 6×6 | EA |
| **7** | **2D Plane Frame** | **3** | **6×6** | **EA + EI** |

### Full API

```julia
d2_planeframe_elementlength(x1, y1, x2, y2)                              # → L
d2_planeframe_elementstiffness(E, A, I, L, theta)                        # → 6×6
d2_planeframe_elementforces(E, A, I, L, theta, u)                        # → [axial₁, shear₁, moment₁, axial₂, shear₂, moment₂]
d2_planeframe_elementaxialdiagram(f, L)                                   # → Plots.Plot
d2_planeframe_elementsheardiagram(f, L)                                   # → Plots.Plot
d2_planeframe_elementmomentdiagram(f, L)                                  # → Plots.Plot
d2_planeframe_assemble(K, k, i, j)                                        # → updated K
```

**Coming up in Lesson 8**: The Pure Beam (Ch8) — bending-only, 4×4 element with 2 DOF/node (transverse displacement + rotation), the foundation of the beam block inside the plane frame.
