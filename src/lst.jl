# ═══════════════════════════════════════════════════════════
# 2-D Quadratic Triangular Element (LST — Linear Strain Triangle)
# ═══════════════════════════════════════════════════════════

"""
    _gauss_triangle_3pt()

Return 3 Gauss points for triangle quadrature as vector of tuples (ξ, η, ζ, w).
Standard 3-point rule for triangles in area coordinates (L₁=ξ, L₂=η, L₃=ζ).

# Returns
Vector of 4-tuples `(L₁, L₂, L₃, w)` where the weights sum to 1.
"""
function _gauss_triangle_3pt()
    return [
        (2.0 / 3.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 3.0),
        (1.0 / 6.0, 2.0 / 3.0, 1.0 / 6.0, 1.0 / 3.0),
        (1.0 / 6.0, 1.0 / 6.0, 2.0 / 3.0, 1.0 / 3.0),
    ]
end

"""
    _lst_shape_derivatives(ξ, η, ζ)

Compute the 6×2 matrix of shape function derivatives [∂Nᵢ/∂ξ, ∂Nᵢ/∂η]
for the 6-node quadratic triangle (LST) at area coordinates (ξ, η, ζ).

# Arguments
- `ξ`: Area coordinate L₁ (ξ coordinate in parametric space).
- `η`: Area coordinate L₂ (η coordinate in parametric space).
- `ζ`: Area coordinate L₃ (ζ = 1 - ξ - η).

# Returns
A 6×2 matrix where row i contains [∂Nᵢ/∂ξ, ∂Nᵢ/∂η].
"""
function _lst_shape_derivatives(ξ::Real, η::Real, ζ::Real)
    dN = zeros(Float64, 6, 2)
    # Corner nodes
    # N₁ = ξ(2ξ - 1) = 2ξ² - ξ
    dN[1, 1] = 4ξ - 1
    dN[1, 2] = 0.0
    # N₂ = η(2η - 1) = 2η² - η
    dN[2, 1] = 0.0
    dN[2, 2] = 4η - 1
    # N₃ = ζ(2ζ - 1) = 2ζ² - ζ, ζ = 1-ξ-η
    dN[3, 1] = 1 - 4ζ
    dN[3, 2] = 1 - 4ζ
    # Mid-edge nodes
    # N₄ = 4ξη
    dN[4, 1] = 4η
    dN[4, 2] = 4ξ
    # N₅ = 4ηζ = 4η(1-ξ-η)
    dN[5, 1] = -4η
    dN[5, 2] = 4(ζ - η)
    # N₆ = 4ζξ = 4ξ(1-ξ-η)
    dN[6, 1] = 4(ζ - ξ)
    dN[6, 2] = -4ξ
    return dN
end

