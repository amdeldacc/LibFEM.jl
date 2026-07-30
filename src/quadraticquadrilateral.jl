# ═══════════════════════════════════════════════════════════════
# Ch14: Quadratic Quadrilateral Element (Q8 — Serendipity)
# MATLAB: QuadQuadrilateralElementStiffness.m, QuadQuadrilateralElementStress.m,
#         QuadQuadrilateralElementPStresses.m
# Julia: d2_q8_elementstiffness, d2_q8_elementstress,
#        d2_q8_elementpstress, d2_q8_assemble
# ═══════════════════════════════════════════════════════════════

"""
    _gauss_3x3()

Return 9 Gauss points for 3×3 quadrature as a vector of tuples `(ξ, η, w)`.
Standard 3×3 Gauss-Legendre points and weights over [-1, 1] × [-1, 1].

# Returns
A vector of 9 tuples `(ξ, η, w)` where each weight `w` is the tensor product
of the 1-D weights.
"""
function _gauss_3x3()
    gp = sqrt(3.0 / 5.0)  # √0.6
    pts = [-gp, 0.0, gp]
    wts = [5.0 / 9.0, 8.0 / 9.0, 5.0 / 9.0]
    points = Tuple{Float64,Float64,Float64}[]
    for i in 1:3, j in 1:3
        push!(points, (pts[i], pts[j], wts[i] * wts[j]))
    end
    return points
end

"""
    _q8_shape_functions(ξ, η)

Return the 8 serendipity shape functions and their natural-coordinate
derivatives at a given point (ξ, η) in the reference domain.

# Arguments
- `ξ::Real`: Natural coordinate in the ξ-direction.
- `η::Real`: Natural coordinate in the η-direction.

# Returns
A tuple `(N, dN_dξ, dN_dη)` where each is an 8-element vector.

# Notes
Node ordering: corners 1-2-3-4 CCW, mid-edges 5 (1-2), 6 (2-3), 7 (3-4), 8 (4-1).

Natural coordinates of nodes:
  Node 1: (-1, -1)  Node 2: (1, -1)  Node 3: (1, 1)  Node 4: (-1, 1)
  Node 5: (0, -1)   Node 6: (1, 0)   Node 7: (0, 1)   Node 8: (-1, 0)

Serendipity shape functions:
  Corner (ξᵢ=±1, ηᵢ=±1): Nᵢ = (1+ξξᵢ)(1+ηηᵢ)(ξξᵢ+ηηᵢ-1)/4
  Mid-edge on ξ=0 (5,7):  Nᵢ = (1-ξ²)(1+ηηᵢ)/2
  Mid-edge on η=0 (6,8):  Nᵢ = (1-η²)(1+ξξᵢ)/2
"""
function _q8_shape_functions(ξ::Real, η::Real)
    # Corner nodes: natural coordinates
    ξᵢ = [-1,  1, 1, -1]
    ηᵢ = [-1, -1, 1,  1]

    N      = Vector{Float64}(undef, 8)
    dN_dξ = Vector{Float64}(undef, 8)
    dN_dη = Vector{Float64}(undef, 8)

    # Corner nodes (1..4)
    for i in 1:4
        ξξᵢ = ξ * ξᵢ[i]
        ηηᵢ = η * ηᵢ[i]
        N[i]      = (1.0 + ξξᵢ) * (1.0 + ηηᵢ) * (ξξᵢ + ηηᵢ - 1.0) / 4.0
        dN_dξ[i]  = ξᵢ[i] * (1.0 + ηηᵢ) * (2.0 * ξξᵢ + ηηᵢ) / 4.0
        dN_dη[i]  = ηᵢ[i] * (1.0 + ξξᵢ) * (2.0 * ηηᵢ + ξξᵢ) / 4.0
    end

    # Mid-edge node 5 (ξ=0, η=-1): (1-ξ²)(1-η)/2
    N[5]     = (1.0 - ξ * ξ) * (1.0 - η) / 2.0
    dN_dξ[5] = -ξ * (1.0 - η)
    dN_dη[5] = -(1.0 - ξ * ξ) / 2.0

    # Mid-edge node 6 (ξ=1, η=0): (1-η²)(1+ξ)/2
    N[6]     = (1.0 - η * η) * (1.0 + ξ) / 2.0
    dN_dξ[6] = (1.0 - η * η) / 2.0
    dN_dη[6] = -η * (1.0 + ξ)

    # Mid-edge node 7 (ξ=0, η=1): (1-ξ²)(1+η)/2
    N[7]     = (1.0 - ξ * ξ) * (1.0 + η) / 2.0
    dN_dξ[7] = -ξ * (1.0 + η)
    dN_dη[7] = (1.0 - ξ * ξ) / 2.0

    # Mid-edge node 8 (ξ=-1, η=0): (1-η²)(1-ξ)/2
    N[8]     = (1.0 - η * η) * (1.0 - ξ) / 2.0
    dN_dξ[8] = -(1.0 - η * η) / 2.0
    dN_dη[8] = -η * (1.0 - ξ)

    return (N, dN_dξ, dN_dη)
end

