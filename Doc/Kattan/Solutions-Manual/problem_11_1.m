% Problem 11.1   Linear Triangle Element (CST)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=210 GPa, NU=0.3, t=0.025 m, Plane Stress (p=1)
% 5 nodes, 4 CST elements -- rectangular plate 0.5m x 0.25m
% Nodes 1 and 4 fixed (left edge), Nodes 2 and 3 loaded (right edge)
% DOF order per node: [Ux, Uy]

E=210e6;
NU=0.3;
t=0.025;
k1=LinearTriangleElementStiffness(E,NU,t,0,0,0.25,0.125,0,0.25,1)
k2=LinearTriangleElementStiffness(E,NU,t,0,0,0.5,0,0.25,0.125,1)
k3=LinearTriangleElementStiffness(E,NU,t,0.5,0.25,0,0.25,0.25,0.125,1)
k4=LinearTriangleElementStiffness(E,NU,t,0.5,0,0.5,0.25,0.25,0.125,1)
K=zeros(10,10);
K=LinearTriangleAssemble(K,k1,1,5,4);
K=LinearTriangleAssemble(K,k2,1,2,5);
K=LinearTriangleAssemble(K,k3,3,4,5);
K=LinearTriangleAssemble(K,k4,2,3,5);
k=[K(3:6,3:6) K(3:6,9:10) ; K(9:10,3:6) K(9:10,9:10)]
f=[9.375 ; 0 ; 9.375 ; 0 ; 0 ; 0]
u=k\f
U=[0;0;u(1:4);0;0;u(5:6)]
F=K*U
u1=[U(1);U(2);U(9);U(10);U(7);U(8)]
u2=[U(1);U(2);U(3);U(4);U(9);U(10)]
u3=[U(5);U(6);U(7);U(8);U(9);U(10)]
u4=[U(3);U(4);U(5);U(6);U(9);U(10)]
sig1=LinearTriangleElementStresses(E,NU,t,0,0,0.25,0.125,0,0.25,1,u1)
sig2=LinearTriangleElementStresses(E,NU,t,0,0,0.5,0,0.25,0.125,1,u2)
sig3=LinearTriangleElementStresses(E,NU,t,0.5,0.25,0,0.25,0.25,0.125,1,u3)
sig4=LinearTriangleElementStresses(E,NU,t,0.5,0,0.5,0.25,0.25,0.125,1,u4)
s1=LinearTriangleElementPStresses(sig1)
s2=LinearTriangleElementPStresses(sig2)
s3=LinearTriangleElementPStresses(sig3)
s4=LinearTriangleElementPStresses(sig4)
