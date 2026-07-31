% Problem 11.2   Linear Triangle Element (CST)
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=70e6 kPa (=70 GPa Al), NU=0.25, t=0.02 m, Plane Stress (p=1)
% 16 nodes, 16 CST elements -- square plate 0.9m x 0.9m, 0.3m spacing
% Nodes 1,5,9,13 fixed (left column), -20 kN load at node 16
% DOF order per node: [Ux, Uy]

E=70e6;
NU=0.25;
t=0.02;
k1=LinearTriangleElementStiffness(E,NU,t,0,0,0.3,0.3,0,0.3,1)
k2=LinearTriangleElementStiffness(E,NU,t,0,0,0.3,0,0.3,0.3,1)
k3=LinearTriangleElementStiffness(E,NU,t,0.3,0,0.6,0.3,0.3,0.3,1)
k4=LinearTriangleElementStiffness(E,NU,t,0.3,0,0.6,0,0.6,0.3,1)
k5=LinearTriangleElementStiffness(E,NU,t,0.6,0,0.9,0.3,0.6,0.3,1)
k6=LinearTriangleElementStiffness(E,NU,t,0.6,0,0.9,0,0.9,0.3,1)
k7=LinearTriangleElementStiffness(E,NU,t,0,0.3,0.3,0.6,0,0.6,1)
k8=LinearTriangleElementStiffness(E,NU,t,0,0.3,0.3,0.3,0.3,0.6,1)
k9=LinearTriangleElementStiffness(E,NU,t,0.6,0.3,0.9,0.6,0.6,0.6,1)
k10=LinearTriangleElementStiffness(E,NU,t,0.6,0.3,0.9,0.3,0.9,0.6,1)
k11=LinearTriangleElementStiffness(E,NU,t,0,0.6,0.3,0.9,0,0.9,1)
k12=LinearTriangleElementStiffness(E,NU,t,0,0.6,0.3,0.6,0.3,0.9,1)
k13=LinearTriangleElementStiffness(E,NU,t,0.3,0.6,0.6,0.9,0.3,0.9,1)
k14=LinearTriangleElementStiffness(E,NU,t,0.3,0.6,0.6,0.6,0.6,0.9,1)
k15=LinearTriangleElementStiffness(E,NU,t,0.6,0.6,0.9,0.9,0.6,0.9,1)
k16=LinearTriangleElementStiffness(E,NU,t,0.6,0.6,0.9,0.6,0.9,0.9,1)
K=zeros(32,32);
K=LinearTriangleAssemble(K,k1,1,6,5);
K=LinearTriangleAssemble(K,k2,1,2,6);
K=LinearTriangleAssemble(K,k3,2,7,6);
K=LinearTriangleAssemble(K,k4,2,3,7);
K=LinearTriangleAssemble(K,k5,3,8,7);
K=LinearTriangleAssemble(K,k6,3,4,8);
K=LinearTriangleAssemble(K,k7,5,10,9);
K=LinearTriangleAssemble(K,k8,5,6,10);
K=LinearTriangleAssemble(K,k9,7,12,11);
K=LinearTriangleAssemble(K,k10,7,8,12);
K=LinearTriangleAssemble(K,k11,9,14,13);
K=LinearTriangleAssemble(K,k12,9,10,14);
K=LinearTriangleAssemble(K,k13,10,15,14);
K=LinearTriangleAssemble(K,k14,10,11,15);
K=LinearTriangleAssemble(K,k15,11,16,15);
K=LinearTriangleAssemble(K,k16,11,12,16);
k=[K(3:8,3:8) K(3:8,11:16) K(3:8,19:24) K(3:8,27:32) ; K(11:16,3:8) K(11:16,11:16) K(11:16,19:24) K(11:16,27:32) ; K(19:24,3:8) K(19:24,11:16) K(19:24,19:24) K(19:24,27:32) ; K(27:32,3:8) K(27:32,11:16) K(27:32,19:24) K(27:32,27:32)];
f=[0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;-20];
u=k\f
U=[0;0;u(1:6);0;0;u(7:12);0;0;u(13:18);0;0;u(19:24)];
F=K*U
