% ===============================================================================
% PROBLEM OVERVIEW: PLANE FRAME WITH DISTRIBUTED LOAD (Fig 8.22)
% ===============================================================================
%
%                      5 kN/m
%                      +---+---+---+---+---+
%                      |   |   |   |   |   |
%                      v   v   v   v   v   v
%                      2                   3
%          20 kN ----->O===================O        - - -
%                     /                     \         ^
%                    /                       \       3 m
%                  1/                         \4      v
%                  O                           O    - - -
%                -----                       -----
%                /////                       /////
%
%              |<-2m->|<--------5m-------->|<-2m->|
%
% ===============================================================================
% NODE COORDINATES & LOADS:
% ===============================================================================
% Assuming Node 1 is at the origin (0,0) and the unit is meters:
%
%   Node 1 : ( 0, 0)   -> Pinned Support
%   Node 2 : ( 2, 3)   -> Applied Load: Fx = +20 kN
%   Node 3 : ( 7, 3)
%   Node 4 : ( 9, 0)   -> Pinned Support
%
%   Distributed Load : q = 5 kN/m downwards, acting on element 2-3.
%
% ===============================================================================
%
% Computes:
%   1. Element lengths and stiffness matrices
%   2. Global stiffness matrix K (12x12)
%   3. Reduced system and displacements
%   4. Reactions at all nodes
%   5. Element forces for each plane frame element
%   6. Axial, shear, and moment diagrams
% ===============================================================================

clear; clc;

E = 210e6

A = 1e-2

I = 9e-5

L1 = PlaneFrameElementLength(0,0,2,3)

L2 = 5

L3 = L1

theta1 = atan(3/2)*180/pi

theta2 = 0

theta3 = 360-theta1

k1 = PlaneFrameElementStiffness(E,A,I,L1,theta1)

k2 = PlaneFrameElementStiffness(E,A,I,L2,theta2)

k3 = PlaneFrameElementStiffness(E,A,I,L3,theta3)

K = zeros(12,12)

K = PlaneFrameAssemble(K,k1,1,2)

K = PlaneFrameAssemble(K,k2,2,3)

K = PlaneFrameAssemble(K,k3,3,4)

k = K(4:9,4:9)

f = [20 ; -12.5 ; -10.417 ; 0 ; -12.5 ; 10.417]

u = k\f

U = [0 ; 0 ; 0 ; u ; 0 ; 0 ; 0]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4) ; U(5) ; U(6)]

u2 = [U(4) ; U(5) ; U(6) ; U(7) ; U(8) ; U(9)]

u3 = [U(7) ; U(8) ; U(9) ; U(10) ; U(11) ; U(12)]

f1 = PlaneFrameElementForces(E,A,I,L1,theta1,u1)

f2 = PlaneFrameElementForces(E,A,I,L2,theta2,u2)

f3 = PlaneFrameElementForces(E,A,I,L3,theta3,u3)

f2 = f2 - [0 ; -12.5 ; -10.417 ; 0 ; -12.5 ; 10.417]

PlaneFrameElementAxialDiagram(f1,L1)
PlaneFrameElementAxialDiagram(f2,L2)
PlaneFrameElementAxialDiagram(f3,L3)
PlaneFrameElementShearDiagram(f1,L1)
PlaneFrameElementShearDiagram(f2,L2)
PlaneFrameElementShearDiagram(f3,L3)
PlaneFrameElementMomentDiagram(f1,L1)
PlaneFrameElementMomentDiagram(f2,L2)
PlaneFrameElementMomentDiagram(f3,L3)
