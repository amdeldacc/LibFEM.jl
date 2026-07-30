# ─────────────────────────────────────────────────────────────────
# MATLAB/Octave ↔ Julia Argument & Result Adapters
# ─────────────────────────────────────────────────────────────────
# These functions bridge the gap between Julia's function-call
# conventions and MATLAB .m file function signatures.  They are
# used by the Octave verification harness to prepare Julia-side
# arguments for Octave execution and to convert JSON-decoded
# Octave output back to Julia types.
#
# Conventions:
#   - Angles are in degrees throughout (MATLAB .m files convert
#     internally with theta*pi/180).
#   - Julia and MATLAB both use 1-indexed, column-major storage.
#   - MATLAB returns row vectors where Julia expects column
#     vectors in some cases; adapters reshape accordingly.
#   - MATLAB scalar results (stress, scalar force, length) are
#     wrapped into 1-element Vectors for Julia API consistency.
# ─────────────────────────────────────────────────────────────────

# No external dependencies for production use (Base.vec, Base.reshape).
# `using Test` is loaded unconditionally so the inline test block
# can use @testset/@test when the file is run directly.
using Test

# ═══════════════════════════════════════════════════════════════
# Spring Element — Argument Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   SpringElementStiffness(k)    → 2×2 matrix   (1 arg:  scalar k)
#   SpringElementForces(k, u)    → 2-element vec (2 args: 2×2 k, 2-vec u)
#   SpringAssemble(K, k, i, j)   → mutated K    (4 args: K, k, i, j)
#
# Julia equivalents (d1_spring_*):
#   d1_spring_elementstiffness(k)       — identical signature
#   d1_spring_elementforce(Ke, u)       — identical signature
#   d1_spring_assemble(K, k, i, j)     — identical signature
#   (d2_spring_* and d3_spring_* use additional angle arguments)

"""
    adapt_spring_args(k) -> Tuple

Prepare Julia arguments for `SpringElementStiffness(k)`.
MATLAB: 1 arg (scalar stiffness k).
Julia:  1 arg (scalar k).
"""
adapt_spring_args(k) = (k,)

"""
    adapt_spring_args(k, u) -> Tuple

Prepare Julia arguments for `SpringElementForces(k, u)`.
MATLAB: 2 args (2×2 stiffness matrix k, 2-element disp vector u).
Julia:  identical to `d1_spring_elementforce(Ke, u)`.
"""
adapt_spring_args(k, u) = (k, u)

"""
    adapt_spring_args(K, k, i, j) -> Tuple

Prepare Julia arguments for `SpringAssemble(K, k, i, j)`.
MATLAB: 4 args (global K, 2×2 element k, node indices i, j).
"""
adapt_spring_args(K, k, i, j) = (K, k, i, j)

# ═══════════════════════════════════════════════════════════════
# Spring Element — Result Adapter
# ═══════════════════════════════════════════════════════════════

"""
    adapt_spring_result(arr, n=2) -> Union{Matrix, Vector, Number}

Convert a JSON-decoded Octave array for a spring-element result
back to the Julia type.

MATLAB returns:
  - Stiffness: 2×2 matrix (column-major → 4-element flat array)
  - Forces:    2×1 column vector

# Arguments
- `arr`: Array from JSON-decoded Octave output (or scalar number).
- `n`:   Total DOF for this element (default 2 for 1D spring).

# Examples
```julia
julia> adapt_spring_result([100.0, -100.0, -100.0, 100.0], 2)
2×2 Matrix{Float64}:
  100  -100
 -100   100
```
"""
function adapt_spring_result(arr, n::Int=2)
    if isa(arr, Number)
        # Scalar from Octave → wrap in 1-element Vector
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Truss / Bar Element — Argument Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (three sub-families):
#
#   ─ LinearBar (1D) ─
#     LinearBarElementStiffness(E, A, L)      → 2×2 matrix  (3 scalars)
#     LinearBarElementForces(k, u)             → 2-vec       (2×2 k, 2-vec u)
#     LinearBarElementStresses(k, u, A)        → 2-vec       (2×2 k, 2-vec u, scalar A)
#     LinearBarAssemble(K, k, i, j)            → mutated K
#
#   ─ PlaneTruss (2D) ─
#     PlaneTrussElementLength(x1, y1, x2, y2) → scalar      (4 coordinates)
#     PlaneTrussElementStiffness(E, A, L, θ)   → 4×4 matrix  (4 scalars)
#     PlaneTrussElementForce(E, A, L, θ, u)    → scalar      (4 scalars + 4-vec u)
#     PlaneTrussElementStress(E, L, θ, u)      → scalar      (3 scalars + 4-vec u)
#     PlaneTrussAssemble(K, k, i, j)           → mutated K
#
#   ─ SpaceTruss (3D) ─
#     SpaceTrussElementLength(x1, y1, z1, x2, y2, z2) → scalar (6 coords)
#     SpaceTrussElementStiffness(E, A, L, θx, θy, θz) → 6×6    (6 scalars)
#     SpaceTrussElementForce(E, A, L, θx, θy, θz, u) → scalar  (6 + u)
#     SpaceTrussElementStress(E, L, θx, θy, θz, u) → scalar    (5 + u)
#     SpaceTrussAssemble(K, k, i, j)                   → mutated K
#
# Julia equivalents (d{1,2,3}_truss_*):
#   d1_bar_elementstiffness(E, A, L)      — identical
#   d1_bar_elementforces(Ke, u)           — identical
#   d1_bar_elementstress(Ke, u, A)        — identical
#   d2_truss_elementstiffness(E, A, L, θ)   — identical
#   d2_truss_elementforces(E, A, L, θ, u)   — 1-element vector (MATLAB: scalar)
#   d2_truss_elementstress(E, L, θ, u)      — 1-element vector (MATLAB: scalar)
#   d3_truss_* — analogous
# ───────────────────────────────────────────────────────────────

