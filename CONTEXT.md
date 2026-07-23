# LibFEM.jl Domain Glossary

This file defines the domain model: element types, dimensionality, and the mapping from Kattan MATLAB reference files to LibFEM.jl Julia function names.

## Design Decisions

### Library Scope (2026-07): Educational-First → Lightweight FEM Toolkit

LibFEM.jl is educational-first but targeted to grow into a lightweight FEM toolkit suitable for real analysis. This means:
- Textbook-correct implementations remain the core (verified against Kattan MATLAB via Octave CI)
- But abstractions (type dispatch, assembly helpers, benchmarks) are not over-engineered; they serve real use
- Future features should balance teaching clarity with practical utility

### Remove `A ≤ 0` Exception, Validate `A > 0` Everywhere (2026-07)

Negative cross-sectional area creates unphysical stiffness matrices (negative `EA/L`) and does not model tension-only behavior — that requires geometric nonlinearity. The `A > 0` precondition will be enforced in all truss and frame element functions, consistent with the `L > 0` validation already in place. For parametric studies near zero area, use `A → 0⁺`.

### Verification Strategy (2026-07): Two-Layer Verification

The verification stack has 2 layers:
- **Unit tests** (`runtests.jl`) — primary, per-element correctness
- **Octave validation** (`validate_matlab.jl`) — ground truth against actual Kattan `.m` files

The hand-transcribed MATLAB layer (`comparison.jl`) has been removed due to transcription bugs, overlap with Octave validation, and maintenance burden.

### Element Roadmap (2026-07): Current Set Complete, Extensible Later

The current 8 element types (d1/d2/d3 spring, d1/d2/d3 truss, d2_beam, d2_planeframe, d3_spaceframe) are the complete set for now. The architecture is designed for extension (add `src/<family>.jl` + `include` line) but no new element families are actively planned. Future candidates: quadrilateral, triangular, axisymmetric, thermal, plate/shell elements.

### Thin Solver Helpers Planned (2026-07)

LibFEM will add utility helpers (e.g., `apply_bc!`, `solve`) to reduce boilerplate. These will be thin wrappers around standard Julia (`K \ F`) — no full `FEModel` abstraction. Not yet implemented.

### Plots.jl → Weak Dependency via Julia Extensions (2026-07)

Diagram functions (in `src/plot.jl`) will move to a Julia package extension. Plots.jl becomes a `[weakdeps]` entry; when both LibFEM and Plots are loaded, the diagram functions auto-activate. Core math (stiffness, assembly, forces) works without Plots. This is the planned approach — not yet implemented.

### Spring Elements Must Not Use Truss Helpers (2026-07)

`d2_spring_elementforce` and `d3_spring_elementforce` currently call `_truss_force_component` from `utils.jl`. This is a conceptual leak — springs are not trusses. The spring force functions should get their own projection logic (semantic decoupling), and the `_truss_force_component` helper should become truss-only. Not high priority, but noted as technical debt.

### Type Hierarchy Is Active (2026-07)

The abstract type hierarchy (`AbstractElement{NDIM}`, `AbstractSpring{NDIM}`, `AbstractTruss{NDIM}`, `AbstractBeam{NDIM}`) and `@kwdef` concrete structs (`Spring{NDIM}`, `Truss{NDIM}`, `Beam{NDIM}`) are **not** decorative — they are awaiting a refactor where element functions will dispatch on these types. The deprecation notice in `types.jl` is outdated. The structs are the intended future dispatch mechanism, not candidates for removal.

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

### Beam (2D Pure Beam, Bending Only)
- **MATLAB prefix**: `Beam*` (pure beam — bending only, no axial DOF)
- **LibFEM prefix**: `d2_beam_*` (2D)
- **Functions**: `*_elementstiffness(E, I, L)`, `*_assemble(K, k, i, j)`, `*_elementforces(k, u)`, `*_elementsheardiagram(f, L)`, `*_elementmomentdiagram(f, L)`
- **DOFs**: 2 DOF/node (v, θ), 4×4 stiffness. **Inextensible** — no axial deformation.
- **Key mapping**: MATLAB `BeamElementStiffness.m` → `d2_beam_elementstiffness`. MATLAB `BeamElementForces.m` → `d2_beam_elementforces`.

