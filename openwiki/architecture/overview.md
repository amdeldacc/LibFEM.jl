---
type: Architecture Overview
title: "Architecture Overview"
description: "LibFEM.jl module structure, naming conventions, dimension system, assembly helper, function inventory, testing, and extension points"
tags: ["architecture", "module-structure", "naming-convention", "assembly", "testing"]
resource: "/home/piou/LibFEM.jl/src"
---

# Architecture Overview

## Module Structure

LibFEM.jl is a single-module library with multi-file source organization. The module `src/LibFEM.jl` uses `include()` to compose files in `src/`:

| File | Contents |
|------|----------|
| `src/LibFEM.jl` | Module declaration, `include()` directives, `export` statements |
| `src/types.jl` | Abstract type hierarchy, `@kwdef` element structs |
| `src/errors.jl` | Custom error type definitions |
| `src/utils.jl` | `deg2rad` and shared helpers |
| `src/assembly.jl` | `_assemble!` private helper |
| `src/spring.jl` | All `d1/d2/d3_spring_*` implementations |
| `src/truss.jl` | All `d1/d2/d3_truss_*` implementations |
| `src/beam.jl` | All `d2_beam_*` (pure beam), `d2_planeframe_*` (plane frame), and `d3_beam_*` (space frame) implementations |
| `src/plot.jl` | Beam diagram functions (Plots dependency) |

```julia
module LibFEM
using Plots

# includes (types/errors/utils first, then element families)
include("types.jl")
include("errors.jl")
include("utils.jl")
include("assembly.jl")
include("spring.jl")
include("truss.jl")
include("beam.jl")
include("plot.jl")

# grouped exports follow...
end
```

**Exports**: All public functions are exported in grouped blocks. `deg2rad` is exported for external use. The helpers `_assemble!` and `_d3_beam_kprime` remain private (underscore prefix, not exported).

## Naming Convention

```
d{N}_{domain}_{operation}
```

| Component | Values | Description |
|-----------|--------|-------------|
| `{N}` | `1`, `2`, `3` | Dimensionality |
| `{domain}` | `spring`, `truss`, `beam` | Element type |
| `{operation}` | `elementstiffness`, `assemble`, `elementforce`, `elementstress`, `elementstrain`, `elementlength`, `elementaxialdiagram`, etc. | Operation |

This is a translation from the MATLAB naming convention in `Doc/Kattan/M-Files/`, where files use PascalCase names like `PlaneTrussElementStiffness.m`. See [Kattan MATLAB Mapping](../reference/kattan-mapping.md) for the full mapping.

## Dimension System

| Prefix | DOF per node | Typical elements | Global matrix indexing |
|--------|-------------|------------------|----------------------|
| `d1_` | 1 | 1D spring, linear bar | Node `i` → row `i` |
| `d2_` | 2 | 2D spring, plane truss | Node `i` → rows `2i-1, 2i` |
| `d2_planeframe` | **3** | Plane frame (2D beam with axial) | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_` | 3 (`d3_spring`, `d3_truss`) | 3D spring, space truss | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_beam` | **6** | Space frame (3D beam) | Node `i` → rows `6i-5, 6i-4, 6i-3, 6i-2, 6i-1, 6i` |

### Beam elements: two variants (2D)

**2D Pure Beam (`d2_beam_*`)**: Uses **2 DOF per node** (deflection `v`, rotation `θ`) — pure bending only, no axial deformation. The 4×4 stiffness matrix is the classical Euler-Bernoulli beam. Assembly uses `_assemble!` with `dofs=2`.

**2D Plane Frame (`d2_planeframe_*`)**: Uses **3 DOF per node** (`u_x`, `u_y`, rotation) — combining axial and bending behavior. The 6×6 stiffness matrix matches Kattan's `PlaneFrameElementStiffness`. Assembly uses `_assemble!` with `dofs=3`.

**3D Beam / Space Frame (`d3_beam_*`)**: Uses **6 DOF per node** (`u_x`, `u_y`, `u_z`, `θ_x`, `θ_y`, `θ_z`) — translations and rotations in all three axes. The element stiffness matrix is 12×12. The rotation matrix `Λ` (3×3 direction cosines) is constructed from the element node coordinates, handling the vertical-element degenerate case where `D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`.