# --- LinearBar / 1D Truss ---

"""
    adapt_truss_args(E, A, L) -> Tuple

Prepare Julia arguments for `LinearBarElementStiffness(E, A, L)`.
MATLAB: 3 scalars (E, A, L).
Julia:  `d1_bar_elementstiffness(E, A, L)` — identical.
"""
adapt_truss_args(E::Real, A::Real, L::Real) = (E, A, L)

"""
    adapt_truss_args(k, u) -> Tuple

Prepare Julia arguments for `LinearBarElementForces(k, u)`.
MATLAB: 2 args (2×2 stiffness k, 2-element disp u).
Julia:  `d1_bar_elementforces(Ke, u)` — identical.
"""
adapt_truss_args(k::AbstractMatrix, u::AbstractVector) = (k, u)

"""
    adapt_truss_args(k, u, A) -> Tuple

Prepare Julia arguments for `LinearBarElementStresses(k, u, A)`.
MATLAB: 3 args (2×2 k, 2-vec u, scalar A).
Julia:  `d1_bar_elementstress(Ke, u, A)` — identical.
"""
adapt_truss_args(k::AbstractMatrix, u::AbstractVector, A::Real) = (k, u, A)

# --- PlaneTruss / 2D Truss ---

"""
    adapt_truss_args(E, A, L, theta) -> Tuple

Prepare Julia arguments for `PlaneTrussElementStiffness(E, A, L, theta)`.
MATLAB: 4 scalars (E, A, L, θ in degrees).
Julia:  `d2_truss_elementstiffness(E, A, L, theta)` — identical.
"""
adapt_truss_args(E::Real, A::Real, L::Real, theta::Real) = (E, A, L, theta)

"""
    adapt_truss_args(E, A, L, theta, u) -> Tuple

Prepare Julia arguments for `PlaneTrussElementForce(E, A, L, theta, u)`.
MATLAB: 5 args (4 scalars + 4-element disp vector).
Julia:  `d2_truss_elementforces(E, A, L, theta, u)`.
"""
adapt_truss_args(E::Real, A::Real, L::Real, theta::Real, u::AbstractVector) = (E, A, L, theta, u)

"""
    adapt_truss_args(E, L, theta, u) -> Tuple

Prepare Julia arguments for `PlaneTrussElementStress(E, L, theta, u)`.
MATLAB: 4 args (3 scalars + 4-element disp vector).
Julia:  `d2_truss_elementstress(E, L, theta, u)`.
"""
adapt_truss_args(E::Real, L::Real, theta::Real, u::AbstractVector) = (E, L, theta, u)

# --- SpaceTruss / 3D Truss ---

"""
    adapt_truss_args(E, A, L, thetax, thetay, thetaz) -> Tuple

Prepare Julia arguments for `SpaceTrussElementStiffness(E, A, L, θx, θy, θz)`.
MATLAB: 6 scalars.
Julia:  `d3_truss_elementstiffness(E, A, L, θx, θy, θz)` — identical.
"""
adapt_truss_args(E::Real, A::Real, L::Real, θx::Real, θy::Real, θz::Real) = (E, A, L, θx, θy, θz)

