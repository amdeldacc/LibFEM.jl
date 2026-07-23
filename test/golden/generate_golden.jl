#!/usr/bin/env julia
"""
    generate_golden.jl

Golden file generator for LibFEM.jl element stiffness matrices.

Reads `manifests.toml`, evaluates each entry's stiffness function,
and writes binary golden files to `v1/<id>.bin`.

Binary format (per entry):
  rows::Int32  — number of rows in the matrix
  cols::Int32  — number of columns in the matrix
  data::Vector{Float64} — matrix elements in column-major order

Error-path entries (e.g. L=0) are caught gracefully; a zero-size marker
file is written with rows=0, cols=0 so the test harness can detect them.

Usage:
  julia --project=. test/golden/generate_golden.jl
"""

using LibFEM
using LinearAlgebra
using TOML

const MANIFEST_PATH = joinpath(@__DIR__, "manifests.toml")
const OUTPUT_DIR    = joinpath(@__DIR__, "v1")

# ---------------------------------------------------------------------------
# Parameter ordering — TOML Dict iteration order is NOT guaranteed, so we
# define the correct positional order explicitly per function.
# ---------------------------------------------------------------------------

const PARAM_ORDER = Dict(
    "d1_spring_elementstiffness"       => [:k],
    "d2_spring_elementstiffness"       => [:k, :theta],
    "d3_spring_elementstiffness"       => [:k, :thetax, :thetay, :thetaz],
    "d1_truss_elementstiffness"        => [:E, :A, :L],
    "d2_truss_elementstiffness"        => [:E, :A, :L, :theta],
    "d3_truss_elementstiffness"        => [:E, :A, :L, :thetax, :thetay, :thetaz],
    "d2_beam_elementstiffness"         => [:E, :I, :L],
    "d2_planeframe_elementstiffness"   => [:E, :A, :I, :L, :theta],
    "d3_spaceframe_elementstiffness"   => [:E, :G, :A, :Iy, :Iz, :J, :x1, :y1, :z1, :x2, :y2, :z2],
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""
    serialize_matrix(path, K)

Write matrix `K` to `path` as:
  rows::Int32, cols::Int32, data::Vector{Float64} (column-major).
"""
function serialize_matrix(path::String, K::AbstractMatrix)
    rows, cols = size(K)
    open(path, "w") do io
        write(io, Int32(rows))
        write(io, Int32(cols))
        # Column-major: Julia's default memory layout (vec on a Matrix)
        write(io, vec(K))
    end
end

"""
    write_error_marker(path)

Write a zero-size marker for error-path entries (e.g. L=0).
The test harness can detect these by checking rows=0, cols=0.
"""
function write_error_marker(path::String)
    open(path, "w") do io
        write(io, Int32(0))
        write(io, Int32(0))
    end
end

# ---------------------------------------------------------------------------
# Function resolution
# ---------------------------------------------------------------------------

"""
    resolve_func(func_name::String) -> Function

Look up `func_name` (e.g. "d1_spring_elementstiffness") as an exported
symbol from `LibFEM`.
"""
function resolve_func(func_name::String)
    return getfield(LibFEM, Symbol(func_name))
end

"""
    build_args(func_name::String, params::Dict) -> Tuple

Build a positional argument tuple from `params` using the explicit
order defined in `PARAM_ORDER`.
"""
function build_args(func_name::String, params::Dict)
    order = get(PARAM_ORDER, func_name) do
        error("Unknown function: $func_name (not in PARAM_ORDER)")
    end
    return Tuple(params[string(k)] for k in order)
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

function main()
    # Ensure output directory exists
    mkpath(OUTPUT_DIR)

    # Parse manifest
    manifest = TOML.parsefile(MANIFEST_PATH)
    entries  = manifest["entries"]

    total       = length(entries)
    ok_count    = 0
    error_count = 0

    println("LibFEM Golden File Generator")
    println("=" ^ 60)
    println("Manifest: $MANIFEST_PATH")
    println("Output:   $OUTPUT_DIR")
    println("Entries:  $total")
    println()

    for (idx, entry) in enumerate(entries)
        id        = entry["id"]
        func_name = entry["function"]
        params    = entry["params"]
        out_path  = joinpath(OUTPUT_DIR, "$id.bin")

        display_name = "v1/$id.bin"
        print(rpad("[$idx/$total] $display_name", 54))

        try
            func = resolve_func(func_name)
            args = build_args(func_name, params)
            K    = func(args...)
            serialize_matrix(out_path, K)
            println("  ✓  $(size(K,1))×$(size(K,2))")
            ok_count += 1
        catch exc
            # Expected for error-path entries (zeroL, etc.)
            write_error_marker(out_path)
            println("  ✗  $(typeof(exc)): $(exc)")
            error_count += 1
        end
    end

    println()
    println("=" ^ 60)
    println("Done.  $ok_count succeeded, $error_count error-path markers written.")
    return ok_count, error_count
end

# Run
main()
