# ═══════════════════════════════════════════════════════════
# 3-D Linear Brick Element (d3_brick)
# ═══════════════════════════════════════════════════════════
# 8-node hexahedron (trilinear), 3 DOF/node, 24×24 stiffness.
# 2×2×2 Gauss quadrature with full integration.
# Node ordering: bottom face CCW 1-2-3-4, top face CCW 5-6-7-8.
# Based on Kattan's LinearBrickElement* functions (Chapter 16).
# ═══════════════════════════════════════════════════════════

"""
    _gauss_2x2x2()

Return 8 Gauss points for 2×2×2 quadrature as a vector of tuples `(ξ, η, ζ, w)`.

Points at ξ, η, ζ = ±1/√3, each with weight 1.
"""
function _gauss_2x2x2()
    gp = 1.0 / sqrt(3.0)
    return [
        (-gp, -gp, -gp, 1.0),
        (gp, -gp, -gp, 1.0),
        (gp, gp, -gp, 1.0),
        (-gp, gp, -gp, 1.0),
        (-gp, -gp, gp, 1.0),
        (gp, -gp, gp, 1.0),
        (gp, gp, gp, 1.0),
        (-gp, gp, gp, 1.0),
    ]
end

# ═══════════════════════════════════════════════════════════
# Shape function derivatives at a point (s, t, u) in natural coords
# Returns 3×8 matrix: dN[i, a] = ∂Nₐ/∂ξᵢ where ξ₁=s, ξ₂=t, ξ₃=u
# ═══════════════════════════════════════════════════════════

@inline function _brick_dN(s::Real, t::Real, u::Real)
    # ∂Nₐ/∂ξ (rows 1), ∂Nₐ/∂η (row 2), ∂Nₐ/∂ζ (row 3)
    dN = zeros(3, 8)
    # Node 1: (-1, -1, -1)
    dN[1, 1] = -(1 - t) * (1 - u) / 8
    dN[2, 1] = -(1 - s) * (1 - u) / 8
    dN[3, 1] = -(1 - s) * (1 - t) / 8
    # Node 2: ( 1, -1, -1)
    dN[1, 2] = (1 - t) * (1 - u) / 8
    dN[2, 2] = -(1 + s) * (1 - u) / 8
    dN[3, 2] = -(1 + s) * (1 - t) / 8
    # Node 3: ( 1,  1, -1)
    dN[1, 3] = (1 + t) * (1 - u) / 8
    dN[2, 3] = (1 + s) * (1 - u) / 8
    dN[3, 3] = -(1 + s) * (1 + t) / 8
    # Node 4: (-1,  1, -1)
    dN[1, 4] = -(1 + t) * (1 - u) / 8
    dN[2, 4] = (1 - s) * (1 - u) / 8
    dN[3, 4] = -(1 - s) * (1 + t) / 8
    # Node 5: (-1, -1,  1)
    dN[1, 5] = -(1 - t) * (1 + u) / 8
    dN[2, 5] = -(1 - s) * (1 + u) / 8
    dN[3, 5] = (1 - s) * (1 - t) / 8
    # Node 6: ( 1, -1,  1)
    dN[1, 6] = (1 - t) * (1 + u) / 8
    dN[2, 6] = -(1 + s) * (1 + u) / 8
    dN[3, 6] = (1 + s) * (1 - t) / 8
    # Node 7: ( 1,  1,  1)
    dN[1, 7] = (1 + t) * (1 + u) / 8
    dN[2, 7] = (1 + s) * (1 + u) / 8
    dN[3, 7] = (1 + s) * (1 + t) / 8
    # Node 8: (-1,  1,  1)
    dN[1, 8] = -(1 + t) * (1 + u) / 8
    dN[2, 8] = (1 - s) * (1 + u) / 8
    dN[3, 8] = (1 - s) * (1 + t) / 8
    return dN
end

@inline function _brick_jacobian(dN::AbstractMatrix, x::AbstractVector, y::AbstractVector, z::AbstractVector)
    J = zeros(3, 3)
    for a in 1:8
        J[1, 1] += dN[1, a] * x[a]
        J[1, 2] += dN[1, a] * y[a]
        J[1, 3] += dN[1, a] * z[a]
        J[2, 1] += dN[2, a] * x[a]
        J[2, 2] += dN[2, a] * y[a]
        J[2, 3] += dN[2, a] * z[a]
        J[3, 1] += dN[3, a] * x[a]
        J[3, 2] += dN[3, a] * y[a]
        J[3, 3] += dN[3, a] * z[a]
    end
    return J
end

"""
    d3_brick_elementvolume(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4,
                           x5,y5,z5, x6,y6,z6, x7,y7,z7, x8,y8,z8)

Compute the volume of an 8-node linear brick element via the
Jacobian determinant at the centroid (ξ=η=ζ=0).

# Arguments
- `(x1,y1,z1)` through `(x8,y8,z8)`: Nodal coordinates.

# Returns
The element volume (scalar).

# Notes
Volume is computed as V = 8 × det(J(0,0,0)), which is exact for
parallelepipeds and approximate for general hexahedra.
"""
function d3_brick_elementvolume(
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
    x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8,
)
    x = [x1, x2, x3, x4, x5, x6, x7, x8]
    y = [y1, y2, y3, y4, y5, y6, y7, y8]
    z = [z1, z2, z3, z4, z5, z6, z7, z8]

    dN = _brick_dN(0.0, 0.0, 0.0)
    J = _brick_jacobian(dN, x, y, z)
    return 8.0 * LinearAlgebra.det(J)