"""
    adapt_truss_args(E, A, L, thetax, thetay, thetaz, u) -> Tuple

Prepare Julia arguments for `SpaceTrussElementForce(E, A, L, θx, θy, θz, u)`.
MATLAB: 7 args (6 scalars + 6-element disp vector).
Julia:  `d3_truss_elementforces(E, A, L, θx, θy, θz, u)`.
"""
adapt_truss_args(E::Real, A::Real, L::Real, θx::Real, θy::Real, θz::Real, u::AbstractVector) = (E, A, L, θx, θy, θz, u)

"""
    adapt_truss_args(E, L, thetax, thetay, thetaz, u) -> Tuple

Prepare Julia arguments for `SpaceTrussElementStress(E, L, θx, θy, θz, u)`.
MATLAB: 6 args (5 scalars + 6-element disp vector).
Julia:  `d3_truss_elementstress(E, L, θx, θy, θz, u)`.
"""
adapt_truss_args(E::Real, L::Real, θx::Real, θy::Real, θz::Real, u::AbstractVector) = (E, L, θx, θy, θz, u)

# --- Truss Length helpers (separate name to avoid dispatch collision) ---

"""
    adapt_truss_length_args(x1, y1, x2, y2) -> Tuple

Prepare Julia arguments for `PlaneTrussElementLength(x1, y1, x2, y2)`.
MATLAB: 4 coordinates (x1, y1, x2, y2).
Julia:  `d2_truss_elementlength(x1, y1, x2, y2)` — identical.
"""
adapt_truss_length_args(x1::Real, y1::Real, x2::Real, y2::Real) = (x1, y1, x2, y2)

"""
    adapt_truss_length_args(x1, y1, z1, x2, y2, z2) -> Tuple

Prepare Julia arguments for `SpaceTrussElementLength(x1, y1, z1, x2, y2, z2)`.
MATLAB: 6 coordinates.
Julia:  `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)` — identical.
"""
adapt_truss_length_args(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real) = (x1, y1, z1, x2, y2, z2)

# --- Truss Assembly ---

"""
    adapt_truss_args(K, k, i, j) -> Tuple

Prepare Julia arguments for `LinearBarAssemble(K, k, i, j)` /
`PlaneTrussAssemble(K, k, i, j)` / `SpaceTrussAssemble(K, k, i, j)`.
"""
adapt_truss_args(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer) = (K, k, i, j)

# ═══════════════════════════════════════════════════════════════
# Truss Element — Result Adapter
# ═══════════════════════════════════════════════════════════════

"""
    adapt_truss_result(arr, n) -> Union{Matrix, Vector, Number}

Convert a JSON-decoded Octave array for a truss-element result
back to the Julia type.

MATLAB returns:
  - Stiffness: n×n matrix (n=2 LinearBar, n=4 PlaneTruss, n=6 SpaceTruss)
  - Forces:    n-element vector (LinearBar) or scalar (Plane/SpaceTruss)
  - Stress:    n-element vector (LinearBar) or scalar (Plane/SpaceTruss)
  - Length:    scalar

The adapter infers the result type from `length(arr)`:
  - `length(arr) == n*n` → reshape to n×n Matrix (stiffness)
  - `length(arr) == n`   → return as Vector (forces/stress for 1D)
  - scalar               → wrap in 1-element Vector (stress/force yield)

# Arguments
- `arr`: JSON-decoded Octave output (Array or scalar Number).
- `n`:   Total DOF for this element (2, 4, or 6).
"""
function adapt_truss_result(arr, n::Int)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Beam / Frame (2D PlaneFrame) — Argument Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   PlaneFrameElementLength(x1, y1, x2, y2)  → scalar
#   PlaneFrameElementStiffness(E, A, I, L, θ) → 6×6 matrix (5 scalars)
#   PlaneFrameElementForces(E, A, I, L, θ, u) → 6-vec (5 + 6-vec u)
#   PlaneFrameAssemble(K, k, i, j)           → mutated K
#
# Julia equivalents (d2_beam_*):
#   d2_beam_elementstiffness(E, A, I, L, θ) — identical
#   d2_beam_elementforces(E, A, I, L, θ, u) — identical (6-vec)

"""
    adapt_beam_args(E, A, I, L, theta) -> Tuple

Prepare Julia arguments for `PlaneFrameElementStiffness(E, A, I, L, θ)`.
MATLAB: 5 scalars (E, A, I, L, θ in degrees).
Julia:  `d2_beam_elementstiffness(E, A, I, L, theta)` — identical.
"""
adapt_beam_args(E::Real, A::Real, I::Real, L::Real, theta::Real) = (E, A, I, L, theta)

