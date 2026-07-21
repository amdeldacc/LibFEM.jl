% =========================================================================
% Problem 2.1 - Two-Element Spring System (Fig. 2.4)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 2, spring element formulation.
%
% =========================================================================
% Fig. 2.4. Two-Element Spring System
% =========================================================================
%
%                             P
%               k1          ----->         k2
% |/----o-----/\/\/\----------o---------/\/\/\-----o----\|
% |/    1                     2                    3    \|
% |/                                                    \|
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacement at node 2
%   3. Forces (reactions at 1,3 and internal spring forces)
%   4. Equilibrium check
% =========================================================================

clear; clc;

k1 = SpringElementStiffness(200)
k2 = SpringElementStiffness(250)

K = zeros(3,3)

K = SpringAssemble(K,k1,1,2)
K = SpringAssemble(K,k2,2,3)

k = K(2,2)

f = [10]

u = k\f

U = [0 ; u ; 0]

F = K*U

u1 = [0;u]
f1 = SpringElementForces(k1,u1)

u2 = [u ; 0]
f2 = SpringElementForces(k2,u2)
