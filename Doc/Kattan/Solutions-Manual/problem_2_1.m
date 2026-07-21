% =========================================================================
% Problem 2.1 - Two-Element Spring System (Fig. 2.4)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 2, spring element formulation.
%
% System:  1 --[k1]-- 2 --[k2]-- 3
%          Node 1 and Node 3 are fixed to walls (u1 = u3 = 0)
%          Force P is applied at Node 2, along the 1->3 axis
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacement at node 2
%   3. Reactions at nodes 1 and 3
%   4. Force in each spring
%
% Requires springElementStiffness.m, springAssemble.m, springElementForce.m
% (in the same folder as this script).
% =========================================================================

clear; clc;

% ---------------------- Given data --------------------------------------
k1 = 200;   % spring 1 stiffness, kN/m
k2 = 250;   % spring 2 stiffness, kN/m
P  = 10;    % applied force at node 2, kN

n_nodes = 3;

% ---------------------- 1. Assemble global stiffness matrix -------------
K = zeros(n_nodes);

k1_local = springElementStiffness(k1);
K = springAssemble(K, k1_local, 1, 2);

k2_local = springElementStiffness(k2);
K = springAssemble(K, k2_local, 2, 3);

disp('=========================================================');
disp('1. Global stiffness matrix K (kN/m):');
disp(K);

% ---------------------- 2. Apply boundary conditions and solve ----------
% u1 = 0 (fixed), u3 = 0 (fixed) -> node 2 is the only free DOF
free_dof = 2;

F = zeros(n_nodes,1);
F(2) = P;

u = zeros(n_nodes,1);
u(free_dof) = K(free_dof,free_dof) \ F(free_dof);

disp('=========================================================');
fprintf('2. Nodal displacements:\n');
fprintf('   u1 = %.6f m (fixed)\n', u(1));
fprintf('   u2 = %.6f m\n', u(2));
fprintf('   u3 = %.6f m (fixed)\n', u(3));

% ---------------------- 3. Reactions at nodes 1 and 3 -------------------
% Full-system equilibrium: K*u = F + R   =>   R = K*u - F
R = K*u - F;

disp('=========================================================');
fprintf('3. Reactions:\n');
fprintf('   R1 = %.4f kN\n', R(1));
fprintf('   R3 = %.4f kN\n', R(3));

% ---------------------- 4. Force in each spring --------------------------
f1 = springElementForce(k1, u(1), u(2));
f2 = springElementForce(k2, u(2), u(3));

disp('=========================================================');
fprintf('4. Element (spring) forces (+ = tension, - = compression):\n');
fprintf('   f1 (spring 1, nodes 1-2) = %.4f kN\n', f1);
fprintf('   f2 (spring 2, nodes 2-3) = %.4f kN\n', f2);

disp('=========================================================');
fprintf('Equilibrium check, R1 + P + R3 = %.6f (should be ~0)\n', R(1)+P+R(3));
