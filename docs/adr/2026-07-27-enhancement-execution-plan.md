# LibFEM.jl Enhancement Execution Plan

**Generated:** 2026-07-27  
**Method:** Adversarial multi-agent hyperplan (5 critics — Pragmatist, Thorough Inspector, Architect, Visionary, Deep Researcher)  
**Input:** `docs/enhancement-roadmap.md`, `docs/2026-07-25_code_review.md`, `docs/2026-07-26-code-review.md`, AI context files (PRD.md, ARCHITECTURE.md, PHASES.md, MEMORY.md, RULES.md, TESTING.md, DECISIONS.md)

---

## 1. Task Dependency Graph

| ID | Item | Depends On | Reason |
|----|------|------------|--------|
| 1 | `apply_bc!` helper | None | New file, no code dependencies |
| 2 | Fix degenerate direction cosines error msg | None | Isolated change in utils.jl |
| 3 | Fix golden regression silent failure | None | Isolated change to test framework |
| 4 | Add Julia LTS to CI matrix | None | Single-line CI config change |
| 5 | Fix duplicate `_direction_cosines` test block | None | Delete duplicate lines in runtests.jl |
| 6 | Add direct `_assemble!` test | None | New test block, no source changes |
| 7 | Missing `elementlength` validation | None | Isolated change in quadraticbar.jl |
| 8 | Missing benchmarks | None | Add to benchmark.jl only |
| ~~9~~ | ~~Assembly distinctness for 3-node~~ | ~~—~~ | **SKIP** — already implemented |
| 10 | Error-path golden files for all element types | None | Independent file additions |
| 11 | Consistent `@views` in assembly | None | Add macro to quadraticbar.jl |
| 12 | `d2_planeframe_elementlength` delegate | None | Simple refactor in beam.jl |
| 13 | d2_planeframe length naming in tests | 12 (weak) | Verify after 12 merged |
| ~~14~~ | ~~d1_truss_assemble consistent pattern~~ | ~~—~~ | **SKIP** — already consistent |
| 15 | Convergence/refinement testing | 1 (weak) | Uses BC helper if available; manual fallback works |
| 16 | Multi-element stress recovery tests | 1 (weak) | Same — cleaner with apply_bc! |

**Critical path**: None — 14/16 items fully independent.

---

## 2. Wave Parallelization

### Wave 1 — All independent, fire simultaneously

```
Item 1:  apply_bc! helper          [20 min]  ── src/solver.jl (new)
Item 2:  direction cosines error   [ 5 min]  ── src/utils.jl
Item 3:  golden silent failure      [10 min]  ── test/golden_regression.jl
Item 4:  Julia LTS in CI            [ 1 min]  ── .github/workflows/ci.yml
Item 5:  duplicate test removal     [ 1 min]  ── test/runtests.jl
Item 6:  _assemble! direct test    [10 min]  ── test/runtests.jl
Item 7:  elementlength validation   [10 min]  ── src/quadraticbar.jl
Item 8:  missing benchmarks         [20 min]  ── test/benchmark.jl
Item 10: error-path golden files    [10 min]  ── test/golden/manifests.toml + regenerate
Item 11: @views in quadraticbar    [ 5 min]  ── src/quadraticbar.jl
Item 12: planeframe length delega   [ 5 min]  ── src/beam.jl
Item 15: convergence tests          [2-3h]   ── test/convergence.jl (new)
Item 16: multi-element stress tests [1-2h]   ── test/runtests.jl
```

### Wave 2 — After Wave 1 items merged

```
Item 13: verify test naming         [ 5 min]  ── verify only (no change likely needed)
```

---

## 3. Item-by-Item Specification

### Item 1: `apply_bc!` helper

**Test**: 2-spring system with `apply_bc!(K, F, [1=>0.0, 3=>0.0])`, verify u[1]≈0, u[3]≈0, u[2]≈10/(200+250).
**Green**: `src/solver.jl` — elimination method. Loops constraints, zeros row/col, sets K[dof,dof]=1, F[dof]=val.
**Files**: CREATE `src/solver.jl`, MODIFY `src/LibFEM.jl` (include + export), MODIFY `test/runtests.jl`.

### Item 2: Direction cosines degenerate error

**Red**: `@test_throws ElementParameterError LibFEM._direction_cosines(90, 90, 90)`
**Green**: In `src/utils.jl`, before warning: `if nsq ≤ 1e-12 throw(ElementParameterError(...))`
**Files**: MODIFY `src/utils.jl`, MODIFY `test/runtests.jl`.

### Item 3: Golden regression silent failure

**Red**: Add non-existent func name to manifest, verify test fails.
**Green**: Change `@warn + continue` → `@error + @test false + continue`.
**Files**: MODIFY `test/golden_regression.jl`.

### Item 4: Julia LTS in CI

**Green**: `version: ["1", "lts"]` in `.github/workflows/ci.yml`.
**Files**: MODIFY `.github/workflows/ci.yml`.

### Item 5: Duplicate test block removal

