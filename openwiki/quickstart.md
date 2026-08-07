---
type: Quickstart
title: "LibFEM.jl — Quickstart"
description: "Educational Finite Element Method library for Julia with springs, trusses/bars, beams, frames, 2D/3D continuum elements, grid structures, and fluid flow in 1D, 2D, and 3D. Getting started guide, element reference table, core patterns, and worked examples."
tags: ["quickstart", "getting-started", "fem", "julia"]
---

# LibFEM.jl — Quickstart

**LibFEM.jl v0.5.0** is an educational Finite Element Method (FEM) library for Julia. It provides element stiffness matrices, assembly functions, force/stress/strain calculations, boundary condition application, and diagram plotting for springs, trusses, beams, 2D/3D continuum elements, grid structures, and fluid flow in 1D, 2D, and 3D.

Inspired by *"MATLAB Guide to Finite Elements — An Interactive Approach"* by Peter I. Kattan (Springer, 2007). The reference MATLAB code is preserved in `Doc/Kattan/M-Files/` as a read-only verification source.

## Getting Started

```julia
# Start Julia with the project environment
julia --project=.

# Load the package
using Pkg; Pkg.activate("."); using LibFEM
```

**Dependencies**: `LinearAlgebra` (declared in `[deps]`); `Plots.jl` v1 is a **weak dependency** activated via the Julia extension `ext/LibFEMPlotsExt.jl`. Beam diagram functions throw `DiagramError` unless `using Plots` is loaded in the same session.

## Element Types at a Glance

| Domain | 1D (`d1_`) | 2D (`d2_`) | 3D (`d3_`) |
|--------|-----------|-----------|-----------|
| **Spring** | `d1_spring_*` — scalar stiffness `k` | `d2_spring_*` — angle `theta` | `d3_spring_*` — angles `thetax, thetay, thetaz` |
| **Truss/Bar** | `d1_bar_*` — `E, A, L` (linear bar) | `d2_truss_*` — `E, A, L, theta` | `d3_truss_*` — `E, A, L, thetax, thetay, thetaz` |
| **Quadratic Bar** | `d1_quadraticbar_*` — `E, A, L` (3 nodes, 1 DOF/node) | (not implemented) | (not implemented) |
| **Beam** (pure bending) | (not implemented) | `d2_beam_*` — `E, I, L` (2 DOF/node) | (not implemented) |
| **Plane/Space Frame** | (not implemented) | `d2_planeframe_*` — `E, A, I, L, theta` (3 DOF/node) | `d3_spaceframe_*` — `E, G, A, Iy, Iz, J` **+ node coords** (6 DOF/node) |
| **2D Continuum** | (not implemented) | `d2_cst_*` — `E, NU, t` (3 nodes, 2 DOF/node, plane stress/strain)<br>`d2_lst_*` — `E, NU, t` (6 nodes, 2 DOF/node)<br>`d2_q4_*` — `E, NU, h` (4 nodes, 2 DOF/node)<br>`d2_q8_*` — `E, NU, h` (8 nodes, 2 DOF/node) | (not implemented) |
| **Grid** | (not implemented) | `d2_grid_*` — `E, I, L, theta` (3 DOF/node: out-of-plane bending + torsion) | (not implemented) |
| **Fluid Flow** | `d1_fluidflow_*` — `E, A, L` (2 nodes, 1 DOF/node) | (not implemented) | (not implemented) |
| **3D Continuum** | (not implemented) | (not implemented) | `d3_brick_*` — `E, NU` (8 nodes, 3 DOF/node)<br>`d3_tet_*` — `E, NU` (4 nodes, 3 DOF/node) |

## Core Function Pattern

Every element type follows the same 3-function pattern:

1. **`<prefix>_elementstiffness(...)`** — compute the element stiffness matrix
2. **`<prefix>_assemble(K, k, i, j)`** — assemble element matrix into global stiffness matrix
3. **One of**: `<prefix>_elementforce(...)`, `<prefix>_elementstress(...)`, `<prefix>_elementstrain(...)` — compute results from displacements

Additional helpers: `_elementlength(...)` (including new `d1_quadraticbar_elementlength`), beam diagram functions (2D: `_elementaxialdiagram`, `_elementmomentdiagram`, `_elementsheardiagram`; 3D: `_elementaxialdiagram`, `_elementshearydiagram`, `_elementshearzdiagram`, `_elementmomentydiagram`, `_elementmomentzdiagram`, `_elementtorsiondiagram`).

**Solver helper** (new in v0.2.0):
- **`apply_bc!(K, F, constraints)`** — apply Dirichlet boundary conditions to global system K·u = F by eliminating constrained DOFs. Takes a vector of `dof => value` pairs.

**New in v0.3.0**: 8 new element types added:
- 2D Continuum: `d2_cst_*` (3-node linear triangle), `d2_lst_*` (6-node quadratic triangle), `d2_q4_*` (4-node bilinear quad), `d2_q8_*` (8-node serendipity quad)
- Grid: `d2_grid_*` (out-of-plane bending + torsion, 3 DOF/node)
- 1D Fluid Flow: `d1_fluidflow_*` (velocity/volumetric flow rate)
- 3D Continuum: `d3_brick_*` (8-node linear brick), `d3_tet_*` (4-node linear tetrahedron)

