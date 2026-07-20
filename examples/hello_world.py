#!/usr/bin/env python3
"""
LibFEM.jl Hello World Example (Python)

This script demonstrates calling LibFEM.jl from Python to solve a simple
1D spring system - the classic "Hello World" of Finite Element Analysis.

Requirements:
    pip install julia

Or run via julia command directly if PyJulia not installed.
"""

import subprocess
import sys
import json


def run_via_julia_cmd(julia_code: str) -> str | None:
    """Execute Julia code via command line and return stdout."""
    result = subprocess.run(
        ["julia", "--project=.", "-e", julia_code],
        capture_output=True,
        text=True,
        cwd="/home/piou/LibFEM.jl"
    )
    if result.returncode != 0:
        print(f"Julia error: {result.stderr}", file=sys.stderr)
        return None
    return result.stdout


def main():
    print("=" * 60)
    print("LibFEM.jl Hello World - 1D Spring System")
    print("=" * 60)
    print()

    # Julia code for a simple 2-spring system (classic FEM example)
    # Two springs in series: k1=200, k2=250, force=10 at node 2
    julia_code = '''
    using Pkg; Pkg.activate(".")
    using LibFEM
    using LinearAlgebra

    println("Loading LibFEM.jl...")

    # Spring stiffnesses (N/m)
    k1 = 200.0
    k2 = 250.0

    # Element stiffness matrices (2x2 each)
    K1 = d1_spring_elementstiffness(k1)
    K2 = d1_spring_elementstiffness(k2)

    println("Element 1 stiffness matrix:")
    display(K1)
    println()

    println("Element 2 stiffness matrix:")
    display(K2)
    println()

    # Global stiffness matrix (3 nodes, 1 DOF each = 3x3)
    K = zeros(3, 3)

    # Assemble element 1 between nodes 1-2
    K = d1_spring_assemble(K, K1, 1, 2)

    # Assemble element 2 between nodes 2-3
    K = d1_spring_assemble(K, K2, 2, 3)

    println("Global stiffness matrix (assembled):")
    display(K)
    println()

    # Boundary conditions: u1 = 0 (fixed), u3 = 0 (fixed)
    # Force: F2 = 10 N at node 2
    F = [0.0, 10.0, 0.0]

    # Apply boundary conditions (remove rows/cols for fixed DOFs)
    # Keep only DOF 2 (node 2)
    K_reduced = K[2:2, 2:2]
    F_reduced = F[2:2]

    println("Reduced system:")
    println("K_reduced = ", K_reduced)
    println("F_reduced = ", F_reduced)
    println()

    # Solve: K * u = F
    u_reduced = K_reduced \\ F_reduced

    # Reconstruct full displacement vector
    u = [0.0, u_reduced[1], 0.0]

    println("Displacements (m):")
    for i in 1:3
        println("  u[$i] = ", u[i])
    end
    println()

    # Compute element forces
    # Element 1 connects nodes 1-2: u_e = [u1, u2]
    u_e1 = [u[1], u[2]]
    f_e1 = d1_spring_elementforce(K1, u_e1)
    println("Element 1 force: ", f_e1[1], " N")

    # Element 2 connects nodes 2-3: u_e = [u2, u3]
    u_e2 = [u[2], u[3]]
    f_e2 = d1_spring_elementforce(K2, u_e2)
    println("Element 2 force: ", f_e2[1], " N")

    # Compute element stresses
    sigma1 = d1_spring_elementstress(K1, u_e1)
    sigma2 = d1_spring_elementstress(K2, u_e2)
    println("Element 1 stress: ", sigma1[1], " Pa")
    println("Element 2 stress: ", sigma2[1], " Pa")

    println()
    println("✓ Hello World FEM solve complete!")
    '''

    print("Running LibFEM.jl example via Julia...")
    print("-" * 60)

    output = run_via_julia_cmd(julia_code)

    if output:
        print(output)
    else:
        print("Failed to run Julia code. Is Julia installed and in PATH?")
        print("Try: julia --project=. -e 'using LibFEM' to verify installation")
        sys.exit(1)


if __name__ == "__main__":
    main()