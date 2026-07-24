# ─────────────────────────────────────────────────
# OctaveRunner — Octave subprocess bridge for LibFEM.jl
# ─────────────────────────────────────────────────
# Wraps GNU Octave as a child process, sends MATLAB .m file
# function calls via JSON serialization, and returns parsed results.
#
# Octave 8+ has built-in `jsonencode`/`jsondecode`.
# This module uses a minimal JSON serializer/parser (no external deps)
# to communicate with the Octave subprocess.

module OctaveRunner

export OctaveInfo, OctaveResult, OctaveError,
       detect_octave, call_function, load_and_call,
       run_script, parse_octave_object

import Base: showerror

# ─── Constants ────────────────────────────────────────

"""Path to the GNU Octave binary."""
const OCTAVE_PATH = "/usr/bin/octave"

"""Default timeout (seconds) for each Octave function call."""
const CALL_TIMEOUT = 30.0

# ─── Types ────────────────────────────────────────────

"""
    OctaveInfo(version, path, has_json)

Information about the detected Octave installation.

# Fields
- `version::String`: Version string (e.g. "8.4.0") or "unknown"
- `path::String`: Absolute path to the Octave binary
- `has_json::Bool`: Whether Octave has built-in jsonencode (≥8.0)
"""
struct OctaveInfo
    version::String
    path::String
    has_json::Bool
end

"""
    OctaveResult(success, output_json, stderr, duration_ms)

Result of a single Octave subprocess call.

# Fields
- `success::Bool`: Whether the call completed without error/timeout
- `output_json::String`: Raw JSON output from Octave's `jsonencode`
- `stderr::String`: Captured stderr (warnings, errors)
- `duration_ms::Float64`: Wall-clock duration of the call
"""
struct OctaveResult
    success::Bool
    output_json::String
    stderr::String
    duration_ms::Float64
end

"""
    OctaveError(msg, result)

Exception thrown when an Octave call fails.

# Fields
- `message::String`: Human-readable error description
- `result::Union{OctaveResult, Nothing}`: The failed result struct
"""
struct OctaveError <: Exception
    message::String
    result::Union{OctaveResult, Nothing}
end

function showerror(io::IO, e::OctaveError)
    print(io, "OctaveError: ", e.message)
    if e.result !== nothing
        if !isempty(e.result.stderr)
            print(io, "\n  stderr: ", e.result.stderr)
        end
        if !isempty(e.result.output_json)
            print(io, "\n  output: ", e.result.output_json)
        end
    end
end

# ─── Detection ────────────────────────────────────────

"""
    detect_octave() -> OctaveInfo

Probe the system for GNU Octave at `OCTAVE_PATH`.
Runs `octave --version` to extract the version string and
determine whether `jsonencode` / `jsondecode` are available
(they were added in Octave 8).
"""
function detect_octave()
    path = OCTAVE_PATH
    if !isfile(path)
        return OctaveInfo("not found", path, false)
    end

    has_json = false
    version = "unknown"

    try
        out = read(`$(path) --version`, String)
        for line in split(out, '\n')
            m = match(r"version\s+(\d+)\.(\d+)\.(\d+)", line)
            if m !== nothing
                version = m[1] * "." * m[2] * "." * m[3]
                major = parse(Int, m[1])
                has_json = major >= 8
                break
            end
        end
    catch e
        return OctaveInfo("error: $(sprint(showerror, e))", path, false)
    end

    return OctaveInfo(version, path, has_json)
end

# ═══════════════════════════════════════════════════════
# Minimal JSON serializer (Julia → JSON)
# ═══════════════════════════════════════════════════════
# Handles: Real numbers, Vectors, Matrices.
# NaN/Inf → "null" (matching Octave's jsonencode convention).
# ═══════════════════════════════════════════════════════

_julia_to_json(x::Real) = (isnan(x) || isinf(x)) ? "null" : repr(x)
_julia_to_json(x::AbstractVector) = "[" * join(_julia_to_json.(x), ",") * "]"

function _julia_to_json(x::AbstractMatrix)
    rows = String[]
    for i in 1:size(x, 1)
        push!(rows, _julia_to_json(vec(x[i, :])))
    end
    return "[" * join(rows, ",") * "]"
