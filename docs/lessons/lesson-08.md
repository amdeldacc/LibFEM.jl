# Lesson 8: The Pure Beam Element — Bending Without Stretching

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 8
> Mapped to LibFEM.jl — `src/beam.jl` (lines 1–71), `ext/LibFEMPlotsExt.jl`

**Prerequisite**: Lesson 7 (Plane Frame — the 6×6 frame contains the 4×4 beam as its bending block)

---

## 8.1 The Pure Beam Concept

A **pure beam** carries only transverse loads — no axial force. Each node has 2 DOFs:

| DOF | Meaning | Unit |
|-----|---------|------|
| v | Transverse deflection (UY) | m |
| θ = dv/dx | Rotation/slope about Z-axis (RZ) | rad |

The beam is based on **Euler-Bernoulli theory**: cross-sections remain plane and perpendicular to the neutral axis (no shear deformation). This assumes slenderness: **L/h ≫ 1**.

### From Euler-Bernoulli to the 4×4 Matrix

The transverse deflection v(x) along the beam is interpolated using **cubic Hermite shape functions** — C¹ continuous (matching both value and slope at nodes):

```
v(x) = N₁(ξ)·v₁ + N₂(ξ)·θ₁ + N₃(ξ)·v₂ + N₄(ξ)·θ₂
```

where ξ = x/L and:

```
N₁(ξ) = 1 − 3ξ² + 2ξ³       (unit deflection at node 1)
N₂(ξ) = L·(ξ − 2ξ² + ξ³)   (unit rotation at node 1)
N₃(ξ) = 3ξ² − 2ξ³           (unit deflection at node 2)
N₄(ξ) = L·(−ξ² + ξ³)        (unit rotation at node 2)
```

The stiffness matrix is the integral of the **curvature** squared:

```
k_ij = ∫₀ᴸ EI · N''_i(ξ) · N''_j(ξ) dx
```

Rather than evaluating every integral, the final 4×4 matrix has a beautiful closed form:

```
            ┌                        ┐
            │  12    6L    -12    6L  │
k = EI/L³ × │  6L   4L²   -6L   2L²  │
            │ -12   -6L    12   -6L   │
            │  6L   2L²   -6L   4L²   │
            └                        ┘
```

**DOF order**: [v₁, θ₁, v₂, θ₂]

This is arguably the most recognizable matrix in structural FEM.

---

## 8.2 Anatomy of the 4×4

Factor out EI/L³. The remaining matrix has dimension L²:

```
k(1,1) = 12     →  force at node 1 from v₁=1
k(2,1) = 6L     →  moment at node 1 from v₁=1
k(2,2) = 4L²    →  moment at node 1 from θ₁=1
k(3,2) = −6L    →  force at node 2 from θ₁=1
k(3,3) = 12     →  force at node 2 from v₂=1
k(4,4) = 4L²    →  moment at node 2 from θ₂=1
```

### Column-by-column interpretation (E=I=L=1)

| Column | Load | Produces | Signs |
|--------|------|----------|-------|
| **Col 1**: v₁=1 | Upward force at node 1 | v₁ up, v₂ down (reaction), moments at both ends pulling back | +12, +6, −12, +6 |
| **Col 2**: θ₁=1 | Counterclockwise rotation at node 1 | v₂ down, counterclockwise θ₂, moments opposing | +6, +4, −6, +2 |
| **Col 3**: v₂=1 | Upward force at node 2 | v₁ down, v₂ up, moments at both ends | −12, −6, +12, −6 |
| **Col 4**: θ₂=1 | Counterclockwise rotation at node 2 | v₁ down, clockwise θ₁, moments opposing | +6, +2, −6, +4 |

### The 4EI/L vs 2EI/L ratio

```
k(2,2) = 4EI/L    →  moment to produce unit rotation at node 1 (node 2 fixed)
k(4,4) = 4EI/L    →  moment to produce unit rotation at node 2 (node 1 fixed)
k(2,4) = 2EI/L    →  moment at node 1 from unit rotation at node 2
```