**Green**: Delete `runtests.jl` lines 91-111 (second `@testset "_direction_cosines"`).
**Files**: MODIFY `test/runtests.jl`.

### Item 6: Direct `_assemble!` test

**Green**: Testset calling `LibFEM._assemble!(K, k, i, j, ndofs)` with various ndofs, verify DOF offsets, bounds checking.
**Files**: MODIFY `test/runtests.jl`.

### Item 7: elementlength validation

**Red**: `@test_throws ElementParameterError d1_quadraticbar_elementlength(1, 1)`
**Green**: Add `validate_positive(L, "L")` to `d1_quadraticbar_elementlength`.
**Files**: MODIFY `src/quadraticbar.jl`, MODIFY `test/runtests.jl`.

### Item 8: Missing benchmarks

**Green**: Add d2_planeframe stiffness, d2_planeframe assembly (500 el), d1_quadraticbar assembly (500 el), d2_planeframe forces to `test/benchmark.jl`.
**Files**: MODIFY `test/benchmark.jl`.

### Item 10: Error-path golden files

**Green**: Add manifests for d3_truss, d2_beam, d2_planeframe, d3_spaceframe, d1_quadraticbar zero-L cases. Regenerate.
**Files**: MODIFY `test/golden/manifests.toml`, new `.bin` files.

### Item 11: `@views` in quadraticbar assembly

**Green**: Wrap 9 assignment statements in `@views begin ... end`.
**Files**: MODIFY `src/quadraticbar.jl`.

### Item 12: `d2_planeframe_elementlength` delegation

**Green**: Replace 5-line body with `return d2_truss_elementlength(x1, y1, x2, y2)`.
**Files**: MODIFY `src/beam.jl`.

### Item 15: Convergence/refinement testing

**Red**: Define exact solutions: d1_truss (uniform bar, axial load), d2_beam (cantilever, tip load).
**Green**: `test/convergence.jl`. For each: solve with 2^n elements, compute L2 error, verify convergence rate O(h²) (linear) or O(h⁴) (quadratic).
**Files**: CREATE `test/convergence.jl`, MODIFY `test/runtests.jl` (include).

### Item 16: Multi-element stress recovery

**Red**: For a 3-element d1_truss model, stress at shared node should be continuous.
**Green**: Add testset building 3-element model, computing stress per element, verifying continuity at shared nodes.
**Files**: MODIFY `test/runtests.jl`.

---

## 4. Verification Gates

| Gate | Command | Expected |
|------|---------|----------|
| G1 — Per item | `julia --project=. test/runtests.jl` | 0 failures |
| G2 — Benchmarks | `julia --project=. test/benchmark.jl` | All complete |
| G3 — Golden regen | `julia --project=. test/golden/generate_golden.jl` | All succeed |
| G4 — Convergence | `julia --project=. -e 'include("test/convergence.jl")'` | Rates within bounds |
| G5 — Full suite | `julia --project=. -e 'using Pkg; Pkg.test()'` | All pass |

---

## 5. Execution Strategy (6 Commits)

```
Commit 1: "fix: small fixes"         → items 2,5,7,11,12
Commit 2: "feat: apply_bc! helper"   → item 1
Commit 3: "fix: golden hardening"    → items 3,10
Commit 4: "ci: CI + benchmarks"      → items 4,8
Commit 5: "test: major test adds"    → items 6,15,16
Commit 6: "test: final verify"       → item 13 (if needed)
```

Each commit: TDD red→green→full suite. Parallelize within Wave 1 before sequencing commit order.

---

## 6. Risk Assessment

| Item | Risk | What could go wrong | Mitigation |
|------|------|---------------------|------------|
| 1 | Low-Med | BC convention choice | Elimination method. 20-min revert. |
| 2 | Low | Existing test expects @warn | No test for degenerate (90,90,90). |
| 3 | Low- | False positive if func legitimately missing | Manifest must match module exports. |
| 4 | Low | Plots may not support LTS | `continue-on-error: true` for LTS. |
| 5 | None | Delete wrong lines | Target lines 91-111 exactly. |
| 6 | Low | Internal func inaccessible | `LibFEM._assemble!` accessible. |
| 7 | Low | Zero-length already handled | Consistent with other length funcs. |
| 8 | Low | Type instability in benchmark | Same paths as existing benchmarks. |
| 10 | Low | Wrong params for regen | Follow existing error-path pattern. |
| 11 | Low | @views with non-1-indexed arrays | 1-indexed. Existing code works. |
| 12 | Low | Call overhead | Julia inlines trivial delegation. |
| 15 | Medium | Convergence rate off; BC complexity | Generous tolerances. Manual fallback. |
| 16 | Low-Med | Stress continuity at shared nodes | Direct computation for 1D truss. |

**Overall risk**: Low. Items 15-16 have implementation uncertainty but are isolated to test files.

---

*Generated by Atlas (OhMyOpenAGent) via adversarial hyperplan. Team: Pragmatist, Thorough Inspector, Architect, Visionary, Deep Researcher.*
