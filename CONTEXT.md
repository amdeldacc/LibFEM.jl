# LibFEM.jl Domain Glossary

This file defines the domain model: element types, dimensionality, and the mapping from Kattan MATLAB reference files to LibFEM.jl Julia function names.

## Element Types

### Spring (1D, 2D, 3D)
- **MATLAB prefix**: `Spring*` (e.g., `SpringElementStiffness.m`, `SpringAssemble.m`, `SpringElementForces.m`)
- **LibFEM prefix**: `d1_spring_*` (1D), `d2_spring_*` (2D), `d3_spring_*` (3D)
- **Functions**: `*_elementstiffness(k)`, `*_assemble(K, k, i, j)`, `*_elementforce(k, u)`
- **2D/3D variants**: Add angle parameters (`theta` for 2D, `thetax, thetay, thetaz` for 3D).

### Truss (1D Linear Bar, 2D Plane Truss, 3D Space Truss)
- **MATLAB prefix**: `LinearBar*` (1D), `PlaneTruss*` (2D), `SpaceTruss*` (3D)
- **LibFEM prefix**: `d1_truss_*` (1D), `d2_truss_*` (2D), `d3_truss_*` (3D)
- **Functions**: `*_elementstiffness(E, A, L, ...)`, `*_assemble(K, k, i, j)`, `*_elementforce(E, A, L, ... , u)`, `*_elementstress(...)`, `*_elementstrain(...)`, `*_elementlength(coords...)`
- **Key mapping**: MATLAB `LinearBarElementStiffness.m` → `d1_truss_elementstiffness`. `PlaneTrussElementForce.m` → `d2_truss_elementforce`. `SpaceTrussElementStress.m` → `d3_truss_elementstress`.

### Beam (2D Plane Beam)
- **MATLAB prefix**: `Beam*` (2D beam), `PlaneFrame*` (plane frame — extended beam)
- **LibFEM prefix**: `d2_beam_*`
- **Functions**: `*_elementstiffness(E, A, I, L, theta)`, `*_assemble(K, k, i, j)`, `*_elementforce(E, A, I, L, theta, u)`, `*_elementlength(x1, y1, x2, y2)`, `*_elementaxialdiagram(f, L)`, `*_elementmomentdiagram(f, L)`, `*_elementsheardiagram(f, L)`
- **Key mapping**: MATLAB `BeamElementStiffness.m` → `d2_beam_elementstiffness`. MATLAB `PlaneFrameElementForces.m` → similar pattern.

## Dimension System

| Prefix | Dimensions | MATLAB Domain | LibFEM Domain |
|--------|-----------|---------------|---------------|
| `d1_` | 1D (x) | LinearBar, 1D Spring | Truss, Spring |
| `d2_` | 2D (x, y) | PlaneTruss, PlaneFrame, Beam, 2D Spring | Truss, Beam, Spring |
| `d3_` | 3D (x, y, z) | SpaceTruss, SpaceFrame, 3D Spring | Truss, Spring |

## Function Pattern

Every element type follows a 3-function pattern:
1. `*_elementstiffness(...)` — returns the element stiffness matrix
2. `*_assemble(K, k, i, j)` — assembles element into global stiffness matrix
3. One of: `*_elementforce(...)`, `*_elementstress(...)`, `*_elementstrain(...)` — computes forces/stresses/strains

Additional helper functions may exist: `*_elementlength(...)`, `*_elementaxialdiagram(...)`, etc.

## MATLAB File Reference

All MATLAB reference files are in `Doc/Kattan/M-Files/`. These are read-only and provided for algorithm verification. The mapping convention is:

MATLAB `{Domain}{Operation}.m` → Julia `d{N}_{domain}_{operation}`

where `{N}` is the dimensionality (1, 2, or 3), `{domain}` is lowercase (spring, truss, beam), and `{operation}` is the function name.
