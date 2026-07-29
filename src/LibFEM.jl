module LibFEM

using LinearAlgebra

# ═══════════════════════════════════════════════════════════
# Includes (order matters: types/errors/utils/assembly first)
# ═══════════════════════════════════════════════════════════

include("types.jl")
include("errors.jl")
include("utils.jl")
include("assembly.jl")
include("spring.jl")
include("bar.jl")
include("truss.jl")
include("beam.jl")
include("planeframe.jl")
include("spaceframe.jl")
include("grid.jl")
include("quadraticbar.jl")
include("triangle.jl")
include("lst.jl")
include("fluidflow.jl")
include("quadrilateral.jl")
include("q8.jl")
include("solver.jl")
include("tetrahedron.jl")
include("brick.jl")

# Import Base.deg2rad for Julia < 1.10 compat (ensures deg2rad
# is available in the module namespace on all Julia 1.x versions)
import Base: deg2rad

# ═══════════════════════════════════════════════════════════
# Stub diagram functions (replaced by extension when Plots loaded)
# ═══════════════════════════════════════════════════════════
for f in (:d2_beam_elementsheardiagram, :d2_beam_elementmomentdiagram,
          :d2_planeframe_elementaxialdiagram, :d2_planeframe_elementsheardiagram, :d2_planeframe_elementmomentdiagram,
          :d3_spaceframe_elementaxialdiagram, :d3_spaceframe_elementshearydiagram,
          :d3_spaceframe_elementshearzdiagram, :d3_spaceframe_elementmomentydiagram,
          :d3_spaceframe_elementmomentzdiagram, :d3_spaceframe_elementtorsiondiagram,
          :_beamdiagram)
    @eval function $f(args...)
        throw(DiagramError("Plots.jl is required for diagram functions. Use `using Plots` along with LibFEM to enable them."))
    end
end

# ═══════════════════════════════════════════════════════════
# Centralized Exports
# ═══════════════════════════════════════════════════════════

# Abstract type hierarchy
export AbstractElement, AbstractSpring, AbstractTruss, AbstractBeam, AbstractTriangle, AbstractQuadrilateral, AbstractTetrahedron, AbstractBrick

# Concrete types
export Spring, Truss, Beam, Triangle, Quadrilateral, Tetrahedron, Tet3D, Brick, Brick3D

# Error types
export ElementDimensionError, ElementParameterError, AssemblyError, DiagramError

# 1-D Spring
export d1_spring_elementstiffness, d1_spring_elementforce, d1_spring_assemble

# 2-D Spring
export d2_spring_elementstiffness, d2_spring_elementforce, d2_spring_assemble

# 3-D Spring
export d3_spring_elementstiffness, d3_spring_elementforce, d3_spring_assemble

# 1-D Bar / Linear Bar
export d1_bar_elementstiffness, d1_bar_elementforces, d1_bar_elementstress, d1_bar_elementstrain, d1_bar_assemble

# 2-D Truss / Plane Truss
export d2_truss_elementlength, d2_truss_elementstiffness, d2_truss_elementforces, d2_truss_elementstrain, d2_truss_elementstress, d2_truss_assemble

# 3-D Truss / Space Truss
export d3_truss_elementlength, d3_truss_elementstiffness, d3_truss_elementforces, d3_truss_elementstrain, d3_truss_elementstress, d3_truss_assemble

# 2-D Pure Beam (bending only, 2 DOF/node)
export d2_beam_elementstiffness, d2_beam_elementforces, d2_beam_assemble, d2_beam_elementsheardiagram, d2_beam_elementmomentdiagram

# 2-D Plane Frame (axial + bending, 3 DOF/node)
export d2_planeframe_elementlength, d2_planeframe_elementstiffness, d2_planeframe_elementforces, d2_planeframe_assemble, d2_planeframe_elementaxialdiagram, d2_planeframe_elementsheardiagram, d2_planeframe_elementmomentdiagram

# 2-D Grid (out-of-plane bending + torsion, 3 DOF/node)
export d2_grid_elementlength, d2_grid_elementstiffness, d2_grid_elementforces, d2_grid_assemble

# 3-D Beam / Space Frame
export d3_spaceframe_elementlength, d3_spaceframe_elementstiffness, d3_spaceframe_assemble, d3_spaceframe_elementforces, d3_spaceframe_elementaxialdiagram, d3_spaceframe_elementshearydiagram, d3_spaceframe_elementshearzdiagram, d3_spaceframe_elementmomentydiagram, d3_spaceframe_elementmomentzdiagram, d3_spaceframe_elementtorsiondiagram

# 1-D Quadratic Bar (3-node element, 1 DOF/node)
export d1_quadraticbar_elementlength, d1_quadraticbar_elementstiffness, d1_quadraticbar_elementforces, d1_quadraticbar_elementstress, d1_quadraticbar_assemble

# 2-D Constant Strain Triangle (CST)
export d2_cst_elementarea, d2_cst_elementstiffness, d2_cst_elementstress, d2_cst_elementpstress, d2_cst_assemble

# 2-D Linear Strain Triangle (LST / Quadratic Triangle)
export d2_lst_elementstiffness, d2_lst_elementstress, d2_lst_elementpstress, d2_lst_assemble

# 2-D Bilinear Quadrilateral (Q4)
export d2_q4_elementarea, d2_q4_elementstiffness, d2_q4_elementstress, d2_q4_elementpstress, d2_q4_assemble

# 2-D Quadratic Quadrilateral (Q8 - Serendipity)
export d2_q8_elementstiffness, d2_q8_elementstress, d2_q8_elementpstress, d2_q8_assemble

# 1-D Fluid Flow (2-node element, 1 DOF/node)
export d1_fluidflow_elementstiffness, d1_fluidflow_elementvelocity, d1_fluidflow_elementvfr, d1_fluidflow_assemble

# 3-D Linear Brick (8-node hexahedron, 3 DOF/node)
export d3_brick_elementvolume, d3_brick_elementstiffness, d3_brick_elementstress, d3_brick_elementpstress, d3_brick_assemble

# 3-D Linear Tetrahedron (4-node continuum, 3 DOF/node)
export d3_tet_elementvolume, d3_tet_elementstiffness, d3_tet_elementstress, d3_tet_elementpstress, d3_tet_assemble

# Solver / Boundary conditions
export apply_bc!

# ─── Deprecated aliases (renamed for MATLAB convention consistency) ───
Base.@deprecate d1_truss_elementstiffness(args...) d1_bar_elementstiffness(args...)
Base.@deprecate d1_truss_elementforces(args...) d1_bar_elementforces(args...)
Base.@deprecate d1_truss_elementstress(args...) d1_bar_elementstress(args...)
Base.@deprecate d1_truss_elementstrain(args...) d1_bar_elementstrain(args...)
Base.@deprecate d1_truss_assemble(args...) d1_bar_assemble(args...)

end # module
