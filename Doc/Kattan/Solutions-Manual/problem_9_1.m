% Problem 9.1   Grid Element
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=210 GPa, G=84 GPa, I=20e-5 m^4, J=5e-5 m^4
% Node 1: (4,0)  Node 2: (0,3)  Node 3: (0,-3)
% Elements: 1-2 (L=5m, theta=216.87°), 1-3 (L=5m, theta=143.13°)
% Load: 10 kN downward (Z) at node 1
% DOF order per node: [UZ, RX, RY]

E=210e6;
G=84e6;
I=20e-5;
J=5e-5;
L1=GridElementLength(4,0,0,3)
L2=GridElementLength(4,0,0,-3)
theta1=180+atan(3/4)*180/pi
theta2=180-atan(3/4)*180/pi
k1=GridElementStiffness(E,G,I,J,L1,theta1)
k2=GridElementStiffness(E,G,I,J,L2,theta2)
K=zeros(9,9)
K=GridAssemble(K,k1,1,2)
K=GridAssemble(K,k2,1,3)
k=K(1:3,1:3)
f=[-10 ; 0 ; 0]
u=k\f
U=[u ; 0 ; 0 ; 0 ; 0 ; 0 ; 0]
F=K*U
u1=[U(1) ; U(2) ; U(3) ; U(4) ; U(5) ; U(6)]
u2=[U(1) ; U(2) ; U(3) ; U(7) ; U(8) ; U(9)]
f1=GridElementForces(E,G,I,J,L1,theta1,u1)
f2=GridElementForces(E,G,I,J,L2,theta2,u2)
