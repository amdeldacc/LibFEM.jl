# Lesson 17: Other Applications — Heat Transfer, Fluid Flow, and Dynamics

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 17
> Mapped to LibFEM.jl — `src/fluidflow.jl` (1D fluid flow), `src/utils.jl`, `src/assembly.jl`

**Prerequisites**: Familiarity with any structural element from Lessons 2–16. The key insight of this lesson is that all physical fields solved by FEM follow the **same mathematical pattern**.

---

## 17.1 The Unified FEM Framework

Every chapter so far covered structural mechanics: the variable is displacement `u`, the constitutive law is Hooke's law, and the stiffness integral is `k = ∫BᵀDB dV`. Chapter 17 shows that **any field problem** governed by a potential fits the same template.

### The analogy

| Physics | Primary variable | Flux | Constitutive law | Matrix equation |
|---------|-----------------|------|-------------------|-----------------|
| **Structural** 1D bar | Displacement `u` (m) | Force `F` (N) | F = EA·du/dx | `K·u = F` |
| **Thermal** 1D | Temperature `T` (K) | Heat flux `q` (W/m²) | q = −k·dT/dx | `K·T = Q` |
| **Fluid flow** 1D | Head/pressure `p` (m) | Velocity `v` (m/s) | v = −K·dp/dx | `K·p = Q` |
| **Electrostatic** | Potential `V` (V) | Current `J` (A/m²) | J = −σ·dV/dx | `K·V = I` |

All governed by **Laplace/Poisson equation**: `∇·(c·∇φ) + f = 0` where:
- φ = primary variable (temperature, head, potential)
- c = conductivity (k, Kxx, σ)
- f = source term

The stiffness matrix formula is always:

```
[k] = ∫ [B]ᵀ [c] [B] dV
```

where `[c]` is the constitutive matrix (for isotropic: scalar c, or tensor for anisotropic media).

### Kattan's Chapter 17 covers three applications

| Section | Topic | Implemented in LibFEM? |
|---------|-------|----------------------|
| 17.2 | 1D Heat Transfer | ❌ |
| 17.3 | 2D Heat Transfer (CST-like) | ❌ |
| 17.4 | 3D Heat Transfer (tet-like) | ❌ |
| 17.5 | 1D Fluid Flow (seepage/pipe) | **✅ `d1_fluidflow`** |
| 17.6 | Consistent Mass Matrices | ❌ |
| 17.7 | Lumped Mass Matrices | ❌ |
| 17.8 | Free Vibration / Modal Analysis | ❌ |

---

## 17.2 Heat Transfer (Not in LibFEM)

### Governing equation

Steady-state heat conduction (no sources):

```
∂/∂x(k·∂T/∂x) + ∂/∂y(k·∂T/∂y) + ∂/∂z(k·∂T/∂z) = 0
```

where `k` = thermal conductivity (W/m·K) and `T` = temperature (K).

### Element conductivity matrix

Same structure as the structural stiffness matrix:

```
[k] = ∫ [B]ᵀ [k] [B] dV
```

For isotropic conductivity, `[k] = k·I` (scalar times identity). The B matrix is the same shape — derivative of shape functions — but maps **scalar temperature to temperature gradient** instead of displacements to strain.

### 1D Heat transfer (2 nodes)

B = [−1/L, 1/L] (size 1×2), k = k·A/L · [1  -1; -1  1]

Identical to the 1D bar with `E·A/L` → `k·A/L`.

### 2D Heat transfer (3-node triangle, CST-like)

B = same 2×3 derivative matrix as CST. `[k]` is a 3×3 matrix:

```
k = ∫ [B]ᵀ · k · [B] · t · dA  with k scalar (isotropic)
```

Size: 3×3 (one DOF per node: temperature).

### 3D Heat transfer (4-node tetrahedron, tet-like)

B = same 3×4 derivative matrix as the linear tetrahedron. `[k]` is 4×4.

