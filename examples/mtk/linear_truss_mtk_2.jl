using LinearAlgebra

# Parameters
const L = 1000.0
const A = 100.0
const E = 210000.0
const FM = 5000.0

# Node coordinates
X1pos = 0.0;  Y1pos = 0.0
X2pos = 0.0;  Y2pos = L
X3pos = L;    Y3pos = L
X4pos = L;    Y4pos = 0.0

# Element lengths
element_length(x1,y1,x2,y2) = sqrt((x2-x1)^2 + (y2-y1)^2)
L1 = element_length(X1pos,Y1pos,X3pos,Y3pos)
L2 = element_length(X2pos,Y2pos,X3pos,Y3pos)
L3 = element_length(X2pos,Y2pos,X4pos,Y4pos)

# Cross-sectional areas
A1 = sqrt(2) * A
A2 = A
A3 = sqrt(2) * A

# ── Element stiffness matrix (4×4) ──────────────────────────────────────────
function k_e(E, A, L, theta_deg)
    theta = theta_deg * pi / 180
    C = cos(theta);  S = sin(theta)
    return E * A / L * [
         C^2    C*S   -C^2   -C*S
         C*S    S^2   -C*S   -S^2
        -C^2   -C*S    C^2    C*S
        -C*S   -S^2    C*S    S^2
    ]
end

K1 = k_e(E, A1, L1,  45.0)
K2 = k_e(E, A2, L2,   0.0)
K3 = k_e(E, A3, L3, -45.0)

# ── Assembly: place each 4×4 Ke into an 8×8 global matrix ───────────────────
function assemble(K_global, Ke, node_i, node_j)
    K_out = copy(K_global)
    dofs = [2*node_i-1, 2*node_i, 2*node_j-1, 2*node_j]
    for (a, I) in enumerate(dofs)
        for (b, J) in enumerate(dofs)
            K_out[I, J] += Ke[a, b]
        end
    end
    return K_out
end

K = zeros(8, 8)
K1P = assemble(zeros(8,8), K1, 1, 3)
K2P = assemble(zeros(8,8), K2, 2, 3)
K3P = assemble(zeros(8,8), K3, 2, 4)
K = K1P + K2P + K3P

println("Global stiffness matrix K:")
display(K)

# ── Solve displacement equations ─────────────────────────────────────────────
# Nodes 1 and 4 are fixed → DOFs 1,2,7,8 = 0
# Free DOFs: 3,4 (node 2) and 5,6 (node 3)
# Load: F at node 3 → DOF 5 = 0, DOF 6 = -FM
K_s = K[5:6, 5:6]
F_s = [0.0, -FM]
U_s = K_s \ F_s

println("\nFree displacements (node 3):")
println("  u3 = ", U_s[1], "  (expected  0.2381)")
println("  v3 = ", U_s[2], "  (expected -0.7143)")

# ── Global displacement vector ───────────────────────────────────────────────
U = [0.0, 0.0, 0.0, 0.0, U_s[1], U_s[2], 0.0, 0.0]

# ── Global force vector ───────────────────────────────────────────────────────
F = K * U
println("\nGlobal force vector F:")
display(F)

# ── Element nodal displacement vectors ───────────────────────────────────────
U1 = [U[1], U[2], U[5], U[6]]   # element 1: nodes 1→3
U2 = [U[3], U[4], U[5], U[6]]   # element 2: nodes 2→3
U3 = [U[3], U[4], U[7], U[8]]   # element 3: nodes 2→4

# ── Strain, force, stress ─────────────────────────────────────────────────────
function truss_strain(L, theta_deg, u)
    t = theta_deg * pi / 180
    C = cos(t);  S = sin(t)
    return (-C*u[1] - S*u[2] + C*u[3] + S*u[4]) / L
end

function truss_force(E, A, L, theta_deg, u)
    return E * A * truss_strain(L, theta_deg, u)
end

function truss_stress(E, L, theta_deg, u)
    return E * truss_strain(L, theta_deg, u)
end

ε1 = truss_strain(L1,  45.0, U1);  f1 = truss_force(E, A1, L1,  45.0, U1);  σ1 = truss_stress(E, L1,  45.0, U1)
ε2 = truss_strain(L2,   0.0, U2);  f2 = truss_force(E, A2, L2,   0.0, U2);  σ2 = truss_stress(E, L2,   0.0, U2)
ε3 = truss_strain(L3, -45.0, U3);  f3 = truss_force(E, A3, L3, -45.0, U3);  σ3 = truss_stress(E, L3, -45.0, U3)

println("\n=== Results ===")
println("Strains:  ε1=", ε1, "  ε2=", ε2, "  ε3=", ε3)
println("Forces:   f1=", f1, "  f2=", f2, "  f3=", f3)
println("          (expected: -7071.07, 5000.0, 0.0)")
println("Stresses: σ1=", σ1, "  σ2=", σ2, "  σ3=", σ3)
println("          (expected: -50.0, 50.0, 0.0)")

# ── Plot undeformed vs deformed ───────────────────────────────────────────────
using Plots

fampl = 100

# Undeformed
plot( [X1pos, X3pos], [Y1pos, Y3pos], label=false, marker=5, markershape=:square, color=:black)
plot!([X2pos, X3pos], [Y2pos, Y3pos], label=false, marker=5, markershape=:square, color=:black)
plot!([X2pos, X4pos], [Y2pos, Y4pos], label=false, marker=5, markershape=:square, color=:black)

# Deformed
plot!([X1pos + fampl*U[1], X3pos + fampl*U[5]], [Y1pos + fampl*U[2], Y3pos + fampl*U[6]],
      label=false, marker=5, markershape=:square, color=:blue)
plot!([X2pos + fampl*U[3], X3pos + fampl*U[5]], [Y2pos + fampl*U[4], Y3pos + fampl*U[6]],
      label=false, marker=5, markershape=:square, color=:blue)
plot!([X2pos + fampl*U[3], X4pos + fampl*U[7]], [Y2pos + fampl*U[4], Y4pos + fampl*U[8]],
      label=false, marker=5, markershape=:square, color=:blue,
      title="Undeformed and Deformed Shapes",
      xlabel="Horizontal coordinate X",
      ylabel="Vertical coordinate Y")