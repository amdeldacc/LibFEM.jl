# Hyperplan Bundle — LibFEM.jl Enhancement Plan

**Generated:** 2026-07-27  
**Method:** Adversarial hyperplan (Pragmatist, Thorough Inspector, Architect, Visionary)  
**Input:** `docs/*.md`, `PRD.md`, `ARCHITECTURE.md`, `PHASES.md`, `MEMORY.md`, `RULES.md`, `TESTING.md`, `docs/enhancement-roadmap.md`, `docs/2026-07-27-enhancement-execution-plan.md`

---

## Tier 0 — Critical Bugs (Fix Immediately)

| # | Item | File(s) | Effort | Why |
|---|------|---------|--------|-----|
| C1 | `solver.jl` orphaned — file exists with `apply_bc!` but NOT included via `include()` in `LibFEM.jl` | `src/LibFEM.jl`, `src/solver.jl` | 5 min | Dead code. `apply_bc!` is unreachable. MEMORY.md claims Phase 4 active work but code does nothing. |
| C2 | Duplicate `_direction_cosines` test blocks in `runtests.jl` (lines 66–86 and 91–111 are identical) | `test/runtests.jl` | 1 min | Test duplication wastes cycles and could mask failures if one copy gets stale. |
| C3 | `d2_planeframe_elementlength` does not validate `L > 0` — can silently return 0 | `src/beam.jl` line 98 | 5 min | Every other length function validates. Inconsistent. |

## Tier 1 — Documentation Accuracy (Fix Next)

| # | Item | File(s) | Effort | Why |
|---|------|---------|--------|-----|
| D1 | PRD.md says "9 element types" → should be 10 (quadratic bar) | `PRD.md` | 1 min | Factual drift. |
| D2 | Octave validation count says "24 comparisons" — actual is 20 | `PRD.md`, `TESTING.md`, `README.md` | 5 min | 2 spring + 11 truss + 7 beam = 20, not 24. |
| D3 | LinearAlgebra compat = `1.12.0` in Project.toml — too restrictive for "Julia 1.x" claim | `Project.toml` | 1 min | Should be `1.6` or match actual compat range. |
| D4 | CI matrix only tests Julia 1.12 — PHASES.md claims "Julia 1 and 1.10" | `.github/workflows/ci.yml` | 1 min | Add `"lts"` or `"1"` to version matrix. |

## Tier 2 — Phase 4 Items (Polish & Refinements)

| # | Item | File(s) | Effort | Depends On |
|---|------|---------|--------|------------|
| P1 | Add `@views` to `d1_quadraticbar_assemble` (9 assignment statements) | `src/quadraticbar.jl` | 5 min | None |
| P2 | Delegate `d2_planeframe_elementlength` to `d2_truss_elementlength` | `src/beam.jl` | 5 min | None |
| P3 | Add `d2_planeframe_elementlength` and `d1_quadraticbar_elementlength` to README function table | `README.md` | 5 min | None |
| P4 | Add `d2_planeframe` to benchmarks (stiffness + assembly + forces) | `test/benchmark.jl` | 20 min | None |
| P5 | Error-path golden files for remaining element types (d3_truss, d2_beam, d2_planeframe, d3_spaceframe, d1_quadraticbar) | `test/golden/` | 10 min | None |
| P6 | Plotting color audit — verify ext/LibFEMPlotsExt.jl uses `:black` not `'k'` everywhere | `ext/LibFEMPlotsExt.jl` | 5 min | None |
| P7 | Docstring audit — fix extra `export` keyword, PascalCase/snake_case mismatches | `src/*.jl` docstrings | 30 min | None |

## Tier 3 — Execution Plan Items (From 2026-07-27 Plan)

| # | Item | File(s) | Effort | Depends On |
|---|------|---------|--------|------------|
| E1 | Direction cosines degenerate → throw `ElementParameterError` instead of `@warn` (breaking change — batch for v2.0) | `src/utils.jl` | 10 min | None |
| E2 | Golden regression: replace `@warn + continue` with `@error + @test false` for missing functions | `test/golden_regression.jl` | 10 min | None |
| E3 | Direct `_assemble!` test — call internal helper with various ndofs | `test/runtests.jl` | 10 min | None |
| E4 | Convergence/refinement tests — d1_truss uniform bar, d2_beam cantilever | `test/convergence.jl` (new) | 2-3h | None |
| E5 | Multi-element stress recovery tests — 3-element d1_truss, verify continuity | `test/runtests.jl` | 1-2h | None |

## Tier 4 — Medium-Term Enhancements

| # | Item | File(s) | Effort | Depends On |
|---|------|---------|--------|------------|
| M1 | Trait-based type hierarchy: `ndofs(::Type{T})`, `element_family(::Type{T})` | `src/types.jl` + new `src/interface.jl` | 2-3 days | v2.0 consideration |
| M2 | `eltype` propagation through element functions | All `src/*.jl` | 1-2 days | v2.0 with M1 |
| M3 | StaticArrays for fixed-size matrices | All `src/*.jl` | 3-4 days | v2.0, batches with M1+M2 |

## Tier 5 — Visionary (Educational Mission)

| # | Item | File(s) | Effort | Why |
|---|------|---------|--------|-----|
| V1 | Proto: single Pluto notebook (01_springs.jl) — stiffness slider, assembly visualization, interactive load | `notebooks/` | 1-2 days | Highest educational ROI. Requires Pluto dep (weak dep). |
| V2 | Visual assembly explorer — color-coded DOF overlay for assembly process | `ext/LibFEMVisualExt.jl` (new) | 2-3 days | Bridges the local→global conceptual gap that students struggle with most. |
| V3 | Educational error mode — `verbose=true` keyword on element functions explaining *why* inputs fail in pedagogical terms | `src/*.jl` | 2-3 days | Turns error messages into teaching moments. |

---

## Execution Strategy

### Phase A — Hotfix & Docs (Tiers 0-1, can parallelize fully)
```
Parallel: C1, C2, C3, D1, D2, D3, D4
No ordering dependencies.
```

### Phase B — Polish (Tier 2, fully parallel after Phase A)
```
Parallel: P1, P2, P3, P4, P5, P6, P7
No ordering dependencies.
```

### Phase C — Execution Plan (Tier 3)
```
Parallel: E1 (breaking → branch), E2, E3
Then:     E4, E5 (larger, depend on none)
```

### Phase D — Medium/Long-Term (Tier 4, v2.0)
```
Ordered:  M1 → M2 → M3 (cumulative API changes)
```

### Phase E — Visionary (Tier 5)
```
V1 → V2 → V3 (increasing complexity, all independent of Tiers 0-4)
```
