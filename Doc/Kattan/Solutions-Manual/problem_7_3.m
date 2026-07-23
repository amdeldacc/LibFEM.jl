% =========================================================================
% Problem 7.3 - Two-Span Beam with Spring Support (Fig. 7.6)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 7, beam element formulation.
% =========================================================================
%
%     Node 1 (fixed v,theta)   Node 2 (load -10 kN)   Node 3 (pinned v + spring)
%        O=========================O========================O
%               L1 = 3 m                    L2 = 3 m
%                                                         |
%                                                    spring k=5000 N/m
%                                                         |
%                                                      Node 7 (fixed)
%
%     E = 70e6 Pa, I = 40e-6 m^4
%     Load: -10 kN (vertical) applied at node 2
%     Spring: k = 5000 N/m between node 3 and ground (node 7)
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K (7x7)
%   2. Displacements/rotations at nodes 2 and 3
%   3. Reactions (shear and moment at each node)
%   4. Element forces for each beam element and spring
% =========================================================================

clear; clc;

E = 70e6

I = 40e-6

L1 = 3

L2 = 3

k_spring = 5000

k1 = BeamElementStiffness(E, I, L1)

k2 = BeamElementStiffness(E, I, L2)

k3 = SpringElementStiffness(k_spring)

K = zeros(7, 7)

K = BeamAssemble(K, k1, 1, 2)

K = BeamAssemble(K, k2, 2, 3)

K = SpringAssemble(K, k3, 3, 7)

% Reduced stiffness matrix for free DOFs:
%   DOF 3 = v2 (vertical displacement at node 2)
%   DOF 4 = theta2 (rotation at node 2)
%   DOF 6 = theta3 (rotation at node 3)
k = [K(3:4, 3:4) K(3:4, 6) ; K(6, 3:4) K(6, 6)]

% Load vector: -10 kN at node 2 (vertical)
f = [-10 ; 0 ; 0]

u = k \ f

% Full displacement vector
%   Node 1: U(1)=v1=0, U(2)=theta1=0
%   Node 2: U(3)=v2,   U(4)=theta2
%   Node 3: U(5)=v3=0, U(6)=theta3
%   Node 7: U(7)=v7=0  (spring ground)
U = [0 ; 0 ; u(1) ; u(2) ; 0 ; u(3) ; 0]

% Nodal reaction forces
F = K * U

% Element nodal displacements
u1 = [U(1) ; U(2) ; U(3) ; U(4)]   % Beam element 1 (nodes 1-2)
u2 = [U(3) ; U(4) ; U(5) ; U(6)]   % Beam element 2 (nodes 2-3)
u3 = [U(3) ; U(7)]                  % Spring element (nodes 3-7)

% Element forces
f1 = BeamElementForces(k1, u1)
f2 = BeamElementForces(k2, u2)
f3 = SpringElementForces(k3, u3)

% Shear force and bending moment diagrams
BeamElementShearDiagram(f1, L1)
BeamElementShearDiagram(f2, L2)
BeamElementMomentDiagram(f1, L1)
BeamElementMomentDiagram(f2, L2)
