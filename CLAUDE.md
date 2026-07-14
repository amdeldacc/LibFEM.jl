# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LibFEM.jl is an educational Finite Element Method library for Julia. It provides element stiffness matrices, assembly functions, and force/stress calculations for springs, trusses, and beams in 1D, 2D, and 3D. Inspired by "MATLAB Guide to Finite Elements" by Peter Kattan.

## Development Commands

```bash
# Start Julia REPL with the project
julia --project=.

# In Julia REPL, activate and load the package
using Pkg; Pkg.activate("."); using LibFEM

# Run tests (if added later)
using Pkg; Pkg.test()
```

## Architecture

All code is in a single module file `src/LibFEM.jl`. Functions follow a naming convention:
- `d1_*` - 1D elements (scalar DOF per node)
- `d2_*` - 2D elements (2 DOF per node for springs/trusses, 3 for beams)
- `d3_*` - 3D elements (3 DOF per node)

Each element type has three core functions:
1. `*_elementstiffness` - returns local stiffness matrix
2. `*_assemble` - assembles element matrix into global stiffness matrix
3. `*_elementforce` - calculates element nodal forces

Angles are always in degrees (converted internally to radians).

## Dependencies

- ModelingToolkit v10.2.0