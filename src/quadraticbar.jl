# ═══════════════════════════════════════════════════════════
# 1-D Quadratic Bar Element (d1_quadraticbar)
# ═══════════════════════════════════════════════════════════

"""
    d1_quadraticbar_elementstiffness(E, A, L)

Return the 3×3 element stiffness matrix for a 1-D quadratic bar element
(3 nodes, 1 DOF per node).

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.

# Returns
A 3×3 element stiffness matrix.

# Notes
- `L > 0` and `A > 0` are validated.
- The quadratic bar has 3 nodes (2 end nodes + 1 mid-node), unlike the
  linear bar which has 2 nodes.
"""
function d1_quadraticbar_elementstiffness(E::Real, A::Real, L::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return (E * A) / (3 * L) * [7 1 -8; 1 7 -8; -8 -8 16]
end

"""
    d1_quadraticbar_elementforces(Ke, u)

Return the element nodal force vector for a 1-D quadratic bar element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix (3×3).
- `u::AbstractVector`: Element nodal displacement vector (3-element).

# Returns
A 3-element force vector (positive = tension).
"""
function d1_quadraticbar_elementforces(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u
end

"""
    d1_quadraticbar_elementstress(Ke, u, A)

Return the element nodal stress vector for a 1-D quadratic bar element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix (3×3).
- `u::AbstractVector`: Element nodal displacement vector (3-element).
- `A::Real`: Cross-sectional area.

# Returns
A 3-element stress vector (positive = tension).
"""
function d1_quadraticbar_elementstress(Ke::AbstractMatrix, u::AbstractVector, A::Real)
    validate_positive(A, "A")
    return Ke * u / A
end

"""
    d1_quadraticbar_assemble(K, k, i, j, m)

Assemble the 1-D quadratic bar element stiffness matrix `k` with nodes `i`, `j`,
and `m` into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: Element stiffness matrix (3×3).
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.
- `m::Integer`: Index of the third/middle node.

# Returns
The updated global stiffness matrix `K`.

# Notes
The nodes `i`, `j`, `m` map to rows 1, 2, 3 of the 3×3 stiffness matrix `k`.
This is a custom assembly because the generic `_assemble!` helper only supports
2-node elements.
"""
function d1_quadraticbar_assemble(
    K::AbstractMatrix,
    k::AbstractMatrix,
    i::Integer,
    j::Integer,
    m::Integer,
)
    K[i, i] += k[1, 1]
    K[i, j] += k[1, 2]
    K[i, m] += k[1, 3]
    K[j, i] += k[2, 1]
    K[j, j] += k[2, 2]
    K[j, m] += k[2, 3]
    K[m, i] += k[3, 1]
    K[m, j] += k[3, 2]
    K[m, m] += k[3, 3]
    return K
end
