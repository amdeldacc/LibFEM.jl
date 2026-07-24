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

"""
    _direction_cosines(theta_deg)

Compute direction cosines from a 2D angle theta in degrees.
Returns `(C, S) = (cos, sin)`.
"""
function _direction_cosines(theta_deg::Real)
    x = deg2rad(theta_deg)
    return (cos(x), sin(x))
end

"""
    _direction_cosines(thetax_deg, thetay_deg, thetaz_deg)

Compute direction cosines from three 3D angles in degrees.
Warns if Cx²+Cy²+Cz² deviates from 1 by >1e-12 (non-physical input).
"""
function _direction_cosines(thetax_deg::Real, thetay_deg::Real, thetaz_deg::Real)
    x = deg2rad(thetax_deg)
    y = deg2rad(thetay_deg)
    z = deg2rad(thetaz_deg)
    Cx = cos(x)
    Cy = cos(y)
    Cz = cos(z)
    nsq = Cx^2 + Cy^2 + Cz^2
    abs(nsq - 1) > 1e-12 &&
        @warn "Direction cosines do not form a unit vector: Cx²+Cy²+Cz² = $nsq ≠ 1"
    return (Cx, Cy, Cz)
end

"""
    _truss_force_component(Cx, Cy, u) -> Real

Compute scalar projection `[-Cx -Cy Cx Cy] · u` for 2D trusses (4-element u).
"""
function _truss_force_component(Cx::Real, Cy::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] + Cx * u[3] + Cy * u[4]
end

"""
    _truss_force_component(Cx, Cy, Cz, u) -> Real

Compute scalar projection `[-Cx -Cy -Cz Cx Cy Cz] · u` for 3D trusses (6-element u).
"""
function _truss_force_component(Cx::Real, Cy::Real, Cz::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] - Cz * u[3] + Cx * u[4] + Cy * u[5] + Cz * u[6]
end

"""
    validate_positive(x::Real, name::AbstractString)

Validate that a numeric value is positive.

# Arguments
- `x::Real`: Value to check.
- `name::AbstractString`: Parameter name for error messages.

# Returns
`nothing` if `x > 0`, otherwise throws `ElementParameterError`.

# Throws
- `ElementParameterError` if `x ≤ 0`.
"""
function validate_positive(x::Real, name::AbstractString)
    x > 0 || throw(ElementParameterError(name, "$name must be positive, got $x"))
    return nothing
end
