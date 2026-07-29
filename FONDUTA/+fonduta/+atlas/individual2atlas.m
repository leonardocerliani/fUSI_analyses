function atlasResult = individual2atlas(subData, atlas, anatomic, Transf)
% fonduta.atlas.individual2atlas  Map subject-space data into atlas space.
%
% Warps a subject-space volume into atlas space using the inverse of the
% registration transformation used in atlas2individual.
%
% Inputs:
%   subData  - struct or volume in subject space to warp to atlas space
%   atlas    - struct with atlas geometry (used as reference)
%   anatomic - struct containing the anatomical scan
%   Transf   - struct with field .M (4x4 affine matrix)
%
% Output:
%   atlasResult - data warped to atlas space
%
% See also: fonduta.atlas.atlas2individual

% Interpolate subject data to atlas reference geometry
anatomicInterp = interpolate3D(atlas, anatomic);
T   = affine3d(Transf.M);
ref = imref3d(size(anatomicInterp.Data));

atlasResult = imwarp(subData, T, 'nearest', 'OutputView', ref);

end
