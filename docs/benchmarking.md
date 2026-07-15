# Benchmarking Suite

## Change Summary

**Date**: 2026-07-15
**Files created**: `test/benchmark.jl` (+74 lines)
**Files modified**: `Project.toml`, `README.md`
**Dependency added**: `BenchmarkTools v1.8` (test-only, `[extras]`/`[targets]`)

## What Was Added

### 1. Benchmark Suite (`test/benchmark.jl`)

A standalone BenchmarkTools suite covering the library's hot path in 3 groups (10 benchmarks total).

**Group 1 — Element Stiffness Construction** (8 benchmarks)
Each element type's stiffness matrix construction benchmarked with realistic engineering values:

| Benchmark | Matrix size | Mean time | Inputs |
|---|---|---|---|
| `d1_spring` | 2×2 | **16.7 ns** | k = 1000 |
| `d2_spring` | 4×4 | **357 ns** | k = 1000, θ = 30° |
| `d3_spring` | 6×6 | **605 ns** | k = 1000, θx=30°, θy=45°, θz=60° |
| `d1_truss` | 2×2 | **17.6 ns** | E=200 GPa, A=0.01 m², L=2.0 m |
| `d2_truss` | 4×4 | **360 ns** | E=200 GPa, A=0.01 m², L=2.0 m, θ=30° |
| `d3_truss` | 6×6 | **606 ns** | E=200 GPa, A=0.01 m², L=2.0 m, θx=30°, θy=45°, θz=60° |
| `d2_beam` | 6×6 | **5.80 μs** | E=200 GPa, A=0.01 m², I=2e-4, L=2.0 m, θ=0° |
| `d3_beam` | 12×12 | **242 μs** | E=30 GPa, G=0.115 GPa, A=0.01 m², Iy=1e-4, Iz=2e-4, J=1e-5 |

**Group 2 — Assembly** (1 benchmark)
500-element d2_truss chain → 1002 DOF system:
- **266 μs** (`fill!` + 500 `d2_truss_assemble` calls)

**Group 3 — Solve** (1 benchmark)
Random symmetric positive-definite system n=200:
- **220 μs** (`K \ f` dense backslash)

### 2. CI Badge (`README.md`)

A `[![CI]](…)` badge linking to the GitHub Actions workflow was added below the project title, showing the latest CI status at a glance.

## How to Run

```bash
# Full benchmark suite
julia --project=. test/benchmark.jl

# Or from a Julia REPL (--project=.)
include("test/benchmark.jl")
```

## Usage as a Baseline

To compare future changes against these initial timings:

```julia
# Current results (reference)
results = include("test/benchmark.jl")

# After changes, run again and compare
# Use BenchmarkTools.jl's `judge()` for regression detection:
# BenchmarkTools.judge(results["stiffness"]["d1_spring"], new_results["stiffness"]["d1_spring"])
```

## Scope Boundaries

- **No CI integration**: Benchmarks run standalone (manually) — benchmarking is slow and noisy in automated CI without baseline comparison.
- **No source changes**: `src/LibFEM.jl` was not modified.
- **No test interference**: `test/runtests.jl` and `test/comparison.jl` are untouched — all 296 existing tests continue to pass.

## Verification

- `using BenchmarkTools` imports cleanly (v1.8)
- All 10 benchmarks execute without errors
- All 296 existing tests pass (zero regressions)
