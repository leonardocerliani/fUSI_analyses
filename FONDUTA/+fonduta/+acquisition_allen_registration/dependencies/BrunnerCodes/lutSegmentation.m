% NERF empowered by imec, KU Leuven and VIB
% Author: Gabriel MONTALDO


%% Lookup table for segmentation with the atlas
% precomputes a looput table for fast interpolatio registering and segmentation of the fus data.
% this lut can be used with all the datas sharing the same transformation. 

% lut=lutSegmentation(Transf,atlas, fusData)
%   Transf, transformation structure obtained with the registering function.
%   atlas, Allen Mouse Common Coordinate Framework provided in the allen_brain_atlas.mat file,
%   fusData, fus-structure of type fusvolume.

% Example: example03_register_data.m


function lut=lutSegmentation(Transf,atlas,fusData)

regions=atlas.Regions;

tform=affine3d(Transf.M);

[nx,ny,nz]=size(regions);
[Y,X,Z] = meshgrid((0:ny-1),(0:nx-1),(0:nz-1));
[Yt,Xt,Zt]=transformPointsInverse(tform,Y,X,Z);

% adjust size of the mesh 
dataperm=permuteScan(fusData,atlas);
Xt=Xt*atlas.VoxelSize(1)/dataperm.VoxelSize(1)+1;
Yt=Yt*atlas.VoxelSize(2)/dataperm.VoxelSize(2)+1;
Zt=Zt*atlas.VoxelSize(3)/dataperm.VoxelSize(3)+1;

% nearest point "low corner" 
xe=floor(Xt);
ye=floor(Yt);
ze=floor(Zt);

dx=Xt-xe;
dy=Yt-ye;
dz=Zt-ze;

% linear interpolation coefficients
C000=(1-dx).*(1-dy).*(1-dz);
C001=(1-dx).*(1-dy).*(dz  );
C010=(1-dx).*(dy  ).*(1-dz);
C011=(1-dx).*(dy  ).*(dz  );
C100=(dx  ).*(1-dy).*(1-dz);
C101=(dx  ).*(1-dy).*(dz  );
C110=(dx  ).*(dy  ).*(1-dz);
C111=(dx  ).*(dy  ).*(dz  );

nreg=max(atlas.Regions(:));

% mark right hemisphere 
nt2=round(size(regions,3)/2);
regions(:,:,1:nt2)=nreg+regions(:,:,1:nt2);
[regSort,ind]=sort(regions(:));   % sort is faster than using find
regSort(end+1)=nreg*2+1;          % last point to stop.

[nxr,nyr,nzr,~]=size(dataperm.Data);
cum=zeros(nxr,nyr,nzr,'single');
lutCoef=cell(nreg*2,1);
lutInd=cell(nreg*2,1);
i=1;
for ireg=1:nreg*2
    
    while regSort(i)==ireg
        x0=xe(ind(i));
        y0=ye(ind(i));
        z0=ze(ind(i));        
        if(x0>0&&y0>0&&z0>0&&x0<nxr&&y0<nyr&&z0<nzr)         
            cum(x0,  y0,  z0  )= cum(x0,  y0,  z0  ) + C000(x0,y0,z0);
            cum(x0,  y0,  z0+1)= cum(x0,  y0,  z0+1) + C001(x0,y0,z0);
            cum(x0,  y0+1,z0  )= cum(x0,  y0+1,z0  ) + C010(x0,y0,z0);
            cum(x0,  y0+1,z0+1)= cum(x0,  y0+1,z0+1) + C011(x0,y0,z0);
            cum(x0+1,y0,  z0  )= cum(x0+1,y0,  z0  ) + C100(x0,y0,z0);
            cum(x0+1,y0,  z0+1)= cum(x0+1,y0,  z0+1) + C101(x0,y0,z0);
            cum(x0+1,y0+1,z0  )= cum(x0+1,y0+1,z0  ) + C110(x0,y0,z0);
            cum(x0+1,y0+1,z0+1)= cum(x0+1,y0+1,z0+1) + C111(x0,y0,z0);
        end
        i=i+1;
    end
    
    indDest=find(cum>0);
    lutCoef{ireg}=cum(indDest);
    lutInd{ireg}=indDest;
    cum(indDest)=0;         %reset cum
end

lut.ind=lutInd;
lut.Coef=lutCoef;
lut.nregion=nreg;
lut.Direction=atlas.Direction;
end


