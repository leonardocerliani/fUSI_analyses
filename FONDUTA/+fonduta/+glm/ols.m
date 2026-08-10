function result = ols(model_name, PDI_3D, bmask, X, predictor_labels)
% fonduta.glm.ols  Fit OLS GLM on fUSI data and return spatially remapped results.
%
% User-facing function: takes raw 3-D fUSI data and returns 3-D spatial maps.
% Internally calls prepare_data_matrix → engine → remap_results.
%
% Inputs:
%   model_name       - string identifier (e.g., 'M1_StimOnly')
%   PDI_3D           - [nx x ny x T] preprocessed fUSI data (or a subset of it)
%   bmask            - [nx x ny] binary brain mask
%   X                - [T x p] design matrix of raw predictor signals (NO intercept)
%                      Each column is z-scored internally before fitting.
%   predictor_labels - {1 x p} cell array of predictor names
%
% Output:
%   result - struct with spatially mapped fields:
%       .betas            [p+1 x nx x ny]  beta maps; last row = intercept
%       .eta2             [p   x nx x ny]  partial eta² maps per predictor
%       .tstat            [p   x nx x ny]  t-statistic maps per predictor
%       .zstat            [p   x nx x ny]  z-statistic maps per predictor
%       .R2               [nx  x ny]       global model R² map
%       .predictor_labels {1 x p+1}        predictor names (last = 'intercept')
%       .model_name       string
%
% Example:
%   hrf_kernel = fonduta.signal.hrf(TR);
%   hrf        = @(ev) filter(hrf_kernel, 1, ev(:));
%   result     = fonduta.glm.ols('M1_StimOnly', PDI.PDI, bmask, hrf(stim), {'stim_hrf'});
%   eta2_map   = squeeze(result.eta2(1,:,:));  % [nx x ny]
%   R2_map     = result.R2;                    % [nx x ny]
%
% For correlations maps use:
%   corrMap = fonduta.glm.remap_vec(corr(x, Y), bmask);
%   where Y = fonduta.glm.prepare_data_matrix(PDI_3D, bmask)
%
% See also: fonduta.glm.engine, fonduta.glm.prepare_data_matrix,
%           fonduta.glm.remap_results, fonduta.glm.remap_vec

%% Extract [T x V] data matrix
Y = fonduta.glm.prepare_data_matrix(PDI_3D, bmask);

%% Fit GLM (engine works on [T x V])
glm_est = fonduta.glm.engine(model_name, Y, X, predictor_labels);

%% Remap to [* x nx x ny] spatial maps
result = fonduta.glm.remap_results(glm_est, bmask);

end
