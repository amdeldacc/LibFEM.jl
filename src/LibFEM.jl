module LibFEM

using LinearAlgebra

# ═══════════════════════════════════════════════════════════
# Includes (order matters: types/errors/utils/assembly first)
# ═══════════════════════════════════════════════════════════
#
# Kattan Chapter Index — 1:1 File ↔ Chapter Mapping
#   Ch2:  spring.jl              ─  1D/2D/3D Spring
#   Ch3:  bar.jl                 ─  1D Linear Bar
#   Ch4:  quadraticbar.jl        ─  1D Quadratic Bar
#   Ch5:  planetruss.jl          ─  2D Plane Truss
#   Ch6:  spacetruss.jl          ─  3D Space Truss
#   Ch7:  beam.jl                ─  2D Pure Beam
#   Ch8:  planeframe.jl          ─  2D Plane Frame
#   Ch9:  grid.jl                ─  2D Grid
#   Ch10: spaceframe.jl          ─  3D Space Frame
#   Ch11: triangle.jl            ─  2D CST (d2_cst_*)
#   Ch12: quadratictriangle.jl   ─  2D LST / Quadratic Triangle (d2_lst_*)
#   Ch13: quadrilateral.jl       ─  2D Q4 (d2_q4_*)
#   Ch14: quadraticquadrilateral.jl ─  2D Q8 / Quadratic Quadrilateral (d2_q8_*)
#   Ch15: tetrahedron.jl         ─  3D Tetrahedron (d3_tet_*)
#   Ch16: brick.jl               ─  3D Brick (d3_brick_*)
#   Ch17: fluidflow.jl           ─  1D Fluid Flow / Seepage

include("types.jl")
include("errors.jl")
include("utils.jl")
include("assembly.jl")
include("spring.jl")                # Ch2:  Spring
include("bar.jl")                   # Ch3:  Linear Bar
include("quadraticbar.jl")          # Ch4:  Quadratic Bar
include("planetruss.jl")            # Ch5:  Plane Truss
include("spacetruss.jl")            # Ch6:  Space Truss
include("beam.jl")                  # Ch7:  Beam
include("planeframe.jl")            # Ch8:  Plane Frame
include("grid.jl")                  # Ch9:  Grid
include("spaceframe.jl")            # Ch10: Space Frame
include("triangle.jl")              # Ch11: CST (Linear Triangle)
include("quadratictriangle.jl")     # Ch12: LST (Quadratic Triangle)
include("quadrilateral.jl")         # Ch13: Q4 (Bilinear Quadrilateral)
include("quadraticquadrilateral.jl")# Ch14: Q8 (Quadratic Quadrilateral)
include("tetrahedron.jl")           # Ch15: Tetrahedron
include("brick.jl")                 # Ch16: Brick
include("fluidflow.jl")             # Ch17: Fluid Flow
include("solver.jl")                # Solver / BCs

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
