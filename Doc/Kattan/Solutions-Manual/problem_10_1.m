% Problem 10.1   Space Frame Element
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=210 GPa, G=84 GPa, A=2e-2 m^2, Iy=10e-5 m^4, Iz=20e-5 m^4, J=5e-5 m^4
% 8 nodes, 8 elements (4 columns, 4 roof beams)
% Nodes 1-4: ground (fixed), Nodes 5-8: top (free)
% Load: -15 kN (Y) at node 7
% DOF order per node: [Ux, Uy, Uz, Rx, Ry, Rz]

E=210e6;
G=84e6;
A=2e-2;
Iy=10e-5;
Iz=20e-5;
J=5e-5;
k1=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,0,0,0,0,5,0)
k2=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,0,0,4,0,5,4)
k3=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,4,0,4,4,5,4)
k4=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,4,0,0,4,5,0)
k5=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,0,5,0,0,5,4)
k6=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,0,5,4,4,5,4)
k7=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,4,5,4,4,5,0)
k8=SpaceFrameElementStiffness(E,G,A,Iy,Iz,J,0,5,0,4,5,0)
K=zeros(48,48);
K=SpaceFrameAssemble(K,k1,1,5);
K=SpaceFrameAssemble(K,k2,2,6);
K=SpaceFrameAssemble(K,k3,3,7);
K=SpaceFrameAssemble(K,k4,4,8);
K=SpaceFrameAssemble(K,k5,5,6);
K=SpaceFrameAssemble(K,k6,6,7);
K=SpaceFrameAssemble(K,k7,7,8);
K=SpaceFrameAssemble(K,k8,5,8);
k=K(25:48,25:48)
f=[0;0;0;0;0;0;0;0;0;0;0;0;-15;0;0;0;0;0;0;0;0;0;0;0]
u=k\f
U=[zeros(24,1);u]
F=K*U
u1=[U(1);U(2);U(3);U(4);U(5);U(6);U(25);U(26);U(27);U(28);U(29);U(30)]
u2=[U(7);U(8);U(9);U(10);U(11);U(12);U(31);U(32);U(33);U(34);U(35);U(36)]
u3=[U(13);U(14);U(15);U(16);U(17);U(18);U(37);U(38);U(39);U(40);U(41);U(42)]
u4=[U(19);U(20);U(21);U(22);U(23);U(24);U(43);U(44);U(45);U(46);U(47);U(48)]
u5=[U(25);U(26);U(27);U(28);U(29);U(30);U(31);U(32);U(33);U(34);U(35);U(36)]
u6=[U(31);U(32);U(33);U(34);U(35);U(36);U(37);U(38);U(39);U(40);U(41);U(42)]
u7=[U(37);U(38);U(39);U(40);U(41);U(42);U(43);U(44);U(45);U(46);U(47);U(48)]
u8=[U(25);U(26);U(27);U(28);U(29);U(30);U(43);U(44);U(45);U(46);U(47);U(48)]
f1=SpaceFrameElementForces(E,G,A,Iy,Iz,J,0,0,0,0,5,0,u1)
f2=SpaceFrameElementForces(E,G,A,Iy,Iz,J,0,0,4,0,5,4,u2)
f3=SpaceFrameElementForces(E,G,A,Iy,Iz,J,4,0,4,4,5,4,u3)
f4=SpaceFrameElementForces(E,G,A,Iy,Iz,J,4,0,0,4,5,0,u4)
f5=SpaceFrameElementForces(E,G,A,Iy,Iz,J,0,5,0,0,5,4,u5)
f6=SpaceFrameElementForces(E,G,A,Iy,Iz,J,0,5,4,4,5,4,u6)
f7=SpaceFrameElementForces(E,G,A,Iy,Iz,J,4,5,4,4,5,0,u7)
f8=SpaceFrameElementForces(E,G,A,Iy,Iz,J,0,5,0,4,5,0,u8)