"""
    adapt_beam_args(E, A, I, L, theta, u) -> Tuple

Prepare Julia arguments for `PlaneFrameElementForces(E, A, I, L, θ, u)`.
MATLAB: 6 args (5 scalars + 6-element disp vector).
Julia:  `d2_beam_elementforces(E, A, I, L, theta, u)` — identical.
"""
adapt_beam_args(E::Real, A::Real, I::Real, L::Real, theta::Real, u::AbstractVector) = (E, A, I, L, theta, u)

"""
    adapt_beam_args(x1, y1, x2, y2) -> Tuple

Prepare Julia arguments for `PlaneFrameElementLength(x1, y1, x2, y2)`.
MATLAB: 4 coordinates.
Julia:  `d2_beam_elementlength(x1, y1, x2, y2)` — identical.
"""
adapt_beam_args(x1::Real, y1::Real, x2::Real, y2::Real) = (x1, y1, x2, y2)

"""
    adapt_beam_args(K, k, i, j) -> Tuple

Prepare Julia arguments for `PlaneFrameAssemble(K, k, i, j)`.
MATLAB: 4 args (global K, 6×6 element k, node indices i, j).
"""
adapt_beam_args(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer) = (K, k, i, j)

# ═══════════════════════════════════════════════════════════════
# Beam (2D PlaneFrame) — Result Adapter
# ═══════════════════════════════════════════════════════════════

"""
    adapt_beam_result(arr, n=6) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a 2D beam (plane frame)
result back to the Julia type.

MATLAB returns:
  - Stiffness: 6×6 matrix (36 flat elements)
  - Forces:    6×1 column vector (6 elements)
  - Length:    scalar

# Arguments
- `arr`: JSON-decoded Octave output (Array or scalar).
- `n`:   Total DOF (default 6 for 2D beam with 2 nodes × 3 DOF).
"""
function adapt_beam_result(arr, n::Int=6)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Space Frame (3D Beam) — Argument Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   SpaceFrameElementLength(x1, y1, z1, x2, y2, z2) → scalar
#   SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)
#     → 12×12 matrix (12 scalars — 6 material + 6 coords)
#   SpaceFrameElementForces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)
#     → 12-vector (12 scalars + 12-vec u)
#   SpaceFrameAssemble(K, k, i, j) → mutated K
#
# Julia equivalents (d3_spaceframe_*):
#   d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)
#     — identical signature
#   d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)
#     — identical signature (returns 12-vec in local frame)

