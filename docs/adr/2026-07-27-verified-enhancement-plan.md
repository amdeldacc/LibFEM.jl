# LibFEM.jl — Verified Enhancement Plan

**Generated:** 2026-07-27  
**Method:** Adversarial hyperplan (Pragmatist, Thorough Inspector, Architect, Visionary) → Plan agent verification pass  
**Inputs:** `docs/enhancement-roadmap.md`, `docs/2026-07-27-enhancement-execution-plan.md`, `docs/2026-07-25_code_review.md`, all AI context files (PRD.md, ARCHITECTURE.md, PHASES.md, MEMORY.md, RULES.md, TESTING.md), full `src/` and `test/` source audit  

---

## Corrections to Previous Plans

| Claim | Previous Plan | Verified Reality | Action |
|-------|--------------|-----------------|--------|
| `solver.jl` wired in | Assumed included | File exists but NOT `include()`'d in `LibFEM.jl` — dead code | ✅ Include it |
| `_direction_cosines` test blocks | Assumed singular | Lines 66–86 and 91–111 are identical duplicates | ✅ Delete duplicate |
| `d2_planeframe_elementlength` validates L>0 | Assumed yes | No `validate_positive` call — can silently return 0 | ✅ Add validation |
| PRD element count | "9 element types" | Code has 10 (includes quadratic bar) | ✅ Fix to 10 |
| Octave validation count | "24 comparisons" | Code has 20 (2 spring + 11 truss + 7 beam) | ✅ Fix to 20 |
| `LinearAlgebra` compat | `"1.12.0"` | Too restrictive for "Julia 1.x" claim | ✅ Widen to `"1.6"` |
| CI matrix | Only Julia 1.12 | PHASES.md claims "tested on Julia 1 and 1.10" | ✅ Add `"lts"` |
| `@views` in quadraticbar | Suggested | Scalar ops `K[i,i] += k[1,1]` — `@views` is a no-op | ❌ Dismissed |
| Plotting `'k'` → `:black` | Claimed active work | `ext/LibFEMPlotsExt.jl` already uses `:black` | ❌ Dismissed |
| Docstring `export` keyword | Claimed present | Zero matches in all `src/*.jl` docstrings | ❌ Dismissed |

---

## Task Dependency Graph

All tasks in Wave 1 are **fully independent** — no item blocks another.  
Wave 2 tasks are also independent of each other and of Wave 1.

```
Wave 1 (Start immediately — ~1 hour total):
├── T1: Include solver.jl in module
├── T2: Remove duplicate test block
├── T3: Fix planeframe length validation + delegate
├── T4: Fix doc counts (PRD, TESTING)
├── T5: Widen LinearAlgebra compat
├── T6: Add Julia LTS to CI matrix
├── T7: Fix README function table
├── T8: Add planeframe benchmarks
├── T9: Add error-path golden files
├── T10: Docstring audit (if needed)
     ╰   All 10 items 100% parallel.

Wave 2 (After Wave 1 — ~4 hours total):
├── T11: Direction cosines → throw (breaking, v2.0 branch)
├── T12: Golden regression error format hardening
├── T13: _assemble! direct test
├── T14: Convergence tests (new test/convergence.jl)
├── T15: Multi-element stress recovery tests
     ╰   All 5 items independent of each other.
```

---

## Wave 1 — Critical & Polish Items

### T1: Include solver.jl in module

**Files:** `src/LibFEM.jl`  
**Effort:** 5 min  
**Category:** `quick`

**Changes:**
- Add `include("solver.jl")` after `include("quadraticbar.jl")` (line 14)
- Add `export apply_bc!` in the export section (after line 75)

**Verification:**
```bash
julia --project=. -e 'using LibFEM; K=zeros(3,3); F=zeros(3); apply_bc!(K,F,[1=>0.0,3=>0.0])'
julia --project=. test/runtests.jl
```

---

### T2: Remove duplicate `_direction_cosines` test block

**Files:** `test/runtests.jl`  
**Effort:** 1 min  
**Category:** `quick`

**Changes:**
- Delete lines 88–111 (entire second `@testset "_direction_cosines"` block)

**Verification:**
```bash
julia --project=. test/runtests.jl
# Verify _direction_cosines tests still run and pass
```

---

### T3: Fix `d2_planeframe_elementlength` — add L>0 validation + delegate

