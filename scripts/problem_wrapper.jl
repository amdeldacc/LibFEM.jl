# ═══════════════════════════════════════════════════════════════
# scripts/problem_wrapper.jl — Octave problem-script wrapper
# ═══════════════════════════════════════════════════════════════
# Generates and runs wrapper scripts around Kattan Solutions
# Manual problem .m files via Octave, parses JSON struct output,
# and optionally compares against Julia equivalents.
#
# Usage (from validate_matlab.jl or standalone):
#   include("scripts/problem_wrapper.jl")
#   using .ProblemWrapper
#   validate_problem("2.1")  # → Vector{ValidateResult}
# ═══════════════════════════════════════════════════════════════

module ProblemWrapper

using LibFEM
using Printf: @sprintf

const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)

include(joinpath(PROJECT_DIR, "test", "octave_runner.jl"))
using .OctaveRunner

# ─── Paths ────────────────────────────────────────────────────

"""Directory containing problem script .m files."""
const PROBLEMS_DIR = joinpath(PROJECT_DIR, "Doc", "Kattan", "Solutions-Manual")

"""Directory containing MATLAB reference .m files."""
const M_FILES_DIR = joinpath(PROJECT_DIR, "Doc", "Kattan", "M-Files")

# ─── Problem Variable Maps ────────────────────────────────────

"""
Dictionary mapping problem names (e.g. "2.1") to the list of
output variable names captured by the problem script.
"""
const PROBLEM_VARS = Dict(
    "2.1" => ["K", "k", "f", "u", "U", "F", "f1", "f2"],
    "2.2" => ["K", "k", "f", "u", "U", "F", "f2", "f3", "f4"],
    # Note: problem_2_2.m reuses `f2` for elements 1 and 2 (no `f1` variable)
    "3.1" => ["K", "k", "f", "u", "U", "F", "sigma1", "sigma2", "sigma3"],
    "3.3" => ["K", "k", "f", "u", "U", "F", "sigma1", "f2"],
    "4.2" => ["K", "k", "f", "u", "U", "F", "f1", "sigma2"],
    "5.1" => ["K", "k", "f", "u", "U", "F",
              "sigma1","sigma2","sigma3","sigma4","sigma5","sigma6","sigma7","sigma8","sigma9"],
    "5.2" => ["K", "k", "f", "u", "U", "F", "sigma1","sigma2","sigma3","f4"],
    "6.1" => ["K", "k", "f", "u", "U", "F", "sigma1","sigma2","sigma3","sigma4"],
    "7.1" => ["K", "k", "f", "u", "U", "F", "f1", "f2"],
    "7.2" => ["K", "k", "f", "u", "U", "F", "f1", "f2", "f3"],
    "7.3" => ["K", "k", "f", "u", "U", "F", "f1", "f2", "f3"],
    "8.1" => ["K", "k", "f", "u", "U", "F", "f1", "f2"],
    "8.2" => ["K", "k", "f", "u", "U", "F", "f1", "f2", "f3"],
    "8.3" => ["K", "k", "f", "u", "U", "F", "f1", "f2"],
)

"""All known problem names (sorted)."""
const PROBLEM_NAMES = sort(collect(keys(PROBLEM_VARS)))

# ─── Problem metadata ─────────────────────────────────────────

"""
    problem_variables(problem_name) -> Vector{String}

Return the list of output variable names for a given problem.
Throws `KeyError` for unknown problem names.
"""
function problem_variables(problem_name::AbstractString)
    return PROBLEM_VARS[problem_name]
end

"""
    problem_mfile_path(problem_name) -> String

Return the full path to the problem's .m file.
"""
function problem_mfile_path(problem_name::AbstractString)
    # Replace "." with "_" in problem name: "2.1" → "problem_2_1.m"
    fname = "problem_" * replace(problem_name, "." => "_") * ".m"
    return joinpath(PROBLEMS_DIR, fname)
end

# ─── Wrapper builder ──────────────────────────────────────────

