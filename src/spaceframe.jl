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

# ═══════════════════════════════════════════════════════════
# Private helpers
# ═══════════════════════════════════════════════════════════

"""
    _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)

Compute the 12×12 local (primal) stiffness matrix for a
3-D beam (space frame) element in its local coordinate system.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `A::Real`: Cross-sectional area.
- `Iy::Real`: Moment of inertia about the local y-axis.
- `Iz::Real`: Moment of inertia about the local z-axis.
- `J::Real`: Torsional constant.
- `L::Real`: Element length.

# Returns
A 12×12 matrix in the local coordinate system.

# Notes
DOF order: [δx, δy, δz, θx, θy, θz, δx₂, δy₂, δz₂, θx₂, θy₂, θz₂]
"""
function _d3_spaceframe_kprime(
    E::Real,
    G::Real,
    A::Real,
    Iy::Real,
    Iz::Real,
    J::Real,
    L::Real,
)
    w1 = E * A / L
    w2 = 12 * E * Iz / (L^3)
    w3 = 6 * E * Iz / (L^2)
    w4 = 4 * E * Iz / L
    w5 = 2 * E * Iz / L
    w6 = 12 * E * Iy / (L^3)
    w7 = 6 * E * Iy / (L^2)
    w8 = 4 * E * Iy / L
    w9 = 2 * E * Iy / L
    w10 = G * J / L
    return [
        w1   0    0    0    0    0   -w1   0    0    0    0    0
        0   w2   0    0    0    w3   0   -w2   0    0    0    w3
        0    0   w6   0   -w7   0    0    0   -w6   0   -w7   0
        0    0    0   w10   0    0    0    0    0   -w10  0    0
        0    0   -w7   0   w8    0    0    0    w7   0    w9   0
        0    w3   0    0    0    w4   0   -w3   0    0    0    w5
       -w1   0    0    0    0    0    w1   0    0    0    0    0
        0   -w2   0    0    0   -w3   0    w2   0    0    0   -w3
        0    0   -w6   0    w7    0    0    0    w6   0    w7   0
        0    0    0   -w10  0    0    0    0    0    w10   0    0
        0    0   -w7   0    w9    0    0    0    w7   0    w8   0
        0    w3   0    0    0    w5   0   -w3   0    0    0    w4
    ]
end

"""
    _spaceframe_transform(x1, y1, z1, x2, y2, z2)

Compute the transformation (rotation) matrices for a 3-D space frame element.

Given the nodal coordinates `(x1, y1, z1)` and `(x2, y2, z2)`, returns two matrices:
- `Lambda`: 3×3 direction cosine matrix (global → local transformation of vectors).
- `R`: 12×12 block-diagonal rotation matrix, with `Lambda` repeated 4 times
  on the diagonal (for the 6-DOF-per-node, 2-node element).

# Arguments
- `x1::Real`: x-coordinate of the first node.
- `y1::Real`: y-coordinate of the first node.
- `z1::Real`: z-coordinate of the first node.
- `x2::Real`: x-coordinate of the second node.
- `y2::Real`: y-coordinate of the second node.
- `z2::Real`: z-coordinate of the second node.

# Returns
A tuple `(Lambda, R)`.
"""
function _spaceframe_transform(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real)
    L = sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
    Cx = (x2 - x1) / L
    Cy = (y2 - y1) / L
    Cz = (z2 - z1) / L

    if hypot(Cx, Cy) < 1e-12
        # Vertical element — standard formula breaks (D = 0)
        if z2 > z1
            Lambda = [0 0 1; 0 1 0; -1 0 0]
        else
            Lambda = [0 0 -1; 0 1 0; 1 0 0]
        end
    else
        D = sqrt(Cx^2 + Cy^2)
        Lambda = [
            Cx       Cy       Cz
            -Cy / D   Cx / D   0
            -Cx * Cz / D  -Cy * Cz / D  D
        ]
    end

    Z33 = zeros(3, 3)
    R = [
        Lambda Z33    Z33    Z33
        Z33    Lambda Z33    Z33
        Z33    Z33    Lambda Z33
        Z33    Z33    Z33    Lambda
    ]
    return (Lambda, R)
end
