% This is a matlab script that generates the input data
% require matlab functions for equation of state
clear all;
clc;
close all;

addpath(genpath('/nfspool-0/home/rgadi/MITgcm/MITgcm-master/utils/matlab'));
kwr=3;
% Dimensions of grid
nx=1;
ny=200;
nr=500;
delz=1;

v0 = 2e3;
h0 = 800;

hfacMin = 0.2;

dlat = 2*0.125/16/16/5; dy=dlat;
dlon = 0.125/1; dx=dlon;

eos = 'jmd95z';
prec = 'real*8';

long = 0;
%long=51.4+[0:nx-1]*dlon;
lonc = long+dlon/2;
latg = -75.5+[0:ny-1]*dlat;
%latg=64;
latc = latg+dlat/2;
zC=-delz*([1:nr]-0.5);
zF=-delz*[0:nr];
%size(latc)

% Gravity
gravity= 9.81;
rhoConst= 1030;
rhoIce = 917;

% Nominal depth of model (meters)
H = -500;		%water depth in the ice shelf cavity
Hmin = H + delz;		% deepest point of cavern		
Hmax = H + delz + 150;		% shallowest point of cavern
%jEnd = ny*3/4;		 % where ice-shelf ends
jEnd = ny;
dHdy = (Hmax-Hmin)/dlat/(jEnd-2); %Slope of ice shelf

bathy = ones(nx,ny)*H;	%For flat bathymetry: bathy = ones(nx,ny)*H;
bathy(:,1) = 0;

j2=jEnd+1;
hIce=Hmin+dHdy*[-1:ny-2]*dlat;
hIce(1)=0; hIce(j2:ny)=0;

var=([1:ny]-2)/(jEnd-2);
%var(2), var(jEnd)
dMdt_fy=-cos(pi*var); 
%dMdt_fy=0;
dMdt_fy(1)=0; dMdt_fy(j2:ny)=0;

figure(1);clf;
subplot(211)
 yax=[1:ny];
 plot(yax,hIce,'r-');
hold on;
 plot(yax,bathy,'b-');
hold off;
 grid
title('ice-shelf & model depth [m]')

subplot(212)
 plot(yax,dMdt_fy,'b-');
 grid
title('shape of ice-mass input')

namF='bathy_flat.bin';
if kwr > 2,
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,bathy,prec);fclose(fid);
 writebin(namF,bathy);
 fprintf(' done\n');
end

namF='shelficeTopo.Lin.bin';
if kwr > 2,
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,hIce,prec);fclose(fid);
 writebin(namF,hIce);
 fprintf(' done\n');
end

regMsk=ones(ny,1);
regMsk(1)=0; regMsk(j2:ny)=2;
namF='under_Ice_mask.bin';
if kwr > 2,
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,regMsk,prec);fclose(fid);
 writebin(namF,regMsk);
 fprintf(' done\n');
end

%- rate of change due to ice-stream dynamics
%rateDyn=rhoConst*0.1/86400; sfx='r01';
%rateDyn=rhoConst*0.1/3600;  sfx='r02';
 rateDyn=rhoConst*0/3600;  sfx='r02';

dMdt=rateDyn*dMdt_fy;
namF=sprintf('%s.%s.%s','shelfice_dMdt',sfx,'bin');
if kwr > 0,
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,dMdt,prec);fclose(fid);
 writebin(namF,dMdt);
 fprintf(' done\n');
end

dz = delz*ones(1,nr);
zgp1 = [0,cumsum(dz)];
zc = .5*(zgp1(1:end-1)+zgp1(2:end));
zg = zgp1(1:end-1);
dz = diff(zgp1);
fprintf('  delZ = %d * %7.6g\n',nr,dz(1))

T_sfc = -0.2;
T_bot = 0.2;
del_T = (T_bot - T_sfc)/(59*delz);
for k = 1:nr;
    tref(k) = T_sfc + del_T*((k-20)*delz);
    tref(k)= max(T_sfc,min(tref(k),T_bot));
end

S_sfc = 32;
S_bot = 34.7;
del_S = (S_bot - S_sfc)/(59*delz);
for k = 1:nr;
    sref(k) = S_sfc + del_S*((k-20)*delz);
    sref(k)= max(S_sfc,min(sref(k),S_bot));
end
pEOS=-rhoConst*gravity*zC; % in Pa
pEOS=pEOS*1.e-4; % in dBar
rhoAn=densjmd95(sref,tref,pEOS);
rhoAn=rhoAn-rhoConst;

pF=-rhoConst*gravity*zF*1.e-4; % in dBar
rhoUp=densjmd95(sref,tref,pF(2:end));
rhoDw=densjmd95(sref,tref,pF(1:nr));
dRho=rhoUp(1:nr-1)-rhoDw(2:nr);
NSq=-gravity*dRho/delz/rhoConst;

mnV=min(NSq); MxV=max(NSq); Avr=mean(NSq);
fprintf(' Stratif (N^2): min= %e , max= %e , Avr= %e\n',mnV,MxV,Avr);

zax=[1:nr];
% 
% v1=2.5e-2;
% var=1+nr-2*zax; var=var/(nr-1);
% vobc=v1*var;

%% New add to the code (Vobc written so that the flux through the boundary
% is made zero)
% vobc = -0.1/abs(Hmax - Hmin) * (zc + H - (2 * H - Hmax - Hmin)/3);
% vobc(-zc>Hmax) = 0;
var = 0.1;
vobc = zeros(size(zc));
ind = find(zc<abs(H)&zc>abs(H+1));
vobc(ind) = -var;
clear ind;
ind = find(zc<=abs(H+1)&zc>abs(H+3));
vobc(ind) = (var * abs(zc(ind) - abs(H+1)) - var * abs(zc(ind) - abs(H+3)))/2;
clear ind;
ind = find(zc<=abs(H+3)&zc>=Hmax);
vobc(ind) = var;

figure(2);clf;
 subplot(131);
 plot(tref,-zax,'r-');
 grid
 title('tRef')
 subplot(132);
 plot(sref,-zax,'b-');
 grid
 title('sRef')
 subplot(133);
%plot(vobc,-zax,'b-');
 plot(rhoAn,-zax,'b-');
%plot(NSq*1.e+6,0.5-[2:nr],'r-');
 grid
 title('rhoAn')

if kwr > 2,
 namF='temp_obc.bin';
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,tref,prec);fclose(fid);
 writebin(namF,tref);
 fprintf(' done\n');
 namF='salt_obc.bin';
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,sref,prec);fclose(fid);
 writebin(namF,sref);
 fprintf(' done\n');
 namF='vVel_obc.bin';
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,vobc,prec);fclose(fid);
 writebin(namF,vobc);
 fprintf(' done\n');
end

if kwr > 2,
 var=ones(ny,1)*tref; %size(var)
 namF='temp_ini.bin';
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,var,prec);fclose(fid);
 writebin(namF,var);
 fprintf(' done\n');
%-
 var=ones(ny,1)*sref; %size(var)
 namF='salt_ini.bin';
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,var,prec);fclose(fid);
 writebin(namF,var);
 fprintf(' done\n');
end

rhoAvr=rhoConst-1.345;
fprintf(' convert Ice topo using rhoAve = %10.6f\n',rhoAvr);
mIce0=-rhoAvr*hIce;

namF='shelficeMass.Lin.bin';
if kwr > 1,
 fprintf(' writing file: %s ...',namF);
 %fid=fopen(namF,'w','b'); fwrite(fid,mIce0,prec);fclose(fid);
 writebin(namF,mIce0);
 fprintf(' done\n');
end

return

