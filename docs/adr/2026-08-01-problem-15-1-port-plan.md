# ADR 2026-08-01 — Port Kattan Problem 15.1 (Linear Tetrahedron 3D block) to LibFEM

## Status

Accepted

## Context

Kattan's "MATLAB Guide to Finite Elements" (2nd ed., Springer 2007), Problem 15.1:
a 3D block 0.025 m (x) × 0.5 m (y) × 0.25 m (z) of material E = 210 GPa, ν = 0.3,
discretized with 6 linear tetrahedron elements (8 nodes × 3 DOF = 24 DOFs).
The bottom face (y = 0) is fully fixed (DOFs 1:6 and 13:18); upward vertical
forces totalling 18.75 kN are applied at the four top-face nodes
(Fy = 3.125 / 6.25 / 6.25 / 3.125 kN at nodes 3 / 4 / 7 / 8, free DOFs 7:12 and 19:24).

This ADR records the port of that problem to LibFEM, following the same workflow
used for Problems 13.1-13.3 and 14.1 (`.m` golden capture in Octave, runnable
Julia example, integration test, ADR, PR).

## Decision

1. **New files**
   - `Doc/Kattan/Solutions-Manual/problem_15_1.m` — exact mirror of the
     solutions-manual MATLAB commands (uses the `../M-Files` directory on the
     path and `format long g` for full-precision golden capture; no symbolic
     package needed — the tetrahedron element is coordinate-explicit).
   - `examples/kattan/problem_15_1.jl` — runnable LibFEM example with ASCII
     schema header, golden assertions, equilibrium check.
   - `docs/adr/2026-08-01-problem-15-1-port-plan.md` — this document.

2. **Test integration** — `problem_15_1_integration` testset added inside the
   `d3_tet` testset in `test/runtests.jl`, after the `pstress` testset.

3. **API mapping** (Julia ↔ MATLAB):
   - `TetrahedronElementStiffness(E, NU, 0,0,0, 0.025,0,0, 0.025,0.5,0, 0.025,0.5,0.25)`
     → `d3_tet_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)`
   - `TetrahedronAssemble(K, k1, 1,2,4,8)` → `d3_tet_assemble(K, k1, 1, 2, 4, 8)`
   - `TetrahedronElementStresses(E, NU, coords..., u1)` → `d3_tet_elementstress(E, NU, coords..., u1)`
   - `TetrahedronElementPStresses(sigma1)` → invariants computed inline in the
     example via a `invariants(s)` helper (see §4), with principal stresses
     displayed via `d3_tet_elementpstress`.

4. **Invariant semantics divergence (important)** — MATLAB's
   `TetrahedronElementPStresses` returns the stress **invariants**
   `[I1 = trace; I2 = Σ principal minors; I3 = det]`, whereas the Julia
   `d3_tet_elementpstress` returns the actual **principal stresses**
   (σ1, σ2, σ3, τ_max) via a 3×3 eigendecomposition. The golden capture is
   therefore done on the invariants, computed in Julia directly from the Voigt
   stress vector:
   ```
   invariants(s) = (s[1]+s[2]+s[3],
                    s[1]*s[2]+s[1]*s[3]+s[2]*s[3]-s[4]^2-s[5]^2-s[6]^2,
                    det([s[1] s[4] s[6]; s[4] s[2] s[5]; s[6] s[5] s[3]]))
   ```
   These are exact (deterministic) functions of σ, so they match the Octave
   golden values to machine precision. Principal stresses are shown for
   interpretation only, not asserted.

5. **Model**
   - Node map: N1(0,0,0), N2(0.025,0,0), N3(0,0.5,0), N4(0.025,0.5,0),
     N5(0,0,0.25), N6(0.025,0,0.25), N7(0,0.5,0.25), N8(0.025,0.5,0.25).
   - Element connectivity (global nodes): k1=(1,2,4,8), k2=(1,2,8,5),
     k3=(2,8,5,6), k4=(1,3,7,4), k5=(1,7,5,8), k6=(1,8,4,7).
   - Fixed DOFs 1:6 (nodes 1, 2) and 13:18 (nodes 5, 6); free DOFs 7:12
     (nodes 3, 4) and 19:24 (nodes 7, 8). Loads f = [0; 3.125; 0; 0; 6.25; 0;
     0; 6.25; 0; 0; 3.125; 0].
   - u = k\f, U = [0;...;u;0;...], F = K·U (near-zero entries zeroed with
     `F[abs.(F) .< 1e-10] .= 0.0`).
   - Element nodal displacement vectors (local node order):
     u1=[U(1:6);U(10:12);U(22:24)], u2=[U(1:6);U(22:24);U(13:15)],
     u3=[U(4:6);U(22:24);U(13:15);U(16:18)], u4=[U(1:3);U(7:9);U(19:21);U(10:12)],
     u5=[U(1:3);U(19:21);U(13:15);U(22:24)], u6=[U(1:3);U(22:24);U(10:12);U(19:21)].

6. **Uniqueness** — the bottom face is fully fixed, so the reduced 12×12
   stiffness is non-singular and ALL quantities (displacements, reactions,
   stresses, invariants) are physically unique. Assertions use `rtol=1e-4`
   for displacements/stresses/invariants and `rtol=1e-6` for reactions (the
   latter are large values dominated by float round-off at the 1e-13 level).

## Consequences

- Golden values were captured from an Octave run of `problem_15_1.m` (full
  precision via `format long g`) and match the solutions-manual session output
  exactly (the manual prints 4-digit displacements at 1e-5 scale and
  stresses at 1e3 scale; the .m file reproduces those to full precision).
- Julia reproduces the Octave golden to `rtol=1e-4` for all 12 free
  displacements, 12 reactions, 36 stress components and 15 invariants, and
  the equilibrium check sums to ≈ 1e-13 (machine noise).
- Elements 2 and 3 are geometrically mirrored (same shape/loading) and produce
  identical stresses (asserted with `rtol=1e-12`).
- The example demonstrates the 3D linear tetrahedron element on a fully-3D
  problem (first 3D Kattan port), exercising 24-DOF mixed assembly.
- MEMORY.md and ADRs updated; no module/API changes were needed (the
  `d3_tet_*` family already existed).