"""
    build_problem_wrapper(mfile_path, output_vars) -> String

Read a problem .m file, strip the leading `clear; clc;`, and
append a `struct(...)` + `jsonencode(...)` capture block that
outputs the requested variables as a JSON object.

# Arguments
- `mfile_path::String`: Path to the problem .m file.
- `output_vars::Vector{String}`: Names of variables to capture.

# Returns
A complete Octave script string ready for `run_script`.
"""
function build_problem_wrapper(mfile_path::String, output_vars::Vector{String})
    script = read(mfile_path, String)

    # Strip `clear;` and `clc;` (don't clear workspace between runs)
    # They may appear on separate lines, possibly with trailing comments.
    script = replace(script, r"\s*clear\s*;.*" => "", count=1)
    script = replace(script, r"\s*clc\s*;.*" => "", count=1)

    # Suppress diagram/plot output — override diagram functions as no-ops
    # to avoid failing when gnuplot is not available (CI with --no-install-recommends).
    diagram_overrides = """
% Override diagram functions to prevent graphics toolkit errors on headless CI
function y = BeamElementMomentDiagram(f, L) y = [0; 0]; end
function y = BeamElementShearDiagram(f, L) y = [0; 0]; end
function y = PlaneFrameElementAxialDiagram(f, L) y = [0; 0]; end
function y = PlaneFrameElementMomentDiagram(f, L) y = [0; 0]; end
function y = PlaneFrameElementShearDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementAxialDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementShearYDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementShearZDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementMomentYDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementMomentZDiagram(f, L) y = [0; 0]; end
function y = SpaceFrameElementTorsionDiagram(f, L) y = [0; 0]; end

"""
    script = diagram_overrides * script * "\n\n"

    # Build the capture struct call
    # Octave struct('key1', val1, 'key2', val2, ...)
    var_pairs = String[]
    for v in output_vars
        push!(var_pairs, "'$(v)', $(v)")
    end
    capture = "result = struct($(join(var_pairs, ", ")));\ndisp(jsonencode(result));\n"

    return script * capture
end

# ─── Octave runner ────────────────────────────────────────────

"""
    run_problem_via_octave(mfile_path, output_vars) -> Dict{String,Any}

Run a problem script through Octave and return the captured
variables as a parsed Julia dictionary.

# Arguments
- `mfile_path::String`: Path to the problem .m file.
- `output_vars::Vector{String}`: Variable names to capture.

# Returns
A `Dict{String,Any}` mapping variable names to their values
(scalar Float64, Vector{Float64}, or Matrix{Float64}).

# Throws
- `OctaveError` if the Octave call fails.
"""
function run_problem_via_octave(mfile_path::String, output_vars::Vector{String})
    wrapper_script = build_problem_wrapper(mfile_path, output_vars)

    # Both the Solutions-Manual dir (for the problem script) and the
    # M-Files dir (for functions it calls) must be on the path.
    result = OctaveRunner.run_script(wrapper_script;
        dirs=[dirname(mfile_path), M_FILES_DIR],
        sanitize=false)

    if !result.success
        throw(OctaveRunner.OctaveError(
            "Octave run failed for $(basename(mfile_path))", result))
    end

    json_str = strip(result.output_json)
    if isempty(json_str)
        throw(OctaveRunner.OctaveError(
            "Empty output from Octave for $(basename(mfile_path))", result))
    end

    # Problem scripts don't use semicolons — Octave echoes intermediate values.
    # Find the last `{` in the output — the JSON struct is always at the end.
    json_str = _extract_last_json(json_str)

    return OctaveRunner.parse_octave_object(json_str)
end

# ═══════════════════════════════════════════════════════════════
# Julia problem equivalents (for comparison)
# ═══════════════════════════════════════════════════════════════
# Each function computes the same variables as the MATLAB problem
# script but using LibFEM.jl Julia functions.
#
# All 14 Kattan problems (2.1 through 8.3) have Julia equivalents.
# ═══════════════════════════════════════════════════════════════

