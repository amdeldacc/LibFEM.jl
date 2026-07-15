# add-spaceframe - Work Plan

## TL;DR (For humans)

**What you'll get:** A complete 3D beam (Space Frame) finite element — 10 new functions in `src/LibFEM.jl` that build 12×12 stiffness matrices from node coordinates, compute element forces, and plot axial/shear/moment/torsion diagrams. Plugs into the existing global assembly system.

**Why this approach:** Space Frame is the natural 3D extension of the existing `d2_beam` element with the highest educational value for the library's stated goal ("first and incomplete release"). It uses node coordinates (not angles/trig) via a rotation matrix, and the generic `_assemble!` helper works for any DOF count — no custom 144-line assembler needed.

**What it will NOT do:** Modify any existing element or test file. Create no new source files. No stress function (MATLAB has none either). No changes to `Doc/` or `Project.toml`.

**Effort:** Medium
**Risk:** Low — every function has a direct MATLAB reference with known input/output values
**Decisions I made for you:** Chose SpaceFrame over LinearTriangle/CST/etc. Naming follows `d3_beam_*` per project convention. Reused `_assemble!(K,k,i,j,6)` instead of writing custom 144-line assembler. No stress function (MATLAB ref doesn't have one). Tests use known MATLAB outputs.

Your next move: **Approve** to start execution, or request changes.

---

> TL;DR (machine): Medium effort, Low risk. 10 new functions adding 3D beam (12×12 stiffness, Lambda rotation, coordinate-based) to src/LibFEM.jl. Reuses existing _assemble! with dofs=6. No new files, no dependency changes.

## Scope
### Must have
- d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2) → 12×12 matrix with Lambda rotation
- d3_beam_assemble(K, k, i, j) → delegates to _assemble!(K, k, i, j, 6)
- d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u) → 12×1 force vector (calls stiffness internally)
- d3_beam_elementlength(x1, y1, z1, x2, y2, z2) → L
- 5 diagram functions (axial, shearY, shearZ, momentY, momentZ, torsion) returning Plots.jl objects
- All exports
- Benchmark integration: add d3_beam to test/benchmark.jl
- Comparative test passing against Kattan example values

### Must NOT have (guardrails, anti-slop, scope boundaries)
- No new source files — all code appended to src/LibFEM.jl
- No changes to existing element functions, test/runtests.jl, or test/comparison.jl
- No changes to Doc/ directory (MATLAB refs are read-only)
- No stress function (no MATLAB reference exists)
- No element solution function (not in MATLAB SpaceFrame refs)
- No changes to Project.toml (Plots already used)
- No removal of ModelingToolkit from Project.toml (separate concern)

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after + comparative MATLAB values. Each function verified with:
  1. `julia --project=. -e 'using LibFEM; ...'` inline assertions matching Kattan example values
  2. Then full `julia --project=. -e 'using Pkg; Pkg.test()'` to confirm no regressions
  3. Then `julia --project=. test/benchmark.jl` to confirm d3_beam benchmark runs
- Evidence: .omo/evidence/add-spaceframe/

