#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# scripts/validate_matlab.jl — Octave/MATLAB vs Julia comparison
# ═══════════════════════════════════════════════════════════════
# Compares LibFEM.jl Julia functions against MATLAB .m file
# reference implementations via GNU Octave.
#
# Usage:
#   julia --project=. scripts/validate_matlab.jl [element_type]
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
using .OctaveRunner

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

    return all(r -> r.status == :pass, all_results)
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
    k1 = d1_truss_elementstiffness(E1, A1, L1)
    u1 = [1.0 / 70000.0, 0.0]  # from Problem 3.1, element 1

    # Stiffness
    push!(results, run_validation(
        "d1_truss_elementstiffness(E, A, L)",
        "d1_truss_elementstiffness",
        "LinearBarElementStiffness.m", "LinearBarElementStiffness";
        julia_fn = () -> d1_truss_elementstiffness(E1, A1, L1),
        matlab_args_fn = () -> adapt_truss_args(E1, A1, L1),
        result_adapter = adapt_truss_result, dof = 2,
    ))

    # Forces
    push!(results, run_validation(
        "d1_truss_elementforces(Ke, u)",
        "d1_truss_elementforces",
        "LinearBarElementForces.m", "LinearBarElementForces";
        julia_fn = () -> d1_truss_elementforces(k1, u1),
        matlab_args_fn = () -> adapt_truss_args(k1, u1),
        result_adapter = adapt_truss_result, dof = 2,
    ))

    # Stress
    push!(results, run_validation(
        "d1_truss_elementstress(Ke, u, A)",
        "d1_truss_elementstress",
        "LinearBarElementStresses.m", "LinearBarElementStresses";
        julia_fn = () -> d1_truss_elementstress(k1, u1, A1),
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
    θx, θy, θz = 0.0, 0.0, 0.0
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

    # ── 2D Beam / PlaneFrame ──
    E2, A2, I2, L2 = 210e6, 4e-2, 4e-6, 4.0
    θ2 = 0.0

    # Length
    push!(results, run_validation(
        "d2_beam_elementlength(x1, y1, x2, y2)",
        "d2_beam_elementlength",
        "PlaneFrameElementLength.m", "PlaneFrameElementLength";
        julia_fn = () -> d2_beam_elementlength(0.0, 0.0, 4.0, 0.0),
        matlab_args_fn = () -> adapt_beam_args(0.0, 0.0, 4.0, 0.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness
    push!(results, run_validation(
        "d2_beam_elementstiffness(E, A, I, L, θ)",
        "d2_beam_elementstiffness",
        "PlaneFrameElementStiffness.m", "PlaneFrameElementStiffness";
        julia_fn = () -> d2_beam_elementstiffness(E2, A2, I2, L2, θ2),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # Forces (using zero displacement)
    u2 = zeros(6)
    push!(results, run_validation(
        "d2_beam_elementforces(E, A, I, L, θ, u=0)",
        "d2_beam_elementforces",
        "PlaneFrameElementForces.m", "PlaneFrameElementForces";
        julia_fn = () -> d2_beam_elementforces(E2, A2, I2, L2, θ2, u2),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2, u2),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # Forces (with displacement from Problem 8.1, element 2)
    # Using computed & verified values from comparison.jl
    u2_loaded = [0.1865, 0.0, -0.0298, 0.1865, 0.0, 0.0149]
    push!(results, run_validation(
        "d2_beam_elementforces(E, A, I, L, θ, u)",
        "d2_beam_elementforces",
        "PlaneFrameElementForces.m", "PlaneFrameElementForces";
        julia_fn = () -> d2_beam_elementforces(E2, A2, I2, L2, θ2, u2_loaded),
        matlab_args_fn = () -> adapt_beam_args(E2, A2, I2, L2, θ2, u2_loaded),
        result_adapter = adapt_beam_result, dof = 6,
    ))

    # ── 3D Beam / SpaceFrame ──
    E3, G3, A3 = 210e6, 84e6, 2e-2
    Iy3, Iz3, J3 = 10e-5, 20e-5, 5e-5

    # Length
    push!(results, run_validation(
        "d3_beam_elementlength(x1, y1, z1, x2, y2, z2)",
        "d3_beam_elementlength",
        "SpaceFrameElementLength.m", "SpaceFrameElementLength";
        julia_fn = () -> d3_beam_elementlength(0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        matlab_args_fn = () -> adapt_space_frame_args(0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        result_adapter = (r, n) -> [r],
        dof = 1,
    ))

    # Stiffness (along x-axis: horizontal member from Problem 10.1)
    push!(results, run_validation(
        "d3_beam_elementstiffness(E, G, A, Iy, Iz, J, coords)",
        "d3_beam_elementstiffness",
        "SpaceFrameElementStiffness.m", "SpaceFrameElementStiffness";
        julia_fn = () -> d3_beam_elementstiffness(E3, G3, A3, Iy3, Iz3, J3,
                                                    0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        matlab_args_fn = () -> adapt_space_frame_args(E3, G3, A3, Iy3, Iz3, J3,
                                                       0.0, 0.0, 0.0, 4.0, 0.0, 0.0),
        result_adapter = adapt_space_frame_result, dof = 12,
    ))

    # Forces (with zero displacement)
    u3 = zeros(12)
    push!(results, run_validation(
        "d3_beam_elementforces(E, G, A, Iy, Iz, J, coords, u=0)",
        "d3_beam_elementforces",
        "SpaceFrameElementForces.m", "SpaceFrameElementForces";
        julia_fn = () -> d3_beam_elementforces(E3, G3, A3, Iy3, Iz3, J3,
                                               0.0, 0.0, 0.0, 4.0, 0.0, 0.0, u3),
        matlab_args_fn = () -> adapt_space_frame_args(E3, G3, A3, Iy3, Iz3, J3,
                                                       0.0, 0.0, 0.0, 4.0, 0.0, 0.0, u3),
        result_adapter = adapt_space_frame_result, dof = 12,
    ))

    return results
end

# ═════════════════════════════════════════════════════════════════
# CLI
# ═════════════════════════════════════════════════════════════════

function print_usage()
    println("Usage: julia --project=. scripts/validate_matlab.jl [element_type]")
    println()
    println("element_type: spring | truss | beam | all")
    println()
    println("Exit codes:")
    println("  0 — all tests within tolerance (rtol=$(RTOL))")
    println("  1 — any discrepancy > tolerance")
    println("  2 — Octave unavailable or version < 8")
end

function main()
    # ─── Parse args ─────────────────────────────────────────────
    valid_types = ["spring", "truss", "beam", "all"]
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
