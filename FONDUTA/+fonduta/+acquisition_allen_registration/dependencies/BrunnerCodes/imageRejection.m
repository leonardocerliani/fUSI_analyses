% Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Mace Lab  - Max Planck institute of Neurobiology
% Authors:  G. MONTALDO, E. MACE
% Review & test: C.BRUNNER, M. GRILLET
% September 2020
%
% Rejet images with averge intensity above a defined threshold
%
%   scanfusRej=imageRejection(scanfus,Threshold)
%       scanfus, fus-structure of type fusvolume.
%       Threshold, rejection threshold in % (use 30%).
%       scanfusRej, fus structure of type fusvolume with the filtered data.
%
% example: example02_filter_average.m
%%
function scanfusRej=imageRejection(scanfus,outliers,method)

if nargin==2
    method='linear';
end
[~,~,nz,nt]=size(scanfus.Data);

accepted=1-outliers;

scanfusRej=scanfus;
time=[1:nt];
for iz=1:nz
    timeAccepted=find(accepted(iz,:));
    DataAccepted= squeeze(scanfus.Data(:,:,iz,timeAccepted));
    DataAccepted= permute(DataAccepted,[3,1,2]);
    DataInterp= interp1(timeAccepted,DataAccepted,time,method,'extrap');
    DataInterp = permute(DataInterp,[2,3,1]);
    scanfusRej.Data(:,:,iz,:)=DataInterp;  
end

end