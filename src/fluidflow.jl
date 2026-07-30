# ═══════════════════════════════════════════════════════════
# Ch17: Fluid Flow / Seepage Element (1D)
# MATLAB: FluidFlow1DElementStiffness.m, FluidFlow1DElementVelocities.m,
#         FluidFlow1DElementVFR.m
# Julia: d1_fluidflow_elementstiffness, d1_fluidflow_elementvelocity,
#        d1_fluidflow_elementvfr, d1_fluidflow_assemble
# Note: Kattan Ch17 also covers 1D/2D heat transfer and structural
# dynamics — only the 1D fluid flow portion is currently implemented.
# ═══════════════════════════════════════════════════════════

"""
    d1_fluidflow_elementstiffness(Kxx, A, L)

Return the 2×2 element stiffness matrix for a 1-D fluid flow element.

# Arguments
- `Kxx::Real`: Hydraulic conductivity (permeability coefficient).
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.

# Returns
A 2×2 element stiffness matrix.

# Notes
Structural analog of the 1-D bar/truss element with `Kxx·A/L` replacing `E·A/L`.
`L > 0` and `A > 0` are validated.
"""
function d1_fluidflow_elementstiffness(Kxx::Real, A::Real, L::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return Kxx * A / L * [1 -1; -1 1]
end

"""
    d1_fluidflow_elementvelocity(Kxx, L, p)

Return the scalar element seepage velocity.

# Arguments
- `Kxx::Real`: Hydraulic conductivity (permeability coefficient).
- `L::Real`: Element length.
- `p::AbstractVector`: Element nodal potential (fluid head) vector [p₁, p₂].

# Returns
Scalar seepage velocity (v = -Kxx · (p₂ - p₁) / L).

# Notes
`L > 0` is validated.
"""
function d1_fluidflow_elementvelocity(Kxx::Real, L::Real, p::AbstractVector)
    validate_positive(L, "L")
    return -Kxx * (-p[1] + p[2]) / L
end

"""
    d1_fluidflow_elementvfr(Kxx, L, p, A)

Return the scalar element volumetric flow rate.

# Arguments
- `Kxx::Real`: Hydraulic conductivity (permeability coefficient).
- `L::Real`: Element length.
- `p::AbstractVector`: Element nodal potential (fluid head) vector [p₁, p₂].
- `A::Real`: Cross-sectional area.

# Returns
Scalar volumetric flow rate (Q = v · A = -Kxx·A·(p₂-p₁)/L).

# Notes
`L > 0` and `A > 0` are validated.
"""
function d1_fluidflow_elementvfr(Kxx::Real, L::Real, p::AbstractVector, A::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return -Kxx * A * (-p[1] + p[2]) / L
end

"""
    d1_fluidflow_assemble(K, k, i, j)

Assemble the 1-D fluid flow element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix (2×2).
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d1_fluidflow_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end
