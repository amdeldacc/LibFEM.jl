% =========================================================================
% Problem 2.2 - Four-Element Spring System (Fig. 2.5)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 2, spring element formulation.
%
% =========================================================================
% Fig. 2.5. Four-Element Spring System
% =========================================================================
%
%                                k
%                         +---/\/\/\---+
% |/           k          |            |           k
% |/----o----/\/\/\-------o            o-------/\/\/\----o---> P
% |/    1                 2            3                 4
%                         |            |
%                         +---/\/\/\---+
%                                k
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at nodes 2, 3, and 4
%   3. Reaction at node 1
%   4. Force in each spring
% =========================================================================

clear; clc;

k1 = SpringElementStiffness(170)
k2 = SpringElementStiffness(170)
k3 = SpringElementStiffness(170)
k4 = SpringElementStiffness(170)

K = zeros(4,4)

K = SpringAssemble(K,k1,1,2)
K = SpringAssemble(K,k2,2,3)
K = SpringAssemble(K,k3,2,3)
K = SpringAssemble(K,k4,3,4)

k = K(2:4,2:4)

f = [0 ; 0 ; 25]

u = k\f

U = [0;u]

F = K*U;
F(abs(F) < 1e-10) = 0

u1 = [0;U(2)]
f2 = SpringElementForces(k1,u1)

u2 = [U(2);U(3)]
f2 = SpringElementForces(k2,u2)

u3 = [U(2);U(3)]
f3 = SpringElementForces(k3,u3)

u4 = [U(3);U(4)]
f4 = SpringElementForces(k4,u4)