end

# ═══════════════════════════════════════════════════════
# Minimal JSON parser (Octave JSON → Julia)
# ═══════════════════════════════════════════════════════
# Parses the subset of JSON that Octave's jsonencode emits:
#   Number:      42  |  3.14  |  6.283e-05  |  -1e99
#   Null:        null  →  NaN
#   Flat array:  [1,2,3]  →  Vector{Float64}
#   Nested arr:  [[1,2],[3,4]]  →  Matrix{Float64}
#   Heterog arr: [[1,2,3],[4,5]]  →  Vector{Any}  (mixed types/sizes)
# ═══════════════════════════════════════════════════════

"""
    _parse_json(s) -> Vector

Parse a JSON *argument* string — always returns a Vector of values.
Used only for decoding `args_json` in `call_function`.
"""
function _parse_json(s::AbstractString)
    s = strip(s)
    if isempty(s)
        return Any[]
    end
    val = _parse_value(s)
    if val isa AbstractVector
        return collect(val)
    else
        return [val]
    end
end

"""
    _parse_octave_result(s) -> Any

Parse a single JSON value returned by Octave.
Returns a scalar (Float64), vector (Vector{Float64}), or matrix (Matrix{Float64}).
"""
function _parse_octave_result(s::AbstractString)
    s = strip(s)
    isempty(s) && return nothing
    return _parse_value(s)
end

"""Parse a single JSON value (number or array)."""
function _parse_value(s::AbstractString)
    s = strip(s)
    if isempty(s)
        return nothing
    elseif s[1] == '['
        return _parse_array(s)
    else
        return _parse_number(s)
    end
end

"""Parse a JSON array body (everything between outer `[...]`)."""
function _parse_array(s::AbstractString)
    s = strip(s)
    @assert s[1] == '[' && s[end] == ']'
    inner = strip(s[2:end-1])
    isempty(inner) && return Float64[]

    elements = _split_top_level(inner)

    # Classify each top-level element as array or flat
    n = length(elements)
    is_arr = Bool[!isempty(strip(e)) && strip(e)[1] == '[' for e in elements]

    if all(is_arr)
        # All sub-elements are arrays → could be a matrix
        sub_vals = [_parse_value(strip(e)) for e in elements]

        # If all sub-values are 1D vectors of equal length → matrix
        if all(v -> v isa AbstractVector, sub_vals)
            nrows = length(sub_vals)
            ncols = length(sub_vals[1])
            if all(v -> length(v) == ncols, sub_vals)
                M = zeros(Float64, nrows, ncols)
                for i in 1:nrows, j in 1:ncols
                    M[i, j] = Float64(sub_vals[i][j])
                end
                return M
            end
        end
        # Heterogeneous nested arrays → return as vector
        return collect(sub_vals)
    elseif any(is_arr)
        # Mixed: some numbers, some arrays → parse each individually
        return [_parse_value(strip(e)) for e in elements]
    else
        # All flat numbers → vector of Float64
        return Float64[_parse_number(strip(e)) for e in elements]
    end
end

"""
    _split_top_level(s) -> Vector{String}

Split a JSON array body string on commas at depth 0 only.
Example: `"[1,2],[3,4]"` → `["[1,2]", "[3,4]"]`
"""
function _split_top_level(s::AbstractString)
    result = String[]
    depth = 0
    start_idx = 1
    for i in eachindex(s)
        c = s[i]
        if c == '['
            depth += 1
        elseif c == ']'
            depth -= 1
        elseif c == ',' && depth == 0
            push!(result, strip(s[start_idx:i-1]))
            start_idx = i + 1
        end
    end
    last = strip(s[start_idx:end])
    if !isempty(last)
        push!(result, last)
    end
    return result
end

"""
    _split_top_level_object(s) -> Vector{String}

Split a JSON object body string on commas at depth 0 only,
tracking both `[]` and `{}` bracket depth.
Example: `"\"K\":[[1,2],[3,4]],\"U\":[0,1]"` → `["\"K\":[[1,2],[3,4]]", "\"U\":[0,1]"]`
"""
function _split_top_level_object(s::AbstractString)
    result = String[]
    depth = 0
    start_idx = 1
    for i in eachindex(s)
        c = s[i]
        if c == '[' || c == '{'
            depth += 1
        elseif c == ']' || c == '}'
            depth -= 1
        elseif c == ',' && depth == 0
            push!(result, strip(s[start_idx:i-1]))
            start_idx = i + 1
        end
    end
    last = strip(s[start_idx:end])
    if !isempty(last)
        push!(result, last)
    end
    return result
