% =========================================================================
% Problem 2.1 - Two-Element Spring System (Fig. 2.4)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 2, spring element formulation.
%
% System:  1 --[k1]-- 2 --[k2]-- 3
%          Node 1 and Node 3 are fixed to walls (u1 = u3 = 0)
%          Force P is applied at Node 2, along the 1->3 axis
%
%   k1 = 200 kN/m          k2 = 250 kN/m
%   |||--/\/\/\---/\/\/\--|||
%     1          2          3
%                |>── P = 10 kN
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacement at node 2
%   3. Forces (reactions at 1,3 and internal spring forces)
%   4. Equilibrium check
% =========================================================================

clear; clc;

% ---------------------- Given data --------------------------------------
k1 = 200;   % spring 1 stiffness, kN/m
k2 = 250;   % spring 2 stiffness, kN/m
P  = 10;    % applied force at node 2, kN

% ---------------------- 1. Assemble global stiffness matrix -------------
K = zeros(3, 3);

k1 = SpringElementStiffness(k1);
K = SpringAssemble(K, k1, 1, 2);

k2 = SpringElementStiffness(k2);
K = SpringAssemble(K, k2, 2, 3);

disp('=========================================================');
disp('1. Global stiffness matrix K (kN/m):');
disp(K);

% ---------------------- 2. Solve for displacement -----------------------
k = K(2, 2);       % free DOF stiffness
f = [P];           % force vector at free DOF
u = k \ f;         % displacement at node 2
U = [0; u; 0];     % full nodal displacement vector

disp('=========================================================');
fprintf('2. Displacement at node 2:\n');
fprintf('   u2 = %.6f m\n', u);

% ---------------------- 3. Forces (reactions + element forces) -----------
F = K * U;         % global forces (includes reactions at constrained DOFs)

disp('=========================================================');
fprintf('3. Global force vector (reactions at nodes 1 and 3):\n');
fprintf('   R1 = %.4f kN\n', F(1));
fprintf('   R2 = %.4f kN (applied load)\n', F(2));
fprintf('   R3 = %.4f kN\n', F(3));

u1 = [0; u];                       % element 1 nodal displacements
f1 = SpringElementForces(k1, u1);  % force in spring 1

u2 = [u; 0];                       % element 2 nodal displacements
f2 = SpringElementForces(k2, u2);  % force in spring 2

fprintf('   f1 (spring 1) = %.4f kN (tension)\n', f1(1));
fprintf('   f2 (spring 2) = %.4f kN (tension)\n', f2(1));

% ---------------------- 4. Equilibrium check ----------------------------
disp('=========================================================');
fprintf('4. Equilibrium check, R1 + P + R3 = %.6f (should be ~0)\n', ...
        F(1) + P + F(3));
