% ===============================================================================
% PROBLEM OVERVIEW: PLANE FRAME WITH A SPRING (Fig 8.23)
% ===============================================================================
%
%                                       |//
%                                      3|//
%                                      O|//
%                                    /  |//
%                                  \    |//
%                                /      |//
%                              \        |//
%                       k   /           |//   - - -
%                         \             |//     ^
%                       /               |//     |
%                     \                 |//    3 m
%                  /                    |//     |
%              1 \                     2|//     v
%              O=======================O|//   - - -
%              |                        |//
%              v                        |//
%            10 kN
%
%              |<-------- 4 m -------->|
%
% ===============================================================================
% NODE COORDINATES & LOADS:
% ===============================================================================
% Assuming Node 1 is at the origin (0,0) and the unit is meters:
%
%   Node 1 : ( 0, 0)   -> Connected to frame & spring, Applied Load: Py = -10 kN
%   Node 2 : ( 4, 0)   -> Fixed Support (Wall)
%   Node 3 : ( 4, 3)   -> Fixed Support (Wall)
%
%   Element 1-2 : Rigid Frame Element (E=70e6, A=1e-2, I=1e-5)
%   Element 1-3 : Spring Element modeled as Truss (k=5000 kN/m)
%
% ===============================================================================
%
% NOTE: The spring is modeled using PlaneTrussElementStiffness with equivalent
%       properties E=2500, A=10, L=5, giving keq = EA/L = 5000 kN/m.
%       Mixed element types with different DOFs per node.
%       Frame nodes have 3 DOFs (x, y, rotation).
%       Truss/spring nodes have 2 DOFs (x, y).
%       Global K is 8x8.
%       Truss uses separate node numbering: node 4 maps to DOFs 7,8
%       (2*4-1=7, 2*4=8) to avoid conflict with frame node 2 (DOFs 4-6).
%
% Computes:
%   1. Element stiffness matrices (frame 6x6, spring/truss 4x4)
%   2. Global stiffness matrix K (8x8)
%   3. Reduced system and displacements
%   4. Reactions at all nodes
%   5. Element forces for both elements
%   6. Axial, shear, and moment diagrams for frame element
% ===============================================================================

clear; clc;

E1 = 70e6

A1 = 1e-2

I = 1e-5

E2 = 2500

A2 = 10

L2 = 5

L1 = 4

theta1 = 0

theta2 = atan(3/4)*180/pi

k1 = PlaneFrameElementStiffness(E1,A1,I,L1,theta1)

k2 = PlaneTrussElementStiffness(E2,A2,L2,theta2)

K = zeros(8,8)

K = PlaneFrameAssemble(K,k1,1,2)

K = PlaneTrussAssemble(K,k2,1,4)

k = K(1:3,1:3)

f = [0 ; -10 ; 0]

u = k\f

U = [u ; 0 ; 0 ; 0 ; 0 ; 0]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4) ; U(5) ; U(6)]

u2 = [U(1) ; U(2) ; U(7) ; U(8)]

f1 = PlaneFrameElementForces(E1,A1,I,L1,theta1,u1)

f2 = PlaneTrussElementForce(E2,A2,L2,theta2,u2)

PlaneFrameElementAxialDiagram(f1,L1)
PlaneFrameElementShearDiagram(f1,L1)
PlaneFrameElementMomentDiagram(f1,L1)
