% =========================================================================
% Problem 6.1 - Space Truss with Four Elements (Fig. 6.3)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 6, space truss element formulation.
%
% ===============================================================================
% PROBLEM OVERVIEW: 3D SPACE TRUSS (Fig 6.3)
% ===============================================================================
% Note: To keep the schematic clean and readable in plain text, the 3D 
% perspective is simplified. Exact dimensions are provided in the table below.
%
%                                       Y
%                                       ^
%                                       |             P1 (Load)
%                          P2 <-------- O [NODE 5]   ↗
%                        (Load)        /|\ \       /
%                                     / | \  \
%                                    /  |  \   \
%                                   /   |   \    \
%                                  /    |    \     \
%                                 /     |     \      \
%                                /      |      \       \
%                               /   (h = 5m)    \        \
%                              /        |        \         \
%                   [NODE 1]  O - - - - + - - - - O [NODE 4] - - > X
%                            ///      Origin       ///
%                            /          |            \
%                           /           |              \
%                          /            v Z              \
%                         /                                \
%               [NODE 2] O - - - - - - - - - - - - - - - - - O [NODE 3]
%                       ///                                 ///
%
%     Node coordinates:
%       1: (0, 0, -3)    2: (-3, 0, 0)    3: (0, 0, 3)
%       4: (4, 0, 0)     5: (0, 5, 0)
%
%     Elements: 1→5, 2→5, 3→5, 4→5
%     Loads: P1=15 kN (+X), P2=20 kN (-Z)
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Displacements at node 5
%   3. Reactions at nodes 1, 2, 3, and 4
%   4. Stress in each element
% =========================================================================

clear; clc;

E = 200e6

A = 0.003

L1 = SpaceTrussElementLength(0,0,-3,0,5,0)

L2 = SpaceTrussElementLength(-3,0,0,0,5,0)

L3 = SpaceTrussElementLength(0,0,3,0,5,0)

L4 = SpaceTrussElementLength(4,0,0,0,5,0)

theta1x = acos(0/L1)*180/pi

theta1y = acos(5/L1)*180/pi

theta1z = acos(3/L1)*180/pi

theta2x = acos(3/L2)*180/pi

theta2y = acos(5/L2)*180/pi

theta2z = acos(0/L2)*180/pi

theta3x = acos(0/L3)*180/pi

theta3y = acos(5/L3)*180/pi

theta3z = acos(-3/L3)*180/pi

theta4x = acos(-4/L4)*180/pi

theta4y = acos(5/L4)*180/pi

theta4z = acos(0/L4)*180/pi

k1 = SpaceTrussElementStiffness(E,A,L1,theta1x,theta1y,theta1z)

k2 = SpaceTrussElementStiffness(E,A,L2,theta2x,theta2y,theta2z)

k3 = SpaceTrussElementStiffness(E,A,L3,theta3x,theta3y,theta3z)

k4 = SpaceTrussElementStiffness(E,A,L4,theta4x,theta4y,theta4z)

K = zeros(15,15)

K = SpaceTrussAssemble(K,k1,1,5)

K = SpaceTrussAssemble(K,k2,2,5)

K = SpaceTrussAssemble(K,k3,3,5)

K = SpaceTrussAssemble(K,k4,4,5)

k = K(13:15,13:15)

f = [15 ; 0 ; -20]

u = k\f

U = [0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; u]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(13) ; U(14) ; U(15)]

sigma1 = SpaceTrussElementStress(E,L1,theta1x,theta1y,theta1z,u1)

u2 = [U(4) ; U(5) ; U(6) ; U(13) ; U(14) ; U(15)]

sigma2 = SpaceTrussElementStress(E,L2,theta2x,theta2y,theta2z,u2)

u3 = [U(7) ; U(8) ; U(9) ; U(13) ; U(14) ; U(15)]

sigma3 = SpaceTrussElementStress(E,L3,theta3x,theta3y,theta3z,u3)

u4 = [U(10) ; U(11) ; U(12) ; U(13) ; U(14) ; U(15)]

sigma4 = SpaceTrussElementStress(E,L4,theta4x,theta4y,theta4z,u4)
