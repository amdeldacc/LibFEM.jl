# ═══════════════════════════════════════════════════════════
# 1-D Spring Element (d1_spring)
# ═══════════════════════════════════════════════════════════

"""
    d1_spring_elementstiffness(k)

Return the 2×2 element stiffness matrix for a 1-D spring element.

# Arguments
- `k::Real`: Spring stiffness.

# Returns
A 2×2 element stiffness matrix.
"""
function d1_spring_elementstiffness(k::Real)
    return [k -k; -k k]
end

"""
    d1_spring_elementforce(Ke, u)

Return the element force vector for a 1-D spring element.

# Arguments
- `Ke::AbstractMatrix`: Element stiffness matrix.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
A 2-element force vector.
"""
function d1_spring_elementforce(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u
end

"""
    d1_spring_assemble(K, k, i, j)

Assemble the spring element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d1_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end

# ═══════════════════════════════════════════════════════════
# 2-D Spring Element (d2_spring)
# ═══════════════════════════════════════════════════════════

"""
    d2_spring_elementstiffness(k, theta)

Return the 4×4 element stiffness matrix for a 2-D spring element.

# Arguments
- `k::Real`: Spring stiffness.
- `theta::Real`: Orientation angle in degrees.

# Returns
A 4×4 element stiffness matrix.
"""
function d2_spring_elementstiffness(k::Real, theta::Real)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return k * [
        C * C C * S -C * C -C * S
        C * S S * S -C * S -S * S
        -C * C -C * S C * C C * S
        -C * S -S * S C * S S * S
    ]
end

"""
    d2_spring_elementforce(k, theta, u)

Return the element force for a 2-D spring element.

# Arguments
- `k::Real`: Spring stiffness.
- `theta::Real`: Orientation angle in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element force (scalar).
"""
function d2_spring_elementforce(k::Real, theta::Real, u::AbstractVector)
    C = cos(deg2rad(theta))
    S = sin(deg2rad(theta))
    T = [-C -S C S]
    return k * (T * u)
end

"""
    d2_spring_assemble(K, k, i, j)

Assemble the 2-D spring element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d2_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end

# ═══════════════════════════════════════════════════════════
# 3-D Spring Element (d3_spring)
# ═══════════════════════════════════════════════════════════

"""
    d3_spring_elementstiffness(k, thetax, thetay, thetaz)

Return the 6×6 element stiffness matrix for a 3-D spring element.

# Arguments
- `k::Real`: Spring stiffness.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.

# Returns
A 6×6 element stiffness matrix.
"""
function d3_spring_elementstiffness(k::Real, thetax::Real, thetay::Real, thetaz::Real)
    x = deg2rad(thetax)
    u = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(u)
    Cz = cos(v)
    w = [
        Cx * Cx Cx * Cy Cx * Cz
        Cy * Cx Cy * Cy Cy * Cz
        Cz * Cx Cz * Cy Cz * Cz
    ]
    return k * [w -w; -w w]
end

"""
    d3_spring_elementforce(k, thetax, thetay, thetaz, u)

Return the element force for a 3-D spring element.

# Arguments
- `k::Real`: Spring stiffness.
- `thetax::Real`: Angle about x-axis in degrees.
- `thetay::Real`: Angle about y-axis in degrees.
- `thetaz::Real`: Angle about z-axis in degrees.
- `u::AbstractVector`: Element nodal displacement vector.

# Returns
The element force (scalar).
"""
function d3_spring_elementforce(k::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    x = deg2rad(thetax)
    uy = deg2rad(thetay)
    vz = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(uy)
    Cz = cos(vz)
    T = [-Cx -Cy -Cz Cx Cy Cz]
    return k * (T * u)
end

"""
    d3_spring_assemble(K, k, i, j)

Assemble the 3-D spring element stiffness matrix `k` with nodes `i` and `j`
into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix.
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.

# Returns
The updated global stiffness matrix `K`.
"""
function d3_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
