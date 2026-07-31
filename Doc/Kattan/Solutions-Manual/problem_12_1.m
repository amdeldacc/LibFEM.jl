% Problem 12.1   Quadratic Triangular Element (LST)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=210e6 kPa, NU=0.3, t=0.025 m, Plane Stress (p=1)
% 13 nodes, 4 LST elements (2x1 grid of quadratic triangles)
% Nodes: 1=(0,0), 2=(0.25,0), 3=(0.5,0), 4=(0.125,0.0625), 5=(0.375,0.0625),
%        6=(0,0.125), 7=(0.25,0.125), 8=(0.5,0.125), 9=(0.125,0.1875),
%        10=(0.375,0.1875), 11=(0,0.25), 12=(0.25,0.25), 13=(0.5,0.25)
% Elements (corner nodes then midside nodes):
%   e1: 1,7,11 / 4,9,6     e2: 1,3,7 / 2,5,4
%   e3: 7,13,11 / 10,12,9  e4: 7,3,13 / 5,8,10
% Left edge fixed (nodes 1, 6, 11): U(1)=U(2)=U(11)=U(12)=U(21)=U(22)=0
% Loads (+x): 3.125 kN @ node 3, 12.5 kN @ node 8, 3.125 kN @ node 13
%   (uniform 75 kN/m on right edge x=0.5; 1/6:2/3:1/6 quadratic distribution)
% DOF order per node: [Ux, Uy]
% NOTE: QuadTriangleElementStiffness/Stresses use syms internally, so the
%       Octave symbolic package must be loaded; stresses are evaluated at
%       the element centroid.

% --- Octave bootstrap: Kattan M-Files + symbolic package ------------------
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
pkg load symbolic;
warning('off', 'all');

E=210e6;
NU=0.3;
t=0.025;
k1=QuadTriangleElementStiffness(E,NU,t,0,0,0.25,0.125,0,0.25,1);
k2=QuadTriangleElementStiffness(E,NU,t,0,0,0.5,0,0.25,0.125,1);
k3=QuadTriangleElementStiffness(E,NU,t,0.25,0.125,0.5,0.25,0,0.25,1);
k4=QuadTriangleElementStiffness(E,NU,t,0.25,0.125,0.5,0,0.5,0.25,1);
K=zeros(26,26);
K=QuadTriangleAssemble(K,k1,1,7,11,4,9,6);
K=QuadTriangleAssemble(K,k2,1,3,7,2,5,4);
K=QuadTriangleAssemble(K,k3,7,13,11,10,12,9);
K=QuadTriangleAssemble(K,k4,7,3,13,5,8,10);
k=[K(3:10,3:10) K(3:10,13:20) K(3:10,23:26) ; K(13:20,3:10) K(13:20,13:20) K(13:20,23:26) ; K(23:26,3:10) K(23:26,13:20) K(23:26,23:26)];
f=[0 ; 0 ; 3.125 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 12.5 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 3.125 ; 0];
u=k\f
U=[0 ; 0 ; u(1:8) ; 0 ; 0 ; u(9:16) ; 0 ; 0 ; u(17:20)]
F=K*U
u1=[U(1) ; U(2) ; U(13) ; U(14) ; U(21) ; U(22) ; U(7) ; U(8) ; U(17) ; U(18) ; U(11) ; U(12)];
u2=[U(1) ; U(2) ; U(5) ; U(6) ; U(13) ; U(14) ; U(3) ; U(4) ; U(9) ; U(10) ; U(7) ; U(8)];
u3=[U(13) ; U(14) ; U(25) ; U(26) ; U(21) ; U(22) ; U(19) ; U(20) ; U(23) ; U(24) ; U(17) ; U(18)];
u4=[U(13) ; U(14) ; U(5) ; U(6) ; U(25) ; U(26) ; U(9) ; U(10) ; U(15) ; U(16) ; U(19) ; U(20)];
sigma1=QuadTriangleElementStresses(E,NU,t,0,0,0.25,0.125,0,0.25,1,u1)
sigma2=QuadTriangleElementStresses(E,NU,t,0,0,0.5,0,0.25,0.125,1,u2)
sigma3=QuadTriangleElementStresses(E,NU,t,0.25,0.125,0.5,0.25,0,0.25,1,u3)
sigma4=QuadTriangleElementStresses(E,NU,t,0.25,0.125,0.5,0,0.5,0.25,1,u4)
s1=QuadTriangleElementPStresses(sigma1)
s2=QuadTriangleElementPStresses(sigma2)
s3=QuadTriangleElementPStresses(sigma3)
s4=QuadTriangleElementPStresses(sigma4)
