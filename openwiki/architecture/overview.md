# Architecture Overview

## Module Structure

LibFEM.jl is a single-module library — all code lives in one file: `src/LibFEM.jl` (~904 lines).

```julia
module LibFEM
using Plots

# ── Private helpers ────────────────────────
deg2rad(theta)           # degrees → radians
_assemble!(K, k, i, j, dofs)  # generic assembly

# ── 1D elements (1 DOF/node) ──────────────
d1_spring_*              # Spring
d1_truss_*               # Linear bar / 1D truss

# ── 2D elements ───────────────────────────
d2_spring_*              # Spring (2 DOF/node)
d2_truss_*               # Plane truss (2 DOF/node)
d2_beam_*                # Plane beam/frame (3 DOF/node)

# ── 3D elements ──────────────────────────
d3_spring_*              # Spring (3 DOF/node)
d3_truss_*               # Space truss (3 DOF/node)
d3_beam_*                # Space frame / 3D beam (6 DOF/node)

end # module
```

**Exports**: All public functions are individually exported immediately after their definitions.

## Naming Convention

```
d{N}_{domain}_{operation}
```

| Component | Values | Description |
|-----------|--------|-------------|
| `{N}` | `1`, `2`, `3` | Dimensionality |
| `{domain}` | `spring`, `truss`, `beam` | Element type |
| `{operation}` | `elementstiffness`, `assemble`, `elementforce`, `elementstress`, `elementstrain`, `elementlength`, `elementaxialdiagram`, etc. | Operation |

This is a translation from the MATLAB naming convention in `Doc/Kattan/M-Files/`, where files use PascalCase names like `PlaneTrussElementStiffness.m`. See [Kattan MATLAB Mapping](../reference/kattan-mapping.md) for the full mapping.

## Dimension System

| Prefix | DOF per node | Typical elements | Global matrix indexing |
|--------|-------------|------------------|----------------------|
| `d1_` | 1 | 1D spring, linear bar | Node `i` → row `i` |
| `d2_` | 2 | 2D spring, plane truss | Node `i` → rows `2i-1, 2i` |
| `d3_` | 3 (`d3_spring`, `d3_truss`) | 3D spring, space truss | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_beam` | **6** | Space frame (3D beam) | Node `i` → rows `6i-5, 6i-4, 6i-3, 6i-2, 6i-1, 6i` |

### Special cases: Beam elements

**2D Beam (`d2_beam_*`)**: Uses 3 DOF per node (`u_x`, `u_y`, rotation) — matching the `d3_` indexing scheme — because beam elements carry both axial and bending behavior. The `_assemble!` helper handles this by parameterizing DOF count per node.

**3D Beam / Space Frame (`d3_beam_*`)**: Uses **6 DOF per node** (`u_x`, `u_y`, `u_z`, `θ_x`, `θ_y`, `θ_z`) — translations and rotations in all three axes. The element stiffness matrix is 12×12. The rotation matrix `Λ` (3×3 direction cosines) is constructed from the element node coordinates, handling the vertical-element degenerate case where `D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`.

## Function Pattern

Every element domain implements three core functions:

```julia
# 1. Element stiffness matrix — depends on material properties + geometry
k = d2_truss_elementstiffness(E, A, L, theta)   # returns 4×4 matrix

# 2. Assemble into global matrix
K = d2_truss_assemble(K, k, i, j)               # mutates K in-place via .+=

# 3a. Force vector (from displacements)
f = d2_truss_elementforce(E, A, L, theta, u)    # returns scalar (or Vector)

# 3b. Stress (from displacements, optional)
sigma = d2_truss_elementstress(E, L, theta, u)

# 3c. Strain (from displacements, optional)
epsilon = d2_truss_elementstrain(L, theta, u)
```

Additional helpers exist per domain:
- **Length**: `_elementlength(...)` — Euclidean distance between node coordinates (2D/3D truss, beam)
- **Diagrams** (beam only): `_elementaxialdiagram`, `_elementmomentdiagram`, `_elementsheardiagram` — return Plots.jl `Plot` objects

### Angle Conventions

Angles are always passed in **degrees** and converted internally:

```julia
deg2rad(theta::Real) = theta * pi / 180
```

- 2D elements: single `theta` parameter (angle from positive x-axis)
- 3D elements: three parameters `thetax, thetay, thetaz` (direction angles to x, y, z axes)

## Assembly Helper (`_assemble!`)

Since [the refactor](assembly-helper-refactor.md) (2026-07-15), all 7 public `*_assemble` functions delegate to one private helper:

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, dofs::Integer)
    ii = (dofs * (i - 1) + 1):(dofs * i)
    jj = (dofs * (j - 1) + 1):(dofs * j)
    K[ii, ii] .+= k[1:dofs, 1:dofs]
    K[ii, jj] .+= k[1:dofs, (dofs + 1):(2 * dofs)]
    K[jj, ii] .+= k[(dofs + 1):(2 * dofs), 1:dofs]
    K[jj, jj] .+= k[(dofs + 1):(2 * dofs), (dofs + 1):(2 * dofs)]
    return K
end
```

This maps 4 element-level blocks (ii, jj, ii→jj, jj→ii) to the global stiffness matrix using block indices based on `dofs`. It works for any DOF count:

| `dofs` | Used by |
|--------|---------|
| `1` | `d1_spring_assemble`, `d1_truss_assemble` |
| `2` | `d2_spring_assemble`, `d2_truss_assemble` |
| `3` | `d2_beam_assemble`, `d3_spring_assemble`, `d3_truss_assemble` |
| `6` | `d3_beam_assemble` |

The helper is private (underscore prefix, not exported). Adding new element types requires only passing the correct `dofs` parameter — no new assembly boilerplate.

