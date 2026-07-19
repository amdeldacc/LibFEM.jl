# LibFEM.jl — Code Review ToDo

## Summary
LibFEM.jl is a well-structured Julia FEM library implementing spring, truss, and beam elements in 1D–3D. The codebase has clean naming conventions, systematic MATLAB-reference parity tests, and comprehensive parameter validation. All 462 tests pass. Below are actionable improvements organized by priority.

---

## Critical

### 1. `plot.jl` — file is corrupted with duplicate line numbers, mixed content
- **File**: `src/plot.jl`
- **Observation**: The GitHub Actions diff shows the file has corrupted/malformed line numbering (lines like `6:` appear twice, content numbers jump non-monotonically: `5 → 6 → 6 → 7 → 7 → 8 → 8 → 9 → ... → 11 → 13 → 15 → 17 → 19 → 20 → 22 → 25 → 28 → 32 → ...`). This suggests a Git merge artifact or partial write.
- **Action**: Re-create `src/plot.jl` from a clean copy. Verify with `git show HEAD:src/plot.jl` or regenerate from scratch.
- **Actual code reads correctly**: When reading the file directly (not the diff view), the file content appears correct with line numbers 1–202 and all 10 diagram functions properly defined. This may be a diff/intra-report artifact. Verify the on-disk file matches expectations.

### 2. `d3_spring_elementforce` — Variable shadowing hides parameter bug
- **File**: `src/spring.jl:186`
- **Issue**: The parameter name `u` in the docstring refers to `"Angle about y-axis in degrees"` but the function signature uses `u` as a parameter (shadowing the displacement vector). Line 188 assigns `uy = deg2rad(thetay)` which is correct, but the naming is confusing and error-prone.
- **Action**: Rename internal variable `u` (angle) to `uy_rad` or similar. Docstring conflicts with parameter `u` on line 186.

### 3. `d3_truss_elementforces/stress/strain` — Variable `w` shadows unused value
- **File**: `src/truss.jl:316,342,369`
- **Issue**: The variable `w` is computed as `deg2rad(thetay)` but is shadowed by parameter naming confusion (`w` also appears as an intermediate variable in some functions). Not a runtime bug, but inconsistent with `d3_spring_elementforce` which uses `uy`.
- **Action**: Standardize naming across all 3-D force/stress/strain functions: use `theta_x_rad`, `theta_y_rad`, `theta_z_rad` consistently.

---

## Improvements

### 4. Missing type annotations & parametric dispatch on abstract types
- **Files**: All `src/*.jl` element functions
- **Issue**: Functions accept individual `Real` parameters rather than element structs. E.g., `d2_beam_elementstiffness(E, A, I, L, theta)` instead of `d2_beam_elementstiffness(beam::Beam2D, L, theta)`. The `@kwdef` structs exist but are unused by element functions.
- **Action**: Add convenience methods that accept the struct and delegate to parameter-based methods, or refactor to prefer the struct-based interface.

### 5. `_assemble!` doesn't validate matrix dimension compatibility
- **File**: `src/assembly.jl:21`
- **Issue**: `_assemble!` does not check if `K` is large enough for the requested node indices, nor that `k` has the right dimensions for `ndofs`. An incorrect `ndofs` value will silently access out-of-bounds indices.
- **Action**: Add bounds checks in `_assemble!`:
  ```julia
  size(k) == (2*ndofs, 2*ndofs) || throw(AssemblyError("..."))
  max((i,j)*ndofs) <= size(K,1) || throw(AssemblyError("..."))
  ```

### 6. Lack of `LinearAlgebra` dependency even though it's used
- **File**: `Project.toml`
- **Issue**: Tests use `LinearAlgebra` (in `benchmark.jl`) but it's not listed as a dependency or test dependency. It works because Julia ships with it, but explicit is cleaner.
- **Action**: Add `LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c89"` to `[extras]` in `Project.toml`.

### 7. Duplicate code blocks in `d3_beam_elementforces` and `d3_beam_elementstiffness`
- **File**: `src/beam.jl:193-225,293-314`
- **Issue**: The rotation matrix construction (Lambda, R) is duplicated verbatim in both functions (~30 lines each). Any bug fix must be applied in two places.
- **Action**: Factor into a shared private function: `_d3_beam_rotation(x1, y1, z1, x2, y2, z2, L)`.

### 8. Missing 3-D beam test for an arbitrary angled element (non-axis-aligned, non-vertical)
- **File**: `test/runtests.jl` `d3_beam` tests
- **Issue**: Tests only cover horizontal (along X) and vertical (along Z) beams. No test for an arbitrary-angled 3D beam where the rotation matrix is non-trivial.
- **Action**: Add a test case like `(0,0,0) → (3,4,12)` (the classic 5-12-13 triangle) with known stiffness values.

### 9. `d2_beam_elementsheardiagram` not exported despite `export` in plot.jl
- **File**: `src/LibFEM.jl:53`
- **Observation**: Line 53 exports `d2_beam_elementsheardiagram` and plots.jl comment says "re-exported from beam.jl" but the function is defined in `plot.jl` and the export exists. However, the diff report mentions "Notice: d2_beam_elementsheardiagram, d2_beam_elementmomentdiagram not yet exported" comments. These appear stale.
- **Action**: Remove stale "Notice" comments from `plot.jl` (they appear in diff view but may be fixed already).

