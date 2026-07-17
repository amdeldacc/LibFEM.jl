"""
    ElementDimensionError <: Exception

Thrown when an element operation is called with an unsupported spatial dimension.

# Fields
- `dim::Int`: The requested dimension.
- `msg::String`: Error description.
"""
struct ElementDimensionError <: Exception
    dim::Int
    msg::String
end

function Base.showerror(io::IO, e::ElementDimensionError)
    print(io, "ElementDimensionError (dim=$(e.dim)): $(e.msg)")
end

"""
    ElementParameterError <: Exception

Thrown when an element parameter (e.g., length, area) has an invalid value.

# Fields
- `param::String`: The parameter name.
- `msg::String`: Error description.
"""
struct ElementParameterError <: Exception
    param::String
    msg::String
end

function Base.showerror(io::IO, e::ElementParameterError)
    print(io, "ElementParameterError ($(e.param)): $(e.msg)")
end

"""
    AssemblyError <: Exception

Thrown when an element assembly operation fails.

# Fields
- `msg::String`: Error description.
"""
struct AssemblyError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::AssemblyError)
    print(io, "AssemblyError: $(e.msg)")
end

"""
    DiagramError <: Exception

Thrown when a diagram plotting operation fails.

# Fields
- `msg::String`: Error description.
"""
struct DiagramError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::DiagramError)
    print(io, "DiagramError: $(e.msg)")
end