### Plane Frame (2D) / Space Frame (3D)
- **MATLAB prefix**: `PlaneFrame*` (2D), `SpaceFrame*` (3D)
- **LibFEM prefix**: `d2_planeframe_*` (2D), `d3_spaceframe_*` (3D, renamed from legacy `d3_spaceframe_*`)
- **Functions (2D)**: `*_elementstiffness(E, A, I, L, theta)`, `*_assemble(K, k, i, j)`, `*_elementforces(E, A, I, L, theta, u)`, `*_elementlength(x1, y1, x2, y2)`, `*_elementaxialdiagram(f, L)`, `*_elementmomentdiagram(f, L)`, `*_elementsheardiagram(f, L)`
- **Functions (3D)**: `*_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)`, `*_assemble(K, k, i, j)`, `*_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)`, `*_elementlength(x1, y1, z1, x2, y2, z2)`, plus 6 diagram functions (axial, shearY, shearZ, momentY, momentZ, torsion)
- **DOFs**: 2D uses 3 DOF/node (6×6 stiffness). 3D uses **6 DOF/node** (12×12 stiffness — 3 translations + 3 rotations per node).
- **Key mapping**: MATLAB `PlaneFrameElementStiffness.m` → `d2_planeframe_elementstiffness`. MATLAB `SpaceFrameElementStiffness.m` → `d3_spaceframe_elementstiffness` (renamed from legacy `d3_beam_*`). MATLAB `PlaneFrameElementForces.m` → `d2_planeframe_elementforces`.

### Naming Decision (2026-07): `d3_beam_*` → `d3_spaceframe_*` (Completed)

`d3_beam_*` implemented a space frame (6 DOF/node, axial + bending + torsion) but was misnamed after the 2D pure beam. It has been renamed to `d3_spaceframe_*` to match MATLAB's `SpaceFrame*` and be consistent with `d2_planeframe_*`. This touched 27 files across source, tests, docs, and scripts.

## Dimension System

| Prefix | Dimensions | MATLAB Domain | LibFEM Domain |
|--------|-----------|---------------|---------------|
| `d1_` | 1D (x) | LinearBar, 1D Spring | Truss, Spring |
| `d2_` | 2D (x, y) | PlaneTruss, PlaneFrame, Beam, 2D Spring | Truss, Beam, Spring |
| `d3_` | 3D (x, y, z) | SpaceTruss, SpaceFrame, 3D Spring | Truss, Beam, Spring |

## Function Pattern

Every element type follows a 3-function pattern:
1. `*_elementstiffness(...)` — returns the element stiffness matrix
2. `*_assemble(K, k, i, j)` — assembles element into global stiffness matrix
3. One of: `*_elementforce(...)`, `*_elementstress(...)`, `*_elementstrain(...)` — computes forces/stresses/strains

Additional helper functions may exist: `*_elementlength(...)`, `*_elementaxialdiagram(...)`, `*_elementshearydiagram(...)`, `*_elementshearzdiagram(...)`, `*_elementmomentydiagram(...)`, `*_elementmomentzdiagram(...)`, `*_elementtorsiondiagram(...)`, etc.

## MATLAB File Reference

All MATLAB reference files are in `Doc/Kattan/M-Files/`. These are read-only and provided for algorithm verification. The mapping convention is:

MATLAB `{Domain}{Operation}.m` → Julia `d{N}_{domain}_{operation}`

where `{N}` is the dimensionality (1, 2, or 3), `{domain}` is lowercase (spring, truss, beam), and `{operation}` is the function name.
