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
| `src/assembly.jl` | `_assemble!` private helper, `_d2_planeframe_kprime`, `_d3_spaceframe_kprime` |
| `src/spring.jl` | All `d1/d2/d3_spring_*` implementations |
| `src/truss.jl` | All `d1/d2/d3_truss_*` implementations |
| `src/quadraticbar.jl` | All `d1_quadraticbar_*` implementations (1-D quadratic bar, 3-node) |
| `src/beam.jl` | All `d2_beam_*` (pure beam), `d2_planeframe_*` (plane frame), and `d3_spaceframe_*` (space frame) implementations |
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
include("quadraticbar.jl")
include("beam.jl")
include("plot.jl")

# grouped exports follow...
end
```

**Exports**: All public functions are exported in grouped blocks. `deg2rad` is exported for external use. The helpers `_assemble!`, `_d2_planeframe_kprime`, and `_d3_spaceframe_kprime` remain private (underscore prefix, not exported).

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
| `d1_` | 1 | 1D spring, linear bar, quadratic bar | Node `i` → row `i` |
| `d2_` | 2 | 2D spring, plane truss | Node `i` → rows `2i-1, 2i` |
| `d2_planeframe` | **3** | Plane frame (2D beam with axial) | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_` | 3 (`d3_spring`, `d3_truss`) | 3D spring, space truss | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_spaceframe` | **6** | Space frame (3D beam) | Node `i` → rows `6i-5, 6i-4, 6i-3, 6i-2, 6i-1, 6i` |

### Beam elements: two variants (2D)

**2D Pure Beam (`d2_beam_*`)**: Uses **2 DOF per node** (deflection `v`, rotation `θ`) — pure bending only, no axial deformation. The 4×4 stiffness matrix is the classical Euler-Bernoulli beam. Assembly uses `_assemble!` with `dofs=2`.

**2D Plane Frame (`d2_planeframe_*`)**: Uses **3 DOF per node** (`u_x`, `u_y`, rotation) — combining axial and bending behavior. The 6×6 stiffness matrix matches Kattan's `PlaneFrameElementStiffness`. Assembly uses `_assemble!` with `dofs=3`.

**3D Space Frame (`d3_spaceframe_*`)**: Uses **6 DOF per node** (`u_x`, `u_y`, `u_z`, `θ_x`, `θ_y`, `θ_z`) — translations and rotations in all three axes. The element stiffness matrix is 12×12. The rotation matrix `Λ` (3×3 direction cosines) is constructed from the element node coordinates, handling the vertical-element degenerate case where `D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`.

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
- **3D space frame internals**: `_d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)` — private helper returning the 12×12 local stiffness matrix in element coordinates (before rotation to global). Used by `d3_spaceframe_elementstiffness` and `d3_spaceframe_elementforces`.

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
| `6` | `d3_spaceframe_assemble` |

The helper is private (underscore prefix, not exported). Adding new element types requires only passing the correct `dofs` parameter — no new assembly boilerplate.

## Complete Function Inventory

### 1D Spring (`d1_spring`)
- `d1_spring_elementstiffness(k)` — 2×2 matrix
- `d1_spring_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_spring_elementforce(k, u)` — 2-element vector

### 1D Quadratic Bar (`d1_quadraticbar`)
- `d1_quadraticbar_elementstiffness(E, A, L)` — 3×3 matrix (validates `L > 0`, `A > 0`)
- `d1_quadraticbar_assemble(K, k, i, j, m)` — custom assembly for 3-node element (DOF mapping: 1)
- `d1_quadraticbar_elementforces(Ke, u)` — 3-element vector
- `d1_quadraticbar_elementstress(Ke, u, A)` — 3-element stress vector (validates `A > 0`)

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

### 3D Space Frame (`d3_spaceframe`)
- `d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` — 12×12 matrix (validates `L > 0`)
- `d3_spaceframe_assemble(K, k, i, j)` — DOF mapping: **6**
- `d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` — 12-element vector (local frame) (validates `L > 0`)
- `d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)` — 3D Euclidean distance
- `d3_spaceframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d3_spaceframe_elementshearydiagram(f, L)` — Plots.jl shear force (Y) diagram
- `d3_spaceframe_elementshearzdiagram(f, L)` — Plots.jl shear force (Z) diagram
- `d3_spaceframe_elementmomentydiagram(f, L)` — Plots.jl bending moment (Y) diagram
- `d3_spaceframe_elementmomentzdiagram(f, L)` — Plots.jl bending moment (Z) diagram
- `d3_spaceframe_elementtorsiondiagram(f, L)` — Plots.jl torsion diagram

  **Note**: The 3D space frame uses a 12×12 local stiffness matrix with an embedded 3×3 rotation matrix `Λ` built from node coordinates (not angle parameters). `Iy` governs bending about the y-axis (δz, θy), `Iz` governs bending about the z-axis (δy, θz). The vertical-element degenerate case (`D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`) is handled automatically.

## Dependencies & Runtime Notes

- **`Plots.jl`** v1 — a **weak dependency** declared under `[weakdeps]` in `Project.toml`. The real beam diagram implementations live in `ext/LibFEMPlotsExt.jl`, a Julia 1.9+ package extension that auto-activates when both LibFEM and Plots are loaded. Core math (stiffness, assembly, forces) works **without** Plots.
- **`src/plot.jl`** only contains **stub** `DiagramError`-throwing fallbacks so that `using LibFEM` (without Plots) still succeeds. The extension replaces these stubs with real `Plots.jl` implementations when loaded.
- **`LinearAlgebra`** is declared in `[deps]` in `Project.toml` (compat pinned to `1.12.0`).
- **`deg2rad` is exported** — users can call `LibFEM.deg2rad(theta)` for degree-to-radian conversion.
- **No `ModelingToolkit`** — listed as a dependency in `CLAUDE.md`'s older version note, but the `Project.toml` has Plots only (as a weakdep). The scripts in `scripts/` use MTK independently.

## Testing

Tests are in `test/` and in a dedicated `test/Project.toml` (a Julia 1.12 workspace project so the test environment can resolve `Plots`, `BenchmarkTools`, `PropCheck`, and `Test` as test-only deps):
- **`runtests.jl`** — Main test suite (~1000 lines). Uses `Test` standard library. Covers all 8 element types (including `d3_spaceframe` and `d1_quadraticbar`) with stiffness matrix shape/symmetry checks, force/stress/strain numeric validation, assembly correctness, and MATLAB reference comparison. Includes golden regression tests against `test/golden/v1/` binary reference files.
- **`property_tests.jl`** — Property-based tests using `PropCheck.jl` for invariant coverage beyond the example-based checks in `runtests.jl`.
- **`benchmark.jl`** — Standalone `BenchmarkTools.jl` suite (12 benchmarks). Covers stiffness construction, assembly (long chain stress tests), solve, and element-force computation. Run from the dedicated `test/` environment: `julia --project=test test/benchmark.jl`.
- **`golden_regression.jl`** — Regression test runner that diffs current outputs against `test/golden/v1/` binary files (`test/golden/manifests.toml` and `params_common.jl` define the corpus; `test/golden/generate_golden.jl` regenerates snapshots).
- **`octave_runner.jl`** — Module that drives Octave (installed with `apt-get install --no-install-recommends`) for MATLAB reference execution, used by `scripts/validate_matlab.jl`.
- **`matlab_adapters.jl`** — MATLAB↔Julia argument/result adapters (handles MATLAB's 1-based vs Julia's 1-based indexing quirks, vector/matrix orientation differences, and the `element_r`/`element_t` naming for the Kattan reference output).

To run tests:
```julia
julia --project=. -e 'using Pkg; Pkg.test()'
# or directly against the test environment:
# julia --project=test test/runtests.jl
```

**CI** (`.github/workflows/`):
- **`ci.yml`** — runs the test suite and Octave validation on every push/PR.
- **`benchmarks.yml`** — runs `test/benchmark.jl` and reports timing as a workflow artifact.
- **`ocr-review.yml`** — OpenCodeReview agent review of staged changes.
- **`opencode.yml`** — runs the OpenCode AI assistant on issue/PR comments containing `/oc` or `/opencode`, using an NVIDIA NIM backend.
- **`openwiki-update.yml`** — scheduled daily OpenWiki documentation refresh that opens a PR with any changes.
- **`openwiki-stale-check.yml`** — flags stale OpenWiki sections.
- **`super-linter.yml`** — runs the GitHub Super-Linter pre-merge.

Per `scripts/pre-commit-check.sh` and `scripts/pre-commit-ocr.sh`, the project also ships pre-commit hooks that lint the Julia sources and run the OCR review.

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

## Verification Stack

Three independent verification layers back the math (see `CONTEXT.md` "Verification Strategy (2026-07)"):

1. **Unit tests** — `test/runtests.jl` provides per-element correctness using the `Test` stdlib.
2. **Octave validation** — `scripts/validate_matlab.jl` runs the actual Kattan `.m` files through Octave (via `test/octave_runner.jl` and the adapters in `test/matlab_adapters.jl`) so Julia results are diffed against the real MATLAB outputs.
3. **Golden regression tests** — `test/golden_regression.jl` snapshots binary outputs under `test/golden/v1/` and lets you regenerate them with `test/golden/generate_golden.jl`. This is an additive snapshot layer for refactor regressions — it complements but does not replace the unit tests or Octave validation.

A previous hand-transcribed MATLAB layer (`test/comparison.jl`) was removed (per `CONTEXT.md`): the transcription drift, overlap with Octave validation, and maintenance burden were not worth keeping it alongside the live-Octave layer.

## Property & Boundary-Condition Tests

`test/property_tests.jl` uses `PropCheck.jl` to assert invariants the example-based tests in `runtests.jl` cannot cover — symmetric position matrices, sign conventions, etc. Run via the standard `Pkg.test()` pipeline.

## Cross-Cutting Conventions

- No boundary condition or solver functions yet — users still solve `K·U = F` themselves with `LinearAlgebra`. Per `CONTEXT.md`, thin wrapper helpers (`apply_bc!`, `solve`) are planned but not implemented.
- Direction cosines are normalized to unit length by `_direction_cosines` (see commit `ffac82c`: "fix: use valid direction cosines in 3D truss validation test (`θx=0°, θy=90°, θz=90° → (1,0,0)`)").
- Spring stiffness `k` is validated as `k > 0` everywhere (was previously silently allowing zero/negative values).
- Quadratic bar `assemble` has its own bounds-checked implementation that does **not** use `_assemble!` because the 3-node element shape doesn't fit the generic 2-node block layout.