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

