# ═══════════════════════════════════════════════════════════
# Tetrahedron Element (3D Continuum, 4-node linear tetrahedron)
# Kattan Ch15 — MATLAB reference: TetrahedronElementStiffness.m
#
# 3 DOF/node (ux, uy, uz), 12×12 stiffness matrix.
# ═══════════════════════════════════════════════════════════

"""
    d3_tet_elementvolume(x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)

Compute the volume of a 4-node tetrahedron using the 4×4 determinant formula:
`V = |det(X)| / 6` where `X = [1 x y z]` for all 4 nodes.

Returns positive volume for valid (non-flipped) node ordering.

# Arguments
- `(x1,y1,z1)`, `(x2,y2,z2)`, `(x3,y3,z3)`, `(x4,y4,z4)`: Nodal coordinates.

# Returns
Positive volume as a `Float64`.
"""
function d3_tet_elementvolume(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
    # V = |det([1 x1 y1 z1; 1 x2 y2 z2; 1 x3 y3 z3; 1 x4 y4 z4])| / 6
    # Use 3×3 determinant of the Jacobian for efficiency:
    # J = [x2-x1 y2-y1 z2-z1; x3-x1 y3-y1 z3-z1; x4-x1 y4-y1 z4-z1]
    det_val = (x2 - x1) * ((y3 - y1) * (z4 - z1) - (z3 - z1) * (y4 - y1)) -
              (y2 - y1) * ((x3 - x1) * (z4 - z1) - (z3 - z1) * (x4 - x1)) +
              (z2 - z1) * ((x3 - x1) * (y4 - y1) - (y3 - y1) * (x4 - x1))
    return abs(det_val) / 6
end

"""
    d3_tet_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4)

Compute the 12×12 stiffness matrix for a linear 4-node tetrahedron element
with 3 DOF per node.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1,y1,z1)`, `(x2,y2,z2)`, `(x3,y3,z3)`, `(x4,y4,z4)`: Nodal coordinates.

# Returns
A 12×12 symmetric positive semi-definite stiffness matrix.

# Notes
- Uses analytical (constant) B matrix — 1-point Gauss quadrature is exact.
- Node order (1-2-3-4) orientation must produce positive Jacobian for
  correct element behavior.
"""
function d3_tet_elementstiffness(
    E::Real, NU::Real,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
)
    # Signed volume from 4×4 determinant (matches MATLAB exactly)
    xyz = [1 x1 y1 z1; 1 x2 y2 z2; 1 x3 y3 z3; 1 x4 y4 z4]
    V = LinearAlgebra.det(xyz) / 6

    # Beta coefficients (cofactors of the y,z columns)
    beta1 = -LinearAlgebra.det([1 y2 z2; 1 y3 z3; 1 y4 z4])
    beta2 = LinearAlgebra.det([1 y1 z1; 1 y3 z3; 1 y4 z4])
    beta3 = -LinearAlgebra.det([1 y1 z1; 1 y2 z2; 1 y4 z4])
    beta4 = LinearAlgebra.det([1 y1 z1; 1 y2 z2; 1 y3 z3])

    # Gamma coefficients (cofactors of the x,z columns)
    gamma1 = LinearAlgebra.det([1 x2 z2; 1 x3 z3; 1 x4 z4])
    gamma2 = -LinearAlgebra.det([1 x1 z1; 1 x3 z3; 1 x4 z4])
    gamma3 = LinearAlgebra.det([1 x1 z1; 1 x2 z2; 1 x4 z4])
    gamma4 = -LinearAlgebra.det([1 x1 z1; 1 x2 z2; 1 x3 z3])

    # Delta coefficients (cofactors of the x,y columns)
    delta1 = -LinearAlgebra.det([1 x2 y2; 1 x3 y3; 1 x4 y4])
    delta2 = LinearAlgebra.det([1 x1 y1; 1 x3 y3; 1 x4 y4])
    delta3 = -LinearAlgebra.det([1 x1 y1; 1 x2 y2; 1 x4 y4])
    delta4 = LinearAlgebra.det([1 x1 y1; 1 x2 y2; 1 x3 y3])

    # B matrix (6×12) = [B1 B2 B3 B4] / (6V)
    # Each Bi is 6×3 per node
    sixV = 6 * V
    B = (1 / sixV) * [
        beta1  0      0      beta2  0      0      beta3  0      0      beta4  0      0
        0      gamma1 0      0      gamma2 0      0      gamma3 0      0      gamma4 0
        0      0      delta1 0      0      delta2 0      0      delta3 0      0      delta4
        gamma1 beta1  0      gamma2 beta2  0      gamma3 beta3  0      gamma4 beta4  0
        0      delta1 gamma1 0      delta2 gamma2 0      delta3 gamma3 0      delta4 gamma4
        delta1 0      beta1  delta2 0      beta2  delta3 0      beta3  delta4 0      beta4
    ]

    # D matrix (6×6 isotropic elasticity)
    D = _d3_elasticity_matrix(E, NU)

    # Stiffness: k = V · Bᵀ · D · B
    return V * transpose(B) * D * B
end

"""
    d3_tet_elementstress(E, NU, x1,y1,z1, x2,y2,z2, x3,y3,z3, x4,y4,z4, u)

Compute the 6×1 stress vector [σxx; σyy; σzz; τxy; τyz; τzx] at any point
in the element (constant stress for linear tetrahedron).

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `(x1,y1,z1)`–`(x4,y4,z4)`: Nodal coordinates.
- `u::AbstractVector`: 12-element displacement vector (ux1,uy1,uz1, ..., ux4,uy4,uz4).

# Returns
A 6-element stress vector in Voigt notation.
"""
function d3_tet_elementstress(
    E::Real, NU::Real,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
    u::AbstractVector,
)
    xyz = [1 x1 y1 z1; 1 x2 y2 z2; 1 x3 y3 z3; 1 x4 y4 z4]
    V = LinearAlgebra.det(xyz) / 6

    beta1 = -LinearAlgebra.det([1 y2 z2; 1 y3 z3; 1 y4 z4])
    beta2 = LinearAlgebra.det([1 y1 z1; 1 y3 z3; 1 y4 z4])
    beta3 = -LinearAlgebra.det([1 y1 z1; 1 y2 z2; 1 y4 z4])
    beta4 = LinearAlgebra.det([1 y1 z1; 1 y2 z2; 1 y3 z3])

    gamma1 = LinearAlgebra.det([1 x2 z2; 1 x3 z3; 1 x4 z4])
    gamma2 = -LinearAlgebra.det([1 x1 z1; 1 x3 z3; 1 x4 z4])
    gamma3 = LinearAlgebra.det([1 x1 z1; 1 x2 z2; 1 x4 z4])
    gamma4 = -LinearAlgebra.det([1 x1 z1; 1 x2 z2; 1 x3 z3])

    delta1 = -LinearAlgebra.det([1 x2 y2; 1 x3 y3; 1 x4 y4])
    delta2 = LinearAlgebra.det([1 x1 y1; 1 x3 y3; 1 x4 y4])
    delta3 = -LinearAlgebra.det([1 x1 y1; 1 x2 y2; 1 x4 y4])
    delta4 = LinearAlgebra.det([1 x1 y1; 1 x2 y2; 1 x3 y3])

    sixV = 6 * V
    B = (1 / sixV) * [
        beta1  0      0      beta2  0      0      beta3  0      0      beta4  0      0
        0      gamma1 0      0      gamma2 0      0      gamma3 0      0      gamma4 0
        0      0      delta1 0      0      delta2 0      0      delta3 0      0      delta4
        gamma1 beta1  0      gamma2 beta2  0      gamma3 beta3  0      gamma4 beta4  0
        0      delta1 gamma1 0      delta2 gamma2 0      delta3 gamma3 0      delta4 gamma4
        delta1 0      beta1  delta2 0      beta2  delta3 0      beta3  delta4 0      beta4
    ]

    D = _d3_elasticity_matrix(E, NU)
    return D * B * u
end

"""
    d3_tet_elementpstress(sigma)

Compute principal stresses from a 6×1 3D stress vector in Voigt notation
[σxx; σyy; σzz; τxy; τyz; τzx].

# Arguments
- `sigma::AbstractVector`: 6-element stress vector.

# Returns
A tuple `(σ1, σ2, σ3, τ_max)` where:
- `σ1`, `σ2`, `σ3`: Principal stresses (σ1 ≥ σ2 ≥ σ3).
- `τ_max`: Maximum shear stress = (σ1 - σ3) / 2.

# Notes
Uses eigenvalue decomposition of the 3×3 stress tensor.
"""
function d3_tet_elementpstress(sigma::AbstractVector)
    # Build 3×3 stress tensor from Voigt notation
    σxx, σyy, σzz = sigma[1], sigma[2], sigma[3]
    τxy, τyz, τzx = sigma[4], sigma[5], sigma[6]
    tensor = [σxx τxy τzx; τxy σyy τyz; τzx τyz σzz]

    # Eigenvalues are the principal stresses
    vals = LinearAlgebra.eigvals(tensor)
    σ1 = max(vals...)
    σ3 = min(vals...)
    σ2 = vals[1] + vals[2] + vals[3] - σ1 - σ3
    τ_max = (σ1 - σ3) / 2
    return (σ1, σ2, σ3, τ_max)
end

"""
    d3_tet_assemble(K, k, i, j, m, n)

Assemble a 12×12 tetrahedron element stiffness matrix into the global
stiffness matrix `K`. The element has 4 nodes with 3 DOF per node.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: 12×12 element stiffness matrix.
- `i::Int`, `j::Int`, `m::Int`, `n::Int`: Node indices (4 nodes).

# Returns
The updated global stiffness matrix `K`.

# Notes
Delegates to `_assemble_n!` with `ndofs=3`.
"""
function d3_tet_assemble(
    K::AbstractMatrix, k::AbstractMatrix, i::Int, j::Int, m::Int, n::Int,
)
    return _assemble_n!(K, k, [i, j, m, n], 3)
end
