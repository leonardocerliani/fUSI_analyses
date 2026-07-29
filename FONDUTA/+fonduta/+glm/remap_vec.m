function map = remap_vec(vec, bmask)
% fonduta.glm.remap_vec  Remap a [1 x V] voxel vector to an [nx x ny] spatial map.
%
% Simple utility for remapping correlation vectors or any other [1 x V]
% quantity back to 2D spatial format. Non-brain positions are NaN.
%
% Inputs:
%   vec   - [1 x V] or [V x 1] vector of voxel values
%   bmask - [nx x ny] binary brain mask (same one used in prepare_data_matrix)
%
% Output:
%   map   - [nx x ny] spatial map with NaN at non-brain voxels
%
% Example:
%   corrVec = corr(xPred, Y);                        % [1 x V]
%   corrMap = fonduta.glm.remap_vec(corrVec, bmask); % [nx x ny]
%
% See also: fonduta.glm.ols, fonduta.glm.remap_results

[nx, ny] = size(bmask);
maskIdx  = find(bmask(:));

map             = nan(nx * ny, 1);
map(maskIdx)    = vec(:);
map             = reshape(map, nx, ny);

end