end

"""
    _split_key_value(s) -> (String, String)

Split a JSON key:value pair at the first top-level `:` (depth 0).
Strips quotes from the key. Returns (key, value_string).

Example: `"\"K\":[[1,2],[3,4]]"` → `("K", "[[1,2],[3,4]]")`
"""
function _split_key_value(s::AbstractString)
    s = strip(s)
    depth = 0
    for i in eachindex(s)
        c = s[i]
        if c == '[' || c == '{'
            depth += 1
        elseif c == ']' || c == '}'
            depth -= 1
        elseif c == ':' && depth == 0
            key = strip(s[1:i-1])
            val = strip(s[i+1:end])
            # Strip surrounding double quotes from key
            if length(key) >= 2 && key[1] == '"' && key[end] == '"'
                key = key[2:end-1]
            end
            return key, val
        end
    end
    error("Invalid JSON object entry (no key:value separator at depth 0): '$(s)'")
end

"""
    _parse_octave_object(s) -> Dict{String, Any}

Parse a JSON object string produced by Octave's `jsonencode(struct(...))`.
The expected format is:
    `{"K":[[1,2],[3,4]],"U":[0,1,2],"F":[1.0,2.0,3.0]}`

Returns a dictionary mapping string keys to parsed Julia values
(scalars, vectors, or matrices via `_parse_value`).
"""
function _parse_octave_object(s::AbstractString)
    s = strip(s)
    if isempty(s)
        return Dict{String,Any}()
    end
    if s[1] != '{' || s[end] != '}'
        error("Expected JSON object wrapped in {...}, got: '$(s[1:min(end,80)])...'")
    end
    inner = strip(s[2:end-1])
    isempty(inner) && return Dict{String,Any}()

    pairs = _split_top_level_object(inner)
    result = Dict{String,Any}()
    for pair in pairs
        key, val_str = _split_key_value(pair)
        result[key] = _parse_value(val_str)
    end
    return result
end

"""Public wrapper for `_parse_octave_object`."""
parse_octave_object(s::AbstractString) = _parse_octave_object(s)

"""Parse a single JSON number (or `null` → `NaN`)."""
function _parse_number(s::AbstractString)
    s = strip(s)
    if s == "null"
        return NaN
    end
    f = tryparse(Float64, s)
    if f !== nothing
        return f
    end
    error("Cannot parse JSON number: '$(s)'")
end

# ═══════════════════════════════════════════════════════
# Julia value → Octave syntax
# ═══════════════════════════════════════════════════════
# Renders Julia values as Octave-compatible literal expressions.
# ═══════════════════════════════════════════════════════

_julia_to_octave_value(x::Real) = repr(x)

function _julia_to_octave_value(x::AbstractVector)
    return "[" * join(_julia_to_octave_value.(x), "; ") * "]"
end

function _julia_to_octave_value(x::AbstractMatrix)
    rows = String[]
    for i in 1:size(x, 1)
        push!(rows, join(_julia_to_octave_value.(vec(x[i, :])), " "))
    end
    return "[" * join(rows, "; ") * "]"
end

# ═══════════════════════════════════════════════════════
# Octave wrapper script generation
# ═══════════════════════════════════════════════════════
# Generates a temporary .m file that:
#   1. Suppresses graphics (headless CI protection)
#   2. Adds the target directory to the path
#   3. Replaces NaN/Inf with sentinel 1e99
#   4. Calls the requested function
#   5. Serializes the result via jsonencode
# ═══════════════════════════════════════════════════════

