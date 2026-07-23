---
type: Reference
title: "Kattan MATLAB Mapping"
description: "Mapping between MATLAB reference implementation and LibFEM.jl Julia API for FEM elements - springs, trusses, beams in 1D, 2D, and 3D"
tags: ["reference", "matlab", "kattan", "mapping", "fem"]
resource: "/home/piou/LibFEM.jl/Doc/Kattan/M-Files"
---

# Kattan MATLAB Mapping

This page documents the relationship between the MATLAB reference implementation in `Doc/Kattan/M-Files/` and the LibFEM.jl Julia API.

## Book Reference

The MATLAB files are companion code for:

> **"MATLAB Guide to Finite Elements — An Interactive Approach"**  
> Peter I. Kattan, Springer, 2007

The book PDF resides at `Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.pdf` with Markdown and plain-text transcriptions also available.

## MATLAB → Julia Naming Convention

```
MATLAB:  {Domain}{Operation}.m    (PascalCase, no underscore)
Julia:   d{N}_{domain}_{operation} (snake_case, dimension prefix)
```

Where `{N}` encodes dimensionality:
- `1` — 1D linear elements (scalar DOF)
- `2` — 2D plane elements (2 DOF for spring/truss, 3 for beam)
- `3` — 3D space elements (3 DOF for spring/truss; **6** for beam)

## Implemented Element Mapping

These are the MATLAB files whose algorithms are implemented (or planned) in `src/LibFEM.jl`:

### Spring Element

| MATLAB File | Julia Function | Status |
|------------|---------------|--------|
| `SpringElementStiffness.m` | `d1_spring_elementstiffness` | Implemented |
| `SpringAssemble.m` | `d1_spring_assemble` | Implemented |
| `SpringElementForces.m` | `d1_spring_elementforce` | Implemented |

2D and 3D spring implementations (`d2_spring_*`, `d3_spring_*`) are LibFEM extensions — Kattan only provides the 1D spring directly, though the 2D/3D formulations follow the same principles.

### Truss / Bar Elements

| MATLAB File | Julia Function | Status |
|------------|---------------|--------|
| `LinearBarElementStiffness.m` | `d1_truss_elementstiffness` | Implemented |
| `LinearBarAssemble.m` | `d1_truss_assemble` | Implemented |
| `LinearBarElementForces.m` | `d1_truss_elementforces` | Implemented |
| `LinearBarElementStresses.m` | `d1_truss_elementstress` | Implemented |
| `PlaneTrussElementStiffness.m` | `d2_truss_elementstiffness` | Implemented |
| `PlaneTrussAssemble.m` | `d2_truss_assemble` | Implemented |
| `PlaneTrussElementForce.m` | `d2_truss_elementforces` | Implemented |
| `PlaneTrussElementStress.m` | `d2_truss_elementstress` | Implemented |
| `PlaneTrussElementLength.m` | `d2_truss_elementlength` | Implemented |
| `PlaneTrussInclinedSupport.m` | — | Not implemented |
| `SpaceTrussElementStiffness.m` | `d3_truss_elementstiffness` | Implemented |
| `SpaceTrussAssemble.m` | `d3_truss_assemble` | Implemented |
| `SpaceTrussElementForce.m` | `d3_truss_elementforces` | Implemented |
| `SpaceTrussElementStress.m` | `d3_truss_elementstress` | Implemented |
| `SpaceTrussElementLength.m` | `d3_truss_elementlength` | Implemented |
| `SpaceTrussInclinedSupport.m` | — | Not implemented |

LibFEM adds `d1_truss_elementstrain`, `d2_truss_elementstrain`, and `d3_truss_elementstrain` — strain calculations not present as standalone MATLAB files.

### Beam (Pure Bending) Elements

| MATLAB File | Julia Function | Status |
|------------|---------------|--------|
| `BeamElementStiffness.m` | `d2_beam_elementstiffness` (pure beam, 4×4, `E, I, L`) | Implemented |
| `BeamAssemble.m` | `d2_beam_assemble` (2 DOF/node) | Implemented |
| `BeamElementForces.m` | `d2_beam_elementforces` (4-element vector) | Implemented |
| `BeamElementMomentDiagram.m` | `d2_beam_elementmomentdiagram` | Implemented |
| `BeamElementShearDiagram.m` | `d2_beam_elementsheardiagram` | Implemented |

