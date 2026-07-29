function subAtlas = atlas2individual(atlas, anatomic, Transf, dispFieldA2I)
% fonduta.atlas.atlas2individual  Map Allen Brain Atlas into subject (individual) space.
%
% Applies affine + optional nonlinear deformable registration to warp
% the atlas Regions, Histology, and Vascular volumes into subject space.
%
% Inputs:
%   atlas         - struct with fields: .Regions, .Histology, .Vascular
%   anatomic      - struct containing the anatomical scan (from load_session)
%   Transf        - struct with field .M (4x4 affine matrix, from Transformation.mat)
%   dispFieldA2I  - (optional) displacement field for nonlinear deformation.
%                   Pass [] or omit to use affine-only registration.
%
% Output:
%   subAtlas - struct with fields:
%       .Region    - atlas regions warped to subject space
%       .Histology - atlas histology warped to subject space
%       .Vascular  - atlas vascular map warped to subject space
%
% See also: fonduta.atlas.individual2atlas, fonduta.atlas.build_brain_masks

if nargin < 4
    dispFieldA2I = [];
end

% Linear transformation: interpolate atlas to match anatomic, then apply affine
anatomicInterp = interpolate3D(atlas, anatomic);
T   = affine3d(Transf.M);
ref = imref3d(size(anatomicInterp.Data));

atlasRegionAffine    = imwarp(atlas.Regions,   T.invert, 'nearest', 'OutputView', ref);
atlasHistologyAffine = imwarp(atlas.Histology, T.invert, 'nearest', 'OutputView', ref);
atlasVascularAffine  = imwarp(atlas.Vascular,  T.invert, 'nearest', 'OutputView', ref);

% Nonlinear deformation (optional)
if isempty(dispFieldA2I)
    anatomicInterp.Data = atlasRegionAffine;
    subAtlas.Region     = interpolate3D(anatomic, anatomicInterp, 'nearest');
    anatomicInterp.Data = atlasHistologyAffine;
    subAtlas.Histology  = interpolate3D(anatomic, anatomicInterp, 'nearest');
    anatomicInterp.Data = atlasVascularAffine;
    subAtlas.Vascular   = interpolate3D(anatomic, anatomicInterp, 'nearest');
else
    regionInterp        = imwarp(atlasRegionAffine,    dispFieldA2I, 'nearest');
    anatomicInterp.Data = regionInterp;
    subAtlas.Region     = interpolate3D(anatomic, anatomicInterp, 'nearest');
    regionInterp        = imwarp(atlasHistologyAffine, dispFieldA2I, 'nearest');
    anatomicInterp.Data = regionInterp;
    subAtlas.Histology  = interpolate3D(anatomic, anatomicInterp, 'nearest');
    regionInterp        = imwarp(atlasVascularAffine,  dispFieldA2I, 'nearest');
    anatomicInterp.Data = regionInterp;
    subAtlas.Vascular   = interpolate3D(anatomic, anatomicInterp, 'nearest');
end

end
