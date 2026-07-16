# LibFEM.jl

[![CI](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml)

A simple educational Finite Element Method library in Julia, for springs, trusses, and beams.
Inspired by Peter Kattan's *MATLAB Guide to Finite Elements*.

## Installation

```bash
git clone https://github.com/amdeldacc/LibFEM.jl.git
cd LibFEM.jl
julia --project=. -e 'using LibFEM'
```

## Quick Start

Solve a 2-spring problem:

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

## Element Reference

### 1-D Elements

| Function | Description |
|----------|-------------|
| `d1_spring_elementstiffness(k)` | 2×2 stiffness for spring with stiffness k |
| `d1_spring_elementforce(k, u)` | Nodal force vector |
| `d1_spring_assemble(K, k, i, j)` | Assemble into global matrix |
| `d1_truss_elementstiffness(E, A, L)` | 2×2 stiffness for linear bar |
| `d1_truss_elementforce(k, u)` | Nodal force vector |
| `d1_truss_elementstress(k, u, A)` | Stress vector |
| `d1_truss_elementstrain(L, u)` | Strain vector |
| `d1_truss_assemble(K, k, i, j)` | Assemble into global matrix |

### 2-D Elements

| Function | Description |
|----------|-------------|
| `d2_spring_elementstiffness(k, theta)` | 4×4 stiffness |
| `d2_spring_elementforce(k, theta, u)` | Force (scalar) |
| `d2_spring_assemble(K, k, i, j)` | Assemble |
| `d2_truss_elementlength(x1, y1, x2, y2)` | Element length |
| `d2_truss_elementstiffness(E, A, L, theta)` | 4×4 stiffness |
| `d2_truss_elementforce(E, A, L, theta, u)` | Force (scalar) |
| `d2_truss_elementstrain(L, theta, u)` | Strain (scalar) |
| `d2_truss_elementstress(E, L, theta, u)` | Stress (scalar) |
| `d2_truss_assemble(K, k, i, j)` | Assemble |
| `d2_beam_elementlength(x1, y1, x2, y2)` | Element length |
| `d2_beam_elementstiffness(E, A, I, L, theta)` | 6×6 stiffness |
| `d2_beam_elementforce(E, A, I, L, theta, u)` | 6-element force vector |
| `d2_beam_elementaxialdiagram(f, L)` | Plot axial force diagram |
| `d2_beam_elementsheardiagram(f, L)` | Plot shear force diagram |
| `d2_beam_elementmomentdiagram(f, L)` | Plot bending moment diagram |
| `d2_beam_assemble(K, k, i, j)` | Assemble (3 DOF/node) |

### 3-D Elements

| Function | Description |
|----------|-------------|
| `d3_spring_elementstiffness(k, thetax, thetay, thetaz)` | 6×6 stiffness |
| `d3_spring_elementforce(k, thetax, thetay, thetaz, u)` | Force (scalar) |
| `d3_spring_assemble(K, k, i, j)` | Assemble |
| `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` | Element length |
| `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)` | 6×6 stiffness |
| `d3_truss_elementforce(E, A, L, thetax, thetay, thetaz, u)` | Force (scalar) |
| `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)` | Strain (scalar) |
| `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)` | Stress (scalar) |
| `d3_truss_assemble(K, k, i, j)` | Assemble |
| `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)` | Element length |
| `d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` | 12×12 stiffness |
| `d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` | 12-element force vector |
| `d3_beam_elementaxialdiagram(f, L)` | Plot axial diagram |
| `d3_beam_elementshearydiagram(f, L)` | Plot shear-Y diagram |
| `d3_beam_elementshearzdiagram(f, L)` | Plot shear-Z diagram |
| `d3_beam_elementmomentydiagram(f, L)` | Plot moment-Y diagram |
| `d3_beam_elementmomentzdiagram(f, L)` | Plot moment-Z diagram |
| `d3_beam_elementtorsiondiagram(f, L)` | Plot torsion diagram |
| `d3_beam_assemble(K, k, i, j)` | Assemble (6 DOF/node) |

### Utility

| Function | Description |
|----------|-------------|
| `deg2rad(theta)` | Degrees to radians conversion |

## Testing

Run all tests:

```bash
julia --project=. test/runtests.jl
```

Or via the package manager:

```julia
julia> using Pkg; Pkg.test()
```

Tests include:
- **Unit tests** (test/runtests.jl, ~500 lines) — per-element correctness
- **MATLAB comparison** (test/comparison.jl, ~1300 lines) — exact numerical match against Kattan textbook solutions
- **Benchmarks** (test/benchmark.jl, 110 lines) — timing for stiffness, assembly, and solve

## Project Structure

```
LibFEM.jl/
├── src/LibFEM.jl          # Single-file module (all element implementations)
├── test/
│   ├── runtests.jl        # Unit tests
│   ├── comparison.jl      # MATLAB reference implementations + comparison tests
│   └── benchmark.jl       # Benchmark suite (BenchmarkTools)
├── docs/                  # Documentation and reference files
├── Project.toml           # Project dependencies (Plots)
└── Doc/Kattan/M-Files/    # MATLAB reference files (read-only)
```

## Acknowledgments

- Peter Kattan, *MATLAB Guide to Finite Elements: An Interactive Approach* (2nd ed.)
