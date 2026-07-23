% =========================================================================
% PROBLEM 7.3 - BEAM WITH A SPRING (Fig 7.17)
% Reference: P. I. Kattan, "MATLAB Guide to Finite Elements: An Interactive
% Approach" - Chapter 7, beam element formulation.
% =========================================================================
%
%                                  10 kN
%                                    |
%                                    v
%             1        E, I         2        E, I         3
%         //|-O======================O======================O
%         //|                        |                      o
%         //|                       /                     -----
%         //|                       \                     /////
%         //|                       /
%                                   \
%                                   |
%                                   O 4
%                                 -----
%                                 /////
%
%             |<------ 3 m ------->|<------ 3 m ------->|
%
% =========================================================================
% PROPERTIES:
% =========================================================================
%   E = 70 GPa  (= 70e6 kN/m^2)
%   I = 40e-6 m^4
%   k = 5000 kN/m   (spring stiffness)
%   Load: Py = -10 kN at node 2
%
% =========================================================================
% NODE NUMBERING (BEAM: 2 DOF/node: v, theta; SPRING: 1 DOF/node):
% =========================================================================
%   Physical node    Beam node     DOFs         Description
%   -------------   ---------     ----         -----------
%        1              1         1,2          Fixed support (v1=0, t1=0)
%        2              2         3,4          Free (v2, t2) + spring + load
%        3              3         5,6          Roller (v3=0, t3 free)
%        4            (none)       7           Spring ground (fixed)
%
%   NOTE: SpringAssemble uses 1-DOF/node indexing, so the spring
%   connects node "3" (= DOF 3 = v2) to node "7" (= spring ground).
%   This avoids conflicting with beam DOF numbering (2 DOF/node).
%
% =========================================================================
%
% Computes:
%   1. Global stiffness matrix K (7x7)
%   2. Rotations at nodes 2 and 3
%   3. Reactions at nodes 1, 3, and 4 (spring ground)
%   4. Element forces (shear and moment) in each beam element
%   5. Force in the spring element
%   6. Shear force and bending moment diagrams
% =========================================================================

clear; clc;

E = 70e6      % 70 GPa = 70e6 kN/m^2

I = 40e-6     % m^4

L1 = 3        % m

L2 = 3        % m

k_spring = 5000   % kN/m

k1 = BeamElementStiffness(E, I, L1)

k2 = BeamElementStiffness(E, I, L2)

k3 = SpringElementStiffness(k_spring)

K = zeros(7, 7)

K = BeamAssemble(K, k1, 1, 2)

K = BeamAssemble(K, k2, 2, 3)

K = SpringAssemble(K, k3, 3, 7)
%   SpringAssemble maps: node i -> DOF i.  Here "node 3" = DOF 3 = v2,
%   "node 7" = spring ground (physical node 4).

% Reduced stiffness matrix for free DOFs:
%   DOF 3 = v2 (vertical displacement at physical node 2)
%   DOF 4 = theta2 (rotation at physical node 2)
%   DOF 6 = theta3 (rotation at physical node 3)
k = [K(3:4, 3:4) K(3:4, 6) ; K(6, 3:4) K(6, 6)]

% Load vector: -10 kN at physical node 2 (vertical)
f = [-10 ; 0 ; 0]

u = k \ f

% Full displacement vector (DOF numbering)
%   Physical node 1: U(1)=v1=0,   U(2)=theta1=0     (fixed)
%   Physical node 2: U(3)=v2,     U(4)=theta2        (free + spring)
%   Physical node 3: U(5)=v3=0,   U(6)=theta3        (roller)
%   Physical node 4: U(7)=spring ground = 0          (fixed)
U = [0 ; 0 ; u(1) ; u(2) ; 0 ; u(3) ; 0]

% Nodal reaction forces
F = K * U

% Element nodal displacements
u1 = [U(1) ; U(2) ; U(3) ; U(4)]   % Beam element 1 (phys nodes 1-2)
u2 = [U(3) ; U(4) ; U(5) ; U(6)]   % Beam element 2 (phys nodes 2-3)
u3 = [U(3) ; U(7)]                  % Spring element (phys nodes 2-4)

% Element forces
f1 = BeamElementForces(k1, u1)
f2 = BeamElementForces(k2, u2)
f3 = SpringElementForces(k3, u3)

% Shear force and bending moment diagrams
BeamElementShearDiagram(f1, L1)
BeamElementShearDiagram(f2, L2)
BeamElementMomentDiagram(f1, L1)
BeamElementMomentDiagram(f2, L2)