## Complete Function Inventory

### 1D Spring (`d1_spring`)
- `d1_spring_elementstiffness(k)` — 2×2 matrix
- `d1_spring_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_spring_elementforce(k, u)` — 2-element vector

### 1D Truss (`d1_truss`)
- `d1_truss_elementstiffness(E, A, L)` — 2×2 matrix
- `d1_truss_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_truss_elementforce(k, u)` — 2-element vector
- `d1_truss_elementstress(k, u, A)` — stress at nodes
- `d1_truss_elementstrain(L, u)` — strain at nodes

### 2D Spring (`d2_spring`)
- `d2_spring_elementstiffness(k, theta)` — 4×4 matrix
- `d2_spring_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_spring_elementforce(k, theta, u)` — scalar force

### 2D Truss (`d2_truss`)
- `d2_truss_elementstiffness(E, A, L, theta)` — 4×4 matrix
- `d2_truss_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_truss_elementforce(E, A, L, theta, u)` — scalar force
- `d2_truss_elementstress(E, L, theta, u)` — scalar stress
- `d2_truss_elementstrain(L, theta, u)` — scalar strain
- `d2_truss_elementlength(x1, y1, x2, y2)` — element length

### 2D Beam (`d2_beam`)
- `d2_beam_elementstiffness(E, A, I, L, theta)` — 6×6 matrix
- `d2_beam_assemble(K, k, i, j)` — DOF mapping: 3
- `d2_beam_elementforce(E, A, I, L, theta, u)` — 6-element vector
- `d2_beam_elementlength(x1, y1, x2, y2)` — element length
- `d2_beam_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d2_beam_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram
- `d2_beam_elementsheardiagram(f, L)` — Plots.jl shear force diagram

### 3D Spring (`d3_spring`)
- `d3_spring_elementstiffness(k, thetax, thetay, thetaz)` — 6×6 matrix
- `d3_spring_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_spring_elementforce(k, thetax, thetay, thetaz, u)` — scalar force

### 3D Truss (`d3_truss`)
- `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)` — 6×6 matrix
- `d3_truss_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_truss_elementforce(E, A, L, thetax, thetay, thetaz, u)` — scalar force
- `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)` — scalar stress
- `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)` — scalar strain
- `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` — element length

### 3D Beam / Space Frame (`d3_beam`)
- `d3_beam_elementstiffness(E, A, Iy, Iz, G, J, L, x1, y1, z1, x2, y2, z2)` — 12×12 matrix
- `d3_beam_assemble(K, k, i, j)` — DOF mapping: **6**
- `d3_beam_elementforces(E, A, Iy, Iz, G, J, L, x1, y1, z1, x2, y2, z2, u)` — 12-element vector (local frame)
- `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)` — 3D Euclidean distance
- `d3_beam_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d3_beam_elementshearydiagram(f, L)` — Plots.jl shear force (Y) diagram
- `d3_beam_elementshearzdiagram(f, L)` — Plots.jl shear force (Z) diagram
- `d3_beam_elementmomentyidiagram(f, L)` — Plots.jl bending moment (Y) diagram
- `d3_beam_elementmomentzdiagram(f, L)` — Plots.jl bending moment (Z) diagram
- `d3_beam_elementtorsiondiagram(f, L)` — Plots.jl torsion diagram

  **Note**: The 3D beam uses a 12×12 local stiffness matrix with an embedded 3×3 rotation matrix `Λ` built from node coordinates (not angle parameters). `Iy` governs bending about the y-axis (δz, θy), `Iz` governs bending about the z-axis (δy, θz). The vertical-element degenerate case (`D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`) is handled automatically.

## Dependencies & Runtime Notes

- **`Plots.jl`** v1 — used by all beam diagram functions (`d2_beam_*` and `d3_beam_*`). Required in `Project.toml`.
- **`using Plots`** is declared at module level in `src/LibFEM.jl`.
- **No `ModelingToolkit`** — listed as a dependency in `CLAUDE.md`'s older version note, but the `Project.toml` has been updated to `Plots` only. The scripts in `scripts/` use MTK independently.

## Testing

Tests are in `test/`:
- **`runtests.jl`** — Main test suite (~400 lines). Uses `Test` standard library. Covers all 8 element types (including `d3_beam`) with stiffness matrix shape/symmetry checks, force/stress/strain numeric validation, and assembly correctness.
- **`comparison.jl`** — Side-by-side MATLAB reference implementations transcribed from `Doc/Kattan/M-Files/`. Not run as independent tests; included from `runtests.jl`.

To run:
```julia
julia --project=. -e 'using Pkg; Pkg.test()'
# Or manually:
# julia --project=. test/runtests.jl
```

No CI is set up yet. The output of `runtests.jl` verifies all behavior matches expectations.

## Extension Points

When adding a new element type:

1. Implement `d{N}_{domain}_elementstiffness(...)` returning the correct matrix size
2. Implement `d{N}_{domain}_assemble(K, k, i, j)` — a 1-liner calling `_assemble!(K, k, i, j, dofs)`
3. Implement force/stress/strain as appropriate
4. Add `export` after each function
5. Add tests in `test/runtests.jl`

Key invariants to maintain:
- All angles in degrees (use `deg2rad`)
- Stiffness matrices must be symmetric
- Assembly uses `.+=` (in-place addition) to allow building up the global matrix from multiple elements

## Known Issues

See `ToDo.md` for full list. Notable items:
- Docstring typos (lines 105-107, ~673 in `src/LibFEM.jl`)
- Double space in an export statement (line 319)
- No boundary condition or solver functions yet (users must solve `K·U = F` themselves)
- No `Project.toml` `[extras]`/`[targets]` section for `Test` dependency