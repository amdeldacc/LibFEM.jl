% ===============================================================================
% PROBLEM OVERVIEW: PLANE TRUSS WITH A SPRING (Fig 5.6)
% ===============================================================================
%
%         - - -
%           ^   //| 3
%           |   //|--O
%          4 m  //|    \
%           |   //|      \
%           v   //| 2      \                 k               5
%         - - - //|--O-------O-------------/\/\/\------------O-----> 10 kN
%           ^   //|          4
%          3 m  //|        /
%           |   //|      /
%           v   //| 1  /
%         - - - //|--O
%
%                    |<----- 4 m ----->|
%
% ===============================================================================
% NODE COORDINATES & LOADS:
% ===============================================================================
% Assuming Node 1 is at the origin (0,0) and the unit is meters:
%
%   Node 1 : ( 0, 0)   -> Fixed Support
%   Node 2 : ( 0, 3)   -> Fixed Support
%   Node 3 : ( 0, 7)   -> Fixed Support
%   Node 4 : ( 4, 3)   -> Truss-Spring Junction
%   Node 5 : ( X, 3)   -> Free End (Spring), Applied Load: Fx = +10 kN
%                         (Where X = 4 + undeformed length of the spring)
%
% ===============================================================================

clear; clc;

E = 70e6

A = 0.01

L1 = PlaneTrussElementLength(0,0,4,3)

L2 = PlaneTrussElementLength(0,0,4,0)

L3 = PlaneTrussElementLength(0,0,4,-4)

theta1 = atan(3/4)*180/pi

theta2 = 0

theta3 = 360 - atan(4/4)*180/pi

k1 = PlaneTrussElementStiffness(E,A,L1,theta1)

k2 = PlaneTrussElementStiffness(E,A,L2,theta2)

k3 = PlaneTrussElementStiffness(E,A,L3,theta3)

k4 = SpringElementStiffness(3000)

K = zeros(9,9)

K = PlaneTrussAssemble(K,k1,1,4)

K = PlaneTrussAssemble(K,k2,2,4)

K = PlaneTrussAssemble(K,k3,3,4)

K = SpringAssemble(K,k4,7,9)

k = K(7:9,7:9)

f = [0 ; 0 ; 10]

u = k\f

U = [0 ; 0 ; 0 ; 0 ; 0 ; 0 ; u]

F = K*U

u1 = [U(1) ; U(2) ; U(7) ; U(8)]

sigma1 = PlaneTrussElementStress(E,L1,theta1,u1)

u2 = [U(3) ; U(4) ; U(7) ; U(8)]

sigma2 = PlaneTrussElementStress(E,L2,theta2,u2)

u3 = [U(5) ; U(6) ; U(7) ; U(8)]

sigma3 = PlaneTrussElementStress(E,L3,theta3,u3)

u4 = [U(7) ; U(9)]

f4 = SpringElementForces(k4,u4)
