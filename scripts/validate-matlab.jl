#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# scripts/validate-matlab.jl — Octave/MATLAB vs Julia comparison
# ═══════════════════════════════════════════════════════════════
# Compares LibFEM.jl Julia functions against MATLAB .m file
# reference implementations via GNU Octave.
#
# Usage:
#   julia --project=. scripts/validate-matlab.jl [element_type]
#
# element_type ∈ {spring, truss, beam, all}
#
# Exit codes:
#   0 — all tests within tolerance (rtol=1e-8)
#   1 — any discrepancy > tolerance
#   2 — Octave unavailable or version < 8
# ═══════════════════════════════════════════════════════════════

# ─── Bootstrap ──────────────────────────────────────────────────
using LibFEM
using Printf: @sprintf
using Test: @test

const SCRIPT_DIR = @__DIR__
const PROJECT_DIR = dirname(SCRIPT_DIR)

include(joinpath(PROJECT_DIR, "test", "octave_runner.jl"))
include(joinpath(PROJECT_DIR, "test", "matlab_adapters.jl"))
include(joinpath(PROJECT_DIR, "lib", "problem_wrapper.jl"))
using .OctaveRunner
using .ProblemWrapper

# ─── Paths & Constants ──────────────────────────────────────────

const M_FILES_DIR = joinpath(PROJECT_DIR, "Doc", "Kattan", "M-Files")
const RTOL = 1e-8
const ATOL = 1e-10

# ANSI color codes
const GREEN  = "\e[32m"
const RED    = "\e[31m"
const YELLOW = "\e[33m"
const CYAN   = "\e[36m"
const BOLD   = "\e[1m"
const RESET  = "\e[0m"

# ═════════════════════════════════════════════════════════════════
# Result Struct
# ═════════════════════════════════════════════════════════════════

struct ValidateResult
    label::String           # Display label (e.g. "d1_spring_elementstiffness")
    julia_func::String      # Julia function name
    matlab_file::String     # .m file basename
    status::Symbol          # :pass :fail :error :skip
    rel_error::Float64      # max relative error
    abs_error::Float64      # max absolute error
    message::String         # Error/annotation message
end

# ═════════════════════════════════════════════════════════════════
# Core Validation Helper
# ═════════════════════════════════════════════════════════════════

function run_validation(
    label::String,
    julia_func_name::String,
    matlab_file::String,
    matlab_func::String;
    julia_fn,
    matlab_args_fn,
    result_adapter::Function=adapt_result,
    dof::Int=2,
)
    m_path = joinpath(M_FILES_DIR, matlab_file)
    if !isfile(m_path)
        return ValidateResult(label, julia_func_name, matlab_file, :skip,
                              NaN, NaN, "File not found: $(matlab_file)")
    end

    # 1. Compute Julia result
    julia_val = try
        julia_fn()
    catch e
        return ValidateResult(label, julia_func_name, matlab_file, :error,
                              NaN, NaN, "Julia error: $(sprint(showerror, e))")
    end

    # 2. Compute MATLAB result via Octave
    matlab_val = try
        m_args = matlab_args_fn()
        octave_result = OctaveRunner.load_and_call(m_path, matlab_func, m_args...)
        result_adapter(octave_result, dof)
    catch e
        return ValidateResult(label, julia_func_name, matlab_file, :error,
                              NaN, NaN, "Octave error: $(sprint(showerror, e))")
    end

    # 3. Normalize types for comparison
    # Julia sometimes returns scalars where MATLAB returns 1-element vectors
    jv = _normalize_val(julia_val)
    mv = _normalize_val(matlab_val)
    rel_err, abs_err = compute_errors(jv, mv)
    ok = isapprox(jv, mv; rtol=RTOL, atol=ATOL)
    status = ok ? :pass : :fail

    msg = if !ok && abs_err < 1e-6
        "Small mismatch (rel=$(fmt_sci(rel_err)))"
    elseif !ok
        "Mismatch: rel=$(fmt_sci(rel_err))"
    else
        ""
    end

    return ValidateResult(label, julia_func_name, matlab_file, status, rel_err, abs_err, msg)
end

"""Normalize a value for comparison: scalar → 1-element vector, arrays stay as-is."""
_normalize_val(v::AbstractMatrix) = v  # Keep matrices as-is
_normalize_val(v::AbstractVector) = v
_normalize_val(v::Number) = [v]

function compute_errors(a::AbstractVector, b::AbstractVector)
    abs_err = maximum(abs.(a .- b))
    ref = max(maximum(abs.(b)), eps(Float64))
    rel_err = abs_err / ref
    return rel_err, abs_err
end

function compute_errors(a::AbstractMatrix, b::AbstractMatrix)
    abs_err = maximum(abs.(a .- b))
    ref = max(maximum(abs.(b)), eps(Float64))
    rel_err = abs_err / ref
    return rel_err, abs_err
end

function compute_errors(a, b)
    return NaN, NaN
end

