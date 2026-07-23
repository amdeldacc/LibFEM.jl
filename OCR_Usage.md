# OpenCodeReview (OCR) — LibFEM.jl Usage Guide

## Current Setup

- **Version**: 1.7.15
- **Provider**: NVIDIA NIM (local, validated)
- **Rules**: `.opencodereview/rule.json` — 3 rule groups for `src/**/*.jl`, `test/**/*.jl`, `Doc/**/*.m`
- **CI**: `.github/workflows/ocr-review.yml` — runs on PR, `llm_extra_body: '{}'` (OpenAI-compatible fix)

## Julia-Specific Review Focus

OCR reviews Julia code through the lens of the project's custom rules. For **LibFEM.jl**, every review should flag violations of these Julia-specific practices:

### Type System & Dispatch

- **Type instability**: Any-typed local variables or return values in hot paths (`assembly.jl`, element kernels). Use concrete types or `Union`.
- **Multiple dispatch**: Prefer generic functions over if-else chains on type. Use parametric methods where natural (e.g., `d{N}_{domain}_*` pattern).
- **Naming**: Functions/variables in **snake_case**, types in **PascalCase**. Flag any `camelCase` or `PascalCase` functions.

### Struct Definitions (`src/types.jl`)

- Use `@kwdef` macro for keyword constructors on element structs.
- Every field must have a docstring.
- Prefer `struct` (immutable) over `mutable struct` unless mutation is required.
- Custom `show` methods should use `dump` for debugging.

### Error Handling (`src/errors.jl`)

- Domain errors must use custom exception types (`ElementDimensionError`, etc.).
- Guard clauses at function entry: `x <= 0 && throw(ArgumentError("..."))`.
- Informative messages — not just "invalid input".

### Performance

- `@views` macro in hot loops to avoid unnecessary copies (already used in `_assemble!`).
- No global mutable state in function bodies.
- Avoid temporary allocations in element stiffness/force loops.
- Type annotations on all function parameters.

### Testing Structure (`test/`)

- One top-level `@testset` per test file.
- `@test_throws` for expected errors (invalid dimensions, zero length, etc.).
- Edge cases and type stability tested separately.
- MATLAB comparisons via `isapprox` with explicit `atol`/`rtol`.

### Code Organization

- Public API functions **exported** in `src/LibFEM.jl`.
- All exported functions have docstrings: signature, args, return value, units.
- `include` for organizing the module (already done).

## Prioritized Use Cases

### 1. Pre-commit (workspace mode)

Run before every commit to catch trivial regressions.

```bash
ocr review --background \
"LibFEM.jl Julia FEA package. Check:
- Type stability and multiple dispatch correctness
- Dimension consistency (d1=1, d2_spring/truss=2, d2_beam=3, d3_spring/truss=3, d3_beam=6 DOF)
- Assembly logic (_assemble! bounds, .+= semantics)
- Symmetric stiffness matrices (k == k')
- snake_case naming for functions/vars, PascalCase for types
- Missing docstrings on exported functions
- Missing guard clauses or custom error types
- No regressions in existing tests"
```

### 2. Branch review (range mode)

Review all changes introduced by a feature branch before PR.

```bash
ocr review --from master --to feat/my-feature --background \
"LibFEM.jl Julia FEA package — feature branch. Check:
- Type stability and multiple dispatch correctness
- Dimension consistency (d1=1, d2_spring/truss=2, d2_beam=3, d3_spring/truss=3, d3_beam=6 DOF)
- Assembly logic (_assemble! bounds, .+= semantics)
- Symmetric stiffness matrices (k == k')
- snake_case naming for functions/vars, PascalCase for types
- Missing docstrings on exported functions
- Missing guard clauses or custom error types
- No regressions in existing tests
- New functions follow 3-function pattern (elementstiffness, assemble, elementforce/stress/strain)
- @test_throws for new error conditions
- No mutable globals in performance paths"
```

### 3. Single commit review

Isolate a specific fix or patch for review.

```bash
ocr review --commit abc123 --background \
"LibFEM.jl Julia FEA package — single commit. Check for regressions, type stability, dimension correctness, API compatibility. No stylistic nits."
```

### 4. MATLAB-to-Julia translation

When translating a `.m` reference file into Julia source.

```bash
ocr review --from master --to feat/translation --background \
"Translate MATLAB problem_X_Y.m to Julia for LibFEM.jl FEA package. Check:
- Julia naming conventions (snake_case functions, PascalCase types) vs MATLAB camelCase
- @kwdef structs for new element types where applicable
- deg2rad conversion on all angle parameters
- Stiffness matrix symmetry
- isapprox tolerances in test comparisons (atol=1e-10, rtol=1e-8)
- Match reference numerical results exactly"
```

### 5. Assembly / type-system changes

Aggressive checking on core infrastructure.

```bash
ocr review --from master --to feat/refactor --background \
"Modification of assembly logic or type hierarchy in LibFEM.jl. Check:
- _assemble! indices stay in bounds for the DOF count of each element type
- @kwdef struct fields unchanged if struct is immutable; field names/types backward-compatible
- Abstract type hierarchy preserved (AbstractElement{NDIM} → AbstractSpring/Truss/Beam)
- No breaking changes to exported API signatures
- All exported functions still have docstrings
- Stiffness matrix symmetry maintained
- @views still used in assembly hot paths"
```

### 6. Agent / CI pipeline integration

Machine-readable JSON for automated decision gates.

```bash
ocr review --format json --audience agent --background \
"LibFEM.jl Julia FEA package — automated CI review. Check type stability, dimension correctness, assembly logic, API compatibility, docstring coverage, test coverage." > review.json
```

### 7. `.m` reference file verification

The custom rule set flags any accidental modifications to MATLAB references.

```bash
ocr review --preview
ocr review
```

### 8. Preview only

List files that would be reviewed without invoking the LLM.

```bash
ocr review --preview
```

## When NOT to run OCR

- On `.md` files (unsupported extension, silently excluded)
- On binary/doc formats (PDF, DOC, RTF)
- On very large diffs (>~58k tokens) — file is dropped with a log warning
- On pure doc/planning commits
- On changes to `Manifest.toml` or generated files in `openwiki/` (excluded by rule.json)

## Recommended alias

```bash
alias ocr-libfem='ocr review --from master --to $(git rev-parse --abbrev-ref HEAD) \
  --background "LibFEM.jl FEA package. Check type stability, dimension correctness, \
  assembly, API compat, docstrings, naming conventions. No stylistic nits."'
```

## Quick reference

| Use case | When | Command |
|---|---|---|
| Pre-commit | Before any commit | `ocr review` |
| Branch review | Before PR | `ocr review --from master --to feat/X` |
| Single commit | After a specific fix | `ocr review --commit <sha>` |
| MATLAB translation | After adding `.m` or Julia export | `ocr review --commit <sha>` |
| CI automation | Pipeline/agent | `ocr review --format json --audience agent` |
| Scope check | Anytime | `ocr review --preview` |
