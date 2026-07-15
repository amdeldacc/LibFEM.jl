---
slug: update-agents-md
status: approved
intent: clear
pending-action: write .omo/plans/update-agents-md.md
approach: Update AGENTS.md in-place and create CONTEXT.md as a pure domain glossary mapping Kattan's MATLAB terminology to LibFEM.jl concepts.
---

# Draft: update-agents-md

## Components (topology ledger)
- id: agents-md
  outcome: AGENTS.md contains only high-signal, actionable developer guidelines
  status: active
  evidence path: AGENTS.md
- id: context-md
  outcome: CONTEXT.md contains the pure glossary of domain terms and MATLAB mappings
  status: active
  evidence path: CONTEXT.md

## Open assumptions (announced defaults)
- None.

## Findings (cited - path:lines)
- Single source file `src/LibFEM.jl` contains all module exports and functions (src/LibFEM.jl:1-709).
- Project.toml lists ModelingToolkit v10.2.0 as a dependency, but it is not imported or used (Project.toml:7,10).
- Diagram plotting functions use Matlab-style plot commands but Plots.jl is not in Project.toml and not imported (src/LibFEM.jl:166-174, 233-241, 250-258).
- Doc/ contains Kattan MATLAB M-Files reference files which are read-only.
- MATLAB files use names like `LinearBar` and `PlaneTruss`, whereas Julia uses `truss` (e.g. `d1_truss_*`, `d2_truss_*`).

## Decisions (with rationale)
- Keep the single file constraint in AGENTS.md.
- Document Julia to MATLAB name mapping rules in AGENTS.md.
- Create CONTEXT.md to define the FEM terminology domain model (1D/2D/3D, spring, truss, beam) and map them to Kattan concepts.
- Warn about unused ModelingToolkit dependency and missing Plots dependency in AGENTS.md.

## Scope IN
- Update AGENTS.md in-place.
- Create CONTEXT.md.

## Scope OUT (Must NOT have)
- Do not create any new code files or test files.
- Do not modify any other file in the repository.

## Open questions
- None.

## Approval gate
status: approved
approach: Update AGENTS.md and create CONTEXT.md to align with Kattan MATLAB mappings and library constraints.