## Function Pattern

Every element domain implements three core functions:

```julia
# 1. Element stiffness matrix — depends on material properties + geometry
k = d2_truss_elementstiffness(E, A, L, theta)   # returns 4×4 matrix

# 2. Assemble into global matrix
K = d2_truss_assemble(K, k, i, j)               # mutates K in-place via .+=

# 3a. Force vector (from displacements)
f = d2_truss_elementforce(E, A, L, theta, u)    # returns scalar (or Vector)

# 3b. Stress (from displacements, optional)
sigma = d2_truss_elementstress(E, L, theta, u)

# 3c. Strain (from displacements, optional)
epsilon = d2_truss_elementstrain(L, theta, u)
```

**Validation**: Most stiffness/length functions now validate positive inputs (e.g., `L > 0`, `A > 0`) and throw `ArgumentError` with descriptive messages on violation. See `src/LibFEM.jl` lines with `throw(ArgumentError(...))`.

Additional helpers exist per domain:
- **Length**: `_elementlength(...)` — Euclidean distance between node coordinates (2D/3D truss, beam)
- **Diagrams** (beam only): `_elementaxialdiagram`, `_elementmomentdiagram`, `_elementsheardiagram` — return Plots.jl `Plot` objects
- **3D beam internals**: `_d3_beam_kprime(E, G, A, Iy, Iz, J, L)` — private helper returning the 12×12 local stiffness matrix in element coordinates (before rotation to global). Used by `d3_beam_elementstiffness` and `d3_beam_elementforces`.

### Angle Conventions

Angles are always passed in **degrees** and converted internally:

```julia
deg2rad(theta::Real) = theta * pi / 180
```

- 2D elements: single `theta` parameter (angle from positive x-axis)
- 3D elements: three parameters `thetax, thetay, thetaz` (direction angles to x, y, z axes)

## Assembly Helper (`_assemble!`)

All 7 public `*_assemble` functions delegate to one private helper:

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    dofs = ndofs
    @views begin
        K[(i - 1) * dofs + 1:i * dofs, (i - 1) * dofs + 1:i * dofs] += k[1:dofs, 1:dofs]
        K[(i - 1) * dofs + 1:i * dofs, (j - 1) * dofs + 1:j * dofs] += k[1:dofs, dofs + 1:2 * dofs]
        K[(j - 1) * dofs + 1:j * dofs, (i - 1) * dofs + 1:i * dofs] += k[dofs + 1:2 * dofs, 1:dofs]
        K[(j - 1) * dofs + 1:j * dofs, (j - 1) * dofs + 1:j * dofs] += k[dofs + 1:2 * dofs, dofs + 1:2 * dofs]
    end
    return K