# ═════════════════════════════════════════════════════════════════
# Symbolic Math Detection (some MATLAB .m files use Symbolic Toolbox)
# ═════════════════════════════════════════════════════════════════

"""Cache for Octave symbolic support check."""
const _OCTAVE_SYMS_CACHE = Ref{Union{Nothing,Bool}}(nothing)

"""
    _has_octave_syms() -> Bool

Check if the current Octave installation supports symbolic math (`syms`).
Cached after first call. Returns `false` if unsupported, which is used
to skip tests that depend on Symbolic Toolbox features.
"""
function _has_octave_syms()
    if _OCTAVE_SYMS_CACHE[] !== nothing
        return _OCTAVE_SYMS_CACHE[]
    end
    result = try
        script = "syms x;\ndisp(jsonencode(1.0));"
        r = OctaveRunner.run_script(script; timeout=5.0)
        r.success
    catch
        false
    end
    _OCTAVE_SYMS_CACHE[] = result
    return result
end

# ═════════════════════════════════════════════════════════════════
# Formatting Helpers
# ═════════════════════════════════════════════════════════════════

function fmt_sci(val::Float64)
    if isnan(val) || isinf(val)
        return "  NaN   "
    elseif abs(val) < 1e-99
        return "0.00e+00"
    else
        return @sprintf("%9.2e", val)
    end
end

function status_str(s::Symbol)
    s == :pass  && return "$(GREEN)✓$(RESET)  "
    s == :fail  && return "$(RED)✗$(RESET)  "
    s == :error && return "$(RED)E$(RESET)  "
    s == :skip  && return "$(YELLOW)⚠$(RESET)  "
    return "?   "
end

function print_separator(char="─", len=80)
    println(repeat(char, len))
end

function print_centered(text, width=80)
    pad = max(0, width - length(text)) ÷ 2
    println(repeat(" ", pad), text)
end

function print_results(results::Vector{ValidateResult}, title::String)
    n = length(results)
    n > 0 || return

    print_centered(" $(title) ", 80)
    print_separator()

    # Header
    println(" $(BOLD)Status  Julia Function                    MATLAB .m File                   Rel Error    Abs Error$(RESET)")
    print_separator("─", 80)

    for r in results
        status = status_str(r.status)
        jf = rpad(r.julia_func, 38)[1:min(end, 38)]
        mf = rpad(basename(r.matlab_file), 34)[1:min(end, 34)]
        re_str = fmt_sci(r.rel_error)
        ae_str = fmt_sci(r.abs_error)
        println("  $(status) $(jf) $(mf) $(re_str)  $(ae_str)")
        if !isempty(r.message) && r.status == :fail
            println("  $(YELLOW)└─ $(r.message)$(RESET)")
        elseif !isempty(r.message)
            println("  $(RED)└─ $(r.message)$(RESET)")
        end
    end
    println()
end

function print_summary(all_results::Vector{ValidateResult})
    total = length(all_results)
    passed = count(r -> r.status == :pass, all_results)
    failed = count(r -> r.status == :fail, all_results)
    errors = count(r -> r.status == :error, all_results)
    skipped = count(r -> r.status == :skip, all_results)

    max_rel = maximum([r.rel_error for r in all_results if r.status ∈ (:pass, :fail) && !isnan(r.rel_error)]; init=0.0)
    max_abs = maximum([r.abs_error for r in all_results if r.status ∈ (:pass, :fail) && !isnan(r.abs_error)]; init=0.0)

    print_separator("═", 80)
    passed_str = failed > 0 ? "$(RED)$(passed) passed$(RESET)" : "$(GREEN)$(passed) passed$(RESET)"
    print(" $(BOLD)Summary:$(RESET) $(passed_str)")

    if failed > 0
        print(" | $(RED)$(failed) failed$(RESET)")
    end
    if errors > 0
        print(" | $(RED)$(errors) errors$(RESET)")
    end
    if skipped > 0
        print(" | $(YELLOW)$(skipped) skipped$(RESET)")
    end
    if passed + failed + errors > 0
        n_tested = passed + failed + errors
        print(" | Total tested: $(n_tested)")
    end

    println()
    if passed + failed > 0
        println(" Max rel error: $(fmt_sci(max_rel)) | Max abs error: $(fmt_sci(max_abs))")
    end

    # Only non-skipped results count toward pass/fail
    tested = filter(r -> r.status != :skip, all_results)
    return all(r -> r.status == :pass, tested)
end

# ═════════════════════════════════════════════════════════════════
# Element Family Test Definitions
# ═════════════════════════════════════════════════════════════════
# Each function returns Vector{ValidateResult}
# ═════════════════════════════════════════════════════════════════

