% Problem 16.1   Linear Brick Element (3D)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
% Units: kN, m, kPa
%
% Thin plate (0.5 m x 0.25 m x 0.025 m) cantilevered at the x = 0 face
% (nodes 1-4), subjected to axial (x-direction) nodal loads on the
% free-end face x = 0.5 (nodes 9-12).
% Discretized with TWO linear brick elements stacked along x.
%
% Material:  E = 210e6 kN/m^2, NU = 0.3
%
% Global nodes (3 DOF each, [Ux, Uy, Uz]):
%   Face x = 0:      1:(0,0,0.025)  2:(0,0,0)  3:(0,0.25,0)  4:(0,0.25,0.025)
%   Face x = 0.25:   5:(0.25,0,0.025)  6:(0.25,0,0)  7:(0.25,0.25,0)  8:(0.25,0.25,0.025)
%   Face x = 0.5:    9:(0.5,0,0.025)  10:(0.5,0,0)  11:(0.5,0.25,0)  12:(0.5,0.25,0.025)
%
% Element assembly (LinearBrickAssemble, local -> global node map):
%   k1 -> (1,2,3,4,5,6,7,8),  k2 -> (5,6,7,8,9,10,11,12)
%
% Loading (as printed in the Solutions Manual): 4.6875 kN at the reduced
% load-vector positions 13, 16, 19, 22 of the full 36-vector f.
%   NOTE: the book's f places these loads at component-major DOFs
%   v1, v4, v7, v10 (nodes 1, 4, 7, 10, y-direction) -- a known book bug;
%   the physically-correct loads are Fx = 4.6875 kN at nodes 9-12
%   (node-major DOFs 25, 28, 31, 34). See the port ADR.
%
% Constrained DOFs: 1:12 (nodes 1-4, x = 0 face).
%   Free DOFs: 13:36 (nodes 5-12) -> 24 free DOFs.
%
% NOTE: The reduced k = K(13:36,13:36) is SINGULAR (rank 23/24,
% RCOND ~ 1.5e-17): the book assembles component-major element matrices
% with node-major LinearBrickAssemble, so the global K is inconsistent and
% the reduced system is rank-deficient. The printed u (1.57e8 m) is
% garbage -- the Julia port computes the physically-correct solution.
%
% NOTE (Octave): LinearBrickElementStiffness uses symbolic integration
% (syms), so the 'symbolic' package must be loaded before calling it.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
warning('off', 'all');
format long g;
pkg load symbolic;

% Material
E = 210e6;
NU = 0.3;

% Element stiffness matrices (2 bricks, MATLAB local node order M1..M8)
k1 = LinearBrickElementStiffness(E, NU, 0,0,0.025, 0,0,0, 0,0.25,0, 0,0.25,0.025, 0.25,0,0.025, 0.25,0,0, 0.25,0.25,0, 0.25,0.25,0.025);
k2 = LinearBrickElementStiffness(E, NU, 0.25,0,0.025, 0.25,0,0, 0.25,0.25,0, 0.25,0.25,0.025, 0.5,0,0.025, 0.5,0,0, 0.5,0.25,0, 0.5,0.25,0.025);

% Assemble global stiffness matrix K (12 nodes x 3 DOF = 36x36)
K = zeros(36, 36);
K = LinearBrickAssemble(K, k1, 1, 2, 3, 4, 5, 6, 7, 8)
K = LinearBrickAssemble(K, k2, 5, 6, 7, 8, 9, 10, 11, 12)

% Partition K: free DOFs 13:36 (nodes 5-12)
k = K(13:36, 13:36)

% Load vector (axial forces at free-end face nodes 9-12)
f = [0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 4.6875; 0; 0; 4.6875; 0; 0; 4.6875; 0; 0; 4.6875; 0; 0]

% Solve for free displacements (near-singular system)
u = k\f
