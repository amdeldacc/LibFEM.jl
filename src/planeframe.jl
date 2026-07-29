# ═══════════════════════════════════════════════════════════
# 2-D Plane Frame Element (d2_planeframe) — Axial + Bending
# ═══════════════════════════════════════════════════════════
# Plane frame: 3 DOF/node (u, v, θ), 6×6 stiffness.
# Superposition of truss bar (axial) + beam (bending).
# Based on Kattan's PlaneFrame* functions.
# ═══════════════════════════════════════════════════════════
# Diagram functions for 2-D and 3-D beams are defined in the Plots extension
# and re-exported from LibFEM.jl.
# ═══════════════════════════════════════════════════════════

"""
    d2_planeframe_elementlength(x1, y1, x2, y2)

Return the length of the 2-D plane frame element.

# Arguments
- `x1::Real`: x-coordinate of first node.
- `y1::Real`: y-coordinate of first node.
- `x2::Real`: x-coordinate of second node.
- `y2::Real`: y-coordinate of second node.

# Returns
The element length.
"""
function d2_planeframe_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    L = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    validate_positive(L, "L")
    return L
end

"""
    d2_planeframe_elementstiffness(E, A, I, L, theta)

Return the 6×6 element stiffness matrix for a 2-D plane frame element
(axial + bending).

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `I::Real`: Moment of inertia.
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.

# Returns
A 6×6 element stiffness matrix in global coordinates.
"""
function d2_planeframe_elementstiffness(E::Real, A::Real, I::Real, L::Real, theta::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    # Expanded formula matching MATLAB Kattan reference (PlaneFrameElementStiffness)
    w1 = A * C * C + 12 * I * S * S / (L * L)
    w2 = A * S * S + 12 * I * C * C / (L * L)
    w3 = (A - 12 * I / (L * L)) * C * S
    w4 = 6 * I * S / L
    w5 = 6 * I * C / L
    return E / L * [
        w1   w3  -w4  -w1  -w3  -w4
        w3   w2   w5  -w3  -w2   w5
       -w4   w5  4*I   w4  -w5  2*I
       -w1  -w3   w4   w1   w3   w4
       -w3  -w2  -w5   w3   w2  -w5
       -w4   w5  2*I   w4  -w5  4*I
    ]
end

"""
    d2_planeframe_elementforces(E, A, I, L, theta, u)

Return the element force vector for a 2-D plane frame element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `I::Real`: Moment of inertia.
- `L::Real`: Element length.
- `theta::Real`: Orientation angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 6-element force vector in the **local** coordinate system
(axial₁, shear₁, moment₁, axial₂, shear₂, moment₂).
"""
function d2_planeframe_elementforces(E::Real, A::Real, I::Real, L::Real, theta::Real, u::AbstractVector)
    validate_positive(L, "L")
    validate_positive(A, "A")
    (C, S) = _direction_cosines(theta)
    kprime = _d2_planeframe_kprime(E, A, I, L)
    # Transformation from global to local (MATLAB Kattan convention)
    T = [
        C  S 0 0 0 0
       -S  C 0 0 0 0
        0  0 1 0 0 0
        0  0 0 C S 0
        0  0 0 -S C 0
        0  0 0 0 0 1
    ]
    return kprime * T * u
end

"""
    d2_planeframe_assemble(K, k, i, j)

Assemble the plane frame element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K` (3 DOF/node).

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix (6×6).
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d2_planeframe_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
