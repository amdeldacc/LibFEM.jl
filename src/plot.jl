# ═══════════════════════════════════════════════════════════
# Diagram Functions
# ═══════════════════════════════════════════════════════════
# These functions use Plots.jl, loaded at module scope in LibFEM.jl.
# All Plots symbols are accessible via the parent module context.
# The 2-D beam diagram functions (d2_beam_element*diagram) are
# re-exported from beam.jl. The 3-D beam diagram functions
# (d3_beam_element*diagram) are defined here and exported from LibFEM.jl.
# ═══════════════════════════════════════════════════════════

# ─── 2-D Beam Diagrams ───

"""
    d2_beam_elementaxialdiagram(f, L)

Plot and return the axial force diagram for a 2-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d2_beam_elementaxialdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [-f[1], f[4]]
    p = plot(x, z, title="Axial Force Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d2_beam_elementsheardiagram(f, L)

Plot and return the shear force diagram for a 2-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d2_beam_elementsheardiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[2], -f[5]]
    p = plot(x, z, title="Shear Force Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d2_beam_elementmomentdiagram(f, L)

Plot and return the bending moment diagram for a 2-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (6 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d2_beam_elementmomentdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [-f[3], f[6]]
    p = plot(x, z, title="Bending Moment Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

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
function d3_beam_elementaxialdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [-f[1], f[7]]
    p = plot(x, z, title="Axial Force Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d3_beam_elementshearydiagram(f, L)

Plot and return the shear force Y diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d3_beam_elementshearydiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[2], -f[8]]
    p = plot(x, z, title="Shear Force Y Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d3_beam_elementshearzdiagram(f, L)

Plot and return the shear force Z diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d3_beam_elementshearzdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[3], -f[9]]
    p = plot(x, z, title="Shear Force Z Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d3_beam_elementmomentydiagram(f, L)

Plot and return the bending moment Y diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d3_beam_elementmomentydiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[5], -f[11]]
    p = plot(x, z, title="Bending Moment Y Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d3_beam_elementmomentzdiagram(f, L)

Plot and return the bending moment Z diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d3_beam_elementmomentzdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[6], -f[12]]
    p = plot(x, z, title="Bending Moment Z Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end

"""
    d3_beam_elementtorsiondiagram(f, L)

Plot and return the torsion diagram for a 3-D beam element.

# Arguments
- `f::AbstractVector`: Element nodal force vector (12 elements).
- `L::Real`: Element length.

# Returns
A Plots.Plot object.
"""
function d3_beam_elementtorsiondiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[4], -f[10]]
    p = plot(x, z, title="Torsion Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end
