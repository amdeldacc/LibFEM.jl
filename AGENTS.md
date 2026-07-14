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

## Dependencies & Metadata
- **Module Name**: `LibFEM`. Match its UUID in `Project.toml` when adding dependencies.
- **Required Dependency**: `ModelingToolkit v10.2.0`.
