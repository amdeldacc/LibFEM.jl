"""
    _gauss_2x2()

Return 4 Gauss points for 2×2 quadrature as a vector of tuples `(ξ, η, w)`.
Points at `ξ = ±1/√3`, `η = ±1/√3`, each with weight `w = 1`.

# Returns
A vector of 4 tuples `(ξ, η, w)` for numerical integration over the
reference domain `[-1, 1] × [-1, 1]`.
"""
function _gauss_2x2()
    gp = 1.0 / sqrt(3.0)
    return [( -gp,  -gp, 1.0),
            (  gp,  -gp, 1.0),
            (  gp,   gp, 1.0),
            ( -gp,   gp, 1.0)]
end

"""
    d2_q4_elementarea(x1, y1, x2, y2, x3, y3, x4, y4)

Compute the area of a quadrilateral by decomposing into two triangles
(1-2-3) and (1-3-4). Assumes CCW node ordering (positive signed area).

# Arguments
- `(x1, y1)`, ..., `(x4, y4)`: Coordinates of the 4 nodes (CCW order).

# Returns
The signed area of the quadrilateral (positive for CCW ordering).

# Notes
- For CCW ordering, returns positive area.
- For CW ordering, returns negative area (same as MATLAB reference).
"""
function d2_q4_elementarea(x1::Real, y1::Real, x2::Real, y2::Real, x3::Real, y3::Real, x4::Real, y4::Real)
    area1 = (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)) / 2
    area2 = (x1 * (y3 - y4) + x3 * (y4 - y1) + x4 * (y1 - y3)) / 2
    return area1 + area2
end

"""
    d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p)

Compute the 8×8 element stiffness matrix for a bilinear quadrilateral (Q4)
using 2×2 Gauss quadrature.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `h::Real`: Thickness.
- `(x1, y1)`, ..., `(x4, y4)`: Coordinates of the 4 nodes (CCW order).
- `p::Int`: 1 = plane stress, 2 = plane strain.

# Returns
An 8×8 symmetric positive semi-definite stiffness matrix.

# Notes
- Node order must be CCW: 1 → 2 → 3 → 4.
- 2 DOF/node: [u₁, v₁, u₂, v₂, u₃, v₃, u₄, v₄].
- Uses isoparametric mapping with bilinear shape functions.
- 2×2 Gauss quadrature is exact for parallelogram elements.
"""
function d2_q4_elementstiffness(
    E::Real, NU::Real, h::Real,
    x1, y1, x2, y2, x3, y3, x4, y4,
    p::Int,
)
    # Node coordinates
    x = [x1, x2, x3, x4]
    y = [y1, y2, y3, y4]

    # D matrix (plane stress or plane strain)
    if p == 1
        D = (E / (1 - NU^2)) * [1   NU   0
                                NU  1    0
                                0   0    (1 - NU) / 2]
    elseif p == 2
        f = E / ((1 + NU) * (1 - 2 * NU))
        D = f * [1 - NU   NU       0
                  NU     1 - NU    0
                  0      0         (1 - 2 * NU) / 2]
    else
        throw(ElementParameterError("p", "p must be 1 (plane stress) or 2 (plane strain), got $p"))
    end

    k = zeros(8, 8)
    gauss_pts = _gauss_2x2()

    for (ξ, η, w) in gauss_pts
        # Shape function derivatives in natural coordinates (ξ, η)
        dN_dξ = [-(1 - η) / 4,  (1 - η) / 4,  (1 + η) / 4, -(1 + η) / 4]
        dN_dη = [-(1 - ξ) / 4, -(1 + ξ) / 4,  (1 + ξ) / 4,  (1 - ξ) / 4]

        # Jacobian matrix (2×2)
        J11 = dN_dξ[1] * x1 + dN_dξ[2] * x2 + dN_dξ[3] * x3 + dN_dξ[4] * x4
        J12 = dN_dξ[1] * y1 + dN_dξ[2] * y2 + dN_dξ[3] * y3 + dN_dξ[4] * y4
        J21 = dN_dη[1] * x1 + dN_dη[2] * x2 + dN_dη[3] * x3 + dN_dη[4] * x4
        J22 = dN_dη[1] * y1 + dN_dη[2] * y2 + dN_dη[3] * y3 + dN_dη[4] * y4

        detJ = J11 * J22 - J12 * J21
        if detJ <= 0
            throw(ElementParameterError("det(J)",
                "Negative or zero Jacobian determinant at Gauss point ($ξ, $η). " *
                "Check element geometry and node ordering (must be CCW)."))
        end

        # Inverse of Jacobian (2×2)
        invJ11 =  J22 / detJ
        invJ12 = -J12 / detJ
        invJ21 = -J21 / detJ
        invJ22 =  J11 / detJ

        # B matrix (3×8) — one pass per node
        B = zeros(3, 8)
        for i in 1:4
            dN_dx = invJ11 * dN_dξ[i] + invJ12 * dN_dη[i]
            dN_dy = invJ21 * dN_dξ[i] + invJ22 * dN_dη[i]
            col = 2 * (i - 1) + 1
            B[1, col]     = dN_dx
            B[2, col + 1] = dN_dy
            B[3, col]     = dN_dy
            B[3, col + 1] = dN_dx
        end

        # Accumulate: k += h · B'· D · B · |J| · w
        k += h * B' * D * B * detJ * w
    end

    return k
