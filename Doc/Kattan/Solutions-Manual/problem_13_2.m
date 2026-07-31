% Problem 13.2   Bilinear Quadrilateral Element (Q4)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
% Units: kN, m
%
% Thin plate with a central void, 0.9 m x 0.9 m, discretized with
% 8 bilinear quadrilateral elements (16 nodes). The center element of a
% 3x3 grid is missing (would be nodes 6, 7, 11, 10).
%
% Material:  E = 70e6 kN/m^2, NU = 0.25
% Thickness: h = 0.02 m, plane stress (p = 1)
%
% Nodes (bottom-up rows, 4 per row, spacing 0.3 m):
%   Row 1 (y = 0.0):   1:(0.0,0.0)   2:(0.3,0.0)   3:(0.6,0.0)   4:(0.9,0.0)
%   Row 2 (y = 0.3):   5:(0.0,0.3)   6:(0.3,0.3)   7:(0.6,0.3)   8:(0.9,0.3)
%   Row 3 (y = 0.6):   9:(0.0,0.6)  10:(0.3,0.6)  11:(0.6,0.6)  12:(0.9,0.6)
%   Row 4 (y = 0.9):  13:(0.0,0.9)  14:(0.3,0.9)  15:(0.6,0.9)  16:(0.9,0.9)
%
% Elements (CCW node order):
%   e1 (1,2,6,5)   e2 (2,3,7,6)   e3 (3,4,8,7)
%   e4 (5,6,10,9)                 e5 (7,8,12,11)
%   e6 (9,10,14,13) e7 (10,11,15,14) e8 (11,12,16,15)
%
% Boundary conditions: left column nodes 1, 5, 9, 13 fully fixed.
%   Constrained DOFs: 1:2, 9:10, 17:18, 25:26
%
% Loading: single downward point load Fy = -20 kN at node 16 (0.9, 0.9),
%   the top-right corner.
%   Free DOFs: [3:8; 11:16; 19:24; 27:32]  (24 free DOFs)
%   DOF order per node: [Ux, Uy]
%
% NOTE: BilinearQuadElementStiffness uses symbolic integration (syms s t)
% internally, so Octave needs: pkg load symbolic. Stresses are evaluated
% at the element centroid in natural coordinates (s, t) = (0, 0).

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
pkg load symbolic;
warning('off', 'all');

% Material and geometry
E = 70e6;
NU = 0.25;
h = 0.02;

% Stiffness matrices for the 8 elements (centroid coords are passed per
% element; node coordinates follow the element node order)
k1 = BilinearQuadElementStiffness(E, NU, h, 0, 0, 0.3, 0, 0.3, 0.3, 0, 0.3, 1);
k2 = BilinearQuadElementStiffness(E, NU, h, 0.3, 0, 0.6, 0, 0.6, 0.3, 0.3, 0.3, 1);
k3 = BilinearQuadElementStiffness(E, NU, h, 0.6, 0, 0.9, 0, 0.9, 0.3, 0.6, 0.3, 1);
k4 = BilinearQuadElementStiffness(E, NU, h, 0, 0.3, 0.3, 0.3, 0.3, 0.6, 0, 0.6, 1);
k5 = BilinearQuadElementStiffness(E, NU, h, 0.6, 0.3, 0.9, 0.3, 0.9, 0.6, 0.6, 0.6, 1);
k6 = BilinearQuadElementStiffness(E, NU, h, 0, 0.6, 0.3, 0.6, 0.3, 0.9, 0, 0.9, 1);
k7 = BilinearQuadElementStiffness(E, NU, h, 0.3, 0.6, 0.6, 0.6, 0.6, 0.9, 0.3, 0.9, 1);
k8 = BilinearQuadElementStiffness(E, NU, h, 0.6, 0.6, 0.9, 0.6, 0.9, 0.9, 0.6, 0.9, 1);

