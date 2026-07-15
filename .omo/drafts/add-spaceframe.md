---
slug: add-spaceframe
status: approved
intent: unclear
pending-action: write .omo/plans/add-spaceframe.md
approach: implement 3D beam (SpaceFrame) element with 12×12 stiffness matrix, assembly, forces, and 5 diagram functions, using coordinates instead of angles, and the existing generic _assemble! helper with dofs=6
---

# Draft: add-spaceframe

## Components (topology ledger)
- d3_beam_elementstiffness | 12×12 stiffness with Lambda rotation | active | src/LibFEM.jl
- d3_beam_assemble | generic _assemble!(K,k,i,j,6) | active | src/LibFEM.jl
- d3_beam_elementforces | kprime*R*u force vector | active | src/LibFEM.jl
- d3_beam_elementlength | 3D distance utility | active | src/LibFEM.jl
- d3_beam_elementaxialdiagram | plot axial force | active | src/LibFEM.jl
- d3_beam_elementshearydiagram | plot shear force Y | active | src/LibFEM.jl
- d3_beam_elementshearzdiagram | plot shear force Z | active | src/LibFEM.jl
- d3_beam_elementmomentyidiagram | plot moment about Y | active | src/LibFEM.jl
- d3_beam_elementmomentzdiagram | plot moment about Z | active | src/LibFEM.jl
- d3_beam_elementtorsiondiagram | plot torsion | active | src/LibFEM.jl
- Benchmark integration | add d3_beam to test/benchmark.jl | active | test/benchmark.jl
- Comparative tests | MATLAB reference verification | deferred | test/comparison.jl

## Open assumptions (announced defaults)
| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| Element choice | SpaceFrame (3D beam) over LinearTriangle or others | Natural extension of d2_beam, uses coords not angles, highest educational value per README's 'first release' | Yes — swap for a different element |
| Naming | d3_beam_* prefix | Follows AGENTS.md convention for SpaceFrame mapping | No — convention is binding |
| Assembly | Reuse _assemble! with dofs=6 | The range-based helper (line 20-28) supports any dofs count generically | Yes — could write custom 144-line assembler |
| Angle convention | Coordinates-based (no angles) | MATLAB ref uses Lambda rotation matrix from node coords, not Euler angles | No — physics constraint |
| Stress function | Not implemented | MATLAB ref has no SpaceFrameElementStress.m — force vector serves that role | Yes — add later if needed |
| Diagram functions | Return Plots.jl objects | Follows existing d2_beam pattern | No — consistent with codebase |
| Plots dependency | Already present in src using Plots (line 2) | No dependency work needed | N/A |
| Test approach | After-implementation comparison vs MATLAB | MATLAB reference values known; tests-after is appropriate | Yes — could use TTD |

## Findings (cited - path:lines)
- src/LibFEM.jl:585 — 7 element types, all 2-node with _assemble! helper
- _assemble! (lines 20-28) uses range indexing `(dofs*(i-1)+1):(dofs*i)` — generic for ANY dofs count
- d2_beam diagram functions (lines 149-238) return Plots.jl p objects
- 10 SpaceFrame MATLAB files exist in Doc/Kattan/M-Files/ (no Stress file)
- SpaceFrameAssemble.m uses explicit 6-DOF indexing (144 lines) — redundant with generic _assemble!
- SpaceFrameElementForces.m duplicates stiffness matrix construction — can share via elementstiffness
- Existing d2_beam_elementforce uses kprime*T*u pattern — SpaceFrame uses kprime*R*u with 4×4 block R composed of 3×3 Lambda

## Decisions (with rationale)
1. **Implement SpaceFrame first** — it's the most natural 3D extension of d2_beam with 6 DOF/node and coordinate-based transformation. Other elements (LinearTriangle, BilinearQuad) use 2D formulations that don't build on existing 1D infrastructure.
2. **Reuse _assemble! with dofs=6** — the generic helper handles any DOF count; a custom 144-line assembler adds zero value and increases maintenance burden.
3. **d3_beam_elementforces calls d3_beam_elementstiffness internally** — avoids MATLAB's pattern of duplicating the kprime matrix construction.
4. **No stress function** — MATLAB reference doesn't include one; force vector is the standard output for frame elements.
5. **Tests use known MATLAB examples** — use values from Kattan examples chapter (not TDD since reference exists).

## Scope IN
- 10 Julia functions in src/LibFEM.jl mapped from 10 MATLAB M-files
- All exports
- Benchmark integration
- d3_beam_elementlength utility

## Scope OUT (Must NOT have)
- Do NOT create new source files — append to src/LibFEM.jl
- Do NOT modify existing element functions
- Do NOT modify test/runtests.jl or test/comparison.jl (those test existing elements)
- Do NOT modify Doc/ directory contents
- Do NOT remove unused ModelingToolkit dependency (separate concern)
- Do NOT implement stress function (no MATLAB reference exists)
- Do NOT implement element solution function (no MATLAB reference exists for SpaceFrame)

## Open questions
None — scope is fully determined by MATLAB reference.

## Approval gate
status: awaiting-approval
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
