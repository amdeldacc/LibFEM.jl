# Graph Report - .  (2026-07-15)

## Corpus Check
- 146 files · ~223,244 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 144 nodes · 211 edges · 11 communities (9 shown, 2 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Kattan FEM Theory and Element Types
- Project Conventions and Plans
- 1D/2D Assembly and Diagram Functions
- 2D/3D Element Computations
- ModelingToolkit Truss Demo v2
- Generic _assemble! Family
- ModelingToolkit Truss Demo v1
- Core FEM Theory
- Test Suite and Module Root
- OpenWiki Documentation System

## God Nodes (most connected - your core abstractions)
1. `LibFEM` - 37 edges
2. `MATLAB Guide to Finite Elements (2nd Edition, 2007)` - 25 edges
3. `Three-Function Element Design Pattern` - 16 edges
4. `deg2rad()` - 15 edges
5. `LibFEM.jl` - 15 edges
6. `MATLAB Guide to Finite Elements — An Interactive Approach (Kattan 2007)` - 10 edges
7. `_assemble!()` - 8 edges
8. `Plane Frame Element (2D, Axial+Bending)` - 7 edges
9. `MATLAB to Julia Name Mapping Convention` - 6 edges
10. `Plane Truss Element (2D, 2-Node)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `d2_beam 3 DOF per Node Indexing Scheme` --conceptually_related_to--> `LibFEM.jl`  [INFERRED]
  openwiki/architecture/overview.md → README.md
- `Julia-Only FEM Extensions (No MATLAB Counterpart)` --conceptually_related_to--> `MATLAB Guide to Finite Elements — An Interactive Approach (Kattan 2007)`  [INFERRED]
  .omo/plans/matlab-comparison.md → README.md
- `Doc/ Directory Read-Only Constraint` --conceptually_related_to--> `MATLAB Guide to Finite Elements — An Interactive Approach (Kattan 2007)`  [INFERRED]
  AGENTS.md → README.md
- `d{N}_{domain}_{operation} Naming Convention` --conceptually_related_to--> `MATLAB to Julia Name Mapping Convention`  [INFERRED]
  openwiki/architecture/overview.md → AGENTS.md
- `Julia-Only FEM Extensions (No MATLAB Counterpart)` --conceptually_related_to--> `LibFEM.jl`  [EXTRACTED]
  .omo/plans/matlab-comparison.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Core Library Architecture** — readme_libfem_jl, agents_single_source_file, agents_3_function_pattern, agents_dimension_prefix, agents_angle_convention_degrees, openwiki_architecture_overview_module_structure, openwiki_architecture_overview_naming_convention [INFERRED 0.95]
- **MATLAB Verification Pipeline** — agents_matlab_mapping_convention, _omo_plans_matlab_comparison_comparison_tests, _omo_drafts_matlab_comparison_beam_planeframe_distinction, openwiki_reference_kattan_mapping_full_mapping, openwiki_architecture_overview_test_suite, context_domain_glossary [INFERRED 0.85]
- **Known Technical Debt** — agents_unused_modelingtoolkit, agents_missing_plots_dependency, todo_known_issues, todo_missing_features [INFERRED 0.95]
- **Kattan Book Element Family** — doc_spring_element, doc_linear_bar_element, doc_quadratic_bar_element, doc_plane_truss_element, doc_space_truss_element, doc_beam_element, doc_plane_frame_element, doc_grid_element, doc_space_frame_element, doc_linear_triangular_cst_element, doc_quadratic_triangular_lst_element, doc_bilinear_quadrilateral_q4_element, doc_quadratic_quadrilateral_q8q9_element, doc_linear_tetrahedral_element, doc_linear_brick_hexahedron_element, doc_fluid_flow_1d_element [EXTRACTED 1.00]
- **FEM Procedure Workflow** — doc_six_step_fem_procedure, doc_direct_stiffness_approach, doc_core_matrix_equation, doc_gaussian_elimination_solver, doc_element_force_equation [EXTRACTED 1.00]
- **1D Element Family** — doc_spring_element, doc_linear_bar_element, doc_quadratic_bar_element [EXTRACTED 1.00]
- **2D Element Family** — doc_plane_truss_element, doc_beam_element, doc_plane_frame_element, doc_grid_element, doc_linear_triangular_cst_element, doc_quadratic_triangular_lst_element, doc_bilinear_quadrilateral_q4_element, doc_quadratic_quadrilateral_q8q9_element [EXTRACTED 1.00]
- **3D Element Family** — doc_space_truss_element, doc_space_frame_element, doc_linear_tetrahedral_element, doc_linear_brick_hexahedron_element [EXTRACTED 1.00]
- **Continuum (Elasticity) Element Family** — doc_linear_triangular_cst_element, doc_quadratic_triangular_lst_element, doc_bilinear_quadrilateral_q4_element, doc_quadratic_quadrilateral_q8q9_element, doc_linear_tetrahedral_element, doc_linear_brick_hexahedron_element [EXTRACTED 1.00]
- **Elements with Diagram Functions** — doc_beam_element, doc_plane_frame_element, doc_space_frame_element [EXTRACTED 1.00]
- **Elements with Principal Stress Functions** — doc_linear_triangular_cst_element, doc_quadratic_triangular_lst_element, doc_bilinear_quadrilateral_q4_element, doc_quadratic_quadrilateral_q8q9_element, doc_linear_tetrahedral_element, doc_linear_brick_hexahedron_element [EXTRACTED 1.00]

## Communities (11 total, 2 thin omitted)

### Community 0 - "Kattan FEM Theory and Element Types"
Cohesion: 0.15
Nodes (30): Analytical Integration over Numerical Integration, Beam Element (2D, Euler-Bernoulli), Bilinear Quadrilateral Q4 Element (2D, 4-Node), Diagram Functions for Beam/Frame (Shear, Moment, Axial, Torsion), Element Progression by Dimensionality, Fluid Flow 1D Element (Seepage/Flow), Frame Element as Truss+Beam Superposition, Grid Element (2D, Bending+Torsion) (+22 more)

### Community 1 - "Project Conventions and Plans"
Cohesion: 0.11
Nodes (28): CI Pipeline (GitHub Actions, Julia 1.10+), MATLAB Beam vs PlaneFrame Critical Distinction, MATLAB Comparison Tests (test/comparison.jl), Julia-Only FEM Extensions (No MATLAB Counterpart), AGENTS.md/CONTEXT.md Documentation Update (Completed), 3-Function Extension Pattern, Angle Convention (Degrees Internally Converted to Radians), Dimension Prefix Convention (d1_, d2_, d3_) (+20 more)

### Community 4 - "2D/3D Element Computations"
Cohesion: 0.13
Nodes (15): d2_beam_elementforce(), d2_beam_elementstiffness(), d2_spring_elementforce(), d2_spring_elementstiffness(), d2_truss_elementforce(), d2_truss_elementstiffness(), d2_truss_elementstrain(), d2_truss_elementstress() (+7 more)

### Community 5 - "ModelingToolkit Truss Demo v2"
Cohesion: 0.28
Nodes (5): LinearAlgebra, Plots, truss_force(), truss_strain(), truss_stress()

### Community 6 - "Generic _assemble! Family"
Cohesion: 0.25
Nodes (8): _assemble!(), d1_spring_assemble(), d1_truss_assemble(), d2_beam_assemble(), d2_spring_assemble(), d2_truss_assemble(), d3_spring_assemble(), d3_truss_assemble()

### Community 8 - "Core FEM Theory"
Cohesion: 0.50
Nodes (5): Core Matrix Equation [K]{U}={F}, Direct Stiffness Approach, Element Force Equation {f}=[k]{u}, Gaussian Elimination Solver (MATLAB Backslash), Six-Step FEM Procedure

### Community 9 - "Test Suite and Module Root"
Cohesion: 0.50
Nodes (3): LibFEM, Test, Plots

### Community 10 - "OpenWiki Documentation System"
Cohesion: 0.67
Nodes (3): OpenWiki Auto-Update GitHub Action, OpenWiki Documentation System, Repository Directory Structure

## Knowledge Gaps
- **18 isolated node(s):** `ModelingToolkit`, `LinearAlgebra`, `LinearAlgebra`, `Plots`, `Plots` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `LibFEM` connect `1D/2D Assembly and Diagram Functions` to `2D/3D Element Computations`, `Generic _assemble! Family`?**
  _High betweenness centrality (0.058) - this node is a cross-community bridge._
- **Why does `MATLAB Guide to Finite Elements (2nd Edition, 2007)` connect `Kattan FEM Theory and Element Types` to `Core FEM Theory`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **What connects `ModelingToolkit`, `LinearAlgebra`, `LinearAlgebra` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project Conventions and Plans` be split into smaller, more focused modules?**
  _Cohesion score 0.10846560846560846 - nodes in this community are weakly interconnected._
- **Should `MATLAB Reference Test Functions` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `1D/2D Assembly and Diagram Functions` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should `2D/3D Element Computations` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._