### 10. Missing `d2_beam_elementtorsiondiagram` — 2D beams have no torsion diagram, but this is hinted at
- **File**: `src/plot.jl` (comment reference only)
- **Observation**: A comment mentions "d2_beam_elementtorsiondiagram not yet exported" but 2D beams (3 DOF/node) don't have torsion DOFs. This comment is misleading.
- **Action**: Remove misleading comment. Torsion is only meaningful in 3D beams.

### 11. `_d3_beam_kprime` in `assembly.jl` — unconventional placement
- **File**: `src/assembly.jl:52`
- **Issue**: `_d3_beam_kprime` belongs logically in `beam.jl` rather than `assembly.jl`. The separation is technically correct (both files are in module namespace), but it makes the code harder to discover.
- **Action**: Move `_d3_beam_kprime` to `src/beam.jl`.

### 12. Run benchmark suite in CI
- **File**: `test/benchmark.jl`, `.github/workflows/`
- **Observation**: A benchmark suite exists but is not referenced from `runtests.jl` or run in CI. It should be part of the test workflow to catch performance regressions.
- **Action**: Add `include("benchmark.jl")` at the end of `runtests.jl` or a separate CI job.

---

## Nitpicks

### 13. `L > 0` check is inconsistently applied
- **Files**: `src/truss.jl, src/beam.jl`
- **Issue**: `d1_truss_elementstiffness` checks `L > 0`, but `_d3_beam_kprime` does not — it relies on the caller (`d3_beam_elementstiffness`) to validate. The private `_assemble!` has no `L` parameter. This is inconsistent but not buggy since all public-facing functions validate.
- **Action**: Document the convention: public functions validate, private `_*` helpers don't.

### 14. Inconsistent use of `return` — sometimes omitted
- **Files**: `src/utils.jl:19` uses explicit `return`, `src/beam.jl:23` uses implicit. Both are valid Julia style, but consistency per file improves readability.
- **Action**: Choose a convention (recommend: implicit for simple one-liners, explicit for multi-step functions) and apply consistently.

### 15. `.gitignore` missing Julia-specific entries
- **File**: `.gitignore`
- **Issue**: No patterns for `Manifest.toml` (recommended for applications), `*.cov`, `*.cov.mem`, etc.
- **Action**: Add standard Julia gitignore entries if appropriate for the project.

### 16. README missing / no usage documentation
- **Issue**: No `README.md` exists. Users have no way to know what the package does, API documentation, or installation instructions without reading the source.
- **Action**: Create a `README.md` with: package description, installation, basic usage examples.

### 17. CI workflow only uses opencode
- **File**: `.github/workflows/opencode.yml`
- **Observation**: The only CI workflow is the opencode agent. There's no test job that runs `Pkg.test()`, no test coverage, no code quality checks.
- **Action**: Add a `test.yml` workflow that runs `Using Pkg; Pkg.test()` on commit/PR.

### 18. `export` order in `LibFEM.jl` doesn't match source file order
- **File**: `src/LibFEM.jl`
- **Observation**: Exports are listed by element family (spring, truss, beam) but `include()` order is `types → errors → utils → assembly → spring → truss → beam → plot`. Mixing `export` with `include` order or at least grouping by file would aid readability.
- **Action**: Reorder exports to follow `include()` order, or region-delineate by source file.

---

## Long-term Items

### 19. Add element types from MATLAB references not yet ported
- **MATLAB files in `Doc/Kattan/M-Files/`**: Quadratic bar, bilinear quad, linear triangle, linear brick, grid, fluid flow 1D elements have MATLAB implementations but no counterparts.
- **Action**: Port to Julia `src/*.jl` files using the existing 3-function pattern.

### 0. GPU acceleration feasibility study
- **Issue**: Assembly loops are done by single-threaded `for` loops. GPU or multi-threaded assembly would benefit large systems.
- **Action**: Investigate `KernelAbstractions.jl` and dimension-parametric assembly to support `CuArray` targets.

### 21. 3D beam element: force computation duplicates stiffness computation
- **File**: `src/beam.jl:278-325`
- **Issue**: When computing forces, the code rebuilds `kprime` and the rotation matrix de novo — if you already computed stiffness, you could reuse `Ke * u` directly via `d3_beam_elementforces(Ke, x1, y1, z1, x2, y2, z2, u)` where `Ke` is precomputed.
- **Action**: Add an optimized force method accepting the precomputed global stiffness matrix: `d3_beam_elementforces(Ke::AbstractMatrix, u::AbstractVector)`.

---

## Verified Correct Items

- All element stiffness matrices match MATLAB reference implementations (verified by test/comparison.jl, 244 comparison tests pass)
- All `L > 0` error paths tested with `@test_throws` for all element types with length parameters
- Negative/zero parameter behavior documented and tested (supported for parametric studies and sensitivity analysis)
- Deg2Rad conversion is accurate (verified by current test)
- Assembly logic is correct (targeted by direct verification with MATLAB-assemble functions)
- Type hierarchy (`AbstractElement{NDIM}` → `AbstractSpring/Truss/Beam{NDIM}` → concrete structs) is well-designed
- Symmetry (K == K'`) of all stiffness matrices verified in tests
- 3D beam vertical special case handled correctly (Λ = [0 0 1; 0 1 0; -1 0 0])
- Export symbols are tested for defensibility (18 assertions against defined by module)