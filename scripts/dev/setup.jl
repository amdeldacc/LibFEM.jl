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
project_dir = dirname(dirname(@__DIR__))
Pkg.activate(project_dir)
Pkg.instantiate()

using LibFEM, LinearAlgebra, Plots

println("Ready.")