"""
    run_julia_problem(problem_name) -> Union{Dict{String,Any}, Nothing}

Compute the same variables as the MATLAB problem script using
LibFEM.jl Julia functions. Returns `nothing` for problems that
do not yet have a Julia equivalent.

Implemented: "2.1", "2.2", "3.1", "3.3", "4.2", "5.1", "5.2",
"6.1", "7.1", "7.2", "7.3", "8.1", "8.2", "8.3".
"""
function run_julia_problem(problem_name::AbstractString)
    if problem_name == "2.1"
        return _problem_2_1_julia()
    elseif problem_name == "2.2"
        return _problem_2_2_julia()
    elseif problem_name == "3.1"
        return _problem_3_1_julia()
    elseif problem_name == "3.3"
        return _problem_3_3_julia()
    elseif problem_name == "4.2"
        return _problem_4_2_julia()
    elseif problem_name == "5.1"
        return _problem_5_1_julia()
    elseif problem_name == "5.2"
        return _problem_5_2_julia()
    elseif problem_name == "6.1"
        return _problem_6_1_julia()
    elseif problem_name == "7.1"
        return _problem_7_1_julia()
    elseif problem_name == "7.2"
        return _problem_7_2_julia()
    elseif problem_name == "7.3"
        return _problem_7_3_julia()
    elseif problem_name == "8.1"
        return _problem_8_1_julia()
    elseif problem_name == "8.2"
        return _problem_8_2_julia()
    elseif problem_name == "8.3"
        return _problem_8_3_julia()
    else
        return nothing
    end
end

"""Julia equivalent of Problem 2.1: Two-element spring system."""
function _problem_2_1_julia()
    k1 = d1_spring_elementstiffness(200.0)
    k2 = d1_spring_elementstiffness(250.0)

    K = zeros(3, 3)
    K = d1_spring_assemble(K, k1, 1, 2)
    K = d1_spring_assemble(K, k2, 2, 3)

    k = K[2, 2]
    f = [10.0]
    u = k \ f
    U = [0.0; u; 0.0]
    F = K * U

    u1 = [0.0; u]
    f1 = d1_spring_elementforce(k1, u1)

    u2 = [u; 0.0]
    f2 = d1_spring_elementforce(k2, u2)

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F, "f1" => f1, "f2" => f2,
    )
end

"""Julia equivalent of Problem 2.2: Four-element spring system."""
function _problem_2_2_julia()
    k1 = d1_spring_elementstiffness(170.0)
    k2 = d1_spring_elementstiffness(170.0)
    k3 = d1_spring_elementstiffness(170.0)
    k4 = d1_spring_elementstiffness(170.0)

    K = zeros(4, 4)
    K = d1_spring_assemble(K, k1, 1, 2)
    K = d1_spring_assemble(K, k2, 2, 3)
    K = d1_spring_assemble(K, k3, 2, 3)
    K = d1_spring_assemble(K, k4, 3, 4)

    k = K[2:4, 2:4]
    f = [0.0; 0.0; 25.0]
    u = k \ f
    U = [0.0; u]
    F = K * U
    # Zero out near-zero entries (same as MATLAB script)
    F[abs.(F) .< 1e-10] .= 0.0

    u1 = [0.0; U[2]]
    f1 = d1_spring_elementforce(k1, u1)

    u2 = [U[2]; U[3]]
    f2 = d1_spring_elementforce(k2, u2)

    u3 = [U[2]; U[3]]
    f3 = d1_spring_elementforce(k3, u3)

    u4 = [U[3]; U[4]]
    f4 = d1_spring_elementforce(k4, u4)

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2, "f3" => f3, "f4" => f4,
    )
end

"""Julia equivalent of Problem 3.1: Three-bar structure (d1_truss)."""
function _problem_3_1_julia()
    E = 70e6; A = 0.005; L1 = 1.0; L2 = 2.0; L3 = 1.0

    k1 = d1_truss_elementstiffness(E, A, L1)
    k2 = d1_truss_elementstiffness(E, A, L2)
    k3 = d1_truss_elementstiffness(E, A, L3)

    K = zeros(4, 4)
    K = d1_truss_assemble(K, k1, 1, 2)
    K = d1_truss_assemble(K, k2, 2, 3)
    K = d1_truss_assemble(K, k3, 3, 4)

    k = K[2:4, 2:4]
    f = [-10.0; 0.0; 15.0]
    u = k \ f
    U = [0.0; u]
    F = K * U

    sigma1 = d1_truss_elementstress(k1, [0.0; U[2]], A)
    sigma2 = d1_truss_elementstress(k2, [U[2]; U[3]], A)
    sigma3 = d1_truss_elementstress(k3, [U[3]; U[4]], A)

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "sigma1" => sigma1, "sigma2" => sigma2, "sigma3" => sigma3,
    )
end

