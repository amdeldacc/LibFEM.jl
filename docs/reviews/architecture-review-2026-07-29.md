# Architecture Review — LibFEM.jl

**Date:** 2026-07-29

Legend: module | seam (dashed) | leakage (red) | deep module

---

## Candidate 1: Remove the type hierarchy scaffolding

**Strength:** Strong
**Files:** `src/types.jl` — 293 lines

**Before:** 7 abstract types → 6 concrete structs → 7 type aliases → 7 show methods → Not used by any element function.

**After:** Deleted. The deletion test passes — removing types.jl concentrates no complexity.

**Problem:** 293 lines of abstract types, concrete structs, type aliases, and show methods that are never dispatched on. CONTEXT.md says: "documentation-only scaffolding."

**Solution:** Delete types.jl, remove its include/export lines. Functions don't use it — nothing breaks.

**Wins:**
- locality: no dead code to navigate around
- interface: shrinks by 7 export lines, 7 types

---

## Candidate 2: Move `_kprime` functions to their element files

**Strength:** Strong
**Files:** `src/assembly.jl` — `_d2_planeframe_kprime`, `_d3_spaceframe_kprime`

**Before:** assembly.jl contains _assemble!, _assemble_n!, AND _d2_planeframe_kprime + _d3_spaceframe_kprime (leaking). Grid's `_d2_grid_kprime` is correctly in grid.jl — inconsistency.

**After:** assembly.jl has only assembly concerns. planeframe.jl and spaceframe.jl each have their own _kprime.

**Problem:** Locality is broken. Understanding plane frame stiffness requires bouncing between planeframe.jl and assembly.jl.

**Solution:** Move `_d2_planeframe_kprime` into planeframe.jl and `_d3_spaceframe_kprime` into spaceframe.jl.

**Wins:**
- locality: element + its internal helpers in one file
- interface: unchanged — both are private

---

## Candidate 3: Domain-split `utils.jl`

**Strength:** Worth exploring
**Files:** `src/utils.jl` — 179 lines, 6 functions, 3 domains

**Before:** utils.jl is a grab bag: _direction_cosines (truss/spring), _truss_force_component (truss), validate_positive (all), _principal_stresses + _d3_elasticity_matrix + _d3_principal_stresses (continuum). Three unrelated concerns.

**After:** utils.jl has validate_positive only. Direction cosines embedded in spring/truss files. Continuum helpers in a shared _continuum.jl.

**Problem:** utils.jl mixes three unrelated domains. Understanding continuum elements means reading past direction cosine logic.

**Solution:** Keep only validate_positive in utils.jl. Extract direction cosines to spring.jl/truss.jl. Extract continuum helpers to a shared _continuum.jl.

**Wins:**
- locality: continuum element authors read only continuum helpers
- seam: each domain can evolve independently
- caveat: 6 functions across 3 groups — extraction is small

---

## Candidate 4: Move `d2_planeframe_elementlength` to planeframe.jl

**Strength:** Worth exploring
**Files:** `src/beam.jl` (line 99) → `src/planeframe.jl`

**Before:** beam.jl contains d2_beam_elementstiffness, d2_beam_elementforces, AND d2_planeframe_elementlength (leftover from Wave 1 delegation). planeframe.jl is missing its length function.

**After:** beam.jl has only beam concerns. planeframe.jl has all planeframe functions including elementlength.

**Problem:** Wave 1 leftover. `d2_planeframe_elementlength` delegates to `d2_truss_elementlength` but lives in beam.jl.

**Solution:** Move the function from beam.jl to planeframe.jl. 2-minute move.

**Wins:**
- locality: all planeframe functions in one file
- interface: unchanged — exported function
- effort: 2 minutes

---

## Candidate 5: Deepen `solver.jl`

**Strength:** Speculative
**Files:** `src/solver.jl` — 46 lines, 1 function

**Before:** solver.jl is perfectly shallow — 46 lines, one function (apply_bc!). The module IS the interface.

**After (if expanded):** solve(K, F, constraints) wraps apply_bc! + K\F in one call. Plus reactions(), multi_load_solve().

**Problem:** solver.jl is perfectly shallow — module boundary barely wider than the function signature. CONTEXT.md says "Thin Solver Helpers Planned."

**Solution:** Wait for planned expansion. If no more functions land, merge back into utils.jl.

**Wins:**
- leverage: a solve() wrapper replaces the most common 3-line user pattern
- deletion test: deleting solver.jl and inlining apply_bc! into utils.jl concentrates zero complexity
- ADR conflict: CONTEXT.md explicitly plans more solver helpers — wait on this

---

## Top Recommendation

**Remove the type hierarchy scaffolding** — It's the highest effort-to-leverage ratio. 293 lines of dead code that every new reader must decode. The deletion test passes cleanly. It's the first file included in the module — deleting it sends the clearest signal about what this library actually does.