**4:1 ratio**: It takes twice the moment to produce a rotation when the opposite end is fixed (4EI/L) vs pinned (2EI/L from the off-diagonal). This is the **carry-over factor** of 0.5 — classic moment distribution.

---

## 8.3 In LibFEM.jl — Side by Side with MATLAB

### Stiffness

LibFEM.jl (`beam.jl:28-36`):

```julia
function d2_beam_elementstiffness(E::Real, I::Real, L::Real)
    validate_positive(L, "L")
    return E * I / (L^3) * [
         12    6*L   -12    6*L
          6*L  4*L^2  -6*L  2*L^2
        -12   -6*L    12   -6*L
          6*L  2*L^2  -6*L  4*L^2
    ]
end
```

Kattan's MATLAB (`BeamElementStiffness.m`):

```matlab
function y = BeamElementStiffness(E,I,L)
    y = E*I/(L*L*L)*[12 6*L -12 6*L ; 6*L 4*L*L -6*L 2*L*L ;
       -12 -6*L 12 -6*L ; 6*L 2*L*L -6*L 4*L*L];
end
```

**Identical**. The only Julia addition is `validate_positive(L, "L")`.

### Forces

LibFEM.jl (`beam.jl:50-52`):

```julia
function d2_beam_elementforces(k::AbstractMatrix, u::AbstractVector)
    return k * u
end
```

Kattan MATLAB:

```matlab
function y = BeamElementForces(k,u)
    y = k * u;
end
```

**Identical**. Output: [shear₁, moment₁, shear₂, moment₂].

### Assembly

LibFEM.jl (`beam.jl:69-71`):

```julia
function d2_beam_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end
```

Kattan MATLAB (`BeamAssemble.m`): 16 explicit assignments with `2*i-1, 2*i` etc.

**Julia**: one-liner via `_assemble!` with `ndofs=2`.

---

## 8.4 The Key Difference: No Transformation

Unlike trusses (Ch5, Ch6) and frames (Ch7), the **beam element does NOT need coordinate transformation**:

| Element | DOF/node | Transformation needed? | Why |
|---------|----------|----------------------|-----|
| 2D Truss | 2 (UX, UY) | **Yes** — rotation T(θ) | Element axis ≠ global axis |
| 2D Plane Frame | 3 (UX, UY, RZ) | **Yes** — rotation T(θ) | Same reason |
| **2D Pure Beam** | **2 (v, θ)** | **No** | Always horizontal, local = global |

The pure beam always lives in its local coordinate system with the beam axis along the global X-axis. For beams at arbitrary angles, use the **plane frame element** (Ch7) — which is exactly the beam + bar with transformation.

**Practical rule**: Single beam → use `d2_beam`. Angled or connected frame → use `d2_planeframe`.

---

## 8.5 The 4×4 Beam — Subset of the 6×6 Frame

The 4×4 beam matrix is literally the **bending block** inside the 6×6 frame matrix. Compare:

```
Frame local k' (6×6):           Beam k (4×4):
                                 
[EA/L  0   0  -EA/L  0   0 ]    [12EI/L³  6EI/L²  -12EI/L³  6EI/L²]
[0   12EI/L³ 6EI/L² 0 -12EI/L³ 6EI/L²]   [6EI/L²  4EI/L   -6EI/L²  2EI/L ]
[0   6EI/L² 4EI/L 0 -6EI/L² 2EI/L ]  =  [-12EI/L³ -6EI/L²  12EI/L³ -6EI/L²]
[-EA/L 0  0  EA/L  0   0 ]    [6EI/L²  2EI/L   -6EI/L²  4EI/L ]
[0  -12EI/L³ -6EI/L² 0 12EI/L³ -6EI/L²]   ↑      ↑        ↑       ↑
[0   6EI/L² 2EI/L 0 -6EI/L² 4EI/L ]     Submatrix rows 2-3, cols 2-3,5-6
```

The beam matrix = frame k' with axial rows/cols (1, 4) removed.

---

## 8.6 Nodal Forces & Equilibrium

The force output `f = [V₁, M₁, V₂, M₂]` must satisfy **static equilibrium**:

```
V₁ + V₂ = 0              (sum of vertical forces = 0)
M₁ + M₂ + V₂·L = 0       (sum of moments = 0)
```

Check with the cantilever example (v₂ = 1, θ₂ = 0):

```julia
k = d2_beam_elementstiffness(1, 1, 1)
f = k * [0, 0, 1, 0]    # → [−12, −6, 12, −6]
```

Verify:
```
V₁ + V₂ = −12 + 12 = 0 ✓
M₁ + M₂ + V₂·L = −6 + (−6) + 12·1 = 0 ✓
```

---

## 8.7 Distributed Loads (Equivalent Nodal Forces)

For a uniformly distributed load w (force/length), the work-equivalent nodal forces are:

```
f_eq = [wL/2, wL²/12, wL/2, −wL²/12]
```

| Entry | Value | Physical meaning |
|-------|-------|-----------------|
| f₁ | wL/2 | Vertical force at node 1 |
| f₂ | wL²/12 | Moment at node 1 (positive = CCW) |
| f₃ | wL/2 | Vertical force at node 2 |
| f₄ | −wL²/12 | Moment at node 2 (negative = CW) |

These are **exact** for uniform loading — a single beam element gives the exact midspan deflection:

```
v_max = 5wL⁴/384EI
```

Note: Kattan provides `BeamElementDistributedLoad(w, L)` for this. LibFEM.jl does not implement this as a separate function (the user constructs the load vector directly). Kattan's MATLAB:

```matlab
function y = BeamElementDistributedLoad(w, L)
    y = [w*L/2; w*L*L/12; w*L/2; -w*L*L/12];
end
```

### Worked procedure: simply supported beam with UDL

```
Step 1: k = d2_beam_elementstiffness(E, I, L)
Step 2: f_eq = [w*L/2, w*L²/12, w*L/2, -w*L²/12]
Step 3: Apply BCs (v₁=0, v₂=0): remove rows 1,3
Step 4: Solve [k(2,2) k(2,4); k(4,2) k(4,4)] × [θ₁; θ₂] = [f_eq(2); f_eq(4)]
Step 5: θ₁ = wL³/24EI,  θ₂ = −wL³/24EI  (equal and opposite)
Step 6: Recover reactions by back-substitution
```

---

## 8.8 MATLAB ↔ Julia Mapping

| Operation | Kattan MATLAB | LibFEM.jl Julia | Source |
|-----------|--------------|-----------------|--------|
| Stiffness | `BeamElementStiffness(E,I,L)` | `d2_beam_elementstiffness(E,I,L)` | `beam.jl:28-36` |
| Forces | `BeamElementForces(k,u)` | `d2_beam_elementforces(k,u)` | `beam.jl:50-52` |
| Distributed load | `BeamElementDistributedLoad(w,L)` | *(manual)* | Kattan MATLAB |
| Assembly | `BeamAssemble(K,k,i,j)` | `d2_beam_assemble(K,k,i,j)` | `beam.jl:69-71` |
| Shear diagram | `BeamElementShearDiagram(f,L)` | `d2_beam_elementsheardiagram(f,L)` | `ext/...:37` |
| Moment diagram | `BeamElementMomentDiagram(f,L)` | `d2_beam_elementmomentdiagram(f,L)` | `ext/...:53` |

### DOF slot mapping

```
Node n → [2n−1, 2n]   (v at 2n−1, θ at 2n)
```

| Node | v | θ |
|------|----|----|
| 1 | 1 | 2 |
| 2 | 3 | 4 |
| n | 2n−1 | 2n |

---

## 8.9 Diagram Functions

The two diagram functions (Julia extension, requires `Plots.jl`) use the `_beamdiagram` helper:

```julia
d2_beam_elementsheardiagram(f, L)    # shear force: [f[1], -f[3]]
d2_beam_elementmomentdiagram(f, L)   # bending moment: [-f[2], f[4]]
```

Where f = [V₁, M₁, V₂, M₂] from `d2_beam_elementforces`.

---

## 8.10 Special Cases