"""
    _build_script(dir, octave_call) -> String

Generate a temporary Octave wrapper script.

# Arguments
- `dir::String`: Directory to add to Octave's path (dirname of .m file)
- `octave_call::String`: Octave function call expression, e.g. `"SpringElementStiffness(200.0)"`
"""
function _build_script(dir::String, octave_call::String)
    return """
set(0, "DefaultFigureVisible", "off");
addpath("$(dir)");

function result = __sanitize__(x)
    if isfloat(x)
        x(isnan(x)) = 1e99;
        x(isinf(x)) = 1e99;
    end
    result = x;
end

result = __sanitize__($(octave_call));
disp(jsonencode(result));
"""
end

# ═══════════════════════════════════════════════════════
# Subprocess execution with timeout
# ═══════════════════════════════════════════════════════

"""
    _run_with_timeout(cmd, timeout_sec) -> (stdout, stderr, success)

Run a command with a wall-clock timeout.
Returns captured stdout, stderr, and a boolean indicating
whether the command completed before the timeout.
"""
function _run_with_timeout(cmd::Cmd, timeout_sec::Float64)
    out_path = tempname()
    err_path = tempname()
    try
        proc = run(pipeline(cmd, stdout=out_path, stderr=err_path); wait=false)

        t_start = time()
        while process_running(proc)
            if time() - t_start > timeout_sec
                kill(proc)
                return "", "TIMEOUT: exceeded $(timeout_sec)s", false
            end
            sleep(0.01)
        end

        out_str = isfile(out_path) ? read(out_path, String) : ""
        err_str = isfile(err_path) ? read(err_path, String) : ""
        return out_str, err_str, true
    finally
        isfile(out_path) && rm(out_path; force=true)
        isfile(err_path) && rm(err_path; force=true)
    end
end

# ═══════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════

"""
    call_function(m_file_path, func_name, args_json) -> OctaveResult

Call a MATLAB function via Octave.

# Arguments
- `m_file_path::String`: Full path to the .m file containing the function
- `func_name::String`: Name of the function to call (must match the .m filename)
- `args_json::String`: JSON array string of the function arguments, e.g. `"[200]"` or `"[70e6, 0.005, 1.0, 30.0]"`

# Returns
An `OctaveResult` struct with the JSON-encoded output and metadata.
"""
function call_function(m_file_path::String, func_name::String, args_json::String)
    # Parse args from JSON into Julia values
    args_parsed = _parse_json(args_json)

    # Convert each argument to Octave-compatible syntax
    args_strs = _julia_to_octave_value.(args_parsed)
    args_comma = join(args_strs, ", ")

    # Build the Octave function call expression
    octave_call = "$(func_name)($(args_comma))"

    # Build and run the wrapper script
    dir = dirname(m_file_path)
    script = _build_script(dir, octave_call)

    octave_bin = OCTAVE_PATH
    if !isfile(octave_bin)
        return OctaveResult(false, "", "Octave not found at $(octave_bin)", 0.0)
    end

    # Check JSON support
    info = detect_octave()
    if !info.has_json
        return OctaveResult(false, "", "Octave $(info.version) does not have jsonencode (need ≥8.0)", 0.0)
    end

    return mktemp() do path, io
        write(io, script)
        close(io)

        cmd = `$(octave_bin) --no-gui --no-window-system --quiet --no-history --no-init-file --no-site-file $(path)`
        t_start = time()
        out_str, err_str, completed = _run_with_timeout(cmd, CALL_TIMEOUT)
        duration_ms = (time() - t_start) * 1000.0

        if !completed
            return OctaveResult(false, "", "Timeout after $(CALL_TIMEOUT)s", duration_ms)
        end

        # Determine success: treat as success if we got non-empty JSON output.
        # Warnings (gnuplot deprecation, etc.) go to stderr but are non-fatal.
        # Only flag failure if stderr contains actual "error:" lines.
        err_trimmed = strip(err_str)
        has_fatal_error = false
        for line in split(err_trimmed, '\n')
            trimmed = strip(line)
            if !isempty(trimmed) && startswith(lowercase(trimmed), "error:")
                has_fatal_error = true
                break
            end
        end

        out_trimmed = strip(out_str)
        if has_fatal_error || isempty(out_trimmed)
            return OctaveResult(false, out_trimmed, err_trimmed, duration_ms)
        end

        return OctaveResult(true, out_trimmed, err_trimmed, duration_ms)
    end
end

