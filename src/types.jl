"""
    AbstractElement{NDIM}

Abstract base type for all finite elements in LibFEM.
Parameterized by spatial dimension `NDIM`.
"""
abstract type AbstractElement{NDIM} end

"""
    AbstractSpring{NDIM} <: AbstractElement{NDIM}

Abstract type for spring elements in `NDIM` dimensions.
"""
abstract type AbstractSpring{NDIM} <: AbstractElement{NDIM} end

"""
    AbstractTruss{NDIM} <: AbstractElement{NDIM}

Abstract type for truss (bar) elements in `NDIM` dimensions.
"""
abstract type AbstractTruss{NDIM} <: AbstractElement{NDIM} end

"""
    AbstractBeam{NDIM} <: AbstractElement{NDIM}

Abstract type for beam (frame) elements in `NDIM` dimensions.

# Notes
- `NDIM` is the spatial dimension (2 or 3).
- DOFs per node differ from dimension: `Beam{2}` has 3 DOF/node,
  `Beam{3}` has 6 DOF/node.
"""
abstract type AbstractBeam{NDIM} <: AbstractElement{NDIM} end

# Explicit import for @kwdef macro (Julia 1.9+ has it in Base, but explicit is cleaner)
using Base: @kwdef

# ═══════════════════════════════════════════════════════════
# Concrete Structs
# ═══════════════════════════════════════════════════════════

"""
    Spring{NDIM} <: AbstractSpring{NDIM}

Concrete spring element type.

# Fields
- `k::Real`: Spring stiffness.
- `theta::Real`: Orientation angle in degrees (unused for 1-D).
"""
@kwdef struct Spring{NDIM} <: AbstractSpring{NDIM}
    k::Real = 0.0
    theta::Real = 0.0
end

"""
    Truss{NDIM} <: AbstractTruss{NDIM}

Concrete truss (bar) element type.

# Fields
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `L::Real`: Element length.
"""
@kwdef struct Truss{NDIM} <: AbstractTruss{NDIM}
    E::Real = 0.0
    A::Real = 0.0
    L::Real = 0.0
end

"""
    Beam{NDIM} <: AbstractBeam{NDIM}

Concrete beam (frame) element type.

# Fields
- `E::Real`: Modulus of elasticity.
- `A::Real`: Cross-sectional area.
- `I::Real`: Moment of inertia (2-D only).
- `Iy::Real`: Moment of inertia about local y-axis (3-D only).
- `Iz::Real`: Moment of inertia about local z-axis (3-D only).
- `J::Real`: Torsional constant (3-D only).
- `G::Real`: Shear modulus (3-D only).

# Notes
- `Beam{2}` has 3 DOF/node; `Beam{3}` has 6 DOF/node.
- `NDIM ≠ DOF` for beam elements.
"""
@kwdef struct Beam{NDIM} <: AbstractBeam{NDIM}
    E::Real = 0.0
    A::Real = 0.0
    I::Real = 0.0
    Iy::Real = 0.0
    Iz::Real = 0.0
    J::Real = 0.0
    G::Real = 0.0
end

# ═══════════════════════════════════════════════════════════
# Type Aliases
# ═══════════════════════════════════════════════════════════

const Spring1D = Spring{1}
const Spring2D = Spring{2}
const Spring3D = Spring{3}
const Truss1D = Truss{1}
const Truss2D = Truss{2}
const Truss3D = Truss{3}
const Beam2D = Beam{2}
const Beam3D = Beam{3}

# ═══════════════════════════════════════════════════════════
# Show Methods
# ═══════════════════════════════════════════════════════════

function Base.show(io::IO, s::Spring{NDIM}) where {NDIM}
    print(io, "Spring{$NDIM}(k=$(s.k)")
    if NDIM > 1
        print(io, ", theta=$(s.theta)")
    end
    print(io, ")")
end

function Base.show(io::IO, ::MIME"text/plain", s::Spring{NDIM}) where {NDIM}
    println(io, "Spring{$NDIM}:")
    println(io, "  k     = $(s.k)")
    if NDIM > 1
        println(io, "  theta = $(s.theta)°")
    end
end

function Base.show(io::IO, t::Truss{NDIM}) where {NDIM}
    print(io, "Truss{$NDIM}(E=$(t.E), A=$(t.A), L=$(t.L))")
end

function Base.show(io::IO, ::MIME"text/plain", t::Truss{NDIM}) where {NDIM}
    println(io, "Truss{$NDIM}:")
    println(io, "  E = $(t.E)")
    println(io, "  A = $(t.A)")
    println(io, "  L = $(t.L)")
end

function Base.show(io::IO, b::Beam{NDIM}) where {NDIM}
    print(io, "Beam{$NDIM}(E=$(b.E), A=$(b.A)")
    if NDIM == 2
        print(io, ", I=$(b.I)")
    else
        print(io, ", Iy=$(b.Iy), Iz=$(b.Iz), J=$(b.J), G=$(b.G)")
    end
    print(io, ")")
end

function Base.show(io::IO, ::MIME"text/plain", b::Beam{NDIM}) where {NDIM}
    println(io, "Beam{$NDIM}:")
    println(io, "  E = $(b.E)")
    println(io, "  A = $(b.A)")
    if NDIM == 2
        println(io, "  I = $(b.I)")
    else
        println(io, "  Iy = $(b.Iy)")
        println(io, "  Iz = $(b.Iz)")
        println(io, "  J  = $(b.J)")
        println(io, "  G  = $(b.G)")
    end
end
