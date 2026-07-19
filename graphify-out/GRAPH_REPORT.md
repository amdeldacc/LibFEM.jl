# Graph Report - .  (2026-07-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 188 nodes · 241 edges · 19 communities (14 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `30df82be`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- comparison.jl
- compress.py
- validate.py
- linear_truss_mtk_2.jl
- beam.jl
- Exception
- linear_truss_mtk.jl
- benchmark.py
- benchmark.jl
- runtests.jl
- graphify.js
- LibFEM
- Base
- __init__.py

## God Nodes (most connected - your core abstractions)
1. `validate()` - 14 edges
2. `compress_file()` - 12 edges
3. `detect_file_type()` - 9 edges
4. `should_compress()` - 8 edges
5. `main()` - 7 edges
6. `backup_dir_for()` - 6 edges
7. `benchmark_pair()` - 5 edges
8. `ValidationResult` - 5 edges
9. `validate_headings()` - 5 edges
10. `validate_inline_codes()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `benchmark_pair()` --calls--> `validate()`  [EXTRACTED]
  .opencode/skills/caveman-compress/scripts/benchmark.py → .opencode/skills/caveman-compress/scripts/validate.py
- `compress_file()` --calls--> `validate()`  [EXTRACTED]
  .opencode/skills/caveman-compress/scripts/compress.py → .opencode/skills/caveman-compress/scripts/validate.py
- `main()` --calls--> `backup_dir_for()`  [EXTRACTED]
  .opencode/skills/caveman-compress/scripts/cli.py → .opencode/skills/caveman-compress/scripts/compress.py
- `main()` --calls--> `compress_file()`  [EXTRACTED]
  .opencode/skills/caveman-compress/scripts/cli.py → .opencode/skills/caveman-compress/scripts/compress.py
- `main()` --calls--> `detect_file_type()`  [EXTRACTED]
  .opencode/skills/caveman-compress/scripts/cli.py → .opencode/skills/caveman-compress/scripts/detect.py

## Import Cycles
- None detected.

## Communities (19 total, 5 thin omitted)

### Community 0 - "comparison.jl"
Cohesion: 0.06
Nodes (3): SpaceFrameElementForces(), SpaceFrameElementLength(), SpaceFrameElementStiffness()

### Community 1 - "compress.py"
Cohesion: 0.12
Nodes (27): main(), print_usage(), backup_dir_for(), build_compress_prompt(), build_fix_prompt(), call_claude(), compress_file(), is_sensitive_path() (+19 more)

### Community 2 - "validate.py"
Cohesion: 0.20
Nodes (17): count_bullets(), extract_code_blocks(), extract_headings(), extract_inline_codes(), extract_paths(), extract_urls(), Path, Line-based fenced code block extractor.      Handles ``` and ~~~ fences with var (+9 more)

### Community 6 - "linear_truss_mtk_2.jl"
Cohesion: 0.28
Nodes (5): LinearAlgebra, Plots, truss_force(), truss_strain(), truss_stress()

### Community 7 - "beam.jl"
Cohesion: 0.28
Nodes (3): d3_beam_elementforces(), d3_beam_elementlength(), d3_beam_elementstiffness()

### Community 8 - "Exception"
Cohesion: 0.46
Nodes (7): Exception, Int, AssemblyError, DiagramError, ElementDimensionError, ElementParameterError, String

### Community 10 - "benchmark.py"
Cohesion: 0.60
Nodes (5): benchmark_pair(), count_tokens(), main(), print_table(), Path

### Community 11 - "benchmark.jl"
Cohesion: 0.50
Nodes (3): BenchmarkTools, LibFEM, LinearAlgebra

### Community 12 - "runtests.jl"
Cohesion: 0.50
Nodes (3): Test, LibFEM, Plots

## Knowledge Gaps
- **12 isolated node(s):** `ModelingToolkit`, `LinearAlgebra`, `LinearAlgebra`, `Plots`, `Plots` (+7 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `validate()` connect `validate.py` to `compress.py`, `benchmark.py`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `compress_file()` connect `compress.py` to `validate.py`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `ModelingToolkit`, `LinearAlgebra`, `LinearAlgebra` to the rest of the system?**
  _12 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `comparison.jl` be split into smaller, more focused modules?**
  _Cohesion score 0.06050420168067227 - nodes in this community are weakly interconnected._
- **Should `compress.py` be split into smaller, more focused modules?**
  _Cohesion score 0.12258064516129032 - nodes in this community are weakly interconnected._
- **Should `truss.jl` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._