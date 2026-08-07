function subAtlas = Atlas2Individual(atlas,anatomic,Transf,dispFieldA2I)

if nargin < 4
    dispFieldA2I = [];
end


% load("allen_brain_atlas.mat");
% load("anatomic.mat");
% load("Transformation.mat");

% linear transformation
anatomicInterp = interpolate3D(atlas,anatomic); %atlas is adjusted so that it matches the anatomic
T = affine3d(Transf.M); %creates a tool for the spatial adjustment. Transf.M is a matrix that specifies how the image should be changed
ref = imref3d(size(anatomicInterp.Data)); % helps the computer to understand how the voxels are arranged

atlasRegionAffineTransformed=imwarp(atlas.Regions,T.invert,'nearest','OutputView',ref);
atlasHistologyAffineTransformed=imwarp(atlas.Histology,T.invert,'nearest','OutputView',ref);

% NB: before the lines with interpolate3D were like
%
%   subAtlas.Region = interpolate3D(anatomic,anatomicInterp,'nearest');
%
% however this was breaking since interpolate3d accepts only two
% arguments and already implements nn interpolation, so I removed it

if isempty(dispFieldA2I)
    % Linear deformation
    anatomicInterp.Data = atlasRegionAffineTransformed;
    subAtlas.Region = interpolate3D(anatomic,anatomicInterp);
    anatomicInterp.Data = atlasHistologyAffineTransformed;
    subAtlas.Histology = interpolate3D(anatomic,anatomicInterp);
else
    % Nonlinear deformation
    regionInterp = imwarp(atlasRegionAffineTransformed,dispFieldA2I,'nearest');
    anatomicInterp.Data = regionInterp;
    subAtlas.Region = interpolate3D(anatomic,anatomicInterp);
    regionInterp = imwarp(atlasHistologyAffineTransformed,dispFieldA2I,'nearest');
    anatomicInterp.Data = regionInterp;
    subAtlas.Histology = interpolate3D(anatomic,anatomicInterp);
end

end