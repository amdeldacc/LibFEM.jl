% Problem 15.1   Linear Tetrahedron Element (3D)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
% Units: kN, m, kPa
%
% 3D block (0.025 m x 0.5 m x 0.25 m) fixed at the bottom-front corners
% (nodes 1, 2) and the bottom-back corner (node 5), subjected to upward
% nodal loads on the top face nodes.
% Discretized with SIX linear tetrahedron elements.
%
% Material:  E = 210e6 kN/m^2, NU = 0.3
%
% Global nodes (3 DOF each, [Ux, Uy, Uz]):
%   Bottom-front  (y = 0):  1:(0,0,0)             2:(0.025,0,0)
%   Bottom-back   (y = 0):  5:(0,0,0.25)          6:(0.025,0,0.25)
%   Top-front     (y = 0.5): 3:(0,0.5,0)          4:(0.025,0.5,0)
%   Top-back      (y = 0.5): 7:(0,0.5,0.25)       8:(0.025,0.5,0.25)
%
% Element assembly (TetrahedronAssemble, local -> global node map):
%   k1 -> (1,2,4,8),  k2 -> (1,2,8,5),  k3 -> (2,8,5,6),
%   k4 -> (1,3,7,4),  k5 -> (1,7,5,8),  k6 -> (1,8,4,7)
%
% Loading: upward vertical forces at the top face nodes (total 18.75 kN):
%   Fy = 3.125 kN at node 3 (DOF 8), Fy = 6.25 kN at node 4 (DOF 11),
%   Fy = 6.25 kN at node 7 (DOF 20), Fy = 3.125 kN at node 8 (DOF 23).
%
% Constrained DOFs: 1:6 (nodes 1, 2) and 13:18 (nodes 5, 6).
%   Free DOFs: 7:12 (nodes 3, 4) and 19:24 (nodes 7, 8) -> 12 free DOFs.
%
% Stresses are constant within each element (linear tetrahedron).
% TetrahedronElementPStresses returns the stress invariants
%   s = [sigma_xx+sigma_yy+sigma_zz ;
%        sigma_xx*sigma_yy + ... - tau_xy^2 - tau_yz^2 - tau_zx^2 ;
%        det(sigma_matrix)].

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
warning('off', 'all');
format long g;

% Material
E = 210e6;
NU = 0.3;

% Element stiffness matrices (6 tetrahedra)
k1 = TetrahedronElementStiffness(E, NU, 0, 0, 0, 0.025, 0, 0, 0.025, 0.5, 0, 0.025, 0.5, 0.25);
k2 = TetrahedronElementStiffness(E, NU, 0, 0, 0, 0.025, 0, 0, 0.025, 0.5, 0.25, 0, 0, 0.25);
k3 = TetrahedronElementStiffness(E, NU, 0.025, 0, 0, 0.025, 0.5, 0.25, 0, 0, 0.25, 0.025, 0, 0.25);
k4 = TetrahedronElementStiffness(E, NU, 0, 0, 0, 0, 0.5, 0, 0, 0.5, 0.25, 0.025, 0.5, 0);
k5 = TetrahedronElementStiffness(E, NU, 0, 0, 0, 0, 0.5, 0.25, 0, 0, 0.25, 0.025, 0.5, 0.25);
k6 = TetrahedronElementStiffness(E, NU, 0, 0, 0, 0.025, 0.5, 0.25, 0.025, 0.5, 0, 0, 0.5, 0.25);

% Assemble global stiffness matrix K (8 nodes x 3 DOF = 24x24)
K = zeros(24, 24);
K = TetrahedronAssemble(K, k1, 1, 2, 4, 8);
K = TetrahedronAssemble(K, k2, 1, 2, 8, 5);
K = TetrahedronAssemble(K, k3, 2, 8, 5, 6);
K = TetrahedronAssemble(K, k4, 1, 3, 7, 4);
K = TetrahedronAssemble(K, k5, 1, 7, 5, 8);
K = TetrahedronAssemble(K, k6, 1, 8, 4, 7);

% Partition K: free DOFs 7:12 (nodes 3,4) and 19:24 (nodes 7,8)
k = [K(7:12, 7:12) K(7:12, 19:24); K(19:24, 7:12) K(19:24, 19:24)];

% Load vector (upward vertical forces at top face nodes)
f = [0; 3.125; 0; 0; 6.25; 0; 0; 6.25; 0; 0; 3.125; 0];

% Solve for free displacements
u = k\f

% Expand to full displacement vector U (24 DOFs; constrained ends fixed)
U = [0; 0; 0; 0; 0; 0; u(1:6); 0; 0; 0; 0; 0; 0; u(7:12)]

% Compute reactions / nodal forces
F = K*U

% Element nodal displacements (local, element node order)
u1 = [U(1); U(2); U(3); U(4); U(5); U(6); U(10); U(11); U(12); U(22); U(23); U(24)];
u2 = [U(1); U(2); U(3); U(4); U(5); U(6); U(22); U(23); U(24); U(13); U(14); U(15)];
u3 = [U(4); U(5); U(6); U(22); U(23); U(24); U(13); U(14); U(15); U(16); U(17); U(18)];
u4 = [U(1); U(2); U(3); U(7); U(8); U(9); U(19); U(20); U(21); U(10); U(11); U(12)];
u5 = [U(1); U(2); U(3); U(19); U(20); U(21); U(13); U(14); U(15); U(22); U(23); U(24)];
u6 = [U(1); U(2); U(3); U(22); U(23); U(24); U(10); U(11); U(12); U(19); U(20); U(21)];

% Element stresses: sigma = [sigma_xx, sigma_yy, sigma_zz, tau_xy, tau_yz, tau_zx]
sigma1 = TetrahedronElementStresses(E, NU, 0, 0, 0, 0.025, 0, 0, 0.025, 0.5, 0, 0.025, 0.5, 0.25, u1)
sigma2 = TetrahedronElementStresses(E, NU, 0, 0, 0, 0.025, 0, 0, 0.025, 0.5, 0.25, 0, 0, 0.25, u2)
sigma3 = TetrahedronElementStresses(E, NU, 0.025, 0, 0, 0.025, 0.5, 0.25, 0, 0, 0.25, 0.025, 0, 0.25, u3)
sigma4 = TetrahedronElementStresses(E, NU, 0, 0, 0, 0, 0.5, 0, 0, 0.5, 0.25, 0.025, 0.5, 0, u4)
sigma5 = TetrahedronElementStresses(E, NU, 0, 0, 0, 0, 0.5, 0.25, 0, 0, 0.25, 0.025, 0.5, 0.25, u5)
sigma6 = TetrahedronElementStresses(E, NU, 0, 0, 0, 0.025, 0.5, 0.25, 0.025, 0.5, 0, 0, 0.5, 0.25, u6)

% Stress invariants: s = [trace; sum of principal minors; determinant]
s1 = TetrahedronElementPStresses(sigma1)
s2 = TetrahedronElementPStresses(sigma2)
s3 = TetrahedronElementPStresses(sigma3)
s4 = TetrahedronElementPStresses(sigma4)
s5 = TetrahedronElementPStresses(sigma5)
s6 = TetrahedronElementPStresses(sigma6)
