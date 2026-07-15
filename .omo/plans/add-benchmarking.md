# add-benchmarking — Work Plan

## TL;DR (For humans)

**What you'll get:** A standalone benchmark suite for LibFEM's hot path (element stiffness construction, assembly, solve) runnable via `julia --project=. test/benchmark.jl`.

**Why this approach:** BenchmarkTools is the Julia standard. Benchmarks are kept separate from tests (slow, noisy in CI). The plan adds BenchmarkTools to test dependencies and creates a single benchmark file covering all 7 element types.

**What it will NOT do:** Change CI workflows (already exists), modify `src/LibFEM.jl` source code, or add BenchmarkTools to runtime deps.

**Effort:** Quick
**Risk:** Low

---

> TL;DR (machine): Quick effort, low risk. Add BenchmarkTools to `[extras]`/`[targets]` in `Project.toml`, create `test/benchmark.jl`, add CI badge to `README.md`.

## Scope
### Must have
- Add `BenchmarkTools` to `Project.toml` under `[extras]` + `[targets]`
- Create `test/benchmark.jl` with 3 benchmark groups:
  1. **Element stiffness construction** — each of the 7 element types (`d1_spring`, `d2_spring`, `d3_spring`, `d1_truss`, `d2_truss`, `d3_truss`, `d2_beam`)
  2. **Assembly** — assemble a medium-sized system (~1000 DOF)
  3. **Solve** — solve the assembled linear system `K \ f`
- Add `[![CI](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml/badge.svg)](...)` badge to `README.md`
### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not modify `src/LibFEM.jl`
- Do not modify `test/runtests.jl` or `test/comparison.jl`
- Do not add BenchmarkTools to `[deps]` (runtime)
- Do not add CI job to run benchmarks automatically
- Do not modify any file under `Doc/`

## Verification strategy
- Run the benchmark file once to confirm it executes without errors
- Benchmark results printed to stdout — no comparison/baseline needed at this stage

## Execution strategy
### Sequential (single wave, 3 files)
1. Edit `Project.toml` — add BenchmarkTools test dependency
2. Create `test/benchmark.jl`
3. Edit `README.md` — add CI badge

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | None | 2, 3 | None |
| 2 | None | None | 3 |
| 3 | None | None | 2 |

## Todos
- [x] 1. Add BenchmarkTools to Project.toml test deps
  What to do: Insert `[extras]` section with `BenchmarkTools`, and `[targets]` section mapping `test = ["BenchmarkTools"]`. (Test itself is a stdlib, no need to list.)
  Parallelization: None | Blocked by: None | Blocks: 2, 3
  References: Project.toml
  Acceptance criteria: `julia --project=. -e 'using Pkg; Pkg.test()'` resolves BenchmarkTools
  QA scenarios: Run `julia --project=. -e 'using BenchmarkTools'` to confirm successful import
  Commit: Y | build: add BenchmarkTools to test dependencies

- [x] 2. Create test/benchmark.jl
  What to do: Write a standalone script using `@benchmark` or `@btime` from BenchmarkTools. Benchmark groups:
    - Stiffness: `d1_spring_elementstiffness(k)`, `d2_spring_elementstiffness(k,θ)`, `d3_spring_elementstiffness(k,θ1,θ2,θ3)`, `d1_truss_elementstiffness(E,A,L)`, `d2_truss_elementstiffness(E,A,L,θ)`, `d3_truss_elementstiffness(E,A,L,θ1,θ2,θ3)`, `d2_beam_elementstiffness(E,I,L,θ)`
    - Assembly: Build ~1000 node connectivity, call `d2_truss_assemble` (or whichever assemble has most DOFs)
    - Solve: Generate random K (n=200) and f, time `K \ f`
  Must NOT do: Use `@benchmarkable` in a file that errors without BenchmarkTools
  Parallelization: None | Blocked by: None | Blocks: None
  References: test/runtests.jl (for `using LibFEM` pattern)
  Acceptance criteria: `julia --project=. test/benchmark.jl` prints benchmark results without errors
  QA scenarios: Run the file, confirm 3 benchmark groups print results, confirm no exception
  Commit: Y | test: add benchmark suite

- [x] 3. Add CI badge to README.md
  What to do: Insert markdown badge link after the title. Badge: `[![CI](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/amdeldacc/LibFEM.jl/actions/workflows/ci.yml)`
  Parallelization: None | Blocked by: None | Blocks: None
  References: README.md
  Acceptance criteria: Badge renders on GitHub README
  QA scenarios: N/A (cosmetic, verified visually on GitHub after push)
  Commit: Y | docs: add CI badge to README

## Final verification wave
- [x] F1. Plan compliance audit — verify no src/ edits, no test/runtests changes
- [x] F2. Run `julia --project=. -e 'using BenchmarkTools'` — confirm import works
- [x] F3. Run `julia --project=. test/benchmark.jl` — confirm output with timing groups
- [x] F4. Scope fidelity — no stray edits outside plan scope

## Commit strategy
- `build: add BenchmarkTools to test dependencies`
- `test: add benchmark suite`
- `docs: add CI badge to README`

## Success criteria
- BenchmarkTools installs as a test dependency without affecting runtime
- `test/benchmark.jl` runs standalone and prints benchmark results for all 3 groups
- README has a working CI badge
- No changes to source code (`src/`), existing tests (`test/runtests.jl`, `test/comparison.jl`), or Doc/
