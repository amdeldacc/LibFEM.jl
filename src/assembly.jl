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
    i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
    @views begin
        K[(i - 1) * ndofs + 1:i * ndofs, (i - 1) * ndofs + 1:i * ndofs] += k[1:ndofs, 1:ndofs]
        K[(i - 1) * ndofs + 1:i * ndofs, (j - 1) * ndofs + 1:j * ndofs] += k[1:ndofs, ndofs + 1:2 * ndofs]
        K[(j - 1) * ndofs + 1:j * ndofs, (i - 1) * ndofs + 1:i * ndofs] += k[ndofs + 1:2 * ndofs, 1:ndofs]
        K[(j - 1) * ndofs + 1:j * ndofs, (j - 1) * ndofs + 1:j * ndofs] += k[ndofs + 1:2 * ndofs, ndofs + 1:2 * ndofs]
    end
    return K
end

"""
    _assemble_n!(K, k, nodes, ndofs)

Assemble element stiffness matrix `k` into global stiffness matrix `K`
for an arbitrary number of nodes, each with `ndofs` degrees of freedom.

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `k::AbstractMatrix`: Element stiffness matrix.
- `nodes::AbstractVector{Int}`: Node indices (length = n_nodes).
- `ndofs::Int`: Number of degrees of freedom per node.

# Returns
The updated global stiffness matrix `K`.

# Notes
Generic N-node assembly for continuum elements (CST: 3 nodes, Q4: 4, Tet: 4, Brick: 8, etc.).
"""
function _assemble_n!(K::AbstractMatrix, k::AbstractMatrix, nodes::AbstractVector{Int}, ndofs::Int)
    for i in 1:length(nodes), j in i+1:length(nodes)
        nodes[i] == nodes[j] && throw(AssemblyError("Duplicate node indices in assembly: $(nodes)"))
    end
    @views begin
        n_nodes = length(nodes)
        dof_ranges = [((nodes[n] - 1) * ndofs + 1):(nodes[n] * ndofs) for n in 1:n_nodes]
        total_dofs = n_nodes * ndofs
        for a in 1:total_dofs
            global_a = dof_ranges[(a - 1) ÷ ndofs + 1][(a - 1) % ndofs + 1]
            for b in 1:total_dofs
                global_b = dof_ranges[(b - 1) ÷ ndofs + 1][(b - 1) % ndofs + 1]
                K[global_a, global_b] += k[a, b]
            end
        end
    end
    return K
end

"""
    _d2_planeframe_kprime(E, A, I, L)

Compute the 6×6 local (primal) stiffness matrix for a
2-D plane frame element in its local coordinate system.

# Arguments
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `I::Real`: Moment of inertia.
- `L::Real`: Element length.

# Returns
A 6×6 matrix in the local coordinate system.

# Notes
DOF order: [u₁, v₁, θ₁, u₂, v₂, θ₂] (axial, transverse, rotation).
"""
function _d2_planeframe_kprime(E::Real, A::Real, I::Real, L::Real)
    w1 = E * A / L
    w2 = 12 * E * I / (L^3)
    w3 = 6 * E * I / (L^2)
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    return [
        w1  0   0   -w1  0    0
        0   w2  w3   0   -w2  w3
        0   w3  w4   0   -w3  w5
        -w1 0   0    w1  0    0
        0   -w2 -w3  0    w2  -w3
        0   w3  w5   0   -w3  w4
    ]
end

"""
    _d3_spaceframe_kprime(E, G, A, Iy, Iz, J, L)

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
function _d3_spaceframe_kprime(
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

"""
    _spaceframe_transform(x1, y1, z1, x2, y2, z2)

Compute the transformation (rotation) matrices for a 3-D space frame element.

Given the nodal coordinates `(x1, y1, z1)` and `(x2, y2, z2)`, returns two matrices:
- `Lambda`: 3×3 direction cosine matrix (global → local transformation of vectors).
- `R`: 12×12 block-diagonal rotation matrix, with `Lambda` repeated 4 times
  on the diagonal (for the 6-DOF-per-node, 2-node element).

# Arguments
- `x1::Real`: x-coordinate of the first node.
- `y1::Real`: y-coordinate of the first node.
- `z1::Real`: z-coordinate of the first node.
- `x2::Real`: x-coordinate of the second node.
- `y2::Real`: y-coordinate of the second node.
- `z2::Real`: z-coordinate of the second node.

# Returns
A tuple `(Lambda, R)`.
"""
function _spaceframe_transform(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real)
    L = sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
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
    return (Lambda, R)
end
