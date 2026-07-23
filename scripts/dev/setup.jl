# This file is part of LibFEM.jl
#
# MIT License
#
# Setup script for Julia dev session — loads Revise, instantiates project,
# pre-loads LibFEM + common dependencies, and prints "Ready."

try
    using Revise
catch
    @warn "Revise.jl not installed — skipping"
end

using Pkg
Pkg.instantiate()

using LibFEM, LinearAlgebra, Plots

println("Ready.")
