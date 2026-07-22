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
% ===============================================================================
% NODE COORDINATES (X, Y, Z) IN METERS:
% ===============================================================================
% Origin (0,0,0) is located on the ground plane, directly below Node 5.
%
%   Node 1 : (-3,  0, -3)    -> Fixed Support
%   Node 2 : (-3,  0,  3)    -> Fixed Support
%   Node 3 : ( 4,  0,  3)    -> Fixed Support
%   Node 4 : ( 4,  0, -3)    -> Fixed Support
%   Node 5 : ( 0,  5,  0)    -> Free Node (Forces P1 and P2 applied here)
%
% ===============================================================================

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
