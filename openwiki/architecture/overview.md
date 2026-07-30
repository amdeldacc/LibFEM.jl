---
type: Architecture Overview
title: "Architecture Overview"
description: "LibFEM.jl module structure, naming conventions, dimension system, assembly helper, function inventory, testing, and extension points"
tags: ["architecture", "module-structure", "naming-convention", "assembly", "testing"]
resource: "/home/piou/LibFEM.jl/src"
---

# Architecture Overview

## Module Structure

LibFEM.jl is a single-module library with multi-file source organization. The module `src/LibFEM.jl` uses `include()` to compose files in `src/`:

| File | Contents |
|------|----------|
| `src/LibFEM.jl` | Module declaration, `include()` directives, `export` statements, stub diagram throwers |
| `src/types.jl` | Abstract type hierarchy, `@kwdef` element structs |
| `src/errors.jl` | Custom error type definitions |
| `src/utils.jl` | `_direction_cosines`, validation helpers (`validate_positive`) |
| `src/assembly.jl` | `_assemble!` private helper, `_d2_planeframe_kprime`, `_d3_spaceframe_kprime` |
| `src/spring.jl` | All `d1/d2/d3_spring_*` implementations |
| `src/truss.jl` | All `d1/d2/d3_truss_*` implementations |
| `src/quadraticbar.jl` | All `d1_quadraticbar_*` implementations (1-D quadratic bar, 3-node) |
| `src/beam.jl` | All `d2_beam_*` (pure beam), `d2_planeframe_*` (plane frame), and `d3_spaceframe_*` (space frame) implementations |
| `src/solver.jl` | `apply_bc!` — Dirichlet boundary condition application |
| `src/triangle.jl` | 2D constant strain triangle (CST) — `d2_cst_*` |
| `src/lst.jl` | 2D quadratic triangle (LST) — `d2_lst_*` |
| `src/quadrilateral.jl` | 2D bilinear quadrilateral (Q4) — `d2_q4_*` |
| `src/q8.jl` | 2D quadratic quadrilateral (Q8) — `d2_q8_*` |
| `src/grid.jl` | 2D grid (out-of-plane bending + torsion) — `d2_grid_*` |
| `src/fluidflow.jl` | 1D fluid flow — `d1_fluidflow_*` |
| `src/brick.jl` | 3D linear brick (8-node) — `d3_brick_*` |
| `src/tetrahedron.jl` | 3D linear tetrahedron (4-node) — `d3_tet_*` |

Beam diagram functions used to live in `src/plot.jl`, but with `Plots.jl` moved to a weak dependency (commit 62baa10), they now live in the package extension `ext/LibFEMPlotsExt.jl`. `src/LibFEM.jl` defines stub throwers (`DiagramError`) for every diagram symbol; loading `Plots` activates the extension, which dispatches into the same exported function names and the stubs are replaced.

```julia
module LibFEM

# includes (order matters: types/errors/utils/assembly first)
include("types.jl")
include("errors.jl")
include("utils.jl")
include("assembly.jl")
include("spring.jl")
include("truss.jl")
include("quadraticbar.jl")
include("beam.jl")
include("solver.jl")

# Import Base.deg2rad for Julia < 1.10 compat (ensures deg2rad
# is available in the module namespace on all Julia 1.x versions)
import Base: deg2rad

# Stub diagram functions (replaced by extension when Plots loaded)
for f in (:d2_beam_elementsheardiagram, :d2_beam_elementmomentdiagram,
          :d2_planeframe_elementaxialdiagram, :d2_planeframe_elementsheardiagram,
          :d2_planeframe_elementmomentdiagram,
          :d3_spaceframe_elementaxialdiagram, :d3_spaceframe_elementshearydiagram,
          :d3_spaceframe_elementshearzdiagram, :d3_spaceframe_elementmomentydiagram,
          :d3_spaceframe_elementmomentzdiagram, :d3_spaceframe_elementtorsiondiagram,
          :_beamdiagram)
    @eval function $f(args...)
        throw(DiagramError("Plots.jl is required for diagram functions. Use `using Plots` along with LibFEM to enable them."))
    end
end

# grouped exports follow...
end
```

