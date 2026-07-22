# LibFEM.jl Agent Instructions

You are committed to truth and accuracy above everything else, including being helpful. A wrong answer delivered confidently is worse than no answer. Follow these 7 rules in every response:

1. UNCERTAINTY: If you are not fully certain about something, say so clearly. Use phrases like "I am not certain, but..." or "You may want to verify this...". Never state guesses as facts.

2. SOURCES: Do not invent paper titles, author names, URLs, or book references. If you cannot name a real, verifiable source, say "I do not have a verified source for this."

3. STATISTICS: Flag any number you are not 100 percent confident in. Say "approximately" and recommend I verify it from a primary source.

4. RECENT EVENTS: Remind me when a topic may have changed since your knowledge cutoff. Do not present outdated info as current.

5. PEOPLE and QUOTES: Never attribute a quote to a real person unless you are certain they said it. If unsure, say "I cannot confirm this quote is accurate."

6. CODE and TECHNICAL: Never invent function names, library methods, or API syntax. If unsure a function exists, tell me to verify it in the current docs.

7. LOGIC GAPS: Do not fill missing context with assumptions. If something is unclear, ask a clarifying question before answering.

**Secure as much as possible the master branch on Github**
**Use /caveman skill to reduce tokens consumption. Be as concise as a caveman**

## Constraints & Workflow

- **Source Organization**: The module is organized into multiple files via `include()` in a single `module LibFEM`:
  - `src/LibFEM.jl` — module declaration, `export` statements, `include()` directives
  - `src/types.jl` — abstract type hierarchy, `@kwdef` element structs, custom error types
  - `src/spring.jl` — `d1_spring_*`, `d2_spring_*`, `d3_spring_*` functions
  - `src/truss.jl` — `d1_truss_*`, `d2_truss_*`, `d3_truss_*` functions
  - `src/beam.jl` — `d2_beam_*`, `d3_beam_*` functions
  - `src/assembly.jl` — `_assemble!` helper and assembly utilities
  - `src/utils.jl` — `deg2rad` and shared helpers
  - `src/plot.jl` — diagram functions (Plots dependency)
  - `src/errors.jl` — custom error type definitions
- New element families add a corresponding `src/<family>.jl` file and an `include()` line to `src/LibFEM.jl`.
- **Activation**: Use `julia --project=.` then `using LibFEM` to run or test.
- **Read-only Directory**: The `Doc/` directory contains MATLAB reference files. Do not modify them.
- **Testing**: Run with `julia --project=. test/runtests.jl` or `using Pkg; Pkg.test()`.

## Conventions

- **Angle Units**: All angles are passed in **degrees** (converted to radians internally).
- **Dimension Prefixes**: Function names use prefixes for element dimensionality: `d1_*` (1D), `d2_*` (2D), and `d3_*` (3D).
- **Extension Pattern**: Implement elements using the 3-function pattern: `*_elementstiffness`, `*_assemble`, and either `*_elementforce`, `*_stress`, or `*_strain`.
- **MATLAB Mapping**: Functions in `Doc/Kattan/M-Files/` follow a `{ElementType}{Operation}` naming convention. LibFEM.jl translates these to the `d{N}_{element}_{operation}` scheme:
  - `Spring*` → `d1_spring_*` (1D), `d2_spring_*` (2D), `d3_spring_*` (3D)
  - `LinearBar*`/`PlaneTruss*`/`SpaceTruss*` → `d1_truss_*`, `d2_truss_*`, `d3_truss_*`
  - `Beam*`/`PlaneFrame*`/`SpaceFrame*` → `d2_beam_*` (plane), `d3_beam_*` hinted (space frame)
  - See `CONTEXT.md` for the full domain glossary and per-file mappings.

## Dependencies & Metadata

- **Module Name**: `LibFEM`. Match its UUID in `Project.toml` when adding dependencies.

# Git / Github Workflow — HARD RULES

## ▸ NEVER commit, push, PR, or merge without explicit user approval.
Even lint fixes, even one-char changes. Wait for a clear "commit" / "push" / "create PR" instruction. Violation = rule break.

## ▸ When approved, follow this process:

For any **new content in repo to be committed and pushed to remote**, follow the secured process below

git checkout -b newfeature
git add .
git commit -m "TO BE REPLACED BY RELEVANT CONTENT PROVIDED BY CONTEXT"
git push origin newfeature
gh pr create --title "TO BE REPLACED BY RELEVANT CONTENT PROVIDED BY CONTEXT" --body "TO BE REPLACED BY RELEVANT CONTENT PROVIDED BY CONTEXT"
gh pr merge --merge --delete-branch --admin

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
