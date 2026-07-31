% Problem 13.3   Bilinear Quadrilateral Element (Q4) + Spring Elements
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
% Units: kN, m
%
% Plate (0.7 m x 0.4 m) supported by three linear springs (k = 4000 kN/m)
% and subjected to vertical upward loads at the top edge nodes.
% Discretized with 2 bilinear quadrilateral elements (6 nodes) plus
% 3 spring elements to fixed ground.
%
% Material:  E = 200e6 kN/m^2, NU = 0.3
% Thickness: h = 0.01 m, plane stress (p = 1)
%
% Nodes (2 DOF each, [Ux, Uy]):
%   Top row    (y = 0.4):  1:(0.0,0.4)  2:(0.35,0.4)  3:(0.7,0.4)
%   Bottom row (y = 0.0):  4:(0.0,0.0)  5:(0.35,0.0)  6:(0.7,0.0)
%
% Elements (CCW node order):
%   e1 (4,5,2,1)  e2 (5,6,3,2)
%   Spring elements to ground: (DOF 8 <-> 13), (DOF 10 <-> 14), (DOF 12 <-> 15)
%   i.e. bottom nodes 4, 5, 6 supported vertically by springs k = 4000.
%
% Loading: vertical upward forces at top nodes:
%   Fy = 8.75 kN at node 1 (DOF 2), Fy = 17.5 kN at node 2 (DOF 4),
%   Fy = 8.75 kN at node 3 (DOF 6).
%
% Constrained DOFs: 13, 14, 15 (spring ground ends, fixed).
%   Free DOFs: 1:12 (12 free DOFs)
%
% NOTE: BilinearQuadElementStiffness uses symbolic integration (syms s t)
% internally, so Octave needs: pkg load symbolic. Stresses are evaluated
% at the element centroid in natural coordinates (s, t) = (0, 0).

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
pkg load symbolic;
warning('off', 'all');
format long g;

% Material and geometry
E = 200e6;
NU = 0.3;
h = 0.01;

% Stiffness matrices for the 2 Q4 elements (node coords follow element order)
k1 = BilinearQuadElementStiffness(E, NU, h, 0, 0, 0.35, 0, 0.35, 0.4, 0, 0.4, 1);
k2 = BilinearQuadElementStiffness(E, NU, h, 0.35, 0, 0.7, 0, 0.7, 0.4, 0.35, 0.4, 1);

% Stiffness matrices for the 3 springs (k = 4000 kN/m)
k3 = SpringElementStiffness(4000);
k4 = SpringElementStiffness(4000);
k5 = SpringElementStiffness(4000);

% Assemble global stiffness matrix K (6 plate nodes x 2 DOF + 3 ground DOFs
% = 15x15). SpringAssemble works directly on DOF indices.
K = zeros(15, 15);
K = BilinearQuadAssemble(K, k1, 4, 5, 2, 1);
K = BilinearQuadAssemble(K, k2, 5, 6, 3, 2);
K = SpringAssemble(K, k3, 8, 13);
K = SpringAssemble(K, k4, 10, 14);
K = SpringAssemble(K, k5, 12, 15);

% Partition K: free DOFs 1:12 (ground DOFs 13-15 are fixed)
k = K(1:12, 1:12);

% Load vector (upward vertical forces at top nodes)
f = [0; 8.75; 0; 17.5; 0; 8.75; 0; 0; 0; 0; 0; 0];

% Solve for free displacements
u = k\f

% Expand to full displacement vector U (15 DOFs; ground ends fixed)
U = [u(1:12); 0; 0; 0]

% Compute reactions / nodal forces
F = K*U

% Element nodal displacements (local, element node order)
u1 = [U(7); U(8); U(9); U(10); U(3); U(4); U(1); U(2)];
u2 = [U(9); U(10); U(11); U(12); U(5); U(6); U(3); U(4)];

% Spring element nodal displacements (plate DOF, ground DOF)
u3 = [U(8); U(13)];
u4 = [U(10); U(14)];
u5 = [U(12); U(15)];

% Stresses at element centroids: sigma = [sigma_xx, sigma_yy, tau_xy]
sigma1 = BilinearQuadElementStresses(E, NU, 0, 0, 0.35, 0, 0.35, 0.4, 0, 0.4, 1, u1)
sigma2 = BilinearQuadElementStresses(E, NU, 0.35, 0, 0.7, 0, 0.7, 0.4, 0.35, 0.4, 1, u2)

% Principal stresses: s = [sigma_1, sigma_2, theta (degrees)]
s1 = BilinearQuadElementPStresses(sigma1)
s2 = BilinearQuadElementPStresses(sigma2)

% Spring element forces (k * u)
f3 = SpringElementForces(k3, u3)
f4 = SpringElementForces(k4, u4)
f5 = SpringElementForces(k5, u5)