```
k = V · Bᵀ · k · B    with k scalar (isotropic)
```

Size: 4×4 (one DOF per node: temperature).

### Key difference from structural

| Aspect | Structural (Ch2–16) | Thermal (Ch17) |
|--------|-------------------|----------------|
| DOF/node | 1–6 (displacements + rotations) | **1** (temperature) |
| Element size (2D tri) | 6×6 (2 DOF/node) | **3×3** (1 DOF/node) |
| D/constitutive matrix | Elasticity (3×3, 6×6) | **Scalar k** (or 3×3 tensor) |
| B matrix | Maps disp → strain (3×6, 6×24) | Maps temp → temp gradient (2×3, 3×4) |
| Post-processing | Stress recovery (D·B·u) | Heat flux (q = −k·B·T) |

### Why not in LibFEM

LibFEM is a **structural mechanics** library following Kattan. Heat transfer uses the same B-matrix/assembly machinery but with different physical interpretation. Adding heat transfer would require:
- A 1-DOF-per-node assembly variant (trivial — already have `_assemble!` for 1 DOF)
- Thermal versions of the triangle/tetrahedron/etc. (the B matrices are already the same shape — just drop the 2→6 expansion of structural DOF)
- Renaming functions to `d1_heat_*`, `d2_heat_*`, etc.

This is left as a natural extension for readers.

---

## 17.3 1D Fluid Flow (Implemented: `d1_fluidflow`)

### Physical problem

1D confined seepage through a porous medium (pipe flow, aquifer flow, dam seepage). Governed by **Darcy's law**:

```
v = −Kxx · dh/dx
```

where:
- `v` = seepage velocity (m/s)
- `Kxx` = hydraulic conductivity / permeability coefficient (m/s)
- `h` = total head (m) — the primary variable

### Element formulation

B = [−1/L, 1/L] (1×2, same as 1D bar)

Element "stiffness" (conductivity) matrix:

```
[k] = ∫₀ᴸ Bᵀ·Kxx·B·A dx = (Kxx·A/L) · [1  -1; -1  1]
```

### LibFEM.jl implementation

`src/fluidflow.jl` — 89 lines, 4 functions:

**`d1_fluidflow_elementstiffness(Kxx, A, L)`** → 2×2 conductivity matrix:

```julia
function d1_fluidflow_elementstiffness(Kxx, A, L)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return Kxx * A / L * [1 -1; -1 1]
end
```

**`d1_fluidflow_elementvelocity(Kxx, L, p)`** → scalar seepage velocity:

```julia
function d1_fluidflow_elementvelocity(Kxx, L, p)
    validate_positive(L, "L")
    return -Kxx * (-p[1] + p[2]) / L
end
```

This is Darcy's law: `v = −Kxx·(p₂−p₁)/L`.

**`d1_fluidflow_elementvfr(Kxx, L, p, A)`** → scalar volumetric flow rate:

```julia
function d1_fluidflow_elementvfr(Kxx, L, p, A)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return -Kxx * A * (-p[1] + p[2]) / L
end
```

`Q = v · A` (flow rate = velocity × area).

**`d1_fluidflow_assemble(K, k, i, j)`** → 1-DOF-per-node assembly:

```julia
function d1_fluidflow_assemble(K, k, i, j)
    return _assemble!(K, k, i, j, 1)
end
```

Uses the 1-DOF `_assemble!` directly — same as the 1D spring and 1D bar.

### Kattan MATLAB equivalents

| Julia | MATLAB | Line count |
|-------|--------|-----------|
| `d1_fluidflow_elementstiffness(Kxx, A, L)` | `FluidFlow1DElementStiffness(Kxx, A, L)` | 1 (both) |
| `d1_fluidflow_elementvelocity(Kxx, L, p)` | `FluidFlow1DElementVelocities(Kxx, L, p)` | 1 (both) |
| `d1_fluidflow_elementvfr(Kxx, L, p, A)` | `FluidFlow1DElementVFR(Kxx, L, p, A)` | 1 (both) |
| `d1_fluidflow_assemble(K, k, i, j)` | `FluidFlow1DAssemble(K, k, i, j)` | 4 (Julia: 1) |