"""Julia equivalent of Problem 3.3: Linear bar with a spring."""
function _problem_3_3_julia()
    E = 200e6; A = 0.01; L = 2.0; k_spring = 1000.0

    k1 = d1_truss_elementstiffness(E, A, L)
    k2 = d1_spring_elementstiffness(k_spring)

    K = zeros(3, 3)
    K = d1_truss_assemble(K, k1, 1, 2)
    K = d1_spring_assemble(K, k2, 2, 3)

    k = K[2:2, 2:2]
    f = [25.0]
    u = k \ f
    U = [0.0; u; 0.0]
    F = K * U

    sigma1 = d1_truss_elementstress(k1, [0.0; u], A)
    f2 = d1_spring_elementforce(k2, [u; 0.0])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "sigma1" => sigma1, "f2" => f2,
    )
end

"""Julia equivalent of Problem 4.2: Quadratic bar with a spring."""
function _problem_4_2_julia()
    E = 70e6; A = 0.001; L = 4.0; k_spring = 2000.0

    k1 = d1_spring_elementstiffness(k_spring)
    k2 = d1_quadraticbar_elementstiffness(E, A, L)

    K = zeros(4, 4)
    K = d1_spring_assemble(K, k1, 1, 2)
    K = d1_quadraticbar_assemble(K, k2, 2, 4, 3)

    k = K[2:4, 2:4]
    f = [0.0; 10.0; 5.0]
    u = k \ f
    U = [0.0; u]
    F = K * U

    f1 = d1_spring_elementforce(k1, [0.0; U[2]])
    sigma2 = d1_quadraticbar_elementstress(k2, [U[2]; U[4]; U[3]], A)

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "sigma2" => sigma2,
    )
end

"""Julia equivalent of Problem 5.1: Nine-element plane truss."""
function _problem_5_1_julia()
    E = 210e6; A = 0.005

    x = [0.0, 5.0, 5.0, 10.0, 10.0, 15.0]
    y = [0.0, 7.0, 0.0, 7.0, 0.0, 0.0]

    elements = [(1,2), (1,3), (2,3), (3,5), (2,5), (2,4), (4,5), (5,6), (4,6)]

    L_vals = Float64[]
    theta_vals = Float64[]
    k_vals = []

    for (n1, n2) in elements
        dx = x[n2] - x[n1]
        dy = y[n2] - y[n1]
        L = sqrt(dx^2 + dy^2)
        theta = atan(dy, dx) * 180 / pi
        push!(L_vals, L)
        push!(theta_vals, theta)
        push!(k_vals, d2_truss_elementstiffness(E, A, L, theta))
    end

    K = zeros(12, 12)
    for (idx, (n1, n2)) in enumerate(elements)
        d2_truss_assemble(K, k_vals[idx], n1, n2)
    end

    k = K[3:10, 3:10]
    f = [20.0; 0.0; zeros(6)...]
    u = k \ f
    U = [0.0; 0.0; u; 0.0; 0.0]
    F = K * U

    sigma = Float64[]
    for (idx, (n1, n2)) in enumerate(elements)
        u_elem = [U[2*n1-1]; U[2*n1]; U[2*n2-1]; U[2*n2]]
        push!(sigma, d2_truss_elementstress(E, L_vals[idx], theta_vals[idx], u_elem))
    end

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "sigma1" => sigma[1], "sigma2" => sigma[2], "sigma3" => sigma[3],
        "sigma4" => sigma[4], "sigma5" => sigma[5], "sigma6" => sigma[6],
        "sigma7" => sigma[7], "sigma8" => sigma[8], "sigma9" => sigma[9],
    )
end

