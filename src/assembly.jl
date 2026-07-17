"""
    _assemble!(K, k, i, j, ndofs)

Assemble element stiffness matrix `k` into global stiffness matrix `K`
for nodes `i` and `j`, each with `ndofs` degrees of freedom.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: Element stiffness matrix.
- `i::Integer`: Index of the first node.
- `j::Integer`: Index of the second node.
- `ndofs::Integer`: Number of degrees of freedom per node.

# Returns
The updated global stiffness matrix `K`.

# Notes
This is the internal assembly workhorse used by all element types.
Uses `@views` for slice operations.
"""
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    @views begin
        K[(i - 1) * ndofs + 1:i * ndofs, (i - 1) * ndofs + 1:i * ndofs] += k[1:ndofs, 1:ndofs]
        K[(i - 1) * ndofs + 1:i * ndofs, (j - 1) * ndofs + 1:j * ndofs] += k[1:ndofs, ndofs + 1:2 * ndofs]
        K[(j - 1) * ndofs + 1:j * ndofs, (i - 1) * ndofs + 1:i * ndofs] += k[ndofs + 1:2 * ndofs, 1:ndofs]
        K[(j - 1) * ndofs + 1:j * ndofs, (j - 1) * ndofs + 1:j * ndofs] += k[ndofs + 1:2 * ndofs, ndofs + 1:2 * ndofs]
    end
    return K
end

"""
    _d3_beam_kprime(E, G, A, Iy, Iz, J, L)

Compute the 12×12 local (primal) stiffness matrix for a
3-D beam (space frame) element in its local coordinate system.

# Arguments
- `E::Real`: Modulus of elasticity.
- `G::Real`: Shear modulus.
- `A::Real`: Cross-sectional area.
- `Iy::Real`: Moment of inertia about the local y-axis.
- `Iz::Real`: Moment of inertia about the local z-axis.
- `J::Real`: Torsional constant.
- `L::Real`: Element length.

# Returns
A 12×12 matrix in the local coordinate system.

# Notes
DOF order: [δx, δy, δz, θx, θy, θz, δx₂, δy₂, δz₂, θx₂, θy₂, θz₂]
"""
function _d3_beam_kprime(
    E::Real,
    G::Real,
    A::Real,
    Iy::Real,
    Iz::Real,
    J::Real,
    L::Real,
)
    w1 = E * A / L
    w2 = 12 * E * Iz / (L^3)
    w3 = 6 * E * Iz / (L^2)
    w4 = 4 * E * Iz / L
    w5 = 2 * E * Iz / L
    w6 = 12 * E * Iy / (L^3)
    w7 = 6 * E * Iy / (L^2)
    w8 = 4 * E * Iy / L
    w9 = 2 * E * Iy / L
    w10 = G * J / L
    # DOF order: [δx, δy, δz, θx, θy, θz, δx₂, δy₂, δz₂, θx₂, θy₂, θz₂]
    # w2..w5 use Iz (bending about z-axis → δy, θz)
    # w6..w9 use Iy (bending about y-axis → δz, θy)
    return [
        w1   0    0    0    0    0   -w1   0    0    0    0    0
        0   w2   0    0    0    w3   0   -w2   0    0    0    w3
        0    0   w6   0   -w7   0    0    0   -w6   0   -w7   0
        0    0    0   w10   0    0    0    0    0   -w10  0    0
        0    0   -w7   0   w8    0    0    0    w7   0    w9   0
        0    w3   0    0    0    w4   0   -w3   0    0    0    w5
       -w1   0    0    0    0    0    w1   0    0    0    0    0
        0   -w2   0    0    0   -w3   0    w2   0    0    0   -w3
        0    0   -w6   0    w7    0    0    0    w6   0    w7   0
        0    0    0   -w10  0    0    0    0    0    w10   0    0
        0    0   -w7   0    w9    0    0    0    w7   0    w8   0
        0    w3   0    0    0    w5   0   -w3   0    0    0    w4
    ]
end
