% =========================================================================
% Problem 4.2 - Quadratic Bar with a Spring (Fig. 4.4)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 4, quadratic bar element and spring formulations.
%
% =========================================================================
% Fig. 4.4. Quadratic Bar and a Spring for Problem 4.2
% =========================================================================
%
%                             10 kN         5 kN
%                             ---->         ---->
% |/----o---/\/\/\---o=============o=============o
% |/    1           2             3             4
% |/    |<- k=2000 ->|<-- 2m ---->|<-- 2m ----->|
%                    |<--- quadratic bar (E=70GPa, A=0.001m²) -->|
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at nodes 2, 3, and 4
%   3. Reaction at node 1
%   4. Force in the spring
%   5. Quadratic bar element stresses
% =========================================================================

clear; clc;

E = 70e6

A = 0.001

L = 4

k1 = SpringElementStiffness(2000)

k2 = QuadraticBarElementStiffness(E,A,L)

K = zeros(4,4)

K = SpringAssemble(K,k1,1,2)

K = QuadraticBarAssemble(K,k2,2,4,3)

k = K(2:4,2:4)

f = [0 ; 10 ; 5]

u = k\f

U = [0 ; u]

F = K*U

u1 = [0 ; U(2)]

f1 = SpringElementForces(k1,u1)

u2 = [U(2) ; U(4) ; U(3)]

sigma2 = QuadraticBarElementStresses(k2,u2,A)