**Files:** `src/beam.jl`  
**Effort:** 5 min  
**Category:** `quick`

**Changes:**
- Replace body with: `d2_truss_elementlength(x1, y1, x2, y2)` (which includes `validate_positive(L, "L")`)
- In `test/runtests.jl:407`: change `@test d2_planeframe_elementlength(1, 2, 1, 2) == 0.0` to `@test_throws ElementParameterError d2_planeframe_elementlength(1, 2, 1, 2)`

**Verification:**
```bash
julia --project=. test/runtests.jl
```

---

### T4: Fix documentation counts

**Files:** `PRD.md`, `TESTING.md`  
**Effort:** 5 min  
**Category:** `writing`

**Changes:**
- `PRD.md:22` — "9 element types" → "10 element types"
- `PRD.md:23` — "all 9 `*_assemble`" → "all 10 `*_assemble`"
- `PRD.md:26` — "24-comparison" → "20-comparison"
- `PRD.md:46` — "24+ comparisons" → "20+ comparisons"
- `TESTING.md:11` — "24 comparisons" → "20 comparisons"

---

### T5: Widen `LinearAlgebra` compat

**Files:** `Project.toml`  
**Effort:** 1 min  
**Category:** `quick`

**Changes:**
- `Project.toml:16` — `LinearAlgebra = "1.12.0"` → `LinearAlgebra = "1.6.0"`

**Risk:** Low — LinearAlgebra is extremely stable between 1.6 and 1.12.

**Verification:**
```bash
julia --project=. -e 'using LibFEM'
julia --project=. test/runtests.jl
```

---

### T6: Add Julia LTS to CI matrix

**Files:** `.github/workflows/ci.yml`  
**Effort:** 1 min  
**Category:** `quick`

**Changes:**
- Add `- "lts"` after `- "1.12"`:

```yaml
matrix:
  version:
    - "1.12"
    - "lts"
```

**Risk:** Medium — tests might not pass on LTS Julia (~1.10). Verify via CI.

---

### T7: Fix README function table

**Files:** `README.md`  
**Effort:** 5 min  
**Category:** `writing`

**Changes:**
- Add quadratic bar functions to the 1-D Elements table:

```
| `d1_quadraticbar_elementlength(x1, x2)` | Element length (abs difference) |
| `d1_quadraticbar_elementstiffness(E, A, L)` | 3×3 stiffness for 3-node quadratic bar |
| `d1_quadraticbar_elementforces(Ke, u)` | Nodal force vector (3×1) |
| `d1_quadraticbar_elementstress(Ke, u, A)` | Nodal stress vector (3×1) |
| `d1_quadraticbar_assemble(K, k, i, j, m)` | Assemble (1 DOF/node, 3-node element) |
```

---

### T8: Add d2_planeframe benchmarks

**Files:** `test/benchmark.jl`  
**Effort:** 20 min  
**Category:** `unspecified-low`

**Changes:**
- Add stiffness benchmark (after d2_beam, line ~34):

```julia
STIFF["d2_planeframe"] = @benchmarkable d2_planeframe_elementstiffness(200e9, 0.01, 2e-4, 2.0, 30)
```

- Add assembly benchmark (after d2_beam assembly, line ~117):

```julia
const n_d2pf = 500
const n_d2pf_nodes = n_d2pf + 1
K_d2pf = zeros(3 * n_d2pf_nodes, 3 * n_d2pf_nodes)
k_d2pf_elements = [d2_planeframe_elementstiffness(200e9, 0.01, 2e-4, 2.0, 30) for _ in 1:n_d2pf]
ASSEMBLE["d2_planeframe"] = @benchmarkable begin
    fill!($K_d2pf, 0.0)
    for idx in 1:$n_d2pf
        d2_planeframe_assemble($K_d2pf, $k_d2pf_elements[idx], idx, idx + 1)
    end
end
```

- Add forces benchmark (after d2_beam forces, line ~192):

```julia
const u_pf = [0.001; zeros(5)]
FORCES["d2_planeframe"] = @benchmarkable d2_planeframe_elementforces(200e9, 0.01, 2e-4, 2.0, 30, $u_pf)
```

**Verification:**
```bash
julia --project=. test/benchmark.jl
```

---

### T9: Add error-path golden files

