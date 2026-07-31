# Porting Plan — Kattan Problem 12.1 (Quadratic Triangle Element / LST)

**Date:** 2026-07-31
**Method:** Adversarial hyperplan (skeptic-minimalist, thorough-executor, logic-architect, creative-disruptor) + lead verification against repo
**Constraint (user, verbatim):** "MAKE IT SIMPLE BUT NOT SIMPLER. DON'T OVER-ARCHITECTURING"

---

## Objective

Port Kattan Problem 12.1 (Quadratic Triangle Element / LST) following the repo's established direct-call convention, in 4 user-requested steps:

1. Extract the reference MATLAB script → `Doc/Kattan/Solutions-Manual/problem_12_1.m`
2. Create the Julia equivalent → `examples/kattan/problem_12_1.jl`
3. Create regression MATLAB validation / golden tests → one `@testset "problem_12_1_integration"` in `test/runtests.jl`
4. Run the tests and verify everything works → `julia --project=. test/runtests.jl` green

**Zero changes** to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`. This is a problem port, not an element build.

---

## Verified Facts

### Source material
- Manual: `Doc/Kattan/Solutions-Manual/SolutionstoProblems.rtf` (1.2M) — confirmed to contain the full Problem 12.1 code (`QuadTriangleElementStiffness` calls at ~lines 7415–7488, `QuadTriangleElementStresses` at ~8418+). Also `.doc` (1.4M).
- M-Files available: `QuadTriangleElementStiffness.m`, `QuadTriangleAssemble.m`, `QuadTriangleElementStresses.m`, `QuadTriangleElementPStresses.m`, `QuadTriangleElementArea.m` in `Doc/Kattan/M-Files/`.
- **NOTE:** `/tmp/opencode/p121_expected.txt` and `p121_wrap_test.m` DO NOT EXIST (verified). Any golden numbers must be regenerated from a one-off Octave run of the extracted `.m` (not wired into anything).
- House `.m` template: `Doc/Kattan/Solutions-Manual/problem_11_3.m` (header comment with problem statement + units/BCs, then direct Kattan function calls). 10 extractions exist (`problem_2_1.m` … `problem_11_3.m`); none contains `syms` (numeric only).

### Problem data (12.1)
- Units: kN, m. E=210e6 kPa, NU=0.3, t=0.025 m, Plane Stress (p=1).
- 0.5 × 0.25 plate, 13 nodes, 4 LST elements meeting at center node 7 = (0.25, 0.125).
- Node coordinates: 1=(0,0), 2=(0.25,0), 3=(0.5,0), 4=(0.125,0.0625), 5=(0.375,0.0625), 6=(0,0.125), 7=(0.25,0.125), 8=(0.5,0.125), 9=(0.125,0.1875), 10=(0.375,0.1875), 11=(0,0.25), 12=(0.25,0.25), 13=(0.5,0.25).
- Elements (corners + mid-edge): e1: 1,7,11 / mids 4,9,6; e2: 1,3,7 / mids 2,5,4; e3: 7,13,11 / mids 10,12,9; e4: 7,3,13 / mids 5,8,10.
- BCs: left edge (x=0) fixed — nodes 1, 6, 11 → U(1)=U(2)=U(11)=U(12)=U(21)=U(22)=0.
- Loads (CORRECTED — right edge x=0.5, from manual F vector): +3.125 kN @ node 3 (full DOF 5), +12.5 kN @ node 8 (full DOF 15), +3.125 kN @ node 13 (full DOF 25). Reduced f positions: 3, 11, 19. Equilibrium: ΣFx = -3.4469 - 11.8562 - 3.4469 + 3.125 + 12.5 + 3.125 = 0 ✓. ΣFy = -1.5335 + 1.5335 = 0 ✓. (The briefing's "nodes 3,7,12" was wrong — positions 3,11,19 in the reduced vector were misread as node numbers.)
- DOF order per node: [Ux, Uy]. Reduced k is 20×20, well-posed, u unique (unlike 11.3).
- Assembly calls (manual-verified, corners-then-mids): `d2_lst_assemble(K, k1, 1, 7, 11, 4, 9, 6)`, `(K, k2, 1, 3, 7, 2, 5, 4)`, `(K, k3, 7, 13, 11, 10, 12, 9)`, `(K, k4, 7, 3, 13, 5, 8, 10)`.
- **Reduced K is BLOCK-ordered, NOT contiguous:** `k = [K(3:10,3:10) K(3:10,13:20) K(3:10,23:26); K(13:20,3:10) K(13:20,13:20) K(13:20,23:26); K(23:26,3:10) K(23:26,13:20) K(23:26,23:26)]`. `K[3:end,3:end]` would include constrained DOFs 11,12,21,22 → singular/wrong.
- u order follows the same block order: u(1:8)=nodes 2-5, u(9:16)=nodes 7-10, u(17:20)=nodes 12-13.
- Local u vectors are corners-first: `u1 = [U(1);U(2);U(13);U(14);U(21);U(22);U(7);U(8);U(17);U(18);U(11);U(12)]` = nodes [1,7,11,4,9,6].

### Golden values (VERIFIED — live Octave run of `problem_12_1.m`, 2026-07-31, ~2m45s; SymPy 1.14.0. RTF values below as cross-check only)
- **u (reduced, m, block order nodes 2-5, 7-10, 12-13)** — Octave: `[3.4997e-06, 5.9026e-07, 7.0058e-06, 4.1514e-07, 1.6528e-06, 1.7157e-07, 5.2857e-06, 2.8779e-07, 3.4535e-06, 3.6671e-21, 7.0799e-06, 7.7899e-21, 1.6528e-06, -1.7157e-07, 5.2857e-06, -2.8779e-07, 3.4997e-06, -5.9026e-07, 7.0058e-06, -4.1514e-07]`. Symmetry zeros u[10], u[12] ≈ 3.7e-21 → `atol=1e-10`.
- **F reactions** (kN): Fx₁=-3.4469, Fy₁=-1.5335, Fx₆=-11.8562, Fx₁₁=-3.4469, Fy₁₁=+1.5335. ΣFx=ΣFy=0 ✓.
- **σ (kPa, at centroid)**: σ1=[2970.2; 506.7; ~0], σ2=[3008.8; -21.3; 10.5], σ3=[3008.8; -21.3; -10.5], σ4=[3012.2; 26.5; ~0]. Principal s1-s4 match manual.
- RTF cross-check (×1e-5): `[0.3500, 0.0590, 0.7006, 0.0415, 0.1653, 0.0172, 0.5286, 0.0288, 0.3454, 0.0000, 0.7080, 0.0000, 0.1653, -0.0172, 0.5286, -0.0288, 0.3500, -0.0590, 0.7006, -0.0415]` — matches Octave to printed precision.
- **F reactions**: F1=-3.4469, F2=-1.5335, F11=-11.8562, F12=0, F21=-3.4469, F22=+1.5335; applied F5=3.125, F15=12.5, F25=3.125
- **σ** (kPa): sigma1=[2970.2; 506.7; 0.0], sigma2=[3008.8; -21.3; 10.5], sigma3=[3008.8; -21.3; -10.5], sigma4=[3012.2; 26.5; 0.0]. Assert ALL 12 components incl. τxy=±10.5 and zeros (e1/e4 σ=[...;0] coincidentally match principal stresses — swap would pass silently without the τxy checks).
- **NOT in manual**: principal stresses s1-s4 numeric outputs (statements only). Assert σ only — dragging in `s` imports the single-arg vs two-arg atan fragility for zero regression value.

### Julia API (already implemented + unit-tested at `@testset "d2_lst"` ~line 1355)
- `d2_lst_elementstiffness(E, NU, t, x1,y1,…,x6,y6, p)` → 12×12 (6 nodes: corners 1-2-3 CCW, mids 4(1-2), 5(2-3), 6(3-1); DOF [u1,v1,…,u6,v6]). `src/quadratictriangle.jl:90`
- `d2_lst_elementstress(E, NU, x1,y1,…,x6,y6, p, u)` → 3×1 [σxx; σyy; τxy] at centroid. **NO `t` argument.** `:181`
- `d2_lst_elementpstress(...)` → principal stresses. `:255`
- `d2_lst_assemble(K, k, i, j, k_, l, m, n, o)` — takes **6 node indices** (corner + mid-edge order). `:281`
- Exported from `src/LibFEM.jl:117`.

### House patterns (the precedents to copy — nothing new invented)
- **Test:** `@testset "problem_11_1_integration"` in `test/runtests.jl:1218` — direct-call style, no wrapper: 4× `d2_cst_elementstiffness` → assemble 10×10 K → reduce to free-DOF submatrix → `u = k \ f` → expand `U` → `F = K*U` with `F[abs.(F) .< 1e-10] .= 0.0` cleanup → per-element local `u` vectors → `d2_cst_elementstress` → `@test … rtol=1e-2` / `atol=1e-10`.
- **Example:** `examples/kattan/problem_11_1.jl` — header banner + ASCII diagram + node/load tables, direct calls, ends with `@assert isapprox(...; rtol=1e-2)` golden blocks + `println("All golden assertions passed ✓")`. 19 examples exist, none uses ProblemWrapper.

---

## Plan Steps

### Step 1 — Extract `Doc/Kattan/Solutions-Manual/problem_12_1.m`
- Transcribe the Problem 12.1 section from `SolutionstoProblems.rtf` into a house-style `.m` matching `problem_11_3.m` format: header comment (title, units, material, mesh, BCs, DOF order) + direct Kattan calls (k1–k4, assemble, reduce, solve, expand, F, local u vectors, stresses, principal stresses).
- Content source: the rtf lines cited above (numeric calls, no syms).
- Follows the existing 10-file extraction convention. `Doc/Kattan/M-Files/*.m`, the `.rtf`/`.doc`, `.github/workflows/`, `Manifest.toml`, `test/golden/*` remain untouched.
- Verification: file reads clean; calls match M-File signatures (stiffness with `t`, stresses without `t`).

### Step 2 — Create `examples/kattan/problem_12_1.jl`
- Model on `examples/kattan/problem_11_1.jl`: banner, mesh diagram (13-node quad-tri layout), node/load/BC tables, then direct calls:
  - 4× `d2_lst_elementstiffness(E, NU, t, …6 coords…, p)`
  - `K = zeros(26, 26)`; 4× `d2_lst_assemble(K, k, …6 node indices…)` — order: corners then mids (e.g. e1 → `(K, k1, 1, 7, 11, 4, 9, 6)`)
  - Reduce: `k = K[free, free]` where free = all DOFs except 1,2,11,12,21,22 → 20×20
  - `f` = 26-vector with 3.125 @ 6th DOF (node 3, Ux), 12.5 @ 14th (node 7, Ux), 3.125 @ 24th (node 12, Ux); then slice to free DOFs
  - `u = k \ f`; expand `U`; `F = K*U` with tiny-reaction cleanup
  - Per-element local `u` vectors (12 each), 4× `d2_lst_elementstress(E, NU, …coords…, p, u_local)`
  - Golden `@assert isapprox(...; rtol=1e-2)` blocks + final println
- Golden numbers come from Step 3's one-off Octave run (then hard-coded here).

### Step 3 — Regression MATLAB validation / golden tests
- One `@testset "problem_12_1_integration"` appended to `test/runtests.jl`, placed inside the `d2_lst` testset (~line 1355, after the unit testsets), byte-for-byte following the `problem_11_1_integration` shape with the 12.1 data.
- **Golden values are already extracted** (verified section above) directly from the manual's RTF listing — the book's own MATLAB output. NO Octave run needed; NO Octave harness; NO symbolic (`syms`) pipeline; NO new files in `test/golden/`.
- **Golden source = live Octave run:** user ran `octave problem_12_1.m` in `Doc/Kattan/Solutions-Manual/` successfully (Symbolic pkg v3.2.2, SymPy 1.14.0 link active) → `u = [3.4997e-06; 5.9026e-07; 7.0058e-06; 4.1514e-07; 1.6528e-06; 1.7157e-07; 5.2857e-06; …]`. These are MORE precise than the RTF-rounded 4-decimal values — the regression golden values come from this live run (one-off capture via `OctaveRunner.run_script(script; timeout)` in `test/octave_runner.jl`, generous `timeout` because symbolic `syms`/`int` computation is slow; keep RTF values as a cross-check only). Octave is NOT wired into CI — the golden values are transcribed into the testset once.
- Placement: inside the `d2_lst` testset after its unit testsets (house: `problem_11_1_integration` nests inside `d2_cst`).

### Step 4 — Make the test and check everything works
- Run: `julia --project=. examples/kattan/problem_12_1.jl` → all golden asserts pass, exit 0.
- Run: `julia --project=. test/runtests.jl` → `problem_12_1_integration` + `d2_lst` + entire suite green, exit 0.
- Run: `julia --project=. scripts/validate-matlab.jl all` only if desired (unchanged — 12.1 not added to its gate; it remains at HEAD).
- Report results; await explicit user approval before any git commit/branch/PR (per AGENTS.md).

---

## Explicitly Forbidden (over-engineering traps — do NOT reintroduce)

1. ProblemWrapper / `PROBLEM_VARS` wiring for 12.1 in `lib/problem_wrapper.jl` — cancelled by user; direct-call precedent exists.
2. Any change to `scripts/validate-matlab.jl` or its problems gate.
3. Octave `syms` / symbolic stiffness derivation; symbolic Python/SymPy env plumbing.
4. New dependencies (Symbolics, Octave harness, etc.) — needs approval, unneeded.
5. Any change to `src/` or `d2_lst_*` API (element exists and is unit-tested).
6. `test/golden/` binary snapshots or new golden harness files.
7. `.github/workflows/` changes.
8. New runner/harness scripts for 12.1.
9. README/OpenWiki/doc updates (out of scope for these 4 steps).

---

## Risks & Traps

- **Arg lists:** `d2_lst_elementstiffness` HAS `t` (17 args); `d2_lst_elementstress` does NOT (16 args). Wrong arity fails loudly — get them right.
- **Assembly node order:** `d2_lst_assemble` takes 6 node indices in corner-then-mid order; mistranscribing the connectivity silently produces wrong K.
- **Reduced vs full indexing:** the reduction is BLOCK-ordered (3:10, 13:20, 23:26), NOT `K[3:end,3:end]` — the top silent-failure risk. Loads in reduced f at positions 3, 11, 19.
- **Stress vs principal stress:** assert σ only; s1-s4 not printed in the manual. σxx-dominated states match the manual's single-arg atan without workaround.
- **Golden regeneration:** golden values come from a live Octave run of `problem_12_1.m` (user-verified working; slow — use generous timeout). RTF listing is the cross-check only.
- **AGENTS.md read-only list:** `.m` extraction target is the Solutions-Manual folder (established 10-file convention); M-Files, `.rtf`/`.doc`, workflows, Manifest, `test/golden/*` remain read-only.

---

## Done Criteria

- [x] `Doc/Kattan/Solutions-Manual/problem_12_1.m` created, house style, numeric (no syms)
- [x] `examples/kattan/problem_12_1.jl` created, direct-call, golden asserts, prints ✓
- [x] `@testset "problem_12_1_integration"` added to `test/runtests.jl` (11.1-style), passes
- [x] `julia --project=. test/runtests.jl` → entire suite green, exit 0
- [x] No changes to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`
- [x] Results shown; git operations only on explicit user approval