"""
    adapt_space_frame_args(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2) -> Tuple

Prepare Julia arguments for `SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)`.
MATLAB: 12 scalars (E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2).
Julia:  `d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)`.
"""
adapt_space_frame_args(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2) = (E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

"""
    adapt_space_frame_args(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u) -> Tuple

Prepare Julia arguments for `SpaceFrameElementForces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)`.
MATLAB: 13 args (12 scalars + 12-element disp vector).
Julia:  `d3_spaceframe_elementforces(...)` — identical.
"""
adapt_space_frame_args(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u) = (E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

"""
    adapt_space_frame_args(x1, y1, z1, x2, y2, z2) -> Tuple

Prepare Julia arguments for `SpaceFrameElementLength(x1, y1, z1, x2, y2, z2)`.
MATLAB: 6 coordinates.
Julia:  `d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)` — identical.
"""
adapt_space_frame_args(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real) = (x1, y1, z1, x2, y2, z2)

"""
    adapt_space_frame_args(K, k, i, j) -> Tuple

Prepare Julia arguments for `SpaceFrameAssemble(K, k, i, j)`.
MATLAB: 4 args (global K, 12×12 element k, node indices i, j).
"""
adapt_space_frame_args(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer) = (K, k, i, j)

# ═══════════════════════════════════════════════════════════════
# Space Frame (3D Beam) — Result Adapter
# ═══════════════════════════════════════════════════════════════

"""
    adapt_space_frame_result(arr, n=12) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a space frame (3D beam)
result back to the Julia type.

MATLAB returns:
  - Stiffness: 12×12 matrix (144 flat elements)
  - Forces:    12×1 column vector (12 elements)
  - Length:    scalar

# Arguments
- `arr`: JSON-decoded Octave output (Array or scalar).
- `n`:   Total DOF (default 12 for 3D beam with 2 nodes × 6 DOF).
"""
function adapt_space_frame_result(arr, n::Int=12)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Simplified dispatch-by-shape adapter
# ═══════════════════════════════════════════════════════════════

"""
    adapt_result(arr, n) -> Union{Matrix, Vector, Number}

Generic result adapter that handles any element family.
Infer output type from array length and DOF count `n`.

This is a convenience wrapper; prefer the family-specific adapters
(`adapt_spring_result`, `adapt_truss_result`, etc.) when the
element type is known.
"""
function adapt_result(arr, n::Int)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# CST (Linear Triangle) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   LinearTriangleElementStiffness(E, NU, t, xi, yi, xj, yj, xm, ym, p) → 6×6
#   LinearTriangleElementArea(xi, yi, xj, yj, xm, ym) → scalar
#   LinearTriangleElementStresses(E, NU, t, xi, yi, xj, yj, xm, ym, p, u) → 3×1
#   LinearTriangleElementPStresses(sigma) → 3 values
#
# Julia equivalents (d2_cst_*):
#   d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p) — identical
#   d2_cst_elementarea(x1, y1, x2, y2, x3, y3) — identical
#   d2_cst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, p, u) — no `t` param

"""
    adapt_cst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p) -> Tuple

Prepare Julia arguments for `LinearTriangleElementStiffness(E, NU, t, xi, yi, xj, yj, xm, ym, p)`.
MATLAB and Julia signatures are identical in structure.
"""
adapt_cst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p) = (E, NU, t, x1, y1, x2, y2, x3, y3, p)

"""
    adapt_cst_area_args(x1, y1, x2, y2, x3, y3) -> Tuple

Prepare Julia arguments for `LinearTriangleElementArea(xi, yi, xj, yj, xm, ym)`.
"""
adapt_cst_area_args(x1, y1, x2, y2, x3, y3) = (x1, y1, x2, y2, x3, y3)

"""
    adapt_cst_stress_args(E, NU, t, x1, y1, x2, y2, x3, y3, p, u) -> Tuple

Prepare Julia arguments for `LinearTriangleElementStresses(E, NU, t, xi, yi, xj, yj, xm, ym, p, u)`.
Note: Julia's `d2_cst_elementstress` does NOT take `t`, but MATLAB does.
This adapter adds `t` for MATLAB compatibility.
"""
adapt_cst_stress_args(E, NU, t, x1, y1, x2, y2, x3, y3, p, u) = (E, NU, t, x1, y1, x2, y2, x3, y3, p, u)

"""
    adapt_cst_result(arr, n=6) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a CST result back to Julia type.
MATLAB returns:
  - Stiffness: 6×6 matrix (36 flat elements)
  - Stress:    3×1 column vector (3 elements)
  - Area:      scalar
"""
function adapt_cst_result(arr, n::Int=6)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# LST (Quad Triangle) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   QuadTriangleElementStiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p) → 12×12
#     (MATLAB computes mid-edge nodes internally via syms)
#   QuadTriangleElementStresses(E, NU, t, x1, y1, x2, y2, x3, y3, p, u) → 3×1
#
# Julia equivalents (d2_lst_*):
#   d2_lst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3,
#                           x4, y4, x5, y5, x6, y6, p)
#     — Julia takes explicit mid-edge coordinates; MATLAB computes them internally.

"""
    adapt_lst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p) -> Tuple

Prepare Julia arguments for `QuadTriangleElementStiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p)`.
MATLAB only takes 3 corner nodes (computes mid-edges internally).
Julia takes 3 corner + 3 mid-edge nodes.
"""
adapt_lst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p) = (E, NU, t, x1, y1, x2, y2, x3, y3, p)

"""
    adapt_lst_result(arr, n=12) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for an LST result back to Julia type.
"""
function adapt_lst_result(arr, n::Int=12)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Q4 (Bilinear Quad) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   BilinearQuadElementStiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) → 8×8
#   BilinearQuadElementArea(x1, y1, x2, y2, x3, y3, x4, y4) → scalar
#
# Julia equivalents (d2_q4_*):
#   d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) — identical
#   d2_q4_elementarea(x1, y1, x2, y2, x3, y3, x4, y4) — identical

"""
    adapt_q4_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) -> Tuple

Prepare Julia arguments for `BilinearQuadElementStiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)`.
MATLAB and Julia signatures are identical.
"""
adapt_q4_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) = (E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)

"""
    adapt_q4_area_args(x1, y1, x2, y2, x3, y3, x4, y4) -> Tuple
"""
adapt_q4_area_args(x1, y1, x2, y2, x3, y3, x4, y4) = (x1, y1, x2, y2, x3, y3, x4, y4)

