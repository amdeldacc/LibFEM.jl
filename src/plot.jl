# ═══════════════════════════════════════════════════════════
# Diagram Functions
# ═══════════════════════════════════════════════════════════
# These functions use Plots.jl, loaded at module scope in LibFEM.jl.
# All Plots symbols are accessible via the parent module context.
# The diagram functions are re-exported from LibFEM.jl.
#
# Sign convention follows Kattan: axial positive = tension,
# shear positive = clockwise on left face, moment positive = sagging.
# Positive values plotted above beam axis.
# ═══════════════════════════════════════════════════════════

# private helper to reduce boilerplate in beam diagram functions
function _beamdiagram(f::AbstractVector, L::Real, title_::AbstractString, z_fn::Function)
    x = [0, L]
    z = z_fn(f, L)
    p = plot(x, z, title=title_)
    plot!(p, x, [0, 0], color=:black)
    return p
end

# ─── 2-D Pure Beam Diagrams (4-element force vector) ───
# f = [shear₁, moment₁, shear₂, moment₂]

"""
    d2_beam_elementsheardiagram(f, L)

Plot and return the shear force diagram for a 2-D pure beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (4 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d2_beam_elementsheardiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Shear Force Diagram", (f,L)->[f[1], -f[3]])

"""
    d2_beam_elementmomentdiagram(f, L)

Plot and return the bending moment diagram for a 2-D pure beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (4 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d2_beam_elementmomentdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Bending Moment Diagram", (f,L)->[-f[2], f[4]])

# ─── 2-D Plane Frame Diagrams (6-element force vector) ───
# f = [axial₁, shear₁, moment₁, axial₂, shear₂, moment₂]

"""
    d2_planeframe_elementaxialdiagram(f, L)

Plot and return the axial force diagram for a 2-D plane frame element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d2_planeframe_elementaxialdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Axial Force Diagram", (f,L)->[-f[1], f[4]])

"""
    d2_planeframe_elementsheardiagram(f, L)

Plot and return the shear force diagram for a 2-D plane frame element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d2_planeframe_elementsheardiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Shear Force Diagram", (f,L)->[f[2], -f[5]])

"""
    d2_planeframe_elementmomentdiagram(f, L)

Plot and return the bending moment diagram for a 2-D plane frame element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d2_planeframe_elementmomentdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Bending Moment Diagram", (f,L)->[-f[3], f[6]])

# ─── 3-D Beam Diagrams ───

"""
    d3_beam_elementaxialdiagram(f, L)

Plot and return the axial force diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementaxialdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Axial Force Diagram", (f,L)->[-f[1], f[7]])

"""
    d3_beam_elementshearydiagram(f, L)

Plot and return the shear force Y diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementshearydiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Shear Force Y Diagram", (f,L)->[f[2], -f[8]])

"""
    d3_beam_elementshearzdiagram(f, L)

Plot and return the shear force Z diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementshearzdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Shear Force Z Diagram", (f,L)->[f[3], -f[9]])

"""
    d3_beam_elementmomentydiagram(f, L)

Plot and return the bending moment Y diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementmomentydiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Bending Moment Y Diagram", (f,L)->[f[5], -f[11]])

"""
    d3_beam_elementmomentzdiagram(f, L)

Plot and return the bending moment Z diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementmomentzdiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Bending Moment Z Diagram", (f,L)->[f[6], -f[12]])

"""
    d3_beam_elementtorsiondiagram(f, L)

Plot and return the torsion diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
d3_beam_elementtorsiondiagram(f::AbstractVector, L::Real) = _beamdiagram(f, L, "Torsion Diagram", (f,L)->[f[4], -f[10]])