### Plane Frame Elements

| MATLAB File | Julia Function | Status |
|------------|---------------|--------|
| `PlaneFrameElementStiffness.m` | `d2_planeframe_elementstiffness` (6×6, `E, A, I, L, theta`) | Implemented |
| `PlaneFrameAssemble.m` | `d2_planeframe_assemble` (3 DOF/node) | Implemented |
| `PlaneFrameElementForces.m` | `d2_planeframe_elementforces` (6-element vector) | Implemented |
| `PlaneFrameElementLength.m` | `d2_planeframe_elementlength` | Implemented |
| `PlaneFrameElementAxialDiagram.m` | `d2_planeframe_elementaxialdiagram` | Implemented |
| `PlaneFrameElementMomentDiagram.m` | `d2_planeframe_elementmomentdiagram` | Implemented |
| `PlaneFrameElementShearDiagram.m` | `d2_planeframe_elementsheardiagram` | Implemented |
| `PlaneFrameInclinedSupport.m` | — | Not implemented |

**Note**: Kattan separates `Beam*` (simple beam, bending only) and `PlaneFrame*` (plane frame with axial effects). LibFEM now reflects this distinction: `d2_beam_*` implements the pure Euler-Bernoulli beam (4×4, 2 DOF/node), while `d2_planeframe_*` implements the plane frame (6×6, 3 DOF/node) with axial + bending.

### Space Frame Elements

| MATLAB File | Julia Function | Status |
|------------|---------------|--------|
| `SpaceFrameElementStiffness.m` | `d3_beam_elementstiffness` | Implemented |
| `SpaceFrameAssemble.m` | `d3_beam_assemble` | Implemented |
| `SpaceFrameElementForces.m` | `d3_beam_elementforces` | Implemented |
| `SpaceFrameElementLength.m` | `d3_beam_elementlength` | Implemented |
| `SpaceFrameElementAxialDiagram.m` | `d3_beam_elementaxialdiagram` | Implemented |
| `SpaceFrameElementMomentYDiagram.m` | `d3_beam_elementmomentydiagram` | Implemented |
| `SpaceFrameElementMomentZDiagram.m` | `d3_beam_elementmomentzdiagram` | Implemented |
| `SpaceFrameElementShearYDiagram.m` | `d3_beam_elementshearydiagram` | Implemented |
| `SpaceFrameElementShearZDiagram.m` | `d3_beam_elementshearzdiagram` | Implemented |
| `SpaceFrameElementTorsionDiagram.m` | `d3_beam_elementtorsiondiagram` | Implemented |

Space frame (3D beam) is the most complex structural element — it carries 6 DOF per node (3 translations + 3 rotations) with a 12×12 stiffness matrix and a rotation matrix `Λ` built from node coordinates (no angle parameters). The Julia implementation in `d3_beam_*` uses a private `_d3_beam_kprime` helper for the local stiffness matrix and a rotation matrix `R` that handles the vertical-element degenerate case automatically via `Λ` (3×3 direction cosines).

### Other MATLAB Files (Not Yet Implemented)

Kattan covers additional element types beyond springs/trusses/beams. These MATLAB files exist in `Doc/Kattan/M-Files/` but are not yet implemented in LibFEM.jl:

