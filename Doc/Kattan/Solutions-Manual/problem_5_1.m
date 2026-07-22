% =========================================================================
% Problem 5.1 - Plane Truss with Nine Elements (Fig. 5.5)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 5, plane truss element formulation.
%
% =========================================================================
% Fig. 5.5. Plane Truss for Problem 5.1
% =========================================================================
%
%     Y
%     ^
%     |   2 ---(6)--- 4
%     |  / \       /  \
%     | /   \ (5) / (9)\
%   7m|/ (3) \  /      \
%     |1---(2)--3--(4)--5--(8)--6-----> X
%     |      5m      5m      5m
%     |       20 kN (+X at node 2)
%
%     Node coordinates:
%       1: (0, 0)    2: (5, 7)    3: (5, 0)
%       4: (10, 7)   5: (10, 0)   6: (15, 0)
%
%     Elements (9): 1→2, 1→3, 2→3, 3→5, 2→5, 2→4, 4→5, 5→6, 4→6
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at nodes 2, 3, 4, and 5
%   3. Reactions at nodes 1 and 6
%   4. Stress in each element
% =========================================================================

clear; clc;

E = 210e6

A = 0.005

L1 = PlaneTrussElementLength(0,0,5,7)

L5 = PlaneTrussElementLength(0,0,5,-7)

L9 = PlaneTrussElementLength(0,0,5,-7)

theta1 = atan(7/5)*180/pi

theta2 = 0

theta3 = 270

theta4 = 0

theta5 = 360 - theta1

theta6 = 0

theta7 = 270

theta8 = 0

theta9 = theta5

k1 = PlaneTrussElementStiffness(E,A,L1,theta1)

k2 = PlaneTrussElementStiffness(E,A,5,theta2)

k3 = PlaneTrussElementStiffness(E,A,7,theta3)

k4 = PlaneTrussElementStiffness(E,A,5,theta4)

k5 = PlaneTrussElementStiffness(E,A,L5,theta5)

k6 = PlaneTrussElementStiffness(E,A,5,theta6)

k7 = PlaneTrussElementStiffness(E,A,7,theta7)

k8 = PlaneTrussElementStiffness(E,A,5,theta8)

k9 = PlaneTrussElementStiffness(E,A,L9,theta9)

K = zeros(12,12)

K = PlaneTrussAssemble(K,k1,1,2)

K = PlaneTrussAssemble(K,k2,1,3)

K = PlaneTrussAssemble(K,k3,2,3)

K = PlaneTrussAssemble(K,k4,3,5)

K = PlaneTrussAssemble(K,k5,2,5)

K = PlaneTrussAssemble(K,k6,2,4)

K = PlaneTrussAssemble(K,k7,4,5)

K = PlaneTrussAssemble(K,k8,5,6)

K = PlaneTrussAssemble(K,k9,4,6)

k = K(3:10,3:10)

f = [20 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0]

u = k\f

U = [0 ; 0 ; u ; 0 ; 0]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4)]

sigma1 = PlaneTrussElementStress(E,L1,theta1,u1)

u2 = [U(1) ; U(2) ; U(5) ; U(6)]

sigma2 = PlaneTrussElementStress(E,5,theta2,u2)

u3 = [U(3) ; U(4) ; U(5) ; U(6)]

sigma3 = PlaneTrussElementStress(E,7,theta3,u3)

u4 = [U(5) ; U(6) ; U(9) ; U(10)]

sigma4 = PlaneTrussElementStress(E,5,theta4,u4)

u5 = [U(3) ; U(4) ; U(9) ; U(10)]

sigma5 = PlaneTrussElementStress(E,L5,theta5,u5)

u6 = [U(3) ; U(4) ; U(7) ; U(8)]

sigma6 = PlaneTrussElementStress(E,5,theta6,u6)

u7 = [U(7) ; U(8) ; U(9) ; U(10)]

sigma7 = PlaneTrussElementStress(E,7,theta7,u7)

u8 = [U(9) ; U(10) ; U(11) ; U(12)]

sigma8 = PlaneTrussElementStress(E,5,theta8,u8)

u9 = [U(7) ; U(8) ; U(11) ; U(12)]

sigma9 = PlaneTrussElementStress(E,L9,theta9,u9)
