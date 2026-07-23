# ═══════════════════════════════════════════════════════════
# 2-D Pure Beam Element (d2_beam) — Bending Only
# ═══════════════════════════════════════════════════════════
# Pure beam: 2 DOF/node (v, θ), 4×4 stiffness, no axial DOF.
# Inextensible Bernoulli-Euler beam (no axial deformation).
# Based on Kattan's Beam* functions.
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

# ═══════════════════════════════════════════════════════════
# 2-D Plane Frame Element (d2_planeframe) — Axial + Bending
# ═══════════════════════════════════════════════════════════
# Plane frame: 3 DOF/node (u, v, θ), 6×6 stiffness.
# Superposition of truss bar (axial) + beam (bending).
# Based on Kattan's PlaneFrame* functions.
# ═══════════════════════════════════════════════════════════
# Diagram functions for 2-D and 3-D beams are defined in plot.jl
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
    return sqrt((x2 - x1)^2 + (y2 - y1)^2)
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
    w1 = E * A / L
    w2 = 12 * E * I / (L^3)
    w3 = 6 * E * I / (L^2)
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    kprime = [
        w1  0   0   -w1  0    0
        0   w2  w3   0   -w2  w3
        0   w3  w4   0   -w3  w5
        -w1 0   0    w1  0    0
        0   -w2 -w3  0    w2  -w3
        0   w3  w5   0   -w3  w4
    ]
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
    return sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
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

    Cx = (x2 - x1) / L
    Cy = (y2 - y1) / L
    Cz = (z2 - z1) / L

    if hypot(Cx, Cy) < 1e-12
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

    return kprime * R * u
end

# Frame
# Forces in **local** coordinate system (kprime * R * u).


