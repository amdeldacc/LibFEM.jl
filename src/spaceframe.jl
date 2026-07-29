# ═══════════════════════════════════════════════════════════
# 3-D Space Frame Element (d3_spaceframe)
# ═══════════════════════════════════════════════════════════

"""
    d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)

Return the length of the 3-D beam (space frame) element.

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
function d3_spaceframe_elementlength(
    x1::Real,
    y1::Real,
    z1::Real,
    x2::Real,
    y2::Real,
    z2::Real,
)
    L = sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
    validate_positive(L, "L")
    return L
end

"""
    d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

Return the 12×12 element stiffness matrix for a 3-D beam (space frame) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `A::Real`: Cross-sectional area.
- `Iy::Real`: Moment of inertia about local y-axis.
- `Iz::Real`: Moment of inertia about local z-axis.
- `J::Real`: Torsional constant.
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `z1::Real`: z-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.
- `z2::Real`: z-coordinate of second node.

# Returns
A 12×12 element stiffness matrix.

# Frame
Stiffness in **global** coordinates via R' * kprime * R.
"""
function d3_spaceframe_elementstiffness(
    E::Real,
    G::Real,
    A::Real,
    Iy::Real,
    Iz::Real,
    J::Real,
    x1::Real,
    y1::Real,
    z1::Real,
    x2::Real,
    y2::Real,
    z2::Real,
)
    L = d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)
    validate_positive(L, "L")
    validate_positive(A, "A")
    kprime = _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)

    (Lambda, R) = _spaceframe_transform(x1, y1, z1, x2, y2, z2)

    return R' * kprime * R
end

"""
    d3_spaceframe_assemble(K, k, i, j)

Assemble the 3-D beam element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d3_spaceframe_assemble(
    K::AbstractMatrix,
    k::AbstractMatrix,
    i::Integer,
    j::Integer,
)
    return _assemble!(K, k, i, j, 6)
end

"""
    d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

Return the element force vector for a 3-D beam element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `A::Real`: Cross-sectional area.
- `Iy::Real`: Moment of inertia about local y-axis.
- `Iz::Real`: Moment of inertia about local z-axis.
- `J::Real`: Torsional constant.
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `z1::Real`: z-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.
- `z2::Real`: z-coordinate of second node.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 12-element force vector (positive = tension).
"""
function d3_spaceframe_elementforces(
    E::Real,
    G::Real,
    A::Real,
    Iy::Real,
    Iz::Real,
    J::Real,
    x1::Real,
    y1::Real,
    z1::Real,
    x2::Real,
    y2::Real,
    z2::Real,
    u::AbstractVector,
)
    L = d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)
    validate_positive(L, "L")
    validate_positive(A, "A")
    kprime = _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)

    (Lambda, R) = _spaceframe_transform(x1, y1, z1, x2, y2, z2)

    return kprime * R * u
end

# Frame
# Forces in **local** coordinate system (kprime * R * u).
