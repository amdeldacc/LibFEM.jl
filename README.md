# LibFEM.jl

[![CI](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml)

A simple educational Finite Element Method library in Julia, for springs, trusses, and beams in 1D, 2D, and 3D.

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

**Dependencies**: `Plots.jl` v1 (listed in `Project.toml`).

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
| `{domain}`    | `spring`, `truss`, `beam`                                                                                                      | Element type           |
| `{operation}` | `elementstiffness`, `assemble`, `elementforce`, `elementstress`, `elementstrain`, `elementlength`, `elementaxialdiagram`, etc. | Operation              |

### Core Pattern (3 Functions per Element Type)

Every element type implements:

1. **`<prefix>_elementstiffness(...)`** — Returns the element stiffness matrix
2. **`<prefix>_assemble(K, k, i, j)`** — Assembles element matrix into global stiffness matrix
3. **One of**: `<prefix>_elementforce(...)`, `<prefix>_elementstress(...)`, `<prefix>_elementstrain(...)` — Computes results from displacements

Additional helpers: `_elementlength(...)`, beam diagram functions.

---

### 1-D Elements

| Function                             | Description                                                                                  |
| ------------------------------------ | -------------------------------------------------------------------------------------------- |
| `d1_spring_elementstiffness(k)`      | 2×2 stiffness matrix for spring with stiffness `k`                                           |
| `d1_spring_elementforce(Ke, u)`      | Nodal force vector (2×1)                                                                     |
| ~~`d1_spring_elementstress(Ke, u)`~~ | ~~Stress vector (2×1)~~ _(removed — meaningless for 0D spring, identical to `elementforce`)_ |
| `d1_spring_assemble(K, k, i, j)`     | Assemble into global matrix (1 DOF/node)                                                     |
| `d1_truss_elementstiffness(E, A, L)` | 2×2 stiffness for linear bar                                                                 |
| `d1_truss_elementforces(Ke, u)`      | Nodal force vector (2×1)                                                                     |
| `d1_truss_elementstress(Ke, u, A)`   | Stress vector (2×1)                                                                          |
| `d1_truss_elementstrain(L, u)`       | Strain vector (2×1)                                                                          |
| `d1_truss_assemble(K, k, i, j)`      | Assemble into global matrix (1 DOF/node)                                                     |

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
| `d2_beam_elementlength(x1, y1, x2, y2)`       | Element length                           |
| `d2_beam_elementstiffness(E, A, I, L, theta)` | 6×6 stiffness (3 DOF/node)               |
| `d2_beam_elementforces(E, A, I, L, theta, u)` | 6-element force vector                   |
| `d2_beam_elementaxialdiagram(f, L)`           | Plots.jl axial force diagram             |
| `d2_beam_elementsheardiagram(f, L)`           | Plots.jl shear force diagram             |
| `d2_beam_elementmomentdiagram(f, L)`          | Plots.jl bending moment diagram          |
| `d2_beam_assemble(K, k, i, j)`                | Assemble (3 DOF/node)                    |

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
| `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)`                        | Element length                        |
| `d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` | 12×12 stiffness (6 DOF/node)          |
| `d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` | 12-element force vector (local frame) |
| `d3_beam_elementaxialdiagram(f, L)`                                    | Plots.jl axial force diagram          |
| `d3_beam_elementshearydiagram(f, L)`                                   | Plots.jl shear-Y diagram              |
| `d3_beam_elementshearzdiagram(f, L)`                                   | Plots.jl shear-Z diagram              |
| `d3_beam_elementmomentydiagram(f, L)`                                  | Plots.jl moment-Y diagram             |
| `d3_beam_elementmomentzdiagram(f, L)`                                  | Plots.jl moment-Z diagram             |
| `d3_beam_elementtorsiondiagram(f, L)`                                  | Plots.jl torsion diagram              |
| `d3_beam_assemble(K, k, i, j)`                                         | Assemble (6 DOF/node)                 |

---

### Utility

| Function         | Description                              |
| ---------------- | ---------------------------------------- |
| `deg2rad(theta)` | Degrees to radians conversion (exported) |

---

## Conventions

- **Angle units**: All angle parameters are in **degrees** (converted internally via `deg2rad`).
- **Dimension prefixes**:
  - `d1_` — 1 DOF/node (1D spring, linear bar)
  - `d2_` — 2 DOF/node (2D spring, plane truss); 3 DOF/node for 2D beam
  - `d3_` — 3 DOF/node (3D spring, space truss); **6 DOF/node** for 3D beam (space frame)
- **Multi-file module**: Source organized into `src/LibFEM.jl` + `src/types.jl`, `src/errors.jl`, `src/utils.jl`, `src/assembly.jl`, `src/spring.jl`, `src/truss.jl`, `src/beam.jl`, `src/plot.jl`.
- **Assembly refactored**: All 7 `*_assemble` functions delegate to one private `_assemble!(K, k, i, j, ndofs)` helper (uses `@views` for efficiency).
- **Validation**: Most stiffness/length functions validate positive inputs (`L > 0`, `A > 0`) and throw `ArgumentError` with descriptive messages.
- **Type hierarchy**: Abstract types `AbstractElement{NDIM}`, `AbstractSpring{NDIM}`, `AbstractTruss{NDIM}`, `AbstractBeam{NDIM}` with concrete `@kwdef` structs `Spring{NDIM}`, `Truss{NDIM}`, `Beam{NDIM}`.

---

## Project Structure

```text
LibFEM.jl/
├── src/
│   ├── LibFEM.jl          # Module declaration, includes, exports
│   ├── types.jl           # Abstract type hierarchy, @kwdef element structs
│   ├── errors.jl          # Custom error types (ElementDimensionError, etc.)
│   ├── utils.jl           # deg2rad and shared helpers
│   ├── assembly.jl        # _assemble! helper, _d3_beam_kprime
│   ├── spring.jl          # d1/d2/d3_spring_* implementations
│   ├── truss.jl           # d1/d2/d3_truss_* implementations
│   ├── beam.jl            # d2/d3_beam_* implementations
│   └── plot.jl            # Beam diagram functions (Plots dependency)
├── test/
│   ├── runtests.jl        # Main test suite (~668 lines, covers all 8 element types)
│   ├── comparison.jl      # MATLAB reference transcriptions for verification
│   └── benchmark.jl       # BenchmarkTools.jl suite (12 benchmarks)
├── scripts/
│   ├── linear_truss_mtk.jl      # ModelingToolkit example
│   └── linear_truss_mtk_2.jl    # ModelingToolkit example
├── openwiki/              # Generated documentation (OpenWiki)
│   ├── quickstart.md
│   ├── architecture/overview.md
│   └── reference/kattan-mapping.md
├── Doc/
│   ├── Kattan/M-Files/    # Read-only MATLAB reference (80 .m files)
│   └── Kattan/Solutions Manual/
├── Project.toml           # Project metadata, deps (Plots), extras (Test, BenchmarkTools)
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

- **Unit tests** (`runtests.jl`, ~668 lines) — per-element correctness: stiffness matrix shape/symmetry, force/stress/strain numeric validation, assembly correctness, MATLAB reference comparison (Problem 10.1).
- **MATLAB comparison** (`comparison.jl`) — Side-by-side MATLAB reference implementations transcribed from `Doc/Kattan/M-Files/`. Included from `runtests.jl`.
- **Benchmarks** (`benchmark.jl`, 12 benchmarks) — Stiffness construction (8 element types), assembly (500-element chains), solve (random SPD), d3_beam forces. Run manually: `julia --project=. test/benchmark.jl`.

**CI**: GitHub Actions (`.github/workflows/ci.yml`) runs tests on Julia 1 and 1.10. Benchmarks run standalone (not in CI).

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
L = d3_beam_elementlength(x1, y1, z1, x2, y2, z2)  # → 4.0

# Element stiffness (12×12)
k = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

# Assemble into global matrix (2 nodes × 6 DOF = 12)
K = zeros(12, 12)
K = d3_beam_assemble(K, k, 1, 2)

# After solving K·U = F for displacements u (12×1)...
f = d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

# Visualize internal force diagrams
d3_beam_elementaxialdiagram(f, L)
d3_beam_elementshearydiagram(f, L)
d3_beam_elementtorsiondiagram(f, L)
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

The `Doc/Kattan/M-Files/` directory contains 80 read-only MATLAB `.m` files from the Kattan textbook. LibFEM functions are numerically validated against these references in `test/comparison.jl` and `test/runtests.jl`.

Mapping convention:

```text
MATLAB {Domain}{Operation}.m → Julia d{N}_{domain}_{operation}
```

Examples:

- `SpringElementStiffness.m` → `d1_spring_elementstiffness`
- `PlaneTrussElementForce.m` → `d2_truss_elementforces`
- `SpaceFrameElementStiffness.m` → `d3_beam_elementstiffness`
- `BeamElementForces.m` → `d2_beam_elementforces`

See `CONTEXT.md` and `openwiki/reference/kattan-mapping.md` for the complete mapping.

---

## Extending the Library

To add a new element type:

1. Implement `d{N}_{domain}_elementstiffness(...)` returning correct matrix size
2. Implement `d{N}_{domain}_assemble(K, k, i, j)` — one-liner calling `_assemble!(K, k, i, j, dofs)`
3. Implement force/stress/strain as appropriate
4. Add `export` statements in `src/LibFEM.jl`
5. Add tests in `test/runtests.jl`

**Key invariants**:

- All angles in degrees (use `deg2rad`)
- Stiffness matrices must be symmetric
- Assembly uses `.+=` (in-place addition) to accumulate multiple elements

---

## Known Issues & Backlog

See the repository's issue tracker for the full list. Highlights:

- **Docstring fixes**: Extra `export` keyword in docstrings, PascalCase vs snake_case mismatch
- **Plotting**: `d2_beam_*diagram` functions use MATLAB-style `'k'` color syntax; need Julia `:black`
- **Dependencies**: `Plots.jl` required; `ModelingToolkit` listed in older docs but not in `Project.toml`
- **Missing features**: Boundary condition helpers, solver functions, mesh/model builders
- **Refactoring**: Assembly functions could be unified (already done via `_assemble!`); angle conversion repeated

---

## Acknowledgments

- **Peter I. Kattan**, _MATLAB Guide to Finite Elements: An Interactive Approach_ (2nd ed., Springer, 2007) — the primary reference for algorithms and verification.
- Julia community for `Plots.jl`, `BenchmarkTools.jl`, and the Julia language itself.

---

## License

MIT License — see [LICENSE](LICENSE) (if present) or standard MIT terms.