"""Julia equivalent of Problem 5.2: Plane truss with a spring."""
function _problem_5_2_julia()
    E = 70e6; A = 0.01; k_spring = 3000.0

    x = [0.0, 0.0, 0.0, 4.0, 4.0]
    y = [0.0, 3.0, 7.0, 3.0, 3.0]

    L1 = d2_truss_elementlength(x[1], y[1], x[4], y[4])
    L2 = d2_truss_elementlength(x[2], y[2], x[4], y[4])
    L3 = d2_truss_elementlength(x[3], y[3], x[4], y[4])

    theta1 = atan(y[4] - y[1], x[4] - x[1]) * 180 / pi
    theta2 = atan(y[4] - y[2], x[4] - x[2]) * 180 / pi
    theta3 = atan(y[4] - y[3], x[4] - x[3]) * 180 / pi
    if theta3 < 0
        theta3 += 360.0
    end

    k1 = d2_truss_elementstiffness(E, A, L1, theta1)
    k2 = d2_truss_elementstiffness(E, A, L2, theta2)
    k3 = d2_truss_elementstiffness(E, A, L3, theta3)
    k4 = d1_spring_elementstiffness(k_spring)

    K = zeros(9, 9)
    K = d2_truss_assemble(K, k1, 1, 4)
    K = d2_truss_assemble(K, k2, 2, 4)
    K = d2_truss_assemble(K, k3, 3, 4)
    K = d1_spring_assemble(K, k4, 7, 9)

    k = K[7:9, 7:9]
    f = [0.0; 0.0; 10.0]
    u = k \ f
    U = [0.0; 0.0; 0.0; 0.0; 0.0; 0.0; u]
    F = K * U

    sigma1 = d2_truss_elementstress(E, L1, theta1, [U[1]; U[2]; U[7]; U[8]])
    sigma2 = d2_truss_elementstress(E, L2, theta2, [U[3]; U[4]; U[7]; U[8]])
    sigma3 = d2_truss_elementstress(E, L3, theta3, [U[5]; U[6]; U[7]; U[8]])

    f4 = d1_spring_elementforce(k4, [U[7]; U[9]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "sigma1" => sigma1, "sigma2" => sigma2, "sigma3" => sigma3,
        "f4" => f4,
    )
end

"""Julia equivalent of Problem 6.1: 3D space truss (4 elements)."""
function _problem_6_1_julia()
    E = 200e6; A = 0.003

    nodes = [
        (0.0,  0.0, -3.0),
        (-3.0, 0.0,  0.0),
        (0.0,  0.0,  3.0),
        (4.0,  0.0,  0.0),
        (0.0,  5.0,  0.0),
    ]
    elem_pairs = [(1,5), (2,5), (3,5), (4,5)]

    L_vals = Float64[]
    theta_x = Float64[]
    theta_y = Float64[]
    theta_z = Float64[]
    k_vals = []

    for (n1, n2) in elem_pairs
        x1, y1, z1 = nodes[n1]
        x2, y2, z2 = nodes[n2]
        L = d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
        push!(L_vals, L)
        tx = acos((x2 - x1) / L) * 180 / pi
        ty = acos((y2 - y1) / L) * 180 / pi
        tz = acos((z2 - z1) / L) * 180 / pi
        push!(theta_x, tx)
        push!(theta_y, ty)
        push!(theta_z, tz)
        push!(k_vals, d3_truss_elementstiffness(E, A, L, tx, ty, tz))
    end

    K = zeros(15, 15)
    for (idx, (n1, n2)) in enumerate(elem_pairs)
        d3_truss_assemble(K, k_vals[idx], n1, n2)
    end

    k = K[13:15, 13:15]
    f = [15.0; 0.0; -20.0]
    u = k \ f
    U = [zeros(12); u]
    F = K * U
    F[abs.(F) .< 1e-10] .= 0.0

    sigma = Float64[]
    for (idx, (n1, n2)) in enumerate(elem_pairs)
        u_elem = [U[3*n1-2]; U[3*n1-1]; U[3*n1]; U[3*n2-2]; U[3*n2-1]; U[3*n2]]
        push!(sigma, d3_truss_elementstress(E, L_vals[idx], theta_x[idx], theta_y[idx], theta_z[idx], u_elem))
    end

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "sigma1" => sigma[1], "sigma2" => sigma[2], "sigma3" => sigma[3], "sigma4" => sigma[4],
    )
end