**Exports**: All public functions are exported in grouped blocks. `deg2rad` is imported from `Base` into the module namespace (`import Base: deg2rad` in `src/LibFEM.jl`). The helpers `_assemble!`, `_d2_planeframe_kprime`, and `_d3_spaceframe_kprime` remain private (underscore prefix, not exported). Diagram functions (`d2_beam_elementsheardiagram`, etc.) are *also* exported — the extension re-exports them with Plots-backed implementations; without `Plots`, calling them throws `DiagramError`. The new solver helper `apply_bc!` is exported for applying Dirichlet boundary conditions.

---

## Git Hooks & Commit Workflow

LibFEM.jl enforces an approval-gated commit workflow via three git hooks installed in `.githooks/`:

| Hook | Script | Purpose |
|------|--------|---------|
| `pre-commit` | `.githooks/pre-commit` | Blocks commit unless `GIT_APPROVED=<message-id>` environment variable is set. Logs approval to `.git/commit-approval.log`. |
| `prepare-commit-msg` | `.githooks/prepare-commit-msg` | 1. Injects `Approved-by: $GIT_APPROVED` into commit body when `GIT_APPROVED` is set (idempotent on `--amend`). 2. Safety net: if the commit message still contains the placeholder `TO BE REPLACED BY RELEVANT CONTENT PROVIDED BY CONTEXT`, replaces it with a `git diff --cached --stat` summary. |
| `pre-push` | `.githooks/pre-push` | Blocks push to `origin` unless every new commit in the pushed range has an `Approved-by:` line in its body. Prevents bypassing the pre-commit guard. |

### Workflow

1. **User approval**: Human sets `GIT_APPROVED='user approved message'` (or `GIT_APPROVED=manual` for direct commits) and runs `git commit`.
2. **Pre-commit**: Allows commit only if `GIT_APPROVED` is set; logs approval.
3. **Prepare-commit-msg**: Injects `Approved-by: $GIT_APPROVED` into the commit body (idempotent on `--amend`). Falls back to a `git diff --stat` summary if the agent forgot to supply a message.
4. **Pre-push**: Verifies every new commit on push to `origin` contains `Approved-by:`. Blocks push if any commit is missing it.

This creates a verifiable chain: **pre-commit requires approval → prepare-commit-msg records it → pre-push enforces it**. The agent cannot bypass the human approval step.