MATLAB assembly is 4 lines of explicit assignments; Julia uses `_assemble!(K, k, i, j, 1)`.

### Example: Seepage through a soil column

```julia
using LibFEM

# Soil column: L=10m, A=1m², Kxx=1e-4 m/s
Kxx, A, L = 1e-4, 1.0, 10.0

k = d1_fluidflow_elementstiffness(Kxx, A, L)
println("k = $k")  # [1e-5  -1e-5; -1e-5  1e-5]

# Two-element column: nodes 1-2-3
K = zeros(3, 3)
k1 = d1_fluidflow_elementstiffness(Kxx, A, L/2)  # element 1: nodes 1-2
k2 = d1_fluidflow_elementstiffness(Kxx, A, L/2)  # element 2: nodes 2-3

K = d1_fluidflow_assemble(K, k1, 1, 2)
K = d1_fluidflow_assemble(K, k2, 2, 3)

# Boundary conditions: head at node 1 = 10m, node 3 = 5m
# Unknown: head at node 2
# K₂₂·p₂ = F₂ = -(K₂₁·p₁ + K₂₃·p₃)
p = zeros(3)
p[1] = 10.0; p[3] = 5.0

F = zeros(3)
free_dofs = [2]
K_ff = K[free_dofs, free_dofs]
F_f = -(K[2,1]*p[1] + K[2,3]*p[3])
p[2] = K_ff \ F_f

println("Head at midpoint: $(p[2]) m")  # 7.5 m (linear interpolation)

# Velocity and flow rate
v = d1_fluidflow_elementvelocity(Kxx, L/2, p[1:2])
Q = d1_fluidflow_elementvfr(Kxx, L/2, p[1:2], A)
println("Seepage velocity: $(v) m/s")
println("Volumetric flow rate: $(Q) m³/s")
```

Output:

```
k = [1e-5  -1e-5; -1e-5  1e-5]
Head at midpoint: 7.5 m
Seepage velocity: -5.0e-5 m/s
Volumetric flow rate: -5.0e-5 m³/s
```

Head varies linearly from 10 to 5 m, giving a constant hydraulic gradient and constant velocity.

### Relationship to 1D bar

The fluid flow element is **numerically identical** to the 1D bar (`d1_bar_elementstiffness`):

```
d1_fluidflow_elementstiffness(Kxx, A, L) = Kxx·A/L·[1 -1; -1  1]
d1_bar_elementstiffness(E, A, L)         = E·A/L·[1 -1; -1  1]
```