function test_spring()
    results = ValidateResult[]

    # ── 1D Spring Stiffness (k=200) ──
    push!(results, run_validation(
        "d1_spring_elementstiffness(200)",
        "d1_spring_elementstiffness",
        "SpringElementStiffness.m", "SpringElementStiffness";
        julia_fn = () -> d1_spring_elementstiffness(200.0),
        matlab_args_fn = () -> adapt_spring_args(200.0),
        result_adapter = adapt_spring_result, dof = 2,
    ))

    # ── 1D Spring Forces (k=200, u = [10/450, 0]) ──
    ke = d1_spring_elementstiffness(200.0)
    u = [10.0 / 450.0, 0.0]  # from Problem 2.1
    push!(results, run_validation(
        "d1_spring_elementforce(Ke, u)",
        "d1_spring_elementforce",
        "SpringElementForces.m", "SpringElementForces";
        julia_fn = () -> d1_spring_elementforce(ke, u),
        matlab_args_fn = () -> adapt_spring_args(ke, u),
        result_adapter = adapt_spring_result, dof = 2,
    ))

    return results
end

function test_truss()
    results = ValidateResult[]

    # ── 1D Truss / LinearBar ──
    E1, A1, L1 = 70e6, 0.005, 1.0
    k1 = d1_bar_elementstiffness(E1, A1, L1)
    u1 = [1.0 / 70000.0, 0.0]  # from Problem 3.1, element 1

    # Stiffness
    push!(results, run_validation(
        "d1_bar_elementstiffness(E, A, L)",
        "d1_bar_elementstiffness",
        "LinearBarElementStiffness.m", "LinearBarElementStiffness";
        julia_fn = () -> d1_bar_elementstiffness(E1, A1, L1),
        matlab_args_fn = () -> adapt_truss_args(E1, A1, L1),
        result_adapter = adapt_truss_result, dof = 2,
    ))

    # Forces
    push!(results, run_validation(
        "d1_bar_elementforces(Ke, u)",
        "d1_bar_elementforces",
        "LinearBarElementForces.m", "LinearBarElementForces";
        julia_fn = () -> d1_bar_elementforces(k1, u1),
        matlab_args_fn = () -> adapt_truss_args(k1, u1),
        result_adapter = adapt_truss_result, dof = 2,
    ))

    # Stress
    push!(results, run_validation(
        "d1_bar_elementstress(Ke, u, A)",
        "d1_bar_elementstress",
        "LinearBarElementStresses.m", "LinearBarElementStresses";
        julia_fn = () -> d1_bar_elementstress(k1, u1, A1),
        matlab_args_fn = () -> adapt_truss_args(k1, u1, A1),
        result_adapter = adapt_truss_result, dof = 2,
    ))

    # ── 2D Truss / PlaneTruss ──
    E2, A2 = 70e6, 0.01
    x1, y1, x2, y2 = 0.0, 0.0, 4.0, 3.0
    L2 = d2_truss_elementlength(x1, y1, x2, y2)  # = 5.0
    theta2 = rad2deg(atan(3, 4))

    # Length
    push!(results, run_validation(
        "d2_truss_elementlength(x1, y1, x2, y2)",
        "d2_truss_elementlength",
        "PlaneTrussElementLength.m", "PlaneTrussElementLength";
        julia_fn = () -> d2_truss_elementlength(x1, y1, x2, y2),
        matlab_args_fn = () -> adapt_truss_length_args(x1, y1, x2, y2),
        result_adapter = (r, n) -> r isa Number ? [r] : vec(r),
        dof = 1,
    ))

    # Stiffness
    push!(results, run_validation(
        "d2_truss_elementstiffness(E, A, L, θ)",
        "d2_truss_elementstiffness",
        "PlaneTrussElementStiffness.m", "PlaneTrussElementStiffness";
        julia_fn = () -> d2_truss_elementstiffness(E2, A2, L2, theta2),
        matlab_args_fn = () -> adapt_truss_args(E2, A2, L2, theta2),
        result_adapter = adapt_truss_result, dof = 4,
    ))

    # Force
    u2 = [0.0, 0.0, 1e-4, 0.0]
    push!(results, run_validation(
        "d2_truss_elementforces(E, A, L, θ, u)",
        "d2_truss_elementforces",
        "PlaneTrussElementForce.m", "PlaneTrussElementForce";
        julia_fn = () -> d2_truss_elementforces(E2, A2, L2, theta2, u2),
        matlab_args_fn = () -> adapt_truss_args(E2, A2, L2, theta2, u2),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stress
    push!(results, run_validation(
        "d2_truss_elementstress(E, L, θ, u)",
        "d2_truss_elementstress",
        "PlaneTrussElementStress.m", "PlaneTrussElementStress";
        julia_fn = () -> d2_truss_elementstress(E2, L2, theta2, u2),
        matlab_args_fn = () -> adapt_truss_args(E2, L2, theta2, u2),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # ── 3D Truss / SpaceTruss ──
    E3, A3, L3 = 1.0, 1.0, 1.0
    θx, θy, θz = 0.0, 90.0, 90.0
    u3 = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    # Length
    push!(results, run_validation(
        "d3_truss_elementlength(x1, y1, z1, x2, y2, z2)",
        "d3_truss_elementlength",
        "SpaceTrussElementLength.m", "SpaceTrussElementLength";
        julia_fn = () -> d3_truss_elementlength(0.0, 0.0, 0.0, 1.0, 1.0, 1.0),
        matlab_args_fn = () -> adapt_truss_length_args(0.0, 0.0, 0.0, 1.0, 1.0, 1.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness
    push!(results, run_validation(
        "d3_truss_elementstiffness(E, A, L, θx, θy, θz)",
        "d3_truss_elementstiffness",
        "SpaceTrussElementStiffness.m", "SpaceTrussElementStiffness";
        julia_fn = () -> d3_truss_elementstiffness(E3, A3, L3, θx, θy, θz),
        matlab_args_fn = () -> adapt_truss_args(E3, A3, L3, θx, θy, θz),
        result_adapter = adapt_truss_result, dof = 6,
    ))

    # Force
    push!(results, run_validation(
        "d3_truss_elementforces(E, A, L, θx, θy, θz, u)",
        "d3_truss_elementforces",
        "SpaceTrussElementForce.m", "SpaceTrussElementForce";
        julia_fn = () -> d3_truss_elementforces(E3, A3, L3, θx, θy, θz, u3),
        matlab_args_fn = () -> adapt_truss_args(E3, A3, L3, θx, θy, θz, u3),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stress
    push!(results, run_validation(
        "d3_truss_elementstress(E, L, θx, θy, θz, u)",
        "d3_truss_elementstress",
        "SpaceTrussElementStress.m", "SpaceTrussElementStress";
        julia_fn = () -> d3_truss_elementstress(E3, L3, θx, θy, θz, u3),
        matlab_args_fn = () -> adapt_truss_args(E3, L3, θx, θy, θz, u3),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    return results
end

function test_beam()
    results = ValidateResult[]

    # ── 2D PlaneFrame (formerly d2_beam)
    E2, A2, I2, L2 = 210e6, 4e-2, 4e-6, 4.0
    θ2 = 0.0

    # Length
    push!(results, run_validation(
        "d2_planeframe_elementlength(x1, y1, x2, y2)",
        "d2_planeframe_elementlength",
        "PlaneFrameElementLength.m", "PlaneFrameElementLength";
        julia_fn = () -> d2_planeframe_elementlength(0.0, 0.0, 4.0, 0.0),
        matlab_args_fn = () -> adapt_beam_args(0.0, 0.0, 4.0, 0.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness
    push!(results, run_validation(
        "d2_planeframe_elementstiffness(E, A, I, L, θ)",
        "d2_planeframe_elementstiffness",
        "PlaneFrameElementStiffness.m", "PlaneFrameElementStiffness";
        julia_fn = () -> d2_planeframe_elementstiffness(E2, A2, I2, L2, θ2),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # Forces (using zero displacement)
    u2 = zeros(6)
    push!(results, run_validation(
        "d2_planeframe_elementforces(E, A, I, L, θ, u=0)",
        "d2_planeframe_elementforces",
        "PlaneFrameElementForces.m", "PlaneFrameElementForces";
        julia_fn = () -> d2_planeframe_elementforces(E2, A2, I2, L2, θ2, u2),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2, u2),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # Forces (with displacement from Problem 8.1, element 2)
    # Using computed & verified values (previously in comparison.jl)
    u2_loaded = [0.1865, 0.0, -0.0298, 0.1865, 0.0, 0.0149]
    push!(results, run_validation(
        "d2_planeframe_elementforces(E, A, I, L, θ, u)",
        "d2_planeframe_elementforces",
        "PlaneFrameElementForces.m", "PlaneFrameElementForces";
        julia_fn = () -> d2_planeframe_elementforces(E2, A2, I2, L2, θ2, u2_loaded),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2, u2_loaded),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # ── 3D Beam / SpaceFrame ──
    E3, G3, A3 = 210e6, 84e6, 2e-2
    Iy3, Iz3, J3 = 10e-5, 20e-5, 5e-5

    # Length
    push!(results, run_validation(
        "d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)",
        "d3_spaceframe_elementlength",
        "SpaceFrameElementLength.m", "SpaceFrameElementLength";
        julia_fn = () -> d3_spaceframe_elementlength(0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        matlab_args_fn = () -> adapt_space_frame_args(0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness (along x-axis: horizontal member from Problem 10.1)
    push!(results, run_validation(
        "d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, coords)",
        "d3_spaceframe_elementstiffness",
        "SpaceFrameElementStiffness.m", "SpaceFrameElementStiffness";
        julia_fn = () -> d3_spaceframe_elementstiffness(E3, G3, A3, Iy3, Iz3, J3,
                                                    0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        matlab_args_fn = () -> adapt_space_frame_args(E3, G3, A3, Iy3, Iz3, J3,
                                                       0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        result_adapter = adapt_space_frame_result, dof = 12,
    ))

    # Forces (with zero displacement)
    u3 = zeros(12)
    push!(results, run_validation(
        "d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, coords, u=0)",
        "d3_spaceframe_elementforces",
        "SpaceFrameElementForces.m", "SpaceFrameElementForces";
        julia_fn = () -> d3_spaceframe_elementforces(E3, G3, A3, Iy3, Iz3, J3,
                                               0.0, 0.0, 0.0, 4.0, 0.0, 0.0, u3),
        matlab_args_fn = () -> adapt_space_frame_args(E3, G3, A3, Iy3, Iz3, J3,
                                                       0.0, 0.0, 0.0, 4.0, 0.0, 0.0, u3),
        result_adapter = adapt_space_frame_result, dof = 12,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# Grid Element (Kattan Ch11)
# ═════════════════════════════════════════════════════════════════

function test_grid()
    results = ValidateResult[]

    E, G, I, J, L = 210e6, 84e6, 4e-6, 2e-6, 4.0
    θ = 0.0

    # Length
    push!(results, run_validation(
        "d2_grid_elementlength(x1, y1, x2, y2)",
        "d2_grid_elementlength",
        "GridElementLength.m", "GridElementLength";
        julia_fn = () -> d2_grid_elementlength(0.0, 0.0, 4.0, 0.0),
        matlab_args_fn = () -> adapt_grid_args(0.0, 0.0, 4.0, 0.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness
    push!(results, run_validation(
        "d2_grid_elementstiffness(E, G, I, J, L, θ)",
        "d2_grid_elementstiffness",
        "GridElementStiffness.m", "GridElementStiffness";
        julia_fn = () -> d2_grid_elementstiffness(E, G, I, J, L, θ),
        matlab_args_fn = () -> adapt_grid_args(E, G, I, J, L, θ),
        result_adapter = adapt_grid_result, dof = 6,
    ))

    # Forces (zero displacement)
    u = zeros(6)
    push!(results, run_validation(
        "d2_grid_elementforces(E, G, I, J, L, θ, u=0)",
        "d2_grid_elementforces",
        "GridElementForces.m", "GridElementForces";
        julia_fn = () -> d2_grid_elementforces(E, G, I, J, L, θ, u),
        matlab_args_fn = () -> adapt_grid_args(E, G, I, J, L, θ, u),
        result_adapter = adapt_grid_result, dof = 6,
    ))

    # Forces (with unit vertical displacement at node 1)
    u = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    push!(results, run_validation(
        "d2_grid_elementforces(E, G, I, J, L, θ, u=[1,0,0,0,0,0])",
        "d2_grid_elementforces",
        "GridElementForces.m", "GridElementForces";
        julia_fn = () -> d2_grid_elementforces(E, G, I, J, L, θ, u),
        matlab_args_fn = () -> adapt_grid_args(E, G, I, J, L, θ, u),
        result_adapter = adapt_grid_result, dof = 6,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# Problem Script Validation
# ═════════════════════════════════════════════════════════════════

function test_problems()
    results = ValidateResult[]
    problems = ProblemWrapper.PROBLEM_NAMES

    for pn in problems
        pw_results = ProblemWrapper.validate_problem(pn)
        # Convert ProblemWrapper.ValidateResult → local ValidateResult
        for r in pw_results
            push!(results, ValidateResult(
                r.label, r.julia_func, r.matlab_file,
                r.status, r.rel_error, r.abs_error, r.message))
        end
    end

    return results
end

# ═════════════════════════════════════════════════════════════════
# CST / Linear Triangle (Kattan Ch11)
# ═════════════════════════════════════════════════════════════════

function test_cst()
    results = ValidateResult[]

    E = 200e9; NU = 0.3; t = 0.01
    x1, y1 = 0.0, 0.0
    x2, y2 = 1.0, 0.0
    x3, y3 = 0.0, 1.0
    p = 1  # plane stress

    # ── Stiffness (6×6) ──
    push!(results, run_validation(
        "d2_cst_elementstiffness(E,NU,t,x1,y1,x2,y2,x3,y3,p)",
        "d2_cst_elementstiffness",
        "LinearTriangleElementStiffness.m", "LinearTriangleElementStiffness";
        julia_fn = () -> d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p),
        matlab_args_fn = () -> adapt_cst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p),
        result_adapter = adapt_cst_result, dof = 6,
    ))

    # ── Area ──
    push!(results, run_validation(
        "d2_cst_elementarea(x1,y1,x2,y2,x3,y3)",
        "d2_cst_elementarea",
        "LinearTriangleElementArea.m", "LinearTriangleElementArea";
        julia_fn = () -> d2_cst_elementarea(x1, y1, x2, y2, x3, y3),
        matlab_args_fn = () -> adapt_cst_area_args(x1, y1, x2, y2, x3, y3),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # ── Stress (zero displacement) ──
    u = zeros(6)
    push!(results, run_validation(
        "d2_cst_elementstress(E,NU,x1,y1,x2,y2,x3,y3,p,u=0)",
        "d2_cst_elementstress",
        "LinearTriangleElementStresses.m", "LinearTriangleElementStresses";
        julia_fn = () -> d2_cst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, p, u),
        matlab_args_fn = () -> adapt_cst_stress_args(E, NU, t, x1, y1, x2, y2, x3, y3, p, u),
        result_adapter = adapt_cst_result, dof = 3,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# LST / Quadratic Triangle (Kattan Ch12)
# ═════════════════════════════════════════════════════════════════
# NOTE: MATLAB uses Symbolic Math Toolbox (syms, int).
# If Octave lacks the symbolic package, this test will be skipped.

function test_lst()
    results = ValidateResult[]

    E = 200e9; NU = 0.3; t = 0.01
    # Corner nodes
    x1, y1 = 0.0, 0.0; x2, y2 = 1.0, 0.0; x3, y3 = 0.0, 1.0
    # Mid-edge nodes (computed internally by MATLAB)
    x4, y4 = 0.5, 0.0; x5, y5 = 0.5, 0.5; x6, y6 = 0.0, 0.5
    p = 1

    # ── Stiffness (12×12) — MATLAB uses syms ──
    if !_has_octave_syms()
        push!(results, ValidateResult(
            "d2_lst_elementstiffness(E,NU,t,...)",
            "d2_lst_elementstiffness",
            "QuadTriangleElementStiffness.m", :skip, NaN, NaN,
            "Skipped: Octave lacks symbolic package (syms)"))
    else
        push!(results, run_validation(
            "d2_lst_elementstiffness(E,NU,t,x1,y1,x2,y2,x3,y3,p)",
            "d2_lst_elementstiffness",
            "QuadTriangleElementStiffness.m", "QuadTriangleElementStiffness";
            julia_fn = () -> d2_lst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3,
                                                     x4, y4, x5, y5, x6, y6, p),
            matlab_args_fn = () -> adapt_lst_args(E, NU, t, x1, y1, x2, y2, x3, y3, p),
            result_adapter = adapt_lst_result, dof = 12,
        ))
    end

    return results
end

# ═════════════════════════════════════════════════════════════════
# Q4 / Bilinear Quadrilateral (Kattan Ch13)
# ═════════════════════════════════════════════════════════════════
# NOTE: MATLAB stiffness uses Symbolic Math Toolbox (syms, int).
# Area calculation is numeric-only.

function test_q4()
    results = ValidateResult[]

    E = 200e9; NU = 0.3; h = 0.01
    x1, y1 = 0.0, 0.0; x2, y2 = 1.0, 0.0
    x3, y3 = 1.0, 1.0; x4, y4 = 0.0, 1.0
    p = 1

    # ── Area (numeric, always works) ──
    push!(results, run_validation(
        "d2_q4_elementarea(x1,y1,x2,y2,x3,y3,x4,y4)",
        "d2_q4_elementarea",
        "BilinearQuadElementArea.m", "BilinearQuadElementArea";
        julia_fn = () -> d2_q4_elementarea(x1, y1, x2, y2, x3, y3, x4, y4),
        matlab_args_fn = () -> adapt_q4_area_args(x1, y1, x2, y2, x3, y3, x4, y4),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # ── Stiffness (8×8) — MATLAB uses syms ──
    if !_has_octave_syms()
        push!(results, ValidateResult(
            "d2_q4_elementstiffness(E,NU,h,...)",
            "d2_q4_elementstiffness",
            "BilinearQuadElementStiffness.m", :skip, NaN, NaN,
            "Skipped: Octave lacks symbolic package (syms)"))
    else
        push!(results, run_validation(
            "d2_q4_elementstiffness(E,NU,h,x1,y1,x2,y2,x3,y3,x4,y4,p)",
            "d2_q4_elementstiffness",
            "BilinearQuadElementStiffness.m", "BilinearQuadElementStiffness";
            julia_fn = () -> d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p),
            matlab_args_fn = () -> adapt_q4_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p),
            result_adapter = adapt_q4_result, dof = 8,
        ))
    end

    return results
end

# ═════════════════════════════════════════════════════════════════
# Q8 / Quadratic Quadrilateral (Kattan Ch14)
# ═════════════════════════════════════════════════════════════════
# NOTE: MATLAB stiffness uses Symbolic Math Toolbox (syms, int).
# Area calculation is numeric-only.

function test_q8()
    results = ValidateResult[]

    E = 200e9; NU = 0.3; h = 0.01
    # Corner nodes
    x1, y1 = 0.0, 0.0; x2, y2 = 1.0, 0.0
    x3, y3 = 1.0, 1.0; x4, y4 = 0.0, 1.0
    # Mid-edge nodes (computed internally by MATLAB)
    x5, y5 = 0.5, 0.0; x6, y6 = 1.0, 0.5
    x7, y7 = 0.5, 1.0; x8, y8 = 0.0, 0.5
    p = 1

    # ── Stiffness (16×16) — MATLAB uses syms ──
    if !_has_octave_syms()
        push!(results, ValidateResult(
            "d2_q8_elementstiffness(E,NU,h,...)",
            "d2_q8_elementstiffness",
            "QuadraticQuadElementStiffness.m", :skip, NaN, NaN,
            "Skipped: Octave lacks symbolic package (syms)"))
    else
        push!(results, run_validation(
            "d2_q8_elementstiffness(E,NU,h,x1,y1,x2,y2,x3,y3,x4,y4,p)",
            "d2_q8_elementstiffness",
            "QuadraticQuadElementStiffness.m", "QuadraticQuadElementStiffness";
            julia_fn = () -> d2_q8_elementstiffness(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4,
                                                    x5, y5, x6, y6, x7, y7, x8, y8, p),
            matlab_args_fn = () -> adapt_q8_args(E, NU, h, x1, y1, x2, y2, x3, y3, x4, y4, p),
            result_adapter = adapt_q8_result, dof = 16,
        ))
    end

    return results
end

# ═════════════════════════════════════════════════════════════════
# Tet / Linear Tetrahedron (Kattan Ch15)
# ═════════════════════════════════════════════════════════════════

function test_tet()
    results = ValidateResult[]

    E = 200e9; NU = 0.3
    x1, y1, z1 = 0.0, 0.0, 0.0
    x2, y2, z2 = 1.0, 0.0, 0.0
    x3, y3, z3 = 0.0, 1.0, 0.0
    x4, y4, z4 = 0.0, 0.0, 1.0

    # ── Volume ──
    push!(results, run_validation(
        "d3_tet_elementvolume(x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)",
        "d3_tet_elementvolume",
        "TetrahedronElementVolume.m", "TetrahedronElementVolume";
        julia_fn = () -> d3_tet_elementvolume(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4),
        matlab_args_fn = () -> adapt_tet_volume_args(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # ── Stiffness (12×12) ──
    push!(results, run_validation(
        "d3_tet_elementstiffness(E,NU,x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4)",
        "d3_tet_elementstiffness",
        "TetrahedronElementStiffness.m", "TetrahedronElementStiffness";
        julia_fn = () -> d3_tet_elementstiffness(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4),
        matlab_args_fn = () -> adapt_tet_args(E, NU, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4),
        result_adapter = adapt_tet_result, dof = 12,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# Brick / Linear Hexahedron (Kattan Ch16)
# ═════════════════════════════════════════════════════════════════
# NOTE: MATLAB uses Symbolic Math Toolbox (syms, int).

function test_brick()
    results = ValidateResult[]

    E = 200e9; NU = 0.3
    # Unit cube: bottom face CCW, top face CCW
    x1, y1, z1 = 0.0, 0.0, 0.0
    x2, y2, z2 = 1.0, 0.0, 0.0
    x3, y3, z3 = 1.0, 1.0, 0.0
    x4, y4, z4 = 0.0, 1.0, 0.0
    x5, y5, z5 = 0.0, 0.0, 1.0
    x6, y6, z6 = 1.0, 0.0, 1.0
    x7, y7, z7 = 1.0, 1.0, 1.0
    x8, y8, z8 = 0.0, 1.0, 1.0

    # ── Stiffness (24×24) — MATLAB uses syms ──
    if !_has_octave_syms()
        push!(results, ValidateResult(
            "d3_brick_elementstiffness(E,NU,...)",
            "d3_brick_elementstiffness",
            "LinearBrickElementStiffness.m", :skip, NaN, NaN,
            "Skipped: Octave lacks symbolic package (syms)"))
    else
        push!(results, run_validation(
            "d3_brick_elementstiffness(E,NU,x1,y1,z1,...,x8,y8,z8)",
            "d3_brick_elementstiffness",
            "LinearBrickElementStiffness.m", "LinearBrickElementStiffness";
            julia_fn = () -> d3_brick_elementstiffness(E, NU,
                x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
                x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8),
            matlab_args_fn = () -> adapt_brick_args(E, NU,
                x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4,
                x5, y5, z5, x6, y6, z6, x7, y7, z7, x8, y8, z8),
            result_adapter = adapt_brick_result, dof = 24,
        ))
    end

    return results
end

# ═════════════════════════════════════════════════════════════════
# Fluid Flow 1D (Kattan Ch17)
# ═════════════════════════════════════════════════════════════════

function test_fluidflow()
    results = ValidateResult[]

    Kxx = 1e-5; A = 0.1; L = 10.0
    p = [10.0, 0.0]  # nodal potentials (head)

    # ── Stiffness (2×2) ──
    push!(results, run_validation(
        "d1_fluidflow_elementstiffness(Kxx, A, L)",
        "d1_fluidflow_elementstiffness",
        "FluidFlow1DElementStiffness.m", "FluidFlow1DElementStiffness";
        julia_fn = () -> d1_fluidflow_elementstiffness(Kxx, A, L),
        matlab_args_fn = () -> adapt_fluidflow_args(Kxx, A, L),
        result_adapter = adapt_fluidflow_result, dof = 2,
    ))

    # ── Velocity (scalar) ──
    push!(results, run_validation(
        "d1_fluidflow_elementvelocity(Kxx, L, p)",
        "d1_fluidflow_elementvelocity",
        "FluidFlow1DElementVelocities.m", "FluidFlow1DElementVelocities";
        julia_fn = () -> d1_fluidflow_elementvelocity(Kxx, L, p),
        matlab_args_fn = () -> adapt_fluidflow_velocity_args(Kxx, L, p),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # ── Volumetric Flow Rate (scalar) ──
    push!(results, run_validation(
        "d1_fluidflow_elementvfr(Kxx, L, p, A)",
        "d1_fluidflow_elementvfr",
        "FluidFlow1DElementVFR.m", "FluidFlow1DElementVFR";
        julia_fn = () -> d1_fluidflow_elementvfr(Kxx, L, p, A),
        matlab_args_fn = () -> adapt_fluidflow_vfr_args(Kxx, L, p, A),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# CLI
# ═════════════════════════════════════════════════════════════════

function print_usage()
    println("Usage: julia --project=. scripts/validate-matlab.jl [element_type]")
    println()
    println("element_type: spring | truss | beam | grid | cst | lst | q4 | q8 | tet | brick | fluidflow | problems | all")
    println()
    println("Exit codes:")
    println("  0 — all tests within tolerance (rtol=$(RTOL))")
    println("  1 — any discrepancy > tolerance")
    println("  2 — Octave unavailable or version < 8")
end

function main()
    # ─── Parse args ─────────────────────────────────────────────
    valid_types = ["spring", "truss", "beam", "grid", "cst", "lst", "q4", "q8", "tet", "brick", "fluidflow", "problems", "all"]
    element_type = length(ARGS) >= 1 ? lowercase(strip(ARGS[1])) : "all"

    if element_type ∉ valid_types
        println(stderr, "$(RED)ERROR:$(RESET) Invalid element type '$(element_type)'.")
        println(stderr, "Valid options: $(join(valid_types, ", "))")
        println(stderr)
        print_usage()
        exit(1)
    end

    # ─── Welcome ────────────────────────────────────────────────
    println()
    print_centered(" $(BOLD)LibFEM.jl — Octave/MATLAB Validation$(RESET) ", 80)
    print_centered(" rtol=$(RTOL) | atol=$(ATOL) ", 80)
    print_separator("═", 80)
    println(" Element type: $(CYAN)$(element_type)$(RESET)")
    println()

    # ─── Check Octave ───────────────────────────────────────────
    octave_info = OctaveRunner.detect_octave()
    if octave_info.version == "not found"
        println(stderr, "$(RED)ERROR:$(RESET) Octave not found at $(octave_info.path)")
        println(stderr, "Install GNU Octave 8+ and ensure it is at $(OctaveRunner.OCTAVE_PATH)")
        exit(2)
    end
    if !octave_info.has_json
        println(stderr, "$(RED)ERROR:$(RESET) Octave $(octave_info.version) does not have jsonencode")
        println(stderr, "Octave 8.0 or later is required (detected: $(octave_info.version))")
        exit(2)
    end

    println(" Octave: $(CYAN)$(octave_info.version)$(RESET) at $(octave_info.path)")
    println()

    # ─── Run tests ──────────────────────────────────────────────
    all_results = ValidateResult[]

    if element_type ∈ ("spring", "all")
        print_separator("─", 80)
        r = test_spring()
        print_results(r, "Spring Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("truss", "all")
        print_separator("─", 80)
        r = test_truss()
        print_results(r, "Truss Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("beam", "all")
        print_separator("─", 80)
        r = test_beam()
        print_results(r, "Beam Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("grid", "all")
        print_separator("─", 80)
        r = test_grid()
        print_results(r, "Grid Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("cst", "all")
        print_separator("─", 80)
        r = test_cst()
        print_results(r, "CST / Linear Triangle Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("lst", "all")
        print_separator("─", 80)
        r = test_lst()
        print_results(r, "LST / Quadratic Triangle Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("q4", "all")
        print_separator("─", 80)
        r = test_q4()
        print_results(r, "Q4 / Bilinear Quadrilateral Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("q8", "all")
        print_separator("─", 80)
        r = test_q8()
        print_results(r, "Q8 / Quadratic Quadrilateral Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("tet", "all")
        print_separator("─", 80)
        r = test_tet()
        print_results(r, "Tet / Linear Tetrahedron Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("brick", "all")
        print_separator("─", 80)
        r = test_brick()
        print_results(r, "Brick / Linear Hexahedron Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("fluidflow", "all")
        print_separator("─", 80)
        r = test_fluidflow()
        print_results(r, "Fluid Flow 1D Elements")
        append!(all_results, r)
    end

    if element_type ∈ ("problems", "all")
        print_separator("─", 80)
        r = test_problems()
        print_results(r, "Kattan Solution Problems (via Octave)")
        append!(all_results, r)
    end

    # ─── Summary ────────────────────────────────────────────────
    all_pass = print_summary(all_results)

    println()

    if all_pass
        exit(0)
    else
        exit(1)
    end
end

# ─── Entry Point ────────────────────────────────────────────────
isinteractive() || main()