"""
    adapt_q4_result(arr, n=8) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a Q4 result back to Julia type.
"""
function adapt_q4_result(arr, n::Int=8)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Q8 (Quadratic Quad) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   QuadraticQuadElementStiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) → 16×16
#     (MATLAB computes mid-edge nodes internally via syms)
#
# Julia equivalents (d2_q8_*):
#   d2_q8_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4,
#                          x5, y5, x6, y6, x7, y7, x8, y8, p)
#     — Julia takes explicit mid-edge coordinates; MATLAB computes them internally.

"""
    adapt_q8_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) -> Tuple

Prepare Julia arguments for `QuadraticQuadElementStiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)`.
MATLAB only takes 4 corner nodes (computes mid-edges internally).
Julia takes 4 corner + 4 mid-edge nodes.
"""
adapt_q8_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p) = (E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)

"""
    adapt_q8_result(arr, n=16) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a Q8 result back to Julia type.
"""
function adapt_q8_result(arr, n::Int=16)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Tet (Tetrahedron) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   TetrahedronElementStiffness(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) → 12×12
#   TetrahedronElementVolume(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) → scalar
#
# Julia equivalents (d3_tet_*):
#   d3_tet_elementstiffness(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) — identical
#   d3_tet_elementvolume(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) — identical

"""
    adapt_tet_args(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) -> Tuple

Prepare Julia arguments for `TetrahedronElementStiffness(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)`.
MATLAB and Julia are identical.
"""
adapt_tet_args(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) = (E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)

"""
    adapt_tet_volume_args(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) -> Tuple
"""
adapt_tet_volume_args(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) = (x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)

"""
    adapt_tet_result(arr, n=12) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a Tet result back to Julia type.
"""
function adapt_tet_result(arr, n::Int=12)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Brick (Linear Brick) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   LinearBrickElementStiffness(E, NU, x1, y1, z1, ..., x8, y8, z8) → 24×24
#   LinearBrickElementVolume(x1, y1, z1, ..., x8, y8, z8) → scalar
#
# Julia equivalents (d3_brick_*):
#   d3_brick_elementstiffness(E, NU, x1, y1, z1, ..., x8, y8, z8) — identical

"""
    adapt_brick_args(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
                     x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8) -> Tuple

Prepare Julia arguments for `LinearBrickElementStiffness(...)`.
MATLAB and Julia are identical.
"""
adapt_brick_args(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
                 x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8) = (E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8)

"""
    adapt_brick_volume_args(x1, y1, z1, ..., x8, y8, z8) -> Tuple
"""
adapt_brick_volume_args(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
                         x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8) = (x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8)

"""
    adapt_brick_result(arr, n=24) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a Brick result back to Julia type.
"""
function adapt_brick_result(arr, n::Int=24)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Grid Element (2D Plane Grid) — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   GridElementLength(x1, y1, x2, y2) → scalar
#   GridElementStiffness(E, G, I, J, L, θ) → 6×6 matrix (6 scalars)
#   GridElementForces(E, G, I, J, L, θ, u) → 6-vec (6 scalars + 6-vec u)
#   GridAssemble(K, k, i, j) → mutated K
#
# Julia equivalents (d2_grid_*):
#   d2_grid_elementlength(x1, y1, x2, y2) — identical
#   d2_grid_elementstiffness(E, G, I, J, L, θ) — identical
#   d2_grid_elementforces(E, G, I, J, L, θ, u) — identical

"""
    adapt_grid_args(E, G, I, J, L, theta) -> Tuple

Prepare Julia arguments for `GridElementStiffness(E, G, I, J, L, θ)`.
MATLAB: 6 scalars (E, G, I, J, L, θ in degrees).
Julia:  `d2_grid_elementstiffness(E, G, I, J, L, theta)` — identical.
"""
adapt_grid_args(E::Real, G::Real, I::Real, J::Real, L::Real, theta::Real) = (E, G, I, J, L, theta)

"""
    adapt_grid_args(E, G, I, J, L, theta, u) -> Tuple

Prepare Julia arguments for `GridElementForces(E, G, I, J, L, θ, u)`.
MATLAB: 7 args (6 scalars + 6-element disp vector).
Julia:  `d2_grid_elementforces(E, G, I, J, L, theta, u)` — identical.
"""
adapt_grid_args(E::Real, G::Real, I::Real, J::Real, L::Real, theta::Real, u::AbstractVector) = (E, G, I, J, L, theta, u)

