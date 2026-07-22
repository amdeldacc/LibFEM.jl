% =========================================================================
% Problem 5.2 - Plane Truss with Spring (Fig. 5.6)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 5, plane truss element formulation.
% =========================================================================
%
%     Node 3: (0,7)
%       |
%       |  element 3 (L3=5.657, theta3=315)
%       |
%       |      Node 4: (4,3)---[k=3000]---Node 5 (Fx=10 kN)
%       |     /
%       |    / element 1 (L1=5, theta1=36.87)
%       |   /
%     Node 1: (0,0)
%       |
%       |  element 2 (L2=4, theta2=0)
%       |
%     Node 2: (0,3)
%
%     Nodes 1,2,3: fixed supports
%     E = 70 GPa, A = 0.01 m^2
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at node 4 and spring end (node 5)
%   3. Reactions at nodes 1, 2, and 3
%   4. Stress in each truss element
%   5. Force in the spring
% =========================================================================

clear; clc;

E = 70e6

A = 0.01

L1 = PlaneTrussElementLength(0,0,4,3)

L2 = PlaneTrussElementLength(0,0,4,0)

L3 = PlaneTrussElementLength(0,0,4,-4)

theta1 = atan(3/4)*180/pi

theta2 = 0

theta3 = 360 - atan(4/4)*180/pi

k1 = PlaneTrussElementStiffness(E,A,L1,theta1)

k2 = PlaneTrussElementStiffness(E,A,L2,theta2)

k3 = PlaneTrussElementStiffness(E,A,L3,theta3)

k4 = SpringElementStiffness(3000)

K = zeros(9,9)

K = PlaneTrussAssemble(K,k1,1,4)

K = PlaneTrussAssemble(K,k2,2,4)

K = PlaneTrussAssemble(K,k3,3,4)

K = SpringAssemble(K,k4,7,9)

k = K(7:9,7:9)

f = [0 ; 0 ; 10]

u = k\f

U = [0 ; 0 ; 0 ; 0 ; 0 ; 0 ; u]

F = K*U

u1 = [U(1) ; U(2) ; U(7) ; U(8)]

sigma1 = PlaneTrussElementStress(E,L1,theta1,u1)

u2 = [U(3) ; U(4) ; U(7) ; U(8)]

sigma2 = PlaneTrussElementStress(E,L2,theta2,u2)

u3 = [U(5) ; U(6) ; U(7) ; U(8)]

sigma3 = PlaneTrussElementStress(E,L3,theta3,u3)

u4 = [U(7) ; U(9)]

f4 = SpringElementForces(k4,u4)
