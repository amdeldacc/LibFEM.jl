% =========================================================================
% Problem 7.2 - Beam with Distributed Load (Fig 7.16)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 7, beam element formulation.
%
% ===============================================================================
% PROBLEM OVERVIEW: BEAM WITH DISTRIBUTED LOAD (Fig 7.16)
% ===============================================================================
%
%            10 kN/m                                         30 kN
%            +--+--+--+--+--+--+                             |
%            |  |  |  |  |  |  |                             |
%            v  v  v  v  v  v  v                             v
%            1                 2                 3                       4
%        //|-O=================O=================O=======================O
%        //|                   o                 o                       o
%        //|                 -----             -----                   -----
%        //|                 /////             /////                   /////
%
%            |<----- 3 m ----->|<----- 3 m ----->|<-- 2 m -->|<-- 2 m -->|
%
% ===============================================================================
% NODE COORDINATES & LOADS:
% ===============================================================================
% Assuming Node 1 is at the origin (0,0) and the unit is meters:
%
%   Node 1 : ( 0, 0)   -> Fixed Support (Wall / Encastrement)
%   Node 2 : ( 3, 0)   -> Roller Support
%   Node 3 : ( 6, 0)   -> Roller Support
%   Node 4 : (10, 0)   -> Roller Support
%
%   Distributed Load : q = 10 kN/m downwards, acting from x = 0 m to x = 3 m.
%   Concentrated Load: P = 30 kN downwards, acting at x = 8 m.
%
% ===============================================================================

clear; clc;

E = 210e6

I = 50e-6

L1 = 3

L2 = 3

L3 = 4

k1 = BeamElementStiffness(E,I,L1)

k2 = BeamElementStiffness(E,I,L2)

k3 = BeamElementStiffness(E,I,L3)

K = zeros(8,8)

K = BeamAssemble(K,k1,1,2)

K = BeamAssemble(K,k2,2,3)

K = BeamAssemble(K,k3,3,4)

k = [K(4,4) K(4,6) K(4,8) ; K(6,4) K(6,6) K(6,8) ; K(8,4) K(8,6) K(8,8)]

f = [7.5 ; -15 ; 15]

u = k\f

U = [0 ; 0 ; 0 ; u(1) ; 0 ; u(2) ; 0 ; u(3)]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4)]

u2 = [U(3) ; U(4) ; U(5) ; U(6)]

u3 = [U(5) ; U(6) ; U(7) ; U(8)]

f1 = BeamElementForces(k1,u1)

f2 = BeamElementForces(k2,u2)

f3 = BeamElementForces(k3,u3)

f1 = f1-[-15 ; -7.5 ; -15 ; 7.5]

f3 = f3-[-15 ; -15 ; -15 ; 15]

BeamElementShearDiagram(f1,L1)
BeamElementShearDiagram(f2,L2)
BeamElementShearDiagram(f3,L3)
BeamElementMomentDiagram(f1,L1)
BeamElementMomentDiagram(f2,L2)
BeamElementMomentDiagram(f3,L3)
