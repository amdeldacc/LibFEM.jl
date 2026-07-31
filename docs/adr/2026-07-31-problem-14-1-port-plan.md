# ADR 2026-07-31 — Port Kattan Problem 14.1 (Q8 + Springs) to LibFEM

## Status

Accepted

## Context

Kattan's "MATLAB Guide to Finite Elements" (2nd ed., Springer 2007), Problem 14.1:
a 0.7 m × 0.4 m thin plate (E = 200 GPa, ν = 0.3, h = 0.01 m, plane stress)
discretized with a single quadratic quadrilateral (Q8) element whose bottom edge
rests on 3 vertical springs (k = 4000 kN/m each) anchored to fixed ground.
Upward loads of 5.8333 / 23.3333 / 5.8333 kN (the Q8 consistent nodal loads for
a uniform edge load, total 35 kN) are applied at the three top nodes. The
reference solution uses 19 DOFs: 8 plate nodes × 2 DOF (1-16) plus 3 spring
ground DOFs (17-19).

This ADR records the port of that problem to LibFEM, following the same
workflow used for Problems 13.1, 13.2 and 13.3 (`.m` golden capture in Octave,
runnable Julia example, integration test, ADR, PR).

## Decision

1. **New files**
   - `Doc/Kattan/Solutions-Manual/problem_14_1.m` — exact mirror of the
     solutions-manual MATLAB commands (requires `pkg load symbolic` and the
     `../M-Files` directory on the path; uses `format long g` for full
     precision golden capture).
   - `examples/kattan/problem_14_1.jl` — runnable LibFEM example with ASCII
     schema header, golden assertions, equilibrium check.
   - `docs/adr/2026-07-31-problem-14-1-port-plan.md` — this document.

2. **Test integration** — `problem_14_1_integration` testset added inside the
   `d2_q8` testset in `test/runtests.jl`, right after the `assemble` testset.

3. **API mapping** (Julia ↔ MATLAB):
   - `QuadraticQuadElementStiffness(E,NU,h, 0,0, 0.7,0, 0.7,0.4, 0,0.4, 1)`
     → `d2_q8_elementstiffness(E, NU, h, x6,y6, x8,y8, x3,y3, x1,y1,
     x7,y7, x5,y5, x2,y2, x4,y4, p)`. The MATLAB function takes only the 4
     corners and computes the mid-edge nodes internally as coordinate
     averages; the Julia function takes all 8 nodes explicitly, so the
     mid-edge averages `(0.35,0), (0.7,0.2), (0.35,0.4), (0,0.2)` are passed
     directly. Node ordering matches: corners 1-4 CCW, mid-edges 5-8 in
     local Q8 order.
   - `QuadraticQuadAssemble(K, k1, 6,8,3,1,7,5,2,4)`
     → `d2_q8_assemble(K, k1, 6, 8, 3, 1, 7, 5, 2, 4)`
   - `QuadraticQuadElementStresses(E,NU, 0,0, 0.7,0, 0.7,0.4, 0,0.4, 1, u1)`
     → `d2_q8_elementstress(E, NU, x6,y6, x8,y8, x3,y3, x1,y1, x7,y7, x5,y5,
     x2,y2, x4,y4, p, u1)` — both evaluate at the element centroid (ξ=η=0).
   - `QuadraticQuadElementPStresses(sigma1)` → `d2_q8_elementpstress(sig1)`
   - `SpringElementStiffness(4000)` → `d1_spring_elementstiffness(4000)`
   - `SpringAssemble(K, k, i, j)` → `d1_spring_assemble(K, k, i, j)` — passing
     the spring DOF pair (e.g. `12, 17`) reproduces MATLAB behaviour exactly.
   - `SpringElementForces(k, u)` → `d1_spring_elementforce(k, u)`

4. **Model**
   - Node map: N1(0.0,0.4), N2(0.35,0.4), N3(0.7,0.4), N4(0.0,0.2),
     N5(0.7,0.2), N6(0.0,0.0), N7(0.35,0.0), N8(0.7,0.0).
   - Single Q8 element, local order (corners CCW, then mid-edges):
     local 1→6, 2→8, 3→3, 4→1, 5→7, 6→5, 7→2, 8→4.
   - Springs: DOF 12 ↔ 17 (node 6 → ground), DOF 14 ↔ 18 (node 7 → ground),
     DOF 16 ↔ 19 (node 8 → ground).
   - Free DOFs 1:16, constrained DOFs 17-19. Loads
     f = [0; 5.8333; 0; 23.3333; 0; 5.8333; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0].
   - u = k\f, U = [u; 0; 0; 0], F = K·U (near-zero entries zeroed with
     `F[abs.(F) .< 1e-10] .= 0.0`).

5. **Singularity handling (unique vs non-unique quantities)** — the plate is
   supported only by vertical springs, so the reduced 16×16 stiffness has a
   zero-energy rigid x-translation mode (RCOND ≈ 1.3e-17, same as 13.3).
   Absolute `ux` values therefore depend on the solver (Octave backslash and
   Julia `\` return different particular solutions, differing by a constant
   shift). The golden assertions check only physically unique quantities:
   - `uy` (≈ 2.91e-3 … 2.93e-3 m, near-uniform field),
   - relative `ux` differences between nodes,
   - spring-ground reactions F(17:19) ≈ [-11.6419; -11.7162; -11.6419] kN,
   - element stresses at centroid σ ≈ [-70.85; 2380.54; ≈0] kPa,
   - spring element forces ≈ ±11.6419 / ±11.7162 / ±11.6419 kN.

## Consequences

- Golden values were captured from an Octave run of `problem_14_1.m` (full
  precision via `format long g`; symbolic `w = (sym ...)` noise blocks in the
  output are expected from `QuadraticQuadElementStresses` and are ignored).
- The reference manual prints σ = 1.0e3·[-0.0709; 2.3805; 0.0000] =
  [-70.9; 2380.5; 0] kPa. Julia matches the manual to printed precision
  ([-70.8527; 2380.5408; -6.7e-11]), while the Octave symbolic package drifts
  slightly ([-72.05; 2379.96; 0]) due to symbolic integration round-off — the
  golden stress assertions use the Julia/manual values.
- The example demonstrates the Q8 element in combination with spring elements
  (`d1_spring_*`), exercising mixed-element assembly of a 19-DOF system.
- Assertions use `rtol=1e-2` for uy/reactions/stresses/spring forces, `atol=1e-9`
  for relative ux, and `abs(x) < 1e-2` for τxy (which should be exactly 0).
