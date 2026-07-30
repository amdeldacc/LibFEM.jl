# ═══════════════════════════════════════════════════════════
# Ch5: Plane Truss Element
# MATLAB: PlaneTrussElementLength.m, PlaneTrussElementStiffness.m,
#         PlaneTrussElementForce.m, PlaneTrussElementStress.m,
#         PlaneTrussElementStrain.m
# Julia: d2_truss_elementlength, d2_truss_elementstiffness,
#        d2_truss_elementforces, d2_truss_elementstress, d2_truss_elementstrain,
#        d2_truss_assemble
# ═══════════════════════════════════════════════════════════

"""
    d2_truss_elementlength(x1, y1, x2, y2)

Return the length of the 2-D truss element with nodes (x1, y1) and (x2, y2).

# Arguments
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.

# Returns
The element length.
"""
function d2_truss_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    L = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    validate_positive(L, "L")
    return L
end

"""
    d2_truss_elementstiffness(E, A, L, theta)

Return the 4×4 element stiffness matrix for a 2-D truss element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.

# Returns
A 4×4 element stiffness matrix.

# Notes
- `L > 0` and `A > 0` are validated.
"""
function d2_truss_elementstiffness(E::Real, A::Real, L::Real, theta::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    w = [C * C C * S; C * S S * S]
    return E * A / L * [w -w; -w w]
end

"""
    d2_truss_elementforces(E, A, L, theta, u)

Return the element force for a 2-D truss element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element force (scalar, positive = tension).
"""
function d2_truss_elementforces(E::Real, A::Real, L::Real, theta::Real, u::AbstractVector)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    return E * A / L * _truss_force_component(C, S, u)
end

"""
    d2_truss_elementstrain(L, theta, u)

Return the element strain for a 2-D truss element.

# Arguments
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element strain (scalar, positive = tension).
"""
function d2_truss_elementstrain(L::Real, theta::Real, u::AbstractVector)
    validate_positive(L, "L")
    (C, S) = _direction_cosines(theta)
    return _truss_force_component(C, S, u) / L
end

"""
    d2_truss_elementstress(E, L, theta, u)

Return the element stress for a 2-D truss element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element stress (scalar, positive = tension).
"""
function d2_truss_elementstress(E::Real, L::Real, theta::Real, u::AbstractVector)
    validate_positive(L, "L")
    (C, S) = _direction_cosines(theta)
    return E / L * _truss_force_component(C, S, u)
end

"""
    d2_truss_assemble(K, k, i, j)

Assemble the 2-D truss element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d2_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end


