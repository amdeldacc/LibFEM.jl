# ═══════════════════════════════════════════════════════════
# Ch7: Beam Element (2D Pure Beam — Bending Only)
# MATLAB: BeamElementStiffness.m, BeamElementForces.m,
#         BeamElementShearDiagram.m, BeamElementMomentDiagram.m
# Julia: d2_beam_elementstiffness, d2_beam_elementforces,
#        d2_beam_elementsheardiagram, d2_beam_elementmomentdiagram,
#        d2_beam_assemble
# Note: 2 DOF/node (v, θ), 4×4 stiffness, no axial DOF.
# Inextensible Bernoulli-Euler beam (no axial deformation).
# ═══════════════════════════════════════════════════════════

"""
    d2_beam_elementstiffness(E, I, L)

Return the 4×4 element stiffness matrix for a 2-D pure beam element
(bending only, no axial deformation).

# Arguments
- `E::Real`: Modulus of elasticity.
- `I::Real`: Moment of inertia.
- `L::Real`: Element length (must be positive).

# Returns
A 4×4 element stiffness matrix.

# Notes
- DOF ordering: [v₁, θ₁, v₂, θ₂] (transverse displacement, rotation).
- No axial DOF — the beam is assumed inextensible.
- Local coordinate system only (always horizontal).
"""
function d2_beam_elementstiffness(E::Real, I::Real, L::Real)
    validate_positive(L, "L")
    return E * I / (L^3) * [
         12    6*L   -12    6*L
          6*L  4*L^2  -6*L  2*L^2
        -12   -6*L    12   -6*L
          6*L  2*L^2  -6*L  4*L^2
    ]
end

"""
    d2_beam_elementforces(k, u)

Return the element force vector for a 2-D pure beam element.

# Arguments
- `k::AbstractMatrix`: Element stiffness matrix (4×4).
- `u::AbstractVector`: Element nodal displacement vector (4-element).

# Returns
A 4-element force vector: [shear₁, moment₁, shear₂, moment₂].
"""
function d2_beam_elementforces(k::AbstractMatrix, u::AbstractVector)
    return k * u
end

"""
    d2_beam_assemble(K, k, i, j)

Assemble the pure beam element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K` (2 DOF/node).

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d2_beam_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end