"""
    d2_lst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, p)

Compute the 12×12 stiffness matrix for a 6-node quadratic triangle (LST).

# Arguments
- `E::Real`: Young's modulus.
- `NU::Real`: Poisson's ratio.
- `t::Real`: Thickness.
- `x1,y1`: Coordinates of corner node 1.
- `x2,y2`: Coordinates of corner node 2.
- `x3,y3`: Coordinates of corner node 3.
- `x4,y4`: Coordinates of mid-edge node 4 (between 1 and 2).
- `x5,y5`: Coordinates of mid-edge node 5 (between 2 and 3).
- `x6,y6`: Coordinates of mid-edge node 6 (between 3 and 1).
- `p::Int`: Flag for element type (1 = plane stress, 2 = plane strain).

# Returns
A 12×12 symmetric positive semi-definite stiffness matrix.

# Notes
- Node numbering: corners 1-2-3 CCW, mid-edge 4 (1-2), 5 (2-3), 6 (3-1).
- Uses 3-point triangle Gauss quadrature in area coordinates.
- Each node has 2 DOF (ux, uy).
"""
function d2_lst_elementstiffness(
    E::Real,
    NU::Real,
    t::Real,
    x1::Real,
    y1::Real,
    x2::Real,
    y2::Real,
    x3::Real,
    y3::Real,
    x4::Real,
    y4::Real,
    x5::Real,
    y5::Real,
    x6::Real,
    y6::Real,
    p::Int,
)
    # Node coordinate arrays
    xs = [x1, x2, x3, x4, x5, x6]
    ys = [y1, y2, y3, y4, y5, y6]

    # Element positive area (from corner nodes)
    A = 0.5 * abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1))

    # Material constitutive matrix D (3×3)
    if p == 1
        # Plane stress
        D = (E / (1 - NU^2)) * [
            1    NU    0
            NU   1     0
            0    0     (1 - NU) / 2
        ]
    else
        # Plane strain
        D = (E / ((1 + NU) * (1 - 2 * NU))) * [
            1 - NU   NU       0
            NU       1 - NU   0
            0        0        (1 - 2 * NU) / 2
        ]
    end

    # Numerical integration over 3 Gauss points
    k = zeros(Float64, 12, 12)
    gauss_pts = _gauss_triangle_3pt()

    for (ξ, η, ζ, w) in gauss_pts
        dN = _lst_shape_derivatives(ξ, η, ζ)

        # Jacobian matrix J (2×2)
        J11 = dN[1, 1] * xs[1] + dN[2, 1] * xs[2] + dN[3, 1] * xs[3] +
              dN[4, 1] * xs[4] + dN[5, 1] * xs[5] + dN[6, 1] * xs[6]
        J12 = dN[1, 1] * ys[1] + dN[2, 1] * ys[2] + dN[3, 1] * ys[3] +
              dN[4, 1] * ys[4] + dN[5, 1] * ys[5] + dN[6, 1] * ys[6]
        J21 = dN[1, 2] * xs[1] + dN[2, 2] * xs[2] + dN[3, 2] * xs[3] +
              dN[4, 2] * xs[4] + dN[5, 2] * xs[5] + dN[6, 2] * xs[6]
        J22 = dN[1, 2] * ys[1] + dN[2, 2] * ys[2] + dN[3, 2] * ys[3] +
              dN[4, 2] * ys[4] + dN[5, 2] * ys[5] + dN[6, 2] * ys[6]

        detJ = J11 * J22 - J12 * J21
        invJ = (1.0 / detJ) * [J22 -J12; -J21 J11]

        # Strain-displacement matrix B (3×12)
        B = zeros(Float64, 3, 12)
        for n in 1:6
            dNdx = invJ[1, 1] * dN[n, 1] + invJ[1, 2] * dN[n, 2]
            dNdy = invJ[2, 1] * dN[n, 1] + invJ[2, 2] * dN[n, 2]
            col = 2n - 1
            B[1, col]     = dNdx
            B[2, col + 1] = dNdy
            B[3, col]     = dNdy
            B[3, col + 1] = dNdx
        end

        # Integrate: k += t · detJ · w/2 · B'·D·B
        # (w is area-coordinate weight summing to 1; reference triangle weight is 1/2, hence w/2)
        k += t * detJ * w / 2 * transpose(B) * D * B
    end

    # Symmetrize to eliminate floating-point noise from numerical quadrature
    return (k + transpose(k)) / 2
end