"""
    d2_q8_elementstiffness(E, NU, h, x1, y1, ..., x8, y8, p)

Compute the 16×16 element stiffness matrix for a quadratic quadrilateral
(Q8, serendipity) element using 3×3 Gauss quadrature.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `h::Real`: Thickness.
- `(x1, y1)`, ..., `(x4, y4)`: Coordinates of the 4 corner nodes (CCW order).
- `(x5, y5)`, ..., `(x8, y8)`: Coordinates of the 4 mid-edge nodes.
  Node 5: mid-edge of 1-2, Node 6: mid-edge of 2-3,
  Node 7: mid-edge of 3-4, Node 8: mid-edge of 4-1.
- `p::Int`: 1 = plane stress, 2 = plane strain.

# Returns
A 16×16 symmetric positive semi-definite stiffness matrix.

# Notes
- 2 DOF/node, 8 nodes: [u₁, v₁, u₂, v₂, ..., u₈, v₈].
- Uses 3×3 Gauss quadrature (9 points).
- Node order must be CCW for corners, with mid-edge nodes following.
"""
function d2_q8_elementstiffness(
    E::Real, NU::Real, h::Real,
    x1, y1, x2, y2, x3, y3, x4, y4,
    x5, y5, x6, y6, x7, y7, x8, y8,
    p::Int,
)
    x = [x1, x2, x3, x4, x5, x6, x7, x8]
    y = [y1, y2, y3, y4, y5, y6, y7, y8]

    # D matrix (plane stress or plane strain)
    D = _d2_elasticity_matrix(E, NU, p)

    k = zeros(16, 16)
    gauss_pts = _gauss_3x3()

    for (ξ, η, w) in gauss_pts
        _, dN_dξ, dN_dη = _q8_shape_functions(ξ, η)

        # Jacobian matrix (2×2)
        J11 = sum(dN_dξ[i] * x[i] for i in 1:8)
        J12 = sum(dN_dξ[i] * y[i] for i in 1:8)
        J21 = sum(dN_dη[i] * x[i] for i in 1:8)
        J22 = sum(dN_dη[i] * y[i] for i in 1:8)

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

        # B matrix (3×16) — one pass per node
        B = zeros(3, 16)
        for i in 1:8
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
    d2_q8_elementstress(E, NU, x1, y1, ..., x8, y8, p, u)

Compute the 3×1 stress vector `[σxx, σyy, τxy]` at the element centroid
(ξ = η = 0) for a quadratic quadrilateral (Q8) element.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1, y1)`, ..., `(x8, y8)`: Coordinates of the 8 nodes (4 corners + 4 mid-edges).
- `p::Int`: 1 = plane stress, 2 = plane strain.
- `u::AbstractVector`: 16-element nodal displacement vector.

# Returns
A 3-element vector `[σxx, σyy, τxy]`.
"""
function d2_q8_elementstress(
    E::Real, NU::Real,
    x1, y1, x2, y2, x3, y3, x4, y4,
    x5, y5, x6, y6, x7, y7, x8, y8,
    p::Int, u::AbstractVector,
)
    x = [x1, x2, x3, x4, x5, x6, x7, x8]
    y = [y1, y2, y3, y4, y5, y6, y7, y8]

    # D matrix
    D = _d2_elasticity_matrix(E, NU, p)

    # Compute B matrix at centroid (ξ = η = 0)
    ξ, η = 0.0, 0.0
    _, dN_dξ, dN_dη = _q8_shape_functions(ξ, η)

    J11 = sum(dN_dξ[i] * x[i] for i in 1:8)
    J12 = sum(dN_dξ[i] * y[i] for i in 1:8)
    J21 = sum(dN_dη[i] * x[i] for i in 1:8)
    J22 = sum(dN_dη[i] * y[i] for i in 1:8)

    detJ = J11 * J22 - J12 * J21
    invJ11 =  J22 / detJ
    invJ12 = -J12 / detJ
    invJ21 = -J21 / detJ
    invJ22 =  J11 / detJ

    B = zeros(3, 16)
    for i in 1:8
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
    d2_q8_elementpstress(sigma)

Compute principal stresses and orientation from a 2D plane stress/strain
vector for a Q8 element.

# Arguments
- `sigma::AbstractVector`: 3-element stress vector `[σxx, σyy, τxy]`.

# Returns
A tuple `(σ₁, σ₂, θ_deg)` — major principal stress, minor principal stress,
and principal angle in degrees.

# Notes
Delegates to `_principal_stresses`.
"""
function d2_q8_elementpstress(sigma::AbstractVector)
    return _principal_stresses(sigma)
end

"""
    d2_q8_assemble(K, k, n1, n2, n3, n4, n5, n6, n7, n8)

Assemble the 16×16 element stiffness matrix `k` of a quadratic quadrilateral
(Q8) element into the global stiffness matrix `K`.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: 16×16 element stiffness matrix.
- `n1`..`n8::Int`: Node indices for the 8 nodes (4 corners + 4 mid-edges).

# Returns
The updated global stiffness matrix `K`.

# Notes
- 2 DOF per node, 8 nodes per element.
- Delegates to `_assemble_n!`.
"""
function d2_q8_assemble(
    K::AbstractMatrix, k::AbstractMatrix,
    n1::Int, n2::Int, n3::Int, n4::Int,
    n5::Int, n6::Int, n7::Int, n8::Int,
)
    return _assemble_n!(K, k, [n1, n2, n3, n4, n5, n6, n7, n8], 2)
end