end

"""
    d2_q4_elementstress(E, NU, x1, y1, x2, y2, x3, y3, x4, y4, p, u)

Compute the 3×1 stress vector `[σxx, σyy, τxy]` at the element centroid
(ξ = η = 0) for a bilinear quadrilateral (Q4) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1, y1)`, ..., `(x4, y4)`: Coordinates of the 4 nodes (CCW order).
- `p::Int`: 1 = plane stress, 2 = plane strain.
- `u::AbstractVector`: 8-element nodal displacement vector
  [u₁, v₁, u₂, v₂, u₃, v₃, u₄, v₄].

# Returns
A 3-element vector `[σxx, σyy, τxy]`.
"""
function d2_q4_elementstress(
    E::Real, NU::Real,
    x1, y1, x2, y2, x3, y3, x4, y4,
    p::Int, u::AbstractVector,
)
    # D matrix
    if p == 1
        D = (E / (1 - NU^2)) * [1   NU   0
                                NU  1    0
                                0   0    (1 - NU) / 2]
    elseif p == 2
        f = E / ((1 + NU) * (1 - 2 * NU))
        D = f * [1 - NU   NU       0
                  NU     1 - NU    0
                  0      0         (1 - 2 * NU) / 2]
    else
        throw(ElementParameterError("p", "p must be 1 (plane stress) or 2 (plane strain), got $p"))
    end

    # Compute B matrix at centroid (ξ = η = 0)
    ξ, η = 0.0, 0.0
    dN_dξ = [-(1 - η) / 4,  (1 - η) / 4,  (1 + η) / 4, -(1 + η) / 4]
    dN_dη = [-(1 - ξ) / 4, -(1 + ξ) / 4,  (1 + ξ) / 4,  (1 - ξ) / 4]

    J11 = dN_dξ[1] * x1 + dN_dξ[2] * x2 + dN_dξ[3] * x3 + dN_dξ[4] * x4
    J12 = dN_dξ[1] * y1 + dN_dξ[2] * y2 + dN_dξ[3] * y3 + dN_dξ[4] * y4
    J21 = dN_dη[1] * x1 + dN_dη[2] * x2 + dN_dη[3] * x3 + dN_dη[4] * x4
    J22 = dN_dη[1] * y1 + dN_dη[2] * y2 + dN_dη[3] * y3 + dN_dη[4] * y4

    detJ = J11 * J22 - J12 * J21
    invJ11 =  J22 / detJ
    invJ12 = -J12 / detJ
    invJ21 = -J21 / detJ
    invJ22 =  J11 / detJ

    B = zeros(3, 8)
    for i in 1:4
        dN_dx = invJ11 * dN_dξ[i] + invJ12 * dN_dη[i]
        dN_dy = invJ21 * dN_dξ[i] + invJ22 * dN_dη[i]
        col = 2 * (i - 1) + 1
        B[1, col]     = dN_dx
        B[2, col + 1] = dN_dy
        B[3, col]     = dN_dy
        B[3, col + 1] = dN_dx
    end

    return D * B * u
end

"""
    d2_q4_elementpstress(sigma)

Compute principal stresses and orientation from a 2D plane stress/strain
vector.

# Arguments
- `sigma::AbstractVector`: 3-element stress vector `[σxx, σyy, τxy]`.

# Returns
A tuple `(σ₁, σ₂, θ_deg)` — major principal stress, minor principal stress,
and principal angle in degrees.

# Notes
Delegates to `_principal_stresses`.
"""
function d2_q4_elementpstress(sigma::AbstractVector)
    return _principal_stresses(sigma)
end

"""
    d2_q4_assemble(K, k, i, j, m, n)

Assemble the 8×8 element stiffness matrix `k` of a bilinear quadrilateral
(Q4) element into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: 8×8 element stiffness matrix.
- `i::Int`: Index of node 1.
- `j::Int`: Index of node 2.
- `m::Int`: Index of node 3.
- `n::Int`: Index of node 4.

# Returns
The updated global stiffness matrix `K`.

# Notes
- 2 DOF per node, 4 nodes per element.
- Node order must be CCW: i → j → m → n.
- Delegates to `_assemble_n!`.
"""
function d2_q4_assemble(
    K::AbstractMatrix, k::AbstractMatrix,
    i::Int, j::Int, m::Int, n::Int,
)
    return _assemble_n!(K, k, [i, j, m, n], 2)
end
