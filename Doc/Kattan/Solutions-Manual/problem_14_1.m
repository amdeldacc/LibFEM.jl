% Problem 14.1   Quadratic Quadrilateral Element (Q8) + Spring Elements
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
% Units: kN, m
%
% Thin plate (0.7 m x 0.4 m) supported by three linear springs (k = 4000 kN/m)
% and subjected to vertical upward loads at the top edge nodes.
% Discretized with ONE quadratic quadrilateral (Q8) element plus 3 spring
% elements to fixed ground.
%
% Material:  E = 200e6 kN/m^2, NU = 0.3
% Thickness: h = 0.01 m, plane stress (p = 1)
%
% Q8 element: 4 corner nodes + 4 mid-side nodes (mid-side nodes are computed
% internally by QuadraticQuadElementStiffness as averages of adjacent corners).
% Global nodes (2 DOF each, [Ux, Uy]):
%   Top row        (y = 0.4):  1:(0.0,0.4)  2:(0.35,0.4)  3:(0.7,0.4)
%   Mid row        (y = 0.2):  4:(0.0,0.2)                5:(0.7,0.2)
%   Bottom row     (y = 0.0):  6:(0.0,0.0)  7:(0.35,0.0)  8:(0.7,0.0)
%
% Element assembly (local -> global node map from the manual):
%   local 1 (0,0)   -> global 6   (BL corner)
%   local 2 (0.7,0) -> global 8   (BR corner)
%   local 3 (0.7,0.4)-> global 3  (TR corner)
%   local 4 (0,0.4) -> global 1   (TL corner)
%   local 5 (0.35,0)  -> global 7 (BM mid-side)
%   local 6 (0.7,0.2) -> global 5 (RM mid-side)
%   local 7 (0.35,0.4) -> global 2 (TM mid-side)
%   local 8 (0,0.2) -> global 4   (LM mid-side)
%
% Spring elements to ground: (DOF 12 <-> 17), (DOF 14 <-> 18), (DOF 16 <-> 19)
%   i.e. bottom nodes 6, 7, 8 supported vertically by springs k = 4000.
%
% Loading: vertical upward forces at top nodes (Q8 consistent nodal loads for
% a uniform edge load, total 35 kN):
%   Fy = 5.8333 kN at node 1 (DOF 2), Fy = 23.3333 kN at node 2 (DOF 4),
%   Fy = 5.8333 kN at node 3 (DOF 6).
%
% Constrained DOFs: 17, 18, 19 (spring ground ends, fixed).
%   Free DOFs: 1:16 (16 free DOFs)
%
% NOTE: QuadraticQuadElementStiffness uses symbolic integration (syms s t)
% internally, so Octave needs: pkg load symbolic. Stresses are evaluated
% at the element centroid in natural coordinates (s, t) = (0, 0).
%
% NOTE ON SINGULARITY: the reduced 16x16 stiffness matrix is singular
% (RCOND ~ 1.3e-17) because the plate rests only on vertical springs
% (rigid x-translation is a zero-energy mode). Only uy, ux differences,
% reactions, stresses, and spring forces are physically unique.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
pkg load symbolic;
warning('off', 'all');
format long g;

% Material and geometry
E = 200e6;
NU = 0.3;
h = 0.01;

% Stiffness matrix for the single Q8 element.
% The MATLAB function takes ONLY the 4 corner coordinates; the 4 mid-side
% nodes (x5..x8, y5..y8) are computed internally as adjacent-corner averages.
k1 = QuadraticQuadElementStiffness(E, NU, h, 0, 0, 0.7, 0, 0.7, 0.4, 0, 0.4, 1);

% Stiffness matrices for the 3 springs (k = 4000 kN/m)
k2 = SpringElementStiffness(4000);
k3 = SpringElementStiffness(4000);
k4 = SpringElementStiffness(4000);

% Assemble global stiffness matrix K (8 plate nodes x 2 DOF + 3 ground DOFs
% = 19x19). SpringAssemble works directly on DOF indices.
K = zeros(19, 19);
K = QuadraticQuadAssemble(K, k1, 6, 8, 3, 1, 7, 5, 2, 4);
K = SpringAssemble(K, k2, 12, 17);
K = SpringAssemble(K, k3, 14, 18);
K = SpringAssemble(K, k4, 16, 19);

% Partition K: free DOFs 1:16 (ground DOFs 17-19 are fixed)
k = K(1:16, 1:16);

% Load vector (upward vertical forces at top nodes)
f = [0; 5.8333; 0; 23.3333; 0; 5.8333; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0];

% Solve for free displacements (singular x-mode: ux is solver-dependent)
u = k\f

% Expand to full displacement vector U (19 DOFs; ground ends fixed)
U = [u(1:16); 0; 0; 0]

% Compute reactions / nodal forces
F = K*U

% Element nodal displacements (local, element node order)
u1 = [U(11); U(12); U(15); U(16); U(5); U(6); U(1); U(2); U(13); U(14); U(9); U(10); U(3); U(4); U(7); U(8)];

% Spring element nodal displacements (plate DOF, ground DOF)
u2 = [U(12); U(17)];
u3 = [U(14); U(18)];
u4 = [U(16); U(19)];

% Stress at element centroid: sigma = [sigma_xx, sigma_yy, tau_xy]
sigma1 = QuadraticQuadElementStresses(E, NU, 0, 0, 0.7, 0, 0.7, 0.4, 0, 0.4, 1, u1)

% Principal stresses: s = [sigma_1, sigma_2, theta (degrees)]
s1 = QuadraticQuadElementPStresses(sigma1)

% Spring element forces (k * u)
f2 = SpringElementForces(k2, u2)
f3 = SpringElementForces(k3, u3)
f4 = SpringElementForces(k4, u4)
