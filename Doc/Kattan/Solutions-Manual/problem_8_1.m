% ===============================================================================
% PROBLEM OVERVIEW: PLANE FRAME WITH TWO ELEMENTS (Fig 8.21)
% ===============================================================================
%
%               15 kN.m
%                .---.
%              v '   |
%                    2                       3           20 kN
%          -         O=======================O----------->
%          ^         |                       o
%          |         |                     -----
%         4 m        |                     /////
%          |         |
%          |         |
%          v         1
%          -         O
%                  -----
%                  /////
%
%                    |<-------- 4 m -------->|
%
% ===============================================================================
% NODE COORDINATES & LOADS:
% ===============================================================================
% Assuming Node 1 is at the origin (0,0) and the unit is meters:
%
%   Node 1 : ( 0,  0)   -> Fixed Support
%   Node 2 : ( 0,  4)   -> Rigid Joint, Applied Moment: M = 15 kN.m (CCW)
%   Node 3 : ( 4,  4)   -> Roller Support, Applied Load: Fx = +20 kN
%
% ===============================================================================
%
% Computes:
%   1. Global stiffness matrix K (9x9)
%   2. Reduced system and displacements
%   3. Reactions at all nodes
%   4. Element forces for each plane frame element
%   5. Axial, shear, and moment diagrams
% ===============================================================================

clear; clc;

E = 210e6

A = 4e-2

I = 4e-6

L = 4

k1 = PlaneFrameElementStiffness(E,A,I,L,90)

k2 = PlaneFrameElementStiffness(E,A,I,L,0)

K = zeros(9,9)

K = PlaneFrameAssemble(K,k1,1,2)

K = PlaneFrameAssemble(K,k2,2,3)

k = [K(4:7,4:7) K(4:7,9) ; K(9,4:7) K(9,9)]

f = [0 ; 0 ; 15 ; 20 ; 0 ]

u = k\f

U = [0 ; 0 ; 0 ; u(1:4) ; 0 ; u(5)]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4) ; U(5) ; U(6)]

u2 = [U(4) ; U(5) ; U(6) ; U(7) ; U(8) ; U(9)]

f1 = PlaneFrameElementForces(E,A,I,L,90,u1)

f2 = PlaneFrameElementForces(E,A,I,L,0,u2)

PlaneFrameElementAxialDiagram(f1,L)
PlaneFrameElementAxialDiagram(f2,L)
PlaneFrameElementShearDiagram(f1,L)
PlaneFrameElementShearDiagram(f2,L)
PlaneFrameElementMomentDiagram(f1,L)
PlaneFrameElementMomentDiagram(f2,L)
