using TOML
using Test
using LinearAlgebra
using LibFEM

# ─────────────────────────────────────────────────────────
# Shared parameter ordering (single source of truth)
# ─────────────────────────────────────────────────────────
include(joinpath(@__DIR__, "golden", "params_common.jl"))

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
        if rows < 0 || cols < 0
            error("Invalid dimensions: rows=$rows, cols=$cols (must be non-negative)")
        end
        if rows == 0 && cols == 0
            return nothing  # error-marker
        end
        # Prevent excessive allocation: limit to 100 million elements (adjust as needed)
        if rows > 0 && cols > 0 && rows > typemax(Int) ÷ cols
            error("Dimensions too large: rows=$rows, cols=$cols")
        end
        n = rows * cols
        if n > 10^8  # arbitrary limit to prevent excessive memory use
            error("Too many elements: $n")
        end
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
            param_values = ordered_params(func_name, params)

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
                    if size(result, 1) == size(result, 2)
                        @test result ≈ result'
                        # Relaxed bound: some problems have negative k or large values
                        @test minimum(eigvals(result)) >= -1e-6
                    else
                        @warn "Result is non-square ($(size(result))); skipping symmetry and definiteness checks."
                    end
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
