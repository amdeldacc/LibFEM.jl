# ADR 2026-08-01 — Port Kattan Problem 16.1 (Linear Brick cantilever plate) to LibFEM

## Status

Accepted

## Context

Kattan's "MATLAB Guide to Finite Elements" (2nd ed., Springer 2007), Problem 16.1:
a cantilever plate 0.5 m (x) × 0.25 m (y) × 0.025 m (z) of material
E = 210 GPa, ν = 0.3, discretized with 2 linear 8-node brick elements
(12 nodes × 3 DOF = 36 DOFs). The left face (x = 0, nodes 1–4) is fully fixed
(DOFs 1:12); a total force of 18.75 kN is applied at the free-end nodes 9–12
(Fx = 4.6875 kN each, node-major DOFs 25, 28, 31, 34).

This ADR records the port of that problem to LibFEM, following the same workflow
used for Problem 15.1 (`.m` golden capture, runnable Julia example,
integration test, ADR, PR).

## Book transcript contains a genuine singularity bug

The solutions-manual session for Problem 16.1 (in `SolutionstoProblems2.rtf`)
produces a displacement vector `u = 1.0e+008 × [0×16; 1.5729×8]`, i.e. a tip
displacement of 1.57×10⁸ m — physically absurd (the plate is 0.5 m long).
MATLAB itself reports `RCOND = 1.551156e-017` when solving the reduced system,
i.e. the reduced 24×24 stiffness is singular. Investigation showed why:

### Root cause: mixed DOF conventions in the book's assembly

1. The book's `LinearBrickElementStiffness` returns a **component-major**
   element matrix `k_c`: its 24 DOFs are ordered u1..u8, v1..v8, w1..w8
   (verified by matching our Julia element stiffness rows 1–3 against the
   book's printed `k1` to display precision, rel. err ≈ 1.7e-5).

2. The book's `LinearBrickAssemble` is **node-major** hand-unrolled code:
   `K(3*i-2, 3*i-2) += k(1,1)`, i.e. it assumes DOFs are grouped per node
   (u_i, v_i, w_i per node i).

3. Feeding a component-major `k_c` into a node-major assembler is
   **inconsistent**: for element 1 (nodes 1–8) the placement is the identity
   mapping, but for element 2 (nodes 5–12) the +12 DOF offset places the
   element's v/w components onto the wrong global DOFs. We reproduced the
   book's global K exactly this way (rel. err 1.3e-4 vs the printed `K2`).

4. Consequently the book's reduced system `k = K(13:36,13:36)` is **singular**
   (rank 23 of 24; smallest eigenvalue ≈ −2e-9, cond ≈ 2×10¹⁷ — we reproduce
   MATLAB's RCOND ≈ 1.55e-17), which is why `u` is garbage.

5. The book's load vector `f` is also wrong: it places 4.6875 at component-major
   DOFs 13, 16, 19, 22, i.e. v1, v4, v7, v10 (y-forces) rather than the
   x-forces at nodes 9–12 that the problem statement specifies.

### Port decision

Do **not** port the book's buggy computation. Assemble the model with the
physically-correct, node-major conventions already used by LibFEM's
`d3_brick_*` family, and take the golden values from the Julia solve itself.
The book's RTF is used only to cross-check the element stiffness matrix
(rows 1–3 match to display precision) and to document the bug.

## Decision

1. **New files**
   - `Doc/Kattan/Solutions-Manual/problem_16_1.m` — exact mirror of the
     solutions-manual MATLAB commands (needs the symbolic package to build the
     element stiffness; uses `../M-Files` on the path). Comments document the
     near-singularity (RCOND ≈ 1.5e-17) and the resulting garbage `u`.
   - `examples/kattan/problem_16_1.jl` — runnable LibFEM example with ASCII
     schema header, golden assertions (rtol=1e-6) and an equilibrium check
     (sum of forces ≈ 0 within 1e-8).
   - `docs/adr/2026-08-01-problem-16-1-port-plan.md` — this document.

2. **Test integration** — `problem_16_1_integration` testset added inside the
   `d3_brick` testset in `test/runtests.jl`, after the `assemble` testset.

3. **API mapping** (Julia ↔ MATLAB):
   - `LinearBrickElementStiffness(E, NU, M1..M8)` (component-major, symbolic)
     → `d3_brick_elementstiffness(E, NU, x1..z8)` (node-major, J1..J8 order,
     2×2×2 Gauss quadrature).
   - `LinearBrickAssemble(K, k, i,j,m,n,p,q,r,s)` → `d3_brick_assemble(K, k, ...)`
     (both take 8 node indices; Julia's is node-major throughout).

4. **Node numbering** — the brick's local node order in the book is
   (M1..M8): M1(0,0,0.025), M2(0,0,0), M3(0,0.25,0), M4(0,0.25,0.025),
   M5(0.25,0,0.025), M6(0.25,0,0), M7(0.25,0.25,0), M8(0.25,0.25,0.025).
   The Julia J-order is bottom-face-CCW then top-face-CCW, which maps
   (J1..J8) = (M2, M6, M7, M3, M1, M5, M8, M4), i.e. global nodes
   [2, 6, 7, 3, 1, 5, 8, 4] for element 1 and
   [6, 10, 11, 7, 5, 9, 12, 8] for element 2 (element 2 = element 1 shifted
   +0.25 m in x, nodes 5–12).

5. **Model** — fixed DOFs 1:12 (nodes 1–4); free DOFs 13:36. Loads
   f = 4.6875 kN at node-major DOFs 25, 28, 31, 34 (Fx at nodes 9–12).
   u = k\f; U = [0;…;u;0;…]; F = K·U (near-zero entries zeroed).
   Element stresses at centroids via `d3_brick_elementstress` (Voigt order),
   principal stresses via `d3_brick_elementpstress`.

6. **Goldens** — all computed by the Julia solve:
   - 24 free displacements: max |u| = 6.82 μm at the free-end tip
     (sanity: axial σ = F/A = 3 MPa, ε = σ/E = 1.43e-5, ΔL = 7.14 μm —
     consistent with the 6.82 μm tip deflection which includes bending).
   - 12 reactions at nodes 1–4 (Fx/Fy/Fz each), 4 applied loads echoed at
     DOFs 25/28/31/34, 6 stress components per element, principal stresses.
   - The reduced stiffness is SPD (cond ≈ 6.5e4) and equilibrium holds to
     ≈ 1e-13 (machine noise).

## Consequences

- The 16.1 port is the first to expose a genuine numerical bug in the Kattan
  solutions manual: the book's reduced 24×24 system is singular (rank 23),
  so its printed `u` (1.57×10⁸ m) is not a meaningful golden. The port instead
  asserts Julia-computed values; the cross-check against the book is limited
  to the element stiffness (display precision).
- The example exercises 36-DOF mixed assembly of two 3D bricks, the largest
  model ported so far, plus centroidal stresses/principal stresses.
- No module/API changes were needed (the `d3_brick_*` family already existed).
- MEMORY.md and ADRs updated.