---

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
| `d1_` | 1 | 1D spring, linear bar, quadratic bar | Node `i` → row `i` |
| `d2_` | 2 | 2D spring, plane truss | Node `i` → rows `2i-1, 2i` |
| `d2_planeframe` | **3** | Plane frame (2D beam with axial) | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_` | 3 (`d3_spring`, `d3_truss`) | 3D spring, space truss | Node `i` → rows `3i-2, 3i-1, 3i` |
| `d3_spaceframe` | **6** | Space frame (3D beam) | Node `i` → rows `6i-5, 6i-4, 6i-3, 6i-2, 6i-1, 6i` |

### Beam elements: two variants (2D)

**2D Pure Beam (`d2_beam_*`)**: Uses **2 DOF per node** (deflection `v`, rotation `θ`) — pure bending only, no axial deformation. The 4×4 stiffness matrix is the classical Euler-Bernoulli beam. Assembly uses `_assemble!` with `dofs=2`.

**2D Plane Frame (`d2_planeframe_*`)**: Uses **3 DOF per node** (`u_x`, `u_y`, rotation) — combining axial and bending behavior. The 6×6 stiffness matrix matches Kattan's `PlaneFrameElementStiffness`. Assembly uses `_assemble!` with `dofs=3`.

**3D Space Frame (`d3_spaceframe_*`)**: Uses **6 DOF per node** (`u_x`, `u_y`, `u_z`, `θ_x`, `θ_y`, `θ_z`) — translations and rotations in all three axes. The element stiffness matrix is 12×12. The rotation matrix `Λ` (3×3 direction cosines) is constructed from the element node coordinates, handling the vertical-element degenerate case where `D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`.

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

**Validation**: Most stiffness/length functions now validate positive inputs (e.g., `L > 0`, `A > 0`, `k > 0`) and throw `ElementParameterError` with descriptive messages on violation. The shared internal helper is `validate_positive(x::Real, name::AbstractString)` in `src/utils.jl`. Functions currently guarded: `d1_truss_elementstiffness`, `d1_quadraticbar_elementstiffness`, `d2_truss_elementstiffness`/`elementstrain`, `d2_beam_elementstiffness`, `d2_planeframe_elementstiffness`, `d3_spring_elementstiffness`, `d3_truss_elementstiffness`/`elementstrain`/`elementlength`, `d3_spaceframe_elementstiffness`/`elementlength`, plus force/stress variants.

Additional helpers exist per domain:
- **Length**: `_elementlength(...)` — Euclidean distance between node coordinates (2D/3D truss, beam)
- **Diagrams** (beam only): `_elementaxialdiagram`, `_elementmomentdiagram`, `_elementsheardiagram` — return Plots.jl `Plot` objects
- **3D space frame internals**: `_d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)` — private helper returning the 12×12 local stiffness matrix in element coordinates (before rotation to global). Used by `d3_spaceframe_elementstiffness` and `d3_spaceframe_elementforces`.

### Angle Conventions

Angles are always passed in **degrees** and converted internally:

```julia
deg2rad(theta::Real) = theta * pi / 180
```

- 2D elements: single `theta` parameter (angle from positive x-axis)
- 3D elements: three parameters `thetax, thetay, thetaz` (direction angles to x, y, z axes)

**3D direction cosine convention** (`src/utils.jl` `_direction_cosines`):

Unlike the spherical (polar + azimuthal) convention, the 3-angle convention defines each angle as the angle between the element axis and the corresponding global axis. The identity `cos²θx + cos²θy + cos²θz = 1` must hold for a valid direction vector. If inputs violate this by more than `1e-12`, the helper warns and normalizes the cosines automatically (degenerate `Cx²+Cy²+Cz² ≈ 0` is returned as-is). In practice, prefer deriving direction cosines from node coordinates via `d2_truss_elementlength`/`d3_truss_elementlength` rather than specifying angles manually.

## Assembly Helper (`_assemble!`)

All 7 public `*_assemble` functions delegate to one private helper:

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    dofs = ndofs
    @views begin
        K[(i - 1) * dofs + 1:i * dofs, (i - 1) * dofs + 1:i * dofs] += k[1:dofs, 1:dofs]
        K[(i - 1) * dofs + 1:i * dofs, (j - 1) * dofs + 1:j * dofs] += k[1:dofs, dofs + 1:2 * dofs]
        K[(j - 1) * dofs + 1:j * dofs, (i - 1) * dofs + 1:i * dofs] += k[dofs + 1:2 * dofs, 1:dofs]
        K[(j - 1) * dofs + 1:j * dofs, (j - 1) * dofs + 1:j * dofs] += k[dofs + 1:2 * dofs, dofs + 1:2 * dofs]
    end
    return K
end
```

This maps 4 element-level blocks (ii, jj, ii→jj, jj→ii) to the global stiffness matrix using block indices based on `dofs`. Uses `@views` for efficient slice operations. Works for any DOF count:

This maps 4 element-level blocks (ii, jj, ii→jj, jj→ii) to the global stiffness matrix using block indices based on `dofs`. It works for any DOF count:

| `dofs` | Used by |
|--------|---------|
| `1` | `d1_spring_assemble`, `d1_truss_assemble` |
| `2` | `d2_spring_assemble`, `d2_truss_assemble` |
| `3` | `d2_planeframe_assemble`, `d3_spring_assemble`, `d3_truss_assemble` |
| `6` | `d3_spaceframe_assemble` |

The helper is private (underscore prefix, not exported). Adding new element types requires only passing the correct `dofs` parameter — no new assembly boilerplate.

## Complete Function Inventory

### 1D Spring (`d1_spring`)
- `d1_spring_elementstiffness(k)` — 2×2 matrix
- `d1_spring_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_spring_elementforce(k, u)` — 2-element vector

