"""
    deg2rad(theta::Real)

Convert an angle in degrees to radians.

# Arguments
- `theta::Real`: Angle in degrees.

# Returns
The angle in radians.

# Examples
```julia
julia> deg2rad(180)
3.141592653589793
```
"""
function deg2rad(theta::Real)
    return theta * pi / 180
end
