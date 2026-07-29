function [Y, maskIdx] = prepare_data_matrix(PDI_3D, bmask)
% fonduta.glm.prepare_data_matrix  Reshape fUSI data [nx x ny x T] to [T x V] for GLM.
%
% Extracts only brain voxels (bmask == 1) and transposes to [T x V] format
% suitable for fonduta.glm.engine(). Call this once per session before fitting
% any models.
%
% Inputs:
%   PDI_3D  - [nx x ny x T] preprocessed fUSI data
%   bmask   - [nx x ny] binary brain mask
%
% Outputs:
%   Y       - [T x V] data matrix  (T timepoints, V = number of brain voxels)
%   maskIdx - linear indices of brain voxels in bmask (used by remap_vec)
%
% See also: fonduta.glm.ols, fonduta.glm.remap_results, fonduta.glm.remap_vec

[nx, ny, T] = size(PDI_3D);

if ~isequal(size(bmask), [nx, ny])
    error('fonduta:glm:prepare_data_matrix:DimensionMismatch', ...
          'bmask must be [%d x %d] to match PDI', nx, ny);
end

PDI_2D  = reshape(PDI_3D, nx * ny, T);  % [nx*ny x T]
maskIdx = find(bmask(:));               % linear indices of brain voxels
Y       = PDI_2D(maskIdx, :)';          % [T x V]

end