"""Julia equivalent of Problem 7.1: Two-span beam with three supports."""
function _problem_7_1_julia()
    E = 200e6; I = 70e-5; L1 = 3.5; L2 = 2.0

    k1 = d2_beam_elementstiffness(E, I, L1)
    k2 = d2_beam_elementstiffness(E, I, L2)

    K = zeros(6, 6)
    K = d2_beam_assemble(K, k1, 1, 2)
    K = d2_beam_assemble(K, k2, 2, 3)

    k = K[[2, 4, 6], [2, 4, 6]]
    f = [0.0; -15.0; 0.0]
    u = k \ f
    U = zeros(6)
    U[[2, 4, 6]] = u
    F = K * U

    f1 = d2_beam_elementforces(k1, [U[1]; U[2]; U[3]; U[4]])
    f2 = d2_beam_elementforces(k2, [U[3]; U[4]; U[5]; U[6]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2,
    )
end

"""Julia equivalent of Problem 7.2: Beam with distributed load."""
function _problem_7_2_julia()
    E = 210e6; I = 50e-6; L1 = 3.0; L2 = 3.0; L3 = 4.0

    k1 = d2_beam_elementstiffness(E, I, L1)
    k2 = d2_beam_elementstiffness(E, I, L2)
    k3 = d2_beam_elementstiffness(E, I, L3)

    K = zeros(8, 8)
    K = d2_beam_assemble(K, k1, 1, 2)
    K = d2_beam_assemble(K, k2, 2, 3)
    K = d2_beam_assemble(K, k3, 3, 4)

    k = K[[4, 6, 8], [4, 6, 8]]
    f = [7.5; -15.0; 15.0]
    u = k \ f
    U = zeros(8)
    U[[4, 6, 8]] = u
    F = K * U

    f1 = d2_beam_elementforces(k1, [U[1]; U[2]; U[3]; U[4]])
    f1 = f1 - [-15.0; -7.5; -15.0; 7.5]

    f2 = d2_beam_elementforces(k2, [U[3]; U[4]; U[5]; U[6]])

    f3 = d2_beam_elementforces(k3, [U[5]; U[6]; U[7]; U[8]])
    f3 = f3 - [-15.0; -15.0; -15.0; 15.0]

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2, "f3" => f3,
    )
end

