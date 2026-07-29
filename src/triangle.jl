"""
    d2_cst_elementarea(x1, y1, x2, y2, x3, y3)

Compute the area of a triangular element using the shoelace formula.
Returns positive area for CCW node ordering.

# Arguments
- `x1,y1`: Coordinates of the first node.
- `x2,y2`: Coordinates of the second node.
- `x3,y3`: Coordinates of the third node.

# Returns
The positive area of the triangle.
"""
function d2_cst_elementarea(x1::Real, y1::Real, x2::Real, y2::Real, x3::Real, y3::Real)
    return 0.5 * abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1))
end

"""
    d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p)

Compute the 6×6 stiffness matrix for a Constant Strain Triangle (CST).

# Arguments
- `E::Real`: Young's modulus.
- `NU::Real`: Poisson's ratio.
- `t::Real`: Thickness.
- `x1,y1`: Coordinates of the first node.
- `x2,y2`: Coordinates of the second node.
- `x3,y3`: Coordinates of the third node.
- `p::Int`: Flag for element type (1 = plane stress, 2 = plane strain).

# Returns
A 6×6 symmetric positive semi-definite stiffness matrix.

# Notes
Implements the constant strain triangle formulation from Kattan Ch11.
Uses the strain-displacement matrix B (3×6) and material matrix D (3×3)
to compute k = t · A · B' · D · B.
"""
function d2_cst_elementstiffness(
    E::Real,
    NU::Real,
    t::Real,
    x1::Real,
    y1::Real,
    x2::Real,
    y2::Real,
    x3::Real,
    y3::Real,
    p::Int,
)
    # Signed area (shoelace formula, no abs — sign matters for B formulation)
    A = (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)) / 2

    # Beta coefficients (shape function derivatives wrt x)
    β₁ = y2 - y3
    β₂ = y3 - y1
    β₃ = y1 - y2

    # Gamma coefficients (shape function derivatives wrt y)
    γ₁ = x3 - x2
    γ₂ = x1 - x3
    γ₃ = x2 - x1

    # Strain-displacement matrix B (3×6)
    B = (1 / (2 * A)) * [
        β₁  0  β₂  0  β₃  0
        0  γ₁  0  γ₂  0  γ₃
        γ₁  β₁  γ₂  β₂  γ₃  β₃
    ]

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

    return t * A * transpose(B) * D * B
end

"""
    d2_cst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, p, u)

Compute the 3×1 stress vector [σxx; σyy; τxy] at the element centroid.

# Arguments
- `E::Real`: Young's modulus.
- `NU::Real`: Poisson's ratio.
- `x1,y1`: Coordinates of the first node.
- `x2,y2`: Coordinates of the second node.
- `x3,y3`: Coordinates of the third node.
- `p::Int`: Flag for element type (1 = plane stress, 2 = plane strain).
- `u::AbstractVector`: 6-element displacement vector [u1, v1, u2, v2, u3, v3].

# Returns
A 3-element stress vector [σxx, σyy, τxy].
"""
function d2_cst_elementstress(
    E::Real,
    NU::Real,
    x1::Real,
    y1::Real,
    x2::Real,
    y2::Real,
    x3::Real,
    y3::Real,
    p::Int,
    u::AbstractVector,
)
    # Signed area
    A = (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)) / 2

    # Beta and gamma coefficients
    β₁ = y2 - y3
    β₂ = y3 - y1
    β₃ = y1 - y2
    γ₁ = x3 - x2
    γ₂ = x1 - x3
    γ₃ = x2 - x1

    # Strain-displacement matrix B (3×6)
    B = (1 / (2 * A)) * [
        β₁  0  β₂  0  β₃  0
        0  γ₁  0  γ₂  0  γ₃
        γ₁  β₁  γ₂  β₂  γ₃  β₃
    ]

    # Material constitutive matrix D (3×3)
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
    d2_cst_elementpstress(sigma)

Compute principal stresses [σ1, σ2, θ_deg] from a 3×1 stress vector.

# Arguments
- `sigma::AbstractVector`: 3-element stress vector [σxx, σyy, τxy].

# Returns
A tuple `(σ1, σ2, θ_deg)` where:
- `σ1` = first principal stress (major)
- `σ2` = second principal stress (minor)
- `θ_deg` = principal angle in degrees

# Notes
Delegates to `_principal_stresses`.
"""
function d2_cst_elementpstress(sigma::AbstractVector)
    return _principal_stresses(sigma)
end

"""
    d2_cst_assemble(K, k, i, j, m)

Assemble 6×6 CST element stiffness matrix into global stiffness matrix K.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: 6×6 CST element stiffness matrix.
- `i::Int`: Index of the first node.
- `j::Int`: Index of the second node.
- `m::Int`: Index of the third node.

# Returns
The updated global stiffness matrix `K`.

# Notes
Each node has 2 DOF (ux, uy). Delegates to `_assemble_n!` with 3 nodes.
"""
function d2_cst_assemble(
    K::AbstractMatrix,
    k::AbstractMatrix,
    i::Int,
    j::Int,
    m::Int,
)
    return _assemble_n!(K, k, [i, j, m], 2)
end
