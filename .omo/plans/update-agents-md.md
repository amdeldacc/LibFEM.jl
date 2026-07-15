# update-agents-md - Work Plan

## TL;DR (For humans)

**What you'll get:** An updated `AGENTS.md` with developer guidelines and toolchain quirks, and a new `CONTEXT.md` acting as a glossary mapping Kattan MATLAB concepts to Julia names.

**Why this approach:** Splitting developer instructions from domain concepts keeps documentation clean.

**What it will NOT do:** Make changes to the source code, add dependencies, or write test files.

**Effort:** Quick
**Risk:** Low

Your next move: approve to write the changes. Full execution detail follows below.

---

> TL;DR (machine): Quick effort, low risk. Update AGENTS.md and create CONTEXT.md.

## Scope
### Must have
- Update `AGENTS.md` with critical constraints, dependencies/toolchain, and conventions.
- Create `CONTEXT.md` with domain terms (spring, truss, beam) and MATLAB file mappings.
### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not modify `src/LibFEM.jl` or any file in `Doc/`.
- Do not add packages to `Project.toml`.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: none (documentation update)
- Evidence: .omo/evidence/update-agents-md-diff.txt

## Execution strategy
### Parallel execution waves
- Wave 1: Edit `AGENTS.md` in place and create `CONTEXT.md`.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | None | None | 2 |
| 2 | None | None | 1 |

## Todos
- [x] 1. Edit AGENTS.md to include high-signal instructions and constraints
  What to do / Must NOT do: Update AGENTS.md with sections: Critical Constraints (Single file, read-only MATLAB directory, no automated tests), Toolchain & Dependencies (Julia load syntax, unused ModelingToolkit, invalid Plotting syntax / missing Plots dependency), and Coding Conventions (angles in degrees, dimensional prefixes, 3-function extension pattern).
  Parallelization: Wave 1 | Blocked by: None | Blocks: None
  References: AGENTS.md
  Acceptance criteria: AGENTS.md contains the updated instructions.
  QA scenarios: Read and print the content of AGENTS.md, verify no formatting errors.
  Commit: Y | docs: update AGENTS.md with high-signal instructions

- [x] 2. Create CONTEXT.md with domain terms and MATLAB mappings
  What to do / Must NOT do: Create CONTEXT.md containing a pure glossary of domain terms (spring, truss, beam, 1D/2D/3D) and their mapping to Kattan MATLAB concepts (e.g. LinearBar mapping to truss).
  Parallelization: Wave 1 | Blocked by: None | Blocks: None
  References: CONTEXT.md
  Acceptance criteria: CONTEXT.md contains terms and Kattan mappings.
  QA scenarios: Read and print the content of CONTEXT.md, verify no formatting errors.
  Commit: Y | docs: create CONTEXT.md domain glossary

## Final verification wave
- [x] F1. Plan compliance audit
- [x] F2. Code quality review
- [x] F3. Real manual QA
- [x] F4. Scope fidelity

## Commit strategy
- Separate commits for each file:
  - `docs: update AGENTS.md with high-signal instructions`
  - `docs: create CONTEXT.md domain glossary`

## Success criteria
- AGENTS.md is updated with accurate, concise guidance.
- CONTEXT.md contains the clear domain model mappings.
