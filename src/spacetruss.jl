# ═══════════════════════════════════════════════════════════
# Ch6: Space Truss Element
# MATLAB: SpaceTrussElementLength.m, SpaceTrussElementStiffness.m,
#         SpaceTrussElementForce.m, SpaceTrussElementStress.m,
#         SpaceTrussElementStrain.m
# Julia: d3_truss_elementlength, d3_truss_elementstiffness,
#        d3_truss_elementforces, d3_truss_elementstress, d3_truss_elementstrain,
#        d3_truss_assemble
# ═══════════════════════════════════════════════════════════

"""
    d3_truss_elementlength(x1, y1, z1, x2, y2, z2)

Return the length of the 3-D truss element with nodes (x1, y1, z1) and (x2, y2, z2).

# Arguments
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `z1::Real`: z-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.
- `z2::Real`: z-coordinate of second node.

# Returns
The element length.
"""
function d3_truss_elementlength(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real)
    L = sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
    validate_positive(L, "L")
    return L
end

"""
    d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)

Return the 6×6 element stiffness matrix for a 3-D truss (space truss) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.

# Returns
A 6×6 element stiffness matrix.

# Notes
- `L > 0` and `A > 0` are validated.
"""
function d3_truss_elementstiffness(E::Real, A::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    w = [
        Cx * Cx Cx * Cy Cx * Cz
        Cy * Cx Cy * Cy Cy * Cz
        Cz * Cx Cz * Cy Cz * Cz
    ]
    return E * A / L * [w -w; -w w]
end

"""
    d3_truss_elementforces(E, A, L, thetax, thetay, thetaz, u)

Return the element force for a 3-D truss element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element force (scalar, positive = tension).
"""
function d3_truss_elementforces(E::Real, A::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E * A / L * _truss_force_component(Cx, Cy, Cz, u)
end

"""
    d3_truss_elementstrain(L, thetax, thetay, thetaz, u)

Return the element strain for a 3-D truss element.

# Arguments
- `L::Real`: Element length.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element strain (scalar, positive = tension).
"""
function d3_truss_elementstrain(L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    validate_positive(L, "L")
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return _truss_force_component(Cx, Cy, Cz, u) / L
end

"""
    d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)

Return the element stress for a 3-D truss element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `L::Real`: Element length.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element stress (scalar, positive = tension).
"""
function d3_truss_elementstress(E::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    validate_positive(L, "L")
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E / L * _truss_force_component(Cx, Cy, Cz, u)
end

"""
    d3_truss_assemble(K, k, i, j)

Assemble the 3-D truss element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d3_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