### Example: 3D Beam (Space Frame) Workflow

```julia
using LibFEM

# Material and section properties
E = 210e9          # Young's modulus (Pa)
A = 0.01           # cross-sectional area (m²)
Iy = 2e-4          # second moment about y-axis (m⁴)
Iz = 1e-4          # second moment about z-axis (m⁴)
G = 80e9           # shear modulus (Pa)
J = 3e-4           # torsional constant (m⁴)

# Node coordinates (x, y, z)
x1, y1, z1 = 0.0, 0.0, 0.0
x2, y2, z2 = 4.0, 0.0, 0.0

# Element length (computed from node coordinates)
L = d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)  # → 4.0

# Element stiffness (12×12 matrix)
k = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

# Assemble into global matrix (global K sized for 2 nodes × 6 DOF = 12)
K = zeros(12, 12)
K = d3_spaceframe_assemble(K, k, 1, 2)

# After solving K·U = F for displacements u (12×1)...
f = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

# Visualize internal force diagrams (displays in REPL; use display() in scripts)
d3_spaceframe_elementaxialdiagram(f, L)
d3_spaceframe_elementshearydiagram(f, L)
d3_spaceframe_elementtorsiondiagram(f, L)
```

### Example: 2D Truss Workflow

```julia
using LibFEM

# Material properties
E, A = 210e9, 0.01

# Compute element length from node coordinates
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

## Conventions

- **Angle units**: all angle parameters are in **degrees**; converted to radians internally via `deg2rad` (imported from `Base`). The 3D convention is the **cosine-of-axis-angle** form: identity `cos²θx + cos²θy + cos²θz = 1` must hold; off-unit inputs are auto-normalized with a `@warn`. Derive angles from node coordinates via `d2_truss_elementlength`/`d3_truss_elementlength` rather than passing angles manually when possible.
- **Dimension prefixes**: `d1_` (1 DOF/node), `d2_` (2 DOF/node for spring/truss; 3 for `d2_planeframe`), `d3_` (3 DOF/node for spring/truss; **6** for `d3_spaceframe`).
- **Multi-file module**: source code is organized into `src/LibFEM.jl` (declaration + includes + diagram stubs) + `src/types.jl`, `src/errors.jl`, `src/utils.jl`, `src/assembly.jl`, `src/spring.jl`, `src/bar.jl`, `src/quadraticbar.jl`, `src/planetruss.jl`, `src/spacetruss.jl`, `src/beam.jl`, `src/planeframe.jl`, `src/spaceframe.jl`, `src/grid.jl`, `src/triangle.jl`, `src/quadratictriangle.jl`, `src/quadrilateral.jl`, `src/quadraticquadrilateral.jl`, `src/tetrahedron.jl`, `src/brick.jl`, `src/fluidflow.jl`. The file layout mirrors the Kattan textbook chapters 1:1. Beam diagram functions live in the package extension `ext/LibFEMPlotsExt.jl` (loaded only when `Plots.jl` is present).
- **Source layout**: each Kattan chapter maps to exactly one `src/*.jl` file (e.g. `planetruss.jl` ↔ Ch5, `spaceframe.jl` ↔ Ch10). Private helpers like `_d2_planeframe_kprime` and `_d3_spaceframe_kprime` live alongside the element they support, not in `src/assembly.jl`.
- **Assembly refactored**: all 8 `*_assemble` functions delegate to one private `_assemble!(K, k, i, j, ndofs)` helper (uses `@views` for efficiency).
- **Parameter validation**: `L`, `A`, `E`, `k > 0` are enforced at function entry via `validate_positive`; invalid inputs throw `ElementParameterError`.

## Repository Map

| Path | Purpose |
|------|---------|
| `src/LibFEM.jl` | Module declaration, includes, exports |
| `src/types.jl` | Abstract type hierarchy, `@kwdef` element structs |
| `src/errors.jl` | Custom error type definitions |
| `src/utils.jl` | Shared helpers (`_direction_cosines`, validation) |
| `src/assembly.jl` | `_assemble!` private helper, generic N-node `_assemble_n!` |
| `src/spring.jl` | All `d1/d2/d3_spring_*` implementations |
| `src/bar.jl` | `d1_bar_*` (1-D linear bar; the `d1_truss_*` aliases live here too) |
| `src/quadraticbar.jl` | All `d1_quadraticbar_*` implementations (3-node quadratic bar) |
| `src/planetruss.jl` | All `d2_truss_*` implementations (2-D plane truss) |
| `src/spacetruss.jl` | All `d3_truss_*` implementations (3-D space truss) |
| `src/beam.jl` | All `d2_beam_*` implementations (pure Euler-Bernoulli beam) |
| `src/planeframe.jl` | All `d2_planeframe_*` implementations + private `_d2_planeframe_kprime` |
| `src/spaceframe.jl` | All `d3_spaceframe_*` implementations + private `_d3_spaceframe_kprime`, `_spaceframe_transform` |
| `src/grid.jl` | All `d2_grid_*` implementations + private `_d2_grid_kprime` |
| `src/triangle.jl` | All `d2_cst_*` implementations (CST) |
| `src/quadratictriangle.jl` | All `d2_lst_*` implementations (LST / 6-node triangle) |
| `src/quadrilateral.jl` | All `d2_q4_*` implementations (Q4 / bilinear quad) |
| `src/quadraticquadrilateral.jl` | All `d2_q8_*` implementations (Q8 / serendipity quad) |
| `src/tetrahedron.jl` | All `d3_tet_*` implementations (4-node tetrahedron) |
| `src/brick.jl` | All `d3_brick_*` implementations (8-node brick) |
| `src/fluidflow.jl` | All `d1_fluidflow_*` implementations (1-D fluid flow) |
| `src/solver.jl` | `apply_bc!` — Dirichlet boundary condition application |
| `ext/LibFEMPlotsExt.jl` | Beam diagram functions (Plots weak dependency via extension) |
| `test/runtests.jl` | Main test suite (covers all 17 element types, 28 `problem_*_integration` Kattan ports spanning problems 2.1–16.1, deprecation-alias tests, physical-invariant macros, parameter-validation contracts) |
| `test/property_tests.jl` | PropCheck.jl property-based tests (symmetry, zero row-sum, assembly linearity, plus a `PropCheck.check` smoke test) |
| `test/golden_regression.jl` | Binary golden regression test runner (28 fixtures in `test/golden/v1/*.bin`, paired with `test/golden/manifests.toml`) |
| `test/benchmark.jl` | Standalone BenchmarkTools.jl suite (22 benchmarks: stiffness for 10 element types, assembly for 8, dense solve, d3_spaceframe forces) |
| `test/golden/generate_golden.jl` | Helper to regenerate the `v1/*.bin` fixtures after a verified math change |
| `test/golden/params_common.jl` | Shared parameter ordering for the manifest |
| `test/octave_runner.jl` | `OctaveRunner` module — subprocess bridge that runs `.m` scripts via GNU Octave ≥ 8.0 |
| `test/matlab_adapters.jl` | MATLAB↔Julia argument/result adapters used by `scripts/validate-matlab.jl` |
| `scripts/setup-dev.jl` | Loads Revise, instantiates the project, and pre-loads LibFEM for interactive sessions |
| `lib/problem_definitions.jl` | `PROBLEM_REGISTRY` (14 problems 2.1–8.3) plus `ProblemDef` struct, `resolve_problem_path`, `problem_by_name` |
| `lib/problem_wrapper.jl` | `ProblemWrapper` module: `build_problem_wrapper`, `run_problem_via_octave`, `run_julia_problem`, `validate_problem`, and 20 `_problem_*_julia()` Julia ports |
| `scripts/validate-matlab.jl` | Octave↔Julia validation driver; CLI `{spring,truss,beam,problems,all}`; runs in CI’s `validate` job |
| `examples/kattan/` | Runnable Julia ports of the Kattan textbook problems (`problem_2_1.jl` … `problem_16_1.jl`) |
| `examples/mtk/` | ModelingToolkit integration examples (`linear_truss_mtk.jl`, `linear_truss_mtk_2.jl`); illustrative only, not part of the LibFEM API |
| `Doc/Kattan/M-Files/` | Read-only MATLAB reference (80 `.m` files from Kattan) — algorithm ground truth, never edit |
| `Doc/Kattan/Solutions-Manual/` | `.rtf` and `.doc` problem solutions, plus per-problem MATLAB scripts (`problem_2_1.m` … `problem_16_1.m`, `ocr_m_verify.m`) |
| `Doc/Peter_Kattan_*` | Book PDF and text/Markdown transcriptions |
| `CONTEXT.md` | Domain glossary: design decisions, MATLAB→Julia mapping, naming conventions |
| `AGENTS.md`, `CLAUDE.md` | Agent instructions with constraints and conventions (including the framework identity rule and OpenWiki handling note) |

## Where to Go Next

- **[Architecture Overview](architecture/overview.md)** — Naming conventions, dimension system, `_assemble!` helper, module structure, **git hooks & commit workflow**, type hierarchy, testing.
- **[Kattan Problem Integration](kattan/overview.md)** — Problem registry, problem wrapper, Octave ↔ Julia validation workflow, how problems 2.1 … 16.1 are wired through three layers (unit tests, Octave driver, runnable examples).
- **[Kattan MATLAB Mapping](reference/kattan-mapping.md)** — Full MATLAB-to-Julia mapping table and reference material index.

## Backlog

| Area | Source Anchor | Reason Deferred |
|------|--------------|-----------------|
| `examples/mtk/` example walkthrough | `/examples/mtk/linear_truss_mtk.jl`, `linear_truss_mtk_2.jl` | Example scripts; interesting but secondary to API docs |
| Detailed per-MATLAB-file analysis | `/Doc/Kattan/M-Files/` (80 files) | Covered at mapping level; deeper analysis can be added on demand |