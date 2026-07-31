<!-- Updated by ai-context skill on 2026-07-30 -->

# Rules — Coding Constraints

<!--
This file defines boundaries the AI must not cross.
AI agents check this BEFORE writing any code.
Violations should be flagged in code review.
-->

## Required Tech Stack

- Julia 1.x (compat range in `Project.toml`), tested on Julia 1 and Julia 1.10 in CI
- `LinearAlgebra` stdlib for matrix operations
- `Plots.jl` v1 as optional weak dependency only (for diagram extensions)
- `Test`, `BenchmarkTools`, `PropCheck` for testing (extras)

## Approved Libraries

- `LinearAlgebra` (stdlib, hard dep)
- `Plots` >=1.0 (optional weak dep, for diagram extension)
- `BenchmarkTools` (test/benchmark only)
- `PropCheck` (test/property tests only)
- `Test` (stdlib, test only)

## Forbidden Libraries

- No GUI or plotting frameworks other than `Plots.jl`
- No web frameworks, HTTP servers, or API clients
- No database drivers or ORMs
- No machine learning or deep learning frameworks
- No commercial or proprietary FEM libraries

## Naming Conventions

- **Files**: `snake_case.jl` — e.g., `spring.jl`, `assembly.jl`, `quadratictriangle.jl`, `quadraticquadrilateral.jl`
- **Modules**: `PascalCase` — `LibFEM`
- **Functions**: `snake_case` — e.g., `d2_spring_elementstiffness`, `_assemble!`
- **Private helpers**: prefix with `_` — e.g., `_assemble!`, `_d3_spaceframe_kprime`
- **Types**: `PascalCase` — e.g., `AbstractElement`, `Spring{NDIM}`, `ElementParameterError`
- **Variables**: `snake_case` — e.g., `element_stiffness`, `global_k`
- **Dimension prefixes**: `d1_` (1D), `d2_` (2D), `d3_` (3D) in function names
- **Domain prefixes**: `spring`, `bar`, `truss`, `beam`, `planeframe`, `spaceframe`, `grid`, `cst`, `lst`, `q4`, `q8`, `quadraticbar`, `tet`, `brick`, `fluidflow` in function names

## Error Handling Rules

- Use custom typed error classes from `errors.jl`: `ElementDimensionError`, `ElementParameterError`, `AssemblyError`, `DiagramError`
- Validate physical inputs (`L > 0`, `A > 0`) with `ElementParameterError` and descriptive messages
- Diagram functions throw `DiagramError("Plots.jl is required...")` when Plots not loaded
- Never throw generic `Exception` — use the typed error hierarchy
- Never silently swallow errors — let them propagate to the user

## Security Guidelines

<!-- N/A — LibFEM is a local-use Julia library with no network, auth, or user input from external sources. -->
- No hardcoded secrets (all parameters are user-provided numeric values)
- No network requests or external I/O (MATLAB validation is opt-in, requires Octave)
- All numeric inputs are validated for physical reasonableness (`L > 0`, `A > 0`)

## Extensibility Standards

- New element family → create `src/<family>.jl` with the 3-function pattern (stiffness, assembly, force/stress/strain)
- Add `include("<family>.jl")` to `src/LibFEM.jl` in the correct order
- Add `export` statements for all public functions in `src/LibFEM.jl`
- Add tests in `test/runtests.jl` covering: stiffness shape/symmetry, numeric correctness against MATLAB, assembly correctness
- Stiffness matrices must be symmetric and positive semi-definite
- Assembly functions must delegate to `_assemble!(K, k, i, j, ndofs)`
- All angles must be accepted in degrees and converted internally

## Files the AI Must Not Touch

<!-- Read-only files. AI may read but never modify. -->
- `./Doc/Kattan/*` — Read-only MATLAB reference files
- `./.github/workflows/*` — CI/CD pipeline definitions
- `./LICENSE` — License file
- `./Manifest.toml` — Auto-generated dependency manifest
- `./AGENTS.md` — Agent instructions (may append context file reference table)
- `./CLAUDE.md` — Agent instructions (symlinked to AGENTS.md)

## Limits on Autonomous Decisions

- Adding new dependencies requires approval
- Changing the module structure (adding/removing `include()` lines) requires approval
- Changing CI/CD pipeline (`.github/workflows/*`) requires approval
- Adding new element families requires approval
- Removing or renaming public API functions requires approval
- Changing the angle convention (degrees vs radians) requires approval
- Any change to `Project.toml` version or compat entries requires approval
