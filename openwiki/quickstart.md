---
type: Quickstart
title: "LibFEM.jl — Quickstart"
description: "Educational Finite Element Method library for Julia with springs, trusses, and beams in 1D, 2D, and 3D. Getting started guide, element reference table, core patterns, and worked examples."
tags: ["quickstart", "getting-started", "fem", "julia"]
---

# LibFEM.jl — Quickstart

**LibFEM.jl** is an educational Finite Element Method (FEM) library for Julia. It provides element stiffness matrices, assembly functions, force/stress/strain calculations, and diagram plotting for springs, trusses, and beams in 1D, 2D, and 3D.

Inspired by *"MATLAB Guide to Finite Elements — An Interactive Approach"* by Peter I. Kattan (Springer, 2007). The reference MATLAB code is preserved in `Doc/Kattan/M-Files/` as a read-only verification source.

## Getting Started

```julia
# Start Julia with the project environment
julia --project=.

# Load the package
using Pkg; Pkg.activate("."); using LibFEM
```

**Dependencies**: `Plots.jl` v1 (`Project.toml`).

## Element Types at a Glance

| Domain | 1D (`d1_`) | 2D (`d2_`) | 3D (`d3_`) |
|--------|-----------|-----------|-----------|
| **Spring** | `d1_spring_*` — scalar stiffness `k` | `d2_spring_*` — angle `theta` | `d3_spring_*` — angles `thetax, thetay, thetaz` |
| **Truss** | `d1_truss_*` — `E, A, L` | `d2_truss_*` — `E, A, L, theta` | `d3_truss_*` — `E, A, L, thetax, thetay, thetaz` |
| **Beam** (pure) | (not implemented) | `d2_beam_*` — `E, I, L` (2 DOF/node, bending only) | (not implemented) |
| **Plane/Space Frame** | (not implemented) | `d2_planeframe_*` — `E, A, I, L, theta` (3 DOF/node) | `d3_spaceframe_*` — `E, G, A, Iy, Iz, J` **+ node coords** (6 DOF/node) |

## Core Function Pattern

Every element type follows the same 3-function pattern:

1. **`<prefix>_elementstiffness(...)`** — compute the element stiffness matrix
2. **`<prefix>_assemble(K, k, i, j)`** — assemble element matrix into global stiffness matrix
3. **One of**: `<prefix>_elementforce(...)`, `<prefix>_elementstress(...)`, `<prefix>_elementstrain(...)` — compute results from displacements

Additional helpers: `_elementlength(...)`, beam diagram functions (2D: `_elementaxialdiagram`, `_elementmomentdiagram`, `_elementsheardiagram`; 3D: `_elementaxialdiagram`, `_elementshearydiagram`, `_elementshearzdiagram`, `_elementmomentydiagram`, `_elementmomentzdiagram`, `_elementtorsiondiagram`).

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

- **Angle units**: all angle parameters are in **degrees**; converted to radians internally via `deg2rad`.
- **Dimension prefixes**: `d1_` (1 DOF/node), `d2_` (2 DOF/node for spring/truss; 3 for `d2_planeframe`), `d3_` (3 DOF/node for spring/truss; **6** for `d3_spaceframe`).
- **Multi-file module**: source code is organized into `src/LibFEM.jl` (declaration + includes) + `src/types.jl`, `src/errors.jl`, `src/utils.jl`, `src/assembly.jl`, `src/spring.jl`, `src/truss.jl`, `src/beam.jl`, `src/plot.jl`.
- **Assembly refactored**: all 7 `*_assemble` functions delegate to one private `_assemble!(K, k, i, j, ndofs)` helper (uses `@views` for efficiency).

## Repository Map

| Path | Purpose |
|------|---------|
| `src/LibFEM.jl` | Module declaration, includes, exports |
| `src/types.jl` | Abstract type hierarchy, `@kwdef` element structs |
| `src/errors.jl` | Custom error type definitions |
| `src/utils.jl` | `deg2rad` and shared helpers |
| `src/assembly.jl` | `_assemble!` private helper, `_d3_spaceframe_kprime` |
| `src/spring.jl` | All `d1/d2/d3_spring_*` implementations |
| `src/truss.jl` | All `d1/d2/d3_truss_*` implementations |
| `src/beam.jl` | All `d2_beam_*`, `d2_planeframe_*`, and `d3_spaceframe_*` implementations |
| `src/plot.jl` | Beam diagram functions (Plots dependency) |
| `test/runtests.jl` | Main test suite (~900 lines, covers all 8 element types, includes golden regression) |
| `test/matlab_adapters.jl` | MATLAB↔Julia argument/result adapters used by the Octave verification harness |
| `test/golden/` | Binary golden files (`v1/*.bin`) + `manifests.toml` + `params_common.jl` for regression testing |
| `test/golden_regression.jl` | Regression test runner that diffs current outputs against `test/golden/v1/` |
| `test/benchmark.jl` | Standalone BenchmarkTools.jl suite (12 benchmarks) |
| `scripts/dev/setup.jl` | Loads Revise, instantiates the project, and pre-loads LibFEM for interactive sessions |
| `scripts/problems/problem_definitions.jl` | `PROBLEM_REGISTRY` — canonical Kattan reference problems with MATLAB file, family, and tolerances |
| `scripts/validate_matlab.jl` | Octave↔Julia validation driver; runs in CI’s `validate` job |
| `scripts/` (other) | Example scripts using LibFEM and ModelingToolkit |
| `Doc/Kattan/M-Files/` | Read-only MATLAB reference (80 `.m` files from Kattan) |
| `Doc/Kattan/Solutions-Manual/` | `.rtf` and `.doc` problem solutions, plus per-problem MATLAB scripts (`problem_2_1.m` … `problem_8_3.m`, `ocr_m_verify.m`) |
| `Doc/Peter_Kattan_*` | Book PDF and text/Markdown transcriptions |
| `CONTEXT.md` | Domain glossary: MATLAB→Julia mapping and naming conventions |
| `AGENTS.md`, `CLAUDE.md` | Agent instructions with constraints and conventions (including the framework identity rule) |

## Where to Go Next

- **[Architecture Overview](architecture/overview.md)** — Naming conventions, dimension system, `_assemble!` helper, module structure.
- **[Kattan MATLAB Mapping](reference/kattan-mapping.md)** — Full MATLAB-to-Julia mapping table and reference material index.

## Backlog

| Area | Source Anchor | Reason Deferred |
|------|--------------|-----------------|
| `scripts/` example walkthrough | `/scripts/linear_truss_mtk.jl`, `linear_truss_mtk_2.jl` | Example scripts; interesting but secondary to API docs |
| Detailed per-MATLAB-file analysis | `/Doc/Kattan/M-Files/` (80 files) | Covered at mapping level; deeper analysis can be added on demand |