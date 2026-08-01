# LibFEM.jl

[![CI](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml)

A simple educational Finite Element Method library in Julia covering 16 element families in 1D, 2D, and 3D — from springs, bars, trusses, and beams to frames, grids, triangles, quadrilaterals, tetrahedra, bricks, and fluid flow.

Inspired by **Peter Kattan's _MATLAB Guide to Finite Elements: An Interactive Approach_** (2nd ed., Springer, 2007). The reference MATLAB code is preserved in `Doc/Kattan/M-Files/` as a read-only verification source.

---

## Installation

```bash
git clone https://github.com/amdeldacc/LibFEM.jl.git
cd LibFEM.jl
julia --project=. -e 'using LibFEM'
```

Or activate the environment in an existing Julia session:

```julia
using Pkg; Pkg.activate("."); using LibFEM
```

**Dependencies**: `LinearAlgebra` (stdlib). `Plots.jl` v1 is an optional weak dependency (only needed for diagram functions via the `LibFEMPlotsExt` extension).

---

## Quick Start

Solve a simple 2-spring system:

```julia
julia> using LibFEM

julia> k1 = d1_spring_elementstiffness(200)
2×2 Matrix{Float64}:
  200  -200
 -200   200

julia> k2 = d1_spring_elementstiffness(250);

julia> K = zeros(3, 3)
julia> K = d1_spring_assemble(K, k1, 1, 2)
julia> K = d1_spring_assemble(K, k2, 2, 3)

julia> u = [0.0; K[2:2, 2:2] \ [10.0]; 0.0]
3-element Vector{Float64}:
 0.0
 0.0222222
 0.0
```

---

## Element Reference

### Function Naming Convention

All functions follow the pattern: `d{N}_{domain}_{operation}`

| Component     | Values                                                                                                                         | Description            |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| `{N}`         | `1`, `2`, `3`                                                                                                                  | Spatial dimensionality |
| `{domain}`    | `spring`, `bar`, `truss`, `beam`, `planeframe`, `spaceframe`, `grid`, `triangle`, `lst`, `quadrilateral`, `q8`, `tetrahedron`, `brick`, `fluidflow`, `quadraticbar`                                                          | Element type           |
| `{operation}` | `elementstiffness`, `assemble`, `elementforces`, `elementstress`, `elementstrain`, `elementlength`, `elementaxialdiagram`, etc. | Operation              |

### Core Pattern (3 Functions per Element Type)

Every element type implements:

1. **`<prefix>_elementstiffness(...)`** — Returns the element stiffness matrix
2. **`<prefix>_assemble(K, k, i, j)`** — Assembles element matrix into global stiffness matrix
3. **One of**: `<prefix>_elementforces(...)`, `<prefix>_elementstress(...)`, `<prefix>_elementstrain(...)` — Computes results from displacements

Additional helpers: `_elementlength(...)`, beam diagram functions.

---

### 1-D Elements

| Function                               | Description                                                                                  |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `d1_spring_elementstiffness(k)`        | 2×2 stiffness matrix for spring with stiffness `k`                                           |
| `d1_spring_elementforce(Ke, u)`        | Nodal force vector (2×1)                                                                     |
| `d1_spring_assemble(K, k, i, j)`       | Assemble into global matrix (1 DOF/node)                                                     |
| `d1_bar_elementstiffness(E, A, L)`   | 2×2 stiffness for 1D bar (linear bar)                                                          |
| `d1_bar_elementforces(Ke, u)`        | Nodal force vector (2×1)                                                                       |
| `d1_bar_elementstress(Ke, u, A)`     | Stress vector (2×1)                                                                            |
| `d1_bar_elementstrain(L, u)`         | Strain vector (2×1)                                                                            |
| `d1_bar_assemble(K, k, i, j)`        | Assemble into global matrix (1 DOF/node)                                                       |
| `d1_quadraticbar_elementlength(x1, x2)` | Length of 3-node 1D element                                                                 |
| `d1_quadraticbar_elementstiffness(E, A, L)` | 3×3 stiffness matrix                                                                    |
| `d1_quadraticbar_elementforces(Ke, u)` | Nodal force vector (3×1)                                                                     |
| `d1_quadraticbar_elementstress(Ke, u, A)` | Stress vector (3×1)                                                                       |
| `d1_quadraticbar_assemble(K, k, i, j, m)` | Assemble into global matrix (1 DOF/node, 3 nodes)                                         |

---

### 2-D Elements

| Function                                      | Description                              |
| --------------------------------------------- | ---------------------------------------- |
| `d2_spring_elementstiffness(k, theta)`        | 4×4 stiffness (angle `theta` in degrees) |
| `d2_spring_elementforce(k, theta, u)`         | Scalar force                             |
| `d2_spring_assemble(K, k, i, j)`              | Assemble (2 DOF/node)                    |
| `d2_truss_elementlength(x1, y1, x2, y2)`      | Element length                           |
| `d2_truss_elementstiffness(E, A, L, theta)`   | 4×4 stiffness                            |
| `d2_truss_elementforces(E, A, L, theta, u)`   | Scalar force                             |
| `d2_truss_elementstrain(L, theta, u)`         | Scalar strain                            |
| `d2_truss_elementstress(E, L, theta, u)`      | Scalar stress                            |
| `d2_truss_assemble(K, k, i, j)`               | Assemble (2 DOF/node)                    |
| `d2_beam_elementstiffness(E, I, L)`           | 4×4 stiffness for pure beam — bending only, 2 DOF/node (v, θ) |
| `d2_beam_elementforces(k, u)`                 | 4-element force vector                   |
| `d2_beam_elementsheardiagram(f, L)`           | Plots.jl shear force diagram             |
| `d2_beam_elementmomentdiagram(f, L)`          | Plots.jl bending moment diagram          |
| `d2_beam_assemble(K, k, i, j)`                | Assemble (2 DOF/node)                    |
| `d2_planeframe_elementlength(x1, y1, x2, y2)` | Element length                           |
| `d2_planeframe_elementstiffness(E, A, I, L, theta)` | 6×6 stiffness (3 DOF/node, axial + bending) |
| `d2_planeframe_elementforces(E, A, I, L, theta, u)` | 6-element force vector                   |
| `d2_planeframe_elementaxialdiagram(f, L)`     | Plots.jl axial force diagram             |
| `d2_planeframe_elementsheardiagram(f, L)`     | Plots.jl shear force diagram             |
| `d2_planeframe_elementmomentdiagram(f, L)`    | Plots.jl bending moment diagram          |
| `d2_planeframe_assemble(K, k, i, j)`          | Assemble (3 DOF/node)                    |

---

### 3D Elements

| Function                                                               | Description                           |
| ---------------------------------------------------------------------- | ------------------------------------- |
| `d3_spring_elementstiffness(k, thetax, thetay, thetaz)`                | 6×6 stiffness                         |
| `d3_spring_elementforce(k, thetax, thetay, thetaz, u)`                 | Scalar force                          |
| `d3_spring_assemble(K, k, i, j)`                                       | Assemble (3 DOF/node)                 |
| `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)`                       | Element length                        |
| `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)`           | 6×6 stiffness                         |
| `d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)`           | Scalar force                          |
| `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)`                 | Scalar strain                         |
| `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)`              | Scalar stress                         |
| `d3_truss_assemble(K, k, i, j)`                                        | Assemble (3 DOF/node)                 |
| `d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)`                        | Element length                        |
| `d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` | 12×12 stiffness (6 DOF/node)          |
| `d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` | 12-element force vector (local frame) |
| `d3_spaceframe_elementaxialdiagram(f, L)`                                    | Plots.jl axial force diagram          |
| `d3_spaceframe_elementshearydiagram(f, L)`                                   | Plots.jl shear-Y diagram              |
| `d3_spaceframe_elementshearzdiagram(f, L)`                                   | Plots.jl shear-Z diagram              |
| `d3_spaceframe_elementmomentydiagram(f, L)`                                  | Plots.jl moment-Y diagram             |
| `d3_spaceframe_elementmomentzdiagram(f, L)`                                  | Plots.jl moment-Z diagram             |
| `d3_spaceframe_elementtorsiondiagram(f, L)`                                  | Plots.jl torsion diagram              |
| `d3_spaceframe_assemble(K, k, i, j)`                                         | Assemble (6 DOF/node)                 |

---

### Utility

| Function         | Description                              |
| ---------------- | ---------------------------------------- |
| `deg2rad(theta)` | Degrees to radians conversion (built-in `Base.deg2rad`) |

---

## Conventions

- **Angle units**: All angle parameters are in **degrees** (converted internally via `deg2rad`, imported from `Base`).
- **Dimension prefixes**:
  - `d1_` — 1 DOF/node (1D spring, linear bar)
  - `d2_` — 2 DOF/node (2D spring, plane truss, pure beam); 3 DOF/node for plane frame
  - `d3_` — 3 DOF/node (3D spring, space truss); **6 DOF/node** for 3D beam (space frame)
- **Multi-file module**: Source organized into `src/LibFEM.jl` + 21 source files in `src/` (types, errors, utils, assembly, individual element families). The `lib/` directory contains problem definitions for Kattan textbook validation.
- **Assembly refactored**: All `*_assemble` functions delegate to the private `_assemble!(K, k, i, j, ndofs)` or `_assemble_n!(K, k, nodes, ndofs)` helpers (use `@views` for efficiency).
- **Validation**: All stiffness/length functions validate positive inputs (`L > 0`, `A > 0`).
- **Type hierarchy**: Abstract types `AbstractElement{NDIM}`, `AbstractSpring{NDIM}`, `AbstractTruss{NDIM}`, `AbstractBeam{NDIM}` with concrete `@kwdef` structs `Spring{NDIM}`, `Truss{NDIM}`, `Beam{NDIM}`.

---

## Project Structure

```text
LibFEM.jl/
├── .githooks/             # Git hooks (pre-commit, pre-push, commit-msg)
│   ├── pre-commit
│   ├── pre-commit-ocr.sh
│   ├── prepare-commit-msg
│   └── pre-push
├── src/
│   ├── LibFEM.jl          # Module declaration, includes, exports
│   ├── types.jl           # Abstract type hierarchy, @kwdef element structs
│   ├── errors.jl          # Custom error types (ElementDimensionError, etc.)
│   ├── utils.jl           # deg2rad and shared helpers
│   ├── assembly.jl        # _assemble! helper, _assemble_n!
│   ├── spring.jl                    # Ch2: Spring (d1/d2/d3_spring_*)
│   ├── bar.jl                       # Ch3: Linear Bar (d1_bar_*)
│   ├── quadraticbar.jl              # Ch4: Quadratic Bar (d1_quadraticbar_*)
│   ├── planetruss.jl                # Ch5: Plane Truss (d2_truss_*)
│   ├── spacetruss.jl                # Ch6: Space Truss (d3_truss_*)
│   ├── beam.jl                      # Ch7: Beam (d2_beam_*)
│   ├── planeframe.jl                # Ch8: Plane Frame (d2_planeframe_*)
│   ├── grid.jl                      # Ch9: Grid (d2_grid_*)
│   ├── spaceframe.jl                # Ch10: Space Frame (d3_spaceframe_*)
│   ├── triangle.jl                  # Ch11: CST Linear Triangle (d2_cst_*)
│   ├── quadratictriangle.jl         # Ch12: LST Quadratic Triangle (d2_lst_*)
│   ├── quadrilateral.jl             # Ch13: Q4 Bilinear Quadrilateral (d2_q4_*)
│   ├── quadraticquadrilateral.jl    # Ch14: Q8 Quadratic Quadrilateral (d2_q8_*)
│   ├── tetrahedron.jl               # Ch15: Tetrahedron (d3_tet_*)
│   ├── brick.jl                     # Ch16: Brick (d3_brick_*)
│   ├── fluidflow.jl                 # Ch17: Fluid Flow (d1_fluidflow_*)
│   └── solver.jl                    # apply_bc! (boundary condition helper)
├── lib/
│   ├── problem_definitions.jl  # Kattan textbook problem definitions
│   └── problem_wrapper.jl      # Problem runner wrapper
├── ext/
│   └── LibFEMPlotsExt.jl  # Julia extension for Plots.jl diagram functions
├── test/
│   ├── Project.toml       # Test-only dependencies
│   ├── runtests.jl        # Main test suite (~2181 lines, covers all element types + deprecation aliases + Kattan problem integration)
│   ├── benchmark.jl       # BenchmarkTools.jl suite (14 benchmarks)
│   ├── property_tests.jl  # PropCheck.jl property-based tests
│   ├── golden_regression.jl  # Binary golden regression tests for Kattan problems
│   ├── golden/            # Golden binary snapshots (v1/)
│   ├── octave_runner.jl   # Octave execution harness
│   └── matlab_adapters.jl # MATLAB-to-Julia adapter helpers
├── scripts/
│   ├── validate-matlab.jl # Octave validation pipeline
│   ├── linear_truss_mtk.jl      # ModelingToolkit example
│   └── linear_truss_mtk_2.jl    # ModelingToolkit example
├── openwiki/              # Generated documentation (OpenWiki)
│   ├── quickstart.md
│   ├── architecture/overview.md
│   └── reference/kattan-mapping.md
├── Doc/
│   ├── Kattan/M-Files/    # Read-only MATLAB reference (80 .m files)
│   └── Kattan/Solutions Manual/
├── Project.toml           # Project metadata, deps (LinearAlgebra), weakdeps (Plots), extras (Test, BenchmarkTools, PropCheck)
├── Manifest.toml
├── CONTEXT.md             # Domain glossary: MATLAB→Julia mapping
├── AGENTS.md              # Agent instructions
└── README.md              # This file
```

---

## Testing

Run all tests:

```bash
julia --project=. test/runtests.jl
# or via package manager:
julia -e 'using Pkg; Pkg.test()'
```

**Test suite includes**:

- **Unit tests** (`runtests.jl`, ~2181 lines) — per-element correctness: stiffness matrix shape/symmetry, force/stress/strain numeric validation, assembly correctness, deprecation alias validation, plus 13 Kattan problem integration testsets (4.2, 9.1–16.1).
- **Property-based tests** (`property_tests.jl`, ~237 lines) — PropCheck.jl random-input invariants (symmetry, positive semi-definiteness).
- **Golden regression** (`golden_regression.jl`, ~114 lines) — binary snapshot regression for individual element functions (function-level, not problem-level; see `test/golden/manifests.toml`).
- **Octave validation** (`scripts/validate-matlab.jl`) — runs separately from `Pkg.test()`; comparisons across 4 test groups (spring, truss, beam, Kattan problems) against Kattan MATLAB reference. Run manually with `julia --project=. scripts/validate-matlab.jl all`. Octave >= 8.0 required.
- **Benchmarks** (`benchmark.jl`, ~240 lines, 14 benchmarks) — Stiffness construction (12 element types), assembly (500-element chains), solve (random SPD), d3_spaceframe forces. Run manually: `julia --project=. test/benchmark.jl`.

**CI**: GitHub Actions (`.github/workflows/ci.yml`) has two jobs: `test` runs unit tests, property tests, and golden regression on Julia 1.12; `validate` runs Octave validation. Other workflows: `benchmarks.yml`, `ocr-review.yml`, `openwiki-update.yml`, `openwiki-stale-check.yml`, `opencode.yml`, `super-linter.yml`.

---

## OpenWiki Documentation

This repository uses [OpenWiki](https://github.com/ondrej-superpowers/openwiki) for recurring code documentation. The generated wiki is kept in `openwiki/`:

- **[Quickstart](openwiki/quickstart.md)** — Getting started, element table, core patterns, worked examples
- **[Architecture Overview](openwiki/architecture/overview.md)** — Module structure, naming conventions, dimension system, function inventory, assembly helper, testing, extension points
- **[Kattan MATLAB Mapping](openwiki/reference/kattan-mapping.md)** — Full MATLAB-to-Julia mapping table and reference material index

The OpenWiki GitHub Actions workflow (`.github/workflows/openwiki-update.yml`) refreshes the repository wiki automatically. Do not hand-edit generated OpenWiki pages; update source code/docs and let OpenWiki regenerate.

---

## Example: 3D Beam (Space Frame) Workflow

```julia
using LibFEM

# Material and section properties
E = 210e9          # Young's modulus (Pa)
A = 0.01           # cross-sectional area (m²)
Iy = 2e-4          # second moment about y-axis (m⁴)
Iz = 1e-4          # second moment about z-axis (m⁴)
G = 80e9           # shear modulus (Pa)
J = 3e-4           # torsional constant (m⁴)

# Node coordinates
x1, y1, z1 = 0.0, 0.0, 0.0
x2, y2, z2 = 4.0, 0.0, 0.0

# Element length from coordinates
L = d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)  # → 4.0

# Element stiffness (12×12)
k = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

# Assemble into global matrix (2 nodes × 6 DOF = 12)
K = zeros(12, 12)
K = d3_spaceframe_assemble(K, k, 1, 2)

# After solving K·U = F for displacements u (12×1)...
f = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

# Visualize internal force diagrams
d3_spaceframe_elementaxialdiagram(f, L)
d3_spaceframe_elementshearydiagram(f, L)
d3_spaceframe_elementtorsiondiagram(f, L)
```

---

## Example: 2D Truss Workflow

```julia
using LibFEM

E, A = 210e9, 0.01

# Element length from node coordinates
L = d2_truss_elementlength(0.0, 0.0, 3.0, 4.0)  # → 5.0
theta = 30.0  # degrees

# Element stiffness (4×4)
k = d2_truss_elementstiffness(E, A, L, theta)

# Assemble into global matrix (8×8 for 4 nodes)
K = zeros(8, 8)
K = d2_truss_assemble(K, k, 1, 2)

# After solving K·U = F for displacements u...
f = d2_truss_elementforces(E, A, L, theta, u)     # element force
sigma = d2_truss_elementstress(E, L, theta, u)    # element stress
```

---

## MATLAB Reference Verification

The `Doc/Kattan/M-Files/` directory contains 80 read-only MATLAB `.m` files from the Kattan textbook. LibFEM functions are numerically validated against these references in `test/runtests.jl` and via the Octave validation pipeline (`scripts/validate-matlab.jl`).

Mapping convention:

```text
MATLAB {Domain}{Operation}.m → Julia d{N}_{domain}_{operation}
```

Examples:

- `SpringElementStiffness.m` → `d1_spring_elementstiffness`
- `PlaneTrussElementForce.m` → `d2_truss_elementforces`
- `SpaceFrameElementStiffness.m` → `d3_spaceframe_elementstiffness`
- `BeamElementForces.m` → `d2_beam_elementforces` (pure beam)
- `PlaneFrameElementStiffness.m` → `d2_planeframe_elementstiffness`

See `CONTEXT.md` and `openwiki/reference/kattan-mapping.md` for the complete mapping.

---

## MATLAB Reference Validation

LibFEM provides a standalone validation pipeline that runs the original Kattan textbook `.m` files through **GNU Octave** and compares results against Julia implementations. This exercises the actual MATLAB reference code, not hand-transcribed Julia translations.

### Purpose

Validate every in-scope element function against its original Kattan textbook MATLAB implementation by executing `.m` files directly through Octave. This catches discrepancies that hand-transcribed translations might miss and provides an independent verification layer.

### Prerequisites

- **GNU Octave >= 8.0** -- required for `jsonencode`/`jsondecode` support. Install via your system package manager:
  - Ubuntu/Debian: `sudo apt-get install octave`
  - macOS: `brew install octave`
  - Windows: See [octave.org/download](https://octave.org/download)

### Quick Start

Run the full validation suite (comparisons across 4 test groups: spring, truss, beam, Kattan problems):

```bash
julia --project=. scripts/validate-matlab.jl all
```

### CLI Reference

| Argument | Description |
| -------- | ----------- |
| `spring` | Validate 1D spring stiffness and forces (2 comparisons) |
| `truss`  | Validate 1D/2D/3D truss length, stiffness, forces, stress (11 comparisons) |
| `beam`   | Validate 2D/3D beam length, stiffness, forces (7 comparisons) |
| `problems` | Validate Kattan textbook solution problems (2.1–11.3, 19 problems) via Octave |
| `all`    | Run every validation comparison across all families (default) |

**Exit codes:**

| Code | Meaning |
| ---- | ------- |
| `0`  | All comparisons pass within tolerance |
| `1`  | One or more comparisons exceed tolerance |
| `2`  | Octave not found or version < 8.0 |

### Tolerances

Both stiffness matrix and force/stress comparisons use uniform tolerances:

- `rtol=1e-8` (relative tolerance)
- `atol=1e-10` (absolute tolerance)

Comparisons use Julia's `isapprox(actual, expected; rtol=1e-8, atol=1e-10)`.

### CI Behavior

The Octave validation pipeline runs automatically in CI as the `validate` ("Octave Validation") job (`.github/workflows/ci.yml`):

- **Octave is installed** via `sudo apt-get install -y octave` at the start of the job.
- **The build fails** if any comparison exceeds tolerance (exit code 1) or if Octave cannot be found (exit code 2). There is no `continue-on-error` flag.

This is a required check; discrepancies between Julia and MATLAB reference implementations are treated as regressions.

### Test Suite Integration

Octave validation runs as a separate script, not via `Pkg.test()`. To validate before releasing, run `julia --project=. scripts/validate-matlab.jl all` manually.

### Troubleshooting

**Octave not found**

```
ERROR: Octave not found at /usr/bin/octave
```

Ensure GNU Octave >= 8.0 is installed and the `octave` binary is at `/usr/bin/octave`. On Ubuntu/Debian: `sudo apt-get install octave`.

**Octave version < 8**

```
ERROR: Octave 8.0 or later is required (detected: 7.x)
```

Upgrade Octave to version 8 or later. The `jsonencode`/`jsondecode` functions are only available in Octave 8+.

**Unexpected numerical discrepancies**

If a comparison fails with a non-zero error:

1. Run the validation for the specific family: `julia --project=. scripts/validate-matlab.jl spring` (or `truss`/`beam`)
2. Check that your Julia code changes match the expected MATLAB output from the textbook
3. Verify the tolerance values in `scripts/validate-matlab.jl` (lines 34-35: `RTOL = 1e-8`, `ATOL = 1e-10`)

---

## Extending the Library

To add a new element type:

1. Implement `d{N}_{domain}_elementstiffness(...)` returning correct matrix size
2. Implement `d{N}_{domain}_assemble(K, k, i, j)` — one-liner calling `_assemble!(K, k, i, j, dofs)`
3. Implement force/stress/strain as appropriate
4. Add `export` statements in `src/LibFEM.jl`
5. Add tests in `test/runtests.jl`

**Key invariants**:

- All angles in degrees (use `deg2rad` internally, imported from `Base`)
- Stiffness matrices must be symmetric
- Assembly uses `.+=` (in-place addition) to accumulate multiple elements

---

## Known Issues & Backlog

See the repository's issue tracker for the full list. Highlights:

- **Docstring fixes**: Extra `export` keyword in docstrings, PascalCase vs snake_case mismatch
- **Missing features**: Boundary condition helpers, solver functions, mesh/model builders
- **Refactoring**: Assembly functions could be unified (already done via `_assemble!`); angle conversion repeated

---

## Acknowledgments

- **Peter I. Kattan**, _MATLAB Guide to Finite Elements: An Interactive Approach_ (2nd ed., Springer, 2007) — the primary reference for algorithms and verification.
- Julia community for `Plots.jl`, `BenchmarkTools.jl`, and the Julia language itself.

---

## License

MIT License — see [LICENSE](LICENSE) (if present) or standard MIT terms.