**Files:** `test/golden/manifests.toml` + 5 new `.bin` files  
**Effort:** 10 min  
**Category:** `unspecified-low`

**Changes:**
- Add entries to `manifests.toml` for: `d3_truss_stiffness_zeroL`, `d2_beam_stiffness_zeroL`, `d2_pf_stiffness_zeroL`, `d3_sf_stiffness_zeroL`, `d1_qbar_stiffness_zeroL`
- Create 5 binary error-marker files (`Int32(0) + Int32(0)` = 8 bytes each)

**Verification:**
```bash
julia --project=. test/runtests.jl
```

---

### T10: Docstring audit

**Files:** `src/*.jl` (if needed)  
**Effort:** 30 min  
**Category:** `unspecified-low`

**Changes:** Scan for PascalCase/snake_case mismatches in function-reference docstrings. Fix any found.

---

## Wave 2 — Execution Plan Items

### T11: Direction cosines degenerate → throw (v2.0 breaking change)

**Files:** `src/utils.jl`, `test/runtests.jl`  
**Effort:** 10 min  
**Category:** `deep`

**Risk:** Breaking change — existing code passing invalid direction cosines silently will now fail. Batch for v2.0.

**Changes:**
- In `_direction_cosines`: replace `@warn + normalize` with `throw(ElementParameterError(...))` when `|nsq - 1| > 1e-12`
- Update tests that expect `@warn` to expect `@test_throws`

---

### T12: Golden regression error format hardening

**Files:** `test/golden_regression.jl`  
**Effort:** 10 min  
**Category:** `quick`

**Changes:**
- Lines 63-66: change `@warn + continue` to `@error + @test false + continue`

---

### T13: Direct `_assemble!` test

**Files:** `test/runtests.jl`  
**Effort:** 10 min  
**Category:** `unspecified-low`

**Changes:**
- Add testset calling `LibFEM._assemble!(K, k, i, j, ndofs)` with various ndofs values
- Verify DOF offsets and bounds checking

---

### T14: Convergence/refinement tests

**Files:** `test/convergence.jl` (new), `test/runtests.jl`  
**Effort:** 2-3h  
**Category:** `unspecified-high`

**Changes:**
- New file with h-refinement tests for `d1_truss` uniform bar and `d2_beam` cantilever
- Solve with 2^n elements, compute L2 error, verify convergence rate O(h²) or O(h⁴)

---

### T15: Multi-element stress recovery tests

**Files:** `test/runtests.jl`  
**Effort:** 1-2h  
**Category:** `unspecified-high`

**Changes:**
- Add test building 3-element `d1_truss` model
- Verify stress continuity at shared nodes

---

## Verification Gates

| Gate | Command | Expected |
|------|---------|----------|
| G1 — Module load | `julia --project=. -e 'using LibFEM'` | No errors |
| G2 — Full test suite | `julia --project=. test/runtests.jl` | 0 failures |
| G3 — Benchmarks | `julia --project=. test/benchmark.jl` | All complete |
| G4 — apply_bc! smoke | `julia --project=. -e 'using LibFEM; K=zeros(3,3); F=zeros(3); apply_bc!(K,F,[1=>0.0,3=>0.0])'` | Runs without error |
| G5 — Zero-length planeframe | `julia --project=. -e 'using LibFEM; d2_planeframe_elementlength(1,2,1,2)'` | Throws `ElementParameterError` |

---

## Future (Tiers 4-5 — No Action Now)

### Tier 4 — Medium-Term (v2.0)
| Item | Est. Time |
|------|-----------|
| M1: Trait-based type hierarchy (`ndofs`, `element_family`) | 2-3 days |
| M2: `eltype` propagation through element functions | 1-2 days |
| M3: StaticArrays for fixed-size matrices | 3-4 days |

### Tier 5 — Visionary (Educational)
| Item | Est. Time |
|------|-----------|
| V1: Pluto FEM Lab notebook (01_springs.jl) | 1-2 days |
| V2: Visual assembly explorer (color-coded DOF overlay) | 2-3 days |
| V3: Educational error mode (`verbose=true` explaining failures) | 2-3 days |

---

*Generated by Atlas (OhMyOpenAGent) via adversarial hyperplan with 4 critics (Pragmatist, Thorough Inspector, Architect, Visionary) and verified against actual file contents by Plan agent. Session: ses_086364771ffen7gkeyoySYwh2e.*