## Execution strategy
### Parallel execution waves
- **Wave 1**: Stiffness + Length + Assemble (stateless math, independent)
- **Wave 2**: Forces + 5 Diagram functions (depends on stiffness output shape)
- **Wave 3**: Benchmark integration + comparative verification
- **Wave 4**: Final verification wave (F1-F4 in parallel)

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1. Stiffness + Length + Assemble | — | 2 | — |
| 2. Forces + Diagram | 1 | 3 | — |
| 3. Benchmark + Tests | 2 | F1-F4 | — |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [ ] 1. Implement d3_beam_elementstiffness, d3_beam_elementlength, d3_beam_assemble
  What to do: Append to src/LibFEM.jl before `end # module`:
  - d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2): Compute L, build 12×12 kprime matrix (same pattern as SpaceFrameElementStiffness.m lines 13-35), compute Lambda 3×3 rotation from node coords, form 12×12 block-diagonal R from Lambda, return R'*kprime*R
    - kprime: w1=E*A/L, w2=12*E*Iz/L³, w3=6*E*Iz/L², w4=4*E*Iz/L, w5=2*E*Iz/L, w6=12*E*Iy/L³, w7=6*E*Iy/L², w8=4*E*Iy/L, w9=2*E*Iy/L, w10=G*J/L (12×12 matrix per MATLAB lines 24-35)
    - Lambda direction-cosine formulas (per MATLAB):
      - If x1==x2 && y1==y2 (vertical element, D=0):
        - If z2 > z1: Lambda = [0 0 1; 0 1 0; -1 0 0]
        - Else: Lambda = [0 0 -1; 0 1 0; 1 0 0]
      - Else (general case):
        - Cx=(x2-x1)/L, Cy=(y2-y1)/L, Cz=(z2-z1)/L
        - D = sqrt(Cx²+Cy²)
        - Row1 (element x-axis): [Cx, Cy, Cz]
        - Row2 (local xy-plane): [-Cy/D, Cx/D, 0]
        - Row3 (z = x × y): [-Cx*Cz/D, -Cy*Cz/D, D]
        - Lambda = [Row1; Row2; Row3] (3×3)
    - R = blockdiag(Lambda, Lambda, Lambda, Lambda) (12×12)
    - Return R'*kprime*R
  - d3_beam_elementlength(x1, y1, z1, x2, y2, z2): sqrt((dx)^2+(dy)^2+(dz)^2)
  - d3_beam_assemble(K, k, i, j): `_assemble!(K, k, i, j, 6)`
  - All three exported
  Must NOT do: Do NOT duplicate stiffness matrix construction in forces function (call elementstiffness internally). Do NOT write explicit 144-line assembler — use _assemble!.
  References: src/LibFEM.jl:20-28 (_assemble!), src/LibFEM.jl:585 (end of module), Doc/Kattan/M-Files/SpaceFrameElementStiffness.m:1-59, Doc/Kattan/M-Files/SpaceFrameAssemble.m:1-152, Doc/Kattan/M-Files/SpaceFrameElementLength.m:1-6
  Acceptance criteria: `julia --project=. -e 'using LibFEM; k=LibFEM.d3_beam_elementstiffness(3e10,1.15e8,0.01,1e-4,2e-4,1e-5,0,0,0,4,0,0); @assert size(k)==(12,12); @assert isapprox(k[1,1],8.244e7, rtol=0.001); println("PASS: stiffness")'`
  QA scenarios: Happy — run acceptance test above. Failure — run `julia --project=. -e 'using LibFEM; d3_beam_assemble(zeros(12,12),zeros(12,12),1,2)'` confirm no error. Evidence .omo/evidence/add-spaceframe/task1.txt
  Commit: Y | feat: add d3_beam element stiffness, length, and assembly

