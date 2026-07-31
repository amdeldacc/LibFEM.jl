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
    n_nodes = length(nodes)
    @views for a in 1:n_nodes
        global_a = (nodes[a] - 1) * ndofs + 1:nodes[a] * ndofs
        local_a  = (a - 1) * ndofs + 1:a * ndofs
        for b in 1:n_nodes
            global_b = (nodes[b] - 1) * ndofs + 1:nodes[b] * ndofs
            local_b  = (b - 1) * ndofs + 1:b * ndofs
            K[global_a, global_b] += k[local_a, local_b]
        end
    end
    return K
end