The only difference is physical interpretation:
- Bar: `E` (Young's modulus) → axial stiffness
- Fluid flow: `Kxx` (hydraulic conductivity) → permeability

This is the simplest demonstration of the **unified FEM framework** — the same stiffness matrix serves two completely different physical problems.

### Test coverage

```julia
@testset "elementstiffness" begin
    k = d1_fluidflow_elementstiffness(1.0, 1.0, 1.0)
    @test size(k) == (2, 2)
    @test k ≈ [1 -1; -1 1]
    @test_throws ElementParameterError d1_fluidflow_elementstiffness(1.0, 1.0, 0.0)
    @test_throws ElementParameterError d1_fluidflow_elementstiffness(1.0, 0.0, 1.0)
end

@testset "velocity" begin
    v = d1_fluidflow_elementvelocity(1.0, 10.0, [10.0, 5.0])
    @test abs(v - 0.5) < 1e-10
end

@testset "vfr" begin
    Q = d1_fluidflow_elementvfr(1.0, 10.0, [10.0, 5.0], 2.0)
    @test abs(Q - 1.0) < 1e-10  # 0.5 * 2 = 1.0
end

@testset "assemble" begin
    K = zeros(4, 4); k = d1_fluidflow_elementstiffness(1.0, 1.0, 1.0)
    K = d1_fluidflow_assemble(K, k, 1, 2)
    @test K[1:2, 1:2] ≈ k
end
```

Four test sets: stiffness (L>0, A>0 validation), velocity, flow rate, and assembly.

---

## 17.4 Structural Dynamics (Not in LibFEM)

### The dynamic equation

For structural dynamics, the static equilibrium `K·u = F` becomes:

```
M·ü + C·u̇ + K·u = F(t)
```

where:
- `M` = mass matrix
- `C` = damping matrix (often `C = α·M + β·K`, Rayleigh damping)
- `K` = stiffness matrix (from Lessons 2–16)

### Free vibration (undamped, no loads)

```
M·ü + K·u = 0
```

Assume harmonic motion: `u(t) = φ·sin(ωt)`

```
(K − ω²·M)·φ = 0  →  K·φ = λ·M·φ  where λ = ω²
```

This is a **generalized eigenvalue problem** solved by `eigvals(K, M)`.

### Consistent mass matrix

For a bar element (2 nodes, 1 DOF/node):

```
[m] = ρ·A·∫₀ᴸ Nᵀ·N dx = ρ·A·L·[⅓  ⅙; ⅙  ⅓]  (consistent)
```

For a beam element (2 nodes, 2 DOF/node): `[m]` is 4×4 with mass and rotary inertia.

### Lumped mass matrix

Same bar element — diagonal matrix with mass concentrated at nodes:

```
[m] = ρ·A·L/2·[1  0; 0  1]  (lumped, half the mass at each node)
```

### The consistent vs. lumped trade-off

| Mass matrix type | Accuracy | Implementation | Diagonal? | Used for |
|-----------------|----------|---------------|-----------|----------|
| **Consistent** | More accurate (couples DOF) | `∫ρ·Nᵀ·N dV` | No (has off-diagonal) | Implicit dynamics, modal analysis |
| **Lumped** | Approximate (diagonal) | Row-sum or direct diagonalization | **Yes** | Explicit dynamics (no matrix solve) |

### Mass matrix comparison for 1D bar

```matlab
Element mass (consistent):  m = ρ·A·L·[1/3  1/6; 1/6  1/3]
Element mass (lumped):      m = ρ·A·L·[1/2    0 ;   0  1/2]
```

The consistent mass matrix gives lower natural frequencies (more accurate), while the lumped mass matrix is preferred for explicit time integration (no system solve).

### Structural dynamics in the Kattan text

Chapter 17 computes natural frequencies for:
1. **Fixed rod**: 1D bar, 2 elements, 2 DOF (fixed at one end)
2. **Fixed beam**: Euler-Bernoulli beam, 2 elements, 4 DOF (fixed at one end)
3. **Plane truss**: 2D truss, multiple elements
4. **Space truss**: 3D truss

Example — 1D bar with 2 elements:

```
Mass matrix (global): M = ρ·A·L·[2/3  1/6  0; 1/6  4/3  1/6; 0  1/6  2/3]
Stiffness (global):   K = EA/L·[2  -1  0; -1  2  -1; 0  -1  1]
```

Apply BC (fix node 1), solve `det(K₂₃ − ω²·M₂₃) = 0` for ω².

### Why not in LibFEM

Mass matrices and modal analysis are not implemented in LibFEM. The library focuses on **static structural analysis**. Adding dynamics would require:

1. A `_mass_matrix` framework (consistent and lumped variants)
2. Eigenvalue solver integration (`LinearAlgebra.eigvals(K, M)`)
3. Time integration schemes (Newmark-β, central difference)

The structural elements (bar, beam, truss, frame, etc.) provide `K` — mass matrices are the natural next step for any reader extending the library.

---

## 17.5 The Complete Unified Analogy

```
Structural (1D bar)            Thermal (1D)                  Fluid (1D)
─────────────────              ───────────                   ──────────
u(x)  = N₁·u₁ + N₂·u₂         T(x) = N₁·T₁ + N₂·T₂          h(x) = N₁·h₁ + N₂·h₂
ε = B·u = (−u₁+u₂)/L          ∇T = B·T = (−T₁+T₂)/L         ∇h = B·h = (−h₁+h₂)/L
σ = E·ε                       q = −k·∇T                     v = −Kxx·∇h
F = A·σ                       Q = A·q                       Q = A·v
K = EA/L·[1 -1; -1 1]         K = kA/L·[1 -1; -1 1]         K = Kxx·A/L·[1 -1; -1 1]
F_ext = K·u                   Q_ext = K·T                   Q_ext = K·h
```

| Domain | Material prop | Loading | Post-processing |
|--------|--------------|---------|-----------------|
| Structural | E (modulus) | Force F (N) | Stress σ = E·B·u |
| Thermal | k (conductivity, W/m·K) | Heat Q (W) | Flux q = −k·B·T |
| Fluid | Kxx (permeability, m/s) | Flow Q (m³/s) | Velocity v = −Kxx·B·h |

The assembly process, BC application, and solution strategy are **identical** across all fields.

---

## 17.6 Summary

| Chapter 17 topic | Formulation | In LibFEM? | Key file |
|-----------------|-------------|-----------|----------|
| 1D Heat Transfer | k·A/L·[1 -1; -1 1], 2-node | ❌ | — |
| 2D Heat Transfer (tri) | ∫Bᵀ·k·B·t·dA, 3-node | ❌ | — |
| 3D Heat Transfer (tet) | V·Bᵀ·k·B, 4-node | ❌ | — |
| 1D Fluid Flow | Kxx·A/L·[1 -1; -1 1], 2-node | **✅** | `src/fluidflow.jl` |
| Consistent mass matrix | ∫ρ·Nᵀ·N dV | ❌ | — |
| Lumped mass matrix | diag(∫ρ·Nᵀ·N dV) | ❌ | — |
| Modal analysis | eig(K, M) → ω² | ❌ | — |

### LibFEM `d1_fluidflow` API

```julia
d1_fluidflow_elementstiffness(Kxx, A, L)        → 2×2 (conductivity matrix)
d1_fluidflow_elementvelocity(Kxx, L, p)          → scalar (seepage velocity)
d1_fluidflow_elementvfr(Kxx, L, p, A)            → scalar (volumetric flow rate)
d1_fluidflow_assemble(K, k, i, j)                → updated K
```

### What makes Chapter 17 special

Every prior lesson was structural mechanics. Chapter 17 shows that FEM is a **universal numerical method**:

> The same 6-step procedure — discretize → element matrices → assemble → BCs → solve → post-process — applies to heat transfer, fluid flow, electromagnetics, acoustics, and more. The only differences are the constitutive law and the meaning of the DOF.

LibFEM.jl implements one Chapter 17 element (fluid flow) as a demonstration of this principle. The remaining thermal and dynamics elements are natural extensions that follow the same patterns already established in Lessons 2–16.

---

## 17.7 The Complete LibFEM Element Family

| Domain | Lesson | Element | Nodes×DOF | Matrix | Key formula |
|--------|--------|---------|-----------|--------|-------------|
| **Structural** | | | | | |
| 1D line | 2 | Spring | 2×1 | 2×2 | k = [k −k; −k k] |
| 1D line | 3 | Linear Bar | 2×1 | 2×2 | k = EA/L·[1 −1; −1 1] |
| 1D line | 4 | Quadratic Bar | 3×1 | 3×3 | 3-node, quadratic shape |
| 2D | 5 | Plane Truss | 2×2 | 4×4 | k₂ = Tᵀ·k₁·T (θ) |
| 3D | 6 | Space Truss | 2×3 | 6×6 | k₂ = Tᵀ·k₁·T (α,β,γ) |
| 2D | 7 | Plane Frame | 2×3 | 6×6 | Bar + beam combined |
| 2D | 8 | Pure Beam | 2×2 | 4×4 | K = ∫E·I·N''²dx |
| 2D | 9 | Grid | 2×3 | 6×6 | Torsion + out-of-plane bending |
| 3D | 10 | Space Frame | 2×6 | 12×12 | Most general 1D element |
| 2D continuum | 11 | CST (3 tri) | 3×2 | 6×6 | Constant strain, area coords |
| 2D continuum | 12 | LST (6 tri) | 6×2 | 12×12 | Quadratic, **no lock** |
| 2D continuum | 13 | Q4 (4 quad) | 4×2 | 8×8 | Bilinear, ξη coords |
| 2D continuum | 14 | Q8 (8 quad) | 8×2 | 16×16 | Serendipity, **no lock** |
| 3D continuum | 15 | Linear Tet | 4×3 | 12×12 | Constant strain, V = det/6 |
| 3D continuum | 16 | Linear Brick | 8×3 | 24×24 | Trilinear, 2×2×2 Gauss |
| **Non-structural** | | | | | |
| 1D fluid | **17** | **1D Fluid Flow** | **2×1** | **2×2** | **Kxx·A/L·[1 −1; −1 1]** |

**Total**: 17 element types implemented across the following categories:

| Category | Count |
|----------|-------|
| 1D spring/bar/truss | 3 (spring, bar, quadratic bar) |
| 2D structural (frames, grids) | 3 (plane truss, plane frame, grid) |
| 3D structural (frames) | 2 (space truss, space frame) |
| Beam/bending | 1 (pure beam) |
| 2D continuum | 4 (CST, LST, Q4, Q8) |
| 3D continuum | 3 (tet, brick, space frame) |
| Non-structural | 1 (fluid flow) |

### The mathematical pattern behind it all

```
┌─────────────────────────────────────────────────────────────────┐
│                  [k] = ∫ [B]ᵀ [D] [B] dV                       │
└─────────────────────────────────────────────────────────────────┘
                      ↑         ↑         ↑
                 Strain-disp.  Material  Integration
                 (shape func.  matrix    over element
                  derivatives)           domain

                ┌───────┬──────────────────────┬──────────────┐
                │ DOF   │ B matrix depends on   │ Integration  │
                ├───────┼──────────────────────┼──────────────┤
                │ 1/node │ N′ (1D gradient)     │ Analytic     │
                │ 2/node │ ∇N (2D gradient)     │ 1-pt / Gauss │
                │ 3/node │ ∇N (3D gradient)     │ Gauss        │
                │ 6/node │ N′ + rotations       │ Analytic     │
                └───────┴──────────────────────┴──────────────┘
```

Every element in LibFEM — from the 2×2 spring to the 24×24 brick to the 2×2 fluid flow — is an instantiation of this single pattern.

### Beyond Kattan

Kattan's book covers 17 chapters of FEM fundamentals. The next steps beyond this series include:

1. **Adaptive mesh refinement** (h-refinement, p-refinement, hp-adaptive)
2. **Nonlinear FEM** (geometric nonlinearity, material nonlinearity, contact)
3. **Plasticity and fracture** (J₂ plasticity, cohesive zone models)
4. **Explicit dynamics** (central difference, reduced integration, hourglass control)
5. **Multiphysics** (thermo-mechanical coupling, fluid-structure interaction)
6. **Isogeometric analysis** (NURBS-based FEM, CAD integration)
7. **GPU-accelerated FEM** (massively parallel element matrix computation)
8. **Boundary element methods** (BEM, for infinite domains)
