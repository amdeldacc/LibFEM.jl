# Porting Plan — Kattan Problem 13.1 (Bilinear Quadrilateral Element / Q4)

**Date:** 2026-08-01
**Method:** Direct replication of the verified 2026-07-31 Problem 12.1 port workflow (same plate geometry pattern, same element chapter progression)
**Constraint (user, verbatim):** "do the same for pb 13.1. Create a feat branch, commit & push & pr" — full 4-step port + git delivery, exactly as 12.1.

---

## Objective

Port Kattan Problem 13.1 (Bilinear Quadrilateral Element / Q4) following the repo's established direct-call convention, in the same 4 steps as the 12.1 port:

1. Extract the reference MATLAB script → `Doc/Kattan/Solutions-Manual/problem_13_1.m`
2. Create the Julia equivalent → `examples/kattan/problem_13_1.jl`
3. Create regression golden tests → one `@testset "problem_13_1_integration"` in `test/runtests.jl`
4. Run the tests and verify everything works → full suite green, exit 0

Then git delivery: branch `feat/problem-13-1`, commit, push, PR (user pre-approved).

**Zero changes** to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`. This is a problem port, not an element build.

---

## Verified Facts

### Source material
- Manual: `Doc/Kattan/Solutions-Manual/SolutionstoProblems.rtf` (1.2M). Problem 13.1 section located via pandoc-converted plain text (`/tmp/opencode/p13_solutions.txt`, 26015 lines): section lines 12341–16336 (13.2@16337, 13.3@20509); extracted to `/tmp/opencode/p131_sec.txt` (3996 lines).
- M-Files available: `BilinearQuadElementStiffness.m`, `BilinearQuadAssemble.m`, `BilinearQuadElementStresses.m`, `BilinearQuadElementPStresses.m`, `BilinearQuadElementArea.m` in `Doc/Kattan/M-Files/`.
- **Both `BilinearQuadElementStiffness.m` (line 15 `syms s t;`, line 39 `int(int(BD, t, -1, 1), s, -1, 1)`) and `BilinearQuadElementStresses.m` (line 13 `syms s t;`) use symbolic integration** → Octave symbolic package (`pkg load symbolic`) required, same as 12.1. Octave env: `ENV["PYTHON"]="/home/piou/miniconda3/bin/python3"`.
- House `.m` template: `Doc/Kattan/Solutions-Manual/problem_12_1.m` (55 lines, header comment + bootstrap + direct calls) — exact structural analog (same plate, same reduction pattern).

### Problem data (13.1)
- Units: kN, m. E=210e6 kPa, NU=0.3, h=0.025 m thickness, Plane Stress (p=1).
- 0.5 × 0.25 plate, 15 nodes, 8 Q4 elements (4 cols × 2 rows of 0.125 × 0.125 squares).
- Node coords: y=0 row: 1=(0,0), 2=(0.125,0), 3=(0.25,0), 4=(0.375,0), 5=(0.5,0); y=0.125 row: 6=(0,0.125), 7=(0.125,0.125), 8=(0.25,0.125), 9=(0.375,0.125), 10=(0.5,0.125); y=0.25 row: 11=(0,0.25), 12=(0.125,0.25), 13=(0.25,0.25), 14=(0.375,0.25), 15=(0.5,0.25).
- Elements (CCW, bottom-left first): e1:(1,2,7,6), e2:(2,3,8,7), e3:(3,4,9,8), e4:(4,5,10,9), e5:(6,7,12,11), e6:(7,8,13,12), e7:(8,9,14,13), e8:(9,10,15,14).
- BCs: left edge (x=0) fixed — nodes 1, 6, 11 → DOFs 1,2,11,12,21,22 = 0 (same pattern as 12.1).
- Loads (+x): 4.6875 kN @ node 5 (DOF 9), 9.375 kN @ node 10 (DOF 19), 4.6875 kN @ node 15 (DOF 29) — right edge x=0.5, uniform traction split 1:2:1. Reduced f positions: 7, 15, 23. Equilibrium: ΣFx = -4.9836 - 8.7829 - 4.9836 + 4.6875 + 9.375 + 4.6875 = 0 ✓; ΣFy = -1.2580 + 1.2580 = 0 ✓.
- DOF order per node: [Ux, Uy]. Reduced k is 24×24.
- **Reduced K is BLOCK-ordered, NOT contiguous:** `k = [K(3:10,3:10) K(3:10,13:20) K(3:10,23:30); K(13:20,3:10) K(13:20,13:20) K(13:20,23:30); K(23:30,3:10) K(23:30,13:20) K(23:30,23:30)]` — same trap as 12.1.
- U expansion: `U=[0;0;u(1:8);0;0;u(9:16);0;0;u(17:24)]` (30×1).
- Assembly calls: `BilinearQuadAssemble(K,k1,1,2,7,6)`, `(K,k2,2,3,8,7)`, `(K,k3,3,4,9,8)`, `(K,k4,4,5,10,9)`, `(K,k5,6,7,12,11)`, `(K,k6,7,8,13,12)`, `(K,k7,8,9,14,13)`, `(K,k8,9,10,15,14)`.
- Local u vectors (8 entries, node order = element node order): u1=[U1;U2;U3;U4;U13;U14;U11;U12]; u2=[U3;U4;U5;U6;U15;U16;U13;U14]; u3=[U5;U6;U7;U8;U17;U18;U15;U16]; u4=[U7;U8;U9;U10;U19;U20;U17;U18]; u5=[U11;U12;U13;U14;U23;U24;U21;U22]; u6=[U13;U14;U15;U16;U25;U26;U23;U24]; u7=[U15;U16;U17;U18;U27;U28;U25;U26]; u8=[U17;U18;U19;U20;U29;U30;U27;U28].

### Julia API (already implemented + unit-tested at `@testset "d2_q4"` ~line 1458)
- `d2_q4_elementarea(x1,y1,…,x4,y4)` → area. `src/quadrilateral.jl:43`
- `d2_q4_elementstiffness(E, NU, h, x1,y1,…,x4,y4, p)` → 8×8. **HAS `h`.** `:71`
- `d2_q4_elementstress(E, NU, x1,y1,…,x4,y4, p, u)` → 3×1 [σxx; σyy; τxy] at centroid. **NO `h`.** `:146`
- `d2_q4_elementpstress(sigma)` → principal stresses. `:200`
- `d2_q4_assemble(K, k, i, j, m, n)` — 4 node indices (CCW). `:226`
- Exported from `src/LibFEM.jl` (d2_q4_* family).

### Manual numeric outputs (CROSS-CHECK only — golden values from live Octave run)
- **u** (×1e-5, m): `[0.1768, 0.0552, 0.3500, 0.0548, 0.5284, 0.0536, 0.7071, 0.0535, 0.1648, 0.0000, 0.3496, 0.0000, 0.5287, 0.0000, 0.7071, 0.0000, 0.1768, -0.0552, 0.3500, -0.0548, 0.5284, -0.0536, 0.7071, -0.0535]`. Symmetry zeros at u[10],u[12],u[14],u[16]; u[1:8] mirrors u[17:24] with Uy sign flip.
- **F** (kN, 30×1): F1=-4.9836, F2=-1.2580, F9=4.6875, F11=-8.7829, F19=9.3750, F21=-4.9836, F22=1.2580, F29=4.6875, rest 0.
- **σ** (kPa): σ1=[3000.0; 436.2; 139.6], σ2=[3000.0; -23.9; -41.4], σ3=[3000.0; -10.2; -4.2], σ4=[3000.0; 0.5; 0.8], σ5=[3000.0; 436.2; -139.6], σ6=[3000.0; -23.9; 41.4], σ7=[3000.0; -10.2; 4.2], σ8=[3000.0; 0.5; -0.8]. σxx=3000 kPa uniform (uniaxial tension state); σ5–σ8 mirror σ1–σ4 with τxy sign flip; σ4/σ8 tiny σyy/τxy.
- **s (principal)** — assert σ only (12.1 precedent; s values not fully readable in manual).

---

## Plan Steps

### Step 1 — Extract `Doc/Kattan/Solutions-Manual/problem_13_1.m`
- Transcribe the Problem 13.1 section from `p131_sec.txt` into house style mirroring `problem_12_1.m`: header comment (title, units, material, mesh, BCs, DOF order, symbolic note) + bootstrap (`addpath(fullfile(fileparts(mfilename('fullpath')),'..','M-Files')); pkg load symbolic; warning('off','all');`) + 8× `BilinearQuadElementStiffness(E,NU,h,…coords…,1)`, 30×30 K, 8× `BilinearQuadAssemble`, block-ordered 24×24 reduction, f (positions 7,15,23), solve, expand U, F=K*U, 8 local u vectors, 8× `BilinearQuadElementStresses` (NO h), 8× `BilinearQuadElementPStresses`.
- `Doc/Kattan/M-Files/*.m`, the `.rtf`/`.doc`, `.github/workflows/`, `Manifest.toml`, `test/golden/*` remain untouched.

### Step 2 — Run `problem_13_1.m` live in Octave → golden values
- `cd Doc/Kattan/Solutions-Manual && ENV["PYTHON"]=/home/piou/miniconda3/bin/python3 octave --no-gui problem_13_1.m > /tmp/opencode/problem_13_1_octave_out.txt` — generous timeout (symbolic int() is slow; 12.1 took ~2m45s).
- Capture u (24), F (30), sigma1–8 (24 values). These become the golden asserts. RTF values are the cross-check.
- Octave is NOT wired into CI — golden values are transcribed once into the example + testset.

### Step 3 — Create `examples/kattan/problem_13_1.jl`
- Model on `examples/kattan/problem_12_1.jl`: banner + ASCII mesh diagram (4×2 Q4 grid, 15 nodes) + node/load/BC tables + direct calls:
  - 8× `d2_q4_elementstiffness(E, NU, h, …4 coords…, p)`
  - `K = zeros(30, 30)`; 8× `d2_q4_assemble(K, k, …4 node indices…)`
  - Reduce: `free = [3:10; 13:20; 23:30]`; `k = K[free, free]` (24×24)
  - `f = zeros(24)`; f[7]=4.6875; f[15]=9.375; f[23]=4.6875
  - `u = k \ f`; expand `U`; `F = K * U` with `F[abs.(F) .< 1e-10] .= 0.0` cleanup
  - 8 per-element local u vectors (8 entries each) → 8× `d2_q4_elementstress(E, NU, …coords…, p, uN)`
  - Equilibrium check; golden `@assert isapprox(...; rtol=1e-2 / atol=1e-10)` blocks + `println("All golden assertions passed ✓")`

### Step 4 — Regression golden tests
- One `@testset "problem_13_1_integration"` appended inside the `d2_q4` testset (~line 1458, after the unit testsets, before the testset's closing `end` — same nesting as `problem_12_1_integration` in `d2_lst`), following the `problem_11_1_integration` shape with the 13.1 data: build K, reduce, solve, expand, F, per-element stresses, `@test … rtol=1e-2 / atol=1e-10` on u, F reactions, and all 24 σ components.

### Step 5 — Verify + git delivery
- Run: `julia --project=. examples/kattan/problem_13_1.jl` → all golden asserts pass, exit 0.
- Run: `julia --project=. test/runtests.jl` → `problem_13_1_integration` + `d2_q4` + entire suite green, exit 0.
- Git (user pre-approved "Create a feat branch, commit & push & pr"): `git checkout -b feat/problem-13-1` → stage → `CI=true GIT_APPROVED='<id>' git commit -m "feat(problem-13-1): …"` with `Approved-by: user` body line → `CI=true git push origin feat/problem-13-1` → `gh pr create --title "feat(problem-13-1): …" --base master`.

---

## Explicitly Forbidden (over-engineering traps — do NOT reintroduce)

1. ProblemWrapper / `PROBLEM_VARS` wiring for 13.1 in `lib/problem_wrapper.jl` — direct-call precedent (12.1) exists.
2. Any change to `scripts/validate-matlab.jl` or its problems gate.
3. Any change to `src/` or `d2_q4_*` API (element exists and is unit-tested).
4. New dependencies (Symbolics, Octave harness, etc.).
5. `test/golden/` binary snapshots or new golden harness files.
6. `.github/workflows/` changes.
7. New runner/harness scripts for 13.1.
8. README/OpenWiki/doc updates beyond the ADR itself (out of scope).

---

## Risks & Traps

- **Arg lists:** `d2_q4_elementstiffness` HAS `h` (12 args); `d2_q4_elementstress` does NOT (11 args + u). Wrong arity fails loudly — get them right.
- **Assembly node order:** `d2_q4_assemble` takes 4 node indices in CCW order (bottom-left first for this mesh); mistranscribing connectivity silently produces wrong K.
- **Reduced vs full indexing:** reduction is BLOCK-ordered (3:10, 13:20, 23:30), NOT `K[3:end,3:end]` — the top silent-failure risk. Loads at reduced positions 7, 15, 23.
- **Stress vs principal stress:** assert σ only; s1-s8 not reliably readable in the manual.
- **Golden regeneration:** golden values come from a live Octave run of `problem_13_1.m` (slow — generous timeout). RTF listing is the cross-check only.
- **AGENTS.md read-only list:** `.m` extraction target is the Solutions-Manual folder (established 11-file convention); M-Files, `.rtf`/`.doc`, workflows, Manifest, `test/golden/*` remain read-only.

---

## Done Criteria

- [ ] `Doc/Kattan/Solutions-Manual/problem_13_1.m` created, house style, numeric calls (syms only inside the Kattan M-Files)
- [ ] Octave live run captured golden u/F/σ
- [ ] `examples/kattan/problem_13_1.jl` created, direct-call, golden asserts, prints ✓
- [ ] `@testset "problem_13_1_integration"` added to `test/runtests.jl` inside `d2_q4`, passes
- [ ] `julia --project=. test/runtests.jl` → entire suite green, exit 0
- [ ] No changes to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`
- [ ] `feat/problem-13-1` branch created, committed, pushed, PR opened
