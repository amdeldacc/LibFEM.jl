# Graph Report - .  (2026-07-28)

## Corpus Check
- 207 files · ~281,332 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 493 nodes · 589 edges · 94 communities (31 shown, 63 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 25 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Problem Wrapper & Validation
- Caveman Compress Tool
- Octave Test Runner
- Caveman Compress Benchmarking
- MATLAB Validation Pipeline
- Domain Concepts & Design
- OpenCode Superpowers
- Graphify Knowledge Graph
- Enhancement Plans
- Beam/Frame Library
- MATLAB Adapter Tests
- ModelingToolkit Examples
- Kattan Book Reference
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 23
- Community 25
- Community 26
- Community 27
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93

## God Nodes (most connected - your core abstractions)
1. `ProblemWrapper` - 30 edges
2. `OctaveRunner` - 23 edges
3. `LibFEM.jl` - 18 edges
4. `run_julia_problem()` - 16 edges
5. `disable` - 15 edges
6. `validate()` - 14 edges
7. `compress_file()` - 12 edges
8. `MATLAB Guide to Finite Elements: An Interactive Approach (2nd ed., Springer 2007)` - 12 edges
9. `Graphify Pipeline` - 11 edges
10. `validate_problem()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `MATLAB Guide to Finite Elements: An Interactive Approach (2nd ed., Springer 2007)` --semantically_similar_to--> `MATLAB Guide to Finite Elements (PDF)`  [INFERRED] [semantically similar]
  Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.txt → Doc/Peter I. Kattan - MATLAB Guide to Finite Elements_ An Interactive Approach (2007, Springer).pdf
- `MATLAB-to-Julia Function Mapping` --semantically_similar_to--> `d{N}_{domain}_{operation} Naming Convention`  [INFERRED] [semantically similar]
  CONTEXT.md → README.md
- `RTK Token Compression Proxy` --conceptually_related_to--> `OpenCode NVIDIA NIM Workflow`  [INFERRED]
  .agents/rules/antigravity-rtk-rules.md → .github/workflows/opencode.yml
- `Doc/Peter_Kattan_MATLAB_Guide_to_FE_2007_Springer.md — Textbook Markdown Transcription` --references--> `MATLAB Guide to Finite Elements — 2nd Ed, Springer 2007`  [EXTRACTED]
  Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.md → Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.pdf
- `MATLAB Guide to Finite Elements — 2nd Ed, Springer 2007` --rationale_for--> `Kattan Basic Equations (Spring, Linear Bar, Beam, Plane Truss, Space Truss, Frame)`  [EXTRACTED]
  Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.pdf → Doc/Peter_Kattan_MATLAB_Guide_to_Finite_Elements_AnInteractiveApproach_2007_Springer.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Agent and AI Tooling Integration** — _agents_rules_antigravity_rtk_rules_rtk, _github_workflows_opencode_nvidia_nim, _github_workflows_ocr_review_action [INFERRED 0.75]
- **LibFEM Enhancement Sprint Plan** — _opencode_plans_libfem_enhancement_plan_sprint_0, _opencode_plans_libfem_enhancement_plan_sprint_1, _opencode_plans_libfem_enhancement_plan_sprint_2, _opencode_plans_libfem_enhancement_plan_sprint_3, _opencode_plans_libfem_enhancement_plan_sprint_4, _opencode_plans_libfem_enhancement_plan_parallelization_map, _opencode_plans_libfem_enhancement_plan_commit_strategy, _opencode_plans_libfem_enhancement_plan_verification_gates [EXTRACTED 1.00]
- **Graphify Full Pipeline** — graphify_ast_extraction, graphify_semantic_extraction, graphify_community_clustering, graphify_visualization [EXTRACTED 1.00]
- **TDD Core Concepts** — tdd_red_green_loop, tdd_seams, tdd_anti_patterns [EXTRACTED 1.00]
- **LibFEM.jl Element System** — readme_spring_element, readme_truss_element, readme_beam_element, readme_quadratic_bar_element, readme_plane_frame_element, readme_space_frame_element [EXTRACTED 1.00]
- **Enhancement Planning Chain** — docs_reviews_2026_07_25_code_review_review_2026_07_25, docs_reviews_2026_07_26_code_review_review_pr_110, docs_adr_enhancement_roadmap_enhancement_roadmap, docs_adr_2026_07_27_enhancement_execution_plan_execution_plan, docs_adr_2026_07_27_verified_enhancement_plan_verified_plan, docs_adr_hyperplan_bundle_hyperplan_bundle [EXTRACTED 1.00]
- **Three-Layer Verification Stack** — readme_three_layer_verification, github_workflows_ci_ci_pipeline, doc_peter_kattan_matlab_guide_to_finite_elements_aninteractiveapproach_2007_springer_matlab_guide_to_finite_elements [INFERRED 0.85]

## Communities (94 total, 63 thin omitted)

### Community 0 - "Problem Wrapper & Validation"
Cohesion: 0.10
Nodes (33): build_problem_wrapper(), _compute_errors(), _extract_last_json(), fmt_sci(), Float64, LibFEM, OctaveRunner, Printf (+25 more)

### Community 1 - "Caveman Compress Tool"
Cohesion: 0.12
Nodes (27): main(), print_usage(), backup_dir_for(), build_compress_prompt(), build_fix_prompt(), call_claude(), compress_file(), is_sensitive_path() (+19 more)

### Community 2 - "Octave Test Runner"
Cohesion: 0.14
Nodes (25): Bool, _build_script(), call_function(), detect_octave(), Base, Exception, Float64, String (+17 more)

### Community 3 - "Caveman Compress Benchmarking"
Cohesion: 0.16
Nodes (22): benchmark_pair(), count_tokens(), main(), print_table(), Path, count_bullets(), extract_code_blocks(), extract_headings() (+14 more)

### Community 4 - "MATLAB Validation Pipeline"
Cohesion: 0.16
Nodes (24): ProblemWrapper, compute_errors(), fmt_sci(), Float64, LibFEM, OctaveRunner, Printf, String (+16 more)

### Community 5 - "Domain Concepts & Design"
Cohesion: 0.17
Nodes (23): A > 0 Validation Everywhere, Educational-First Design Philosophy, MATLAB-to-Julia Function Mapping, Plots.jl Weak Dependency via Julia Extensions, Abstract Type Hierarchy (Documentation Scaffolding), MATLAB Guide to Finite Elements (PDF), MATLAB Finite Element Toolbox (84 M-files), MATLAB Guide to Finite Elements: An Interactive Approach (2nd ed., Springer 2007) (+15 more)

### Community 6 - "OpenCode Superpowers"
Cohesion: 0.10
Nodes (19): plugin, $schema, skills, disable, brainstorming, executing-plans, finishing-a-development-branch, note-taking (+11 more)

### Community 8 - "Graphify Knowledge Graph"
Cohesion: 0.21
Nodes (16): AST Extraction, Community Clustering, Graphify Confidence Score Rubric, Graphify Node ID Format, Graphify Pipeline, Semantic Extraction, Graph Visualization, Add Watch Reference (+8 more)

### Community 9 - "Enhancement Plans"
Cohesion: 0.20
Nodes (14): LibFEM Enhancement Plan, _beamdiagram Helper Extraction, Commit Strategy, i=j Assembly Guard (C8), Near-Vertical Beam Tolerance Fix (C3), Parallelization Wave Map, Shared Helper Functions, Sprint 0: Assembly Safety Net (+6 more)

### Community 10 - "Beam/Frame Library"
Cohesion: 0.20
Nodes (3): d3_spaceframe_elementforces(), d3_spaceframe_elementlength(), d3_spaceframe_elementstiffness()

### Community 13 - "ModelingToolkit Examples"
Cohesion: 0.28
Nodes (5): LinearAlgebra, Plots, truss_force(), truss_strain(), truss_stress()

### Community 14 - "Kattan Book Reference"
Cohesion: 0.22
Nodes (9): MATLAB Guide to Finite Elements — 2nd Ed, Springer 2007, Kattan Basic Equations (Spring, Linear Bar, Beam, Plane Truss, Space Truss, Frame), Kattan Book Chapters (17 chapters covering 16 element types + fluid flow), Continuum Elements (CST, Q4, T6, Q8, Brick, Tetrahedron) — not yet implemented in LibFEM, Linear Bar Element — k=EA/L*[[1,-1],[-1,1]], 2 DOF, linear shape functions, MATLAB Finite Element Toolbox (84 functions on CD-ROM), Doc/Peter_Kattan_MATLAB_Guide_to_FE_2007_Springer.md — Textbook Markdown Transcription, 6-Step FEM Process: Discretize, Element Stiffness, Assemble, BCs, Solve, Post-process (+1 more)

### Community 15 - "Community 15"
Cohesion: 0.22
Nodes (9): TDD OpenAI Agent, Mocking Guidelines, Mock at System Boundaries, Test-Driven Development, Good and Bad Tests, TDD Anti-Patterns, Red-Green Refactor Loop, Testing Seams (+1 more)

### Community 16 - "Community 16"
Cohesion: 0.46
Nodes (7): Int, AssemblyError, DiagramError, ElementDimensionError, ElementParameterError, Exception, String

### Community 17 - "Community 17"
Cohesion: 0.36
Nodes (7): LibFEM, LinearAlgebra, TOML, main(), resolve_func(), serialize_matrix(), write_error_marker()

### Community 19 - "Community 19"
Cohesion: 0.73
Nodes (6): Enhancement Execution Plan (2026-07-27), Verified Enhancement Plan (2026-07-27), Enhancement Roadmap (2026-07-26), Hyperplan Bundle (Tiers 0-5), Code Review (2026-07-25), PR #110 Code Review (2026-07-26)

### Community 20 - "Community 20"
Cohesion: 0.33
Nodes (4): PropCheck, LibFEM, LinearAlgebra, Test

### Community 21 - "Community 21"
Cohesion: 0.33
Nodes (5): Revise, LibFEM, LinearAlgebra, Pkg, Plots

### Community 23 - "Community 23"
Cohesion: 0.33
Nodes (5): LibFEM, LinearAlgebra, Pkg, Plots, Test

### Community 25 - "Community 25"
Cohesion: 0.40
Nodes (3): LinearAlgebra, Test, TOML

### Community 26 - "Community 26"
Cohesion: 0.50
Nodes (3): BenchmarkTools, LibFEM, LinearAlgebra

### Community 27 - "Community 27"
Cohesion: 0.50
Nodes (3): LibFEM, Plots, LibFEMPlotsExt

### Community 29 - "Community 29"
Cohesion: 0.67
Nodes (3): RTK Token Compression Proxy, OpenCode NVIDIA NIM Workflow, NVIDIA NIM Agent Pipeline

### Community 30 - "Community 30"
Cohesion: 0.67
Nodes (3): OpenCodeReview PR Review Workflow, alibaba/open-code-review Action, Conditional Concurrency Group Pattern

### Community 31 - "Community 31"
Cohesion: 0.67
Nodes (3): OpenWiki Stale Check Workflow, OpenWiki Update Workflow, OpenWiki Documentation Generator

## Knowledge Gaps
- **157 isolated node(s):** `pre-commit-ocr.sh script`, `$schema`, `oh-my-openagent@latest`, `using-superpowers`, `brainstorming` (+152 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **63 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `validate()` connect `Caveman Compress Benchmarking` to `Caveman Compress Tool`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **What connects `pre-commit-ocr.sh script`, `$schema`, `oh-my-openagent@latest` to the rest of the system?**
  _157 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Problem Wrapper & Validation` be split into smaller, more focused modules?**
  _Cohesion score 0.10338680926916222 - nodes in this community are weakly interconnected._
- **Should `Caveman Compress Tool` be split into smaller, more focused modules?**
  _Cohesion score 0.12258064516129032 - nodes in this community are weakly interconnected._
- **Should `Octave Test Runner` be split into smaller, more focused modules?**
  _Cohesion score 0.1402116402116402 - nodes in this community are weakly interconnected._
- **Should `OpenCode Superpowers` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `Truss Element Library` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._