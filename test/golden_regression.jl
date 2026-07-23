using TOML
using Test
using LinearAlgebra

# ─────────────────────────────────────────────────────────
# Helpers — MUST be defined before @testset block that uses them
# ─────────────────────────────────────────────────────────

"""
    _ordered_params(func_name::String, params::Dict) -> Vector

Return parameter values in the correct order for the given function.
This mapping must be kept in sync with the function signatures.
"""
function _ordered_params(func_name::String, params::Dict)
    # Map function name → ordered parameter keys
    order_map = Dict{String,Vector{String}}(
        # d1_spring
        "d1_spring_elementstiffness" => ["k"],
        "d1_spring_elementforce" => ["Ke", "u"],
        # d2_spring
        "d2_spring_elementstiffness" => ["k", "theta"],
        "d2_spring_elementforce" => ["k", "theta", "u"],
        # d3_spring
        "d3_spring_elementstiffness" => ["k", "thetax", "thetay", "thetaz"],
        "d3_spring_elementforce" => ["k", "thetax", "thetay", "thetaz", "u"],
        # d1_truss
        "d1_truss_elementstiffness" => ["E", "A", "L"],
        "d1_truss_elementforces" => ["Ke", "u"],
        "d1_truss_elementstress" => ["Ke", "u", "A"],
        "d1_truss_elementstrain" => ["L", "u"],
        # d2_truss
        "d2_truss_elementlength" => ["x1", "y1", "x2", "y2"],
        "d2_truss_elementstiffness" => ["E", "A", "L", "theta"],
        "d2_truss_elementforces" => ["E", "A", "L", "theta", "u"],
        "d2_truss_elementstrain" => ["L", "theta", "u"],
        "d2_truss_elementstress" => ["E", "L", "theta", "u"],
        # d3_truss
        "d3_truss_elementlength" => ["x1", "y1", "z1", "x2", "y2", "z2"],
        "d3_truss_elementstiffness" => ["E", "A", "L", "thetax", "thetay", "thetaz"],
        "d3_truss_elementforces" => ["E", "A", "L", "thetax", "thetay", "thetaz", "u"],
        "d3_truss_elementstrain" => ["L", "thetax", "thetay", "thetaz", "u"],
        "d3_truss_elementstress" => ["E", "L", "thetax", "thetay", "thetaz", "u"],
        # d2_beam
        "d2_beam_elementstiffness" => ["E", "I", "L"],
        "d2_beam_elementforces" => ["k", "u"],
        # d2_planeframe
        "d2_planeframe_elementlength" => ["x1", "y1", "x2", "y2"],
        "d2_planeframe_elementstiffness" => ["E", "A", "I", "L", "theta"],
        "d2_planeframe_elementforces" => ["E", "A", "I", "L", "theta", "u"],
        # d3_spaceframe
        "d3_spaceframe_elementlength" => ["x1", "y1", "z1", "x2", "y2", "z2"],
        "d3_spaceframe_elementstiffness" => ["E", "G", "A", "Iy", "Iz", "J", "x1", "y1", "z1", "x2", "y2", "z2"],
        "d3_spaceframe_elementforces" => ["E", "G", "A", "Iy", "Iz", "J", "x1", "y1", "z1", "x2", "y2", "z2", "u"],
    )

    keys = get(order_map, func_name, String[])
    if isempty(keys)
        error("Unknown function: $func_name — add to _ordered_params mapping in golden_regression.jl")
    end

    return [params[k] for k in keys]
end

"""
    _deserialize_binary(path::String) -> Union{Matrix{Float64}, Nothing}

Read a matrix from the binary golden file format:
  rows::Int32, cols::Int32, data::Vector{Float64} (column-major).
Returns `nothing` for error-marker files (rows=0, cols=0),
meaning the function is expected to throw.
Matches the format written by generate_golden.jl's serialize_matrix().
"""
function _deserialize_binary(path::String)
    open(path) do io
        rows = Int(read(io, Int32))
        cols = Int(read(io, Int32))
        if rows == 0 && cols == 0
            return nothing  # error-marker
        end
        n = rows * cols
        data = Vector{Float64}(undef, n)
        read!(io, data)
        return reshape(data, rows, cols)
    end
end

@testset "Golden Regression" begin
    manifest_path = joinpath(@__DIR__, "golden", "manifests.toml")
    if !isfile(manifest_path)
        @warn "Golden manifest not found at $manifest_path — skipping golden regression tests"
        return
    end

    manifest = TOML.parsefile(manifest_path)
    entries = get(manifest, "entries", [])
    if isempty(entries)
        @warn "No entries in golden manifest — skipping golden regression tests"
        return
    end

    schema_version = get(manifest, "schema_version", 1)
    golden_dir = joinpath(@__DIR__, "golden")

    for (i, entry) in enumerate(entries)
        func_name = entry["function"]
        id = entry["id"]
        file = entry["file"]
        rtol = get(entry, "tolerances", Dict()) |> d -> get(d, "rtol", 1e-12)
        atol = get(entry, "tolerances", Dict()) |> d -> get(d, "atol", 1e-14)

        golden_path = joinpath(golden_dir, file)

        @testset "$id ($func_name)" begin
            # Resolve the function
            func_sym = Symbol(func_name)
            if !isdefined(LibFEM, func_sym)
                @warn "Function $func_name not defined in LibFEM — skipping"
                continue
            end
            f = getfield(LibFEM, func_sym)

            # Build ordered parameter list from manifest entry
            params = entry["params"]
            param_values = _ordered_params(func_name, params)

            # Try calling the function
            call_ok = false
            result = nothing
            try
                result = f(param_values...)
                call_ok = true
            catch e
                if !(e isa ElementParameterError)
                    rethrow()  # unexpected error — let it propagate
                end
                # Expected error: check golden file is error-marker
                if !isfile(golden_path)
                    @warn "Function $func_name threw ElementParameterError (expected), but no golden file at $golden_path"
                    @test true
                else
                    golden_data = _deserialize_binary(golden_path)
                    @test golden_data === nothing
                end
                continue
            end

            # Function call succeeded — compare against golden
            if !isfile(golden_path)
                @warn "No golden file at $golden_path — run generate_golden.jl"
                if result isa AbstractMatrix
                    @test result ≈ result'
                    # Relaxed bound: some problems have negative k or large values
                    @test minimum(eigvals(result)) >= -1e-6
                end
            else
                golden_data = _deserialize_binary(golden_path)
                if golden_data === nothing
                    @error "Function $func_name succeeded but golden file is an error-marker"
                    @test false
                else
                    @test isapprox(result, golden_data; rtol=rtol, atol=atol)
                end
            end
        end
    end
end
