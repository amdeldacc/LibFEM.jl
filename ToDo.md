# LibFEM.jl - Corrections and Enhancements

## Critical Issues

### 1. Docstring Errors
- [ ] Line 105-107: `d1_truss_elementstrain` docstring says "stress vector" but should say "strain vector"
- [ ] Line 673: Docstring has extra "export" keyword: `function declaration: export d3_truss_elementstrain` should be `function declaration: d3_truss_elementstrain`

### 2. Export Formatting
- [ ] Line 319: Double space in `export  d2_spring_assemble` (should be single space)

### 3. Plotting Functions (Lines 166-258)
- [ ] `d2_beam_elementaxialdiagram`, `d2_beam_elementmomentdiagram`, `d2_beam_elementsheardiagram` use MATLAB syntax `'k'` for color - should use Julia syntax `:black` or `"black"`
- [ ] These functions call `plot()` and `title()` without importing Plots.jl - need `using Plots` or move to separate module/extension
- [ ] Commented-out `#hold on` is MATLAB syntax, not needed in Julia

## Code Quality

### 4. Naming Convention
- [ ] Line 367: `D2_TrussAssemble` in docstring uses PascalCase, but function name is `d2_truss_assemble` (snake_case) - docstring should match

### 5. Missing Dependencies
- [ ] Add Plots.jl as a dependency if plotting functions are kept, or make it an optional dependency
- [ ] Currently only ModelingToolkit is listed, but it's not actually used in the code

### 6. Unused Import
- [ ] `using ModelingToolkit` is declared in dependencies but never used in src/LibFEM.jl

## Missing Features

### 7. Test Suite
- [ ] Create `test/` directory with test files
- [ ] Add tests for all element stiffness matrix functions
- [ ] Add tests for assembly functions
- [ ] Add tests for force/stress/strain calculations
- [ ] Add Project.toml `[extras]` section for Test dependency

### 8. Boundary Conditions
- [ ] Add function to apply boundary conditions (zero displacement at fixed nodes)
- [ ] Add function to extract reduced system after applying BCs

### 9. Solver Functions
- [ ] Add function to solve global system K*U = F
- [ ] Add function to compute reactions at supports

### 10. Mesh/Model Helpers
- [ ] Add function to compute element angle from node coordinates
- [ ] Add helper to build global stiffness matrix from mesh definition

## Documentation

### 11. Incomplete Documentation
- [ ] Add usage examples to README.md
- [ ] Add mathematical formulas to docstrings
- [ ] Document coordinate system assumptions (which direction angles are measured from)

## Refactoring Opportunities

### 12. Assembly Functions
- [ ] All `*_assemble` functions have repetitive code - could use a helper function with DOF-per-node parameter

### 13. Angle Conversion
- [ ] Multiple functions repeat `theta * pi / 180` - create a helper `deg2rad(theta)` function

### 14. Matrix Construction
- [ ] Several stiffness matrices follow similar patterns - could use template functions with parameters

## Recommended Priority

1. **High**: Fix docstring errors (#1), remove unused dependency (#6), fix export spacing (#2)
2. **Medium**: Fix plotting functions (#3), add test suite (#7)
3. **Low**: Refactoring opportunities (#12-14), missing features (#8-10)