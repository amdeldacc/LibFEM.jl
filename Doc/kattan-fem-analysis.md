# Extraction Report — MATLAB Guide to Finite Elements (2nd Ed.)

**Author**: Peter I. Kattan | **Pages**: ~433 | **Chapters**: 17 | **Year**: 2007 (Springer)

## Author's Core Framework: The 6-Step FEM Method

Kattan's central contribution is a **systematic, repeatable 6-step procedure** applied uniformly across every element type in the book. This is the unifying methodology:

1. **Discretize the domain** — subdivide into elements and nodes (manual)
2. **Write element stiffness matrices** — per-element equations via MATLAB
3. **Assemble global stiffness matrix** — direct stiffness approach via MATLAB
4. **Apply boundary conditions** — supports, loads, displacements (manual)
5. **Solve equations** — partition stiffness matrix (manual) + Gaussian elimination (MATLAB)
6. **Post-process** — reactions, element forces/stresses via MATLAB

Each chapter follows this identical scaffolding, varying only the element-specific equations.

---

## Key Principles

- **One element type per chapter** — each chapter teaches exactly one element type, from simple (1D spring) to complex (3D brick, fluid flow)
- **Interactive learning** — no black-box programs; every example is solved step-by-step in an interactive MATLAB session so the student sees intermediate matrices
- **Exact integration over numerical** — uses MATLAB Symbolic Math Toolbox for analytical integration (Ch12–14, 16), bypassing numerical quadrature for educational clarity
- **Consistent MATLAB API pattern** — every element type provides 3–4 functions with a predictable naming convention: `{ElementName}{Operation}` (e.g., `SpringElementStiffness`, `SpringAssemble`, `SpringElementForces`)

---

## Techniques & Methods

- **Direct stiffness assembly** — global stiffness matrix built by adding element matrices at DOF indices using the superposition principle
- **Partitioning method for BCs** — global equations partitioned into known/unknown DOFs before solving (manual step, then MATLAB solves)
- **MATLAB-as-calculator** — used for matrix inversion, multiplication, equation solving, not as a black-box FEA package
- **Symbolic integration** — uses MATLAB's Symbolic Math Toolbox for analytical integration of shape functions, avoiding numerical quadrature in elasticity elements

---

## Anti-patterns (What the Book Avoids / Warns Against)

- ❌ **Numerical integration for teaching** — avoided in favor of exact symbolic integration; numerical quadrature is production-grade but hides what's happening analytically
- ❌ **Black-box programs** — the book never provides a single monolithic FEM solver; every function is a single small operation the student can inspect
- ❌ **Blind trust in output** — by partitioning manually and inspecting intermediate matrices, the student must understand every step

---

## Suggested Skill Name

`kattan-fem` — covering the complete FEM methodology from the Kattan textbook

---

## Chapters Detected

| # | Title | Key Topics |
|---|-------|------------|
| 1 | Introduction | 6-step FEM method, MATLAB tutorial, 84 M-file listing |
| 2 | The Spring Element | 1D spring stiffness (k), 2-node assembly, nodal forces |
| 3 | The Linear Bar Element | E, A, L parameters, axial stiffness (EA/L) |
| 4 | The Quadratic Bar Element | 3-node bar, quadratic shape functions, 3×3 stiffness |
| 5 | The Plane Truss Element | 2D truss, rotation matrix, 4×4 stiffness (theta) |
| 6 | The Space Truss Element | 3D truss, directional cosines, 6×6 stiffness |
| 7 | The Beam Element | Pure beam bending (EI/L), 4×4 stiffness, shear/moment diagrams |
| 8 | The Plane Frame Element | 2D frame (axial + bending), 6×6 stiffness, 3 DOF/node |
| 9 | The Grid Element | 2D grid bending, 3 DOF/node, torsional + bending |
| 10 | The Space Frame Element | 3D frame, 12×12 stiffness, 6 DOF/node, torsion |
| 11 | The Linear Triangular Element | 2D CST (constant strain triangle), plane stress/strain |
| 12 | The Quadratic Triangular Element | 6-node triangle, quadratic shape functions, symbolic integration |
| 13 | The Bilinear Quadrilateral Element | 4-node quad, isoparametric formulation, symbolic integration |
| 14 | The Quadratic Quadrilateral Element | 8/9-node quad, higher-order shape functions |
| 15 | The Linear Tetrahedral Element | 3D solid tetrahedron, 4-node, volume coordinates |
| 16 | The Linear Brick Element | 8-node hexahedral brick, 3D solid, symbolic integration |
| 17 | Other Elements | Fluid flow 1D, heat transfer, geotechnical, EM, structural dynamics |

---

## LibFEM.jl Mapping Note

LibFEM.jl implements Kattan's MATLAB functions in Julia for element types **Ch2–Ch8** and **Ch10** (springs, trusses, beams, plane frames, space frames, quadratic bar). LibFEM does **not** yet cover Ch9 (grid), Ch11–16 (2D/3D continuum elements: triangles, quadrilaterals, tetrahedra, bricks), or Ch17 (fluid flow/other physics). The Julia naming convention `d{N}_{domain}_{operation}` maps directly from Kattan's `{Domain}{Operation}` — e.g., `SpringElementStiffness` → `d1_spring_elementstiffness`, `SpaceFrameElementForces` → `d3_spaceframe_elementforces`.

---

*Generated by book-to-skill analysis mode on 2026-07-28.*
