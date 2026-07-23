# ═══════════════════════════════════════════════════════════
# Shared parameter ordering for the golden test framework
# ═══════════════════════════════════════════════════════════
#
# Single source of truth used by:
#   - golden_regression.jl (test runner)
#   - generate_golden.jl    (golden file generator)
#
# Must be kept in sync with the actual function signatures in src/.

"""
    PARAM_ORDER::Dict{String,Vector{Symbol}}

Maps each function name to its parameter keys in positional order.
The order matches the function signature in the corresponding source file.
"""
const PARAM_ORDER = Dict{String,Vector{Symbol}}(
    # ── d1_spring ──
    "d1_spring_elementstiffness" => [:k],
    "d1_spring_elementforce"     => [:Ke, :u],
    # ── d2_spring ──
    "d2_spring_elementstiffness" => [:k, :theta],
    "d2_spring_elementforce"     => [:k, :theta, :u],
    # ── d3_spring ──
    "d3_spring_elementstiffness" => [:k, :thetax, :thetay, :thetaz],
    "d3_spring_elementforce"     => [:k, :thetax, :thetay, :thetaz, :u],
    # ── d1_truss ──
    "d1_truss_elementstiffness"  => [:E, :A, :L],
    "d1_truss_elementforces"     => [:Ke, :u],
    "d1_truss_elementstress"     => [:Ke, :u, :A],
    "d1_truss_elementstrain"     => [:L, :u],
    # ── d2_truss ──
    "d2_truss_elementlength"     => [:x1, :y1, :x2, :y2],
    "d2_truss_elementstiffness"  => [:E, :A, :L, :theta],
    "d2_truss_elementforces"     => [:E, :A, :L, :theta, :u],
    "d2_truss_elementstrain"     => [:L, :theta, :u],
    "d2_truss_elementstress"     => [:E, :L, :theta, :u],
    # ── d3_truss ──
    "d3_truss_elementlength"     => [:x1, :y1, :z1, :x2, :y2, :z2],
    "d3_truss_elementstiffness"  => [:E, :A, :L, :thetax, :thetay, :thetaz],
    "d3_truss_elementforces"     => [:E, :A, :L, :thetax, :thetay, :thetaz, :u],
    "d3_truss_elementstrain"     => [:L, :thetax, :thetay, :thetaz, :u],
    "d3_truss_elementstress"     => [:E, :L, :thetax, :thetay, :thetaz, :u],
    # ── d2_beam ──
    "d2_beam_elementstiffness"   => [:E, :I, :L],
    "d2_beam_elementforces"      => [:k, :u],
    # ── d2_planeframe ──
    "d2_planeframe_elementlength"     => [:x1, :y1, :x2, :y2],
    "d2_planeframe_elementstiffness"  => [:E, :A, :I, :L, :theta],
    "d2_planeframe_elementforces"     => [:E, :A, :I, :L, :theta, :u],
    # ── d3_spaceframe ──
    "d3_spaceframe_elementlength"     => [:x1, :y1, :z1, :x2, :y2, :z2],
    "d3_spaceframe_elementstiffness"  => [:E, :G, :A, :Iy, :Iz, :J, :x1, :y1, :z1, :x2, :y2, :z2],
    "d3_spaceframe_elementforces"     => [:E, :G, :A, :Iy, :Iz, :J, :x1, :y1, :z1, :x2, :y2, :z2, :u],
)

"""
    ordered_params(func_name, params) -> Vector

Return parameter values from `params` (a Dict{String,Any} as parsed from TOML)
in the correct positional order for the function `func_name`.
The result can be splatted into the function call.
"""
function ordered_params(func_name::AbstractString, params::Dict)
    order = get(PARAM_ORDER, func_name) do
        error("Unknown function: $func_name — add to PARAM_ORDER in params_common.jl")
    end
    return [params[string(k)] for k in order]
end

"""
    ordered_params(func_name, params) -> Tuple

Return parameter values as a Tuple (for splatting into function calls).
Convenience wrapper for callers that prefer a Tuple.
"""
function ordered_params_tuple(func_name::AbstractString, params::Dict)
    return Tuple(ordered_params(func_name, params))
end
