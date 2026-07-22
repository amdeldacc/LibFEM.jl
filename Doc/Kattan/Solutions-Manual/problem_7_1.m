% =========================================================================
% Problem 7.1 - Two-Span Beam with Three Supports (Fig. 7.5)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 7, beam element formulation.
% =========================================================================
%
%     Node 1 (fixed v)   Node 2 (fixed v, -15 kN-m)   Node 3 (fixed v)
%        O====================O============================O
%               L1 = 3.5 m               L2 = 2 m
%
%     E = 200 GPa, I = 70e-5 m^4
%     Load: -15 kN-m applied at node 2 (rotation DOF)
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K
%   2. Rotations at nodes 1, 2, and 3
%   3. Reactions (shear and moment at each node)
%   4. Element forces for each beam element
% =========================================================================

clear; clc;

E = 200e6

I = 70e-5

L1 = 3.5

L2 = 2

k1 = BeamElementStiffness(E,I,L1)

k2 = BeamElementStiffness(E,I,L2)

K = zeros(6,6)

K = BeamAssemble(K,k1,1,2)

K = BeamAssemble(K,k2,2,3)

k = [K(2,2) K(2,4) K(2,6) ; K(4,2) K(4,4) K(4,6) ; K(6,2) K(6,4) K(6,6)]

f = [0 ; -15 ; 0]

u = k\f

U = [0 ; u(1) ; 0 ; u(2) ; 0 ; u(3)]

F = K*U

u1 = [U(1) ; U(2) ; U(3) ; U(4)]

u2 = [U(3) ; U(4) ; U(5) ; U(6)]

f1 = BeamElementForces(k1,u1)

f2 = BeamElementForces(k2,u2)

BeamElementShearDiagram(f1,L1)
BeamElementShearDiagram(f2,L2)
BeamElementMomentDiagram(f1,L1)
BeamElementMomentDiagram(f2,L2)
