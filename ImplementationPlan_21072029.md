# Implementation Plan: LibFEM.jl v0.2 → v0.4

**Date:** 2026-07-21  
**Commits:** 7 source commits, 1 rollup PR (#70)  
**PR:** [#70 — test hardening, doc convention fixes, shared helpers](https://github.com/amdeldacc/LibFEM.jl/pull/70)  
**Verification:** 701 unit tests + 427 MATLAB comparison + 24 Octave validation = ~1152 total

---

## Overview

This plan documents all changes between tag `v0.2` and `v0.4`. The work is organized into **5 sprints** delivered via **6 parallel waves**, with an additional layer of **infrastructure** changes (CI, Octave validation, docs).

**Legend:**
- `[C{N}]` = Correctness concern (adversarial review finding)
- `[C{N}w]` = Warning-level correctness concern (adversarial review)
- `[H{N}]` = Housekeeping concern (adversarial review)

---

## Infrastructure (v0.2 base → pre-enhancement)

Done before the main enhancement sprints:

| Commit | Scope | Description |
|--------|-------|-------------|
| `85a31e5` | `spring.jl`, `LibFEM.jl`, `runtests.jl` | Remove meaningless `d1_spring_elementstress` (identical to `elementforce` for 0D spring) |
| `d24a082` | `scripts/validate_matlab.jl`, `test/comparison.jl`, `test/matlab_adapters.jl`, `test/octave_runner.jl` | Add Octave-based MATLAB reference validation pipeline |
| `d580889` | `README.md` | Comprehensive README rewrite with full element reference, naming convention docs, OpenWiki links |
| `50d894b` | `README.md` | Remove references to gitignored files |
| `27beeb8` | — | super-linter fixes (markdown, prettier, pylint) |
| `4f51fcc` | `.github/workflows/ci.yml` | Fix workflow permissions |

**PR:** Infrastructure changes landed incrementally (not via single PR).

---

## Sprint 0 — Safety Net [C8]

### Goal
Reject `i=j` assembly calls (self-assembly produces corrupted matrices).

### Files Changed
- `src/assembly.jl` (+1 line)
- `test/runtests.jl` (+14 lines)

### Changes

```
src/assembly.jl: _assemble! guard
  └─ i == j && throw(AssemblyError(...))
```

**Exact edit:**
```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
    @views begin
        ...
```

**Test coverage** (3 cases):
- `d1_truss_assemble` (1 DOF/node)
- `d2_truss_assemble` (2 DOF/node)  
- `d2_beam_assemble` (3 DOF/node)

### Verification
```julia
julia> using LibFEM; K=zeros(2,2); k=d1_truss_elementstiffness(1,1,1)
julia> try d1_truss_assemble(K,k,1,1); catch e; @assert e isa AssemblyError; end  # ✓
```

---

## Sprint 1 — Correctness Fixes [C1, C3]

### Goal
Fix `d1_truss_elementstrain` returning 2-vector instead of scalar; fix near-vertical beam `==` comparison.

### Files Changed
- `src/truss.jl` (1 function body)
- `src/beam.jl` (2 conditionals)
- `test/runtests.jl` (+14 lines, 2 assertions fixed)

### Changes

**C1 — `d1_truss_elementstrain` scalar return:**
```julia
# Before (2×2 matrix × u → 2-vector):
return 1 / L * [1 -1; -1 1] * u

# After (scalar strain formula):
return (u[2] - u[1]) / L
```

**C3 — near-vertical beam tolerance:**
```julia
# Before (exact equality fails for tiny deviations):
if x1 == x2 && y1 == y2

# After (stable tolerance on direction cosines):
if hypot(Cx, Cy) < 1e-12
```
Applied in both `d3_beam_elementstiffness` and `d3_beam_elementforces`.

**Test fixes:**
```julia
# Before (2-vector assertion with wrong sign):
@test eps ≈ [2.5e-4; -2.5e-4]

# After (scalar, negative = compression):
@test eps ≈ -2.5e-4
```

**Near-vertical regression test:**
```julia
@testset "near-vertical beam" begin
    Ke = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4)
    @test all(!isnan, Ke)
    # ...
end
```

---

## Sprint 2 — Shared Helpers & UX [C2, C7, C4]

### Goal
Extract direction cosine computation, force projection, and validation into shared helpers in `src/utils.jl`; refactor all call sites; add `_beamdiagram` helper.

### Files Changed
- `src/utils.jl` (+58 lines, 5 new functions)
- `src/truss.jl` (-93 lines net, 10 sites refactored)
- `src/spring.jl` (-53 lines net, 4 sites refactored)
- `src/beam.jl` (-32 lines net, 6 sites refactored)
- `src/plot.jl` (+4 lines, new helper + sign convention doc)

### New Helpers (added to `src/utils.jl`)

| Helper | Signature | Purpose |
|--------|-----------|---------|
| `_direction_cosines(theta)` | `(Real) → (C, S)` | 2D: `deg2rad` → `cos`/`sin` |
| `_direction_cosines(thetax, thetay, thetaz)` | `(Real, Real, Real) → (Cx, Cy, Cz)` | 3D: `deg2rad` → cosines + **C2 validation** |
| `_truss_force_component(Cx, Cy, u)` | `(Real, Real, Vector) → Real` | 2D: `[-Cx -Cy Cx Cy] · u` |
| `_truss_force_component(Cx, Cy, Cz, u)` | `(Real, Real, Real, Vector) → Real` | 3D: `[-Cx -Cy -Cz Cx Cy Cz] · u` |
| `validate_positive(x, name)` | `(Real, String) → Nothing` | Throw `ElementParameterError` if `x ≤ 0` |

### C2 Validation (direction cosine warning)

The 3-arg `_direction_cosines` emits a warning when `Cx²+Cy²+Cz²` deviates from 1 by >1e-12:

```julia
function _direction_cosines(thetax_deg::Real, thetay_deg::Real, thetaz_deg::Real)
    ...
    abs(Cx^2 + Cy^2 + Cz^2 - 1) > 1e-12 &&
        @warn "Direction cosines do not form a unit vector: Cx²+Cy²+Cz² = $nsq ≠ 1"
    return (Cx, Cy, Cz)
end
```

This catches invalid angle combinations (e.g. `θx=θy=θz=90°` which cannot form a unit vector).

### Refactored Sites (callers → helpers)

**`src/truss.jl`** — 10 `L>0` guards replaced with `validate_positive(L, "L")`:
- `d1_truss_elementstiffness`, `d1_truss_elementstrain`
- `d2_truss_elementstiffness`, `d2_truss_elementforces`, `d2_truss_elementstrain`, `d2_truss_elementstress`
- `d3_truss_elementstiffness`, `d3_truss_elementforces`, `d3_truss_elementstrain`, `d3_truss_elementstress`

6 `deg2rad`+`cos` blocks replaced with `_direction_cosines` + `_truss_force_component`:
- `d2_truss_elementstiffness`, `d2_truss_elementforces`, `d2_truss_elementstrain`, `d2_truss_elementstress`
- `d3_truss_elementstiffness`, `d3_truss_elementforces`, `d3_truss_elementstrain`, `d3_truss_elementstress`

**`src/spring.jl`** — 4 `deg2rad`+`cos` blocks replaced:
- `d2_spring_elementstiffness`, `d2_spring_elementforce`
- `d3_spring_elementstiffness`, `d3_spring_elementforce`

**`src/beam.jl`** — 4 `L>0` guards replaced with `validate_positive`:
- `d2_beam_elementstiffness`, `d2_beam_elementforces`
- `d3_beam_elementstiffness`, `d3_beam_elementforces`

2 `deg2rad`+`cos` blocks replaced with `_direction_cosines`:
- `d2_beam_elementstiffness`, `d2_beam_elementforces`

### `_beamdiagram` Helper (src/plot.jl)

All 9 diagram functions refactored to one-liners via a private helper:

```julia
function _beamdiagram(f::AbstractVector, L::Real, title_::AbstractString, z_fn::Function)
    x = [0, L]
    z = z_fn(f, L)
    p = plot(x, z, title=title_)
    plot!(p, x, [0, 0], color=:black)
    return p
end
```

Result: **-72 lines of diagram code**, all 9 functions become one-liners.

### Sign Convention Documentation (C7)

Added to `src/plot.jl` module header:
```
# Sign convention follows Kattan: axial positive = tension,
# shear positive = clockwise on left face, moment positive = sagging.
# Positive values plotted above beam axis.
```

---

## Sprint 3 — Test Hardening

### Goal
Add property-based tests (symmetry, row-sum-zero), negative path coverage, diagram tests, and assembly edge case tests.

### Files Changed
- `test/runtests.jl` (+132 lines, 4 new testsets)

### New Testsets (4)

| Testset | Lines | Coverage |
|---------|-------|----------|
| `"element property tests"` | ~20 | Symmetry + row-sum-zero for all 7 stiffness types |
| `"negative path tests"` | ~10 | `L=0`, `L=-1` → `ElementParameterError`; impossible angles → `@test_logs (:warn, ...)` |
| `"diagram functions"` | ~15 | All 9 diagram functions return `Plots.Plot` |
| `"assembly edge cases"` | ~20 | Non-contiguous node assembly; spring/truss identity (1D, 2D, 3D) |

### Key Test Patterns

**Row-sum-zero (rigid-body motion):**
```julia
@test all(k1 * ones(2) .≈ 0.0 atol=1e-15)   # d1_truss
@test all(k3b * ones(12) .≈ 0.0 atol=1e-12)  # d3_beam
```

**Spring/truss identity:**
```julia
@test d1_spring_elementstiffness(500) == d1_truss_elementstiffness(500, 1, 1)  # spring(k) = truss(k, 1, 1)
@test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)  # spring(EA/L) = truss(E, A, L)
```

**C2 warning path:**
```julia
@test_logs (:warn, r"Direction cosines do not form a unit vector") d3_truss_elementstiffness(1, 1, 1, 90, 90, 90)
```

---

## Sprint 4 — Documentation & Visibility

### Goal
Add "positive = tension" docstrings, local/global frame notes, sign convention docs, fix README A>0 claim, deprecation notice.

### Files Changed
- `src/truss.jl` — 9 functions with `(positive = tension)` appended to Returns
- `src/spring.jl` — 3 `*_elementforce` functions with `(positive = tension)`
- `src/beam.jl` — `d2_beam_elementforces`, `d3_beam_elementforces` with `(positive = tension)` + `# Frame` notes
- `src/plot.jl` — Sign convention header
- `src/types.jl` — Deprecation notice block
- `README.md` — Fix A>0 claim in Validation section

### Docstring Changes

**"Positive = tension"** added to return docs:
```julia
# Before:
# Returns
# The element force (scalar).

# After:
# Returns
# The element force (scalar, positive = tension).
```

**Local/global frame notes (C4):**
```julia
# d2_beam_elementstiffness: # Frame — Stiffness in **global** coordinates via rotation transform.
# d2_beam_elementforces:    # Frame — Forces in **local** coordinate system (kprime * T * u).
# d3_beam_elementstiffness: # Frame — Stiffness in **global** coordinates via R' * kprime * R.
# d3_beam_elementforces:    # Frame — Forces in **local** coordinate system (kprime * R * u).
```

### README Fix (H8)

```diff
- # Validation: Most stiffness/length functions validate positive inputs (L > 0, A > 0)
+ # Validation: Most stiffness/length functions validate positive inputs (L > 0).
+ # Note: A ≤ 0 is intentionally allowed for parametric studies (negative area produces negated matrices).
```

### Deprecation Notice (src/types.jl)

```
# ═══════════════════════════════════════════════════════════
# Deprecation Notice (2026-07)
# ═══════════════════════════════════════════════════════════
# The abstract type hierarchy and @kwdef structs in this file
# are retained for backward compatibility but are NOT used by
# any element function. All functions operate on plain
# Real/AbstractMatrix/AbstractVector parameters.
# These types may be removed in LibFEM 2.0.
```

---

## Verification Gates

All gates pass on `v0.4`:

```bash
$ julia --project=. test/runtests.jl                           # 701 tests ✓
$ julia --project=. scripts/validate_matlab.jl all              # 24 Octave comparisons ✓
$ julia --project=. -e 'using LibFEM; println("OK")'            # Module loads ✓
```

| Gate | Test | Status |
|------|------|--------|
| C1 | `d1_truss_elementstrain(4.0, [0.001,0.0]) ≈ -2.5e-4` | ✓ scalar, negative=compression |
| C2 | `d3_truss_elementstiffness(1,1,1,90,90,90)` warns | ✓ |
| C3 | `d3_beam_elementstiffness(..., 1e-12,1e-12,4)` no NaN | ✓ |
| C7 | Diagram sign convention documented | ✓ |
| C8 | `d1_truss_assemble(K,k,1,1)` → `AssemblyError` | ✓ |
| H8 | README `A>0` claim corrected | ✓ |

---

## Commit History (v0.2 → v0.4)

```
a3888cd v0.4: test hardening, doc convention fixes, shared helpers (#70)  ← ROLLUP
27beeb8 fix: resolve super-linter failures
d24a082 Add Octave-based MATLAB reference validation (#42)
85a31e5 fix(spring): remove meaningless d1_spring_elementstress (#37)
4f51fcc fix: remove invalid 'workflows' permission scope
50d894b docs: remove references to gitignored files from README.md
d580889 docs: update README.md with comprehensive element reference
```

PR #70 (`a3888cd`) is the rollup containing all 5 sprints. The remaining 6 commits are infrastructure/docs landed separately.

---

## Diff Summary

```
120 files changed, 25851 insertions(+), 250 deletions(-)

Key source changes:
  src/utils.jl       |  58 +++   (5 new shared helpers)
  src/truss.jl       |  99 ++--   (refactored to helpers)
  src/spring.jl      |  49 ++--   (refactored + d1_spring_elementstress removed)
  src/beam.jl        |  36 ++--   (hypot guard + frame notes)
  src/assembly.jl    |   1 +    (i=j guard)
  src/plot.jl        |   4 +    (_beamdiagram helper + sign convention)
  src/types.jl       |   9 +    (deprecation notice)
  src/LibFEM.jl      |   2 +-   (export diff: removed d1_spring_elementstress)
  test/runtests.jl   | 119 ++++   (4 new testsets + 2 assertion fixes)
  test/comparison.jl | 143 ++++   (2D Spring Full Problem test)
  README.md          | comprehensive rewrite
```