### 1D Quadratic Bar (`d1_quadraticbar`)
- `d1_quadraticbar_elementlength(x1, x2)` — element length (absolute difference)
- `d1_quadraticbar_elementstiffness(E, A, L)` — 3×3 matrix (validates `L > 0`, `A > 0`)
- `d1_quadraticbar_assemble(K, k, i, j, m)` — custom assembly for 3-node element (DOF mapping: 1)
- `d1_quadraticbar_elementforces(Ke, u)` — 3-element vector
- `d1_quadraticbar_elementstress(Ke, u, A)` — 3-element stress vector (validates `A > 0`)

### 1D Truss (`d1_truss`)
- `d1_truss_elementstiffness(E, A, L)` — 2×2 matrix (validates `L > 0`, `A > 0`)
- `d1_truss_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_truss_elementforces(Ke, u)` — 2-element vector
- `d1_truss_elementstress(Ke, u, A)` — stress at nodes
- `d1_truss_elementstrain(L, u)` — strain at nodes (validates `L > 0`)

### 2D Spring (`d2_spring`)
- `d2_spring_elementstiffness(k, theta)` — 4×4 matrix
- `d2_spring_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_spring_elementforce(k, theta, u)` — scalar force

### 2D Truss (`d2_truss`)
- `d2_truss_elementstiffness(E, A, L, theta)` — 4×4 matrix (validates `L > 0`)
- `d2_truss_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_truss_elementforces(E, A, L, theta, u)` — scalar force
- `d2_truss_elementstress(E, L, theta, u)` — scalar stress
- `d2_truss_elementstrain(L, theta, u)` — scalar strain (validates `L > 0`)
- `d2_truss_elementlength(x1, y1, x2, y2)` — element length

### 2D Pure Beam (`d2_beam`)
- `d2_beam_elementstiffness(E, I, L)` — 4×4 matrix (Euler-Bernoulli, bending only; validates `L > 0`)
- `d2_beam_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_beam_elementforces(k, u)` — 4-element force vector (shear + moment at nodes)
- `d2_beam_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_beam_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 2D Plane Frame (`d2_planeframe`)
- `d2_planeframe_elementlength(x1, y1, x2, y2)` — element length
- `d2_planeframe_elementstiffness(E, A, I, L, theta)` — 6×6 matrix (axial + bending; validates `L > 0`)
- `d2_planeframe_assemble(K, k, i, j)` — DOF mapping: 3
- `d2_planeframe_elementforces(E, A, I, L, theta, u)` — 6-element vector
- `d2_planeframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d2_planeframe_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_planeframe_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 3D Spring (`d3_spring`)
- `d3_spring_elementstiffness(k, thetax, thetay, thetaz)` — 6×6 matrix
- `d3_spring_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_spring_elementforce(k, thetax, thetay, thetaz, u)` — scalar force

### 3D Truss (`d3_truss`)
- `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)` — 6×6 matrix (validates `L > 0`)
- `d3_truss_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)` — scalar force
- `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)` — scalar stress
- `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)` — scalar strain (validates `L > 0`)
- `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` — element length

### 3D Space Frame (`d3_spaceframe`)
- `d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)` — 3D Euclidean distance (validates `L > 0`)
- `d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` — 12×12 matrix (validates `L > 0`)
- `d3_spaceframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d3_spaceframe_elementshearydiagram(f, L)` — Plots.jl shear force (Y) diagram
- `d3_spaceframe_elementshearzdiagram(f, L)` — Plots.jl shear force (Z) diagram
- `d3_spaceframe_elementmomentydiagram(f, L)` — Plots.jl bending moment (Y) diagram
- `d3_spaceframe_elementmomentzdiagram(f, L)` — Plots.jl bending moment (Z) diagram
- `d3_spaceframe_elementtorsiondiagram(f, L)` — Plots.jl torsion diagram

  **Note**: The 3D space frame uses a 12×12 local stiffness matrix with an embedded 3×3 rotation matrix `Λ` built from node coordinates (not angle parameters). `Iy` governs bending about the y-axis (δz, θy), `Iz` governs bending about the z-axis (δy, θz). The vertical-element degenerate case (`D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`) is handled automatically.

### 1D Bar / Linear Bar (`d1_bar`)
- `d1_bar_elementstiffness(E, A, L)` — 2×2 matrix (validates `L > 0`, `A > 0`)
- `d1_bar_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_bar_elementforces(Ke, u)` — 2-element vector
- `d1_bar_elementstress(Ke, u, A)` — stress at nodes (validates `A > 0`)
- `d1_bar_elementstrain(L, u)` — strain at nodes (validates `L > 0`)

