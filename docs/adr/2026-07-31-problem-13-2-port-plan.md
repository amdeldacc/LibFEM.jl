# Porting Plan — Kattan Problem 13.2 (Bilinear Quadrilateral Element / Q4 — Thin Plate with Central Hole)

**Date:** 2026-07-31
**Method:** Direct replication of the verified 2026-08-01 Problem 13.1 port workflow (same element family, same 4-step port + git delivery)
**Constraint (user, verbatim):** "same for 13.2. Create a branch & Commit and push & pr" — full 4-step port + git delivery, exactly as 13.1.

---

## Objective

Port Kattan Problem 13.2 (Bilinear Quadrilateral Element / Q4, thin plate with a central hole) following the repo's established direct-call convention, in the same 4 steps as the 13.1 port:

1. Extract the reference MATLAB script → `Doc/Kattan/Solutions-Manual/problem_13_2.m`
2. Create the Julia equivalent → `examples/kattan/problem_13_2.jl`
3. Create regression golden tests → one `@testset "problem_13_2_integration"` in `test/runtests.jl`
4. Run the tests and verify everything works → full suite green, exit 0

Then git delivery: branch `feat/problem-13-2`, commit, push, PR (user pre-approved).

**Zero changes** to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`. This is a problem port, not an element build.

---

## Verified Facts

### Source material
- Manual: `Doc/Kattan/Solutions-Manual/SolutionstoProblems.rtf` (1.2M). Problem 13.2 section located via pandoc-converted plain text (`/tmp/opencode/kattan_solutions.txt`): lines 16337–20508 (13.3 starts at 20509).
- M-Files available (unchanged from 13.1): `BilinearQuadElementStiffness.m`, `BilinearQuadAssemble.m`, `BilinearQuadElementStresses.m`, `BilinearQuadElementPStresses.m`, `BilinearQuadElementArea.m` in `Doc/Kattan/M-Files/`.
- **Both `BilinearQuadElementStiffness.m` (line 15 `syms s t;`, line 39 `int(int(BD, t, -1, 1), s, -1, 1)`) and `BilinearQuadElementStresses.m` (line 13 `syms s t;`, `subs(w, {s,t}, {0,0})` at centroid) use symbolic math** → Octave symbolic package (`pkg load symbolic`) required. Octave env: `ENV["PYTHON"]="/home/piou/miniconda3/bin/python3"`. Octave 8.4.0 at `/usr/bin/octave`.
- House `.m` template: `Doc/Kattan/Solutions-Manual/problem_13_1.m` (76 lines) — exact structural analog.

### Problem data (13.2)
- Units: kN, m. E=70e6 kPa, NU=0.25, h=0.02 m thickness, Plane Stress (p=1).
- 0.9 × 0.9 plate, 16 nodes, 8 Q4 elements (3×3 grid of 0.3 × 0.3 squares with the CENTER element removed — the hole between nodes 6,7,11,10).
- Node coords (bottom-up rows, 4/row): Row1 (y=0): 1=(0,0), 2=(0.3,0), 3=(0.6,0), 4=(0.9,0); Row2 (y=0.3): 5=(0,0.3), 6=(0.3,0.3), 7=(0.6,0.3), 8=(0.9,0.3); Row3 (y=0.6): 9=(0,0.6), 10=(0.3,0.6), 11=(0.6,0.6), 12=(0.9,0.6); Row4 (y=0.9): 13=(0,0.9), 14=(0.3,0.9), 15=(0.6,0.9), 16=(0.9,0.9).
- Elements (CCW, bottom-left first): e1:(1,2,6,5), e2:(2,3,7,6), e3:(3,4,8,7), e4:(5,6,10,9), e5:(7,8,12,11), e6:(9,10,14,13), e7:(10,11,15,14), e8:(11,12,16,15). Hole between 6,7,11,10.
- BCs: left edge (x=0) fixed — nodes 1, 5, 9, 13 → DOFs 1:2, 9:10, 17:18, 25:26 = 0.
- Load: single downward point load Fy = −20 kN at node 16 (0.9, 0.9) top-right corner → DOF 32 (the 24th free DOF). Reduced f position 24: `f=[zeros(22,1);0;-20]`.
- DOF order per node: [Ux, Uy]. Reduced k is 24×24.
- **Reduced K is BLOCK-ordered, NOT contiguous:** `k = [K(3:8,3:8) K(3:8,11:16) K(3:8,19:24) K(3:8,27:32); K(11:16,3:8) K(11:16,11:16) K(11:16,19:24) K(11:16,27:32); K(19:24,3:8) K(19:24,11:16) K(19:24,19:24) K(19:24,27:32); K(27:32,3:8) K(27:32,11:16) K(27:32,19:24) K(27:32,27:32)]` — free DOFs `[3:8; 11:16; 19:24; 27:32]`, same trap as 13.1.
- U expansion: `U=[0;0;u(1:6);0;0;u(7:12);0;0;u(13:18);0;0;u(19:24)]` (32×1).
- Assembly calls: `BilinearQuadAssemble(K,k1,1,2,6,5)`, `(K,k2,2,3,7,6)`, `(K,k3,3,4,8,7)`, `(K,k4,5,6,10,9)`, `(K,k5,7,8,12,11)`, `(K,k6,9,10,14,13)`, `(K,k7,10,11,15,14)`, `(K,k8,11,12,16,15)`.
- Local u vectors (8 entries, element node order): u1=[U1;U2;U3;U4;U11;U12;U9;U10]; u2=[U3;U4;U5;U6;U13;U14;U11;U12]; u3=[U5;U6;U7;U8;U15;U16;U13;U14]; u4=[U9;U10;U11;U12;U19;U20;U17;U18]; u5=[U13;U14;U15;U16;U23;U24;U21;U22]; u6=[U17;U18;U19;U20;U27;U28;U25;U26]; u7=[U19;U20;U21;U22;U29;U30;U27;U28]; u8=[U21;U22;U23;U24;U31;U32;U29;U30].
- Header schema: user-supplied verbatim Fig 13.9 (PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE WITH A HOLE (Fig 13.9); 8 quadrilaterals, hole between 6,7,11,10; Fixed Wall x=0 nodes 1,5,9,13 (Encastrement); Loaded Node 16 (0.9,0.9) Fy=-20 kN; e1(1,2,6,5) e2(2,3,7,6) e3(3,4,8,7) e4(5,6,10,9) [HOLE] e5(7,8,12,11) e6(9,10,14,13) e7(10,11,15,14) e8(11,12,16,15)).

### Julia API (already implemented + unit-tested at `@testset "d2_q4"` ~line 1458)
- `d2_q4_elementarea(x1,y1,…,x4,y4)` → area. `src/quadrilateral.jl:43`
- `d2_q4_elementstiffness(E, NU, h, x1,y1,…,x4,y4, p)` → 8×8. **HAS `h`.** `:71`
- `d2_q4_elementstress(E, NU, x1,y1,…,x4,y4, p, u)` → 3×1 [σxx; σyy; τxy] at centroid. **NO `h`.** `:146`
- `d2_q4_elementpstress(sigma)` → principal stresses. `:200`
- `d2_q4_assemble(K, k, i, j, m, n)` — 4 node indices (CCW). `:226`
- Exported from `src/LibFEM.jl` (d2_q4_* family).

### Manual numeric outputs (CROSS-CHECK only — golden values from live Octave run)
- **u** (×1e-3, m): `[-0.0299, -0.0284, -0.0402, -0.0753, -0.0386, -0.1102, 0.0015, -0.0203, -0.0068, -0.0800, -0.0123, -0.1088, -0.0021, -0.0185, -0.0023, -0.0824, 0.0047, -0.1224, 0.0307, -0.0260, 0.0489, -0.0758, 0.0565, -0.1589]`. Max displacement Uy16 = −1.5895e-4 (top-right corner, loaded).
- **F** (kN, 32×1): F1=17.6570, F2=3.4450, F9=7.4806, F10=7.0314, F17=-7.9321, F18=6.7416, F25=-17.2054, F26=2.7819, F32=-20.0000, rest 0. Equilibrium: ΣFx = 17.6570+7.4806-7.9321-17.2054 ≈ 0 ✓; ΣFy = 3.4450+7.0314+6.7416+2.7819 ≈ 20 ✓.
- **σ** (Pa): σ1=[-3288.97; 116.86; -806.08], σ2=[-2209.08; -158.45; -1949.31], σ3=[-592.06; -532.59; -187.44], σ4=[-27.362; 203.241; -1980.510], σ5=[-308.67; -1949.31; -2209.09], σ6=[3316.329; -48.438; -546.742], σ7=[2209.08; 446.45; -1384.02], σ8=[900.72; -3267.68; -936.81].
- **s (principal)** — assert σ only (13.1 precedent; principal-angle convention differs, manual rounds to 1 decimal).

---

## Plan Steps

### Step 1 — Extract `Doc/Kattan/Solutions-Manual/problem_13_2.m`
- Transcribe the Problem 13.2 section into house style mirroring `problem_13_1.m`: header comment (title, units, material, mesh with hole, BCs, DOF order, symbolic note) + bootstrap (`addpath(fullfile(fileparts(mfilename('fullpath')),'..','M-Files')); pkg load symbolic; warning('off','all');`) + 8× `BilinearQuadElementStiffness(E,NU,h,…coords…,1)`, 32×32 K, 8× `BilinearQuadAssemble`, block-ordered 24×24 reduction, f (position 24), solve, expand U, F=K*U, 8 local u vectors, 8× `BilinearQuadElementStresses` (NO h), 8× `BilinearQuadElementPStresses`.
- `Doc/Kattan/M-Files/*.m`, the `.rtf`/`.doc`, `.github/workflows/`, `Manifest.toml`, `test/golden/*` remain untouched.

### Step 2 — Run `problem_13_2.m` live in Octave → golden values
- `cd Doc/Kattan/Solutions-Manual && ENV["PYTHON"]=/home/piou/miniconda3/bin/python3 octave --no-gui problem_13_2.m > /tmp/opencode/problem_13_2_octave_out.txt` — generous timeout (symbolic int() is slow; ~3 min).
- Capture u (24), F (32), sigma1–8 (24 values). These become the golden asserts. RTF values are the cross-check.
- Octave is NOT wired into CI — golden values are transcribed once into the example + testset.

### Step 3 — Create `examples/kattan/problem_13_2.jl`
- Model on `examples/kattan/problem_13_1.jl`: banner + Fig 13.9 ASCII mesh diagram (3×3 Q4 grid with hole, 16 nodes) + node/load/BC tables + direct calls:
  - 8× `d2_q4_elementstiffness(E, NU, h, …4 coords…, p)`
  - `K = zeros(32, 32)`; 8× `d2_q4_assemble(K, k, …4 node indices…)`
  - Reduce: `free = [3:8; 11:16; 19:24; 27:32]`; `k = K[free, free]` (24×24)
  - `f = zeros(24)`; `f[24] = -20.0`
  - `u = k \ f`; expand `U`; `F = K * U` with `F[abs.(F) .< 1e-10] .= 0.0` cleanup
  - 8 per-element local u vectors (8 entries each) → 8× `d2_q4_elementstress(E, NU, …coords…, p, uN)`
  - Equilibrium check; golden `@assert isapprox(...; rtol=1e-2 / atol=1e-10)` blocks + `println("All golden assertions passed ✓")`

### Step 4 — Regression golden tests
- One `@testset "problem_13_2_integration"` appended inside the `d2_q4` testset (right after `problem_13_1_integration`, ~line 1568), following the `problem_13_1_integration` shape with the 13.2 data: build K, reduce, solve, expand, F, per-element stresses, `@test … rtol=1e-2 / atol=1e-10` on u, F reactions, and all 24 σ components.

### Step 5 — Verify + git delivery
- Run: `julia --project=. examples/kattan/problem_13_2.jl` → all golden asserts pass, exit 0.
- Run: `julia --project=. test/runtests.jl` → `problem_13_2_integration` + `d2_q4` + entire suite green, exit 0.
- Git (user pre-approved "Create a branch & Commit and push & pr"): `git checkout -b feat/problem-13-2` → stage → `CI=true GIT_APPROVED='<id>' git commit -m "feat(problem-13-2): …"` with `Approved-by: user` body line → `CI=true git push origin feat/problem-13-2` → `gh pr create --title "feat(problem-13-2): …" --base master`.

---

## Explicitly Forbidden (over-engineering traps — do NOT reintroduce)

1. ProblemWrapper / `PROBLEM_VARS` wiring for 13.2 in `lib/problem_wrapper.jl` — direct-call precedent (13.1) exists.
2. Any change to `scripts/validate-matlab.jl` or its problems gate.
3. Any change to `src/` or `d2_q4_*` API (element exists and is unit-tested).
4. New dependencies (Symbolics, Octave harness, etc.).
5. `test/golden/` binary snapshots or new golden harness files.
6. `.github/workflows/` changes.
7. New runner/harness scripts for 13.2.
8. README/OpenWiki/doc updates beyond the ADR itself (out of scope).

---

## Risks & Traps

- **Arg lists:** `d2_q4_elementstiffness` HAS `h` (12 args); `d2_q4_elementstress` does NOT (11 args + u). Wrong arity fails loudly — get them right.
- **Assembly node order:** `d2_q4_assemble` takes 4 node indices in CCW order (bottom-left first for this mesh); mistranscribing connectivity silently produces wrong K. e4 is (5,6,10,9) — note the hole shifts connectivity vs a full 3×3 grid.
- **Reduced vs full indexing:** reduction is BLOCK-ordered (3:8, 11:16, 19:24, 27:32), NOT `K[3:end,3:end]` — the top silent-failure risk. Load at reduced position 24 (DOF 32).
- **Stress vs principal stress:** assert σ only; s1-s8 not reliably readable in the manual (principal-angle convention uses single-arg atan).
- **Golden regeneration:** golden values come from a live Octave run of `problem_13_2.m` (slow — generous timeout). RTF listing is the cross-check only.
- **AGENTS.md read-only list:** `.m` extraction target is the Solutions-Manual folder (established convention); M-Files, `.rtf`/`.doc`, workflows, Manifest, `test/golden/*` remain read-only.

---

## Done Criteria

- [ ] `Doc/Kattan/Solutions-Manual/problem_13_2.m` created, house style, numeric calls (syms only inside the Kattan M-Files)
- [ ] Octave live run captured golden u/F/σ
- [ ] `examples/kattan/problem_13_2.jl` created, direct-call, golden asserts, prints ✓
- [ ] `@testset "problem_13_2_integration"` added to `test/runtests.jl` inside `d2_q4`, passes
- [ ] `julia --project=. test/runtests.jl` → entire suite green, exit 0
- [ ] No changes to `src/`, `lib/`, `scripts/`, `.github/`, `Project.toml`, `Manifest.toml`, `test/golden/`
- [ ] `feat/problem-13-2` branch created, committed, pushed, PR opened