end
```

This maps 4 element-level blocks (ii, jj, ii→jj, jj→ii) to the global stiffness matrix using block indices based on `dofs`. Uses `@views` for efficient slice operations. Works for any DOF count:

This maps 4 element-level blocks (ii, jj, ii→jj, jj→ii) to the global stiffness matrix using block indices based on `dofs`. It works for any DOF count:

| `dofs` | Used by |
|--------|---------|
| `1` | `d1_spring_assemble`, `d1_truss_assemble` |
| `2` | `d2_spring_assemble`, `d2_truss_assemble` |
| `3` | `d2_planeframe_assemble`, `d3_spring_assemble`, `d3_truss_assemble` |
| `6` | `d3_beam_assemble` |

The helper is private (underscore prefix, not exported). Adding new element types requires only passing the correct `dofs` parameter — no new assembly boilerplate.

## Complete Function Inventory

### 1D Spring (`d1_spring`)
- `d1_spring_elementstiffness(k)` — 2×2 matrix
- `d1_spring_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_spring_elementforce(k, u)` — 2-element vector

### 1D Truss (`d1_truss`)
- `d1_truss_elementstiffness(E, A, L)` — 2×2 matrix (validates `L > 0`, `A > 0`)
- `d1_truss_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_truss_elementforces(Ke, u)` — 2-element vector
- `d1_truss_elementstress(Ke, u, A)` — stress at nodes
- `d1_truss_elementstrain(L, u)` — strain at nodes (validates `L > 0`)

### 2D Spring (`d2_spring`)
- `d2_spring_elementstiffness(k, theta)` — 4×4 matrix
- `d2_spring_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_spring_elementforce(k, theta, u)` — scalar force

### 2D Truss (`d2_truss`)
- `d2_truss_elementstiffness(E, A, L, theta)` — 4×4 matrix (validates `L > 0`)
- `d2_truss_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_truss_elementforces(E, A, L, theta, u)` — scalar force
- `d2_truss_elementstress(E, L, theta, u)` — scalar stress
- `d2_truss_elementstrain(L, theta, u)` — scalar strain (validates `L > 0`)
- `d2_truss_elementlength(x1, y1, x2, y2)` — element length

### 2D Pure Beam (`d2_beam`)
- `d2_beam_elementstiffness(E, I, L)` — 4×4 matrix (Euler-Bernoulli, bending only; validates `L > 0`)
- `d2_beam_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_beam_elementforces(k, u)` — 4-element force vector (shear + moment at nodes)
- `d2_beam_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_beam_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 2D Plane Frame (`d2_planeframe`)
- `d2_planeframe_elementlength(x1, y1, x2, y2)` — element length
- `d2_planeframe_elementstiffness(E, A, I, L, theta)` — 6×6 matrix (axial + bending; validates `L > 0`)
- `d2_planeframe_assemble(K, k, i, j)` — DOF mapping: 3
- `d2_planeframe_elementforces(E, A, I, L, theta, u)` — 6-element vector
- `d2_planeframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d2_planeframe_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_planeframe_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 3D Spring (`d3_spring`)
- `d3_spring_elementstiffness(k, thetax, thetay, thetaz)` — 6×6 matrix
- `d3_spring_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_spring_elementforce(k, thetax, thetay, thetaz, u)` — scalar force

### 3D Truss (`d3_truss`)
- `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)` — 6×6 matrix (validates `L > 0`)
- `d3_truss_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)` — scalar force
- `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)` — scalar stress
- `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)` — scalar strain (validates `L > 0`)
- `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` — element length

### 3D Beam / Space Frame (`d3_beam`)
- `d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` — 12×12 matrix (validates `L > 0`)
- `d3_beam_assemble(K, k, i, j)` — DOF mapping: **6**
- `d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` — 12-element vector (local frame) (validates `L > 0`)
- `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)` — 3D Euclidean distance
- `d3_beam_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d3_beam_elementshearydiagram(f, L)` — Plots.jl shear force (Y) diagram
- `d3_beam_elementshearzdiagram(f, L)` — Plots.jl shear force (Z) diagram
- `d3_beam_elementmomentydiagram(f, L)` — Plots.jl bending moment (Y) diagram
- `d3_beam_elementmomentzdiagram(f, L)` — Plots.jl bending moment (Z) diagram
- `d3_beam_elementtorsiondiagram(f, L)` — Plots.jl torsion diagram

  **Note**: The 3D beam uses a 12×12 local stiffness matrix with an embedded 3×3 rotation matrix `Λ` built from node coordinates (not angle parameters). `Iy` governs bending about the y-axis (δz, θy), `Iz` governs bending about the z-axis (δy, θz). The vertical-element degenerate case (`D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`) is handled automatically.

## Dependencies & Runtime Notes

- **`Plots.jl`** v1 — used by all beam diagram functions (`d2_beam_*`, `d2_planeframe_*`, and `d3_beam_*`). Required in `Project.toml`.
- **`using Plots`** is declared at module level in `src/LibFEM.jl` (though the diagram functions are in `src/plot.jl`).
- **`deg2rad` is now exported** — users can call `LibFEM.deg2rad(theta)` for degree-to-radian conversion.
- **No `ModelingToolkit`** — listed as a dependency in `CLAUDE.md`'s older version note, but the `Project.toml` has been updated to `Plots` only. The scripts in `scripts/` use MTK independently.

## Testing

Tests are in `test/`:
- **`runtests.jl`** — Main test suite (~400 lines). Uses `Test` standard library. Covers all 8 element types (including `d3_beam`) with stiffness matrix shape/symmetry checks, force/stress/strain numeric validation, assembly correctness, and MATLAB reference comparison for Problem 10.1.
- **`comparison.jl`** — Side-by-side MATLAB reference implementations transcribed from `Doc/Kattan/M-Files/`. Not run as independent tests; included from `runtests.jl`.
- **`benchmark.jl`** — Standalone `BenchmarkTools.jl` suite (12 benchmarks). Covers stiffness construction (8 element types), assembly (500-element d2_truss chain + 500-element d3_beam chain), solve (random SPD system), and d3_beam element forces. Run manually with `julia --project=. test/benchmark.jl`. Not part of CI.

To run tests:
```julia
julia --project=. -e 'using Pkg; Pkg.test()'
# or manually:
# julia --project=. test/runtests.jl
```

**CI**: There is no automated test runner workflow currently. The test suite is run manually. Benchmarks are not automated — they run standalone due to noise and slowness in automated environments.

**GitHub Actions workflows**: `.github/workflows/opencode.yml` runs the OpenCode AI assistant on issue/PR comments containing `/oc` or `/opencode`, using an NVIDIA NIM backend. `.github/workflows/openwiki-update.yml` runs a scheduled daily OpenWiki documentation refresh and opens a PR with any changes.

## Extension Points

When adding a new element type:

1. Implement `d{N}_{domain}_elementstiffness(...)` returning the correct matrix size
2. Implement `d{N}_{domain}_assemble(K, k, i, j)` — a 1-liner calling `_assemble!(K, k, i, j, dofs)`
3. Implement force/stress/strain as appropriate
4. Add `export` after each function
5. Add tests in `test/runtests.jl`

Key invariants to maintain:
- All angles in degrees (use `deg2rad`)
- Stiffness matrices must be symmetric
- Assembly uses `.+=` (in-place addition) to allow building up the global matrix from multiple elements

## Known Issues

See the repository's issue tracker for the full list. The **`ToDo.md`** file at the repository root is the merged code review backlog from two independent AI reviews. The cross-verified review (`ToDo_Promethus_inkling.md`) identified **false positives** in the merged list:

**⚠️ False Positives (NOT bugs — mathematically correct per MATLAB reference):**
- **C1**: `d3_beam_elementforces` uses `R` not `R'` — MATLAB `SpaceFrameElementForces.m:57` uses `kprime * R * u` (identical to Julia). Standard FEM: stiffness uses `R' * k_local * R` (global), forces use `k_local * R * u` (local).
- **C2**: `d2_planeframe_elementforces` "inverted transformation" — MATLAB `PlaneFrameElementForces.m:21` uses `kprime * T * u` (identical to Julia).

**✅ Verified Real Issues (from cross-verified review):**

| ID | Severity | Issue | Location |
|---|---|---|---|
| **H1** | HIGH | Duplicated rotation matrix (Λ/R) in 3D beam stiffness & force (~30 lines each) | `src/beam.jl:200-228`, `297-322` |
| **H2** | HIGH | Inconsistent force return types: 1D returns 2-element Vector, 2D/3D return scalar | `src/truss.jl:161, 313, 339, 366` |
| **H3** | HIGH | `_d3_beam_kprime` misplaced in `assembly.jl` (belongs in `beam.jl`) | `src/assembly.jl:32-87` |
| **H4** | MEDIUM | `_assemble!` missing bounds checks on `K` size vs indices | `src/assembly.jl:21-27` |
| **H5** | HIGH | `LinearAlgebra` not declared in `Project.toml` deps | `Project.toml` |
| **M1** | MEDIUM | `d3_truss` angle variable naming: `u` vs `w` for `thetay` | `src/truss.jl:282-284` vs `315+` |
| **M2** | MEDIUM | No arbitrary-orientation test for 3D beam forces (all tests use θ=0) | `test/runtests.jl` |
| **M3** | LOW | `ElementDimensionError` exported but never thrown/tested | `test/runtests.jl` |
| **M4** | MEDIUM | Benchmark suite not in CI | `.github/workflows/ci.yml` |
| **M5** | LOW | `plot.jl` docstrings contain spurious `export` keyword | `src/plot.jl` |

Notable items beyond the verified issues:
- No boundary condition or solver functions yet (users must solve `K·U = F` themselves)
- `Project.toml` has `[extras]`/`[targets]` for `BenchmarkTools` (test-only), but `Test` stdlib is not declared there