| Category | MATLAB Files |
|----------|-------------|
| **Linear Triangle (CST)** | `LinearTriangleAssemble.m`, `LinearTriangleElementStiffness.m`, `LinearTriangleElementStresses.m`, `LinearTriangleElementPStresses.m`, `LinearTriangleElementArea.m` |
| **Bilinear Quad (Q4)** | `BilinearQuadAssemble.m`, `BilinearQuadElementStiffness.m`, `BilinearQuadElementStiffness2.m`, `BilinearQuadElementStresses.m`, `BilinearQuadElementPStresses.m`, `BilinearQuadElementArea.m` |
| **Quadratic Bar** | `QuadraticBarAssemble.m`, `QuadraticBarElementStiffness.m`, `QuadraticBarElementForces.m`, `QuadraticBarElementStresses.m` |
| **Quadratic Triangle (T6)** | `QuadTriangleAssemble.m`, `QuadTriangleElementStiffness.m`, `QuadTriangleElementStresses.m`, `QuadTriangleElementPStresses.m`, `QuadTriangleElementArea.m` |
| **Quadratic Quad (Q8)** | `QuadraticQuadAssemble.m`, `QuadraticQuadElementStiffness.m`, `QuadraticQuadElementStresses.m`, `QuadraticQuadElementPStresses.m`, `QuadraticQuadElementArea.m` |
| **Linear Brick (B8)** | `LinearBrickAssemble.m`, `LinearBrickElementStiffness.m`, `LinearBrickElementStresses.m`, `LinearBrickElementPStresses.m`, `LinearBrickElementVolume.m` |
| **Tetrahedron (T4)** | `TetrahedronAssemble.m`, `TetrahedronElementStiffness.m`, `TetrahedronElementStresses.m`, `TetrahedronElementPStresses.m`, `TetrahedronElementVolume.m` |
| **Grid** | `GridAssemble.m`, `GridElementStiffness.m`, `GridElementForces.m`, `GridElementLength.m` |
| **1D Fluid Flow** | `FluidFlow1DAssemble.m`, `FluidFlow1DElementStiffness.m`, `FluidFlow1DElementVFR.m`, `FluidFlow1DElementVelocities.m` |

These represent 2D/3D continuum elements (plane stress/strain, solid mechanics), grid structures, and fluid flow — natural extension areas for the library.

## Verification: `test/comparison.jl`

The file `test/comparison.jl` contains Julia transcriptions of selected MATLAB functions using the original PascalCase naming. This enables side-by-side verification that the Julia implementations produce identical results. Transcribed functions include:

- `SpringElementStiffness`, `SpringElementForces`, `SpringAssemble`
- `LinearBarElementStiffness`, `LinearBarElementForces`, `LinearBarElementStresses`, `LinearBarAssemble`
- `PlaneTrussElementLength`, `PlaneTrussElementStiffness`, `PlaneTrussElementForce`, `PlaneTrussElementStress`, `PlaneTrussAssemble`
- `PlaneFrameElementLength`, `PlaneFrameElementStiffness`, `PlaneFrameElementForces`, `PlaneFrameAssemble` (and diagram functions)

Note: these transcriptions use MATLAB-style explicit index assignment (16 lines per 4×4 assemble) rather than the refactored `_assemble!` helper — they serve as algorithmic ground truth, not as reusable code.

## Doc/ Directory Structure

```
Doc/
├── Kattan/
│   ├── Kattan_CD.doc               # Book companion CD contents
│   ├── M-Files/                    # 80 MATLAB function files (read-only)
│   │   ├── Spring*.m               # 3 files
│   │   ├── LinearBar*.m            # 4 files
│   │   ├── PlaneTruss*.m           # 6 files
│   │   ├── SpaceTruss*.m           # 6 files
│   │   ├── Beam*.m                 # 5 files
│   │   ├── PlaneFrame*.m           # 8 files
│   │   ├── SpaceFrame*.m           # 10 files
│   │   ├── LinearTriangle*.m       # 5 files
│   │   ├── BilinearQuad*.m         # 6 files
│   │   ├── QuadraticBar*.m         # 4 files
│   │   ├── QuadTriangle*.m         # 5 files
│   │   ├── QuadraticQuad*.m        # 5 files
│   │   ├── LinearBrick*.m          # 5 files
│   │   ├── Tetrahedron*.m          # 5 files
│   │   ├── Grid*.m                 # 4 files
│   │   └── FluidFlow1D*.m          # 4 files
│   └── Solutions-Manual/          # .rtf and .doc solutions +
│                                 # per-problem MATLAB scripts
│                                 # (problem_2_1.m … problem_8_3.m,
│                                 #  ocr_m_verify.m)
└── Peter_Kattan_*                  # Book PDF and transcriptions
```

**Important**: The `Doc/Kattan/M-Files/` directory is designated **read-only** (per `AGENTS.md`). These files are reference material — do not modify them.