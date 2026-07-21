% =========================================================================
% Problem 3.1 - Three-Bar Structure (Fig. 3.5)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 3, linear bar element formulation.
%
% =========================================================================
% Fig. 3.5. Three-Bar Structure
% =========================================================================
%
%                    P1=10 kN
%                 <----------
% |/----o---------o---------o---------o----> P2=15 kN
% |/    1         2         3         4
% |/
%      |-- 1 m --|-- 2 m --|-- 1 m --|
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at nodes 2, 3, and 4
%   3. Reaction at node 1
%   4. Stress in each bar
% =========================================================================

clear; clc;

E = 70e6

A = 0.005

L1 = 1

L2 = 2

L3 = 1

k1 = LinearBarElementStiffness(E,A,L1)

k2 = LinearBarElementStiffness(E,A,L2)

k3 = LinearBarElementStiffness(E,A,L3)

K = zeros(4,4)

K = LinearBarAssemble(K,k1,1,2)

K = LinearBarAssemble(K,k2,2,3)

K = LinearBarAssemble(K,k3,3,4)

k = K(2:4,2:4)

f = [-10 ; 0 ; 15]

u = k\f

U = [0 ; u]

F = K*U

u1 = [0 ; U(2)]

sigma1 = LinearBarElementStresses(k1,u1,A)

u2 = [U(2) ; U(3)]

sigma2 = LinearBarElementStresses(k2,u2,A)

u3 = [U(3) ; U(4)]

sigma3 = LinearBarElementStresses(k3,u3,A)
