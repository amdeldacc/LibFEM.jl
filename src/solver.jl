"""
    apply_bc!(K, F, constraints)

Apply Dirichlet boundary conditions to a global system K·u = F
by eliminating constrained degrees of freedom.

For each `(dof, val)` pair in `constraints`:
  - Zero row `dof` of K
  - Zero column `dof` of K
  - Set `K[dof, dof] = 1.0`
  - Set `F[dof] = val`

# Arguments
- `K::AbstractMatrix`: Global stiffness matrix (modified in-place).
- `F::AbstractVector`: Global force vector (modified in-place).
- `constraints::AbstractVector{<:Pair{Int,<:Real}}`: List of `(dof => value)` pairs,
  where `dof` is the constrained degree of freedom and `value` is the prescribed
  displacement. DOFs are 1-indexed.

# Returns
A tuple `(K, F)` with boundary conditions applied.

# Throws
- `BoundsError` if any DOF is out of range for `K` or `F`.

# Examples
```julia
julia> K = [200 -200   0; -200 450 -250; 0 -250 250]
julia> F = [0.0; 10.0; 0.0]
julia> apply_bc!(K, F, [1 => 0.0, 3 => 0.0])
```
"""
function apply_bc!(K::AbstractMatrix, F::AbstractVector, constraints::AbstractVector{<:Pair{Int,<:Real}})
    n = size(K, 1)
    for (dof, val) in constraints
        # Bounds check
        1 <= dof <= n || throw(BoundsError(K, dof))
        1 <= dof <= length(F) || throw(BoundsError(F, dof))
        # Zero row and column, set diagonal to 1
        K[dof, :] .= 0.0
        K[:, dof] .= 0.0
        K[dof, dof] = 1.0
        F[dof] = val
    end
    return (K, F)
end
