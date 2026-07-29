# ═══════════════════════════════════════════════════════════
# 2-D Grid Element (d2_grid) — Out-of-Plane Bending + Torsion
# ═══════════════════════════════════════════════════════════
# Grid element: 3 DOF/node (UZ, RX, RY), 6×6 stiffness.
# Superposition of torsional stiffness (GJ/L) + out-of-plane
# beam bending (EI/L³). Elements lie in the XY plane; loads
# are perpendicular to the plane (Z-direction).
# Based on Kattan's GridElement* functions (Chapter 11).
# ═══════════════════════════════════════════════════════════

"""
    d2_grid_elementlength(x1, y1, x2, y2)

Return the length of the 2-D grid element.

# Arguments
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.

# Returns
The element length.
"""
function d2_grid_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    return d2_truss_elementlength(x1, y1, x2, y2)
end

"""
    d2_grid_elementstiffness(E, G, I, J, L, azi)

Return the 6×6 element stiffness matrix for a 2-D grid element
(out-of-plane bending + torsion).

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `I::Real`: Moment of inertia for out-of-plane bending.
- `J::Real`: Torsional constant.
- `L::Real`: Element length.
- `azi::Real`: Azimuth angle in degrees (orientation in the XY plane).

# Returns
A 6×6 element stiffness matrix in global coordinates.

# Notes
- DOF ordering: [UZ₁, RX₁, RY₁, UZ₂, RX₂, RY₂]
- The element lies in the XY plane; loads are perpendicular (Z-direction).
- Combines torsional stiffness (GJ/L) with out-of-plane bending (EI).
"""
function d2_grid_elementstiffness(E::Real, G::Real, I::Real, J::Real, L::Real, azi::Real)
    validate_positive(L, "L")
    kprime = _d2_grid_kprime(E, G, I, J, L)
    C = cos(deg2rad(azi))
    S = sin(deg2rad(azi))
    # Transformation: global → local (per Kattan GridElementStiffness)
    R = [
        1  0  0  0  0  0
        0  C  S  0  0  0
        0 -S  C  0  0  0
        0  0  0  1  0  0
        0  0  0  0  C  S
        0  0  0  0 -S  C
    ]
    return R' * kprime * R
end

"""
    d2_grid_elementforces(E, G, I, J, L, azi, u)

Return the element force vector for a 2-D grid element in the
**local** coordinate system.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `I::Real`: Moment of inertia for out-of-plane bending.
- `J::Real`: Torsional constant.
- `L::Real`: Element length.
- `azi::Real`: Azimuth angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 6-element force vector in the local coordinate system
(shear₁, torque₁, moment₁, shear₂, torque₂, moment₂).
"""
function d2_grid_elementforces(E::Real, G::Real, I::Real, J::Real, L::Real, azi::Real, u::AbstractVector)
    validate_positive(L, "L")
    kprime = _d2_grid_kprime(E, G, I, J, L)
    C = cos(deg2rad(azi))
    S = sin(deg2rad(azi))
    # Transformation: global → local (per Kattan GridElementForces)
    R = [
        1  0  0  0  0  0
        0  C  S  0  0  0
        0 -S  C  0  0  0
        0  0  0  1  0  0
        0  0  0  0  C  S
        0  0  0  0 -S  C
    ]
    return kprime * R * u
end

"""
    d2_grid_assemble(K, k, i, j)

Assemble the grid element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K` (3 DOF/node).

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix (6×6).
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d2_grid_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end

# ═══════════════════════════════════════════════════════════
# Private helpers
# ═══════════════════════════════════════════════════════════

"""
    _d2_grid_kprime(E, G, I, J, L)

Compute the 6×6 local (primal) stiffness matrix for a
2-D grid element in its local coordinate system.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `I::Real`: Moment of inertia for out-of-plane bending.
- `J::Real`: Torsional constant.
- `L::Real`: Element length.

# Returns
A 6×6 matrix in the local coordinate system.

# Notes
DOF order: [UZ₁, RX₁, RY₁, UZ₂, RX₂, RY₂]
- UZ (vertical displacement) and RY (rotation about y) are coupled via beam bending.
- RX (rotation about x) is the torsional DOF, independent of UZ/RY.
"""
function _d2_grid_kprime(E::Real, G::Real, I::Real, J::Real, L::Real)
    w1 = 12 * E * I / (L^3)
    w2 = 6 * E * I / (L^2)
    w3 = G * J / L
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    return [
         w1    0    w2   -w1    0    w2
          0    w3    0     0   -w3    0
         w2    0    w4   -w2    0    w5
        -w1    0   -w2    w1    0   -w2
          0   -w3    0     0    w3    0
         w2    0    w5   -w2    0    w4
    ]
end
