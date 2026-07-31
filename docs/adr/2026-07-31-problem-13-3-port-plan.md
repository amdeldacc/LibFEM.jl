# ADR 2026-07-31 — Port Kattan Problem 13.3 (Q4 + Springs) to LibFEM

## Status

Accepted

## Context

Kattan's "MATLAB Guide to Finite Elements" (2nd ed., Springer 2007), Problem 13.3
(Fig 13.11): a 0.7 m × 0.4 m thin plate (E = 200 GPa, ν = 0.3, h = 0.01 m,
plane stress) discretized with 2 bilinear quadrilateral (Q4) elements whose
bottom edge rests on 3 vertical springs (k = 4000 kN/m each) anchored to fixed
ground. Upward loads of 8.75 / 17.5 / 8.75 kN are applied at the three top
nodes. The reference solution uses 15 DOFs: 6 plate nodes × 2 DOF (1-12) plus
3 spring ground DOFs (13-15).

This ADR records the port of that problem to LibFEM, following the same
workflow used for Problems 13.1 and 13.2 (`.m` golden capture in Octave,
runnable Julia example, integration test, ADR, PR).

## Decision

1. **New files**
   - `Doc/Kattan/Solutions-Manual/problem_13_3.m` — exact mirror of the
     solutions-manual MATLAB commands (requires `pkg load symbolic` and the
     `../M-Files` directory on the path; uses `format long g` for full
     precision golden capture).
   - `examples/kattan/problem_13_3.jl` — runnable LibFEM example with ASCII
     schema header, golden assertions, equilibrium check.
   - `docs/adr/2026-07-31-problem-13-3-port-plan.md` — this document.

2. **Test integration** — `problem_13_3_integration` testset added inside the
   `d2_q4` testset in `test/runtests.jl`, right after
   `problem_13_2_integration`.

3. **API mapping** (Julia ↔ MATLAB):
   - `BilinearQuadElementStiffness` → `d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)`
   - `BilinearQuadAssemble` → `d2_q4_assemble(K, k, i, j, m, n)`
   - `BilinearQuadElementStresses` → `d2_q4_elementstress(E, NU, x1..y4, p, u)`
   - `SpringElementStiffness(4000)` → `d1_spring_elementstiffness(4000)`
   - `SpringAssemble(K, k, i, j)` → `d1_spring_assemble(K, k, i, j)` — the
     MATLAB function operates directly on DOF indices and `d1_spring_assemble`
     uses 1 DOF/node, so passing the spring DOF pair (e.g. `8, 13`) reproduces
     MATLAB behaviour exactly.
   - `SpringElementForces(k, u)` → `d1_spring_elementforce(k, u)`

4. **Model**
   - Node map: N1(0.0,0.4), N2(0.35,0.4), N3(0.7,0.4), N4(0.0,0.0),
     N5(0.35,0.0), N6(0.7,0.0).
   - Element 1 = nodes (4,5,2,1), Element 2 = nodes (5,6,3,2).
   - Springs: DOF 8 ↔ 13 (node 4 → ground), DOF 10 ↔ 14 (node 5 → ground),
     DOF 12 ↔ 15 (node 6 → ground).
   - Free DOFs 1:12, constrained DOFs 13-15. Loads f = [0; 8.75; 0; 17.5; 0; 8.75; 0; 0; 0; 0; 0; 0].
   - u = k\f, U = [u; 0; 0; 0], F = K·U (near-zero entries zeroed with
     `F[abs.(F) .< 1e-10] .= 0.0`).

5. **Singularity handling (unique vs non-unique quantities)** — the plate is
   supported only by vertical springs, so the reduced 12×12 stiffness has a
   zero-energy rigid x-translation mode. Absolute `ux` values therefore depend
   on the solver (Octave backslash and Julia `\` return different particular
   solutions, differing by a constant shift ~2.36e-3 m). The golden assertions
   check only physically unique quantities:
   - `uy` (≈ 2.91e-3 … 2.93e-3 m, near-uniform field),
   - relative `ux` differences between nodes,
   - spring-ground reactions F(13:15) ≈ [-11.6553; -11.6894; -11.6553] kN,
   - element stresses σyy ≈ 5000 kPa, τxy ≈ ±726.3 kPa, σxx ≈ 0,
   - spring element forces ≈ ±11.655 / ±11.689 / ±11.655 kN.

## Consequences

- Golden values were captured from an Octave run of
  `problem_13_3.m` (full precision via `format long g`; symbolic `w = (sym ...)`
  noise blocks in the output are expected from `BilinearQuadElementStresses`
  and are ignored).
- The example demonstrates the Q4 element in combination with spring elements
  (`d1_spring_*`), exercising mixed-element assembly of a 15-DOF system.
- Assertions use `rtol=1e-2` for uy/reactions/stresses/spring forces, `atol=1e-9`
  for relative ux, and `abs(x) < 1e-2` for σxx (which should be exactly 0;
  Octave's ~-0.03 kPa is solver noise from the singular system).