### 2D Grid (`d2_grid`)
- `d2_grid_elementlength(x1, y1, x2, y2)` — element length
- `d2_grid_elementstiffness(E, I, L, theta)` — 6×6 matrix (out-of-plane bending + torsion; validates `L > 0`)
- `d2_grid_elementforces(E, I, L, theta, u)` — 6-element force vector
- `d2_grid_assemble(K, k, i, j)` — DOF mapping: 3

### 1D Fluid Flow (`d1_fluidflow`)
- `d1_fluidflow_elementstiffness(E, A, L)` — 2×2 matrix (validates `L > 0`, `A > 0`)
- `d1_fluidflow_elementvelocity(Ke, u)` — 2-element velocity vector
- `d1_fluidflow_elementvfr(Ke, u)` — volume flow rate
- `d1_fluidflow_assemble(K, k, i, j)` — DOF mapping: 1

### 2D Constant Strain Triangle (CST, `d2_cst`)
- `d2_cst_elementarea(x1, y1, x2, y2, x3, y3)` — signed triangle area
- `d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p)` — 6×6 matrix (plane stress/strain; `p=1` stress, `p=2` strain)
- `d2_cst_elementstress(E, NU, t, x1, y1, x2, y2, x3, y3, p, u)` — 3-element stress vector
- `d2_cst_elementpstress(E, NU, t, x1, y1, x2, y2, x3, y3, p, u)` — 3-element principal stress vector
- `d2_cst_assemble(K, k, i, j, m)` — custom assembly for 3-node element (DOF mapping: 2)

### 2D Linear Strain Triangle (LST, `d2_lst`)
- `d2_lst_elementstiffness(E, NU, t, x1, y1, ..., x6, y6, p)` — 12×12 matrix (6 nodes, 2 DOF/node; plane stress/strain)
- `d2_lst_elementstress(E, NU, t, x1, y1, ..., x6, y6, p, u)` — 3-element stress vector
- `d2_lst_elementpstress(E, NU, t, x1, y1, ..., x6, y6, p, u)` — 3-element principal stress vector
- `d2_lst_assemble(K, k, i, j, m, n, o)` — custom assembly for 6-node element (DOF mapping: 2)

### 2D Bilinear Quadrilateral (Q4, `d2_q4`)
- `d2_q4_elementarea(x1, y1, x2, y2, x3, y3, x4, y4)` — quadrilateral area (CCW positive)
- `d2_q4_elementstiffness(E, NU, h, x1, y1, ..., x4, y4, p)` — 8×8 matrix (4 nodes, 2 DOF/node; 2×2 Gauss quadrature)
- `d2_q4_elementstress(E, NU, h, x1, y1, ..., x4, y4, p, u)` — 3-element stress vector
- `d2_q4_elementpstress(E, NU, h, x1, y1, ..., x4, y4, p, u)` — 3-element principal stress vector
- `d2_q4_assemble(K, k, i, j, m, n)` — custom assembly for 4-node element (DOF mapping: 2)

### 2D Quadratic Quadrilateral (Q8, `d2_q8`)
- `d2_q8_elementstiffness(E, NU, h, x1, y1, ..., x8, y8, p)` — 16×16 matrix (8 nodes, 2 DOF/node; 3×3 Gauss quadrature, serendipity)
- `d2_q8_elementstress(E, NU, h, x1, y1, ..., x8, y8, p, u)` — 3-element stress vector
- `d2_q8_elementpstress(E, NU, h, x1, y1, ..., x8, y8, p, u)` — 3-element principal stress vector
- `d2_q8_assemble(K, k, i, j, m, n, o, p)` — custom assembly for 8-node element (DOF mapping: 2)

