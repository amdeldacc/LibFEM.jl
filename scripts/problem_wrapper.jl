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

    # Strip `clear; clc;` (don't clear workspace between runs)
    # It may appear after the comment header, not necessarily at line 1.
    script = replace(script, r"clear\s*;\s*clc\s*;" => "")

    # Suppress diagram/plot output — some scripts call diagram functions
    # that would produce gnuplot warnings. We add a brief comment.
    script = script * "\n\n"

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
# Currently implemented: Problems 2.1, 2.2 (spring systems)
# All others return nothing (TODO — need Julia equivalents for
# truss/beam/plane-frame element systems).
# ═══════════════════════════════════════════════════════════════

"""
    run_julia_problem(problem_name) -> Union{Dict{String,Any}, Nothing}

Compute the same variables as the MATLAB problem script using
LibFEM.jl Julia functions. Returns `nothing` for problems that
do not yet have a Julia equivalent.

Currently implemented: "2.1", "2.2" (1-D spring systems).
"""
function run_julia_problem(problem_name::AbstractString)
    if problem_name == "2.1"
        return _problem_2_1_julia()
    elseif problem_name == "2.2"
        return _problem_2_2_julia()
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
must find the last JSON struct at the end of the output.
"""
function _extract_last_json(s::AbstractString)
    s = strip(s)
    idx = findlast('{', s)
    if idx === nothing
        return s
    end
    return s[idx:end]
end

end  # module ProblemWrapper