- [ ] 2. Implement d3_beam_elementforces + 5 diagram functions
  What to do: Append to src/LibFEM.jl before `end # module`:
  - d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u): Call d3_beam_elementstiffness to get k; Build Lambda+R same as stiffness; return kprime*R*u (12×1 vector). NOTE: kprime is the element frame 12×12 — extract it from the stiffness computation without the R rotation. Alternative: compute kprime+R directly, extract just kprime. Best: refactor into a shared helper `_d3_beam_kprime` that both stiffness and forces use to avoid duplication.
  - d3_beam_elementaxialdiagram(f, L): plot axial force (f[1], f[7])
  - d3_beam_elementshearydiagram(f, L): plot shear Y (f[2], -f[8])
  - d3_beam_elementshearzdiagram(f, L): plot shear Z (f[3], -f[9])
  - d3_beam_elementmomentyidiagram(f, L): plot moment Y (f[5], -f[11])
  - d3_beam_elementmomentzdiagram(f, L): plot moment Z (f[6], -f[12])
  - d3_beam_elementtorsiondiagram(f, L): plot torsion (f[4], -f[10])
  - All exported
  Must NOT do: Do NOT duplicate the kprime matrix computation — create a shared `_d3_beam_kprime(E, G, A, Iy, Iz, J, L)` helper private function that both stiffness and forces call. No filename arguments, no file I/O in diagram functions.
  References: src/LibFEM.jl:149-238 (existing diagram pattern), Doc/Kattan/M-Files/SpaceFrameElementForces.m:1-57, Doc/Kattan/M-Files/SpaceFrameElementAxialDiagram.m:1-12, SpaceFrameElementShearYDiagram.m, SpaceFrameElementShearZDiagram.m, SpaceFrameElementMomentYDiagram.m, SpaceFrameElementMomentZDiagram.m, SpaceFrameElementTorsionDiagram.m
  Acceptance criteria: `julia --project=. -e 'using LibFEM; f=LibFEM.d3_beam_elementforces(3e10,1.15e8,0.01,1e-4,2e-4,1e-5,0,0,0,4,0,0,zeros(12)); @assert length(f)==12; println("PASS: forces")'`
  QA scenarios: Happy — run acceptance test. Visual — create a test plot and verify it's a Plots object: `p = d3_beam_elementaxialdiagram([-1000, 500, 300, 50, 200, 150, 1000, -500, -300, -50, -200, -150], 4.0); @assert typeof(p) <: Plots.Plot`. Evidence .omo/evidence/add-spaceframe/task2.txt
  Commit: Y | feat: add d3_beam forces and 5 diagram functions

- [ ] 3. Integrate into benchmark + test against MATLAB values
  What to do:
  - Add d3_beam to test/benchmark.jl: in the stiffness group, add `"d3_beam" => @benchmarkable $lib.d3_beam_elementstiffness(...)` with E=3e10, G=1.15e8, A=0.01, Iy=1e-4, Iz=2e-4, J=1e-5, coords (0,0,0,4,0,0).
  - Write a one-shot verification script in .omo/evidence/add-spaceframe/verify.jl that computes:
    * Stiffness matrix for a 4m beam along X-axis
    * Force vector for a known displacement
    * Results compared to hand-computed MATLAB reference values
  Must NOT do: Do NOT add d3_beam tests to test/runtests.jl or test/comparison.jl (those test existing elements only). Do NOT remove existing benchmark entries.
  References: test/benchmark.jl:1-100 (existing benchmark), Doc/Kattan/M-Files/SpaceFrameElementStiffness.m, SpaceFrameElementForces.m
  Acceptance criteria: `julia --project=. .omo/evidence/add-spaceframe/verify.jl` prints 3 PASS lines. `julia --project=. test/benchmark.jl` shows d3_beam in stiffness group.
  QA scenarios: Happy — acceptance test + benchmark run. Failure — run with wrong args and confirm TypeError. Evidence .omo/evidence/add-spaceframe/task3.txt
  Commit: Y | test: add d3_beam benchmark and MATLAB verification

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit — no src/ edits outside new d3_beam functions, no test/runtests changes, no Doc/ changes
- [ ] F2. Full test suite — `julia --project=. -e 'using Pkg; Pkg.test()'` passes 296+ tests
- [ ] F3. Manual QA — `julia --project=. -e 'using LibFEM; ...'` inline compute for stiffness + forces + assemble
- [ ] F4. Scope fidelity — only new d3_beam_* functions, no existing code touched

## Commit strategy
- Todo 1: `feat: add d3_beam element stiffness, length, and assembly`
- Todo 2: `feat: add d3_beam forces and 5 diagram functions`
- Todo 3: `test: add d3_beam benchmark and MATLAB verification`
- Squash to `feat: add SpaceFrame (d3_beam) element with 10 functions` on merge

## Success criteria
1. All 10 new functions exported and callable from `using LibFEM`
2. d3_beam_elementstiffness(..., 0,0,0,4,0,0) produces correct 12×12 with k[1,1] = E*A/L
3. d3_beam_assemble(K, k, 1, 2) correctly assembles into 12×12 DOF global
4. d3_beam_elementforces produces correct 12×1 force vector
5. All 6 diagram functions return Plots.jl plots without error
6. Full test suite remains 296+ passing
7. Benchmark suite includes d3_beam