% Assemble global stiffness matrix K (16 nodes x 2 DOF = 32x32)
K = zeros(32, 32);
K = BilinearQuadAssemble(K, k1, 1, 2, 6, 5);
K = BilinearQuadAssemble(K, k2, 2, 3, 7, 6);
K = BilinearQuadAssemble(K, k3, 3, 4, 8, 7);
K = BilinearQuadAssemble(K, k4, 5, 6, 10, 9);
K = BilinearQuadAssemble(K, k5, 7, 8, 12, 11);
K = BilinearQuadAssemble(K, k6, 9, 10, 14, 13);
K = BilinearQuadAssemble(K, k7, 10, 11, 15, 14);
K = BilinearQuadAssemble(K, k8, 11, 12, 16, 15);

% Partition K: free DOFs [3:8; 11:16; 19:24; 27:32]
k = [K(3:8,3:8) K(3:8,11:16) K(3:8,19:24) K(3:8,27:32) ;
     K(11:16,3:8) K(11:16,11:16) K(11:16,19:24) K(11:16,27:32) ;
     K(19:24,3:8) K(19:24,11:16) K(19:24,19:24) K(19:24,27:32) ;
     K(27:32,3:8) K(27:32,11:16) K(27:32,19:24) K(27:32,27:32)];

% Load vector: -20 kN at node 16, DOF 32 (uy, the 24th free DOF)
f = [zeros(22, 1); 0; -20];

% Solve for free displacements
u = k\f

% Expand to full displacement vector U (32 DOFs)
U = [0; 0; u(1:6); 0; 0; u(7:12); 0; 0; u(13:18); 0; 0; u(19:24)]

% Compute reactions
F = K*U

% Element nodal displacements (local, element node order)
u1 = [U(1); U(2); U(3); U(4); U(11); U(12); U(9); U(10)];
u2 = [U(3); U(4); U(5); U(6); U(13); U(14); U(11); U(12)];
u3 = [U(5); U(6); U(7); U(8); U(15); U(16); U(13); U(14)];
u4 = [U(9); U(10); U(11); U(12); U(19); U(20); U(17); U(18)];
u5 = [U(13); U(14); U(15); U(16); U(23); U(24); U(21); U(22)];
u6 = [U(17); U(18); U(19); U(20); U(27); U(28); U(25); U(26)];
u7 = [U(19); U(20); U(21); U(22); U(29); U(30); U(27); U(28)];
u8 = [U(21); U(22); U(23); U(24); U(31); U(32); U(29); U(30)];

% Stresses at element centroids: sigma = [sigma_xx, sigma_yy, tau_xy]
sigma1 = BilinearQuadElementStresses(E, NU, 0, 0, 0.3, 0, 0.3, 0.3, 0, 0.3, 1, u1)
sigma2 = BilinearQuadElementStresses(E, NU, 0.3, 0, 0.6, 0, 0.6, 0.3, 0.3, 0.3, 1, u2)
sigma3 = BilinearQuadElementStresses(E, NU, 0.6, 0, 0.9, 0, 0.9, 0.3, 0.6, 0.3, 1, u3)
sigma4 = BilinearQuadElementStresses(E, NU, 0, 0.3, 0.3, 0.3, 0.3, 0.6, 0, 0.6, 1, u4)
sigma5 = BilinearQuadElementStresses(E, NU, 0.6, 0.3, 0.9, 0.3, 0.9, 0.6, 0.6, 0.6, 1, u5)
sigma6 = BilinearQuadElementStresses(E, NU, 0, 0.6, 0.3, 0.6, 0.3, 0.9, 0, 0.9, 1, u6)
sigma7 = BilinearQuadElementStresses(E, NU, 0.3, 0.6, 0.6, 0.6, 0.6, 0.9, 0.3, 0.9, 1, u7)
sigma8 = BilinearQuadElementStresses(E, NU, 0.6, 0.6, 0.9, 0.6, 0.9, 0.9, 0.6, 0.9, 1, u8)

% Principal stresses: s = [sigma_1, sigma_2, theta (degrees)]
s1 = BilinearQuadElementPStresses(sigma1)
s2 = BilinearQuadElementPStresses(sigma2)
s3 = BilinearQuadElementPStresses(sigma3)
s4 = BilinearQuadElementPStresses(sigma4)
s5 = BilinearQuadElementPStresses(sigma5)
s6 = BilinearQuadElementPStresses(sigma6)
s7 = BilinearQuadElementPStresses(sigma7)
s8 = BilinearQuadElementPStresses(sigma8)
