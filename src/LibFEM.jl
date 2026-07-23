module LibFEM

using Plots

# ═══════════════════════════════════════════════════════════
# Includes (order matters: types/errors/utils/assembly first)
# ═══════════════════════════════════════════════════════════

include("types.jl")
include("errors.jl")
include("utils.jl")
include("assembly.jl")
include("spring.jl")
include("truss.jl")
include("beam.jl")
include("plot.jl")

# ═══════════════════════════════════════════════════════════
# Centralized Exports
# ═══════════════════════════════════════════════════════════

# Abstract type hierarchy
export AbstractElement, AbstractSpring, AbstractTruss, AbstractBeam

# Concrete types
export Spring, Truss, Beam

# Error types
export ElementDimensionError, ElementParameterError, AssemblyError, DiagramError

# Utility
export deg2rad

# 1-D Spring
export d1_spring_elementstiffness, d1_spring_elementforce, d1_spring_assemble

# 2-D Spring
export d2_spring_elementstiffness, d2_spring_elementforce, d2_spring_assemble

# 3-D Spring
export d3_spring_elementstiffness, d3_spring_elementforce, d3_spring_assemble

# 1-D Truss / Linear Bar
export d1_truss_elementstiffness, d1_truss_elementforces, d1_truss_elementstress, d1_truss_elementstrain, d1_truss_assemble

# 2-D Truss / Plane Truss
export d2_truss_elementlength, d2_truss_elementstiffness, d2_truss_elementforces, d2_truss_elementstrain, d2_truss_elementstress, d2_truss_assemble

# 3-D Truss / Space Truss
export d3_truss_elementlength, d3_truss_elementstiffness, d3_truss_elementforces, d3_truss_elementstrain, d3_truss_elementstress, d3_truss_assemble

# 2-D Pure Beam (bending only, 2 DOF/node)
export d2_beam_elementstiffness, d2_beam_elementforces, d2_beam_assemble, d2_beam_elementsheardiagram, d2_beam_elementmomentdiagram

# 2-D Plane Frame (axial + bending, 3 DOF/node)
export d2_planeframe_elementlength, d2_planeframe_elementstiffness, d2_planeframe_elementforces, d2_planeframe_assemble, d2_planeframe_elementaxialdiagram, d2_planeframe_elementsheardiagram, d2_planeframe_elementmomentdiagram

# 3-D Beam / Space Frame
export d3_spaceframe_elementlength, d3_spaceframe_elementstiffness, d3_spaceframe_assemble, d3_spaceframe_elementforces, d3_spaceframe_elementaxialdiagram, d3_spaceframe_elementshearydiagram, d3_spaceframe_elementshearzdiagram, d3_spaceframe_elementmomentydiagram, d3_spaceframe_elementmomentzdiagram, d3_spaceframe_elementtorsiondiagram

end # module
