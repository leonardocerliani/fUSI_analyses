% Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Mace Lab  - Max Planck institute of Neurobiology
% Authors:  G. MONTALDO, E. MACE
% Review & test: C.BRUNNER, M. GRILLET
% September 2020
%
% Visualization of the output by selecting a set of regions to display. 
% Output data is normalized as a Z-score
%
% selectSegmented=selectBrainRegions(atlas, fileRegions, segmented)
%   atlas, the Allen Mouse Common Coordinate Framework provided in the 'atlas.mat' file,
%   fileRegions, a sting with the name of a text file listing the selected regions, see details below,
%   segmented, structure of segmented regions provided by the 'segmentation.m' function.
%   selectSegmented, a 2-field structure (‘.Left’ and ‘.Right’) containing temporal traces
%       of regions selected or grouped as organized in the fileRegions for both the left and right hemisphere. 
%       Each field is a 2D matrix of Nregions*nt. The Nregions lines are the selected or grouped regions 
%       as organized in the fileRegions file and the nt the time points.
%
% Example: 	'example05_segmentation.m'
%% 
function selectSegmented=selectBrainRegions(atlas,region_list,segmented)
D=readFileList(region_list,atlas.infoRegions);      
selectSegmented.Left = select(D,segmented.Left );  
selectSegmented.Right= select(D,segmented.Right);  
end


function px=select(D,p)
nt=size(p,2);
nr=length(D.parts);

px=zeros(nr,nt);
for ir=1:nr
    parts=D.parts{ir};
    nsp=length(parts);
    tmp=zeros(1,nt);
    for isp=1:nsp
        tmp=tmp+p(parts(isp),:);
    end
    px(ir,:,:)=tmp./nsp;
end

% normalize data as Z-score for visualization
for ir=1:nr
    px(ir,:)=px(ir,:)-mean(px(ir,:));
    px(ir,:)=px(ir,:)./std(px(ir,:));
end

end


