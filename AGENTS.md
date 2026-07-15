# LibFEM.jl Agent Instructions

## Constraints & Workflow
- **Single Source File**: All code must be in `src/LibFEM.jl`. Do not create new source files; append to this file and add the necessary `export` calls.
- **Activation**: Use `julia --project=.` then `using LibFEM` to run or test.
- **Read-only Directory**: The `Doc/` directory contains MATLAB reference files. Do not modify them.
- **Testing**: No automated testing or CI currently exists in this repository.

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
- **Required Dependency**: `ModelingToolkit v10.2.0`.
- **Unused Dependency**: `ModelingToolkit v10.2.0` is listed in `Project.toml` but is NOT imported or used anywhere in `src/LibFEM.jl`. Consider removing if no future use is planned.
- **Missing Dependency**: Functions `d2_beam_elementaxialdiagram`, `d2_beam_elementmomentdiagram`, and `d2_beam_elementsheardiagram` call `plot()` directly (Matlab-style) at lines 171, 173, 238, 240, 255, 257 of `src/LibFEM.jl`, plus `title()` and `#hold on` comments, but no plotting package (`Plots`, `PyPlot`, etc.) is imported or listed in `Project.toml`. These functions will error at runtime. Add `Plots` to `Project.toml` and add `using Plots` before using these functions.

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