"""Julia equivalent of Problem 7.3: Beam with a spring."""
function _problem_7_3_julia()
    E = 70e6; I = 40e-6; L1 = 3.0; L2 = 3.0; k_spring = 5000.0

    k1 = d2_beam_elementstiffness(E, I, L1)
    k2 = d2_beam_elementstiffness(E, I, L2)
    k3 = d1_spring_elementstiffness(k_spring)

    K = zeros(7, 7)
    K = d2_beam_assemble(K, k1, 1, 2)
    K = d2_beam_assemble(K, k2, 2, 3)
    K = d1_spring_assemble(K, k3, 3, 7)

    k = vcat(hcat(K[3:4, 3:4], K[3:4, 6:6]), hcat(K[6:6, 3:4], K[6:6, 6:6]))
    f = [-10.0; 0.0; 0.0]
    u = k \ f
    U = [0.0; 0.0; u[1]; u[2]; 0.0; u[3]; 0.0]
    F = K * U
    F[abs.(F) .< 1e-10] .= 0.0

    f1 = d2_beam_elementforces(k1, [U[1]; U[2]; U[3]; U[4]])
    f2 = d2_beam_elementforces(k2, [U[3]; U[4]; U[5]; U[6]])
    f3 = d1_spring_elementforce(k3, [U[3]; U[7]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2, "f3" => f3,
    )
end

"""Julia equivalent of Problem 8.1: Plane frame with two elements."""
function _problem_8_1_julia()
    E = 210e6; A = 4e-2; I = 4e-6; L = 4.0

    k1 = d2_planeframe_elementstiffness(E, A, I, L, 90.0)
    k2 = d2_planeframe_elementstiffness(E, A, I, L, 0.0)

    K = zeros(9, 9)
    K = d2_planeframe_assemble(K, k1, 1, 2)
    K = d2_planeframe_assemble(K, k2, 2, 3)

    k = vcat(hcat(K[4:7, 4:7], K[4:7, 9:9]), hcat(K[9:9, 4:7], K[9:9, 9:9]))
    f = [0.0; 0.0; 15.0; 20.0; 0.0]
    u = k \ f
    U = [0.0; 0.0; 0.0; u[1:4]; 0.0; u[5]]
    F = K * U
    F[abs.(F) .< 1e-10] .= 0.0

    f1 = d2_planeframe_elementforces(E, A, I, L, 90.0, [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]])
    f2 = d2_planeframe_elementforces(E, A, I, L, 0.0, [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2,
    )
end

"""Julia equivalent of Problem 8.2: Plane frame with distributed load."""
function _problem_8_2_julia()
    E = 210e6; A = 1e-2; I = 9e-5

    x = [0.0, 2.0, 7.0, 9.0]
    y = [0.0, 3.0, 3.0, 0.0]

    L1 = d2_planeframe_elementlength(x[1], y[1], x[2], y[2])
    L2 = d2_planeframe_elementlength(x[2], y[2], x[3], y[3])
    L3 = d2_planeframe_elementlength(x[3], y[3], x[4], y[4])

    theta1 = atan(y[2] - y[1], x[2] - x[1]) * 180 / pi
    theta2 = 0.0
    theta3 = 360.0 - theta1

    k1 = d2_planeframe_elementstiffness(E, A, I, L1, theta1)
    k2 = d2_planeframe_elementstiffness(E, A, I, L2, theta2)
    k3 = d2_planeframe_elementstiffness(E, A, I, L3, theta3)

    K = zeros(12, 12)
    K = d2_planeframe_assemble(K, k1, 1, 2)
    K = d2_planeframe_assemble(K, k2, 2, 3)
    K = d2_planeframe_assemble(K, k3, 3, 4)

    k = K[4:9, 4:9]
    f = [20.0; -12.5; -10.417; 0.0; -12.5; 10.417]
    u = k \ f
    U = [0.0; 0.0; 0.0; u; 0.0; 0.0; 0.0]
    F = K * U
    F[abs.(F) .< 1e-10] .= 0.0

    f1 = d2_planeframe_elementforces(E, A, I, L1, theta1, [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]])
    f2 = d2_planeframe_elementforces(E, A, I, L2, theta2, [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]])
    f2 = f2 - [0.0; -12.5; -10.417; 0.0; -12.5; 10.417]
    f3 = d2_planeframe_elementforces(E, A, I, L3, theta3, [U[7]; U[8]; U[9]; U[10]; U[11]; U[12]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2, "f3" => f3,
    )
end

"""Julia equivalent of Problem 8.3: Plane frame with a spring (mixed elements)."""
function _problem_8_3_julia()
    E1 = 70e6; A1 = 1e-2; I = 1e-5
    E2 = 2500.0; A2 = 10.0; L2 = 5.0
    L1 = 4.0

    theta1 = 0.0
    theta2 = atan(3.0, 4.0) * 180 / pi

    k1 = d2_planeframe_elementstiffness(E1, A1, I, L1, theta1)
    k2 = d2_truss_elementstiffness(E2, A2, L2, theta2)

    K = zeros(8, 8)
    K = d2_planeframe_assemble(K, k1, 1, 2)
    K = d2_truss_assemble(K, k2, 1, 3)

    k = K[1:3, 1:3]
    f = [0.0; -10.0; 0.0]
    u = k \ f
    U = [u; 0.0; 0.0; 0.0; 0.0; 0.0]
    F = K * U
    F[abs.(F) .< 1e-10] .= 0.0

    f1 = d2_planeframe_elementforces(E1, A1, I, L1, theta1, [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]])
    f2 = d2_truss_elementforces(E2, A2, L2, theta2, [U[1]; U[2]; U[7]; U[8]])

    return Dict{String,Any}(
        "K" => K, "k" => k, "f" => f, "u" => u,
        "U" => U, "F" => F,
        "f1" => f1, "f2" => f2,
    )
end

# ═══════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════

# Reuse tolerance and result type from validate_matlab.jl
const RTOL = 1e-8
const ATOL = 1e-10

"""
    ValidateResult(label, julia_func, matlab_file, status, rel_error, abs_error, message)

Result of a single variable comparison.
"""
struct ValidateResult
    label::String
    julia_func::String
    matlab_file::String
    status::Symbol          # :pass :fail :error :skip
    rel_error::Float64
    abs_error::Float64
    message::String
end