### L → 0 (Length approaching zero)

The 12EI/L³, 6EI/L², 4EI/L, 2EI/L terms all blow up. This is **shear locking** — an element with vanishing length becomes infinitely stiff in bending. Physically meaningless. Always keep L > 0 (enforced by `validate_positive`).

### I → 0 (No moment of inertia)

The entire matrix becomes zero — no bending stiffness. This is the beam equivalent of a "pin" joint for rotation.

### Single-element exactness for UDL

The cubic Hermite shape functions span **all cubic polynomials**. Since the Euler-Bernoulli beam equation `EI·v'''' = w(x)` integrates to a cubic for a constant w (UDL), a single element captures the deflection field exactly — at the nodes **and** at midspan.

---

## 8.11 Test Coverage

The `d2_beam` test block (`runtests.jl:310-374`) covers:

| Test | What it checks |
|------|---------------|
| `elementstiffness` | 4×4 shape, (E=I=L=1) matches expected, (E=2,I=3,L=4) scaled |
| `elementforces` | v₂=1 → [−12, −6, 12, −6], zero displacement → zero |
| `assemble` | Block placement, unused entries zero |
| `L>0 error paths` | L=0, L<0 throw |
| `elementsheardiagram` | Returns `Plots.Plot` |
| `elementmomentdiagram` | Returns `Plots.Plot` |
| `@test_physical_invariants` | Symmetry + positive semi-definiteness |

Plus property-based tests (`property_tests.jl:50-55`): symmetry for random `(E, I, L)`.

Plus Kattan problem definitions in `lib/problem_definitions.jl`:
- Problem 7.1: 2-element beam
- Problem 7.2: 3-element beam with distributed load
- Problem 7.3: Beam with spring support

---

## 8.12 Summary

| Concept | Takeaway |
|---------|----------|
| Theory | **Euler-Bernoulli** — plane sections remain plane, no shear deformation |
| DOF/node | **2** — v (transverse), θ (rotation/slope) |
| Matrix | **4×4** — EI/L³ × the distinctive patterned matrix |
| Shape functions | **Cubic Hermite** — C¹ continuous, exact for cubic deflections |
| Transformation | **None** — always in local/global aligned coordinates |
| Key ratio | **4EI/L vs 2EI/L** — carry-over factor = 1/2 |
| Forces | [V₁, M₁, V₂, M₂] — f = k × u |
| Distributed loads | f_eq = [wL/2, wL²/12, wL/2, −wL²/12] |
| Exact for UDL | Single element → exact midspan deflection |
| Assembly | `_assemble!(..., ndofs=2)` |
| Relationship | **Beam = frame minus axial DOF** |

### Full API

```julia
d2_beam_elementstiffness(E, I, L)                        # → 4×4
d2_beam_elementforces(k, u)                              # → [V₁, M₁, V₂, M₂]
d2_beam_elementsheardiagram(f, L)                        # → Plots.Plot
d2_beam_elementmomentdiagram(f, L)                       # → Plots.Plot
d2_beam_assemble(K, k, i, j)                             # → updated K
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
| **8** | **2D Pure Beam** | **2** | **4×4** | **EI only** |

### The Relationship Diagram

```
Bar (Ch3)     +     Beam (Ch8)       =     Plane Frame (Ch7)
 ┌─  ─┐            ┌─  ─  ─┐              ┌─  ─  ─  ─┐
 │    │            │       │              │  axial   │
 │ EA │            │  EI   │              │  block   │
 │ L  │            │  ...  │              ├─  ─  ─  ─┤
 │    │            │       │              │  bending │
 └─  ─┘            └─  ─  ─┘              │  block   │
 2×2 axial         4×4 bending            └─  ─  ─  ─┘
                                             6×6 frame
```

The beam element (Ch8) provides the bending core. The plane frame (Ch7) adds axial capacity and transformation for arbitrary orientation. Knowing the beam is the prerequisite for understanding frame behavior.

**Coming up in Lesson 9**: The 3D Space Frame (Ch9) — 6 DOF/node, 12×12 matrix, axial + bending + torsion.