"""
    d2_lst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, p, u)

Compute the 3×1 stress vector [σxx; σyy; τxy] at the element centroid
for a 6-node quadratic triangle (LST).

# Arguments
- `E::Real`: Young's modulus.
- `NU::Real`: Poisson's ratio.
- `x1,y1`: Coordinates of corner node 1.
- `x2,y2`: Coordinates of corner node 2.
- `x3,y3`: Coordinates of corner node 3.
- `x4,y4`: Coordinates of mid-edge node 4 (between 1 and 2).
- `x5,y5`: Coordinates of mid-edge node 5 (between 2 and 3).
- `x6,y6`: Coordinates of mid-edge node 6 (between 3 and 1).
- `p::Int`: Flag for element type (1 = plane stress, 2 = plane strain).
- `u::AbstractVector`: 12-element displacement vector
  [u1, v1, u2, v2, u3, v3, u4, v4, u5, v5, u6, v6].

# Returns
A 3-element stress vector [σxx, σyy, τxy] at the element centroid.
"""
function d2_lst_elementstress(
    E::Real,
    NU::Real,
    x1::Real,
    y1::Real,
    x2::Real,
    y2::Real,
    x3::Real,
    y3::Real,
    x4::Real,
    y4::Real,
    x5::Real,
    y5::Real,
    x6::Real,
    y6::Real,
    p::Int,
    u::AbstractVector,
)
    # Centroid in area coordinates
    ξ, η, ζ = 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0

    xs = [x1, x2, x3, x4, x5, x6]
    ys = [y1, y2, y3, y4, y5, y6]

    dN = _lst_shape_derivatives(ξ, η, ζ)

    # Jacobian at centroid
    J11 = dN[1, 1] * xs[1] + dN[2, 1] * xs[2] + dN[3, 1] * xs[3] +
          dN[4, 1] * xs[4] + dN[5, 1] * xs[5] + dN[6, 1] * xs[6]
    J12 = dN[1, 1] * ys[1] + dN[2, 1] * ys[2] + dN[3, 1] * ys[3] +
          dN[4, 1] * ys[4] + dN[5, 1] * ys[5] + dN[6, 1] * ys[6]
    J21 = dN[1, 2] * xs[1] + dN[2, 2] * xs[2] + dN[3, 2] * xs[3] +
          dN[4, 2] * xs[4] + dN[5, 2] * xs[5] + dN[6, 2] * xs[6]
    J22 = dN[1, 2] * ys[1] + dN[2, 2] * ys[2] + dN[3, 2] * ys[3] +
          dN[4, 2] * ys[4] + dN[5, 2] * ys[5] + dN[6, 2] * ys[6]

    detJ = J11 * J22 - J12 * J21
    invJ = (1.0 / detJ) * [J22 -J12; -J21 J11]

    # B matrix at centroid
    B = zeros(Float64, 3, 12)
    for n in 1:6
        dNdx = invJ[1, 1] * dN[n, 1] + invJ[1, 2] * dN[n, 2]
        dNdy = invJ[2, 1] * dN[n, 1] + invJ[2, 2] * dN[n, 2]
        col = 2n - 1
        B[1, col]     = dNdx
        B[2, col + 1] = dNdy
        B[3, col]     = dNdy
        B[3, col + 1] = dNdx
    end

    # D matrix (3×3)
    if p == 1
        D = (E / (1 - NU^2)) * [
            1    NU    0
            NU   1     0
            0    0     (1 - NU) / 2
        ]
    else
        D = (E / ((1 + NU) * (1 - 2 * NU))) * [
            1 - NU   NU       0
            NU       1 - NU   0
            0        0        (1 - 2 * NU) / 2
        ]
    end

    return D * B * u
end

"""
    d2_lst_elementpstress(sigma)

Compute principal stresses [σ1, σ2, θ_deg] from a 3×1 stress vector.

# Arguments
- `sigma::AbstractVector`: 3-element stress vector [σxx, σyy, τxy].

# Returns
A tuple `(σ1, σ2, θ_deg)` where:
- `σ1` = first principal stress (major).
- `σ2` = second principal stress (minor).
- `θ_deg` = principal angle in degrees.

# Notes
Delegates to `_principal_stresses`.
"""
function d2_lst_elementpstress(sigma::AbstractVector)
    return _principal_stresses(sigma)
end

"""
    d2_lst_assemble(K, k, i, j, m, n, o, p_)

Assemble 12×12 LST element stiffness matrix into global stiffness matrix K.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: 12×12 LST element stiffness matrix.
- `i::Int`: Index of corner node 1.
- `j::Int`: Index of corner node 2.
- `m::Int`: Index of corner node 3.
- `n::Int`: Index of mid-edge node 4 (between 1 and 2).
- `o::Int`: Index of mid-edge node 5 (between 2 and 3).
- `p_::Int`: Index of mid-edge node 6 (between 3 and 1).

# Returns
The updated global stiffness matrix `K`.

# Notes
Each node has 2 DOF (ux, uy). Delegates to `_assemble_n!` with 6 nodes.
Node order: corners first (i, j, m), then mid-edge (n, o, p_).
"""
function d2_lst_assemble(
    K::AbstractMatrix,
    k::AbstractMatrix,
    i::Int,
    j::Int,
    m::Int,
    n::Int,
    o::Int,
    p_::Int,
)
    return _assemble_n!(K, k, [i, j, m, n, o, p_], 2)
end
