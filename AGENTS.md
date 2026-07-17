# LibFEM.jl Agent Instructions

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

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
