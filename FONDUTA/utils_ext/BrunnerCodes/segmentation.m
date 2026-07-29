% NERF empowered by imec, KU Leuven and VIB
% Author: Gabriel MONTALDO


%% Data Segmantation in regions defined by the atals
% from the looput table for fast interpolatio registering and segmentation of the fus data.
% this lut can be used with all the datas sharing the same transformation. 

% segmented=segmentation(Lut,scanfus)
%   Lut, lookup table computed with lutSegmentation.m,
%   scanfus, fus-structure of fusvolume type,
%   segmented, a structure with 2 fields containing temporal traces for either the left or the right hemisphere. 
%       Each field is a 2D matrix of 509*nt. The 509 lines are all brain regions from the Allen Mouse Common Coordinate Framework and nt the number of time points. 
%

% Example: example05_segmentation.m


function segmented=segmentation(Lut,scanfus)     

xp=permuteScan(scanfus,Lut);
Data=xp.Data;
nt=size(Data,4);        

% normalization (optional can be commented)
m=mean(Data,4);
for it=1:nt         
   Data(:,:,:,it)=Data(:,:,:,it)./m;
end

[pl,pr]=projectLut3D(Data,Lut); 
segmented.Left=pl;
segmented.Right=pr;
end


function [pl,pr]=projectLut3D(data,Lut)
nr=Lut.nregion;
[nx,ny,nz,nt]=size(data);
nxyz=nx*ny*nz;
pl=zeros(nr,nt);
pr=zeros(nr,nt);
for ir=1:nr
    indL =Lut.ind{ir};
    coefL=Lut.Coef{ir};
    indR =Lut.ind{ir+nr};
    coefR=Lut.Coef{ir+nr};
    for it=1:nt
       pl(ir,it)=sum( data(indL+(it-1)*nxyz).*coefL);
       pr(ir,it)=sum( data(indR+(it-1)*nxyz).*coefR);
    end
end
end