### 3D Linear Brick (B8, `d3_brick`)
- `d3_brick_elementvolume(x1, y1, z1, ..., x8, y8, z8)` — 8-node hexahedron volume
- `d3_brick_elementstiffness(E, NU, x1, y1, z1, ..., x8, y8, z8)` — 24×24 matrix (8 nodes, 3 DOF/node; 2×2×2 Gauss quadrature)
- `d3_brick_elementstress(E, NU, x1, y1, z1, ..., x8, y8, z8, u)` — 6-element stress vector
- `d3_brick_elementpstress(E, NU, x1, y1, z1, ..., x8, y8, z8, u)` — 6-element principal stress vector
- `d3_brick_assemble(K, k, i, j, m, n, o, p)` — custom assembly for 8-node element (DOF mapping: 3)

### 3D Linear Tetrahedron (T4, `d3_tet`)
- `d3_tet_elementvolume(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)` — 4-node tetrahedron volume
- `d3_tet_elementstiffness(E, NU, x1, y1, z1, ..., x4, y4, z4)` — 12×12 matrix (4 nodes, 3 DOF/node)
- `d3_tet_elementstress(E, NU, x1, y1, z1, ..., x4, y4, z4, u)` — 6-element stress vector
- `d3_tet_elementpstress(E, NU, x1, y1, z1, ..., x4, y4, z4, u)` — 6-element principal stress vector
- `d3_tet_assemble(K, k, i, j, m, n)` — custom assembly for 4-node element (DOF mapping: 3)

### 1D Spring (`d1_spring`)
- `d1_spring_elementstiffness(k)` — 2×2 matrix
- `d1_spring_assemble(K, k, i, j)` — DOF mapping: 1
- `d1_spring_elementforce(k, u)` — 2-element vector

### 1D Quadratic Bar (`d1_quadraticbar`)
- `d1_quadraticbar_elementlength(x1, x2)` — element length (absolute difference)
- `d1_quadraticbar_elementstiffness(E, A, L)` — 3×3 matrix (validates `L > 0`, `A > 0`)
- `d1_quadraticbar_assemble(K, k, i, j, m)` — custom assembly for 3-node element (DOF mapping: 1)
- `d1_quadraticbar_elementforces(Ke, u)` — 3-element vector
- `d1_quadraticbar_elementstress(Ke, u, A)` — 3-element stress vector (validates `A > 0`)

### 2D Spring (`d2_spring`)
- `d2_spring_elementstiffness(k, theta)` — 4×4 matrix
- `d2_spring_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_spring_elementforce(k, theta, u)` — scalar force

### 2D Truss (`d2_truss`)
- `d2_truss_elementstiffness(E, A, L, theta)` — 4×4 matrix (validates `L > 0`)
- `d2_truss_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_truss_elementforces(E, A, L, theta, u)` — scalar force
- `d2_truss_elementstress(E, L, theta, u)` — scalar stress
- `d2_truss_elementstrain(L, theta, u)` — scalar strain (validates `L > 0`)
- `d2_truss_elementlength(x1, y1, x2, y2)` — element length

