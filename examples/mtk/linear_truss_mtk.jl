# Linear 2D Truss using ModelingToolkit.jl
# Replicates the notebook example from LibFEM.jl
using ModelingToolkit
using LinearAlgebra

# Parameters (same as notebook)
const L = 1000.0
const A = 100.0
const E = 210000.0
const FM = 5000.0

# Node coordinates (2D)
coords = Dict(
    1 => (0.0, 0.0),
    2 => (0.0, L),
    3 => (L, L),
    4 => (L, 0.0)
)

# Element connectivity
conns = [(1,3), (2,3), (2,4)]

# Helper: element length
@inline function element_length(x1,y1,x2,y2)
    sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

# Compute element lengths
Ls = []
for (i,j) in conns
    x1,y1 = coords[i]; x2,y2 = coords[j]
    push!(Ls, element_length(x1,y1,x2,y2))
end
L1, L2, L3 = Ls

# Areas (different for each element)
A1 = sqrt(2) * A
A2 = A
A3 = sqrt(2) * A

# Orientation angles in degrees
thetas = (45.0, 0.0, -45.0)

# Function to build element stiffness matrix (4x4) using MTK symbols
function k_e(E,A,L,theta_deg)
    theta = theta_deg * pi / 180
    C = cos(theta)
    S = sin(theta)
    ke = (E*A/L) * [
        C^2   C*S   -C^2  -C*S
        C*S   S^2   -C*S  -S^2
        -C^2  -C*S   C^2   C*S
        -C*S  -S^2   C*S   S^2
    ]
    return ke
end

# Build global stiffness matrix (8x8) by assembly
K = Matrix{Float64}(undef, 8, 8)
K .= 0.0

for ((i,j), (Li, Ai, thetai), ke) in zip(conns, zip(Ls, [A1,A2,A3], thetas), zip(k_e(E,A1,L1,45.0), k_e(E,A2,L2,0.0), k_e(E,A3,L3,-45.0)))
    # DOF indices (1-indexed)
    dof_i = 2*i-1
    dof_i_v = 2*i
    dof_j = 2*j-1
    dof_j_v = 2*j
    # Map ke entries to global K
    # row 1, col 1 -> u_i,u_i
    K[dof_i, dof_i] += ke[1,1]
    K[dof_i, dof_i_v] += ke[1,2]
    K[dof_i, dof_j]   += ke[1,3]
    K[dof_i, dof_j_v] += ke[1,4]
    # row 2, col 1 -> v_i,u_i
    K[dof_i_v, dof_i] += ke[2,1]
    K[dof_i_v, dof_i_v] += ke[2,2]
    K[dof_i_v, dof_j]   += ke[2,3]
    K[dof_i_v, dof_j_v] += ke[2,4]
    # row 3, col 1 -> u_j,u_i
    K[dof_j, dof_i] += ke[3,1]
    K[dof_j, dof_i_v] += ke[3,2]
    K[dof_j, dof_j]   += ke[3,3]
    K[dof_j, dof_j_v] += ke[3,4]
    # row 4, col 1 -> v_j,u_i
    K[dof_j_v, dof_i] += ke[4,1]
    K[dof_j_v, dof_i_v] += ke[4,2]
    K[dof_j_v, dof_j]   += ke[4,3]
    K[dof_j_v, dof_j_v] += ke[4,4]
end

# Apply boundary conditions: nodes 1 and 4 fixed (u=v=0)
# Fixed DOFs: 1,2 (node1), 7,8 (node4)
fixed = [1,2,7,8]
free = setdiff(1:8, fixed)  # DOFs 3,4,5,6

# Load vector: -FM applied at node 2 (vertical DOF = DOF 4)
F = zeros(8)
F[4] = -FM

# Solve for unknown displacements
U = zeros(8)
U[free] = K[free,free] \ F[free]

# Compute global forces (for verification)
F_calc = K * U

# Element displacement vectors (2 DOFs per node)
U1 = [U[1], U[2], U[5], U[6]]
U2 = [U[3], U[4], U[5], U[6]]
U3 = [U[3], U[4], U[7], U[8]]

# Strain computation (using the same angle-dependent formula as notebook)
@inline function truss_strain(Li, theta_deg, u_vec)
    theta = theta_deg * pi / 180
    C = cos(theta)
    S = sin(theta)
    return (-C*u_vec[1] - S*u_vec[2] + C*u_vec[3] + S*u_vec[4]) / Li
end

epsilon1 = truss_strain(L1, 45.0, U1)
epsilon2 = truss_strain(L2, 0.0, U2)
epsilon3 = truss_strain(L3, -45.0, U3)

# Element forces (using same formula as notebook)
@inline function truss_force(Ei, Ai, Li, theta_deg, u_vec)
    theta = theta_deg * pi / 180
    C = cos(theta)
    S = sin(theta)
    return Ei * Ai / Li * (-C*u_vec[1] - S*u_vec[2] + C*u_vec[3] + S*u_vec[4])
end

f1 = truss_force(E, A1, L1, 45.0, U1)
f2 = truss_force(E, A2, L2, 0.0, U2)
f3 = truss_force(E, A3, L3, -45.0, U3)

# Stresses
sigma1 = f1 / A1
sigma2 = f2 / A2
sigma3 = f3 / A3

println("=== Results ===")
println("Global stiffness matrix K:")
show(K)
println("\nDisplacements U:")
show(U)
println("\nElement forces f1, f2, f3:")
show([f1; f2; f3])
println("\nElement stresses sigma1, sigma2, sigma3:")
show([sigma1; sigma2; sigma3])

# Verify against notebook values (optional)
println("\n--- Check against notebook (approximate) ---")
println("Displacement at node 2 (u2): ", U[5])  # should be ~0.2381
println("Displacement at node 2 (v2): ", U[6])  # should be ~-0.7143
println("Element forces (expected): f1=-7071.07, f2=5000.0, f3=0.0")
println("Stresses (expected): sigma1=-50.0, sigma2=50.0, sigma3=0.0")