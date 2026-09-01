function result = ols(model_name, PDI_3D, bmask, X, predictor_labels, contrasts, skip_zscore)
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
%   predictor_labels - {1 x p} cell array of predictor names
%   contrasts        - (optional) struct array for omnibus F-tests; see fonduta.glm.engine
%                      for the expected format.  Leave empty [] or omit to skip.
%   skip_zscore      - (optional, default false) logical.
%                      true  → skip z-scoring of X columns (required for FIR matrices).
%                      false → z-score each column of X before fitting (default).
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
%       .fcontrasts       struct (only when contrasts is supplied); see fonduta.glm.engine
%           .<name>.Fmap    [nx x ny]
%           .<name>.eta2_p  [nx x ny]
%           .<name>.df_effect scalar
%           .<name>.df_error  scalar
%
% Example (standard HRF model — no changes to existing call sites):
%   result = fonduta.glm.ols('M1_StimOnly', PDI.PDI, bmask, hrf(stim), {'stim_hrf'});
%
% Example (FIR model with F-contrasts):
%   B = fn.generate_fir_basis(stim_all, TR, 15, 12, 0.5, 'tent');  % [T x N]
%   N = size(B, 2);  p = N;
%   C = [eye(N), zeros(N, 1)];  % contrast for the N FIR columns (intercept last)
%   c.name = 'Visual_FIR';  c.C = C;
%   result = fonduta.glm.ols('F1_StimOnly', PDI.PDI, bmask, B, labels, c, true);
%
% For correlations maps use:
%   corrMap = fonduta.glm.remap_vec(corr(x, Y), bmask);
%   where Y = fonduta.glm.prepare_data_matrix(PDI_3D, bmask)
%
% See also: fonduta.glm.engine, fonduta.glm.prepare_data_matrix,
%           fonduta.glm.remap_results, fonduta.glm.remap_vec

%% Optional argument defaults
if nargin < 6
    contrasts = [];
end
if nargin < 7 || isempty(skip_zscore)
    skip_zscore = false;
end

%% Extract [T x V] data matrix
Y = fonduta.glm.prepare_data_matrix(PDI_3D, bmask);

%% Fit GLM (engine works on [T x V])
glm_est = fonduta.glm.engine(model_name, Y, X, predictor_labels, contrasts, skip_zscore);

%% Remap to [* x nx x ny] spatial maps
result = fonduta.glm.remap_results(glm_est, bmask);

end
