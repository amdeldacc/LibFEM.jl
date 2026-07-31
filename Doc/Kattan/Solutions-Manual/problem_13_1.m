% Problem 13.1   Bilinear Quadrilateral Element (Q4)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=210e6 kPa, NU=0.3, h=0.025 m, Plane Stress (p=1)
% 15 nodes, 8 Q4 elements (4x2 grid of 0.125x0.125 bilinear quads)
% Nodes: 1=(0,0), 2=(0.125,0), 3=(0.25,0), 4=(0.375,0), 5=(0.5,0),
%        6=(0,0.125), 7=(0.125,0.125), 8=(0.25,0.125), 9=(0.375,0.125),
%        10=(0.5,0.125), 11=(0,0.25), 12=(0.125,0.25), 13=(0.25,0.25),
%        14=(0.375,0.25), 15=(0.5,0.25)
% Elements (CCW, bottom-left first):
%   e1: 1,2,7,6   e2: 2,3,8,7   e3: 3,4,9,8   e4: 4,5,10,9
%   e5: 6,7,12,11 e6: 7,8,13,12 e7: 8,9,14,13 e8: 9,10,15,14
% Left edge fixed (nodes 1, 6, 11): U(1)=U(2)=U(11)=U(12)=U(21)=U(22)=0
% Loads (+x): 4.6875 kN @ node 5, 9.375 kN @ node 10, 4.6875 kN @ node 15
%   (uniform traction on right edge x=0.5; 1:2:1 split)
% DOF order per node: [Ux, Uy]
% NOTE: BilinearQuadElementStiffness/Stresses use syms internally, so the
%       Octave symbolic package must be loaded; stresses are evaluated at
%       the element centroid.

% --- Octave bootstrap: Kattan M-Files + symbolic package ------------------
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'M-Files'));
pkg load symbolic;
warning('off', 'all');

E=210e6;
NU=0.3;
h=0.025;
k1=BilinearQuadElementStiffness(E,NU,h,0,0,0.125,0,0.125,0.125,0,0.125,1);
k2=BilinearQuadElementStiffness(E,NU,h,0.125,0,0.25,0,0.25,0.125,0.125,0.125,1);
k3=BilinearQuadElementStiffness(E,NU,h,0.25,0,0.375,0,0.375,0.125,0.25,0.125,1);
k4=BilinearQuadElementStiffness(E,NU,h,0.375,0,0.5,0,0.5,0.125,0.375,0.125,1);
k5=BilinearQuadElementStiffness(E,NU,h,0,0.125,0.125,0.125,0.125,0.25,0,0.25,1);
k6=BilinearQuadElementStiffness(E,NU,h,0.125,0.125,0.25,0.125,0.25,0.25,0.125,0.25,1);
k7=BilinearQuadElementStiffness(E,NU,h,0.25,0.125,0.375,0.125,0.375,0.25,0.25,0.25,1);
k8=BilinearQuadElementStiffness(E,NU,h,0.375,0.125,0.5,0.125,0.5,0.25,0.375,0.25,1);
K=zeros(30,30);
K=BilinearQuadAssemble(K,k1,1,2,7,6);
K=BilinearQuadAssemble(K,k2,2,3,8,7);
K=BilinearQuadAssemble(K,k3,3,4,9,8);
K=BilinearQuadAssemble(K,k4,4,5,10,9);
K=BilinearQuadAssemble(K,k5,6,7,12,11);
K=BilinearQuadAssemble(K,k6,7,8,13,12);
K=BilinearQuadAssemble(K,k7,8,9,14,13);
K=BilinearQuadAssemble(K,k8,9,10,15,14);
k=[K(3:10,3:10) K(3:10,13:20) K(3:10,23:30) ; K(13:20,3:10) K(13:20,13:20) K(13:20,23:30) ; K(23:30,3:10) K(23:30,13:20) K(23:30,23:30)];
f=[0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 4.6875 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 9.375 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 0 ; 4.6875 ; 0];
u=k\f
U=[0 ; 0 ; u(1:8) ; 0 ; 0 ; u(9:16) ; 0 ; 0 ; u(17:24)]
F=K*U
u1=[U(1) ; U(2) ; U(3) ; U(4) ; U(13) ; U(14) ; U(11) ; U(12)];
u2=[U(3) ; U(4) ; U(5) ; U(6) ; U(15) ; U(16) ; U(13) ; U(14)];
u3=[U(5) ; U(6) ; U(7) ; U(8) ; U(17) ; U(18) ; U(15) ; U(16)];
u4=[U(7) ; U(8) ; U(9) ; U(10) ; U(19) ; U(20) ; U(17) ; U(18)];
u5=[U(11) ; U(12) ; U(13) ; U(14) ; U(23) ; U(24) ; U(21) ; U(22)];
u6=[U(13) ; U(14) ; U(15) ; U(16) ; U(25) ; U(26) ; U(23) ; U(24)];
u7=[U(15) ; U(16) ; U(17) ; U(18) ; U(27) ; U(28) ; U(25) ; U(26)];
u8=[U(17) ; U(18) ; U(19) ; U(20) ; U(29) ; U(30) ; U(27) ; U(28)];
sigma1=BilinearQuadElementStresses(E,NU,0,0,0.125,0,0.125,0.125,0,0.125,1,u1)
sigma2=BilinearQuadElementStresses(E,NU,0.125,0,0.25,0,0.25,0.125,0.125,0.125,1,u2)
sigma3=BilinearQuadElementStresses(E,NU,0.25,0,0.375,0,0.375,0.125,0.25,0.125,1,u3)
sigma4=BilinearQuadElementStresses(E,NU,0.375,0,0.5,0,0.5,0.125,0.375,0.125,1,u4)
sigma5=BilinearQuadElementStresses(E,NU,0,0.125,0.125,0.125,0.125,0.25,0,0.25,1,u5)
sigma6=BilinearQuadElementStresses(E,NU,0.125,0.125,0.25,0.125,0.25,0.25,0.125,0.25,1,u6)
sigma7=BilinearQuadElementStresses(E,NU,0.25,0.125,0.375,0.125,0.375,0.25,0.25,0.25,1,u7)
sigma8=BilinearQuadElementStresses(E,NU,0.375,0.125,0.5,0.125,0.5,0.25,0.375,0.25,1,u8)
s1=BilinearQuadElementPStresses(sigma1)
s2=BilinearQuadElementPStresses(sigma2)
s3=BilinearQuadElementPStresses(sigma3)
s4=BilinearQuadElementPStresses(sigma4)
s5=BilinearQuadElementPStresses(sigma5)
s6=BilinearQuadElementPStresses(sigma6)
s7=BilinearQuadElementPStresses(sigma7)
s8=BilinearQuadElementPStresses(sigma8)