"""
    adapt_grid_args(x1, y1, x2, y2) -> Tuple

Prepare Julia arguments for `GridElementLength(x1, y1, x2, y2)`.
MATLAB: 4 coordinates.
Julia:  `d2_grid_elementlength(x1, y1, x2, y2)` — identical.
"""
adapt_grid_args(x1::Real, y1::Real, x2::Real, y2::Real) = (x1, y1, x2, y2)

"""
    adapt_grid_args(K, k, i, j) -> Tuple

Prepare Julia arguments for `GridAssemble(K, k, i, j)`.
MATLAB: 4 args (global K, 6×6 element k, node indices i, j).
"""
adapt_grid_args(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer) = (K, k, i, j)

"""
    adapt_grid_result(arr, n=6) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a grid element result back to Julia type.

MATLAB returns:
  - Stiffness: 6×6 matrix (36 flat elements)
  - Forces:    6×1 column vector (6 elements)
  - Length:    scalar

# Arguments
- `arr`: JSON-decoded Octave output (Array or scalar).
- `n`:   Total DOF (default 6 for grid with 2 nodes × 3 DOF).
"""
function adapt_grid_result(arr, n::Int=6)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Fluid Flow 1D — Argument & Result Adapters
# ═══════════════════════════════════════════════════════════════
#
# MATLAB function signatures (from Doc/Kattan/M-Files/):
#   FluidFlow1DElementStiffness(Kxx, A, L) → 2×2
#   FluidFlow1DElementVelocities(Kxx, L, p) → scalar
#   FluidFlow1DElementVFR(Kxx, L, p, A) → scalar
#
# Julia equivalents (d1_fluidflow_*):
#   d1_fluidflow_elementstiffness(Kxx, A, L) — identical
#   d1_fluidflow_elementvelocity(Kxx, L, p) — identical
#   d1_fluidflow_elementvfr(Kxx, L, p, A) — identical

"""
    adapt_fluidflow_args(Kxx, A, L) -> Tuple

Prepare Julia arguments for `FluidFlow1DElementStiffness(Kxx, A, L)`.
MATLAB and Julia signatures are identical.
"""
adapt_fluidflow_args(Kxx, A, L) = (Kxx, A, L)

"""
    adapt_fluidflow_velocity_args(Kxx, L, p) -> Tuple
"""
adapt_fluidflow_velocity_args(Kxx, L, p) = (Kxx, L, p)

"""
    adapt_fluidflow_vfr_args(Kxx, L, p, A) -> Tuple
"""
adapt_fluidflow_vfr_args(Kxx, L, p, A) = (Kxx, L, p, A)

"""
    adapt_fluidflow_result(arr, n=2) -> Union{Matrix, Vector}

Convert a JSON-decoded Octave array for a FluidFlow result back to Julia type.
"""
function adapt_fluidflow_result(arr, n::Int=2)
    if isa(arr, Number)
        return [arr]
    elseif length(arr) == n * n
        return reshape(arr, n, n)
    else
        return vec(arr)
    end
end

# ═══════════════════════════════════════════════════════════════
# Verification (run with: julia --project=. test/matlab_adapters.jl)
# ═══════════════════════════════════════════════════════════════

