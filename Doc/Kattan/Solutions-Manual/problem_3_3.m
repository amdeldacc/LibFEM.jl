% =========================================================================
% Problem 3.3 - Linear Bar with a Spring (Fig. 3.6)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 3, linear bar and spring element formulations.
%
% =========================================================================
% Fig. 3.6. Linear Bar with a Spring for Problem 3.3
% =========================================================================
%
%                                  P
%                  E, A          ----->         k
% |/----o========================o---------/\/\/\-----o----\|
% |/    1                        2                    3    \|
% |/    <-------- 2 m --------->                           \|
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacement at node 2
%   3. Reactions at nodes 1 and 3
%   4. Stress in the bar
%   5. Force in the spring
% =========================================================================

clear; clc;

E = 200e6

A = 0.01

L = 2

k1 = LinearBarElementStiffness(E,A,L)

k2 = SpringElementStiffness(1000)

K = zeros(3,3)

K = LinearBarAssemble(K,k1,1,2)

K = SpringAssemble(K,k2,2,3)

k = K(2,2)

f = [25]

u = k\f

U = [0 ; u ; 0]

F = K*U

u1 = [0 ; u]

sigma1 = LinearBarElementStresses(k1,u1,A)

u2 = [u ; 0]

f2 = SpringElementForces(k2,u2)