"""
    run_script(script_body; dirs, sanitize, timeout) -> OctaveResult

Run an arbitrary Octave script (not just a single function call).
Wraps the script in the same headless/timeout infrastructure as
`call_function`, but does NOT inject sanitize code by default.

# Arguments
- `script_body::String`: Raw Octave code to execute.

# Keyword Arguments
- `dirs::Vector{String}`: Directories to add to Octave's path via `addpath`.
- `sanitize::Bool`: Whether to replace NaN/Inf with 1e99 (default: `false`).
- `timeout::Float64`: Maximum execution time in seconds (default: `CALL_TIMEOUT`).

# Returns
An `OctaveResult` struct. On success, `.output_json` contains the raw stdout.
"""
function run_script(
    script_body::String;
    dirs::Vector{String}=String[],
    sanitize::Bool=false,
    timeout::Float64=CALL_TIMEOUT,
)
    # Build addpath lines
    addpath_lines = join(["addpath(\"$d\");" for d in dirs], "\n")

    # Build sanitization block (off by default for problem scripts)
    sanitize_block = if sanitize
        """
        function result = __sanitize__(x)
            if isfloat(x)
                x(isnan(x)) = 1e99;
                x(isinf(x)) = 1e99;
            end
            result = x;
        end
        """
    else
        ""
    end

    # Suppress graphics — problem scripts may call diagram functions
    wrapper_script = """
set(0, "DefaultFigureVisible", "off");
$(addpath_lines)
$(sanitize_block)

$(script_body)
"""

    octave_bin = OCTAVE_PATH
    if !isfile(octave_bin)
        return OctaveResult(false, "", "Octave not found at $(octave_bin)", 0.0)
    end

    info = detect_octave()
    if !info.has_json
        return OctaveResult(false, "", "Octave $(info.version) does not have jsonencode (need ≥8.0)", 0.0)
    end

    return mktemp() do path, io
        write(io, wrapper_script)
        close(io)

        cmd = `$(octave_bin) --no-gui --no-window-system --quiet --no-history --no-init-file --no-site-file $(path)`
        t_start = time()
        out_str, err_str, completed = _run_with_timeout(cmd, timeout)
        duration_ms = (time() - t_start) * 1000.0

        if !completed
            return OctaveResult(false, "", "Timeout after $(timeout)s", duration_ms)
        end

        # Determine success
        err_trimmed = strip(err_str)
        has_fatal_error = false
        for line in split(err_trimmed, '\n')
            trimmed = strip(line)
            if !isempty(trimmed) && startswith(lowercase(trimmed), "error:")
                has_fatal_error = true
                break
            end
        end

        out_trimmed = strip(out_str)
        if has_fatal_error || isempty(out_trimmed)
            return OctaveResult(false, out_trimmed, err_trimmed, duration_ms)
        end

        return OctaveResult(true, out_trimmed, err_trimmed, duration_ms)
    end
end

"""
    load_and_call(m_file_path, func_name, julia_args...) -> Any

Full pipeline: serialize Julia args to JSON → call Octave →
parse the JSON result → return a Julia value.

# Arguments
- `m_file_path::String`: Full path to the .m file
- `func_name::String`: Function name (matches .m filename)
- `julia_args...`: One or more Julia values (scalars, vectors, or matrices)

# Returns
- `Float64` for scalar results
- `Vector{Float64}` for vector results
- `Matrix{Float64}` for matrix results

# Throws
- `OctaveError` if the Octave call or JSON parsing fails
"""
function load_and_call(m_file_path::String, func_name::String, julia_args...)
    # Serialize Julia args to JSON array
    args_json = "[" * join(_julia_to_json.(julia_args), ",") * "]"

    # Call Octave
    result = call_function(m_file_path, func_name, args_json)

    if !result.success
        throw(OctaveError("Octave call to $(func_name) failed", result))
    end

    if isempty(strip(result.output_json))
        throw(OctaveError("Empty output from Octave for $(func_name)", result))
    end

    # Parse the JSON result
    parsed = _parse_octave_result(result.output_json)
    if parsed === nothing
        throw(OctaveError("Failed to parse Octave output for $(func_name)", result))
    end

    return parsed
end

end  # module OctaveRunner
