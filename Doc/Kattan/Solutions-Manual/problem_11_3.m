% Problem 11.3   Linear Triangle Element (CST) with Springs
% From "MATLAB Guide to Finite Elements" by Peter I. Kattan
% Solutions Manual (Reduced Version)
%
% Units: kN, m
% E=200e6 kPa, NU=0.3, t=0.01 m, Plane Stress (p=1)
% 5 nodes: 1=(0,0.4), 2=(0.7,0.4), 3=(0,0), 4=(0.7,0), 5=ground node (fixed)
% Two CST triangles + two springs (k=4000 each); 17.5 kN loads at nodes 1 and 2
% Node 5 fixed: U(9)=U(10)=0
% DOF order per node: [Ux, Uy]
% NOTE: k=K(1:8,1:8) is singular (RCOND ~ 2.5e-17); u's x-components
%       are an arbitrary particular solution.

E=200e6;
NU=0.3;
t=0.01;
k1=LinearTriangleElementStiffness(E,NU,t,0,0.4,0,0,0.7,0.4,1);
k2=LinearTriangleElementStiffness(E,NU,t,0.7,0.4,0,0,0.7,0,1);
k3=SpringElementStiffness(4000);
k4=SpringElementStiffness(4000);
K=zeros(10,10);
K=LinearTriangleAssemble(K,k1,1,3,2);
K=LinearTriangleAssemble(K,k2,2,3,4);
K=SpringAssemble(K,k3,6,9);
K=SpringAssemble(K,k4,8,10)
k=K(1:8,1:8);
f=[0 ; 17.5 ; 0 ; 17.5 ; 0 ; 0 ; 0 ; 0];
u=k\f
U=[u(1:8) ; 0 ; 0];
F=K*U
u1=[U(1) ; U(2) ; U(5) ; U(6) ; U(3) ; U(4)];
u2=[U(3) ; U(4) ; U(5) ; U(6) ; U(7) ; U(8)];
u3=[U(6) ; U(9)];
u4=[U(8) ; U(10)];
sigma1=LinearTriangleElementStresses(E,NU,t,0,0.4,0,0,0.7,0.4,1,u1);
sigma2=LinearTriangleElementStresses(E,NU,t,0.7,0.4,0,0,0.7,0,1,u2);
s1=LinearTriangleElementPStresses(sigma1);
s2=LinearTriangleElementPStresses(sigma2);
f3=SpringElementForces(k3,u3);
f4=SpringElementForces(k4,u4);
