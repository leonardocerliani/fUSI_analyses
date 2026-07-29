function results = engine(model_name, Y, X, predictor_labels)
% fonduta.glm.engine  Low-level OLS GLM on [T x V] matrices.
%
% Fits a General Linear Model for each voxel column. Computes betas, R²,
% and partial eta² for each predictor using the reduced-model approach:
%
%   eta²_j = max(0, SSE_reduced_j - SSE_full) / (max(0, SSE_reduced_j - SSE_full) + SSE_full)
%
% The intercept is auto-appended to X and is always the last column.
% Partial eta² is computed only for non-intercept predictors (rows 1..p of eta2).
%
% Inputs:
%   model_name       - string, model identifier (e.g., 'M1_StimOnly')
%   Y                - [T x V] data matrix (timepoints x voxels)
%   X                - [T x p] design matrix of raw predictor signals (NO intercept)
%                      Each column is z-scored internally before fitting
%   predictor_labels - {1 x p} cell array of predictor names (matched to X columns)
%
% Outputs:
%   results - struct with fields:
%       .betas            [p+1 x V]  parameter estimates
%       .eta2             [p x V]    partial eta² per predictor (excl. intercept)
%       .R2               [1 x V]    global model R²
%       .predictor_labels {1 x p+1}  predictor names (last entry = 'intercept')
%       .model_name       string
%
% Note: This is a private engine function. Users should call fonduta.glm.ols()
%       which accepts 3-D PDI data and returns spatially remapped 3-D results.
%
% See also: fonduta.glm.ols, fonduta.glm.prepare_data_matrix, fonduta.glm.remap_results

%% Validate inputs
[T, p] = size(X);
V      = size(Y, 2);

if size(Y, 1) ~= T
    error('fonduta:glm:engine:DimensionMismatch', 'Y must have %d rows to match X', T);
end
if ~iscell(predictor_labels) || length(predictor_labels) ~= p
    error('fonduta:glm:engine:LabelMismatch', ...
          'predictor_labels must be a cell array with %d elements', p);
end

%% Z-score each predictor column before fitting
X = fonduta.glm.zscore_safe(X);

%% Auto-append intercept (always last column)
Xfull            = [X, ones(T, 1)];
predictor_labels = [predictor_labels, {'intercept'}];

%% Full model OLS solve (vectorized across all voxels)
betas    = Xfull \ Y;                          % [p+1 x V]
fitted   = Xfull * betas;                      % [T x V]
SSE_full = sum((Y - fitted).^2, 1);            % [1 x V]

%% R² (global model fit)
SS_total        = sum((Y - mean(Y, 1)).^2, 1); % [1 x V]
R2              = 1 - SSE_full ./ SS_total;
R2(SS_total == 0) = 0;

%% Partial eta² for each non-intercept predictor (reduced-model approach)
eta2 = zeros(p, V);

for j = 1:p
    Xred    = Xfull(:, [1:j-1, j+1:end]);     % [T x p] — drop predictor j
    breds   = Xred \ Y;
    SSE_red = sum((Y - Xred * breds).^2, 1);   % [1 x V]

    ssUnique     = max(0, SSE_red - SSE_full);
    denom        = ssUnique + SSE_full;
    eta2(j, :)   = ssUnique ./ denom;
    eta2(j, denom == 0) = 0;
end

%% Pack results
results                  = struct();
results.betas            = betas;
results.eta2             = eta2;
results.R2               = R2;
results.predictor_labels = predictor_labels;
results.model_name       = model_name;

end