if abspath(PROGRAM_FILE) == @__FILE__
    @testset "matlab_adapters" begin

        # ── Spring argument packaging ──
        @test adapt_spring_args(100) == (100,)
        @test adapt_spring_args(100, 200) == (100, 200)

        # ── Spring result (stiffness: 2×2) ──
        result_2x2 = adapt_spring_result([100.0, -100.0, -100.0, 100.0], 2)
        @test result_2x2 ≈ [100 -100; -100 100]
        @test size(result_2x2) == (2, 2)

        # ── Spring result (forces: 2-vector) ──
        result_2vec = adapt_spring_result([4.444, -4.444], 2)
        @test result_2vec ≈ [4.444, -4.444]
        @test length(result_2vec) == 2

        # ── Scalar result (stress → wrap as 1-element vector) ──
        @test adapt_spring_result(42.0, 2) == [42.0]

        # ── Truss argument packaging ──
        @test adapt_truss_args(200e9, 0.01, 5.0) == (200e9, 0.01, 5.0)
        @test adapt_truss_args(200e9, 0.01, 5.0, 30.0) == (200e9, 0.01, 5.0, 30.0)
        @test adapt_truss_args(200e9, 0.01, 5.0, 0.0, 45.0, 90.0) == (200e9, 0.01, 5.0, 0.0, 45.0, 90.0)

        # ── Truss result: 4×4 stiffness matrix ──
        flat_4x4 = collect(1.0:16.0)
        r4 = adapt_truss_result(flat_4x4, 4)
        @test size(r4) == (4, 4)
        @test r4[1, 1] ≈ 1.0
        @test r4[4, 4] ≈ 16.0

        # ── Beam argument packaging ──
        @test adapt_beam_args(210e6, 0.04, 4e-6, 4.0, 0.0) == (210e6, 0.04, 4e-6, 4.0, 0.0)

        # ── Beam result: 6×6 stiffness matrix ──
        flat_6x6 = collect(1.0:36.0)
        r6 = adapt_beam_result(flat_6x6, 6)
        @test size(r6) == (6, 6)
        @test r6[1, 1] ≈ 1.0
        @test r6[6, 6] ≈ 36.0

        # ── Space frame argument packaging ──
        args = adapt_space_frame_args(210e6, 84e6, 0.02, 10e-5, 20e-5, 5e-5, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0)
        @test length(args) == 12
        @test args[1] == 210e6
        @test args[12] == 0.0

        # ── Space frame result: 12×12 stiffness matrix ──
        flat_12x12 = collect(1.0:144.0)
        r12 = adapt_space_frame_result(flat_12x12, 12)
        @test size(r12) == (12, 12)
        @test r12[1, 1] ≈ 1.0
        @test r12[12, 12] ≈ 144.0

        # ── Space frame result: 12-vector forces ──
        flat_12vec = collect(1.0:12.0)
        r12v = adapt_space_frame_result(flat_12vec, 12)
        @test length(r12v) == 12
        @test r12v[1] ≈ 1.0
        @test r12v[12] ≈ 12.0

        # ── Generic adapt_result ──
        @test adapt_result(5.0, 4) == [5.0]  # scalar → 1-element vector
        @test size(adapt_result(collect(1.0:16.0), 4)) == (4, 4)  # matrix
        @test length(adapt_result(collect(1.0:4.0), 4)) == 4       # vector

        # ── Truss length args ──
        @test adapt_truss_length_args(0.0, 0.0, 3.0, 4.0) == (0.0, 0.0, 3.0, 4.0)
        @test adapt_truss_length_args(0.0, 0.0, 0.0, 1.0, 1.0, 1.0) == (0.0, 0.0, 0.0, 1.0, 1.0, 1.0)

        # ── Force/stress arg adapters ──
        u = [1.0, 0.0, 0.0, 0.0]
        @test adapt_truss_args(200e9, 0.01, 5.0, 30.0, u) == (200e9, 0.01, 5.0, 30.0, u)
        @test adapt_truss_args(200e9, 5.0, 30.0, u) == (200e9, 5.0, 30.0, u)

        u6 = zeros(6)
        @test length(adapt_truss_args(200e9, 0.01, 5.0, 0.0, 45.0, 90.0, u6)) == 7
        @test length(adapt_truss_args(200e9, 5.0, 0.0, 45.0, 90.0, u6)) == 6

        # ── Beam force args ──
        u6b = zeros(6)
        @test adapt_beam_args(210e6, 0.04, 4e-6, 4.0, 90.0, u6b) == (210e6, 0.04, 4e-6, 4.0, 90.0, u6b)

        # ── Space frame force args ──
        u12 = zeros(12)
        @test length(adapt_space_frame_args(210e6, 84e6, 0.02, 10e-5, 20e-5, 5e-5, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, u12)) == 13

        # ── Assembly arg adapters ──
        K2 = zeros(2, 2)
        k2 = [100 -100; -100 100]
        @test adapt_spring_args(K2, k2, 1, 2) == (K2, k2, 1, 2)

        K4 = zeros(4, 4)
        k4 = rand(4, 4)
        @test adapt_truss_args(K4, k4, 1, 2) == (K4, k4, 1, 2)
        @test adapt_beam_args(K4, k4, 1, 2) == (K4, k4, 1, 2)

        K12 = zeros(12, 12)
        k12 = rand(12, 12)
        @test adapt_space_frame_args(K12, k12, 1, 2) == (K12, k12, 1, 2)

        # ── Beam length args ──
        @test adapt_beam_args(0.0, 0.0, 3.0, 4.0) == (0.0, 0.0, 3.0, 4.0)

        # ── Space frame length args ──
        @test adapt_space_frame_args(0.0, 0.0, 0.0, 4.0, 0.0, 0.0) == (0.0, 0.0, 0.0, 4.0, 0.0, 0.0)
    end

    println("✅ All adapter tests passed.")
end
