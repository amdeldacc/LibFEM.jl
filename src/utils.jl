"""
    _direction_cosines(theta_deg)

Compute direction cosines from a 2D angle theta in degrees.
Returns `(C, S) = (cos, sin)`.
"""
@inline function _direction_cosines(theta_deg::Real)
    x = deg2rad(theta_deg)
    return (cos(x), sin(x))
end

"""
    _direction_cosines(thetax_deg, thetay_deg, thetaz_deg)

Compute direction cosines from three 3D angles in degrees.
Warns and normalizes if Cx²+Cy²+Cz² deviates from 1 by >1e-12
(non-physical input automatically corrected).

# Direction Cosine Convention (3-Angle)
Unlike the spherical (polar + azimuthal) convention commonly used
in mathematics, this 3-angle convention defines each angle as the
angle between the element axis and a corresponding global axis:
- `θx`: angle between element axis and global X-axis
- `θy`: angle between element axis and global Y-axis
- `θz`: angle between element axis and global Z-axis

The identity `cos²θx + cos²θy + cos²θz = 1` must hold for a valid
direction vector. Inputs violating this by more than 1e-12 are
automatically normalized (with a warning).

For most practical purposes, users should derive direction cosines
from node coordinates via `d2_truss_elementlength` or
`d3_truss_elementlength` rather than specifying angles manually.
"""
@inline function _direction_cosines(thetax_deg::Real, thetay_deg::Real, thetaz_deg::Real)
    x = deg2rad(thetax_deg)
    y = deg2rad(thetay_deg)
    z = deg2rad(thetaz_deg)
    Cx = cos(x)
    Cy = cos(y)
    Cz = cos(z)
    nsq = Cx^2 + Cy^2 + Cz^2
    if abs(nsq - 1) > 1e-12
        @warn "Direction cosines do not form a unit vector: Cx²+Cy²+Cz² = $nsq ≠ 1"
        if nsq > 1e-12  # non-degenerate: can normalize
            n = sqrt(nsq)
            return (Cx / n, Cy / n, Cz / n)
        end
        # degenerate (nsq ≈ 0): return as-is, can't normalize
    end
    return (Cx, Cy, Cz)
end

"""
    _truss_force_component(Cx, Cy, u) -> Real

Compute scalar projection `[-Cx -Cy Cx Cy] · u` for 2D trusses (4-element u).
"""
@inline function _truss_force_component(Cx::Real, Cy::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] + Cx * u[3] + Cy * u[4]
end

"""
    _truss_force_component(Cx, Cy, Cz, u) -> Real

Compute scalar projection `[-Cx -Cy -Cz Cx Cy Cz] · u` for 3D trusses (6-element u).
"""
@inline function _truss_force_component(Cx::Real, Cy::Real, Cz::Real, u::AbstractVector)
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
@inline function validate_positive(x::Real, name::AbstractString)
    x > 0 || throw(ElementParameterError(name, "$name must be positive, got $x"))
    return nothing
end

"""
    _principal_stresses(sigma)

Compute principal stresses and orientation from a 2D stress vector.

# Arguments
- `sigma::AbstractVector`: 3-element stress vector [σxx, σyy, τxy]

# Returns
A tuple `(σ1, σ2, θ_deg)` where:
- `σ1` = first principal stress (major)
- `σ2` = second principal stress (minor)
- `θ_deg` = principal angle in degrees

# Formula
σ1,2 = (σxx + σyy)/2 ± √(((σxx - σyy)/2)² + τxy²)
θ = ½ · atan2(τxy, (σxx - σyy)/2)  (returned in degrees)
"""
function _principal_stresses(sigma::AbstractVector)
    σxx, σyy, τxy = sigma[1], sigma[2], sigma[3]
    center = (σxx + σyy) / 2
    radius = sqrt(((σxx - σyy) / 2)^2 + τxy^2)
    σ1 = center + radius
    σ2 = center - radius
    θ_rad = 0.5 * atan(τxy, (σxx - σyy) / 2)
    θ_deg = rad2deg(θ_rad)
    return (σ1, σ2, θ_deg)
end

"""
    _d3_elasticity_matrix(E, NU)

Compute the 6×6 3D isotropic elasticity (constitutive) matrix D.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.

# Returns
A 6×6 symmetric matrix for 3D stress-strain relation.

# Notes
Standard 3D isotropic elasticity matrix, matching Kattan's formulation.
Used by both tetrahedron and brick elements.
"""
function _d3_elasticity_matrix(E::Real, NU::Real)
    c = E / ((1 + NU) * (1 - 2 * NU))
    return c * [
        1 - NU   NU       NU       0       0       0
        NU       1 - NU   NU       0       0       0
        NU       NU       1 - NU   0       0       0
        0        0        0        (1 - 2 * NU) / 2  0       0
        0        0        0        0       (1 - 2 * NU) / 2  0
        0        0        0        0       0       (1 - 2 * NU) / 2
    ]
end

"""
    _d2_elasticity_matrix(E, NU, p)

Compute the 2D isotropic elasticity (constitutive) matrix D for plane stress or plane strain.

# Arguments
- `E::Real`: Modulus of elasticity.
- `NU::Real`: Poisson's ratio.
- `p::Int`: Plane type (1 = plane stress, 2 = plane strain).

# Returns
A 3×3 symmetric matrix for 2D stress-strain relation.

# Notes
Standard 2D isotropic elasticity matrix, matching Kattan's formulation.
Used by plane quadrilateral and 8-node quadrilateral elements.
"""
function _d2_elasticity_matrix(E::Real, NU::Real, p::Int)
    if p == 1
        return (E / (1 - NU^2)) * [
            1    NU    0
            NU   1     0
            0    0     (1 - NU) / 2
        ]
    elseif p == 2
        f = E / ((1 + NU) * (1 - 2 * NU))
        return f * [
            1 - NU   NU       0
            NU       1 - NU   0
            0        0        (1 - 2 * NU) / 2
        ]
    else
        throw(ElementParameterError("p", "p must be 1 (plane stress) or 2 (plane strain), got $p"))
    end
end

"""
    _d3_principal_stresses(sigma)

Compute principal stresses from a 6×1 3D stress vector
[σxx; σyy; σzz; τxy; τyz; τzx].

# Arguments
- `sigma::AbstractVector`: 6-element stress vector.

# Returns
A tuple `(σ1, σ2, σ3, τ_max)` where:
- `σ1`: Maximum principal stress (most tensile).
- `σ2`: Intermediate principal stress.
- `σ3`: Minimum principal stress (most compressive).
- `τ_max`: Maximum shear stress = (σ1 - σ3) / 2.

# Notes
Uses eigenvalue decomposition of the 3×3 stress tensor.
Same formulation for tetrahedron and brick elements.
"""
function _d3_principal_stresses(sigma::AbstractVector)
    S = [
        sigma[1] sigma[4] sigma[6]
        sigma[4] sigma[2] sigma[5]
        sigma[6] sigma[5] sigma[3]
    ]
    vals = eigvals(S)
    σ1, σ2, σ3 = sort(vals, rev=true)
    τ_max = (σ1 - σ3) / 2
    return (σ1, σ2, σ3, τ_max)
end
