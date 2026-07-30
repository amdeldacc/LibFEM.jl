# ═══════════════════════════════════════════════════════════
# Ch3: Linear Bar Element
# MATLAB: LinearBarElementStiffness.m, LinearBarElementForces.m,
#         LinearBarElementStresses.m
# Julia: d1_bar_elementstiffness, d1_bar_elementforces,
#        d1_bar_elementstress, d1_bar_elementstrain, d1_bar_assemble
# ═══════════════════════════════════════════════════════════

"""
    d1_bar_elementstiffness(E, A, L)

Return the 2×2 element stiffness matrix for a 1-D bar (linear bar) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.

# Returns
A 2×2 element stiffness matrix.

# Notes
- `L > 0` and `A > 0` are validated.
"""
function d1_bar_elementstiffness(E::Real, A::Real, L::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return E * A / L * [1 -1; -1 1]
end

"""
    d1_bar_elementforces(Ke, u)

Return the element force vector for a 1-D bar element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 2-element force vector (positive = tension).
"""
function d1_bar_elementforces(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u
end

"""
    d1_bar_elementstress(Ke, u, A)

Return the element stress for a 1-D bar element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix.
- `u::AbstractVector`: Element nodal displacement vector.
- `A::Real`: Cross-sectional area.

# Returns
A 2-element stress vector (positive = tension).
"""
function d1_bar_elementstress(Ke::AbstractMatrix, u::AbstractVector, A::Real)
    validate_positive(A, "A")
    return Ke * u / A
end

"""
    d1_bar_elementstrain(L, u)

Return the element strain for a 1-D bar element.

# Arguments
- `L::Real`: Element length.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 2-element strain vector (positive = tension).
"""
function d1_bar_elementstrain(L::Real, u::AbstractVector)
    validate_positive(L, "L")
    return (u[2] - u[1]) / L
end

"""
    d1_bar_assemble(K, k, i, j)

Assemble the 1-D bar element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d1_bar_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end
