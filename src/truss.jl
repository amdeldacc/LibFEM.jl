# ═══════════════════════════════════════════════════════════
# 1-D Truss / Linear Bar Element (d1_truss)
# ═══════════════════════════════════════════════════════════

"""
    d1_truss_elementstiffness(E, A, L)

Return the 2×2 element stiffness matrix for a 1-D truss (linear bar) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.

# Returns
A 2×2 element stiffness matrix.

# Notes
- Only `L > 0` is validated. `A ≤ 0` is intentionally allowed (produces zero/negated matrices)
  to support parametric studies and sensitivity analysis. Negative/zero area has physical
  meaning in some contexts (e.g., tension-only members with slack).
"""
function d1_truss_elementstiffness(E::Real, A::Real, L::Real)
    validate_positive(L, "L")
    return E * A / L * [1 -1; -1 1]
end

"""
    d1_truss_elementforces(Ke, u)

Return the element force vector for a 1-D truss element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 2-element force vector (positive = tension).
"""
function d1_truss_elementforces(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u
end

"""
    d1_truss_elementstress(Ke, u, A)

Return the element stress for a 1-D truss element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix.
- `u::AbstractVector`: Element nodal displacement vector.
- `A::Real`: Cross-sectional area.

# Returns
A 2-element stress vector (positive = tension).
"""
function d1_truss_elementstress(Ke::AbstractMatrix, u::AbstractVector, A::Real)
    return Ke * u / A
end

"""
    d1_truss_elementstrain(L, u)

Return the element strain for a 1-D truss element.

# Arguments
- `L::Real`: Element length.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 2-element strain vector (positive = tension).
"""
function d1_truss_elementstrain(L::Real, u::AbstractVector)
    validate_positive(L, "L")
    return (u[2] - u[1]) / L
end

"""
    d1_truss_assemble(K, k, i, j)

Assemble the 1-D truss element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d1_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end

# ═══════════════════════════════════════════════════════════
# 2-D Truss / Plane Truss Element (d2_truss)
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
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
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
- Only `L > 0` is validated. `A ≤ 0` is intentionally allowed (produces zero/negated matrices)
  to support parametric studies and sensitivity analysis.
"""
function d2_truss_elementstiffness(E::Real, A::Real, L::Real, theta::Real)
    validate_positive(L, "L")
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

# ═══════════════════════════════════════════════════════════
# 3-D Truss / Space Truss Element (d3_truss)
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
    return sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
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
- Only `L > 0` is validated. `A ≤ 0` is intentionally allowed (produces zero/negated matrices)
  to support parametric studies and sensitivity analysis.
"""
function d3_truss_elementstiffness(E::Real, A::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real)
    validate_positive(L, "L")
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
