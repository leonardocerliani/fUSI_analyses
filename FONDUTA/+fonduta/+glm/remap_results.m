function remapped = remap_results(glm_est, bmask)
% fonduta.glm.remap_results  Remap GLM results from voxel-vector to 2D spatial maps.
%
% Converts the output of fonduta.glm.engine() from [* x V] format to
% [* x nx x ny] spatial maps, placing NaN at non-brain voxels (bmask == 0).
%
% Inputs:
%   glm_est  - struct from fonduta.glm.engine(), with fields:
%                .betas  [p+1 x V]
%                .eta2   [p   x V]
%                .tstat  [p   x V]
%                .zstat  [p   x V]
%                .R2     [1   x V]
%   bmask    - [nx x ny] binary brain mask (same one used in prepare_data_matrix)
%
% Output:
%   remapped - struct with spatially remapped fields:
%                .betas  [p+1 x nx x ny]  beta maps (last slice = intercept)
%                .eta2   [p   x nx x ny]  partial eta² maps per predictor
%                .tstat  [p   x nx x ny]  t-statistic maps per predictor
%                .zstat  [p   x nx x ny]  z-statistic maps per predictor
%                .R2     [nx  x ny]        global R² map
%                .Xmodel [T x p]           z-scored design matrix (no intercept), copied from glm_est
%                .predictor_labels         copied from glm_est
%                .model_name               copied from glm_est
%
% See also: fonduta.glm.ols, fonduta.glm.engine, fonduta.glm.remap_vec

[nx, ny] = size(bmask);
maskIdx  = find(bmask(:));

remapped                  = struct();
remapped.betas            = remap_array(glm_est.betas,  maskIdx, nx, ny);
remapped.eta2             = remap_array(glm_est.eta2,   maskIdx, nx, ny);
remapped.tstat            = remap_array(glm_est.tstat,  maskIdx, nx, ny);
remapped.zstat            = remap_array(glm_est.zstat,  maskIdx, nx, ny);
remapped.R2               = squeeze(remap_array(glm_est.R2, maskIdx, nx, ny));
remapped.Xmodel           = glm_est.Xmodel;   % [T x p] z-scored design matrix, passed through as-is
remapped.predictor_labels = glm_est.predictor_labels;
remapped.model_name       = glm_est.model_name;

end


function out = remap_array(arr, maskIdx, nx, ny)
% Remap [k x V] voxel array to [k x nx x ny] spatial array.
% Non-brain positions are NaN.
k         = size(arr, 1);
out       = nan(k, nx * ny);
out(:, maskIdx) = arr;
out       = reshape(out, k, nx, ny);
end
