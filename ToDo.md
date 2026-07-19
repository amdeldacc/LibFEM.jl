# LibFEM.jl Code Review — Merged ToDo (Critical + Actionable Only)

**Source**: Cross-verification of two independent reviews (nemo-ultra, deepseek-v4-pro) on branches `opencode/issue12-20260719161929` and `opencode/issue12-20260719175910`. Redundant, stale, and low-signal items suppressed.

---

## CRITICAL — Correctness Bugs (Fix Immediately)

| # | Issue | Location | Evidence |
|---|-------|----------|----------|
| **C1** | `d3_beam_elementforces` uses `R` instead of `R'` for force transformation | `src/beam.jl:324` | Stiffness uses `R' * kprime * R`; force must use `R'` to map local→global. **Produces wrong 3D beam forces.** |
| **C2** | `d2_beam_elementforces` transformation matrix inverted | `src/beam.jl:75-86` | `T` maps global→local; force calc does `kprime * T * u` with `u` in global coords. Should be `kprime * T' * u`. |
| **C3** | `d3_spring_elementforce` parameter shadowing: docstring says `u` = "angle about y-axis" but `u` is displacement vector | `src/spring.jl:186-188` | Line 188: `uy = deg2rad(thetay)` correct, but naming hides bug surface. Rename internal angle var. |
| **C4** | `d1_spring_elementstress` returns force, not stress | `src/spring.jl:26` | Computes `k * (u2 - u1)` → force. Stress = force / A. Missing division by area. |
| **C5** | Missing parameter validation for `A`, `I`, `E`, `G` in truss/beam | `src/truss.jl`, `src/beam.jl` | Only `L > 0` checked. Negative/zero `A`, `I`, `E`, `G` produce negative/zero stiffness silently. |

---

## HIGH — Refactoring & Architecture

| # | Issue | Location | Action |
|---|-------|----------|--------|
| **R1** | Duplicate Lambda/R rotation matrix construction in 3D beam stiffness & force (~30 lines each) | `src/beam.jl:193-225`, `293-314` | Extract to private `_d3_beam_rotation(x1,y1,z1,x2,y2,z2,L) -> R` |
| **R2** | `_d3_beam_kprime` lives in `assembly.jl` but belongs in `beam.jl` | `src/assembly.jl:52` | Move to `src/beam.jl` near other 3D beam internals. |
| **R3** | Inconsistent return types: 2D/3D spring/truss force functions return 1-element `Vector{Any}`; 1D returns `Vector` (2 elements) | `src/spring.jl`, `src/truss.jl` | Standardize: return `Vector{Float64}` with proper length (2 for 1D, 3 for 2D, 6 for 3D) or scalar for single-DOF. Match MATLAB reference (returns scalar/vector). |
| **R4** | `_assemble!` lacks bounds checks on `K` and `k` dimensions | `src/assembly.jl:21` | Add: `size(k) == (2ndofs,2ndofs)` and `max(idx) <= size(K,1)` guards with `AssemblyError`. |
| **R5** | Element functions take raw `Real` params instead of element structs (e.g., `d2_beam_elementstiffness(E,A,I,L,theta)` vs `d2_beam_elementstiffness(beam::Beam2D, L, theta)`) | All `src/*.jl` | Add convenience methods accepting structs; delegate to param-based versions. |

---

## MEDIUM — Consistency, Dependencies, Testing

| # | Issue | Location | Action |
|---|-------|----------|--------|
| **M1** | `deg2rad` used everywhere but not exported | `src/utils.jl:19` | Add `export deg2rad` to `LibFEM.jl` (public utility). |
| **M2** | `LinearAlgebra` used in tests/benchmark but not declared in `Project.toml` | `Project.toml` | Add to `[extras]` test deps. |
| **M3** | No test for 3D beam with arbitrary non-axis-aligned orientation | `test/runtests.jl` | Add case: `(0,0,0) → (3,4,12)` (5-12-13 triangle) with known stiffness. |
| **M4** | No tests for `ElementDimensionError` (defined, exported, never thrown/tested) | `test/runtests.jl` | Add `@test_throws ElementDimensionError` cases. |
| **M5** | No tests for spring/truss force return type consistency | `test/runtests.jl` | Verify return types match across dimensions. |

---

## LOW — Documentation & Project Hygiene

| # | Issue | Action |
|---|-------|--------|
| **D1** | No `README.md` — users cannot discover purpose, install, or use | Create with: description, install, quick example, API link. |
| **D2** | No CI test workflow (only opencode agent workflow) | Add `.github/workflows/test.yml` running `Pkg.test()` on PR/push. |
| **D3** | Module-level docstring in `src/LibFEM.jl` minimal | Expand: purpose, element table, angle convention (degrees), MATLAB reference (Kattan). |
| **D4** | Document "NDIM ≠ DOF" for beams: `Beam{2}` = 3 DOF/node, `Beam{3}` = 6 DOF/node | Add to `types.jl` or module docstring. |
| **D5** | `export` order in `LibFEM.jl` doesn't match `include()` order | Reorder exports to follow `include` sequence (types → errors → utils → assembly → spring → truss → beam → plot). |
| **D6** | Plot functions return `Plots.Plot` but lack return type annotations | Add `::Plots.Plot` to diagram functions in `plot.jl`. |
| **D7** | `.gitignore` missing Julia artifacts (`Manifest.toml`, `*.cov`, `*.cov.mem`, `.julia/`) | Add standard entries. |

---

## VERIFIED CORRECT (No Action Needed)

- All element stiffness matrices match MATLAB reference (244 comparison tests pass)
- All `L > 0` error paths tested with `@test_throws` for all element types
- Negative/zero parameter behavior documented as intentional for parametric/sensitivity studies
- `deg2rad` conversion accurate (tested)
- Assembly logic correct (verified vs MATLAB assemble functions)
- Type hierarchy well-designed: `AbstractElement{NDIM} → AbstractSpring/Truss/Beam{NDIM} → concrete`
- Symmetry (`K == K'`) of all stiffness matrices verified
- 3D beam vertical special case handled correctly (Λ = `[0 0 1; 0 1 0; -1 0 0]`)
- Export symbols tested for defensibility (18 assertions)
- 3D beam force computation correctly rebuilds `kprime` + rotation (no optimization bug; see R1 for dedup)

---

## PRIORITY EXECUTION ORDER

1. **C1–C5** — Correctness bugs (blocker for 3D beam/truss/spring reliability)
2. **R1–R4** — Refactors that prevent bug regression & improve maintainability
3. **M1–M5** — Tests & deps to lock in correctness
4. **D1–D7** — Project hygiene (can be parallelized)

---

## NOTES ON SUPPRESSED ITEMS

| Suppressed | Reason |
|------------|--------|
| `plot.jl` corruption report | Diff artifact; on-disk file reads correctly (lines 1–202, 10 diagram funcs) |
| Stale "Notice" comments in `plot.jl` about unexported functions | Already exported; comments noise |
| `d2_beam_elementtorsiondiagram` missing | 2D beams have no torsion DOF; comment was misleading |
| Inconsistent `L > 0` check in private helpers | Convention: public validates, private trusts caller — documented, not a bug |
| Implicit vs explicit `return` style | Style preference; no correctness impact |
| GPU acceleration study | Long-term; out of scope for correctness pass |
| Porting remaining MATLAB elements (quad, tri, brick, fluid) | Feature work; separate from code quality baseline |