end

"""
    d3_brick_elementstiffness(E, NU, x1,y1,z1, ..., x8,y8,z8)

Compute the 24×24 element stiffness matrix for a linear brick (8-node
hexahedron) element with trilinear shape functions and 2×2×2 Gauss quadrature.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1,y1,z1)` through `(x8,y8,z8)`: Nodal coordinates.

# Returns
A 24×24 symmetric positive semi-definite stiffness matrix.

# Notes
- 3 DOF/node: node n → DOFs [3n-2, 3n-1, 3n].
- Full 2×2×2 integration (8 Gauss points).
- Node ordering: bottom face CCW 1-2-3-4, top face CCW 5-6-7-8.
"""
function d3_brick_elementstiffness(
    E::Real, NU::Real,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
    x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8,
)
    x = [x1, x2, x3, x4, x5, x6, x7, x8]
    y = [y1, y2, y3, y4, y5, y6, y7, y8]
    z = [z1, z2, z3, z4, z5, z6, z7, z8]

    D = _d3_elasticity_matrix(E, NU)
    k = zeros(24, 24)

    for (s, t, u, w) in _gauss_2x2x2()
        dN = _brick_dN(s, t, u)
        J = _brick_jacobian(dN, x, y, z)
        detJ = LinearAlgebra.det(J)
        invJ = LinearAlgebra.inv(J)

        # Convert natural derivatives to physical: dNx = J⁻¹ · dN
        dNx = invJ * dN  # 3×8: rows = ∂/∂x, ∂/∂y, ∂/∂z

        # Build B matrix (6×24)
        B = zeros(6, 24)
        @views for a in 1:8
            col = (a - 1) * 3 + 1
            B[1, col]     = dNx[1, a]
            B[2, col + 1] = dNx[2, a]
            B[3, col + 2] = dNx[3, a]
            B[4, col]     = dNx[2, a]
            B[4, col + 1] = dNx[1, a]
            B[5, col + 1] = dNx[3, a]
            B[5, col + 2] = dNx[2, a]
            B[6, col]     = dNx[3, a]
            B[6, col + 2] = dNx[1, a]
        end

        k += B' * D * B * detJ * w
    end

    # Symmetrize to eliminate numerical noise from Gauss summation
    return (k + k') / 2
end

"""
    d3_brick_elementstress(E, NU, x1,y1,z1, ..., x8,y8,z8, u)

Compute the 6×1 stress vector [σxx; σyy; σzz; τxy; τyz; τzx]
at the element centroid (ξ=η=ζ=0).

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1,y1,z1)` through `(x8,y8,z8)`: Nodal coordinates.
- `u::AbstractVector`: 24-element element nodal displacement vector.

# Returns
A 6-element stress vector at the centroid.
"""
function d3_brick_elementstress(
    E::Real, NU::Real,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
    x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8,
    u::AbstractVector,
)
    x = [x1, x2, x3, x4, x5, x6, x7, x8]
    y = [y1, y2, y3, y4, y5, y6, y7, y8]
    z = [z1, z2, z3, z4, z5, z6, z7, z8]

    # Evaluate at centroid (s=t=u=0)
    dN = _brick_dN(0.0, 0.0, 0.0)
    J = _brick_jacobian(dN, x, y, z)
    invJ = LinearAlgebra.inv(J)
    dNx = invJ * dN  # 3×8

    D = _d3_elasticity_matrix(E, NU)

    # Build B at centroid (6×24)
    B = zeros(6, 24)
    @views for a in 1:8
        col = (a - 1) * 3 + 1
        B[1, col]     = dNx[1, a]
        B[2, col + 1] = dNx[2, a]
        B[3, col + 2] = dNx[3, a]
        B[4, col]     = dNx[2, a]
        B[4, col + 1] = dNx[1, a]
        B[5, col + 1] = dNx[3, a]
        B[5, col + 2] = dNx[2, a]
        B[6, col]     = dNx[3, a]
        B[6, col + 2] = dNx[1, a]
    end

    return D * B * u
end

"""
    d3_brick_elementpstress(sigma)

Compute principal stresses from a 6×1 3D stress vector.

# Arguments
- `sigma::AbstractVector`: 6-element stress vector [σxx;σyy;σzz;τxy;τyz;τzx].

# Returns
A tuple `(σ1, σ2, σ3, τ_max)` where σ1 ≥ σ2 ≥ σ3 and τ_max = (σ1-σ3)/2.
"""
function d3_brick_elementpstress(sigma::AbstractVector)
    return _d3_principal_stresses(sigma)
end

"""
    d3_brick_assemble(K, k, i, j, m, n, p, q, r, s)

Assemble the 24×24 brick element stiffness matrix `k` into the global
stiffness matrix `K` for 8 nodes, each with 3 DOF.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: Element stiffness matrix (24×24).
- `i, j, m, n, p, q, r, s::Int`: Node indices for the 8 nodes.

# Returns
The updated global stiffness matrix `K`.
"""
function d3_brick_assemble(
    K::AbstractMatrix, k::AbstractMatrix,
    i::Int, j::Int, m::Int, n::Int,
    p::Int, q::Int, r::Int, s::Int,
)
    return _assemble_n!(K, k, [i, j, m, n, p, q, r, s], 3)
end