### 2D Pure Beam (`d2_beam`)
- `d2_beam_elementstiffness(E, I, L)` — 4×4 matrix (Euler-Bernoulli, bending only; validates `L > 0`)
- `d2_beam_assemble(K, k, i, j)` — DOF mapping: 2
- `d2_beam_elementforces(k, u)` — 4-element force vector (shear + moment at nodes)
- `d2_beam_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_beam_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 2D Plane Frame (`d2_planeframe`)
- `d2_planeframe_elementlength(x1, y1, x2, y2)` — element length
- `d2_planeframe_elementstiffness(E, A, I, L, theta)` — 6×6 matrix (axial + bending; validates `L > 0`)
- `d2_planeframe_assemble(K, k, i, j)` — DOF mapping: 3
- `d2_planeframe_elementforces(E, A, I, L, theta, u)` — 6-element vector
- `d2_planeframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d2_planeframe_elementsheardiagram(f, L)` — Plots.jl shear force diagram
- `d2_planeframe_elementmomentdiagram(f, L)` — Plots.jl bending moment diagram

### 3D Spring (`d3_spring`)
- `d3_spring_elementstiffness(k, thetax, thetay, thetaz)` — 6×6 matrix
- `d3_spring_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_spring_elementforce(k, thetax, thetay, thetaz, u)` — scalar force

### 3D Truss (`d3_truss`)
- `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)` — 6×6 matrix (validates `L > 0`)
- `d3_truss_assemble(K, k, i, j)` — DOF mapping: 3
- `d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)` — scalar force
- `d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)` — scalar stress
- `d3_truss_elementstrain(L, thetax, thetay, thetaz, u)` — scalar strain (validates `L > 0`)
- `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` — element length

### 3D Space Frame (`d3_spaceframe`)
- `d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)` — 3D Euclidean distance (validates `L > 0`)
- `d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)` — 12×12 matrix (validates `L > 0`)
- `d3_spaceframe_assemble(K, k, i, j)` — DOF mapping: 6
- `d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)` — 12-element force vector
- `d3_spaceframe_elementaxialdiagram(f, L)` — Plots.jl axial force diagram
- `d3_spaceframe_elementshearydiagram(f, L)` — Plots.jl shear force (Y) diagram
- `d3_spaceframe_elementshearzdiagram(f, L)` — Plots.jl shear force (Z) diagram
- `d3_spaceframe_elementmomentydiagram(f, L)` — Plots.jl bending moment (Y) diagram
- `d3_spaceframe_elementmomentzdiagram(f, L)` — Plots.jl bending moment (Z) diagram
- `d3_spaceframe_elementtorsiondiagram(f, L)` — Plots.jl torsion diagram

  **Note**: The 3D space frame uses a 12×12 local stiffness matrix with an embedded 3×3 rotation matrix `Λ` built from node coordinates (not angle parameters). `Iy` governs bending about the y-axis (δz, θy), `Iz` governs bending about the z-axis (δy, θz). The vertical-element degenerate case (`D = y₂ - y₁ = 0` and `z₂ - z₁ = 0`) is handled automatically.

### Deprecated Aliases (v0.3.0+)
The 1D linear bar was renamed from `d1_truss_*` to `d1_bar_*` to match the MATLAB `LinearBar` naming convention. Deprecated aliases with `@deprecate`:
- `d1_truss_elementstiffness` → `d1_bar_elementstiffness`
- `d1_truss_elementforces` → `d1_bar_elementforces`
- `d1_truss_elementstress` → `d1_bar_elementstress`
- `d1_truss_elementstrain` → `d1_bar_elementstrain`
- `d1_truss_assemble` → `d1_bar_assemble`

## Dependencies & Runtime Notes

- **`Plots.jl`** v1 — a **weak dependency** via the Julia package extension `ext/LibFEMPlotsExt.jl`. `Project.toml` declares it under `[weakdeps]` (not `[deps]`) and the extension block `LibFEMPlotsExt = ["Plots"]`. Loading LibFEM alone installs stub throwers for every diagram symbol that raise `DiagramError`; loading `Plots` in the same session activates the extension and replaces the stubs with Plots-backed implementations (same exported names, no API change for callers).
- **`LinearAlgebra`** — declared as a hard dep in `[deps]` (Julia 1.12.0 compat). The module does not `using LinearAlgebra` explicitly because the relevant operations (transpose, conjugates) are reached via `LinearAlgebra`'s methods on AbstractMatrix, but the dep is declared so downstream code that does `using LinearAlgebra` after `using LibFEM` gets the correct version.
- **`deg2rad` is imported from `Base`** via `import Base: deg2rad` in `src/LibFEM.jl`, making it available in the module namespace on all Julia 1.x versions. It is not re-exported — users call `deg2rad(theta)` directly from `Base`.

## Testing

Tests are in `test/`:
- **`runtests.jl`** — Main test suite (~1054 lines). Uses `Test` standard library plus `LinearAlgebra`. Covers all 10 element types (including `d3_spaceframe` and `d1_quadraticbar`) with stiffness matrix shape/symmetry checks, force/stress/strain numeric validation, assembly correctness, and MATLAB reference comparison for Problem 10.1. Includes `include` of `property_tests.jl` and `golden_regression.jl`. The new validation contracts (zero `k`, zero `L`) are asserted via `@test_throws ElementParameterError` (e.g. `d2_spring_elementstiffness(0, 30)`, `d3_truss_elementlength(0,0,0,0,0,0)`, `d3_spaceframe_elementlength(0,0,0,0,0,0)`). Several testsets wrap bodies in `Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Error)) do ... end` to suppress the `@warn` emitted by `_direction_cosines` for valid-but-non-unit random triples.
- **`property_tests.jl`** — Property-based tests using `PropCheck.jl` (added to test `[extras]` in commit fea71d7). Asserts symmetry, translational invariance, and zero-stiffness behavior across randomized inputs. The 3D spring/truss section uses a `_rand_3d_angles()` helper that generates spherical-polar samples on the unit sphere (so `Cx²+Cy²+Cz² = 1` by construction) rather than independent uniform angles, because the validation logic auto-normalizes off-unit triples.
- **`benchmark.jl`** — Standalone `BenchmarkTools.jl` suite (12 benchmarks). Covers stiffness construction (10 element types), assembly (500-element d2_truss chain + 500-element d3_spaceframe chain), solve (random SPD system), and d3_spaceframe element forces. Run manually with `julia --project=. test/benchmark.jl`. Not part of CI.
- **`golden_regression.jl`** — Regression test runner that diffs current outputs against `test/golden/v1/`. Binary fixtures in `test/golden/v1/d{2,3}_{spring,truss,spaceframe}_*.bin` are paired with a `manifests.toml` specifying parameters and tolerances; the binary content was regenerated in commit 4f7582f after the 3D direction-cosine normalization fix to track the new (mathematically correct) outputs.
- **`octave_runner.jl`** — Octave runner module for MATLAB validation (used by `scripts/validate-matlab.jl`).
- **`matlab_adapters.jl`** — MATLAB↔Julia argument/result adapters used by the Octave verification harness.

Test-only deps (`Project.toml` `[extras]` `[targets].test`): `BenchmarkTools`, `PropCheck`, `Test`. The `test/Project.toml` workspace holds the test project.

To run tests:
```julia
julia --project=. -e 'using Pkg; Pkg.test()'
# or manually:
# julia --project=. test/runtests.jl
```

**CI**: GitHub Actions (`.github/workflows/ci.yml`) has two jobs: `test` runs unit tests, property tests, and golden regression on Julia 1.12; `validate` runs Octave validation. Other workflows: `benchmarks.yml`, `ocr-review.yml`, `openwiki-update.yml`, `super-linter.yml`.

## Extension Points

When adding a new element type:

1. Implement `d{N}_{domain}_elementstiffness(...)` returning the correct matrix size
2. Implement `d{N}_{domain}_assemble(K, k, i, j)` — a 1-liner calling `_assemble!(K, k, i, j, dofs)`
3. Implement force/stress/strain as appropriate
4. Add `export` after each function
5. Add tests in `test/runtests.jl`

Key invariants to maintain:
- All angles in degrees (use `deg2rad` internally, imported from `Base`)
- Stiffness matrices must be symmetric
- Assembly uses `.+=` (in-place addition) to allow building up the global matrix from multiple elements
- Positive material/geometric parameters (e.g. `L > 0`, `A > 0`, `k > 0`) must be enforced via `validate_positive`; inputs that violate them should throw `ElementParameterError`, not silently produce a zero matrix

## Limitations & Watch-outs

- **No built-in boundary condition or solver functions** — users supply their own `K·U = F` solver (PartitionedArrays-style partitioning, prescribed-DOF stripping, etc. is out of scope). The new `apply_bc!` helper in `src/solver.jl` provides Dirichlet boundary condition application by zeroing rows/columns and setting diagonal to 1, but it's a helper, not a full solver.
- **Diagram functions raise `DiagramError` unless `Plots` is loaded** in the same Julia session. CI scripts (e.g. `lib/problem_wrapper.jl` headless Octave path) override the exported diagram functions in a wrapper module with no-ops so they don't fail on import-time resolution. If you hit `DiagramError` in a script, make sure `using Plots` precedes the call.
- **3D direction cosine inputs** that violate `Cx²+Cy²+Cz² = 1` by more than `1e-12` emit a `@warn` and are auto-normalized; degenerate triples (`Cx²+Cy²+Cz² ≈ 0`) cannot be normalized and pass through unchanged. Prefer deriving angles from node coordinates via `d3_*_elementlength`.
- **No `ModelingToolkit` integration in the library itself.** The example scripts in `examples/mtk/` (`linear_truss_mtk*.jl`) use MTK independently of this project; they are not part of the public API.

