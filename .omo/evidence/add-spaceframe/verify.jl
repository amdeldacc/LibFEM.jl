#!/usr/bin/env julia
# Verification script for 3D space frame (beam) element
# Tests horizontal beam along X-axis: (0,0,0) → (4,0,0)

using LibFEM

all_pass = true
failures = 0

function check(description, condition)
    global all_pass, failures
    if condition
        println("PASS: ", description)
    else
        println("FAIL: ", description)
        all_pass = false
        failures += 1
    end
end

# Parameters
const E  = 3e10
const G  = 1.15e8
const A  = 0.01
const Iy = 1e-4
const Iz = 2e-4
const J  = 1e-5
const x1, y1, z1 = 0.0, 0.0, 0.0
const x2, y2, z2 = 4.0, 0.0, 0.0
const L = 4.0  # hand-computed length

# --- Test 1: Element length ---
computed_L = d3_beam_elementlength(x1, y1, z1, x2, y2, z2)
check("length = 4.0", computed_L == L)

# --- Test 2: Stiffness matrix shape ---
k = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)
check("stiffness matrix is 12×12", size(k) == (12, 12))

# --- Test 3: Axial stiffness k[1,1] = E*A/L ---
# For horizontal beam (Lambda=I), k = kprime
# kprime[1,1] = w1 = E*A/L
expected_k11 = E * A / L
check("axial stiffness k[1,1] = $expected_k11", isapprox(k[1,1], expected_k11; rtol=1e-10))

# --- Test 4: Shear-bending coupling k[2,6] = 6*E*Iz/L² ---
# kprime[2,6] = w3 = 6*E*Iz/L²
expected_k26 = 6 * E * Iz / (L^2)
check("shear-bending coupling k[2,6] = $expected_k26", isapprox(k[2,6], expected_k26; rtol=1e-10))

# --- Test 5: Element forces for zero displacement ---
u_zero = zeros(12)
f = d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u_zero)
check("zero displacement forces are all zero", all(f .== 0.0))

# --- Test 6: Assembly ---
let
    Kmat = zeros(12, 12)
    try
        Kmat = d3_beam_assemble(Kmat, k, 1, 2)
        check("assembly completes without error", true)
    catch e
        check("assembly completes without error", false)
        println("  Assembly error: ", e)
    end
end

# --- Summary ---
println()
if all_pass
    println("All checks passed.")
    exit(0)
else
    println("$failures check(s) FAILED.")
    exit(1)
end