"""
    validate_problem(problem_name) -> Vector{ValidateResult}

Run a problem through Octave, compare against the Julia equivalent
(if available), and return per-variable validation results.

If no Julia equivalent exists, each variable records a `:skip` status.
"""
function validate_problem(problem_name::AbstractString)
    results = ValidateResult[]

    mfile = problem_mfile_path(problem_name)
    if !isfile(mfile)
        push!(results, ValidateResult(
            "problem_$(problem_name)",
            "N/A", basename(mfile), :error,
            NaN, NaN, "File not found: $(mfile)"))
        return results
    end

    vars = problem_variables(problem_name)

    # 1. Run via Octave
    octave_data = try
        run_problem_via_octave(mfile, vars)
    catch e
        for v in vars
            label = "problem_$(replace(problem_name, "." => "_")).$(v)"
            push!(results, ValidateResult(
                label, "N/A", basename(mfile), :error,
                NaN, NaN, "Octave error: $(sprint(showerror, e))"))
        end
        return results
    end

    # 2. Run via Julia (if available)
    julia_data = run_julia_problem(problem_name)

    if julia_data === nothing
        # No Julia equivalent — record skip for each variable
        for v in vars
            label = "problem_$(replace(problem_name, "." => "_")).$(v)"
            val = get(octave_data, v, nothing)
            val_str = val === nothing ? "N/A" : _val_summary(val)
            push!(results, ValidateResult(
                label,
                "julia_$(problem_name)",
                basename(mfile), :skip,
                NaN, NaN,
                "Julia equivalent not yet implemented (Octave: $(val_str))"))
        end
    else
        # Compare each variable
        for v in vars
            label = "problem_$(replace(problem_name, "." => "_")).$(v)"
            octave_val = get(octave_data, v, nothing)
            julia_val = get(julia_data, v, nothing)

            if octave_val === nothing
                push!(results, ValidateResult(
                    label, "N/A", basename(mfile), :error,
                    NaN, NaN, "Variable '$v' not found in Octave output"))
                continue
            end

            if julia_val === nothing
                push!(results, ValidateResult(
                    label, "julia_$(problem_name)", basename(mfile), :skip,
                    NaN, NaN, "Variable '$v' not found in Julia equivalent"))
                continue
            end

            # Normalize and compare
            jv = _normalize_val(julia_val)
            ov = _normalize_val(octave_val)

            rel_err, abs_err = _compute_errors(jv, ov)
            ok = isapprox(jv, ov; rtol=RTOL, atol=ATOL)

            status = ok ? :pass : :fail
            msg = if !ok && abs_err < 1e-6
                "Small mismatch (rel=$(fmt_sci(rel_err)))"
            elseif !ok
                "Mismatch: rel=$(fmt_sci(rel_err))"
            else
                ""
            end

            push!(results, ValidateResult(
                label, "julia_$(problem_name)", basename(mfile),
                status, rel_err, abs_err, msg))
        end
    end

    return results
end

# ─── Helpers ──────────────────────────────────────────────────

_normalize_val(v::AbstractMatrix) = v
_normalize_val(v::AbstractVector) = v
_normalize_val(v::Number) = [v]

function _compute_errors(a::AbstractVector, b::AbstractVector)
    abs_err = maximum(abs.(a .- b))
    ref = max(maximum(abs.(b)), eps(Float64))
    rel_err = abs_err / ref
    return rel_err, abs_err
end

function _compute_errors(a::AbstractMatrix, b::AbstractMatrix)
    abs_err = maximum(abs.(a .- b))
    ref = max(maximum(abs.(b)), eps(Float64))
    rel_err = abs_err / ref
    return rel_err, abs_err
end

function _compute_errors(a, b)
    return NaN, NaN
end

"""Summarize a value for display in skip messages."""
function _val_summary(v::AbstractMatrix)
    return "$(size(v, 1))×$(size(v, 2)) matrix"
end
function _val_summary(v::AbstractVector)
    return "$(length(v))-element vector"
end
function _val_summary(v::Number)
    return @sprintf("%.4f", v)
end

function fmt_sci(val::Float64)
    if isnan(val) || isinf(val)
        return "  NaN   "
    elseif abs(val) < 1e-99
        return "0.00e+00"
    else
        return @sprintf("%9.2e", val)
    end
end

"""
    _extract_last_json(s) -> String

Extract the final JSON object `{...}` from a mixed output string.
Problem scripts echo intermediate values (no semicolons), so we
must find the last valid JSON struct at the end of the output.
Iterates `{` positions from right to left, using brace-balancing
to find a well-formed object.
"""
function _extract_last_json(s::AbstractString)
    s = strip(s)
    pos = findlast('{', s)
    while pos !== nothing
        cand = s[pos:end]
        bal = 0
        ok = true
        for c in cand
            if c == '{'
                bal += 1
            elseif c == '}'
                bal -= 1
                bal < 0 && (ok = false; break)
            end
        end
        if ok && bal == 0
            return cand
        end
        pos = pos > 1 ? findprev('{', s, pos - 1) : nothing
    end
    idx = findlast('{', s)
    return idx === nothing ? s : s[idx:end]
end

end  # module ProblemWrapper
