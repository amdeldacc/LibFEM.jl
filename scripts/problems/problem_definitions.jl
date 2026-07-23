# Problem definitions registry for LibFEM.jl
#
# Each entry maps a problem name to its MATLAB reference file, element family,
# and tolerance values for verification testing.
#
# MATLAB files are relative to Doc/Kattan/Solutions-Manual/ in the project root.

module ProblemDefinitions

  export ProblemDef, PROBLEM_REGISTRY, resolve_problem_path, problem_by_name

  """
    @kwdef struct ProblemDef

Canonical description of a reference problem from the MATLAB FEM textbook.
"""
@kwdef struct ProblemDef
    name::String
    matlab_file::String
    element_family::String
    description::String
    rtol::Float64 = 1e-8
    atol::Float64 = 1e-10
end

"""
    resolve_problem_path(def::ProblemDef) -> String

Return the absolute path to the MATLAB .m file for a problem definition,
resolved relative to `Doc/Kattan/Solutions-Manual/` in the project root.
"""
function resolve_problem_path(def::ProblemDef)::String
    return joinpath(dirname(@__DIR__), "..", "Doc", "Kattan", "Solutions-Manual", def.matlab_file)
end

"""
    problem_by_name(name::String) -> Union{ProblemDef, Nothing}

Look up a problem definition by its symbolic name (e.g. "problem_2_1").
Returns `nothing` if no match is found.
"""
const PROBLEM_DICT = Dict{String, ProblemDef}(pair.name => pair for pair in PROBLEM_REGISTRY)

function problem_by_name(name::String)::Union{ProblemDef, Nothing}
    return get(PROBLEM_DICT, name, nothing)
end

"""
    PROBLEM_REGISTRY::Vector{ProblemDef}

Vector of 7 canonical FEM problems from the Kattan textbook.
"""
const PROBLEM_REGISTRY = Vector{ProblemDef}([
    ProblemDef(
        name="problem_2_1",
        matlab_file="problem_2_1.m",
        element_family="d1_spring",
        description="Two-element spring system",
    )
    ProblemDef(
        name="problem_3_1",
        matlab_file="problem_3_1.m",
        element_family="d1_truss",
        description="Three-bar truss",
        rtol=1e-8, atol=1e-10,
    ),
    ProblemDef(
        name="problem_4_2",
        matlab_file="problem_4_2.m",
        element_family="quadratic_bar",
        description="Quadratic bar element (pending impl)",
        rtol=1e-8, atol=1e-10,
    ),
    ProblemDef(
        name="problem_5_1",
        matlab_file="problem_5_1.m",
        element_family="d2_truss",
        description="2D plane truss, 6 nodes",
        rtol=1e-8, atol=1e-10,
    ),
    ProblemDef(
        name="problem_6_1",
        matlab_file="problem_6_1.m",
        element_family="d3_truss",
        description="3D space truss, 5 nodes",
        rtol=1e-8, atol=1e-10,
    ),
    ProblemDef(
        name="problem_7_1",
        matlab_file="problem_7_1.m",
        element_family="d2_beam",
        description="2D pure beam, 2 elements",
        rtol=1e-8, atol=1e-10,
    ),
    ProblemDef(
        name="problem_8_1",
        matlab_file="problem_8_1.m",
        element_family="d2_planeframe",
        description="2D plane frame, 2 elements",
        rtol=1e-8, atol=1e-10,
    ),
])
