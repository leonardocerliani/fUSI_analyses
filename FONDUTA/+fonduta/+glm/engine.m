function results = engine(model_name, Y, X, predictor_labels, contrasts, skip_zscore)
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
%   predictor_labels - {1 x p} cell array of predictor names (matched to X columns)
%   contrasts        - (optional) struct array for omnibus F-tests.
%                      Each element has fields:
%                        .name  - string label for this contrast (e.g. 'Visual_FIR')
%                        .C     - [N x (p+1)] contrast matrix.  Rows select the N
%                                 columns of Xfull (including intercept as last col)
%                                 that belong to this FIR block.
%                      Leave empty [] or omit to skip F-test computation.
%   skip_zscore      - (optional, default false) logical.
%                      false → each column of X is z-scored before fitting (default,
%                              preserves existing behaviour for HRF models).
%                      true  → X is used as-is (required for FIR design matrices
%                              whose columns are sparse tent/boxcar pulses; z-scoring
%                              would destroy their physical amplitude scale).
%
% Outputs:
%   results - struct with fields:
%       .betas            [p+1 x V]  parameter estimates
%       .eta2             [p x V]    partial eta² per predictor (excl. intercept)
%       .tstat            [p x V]    t-statistic per predictor (excl. intercept)
%       .zstat            [p x V]    z-statistic (from t via normal CDF) per predictor
%       .R2               [1 x V]    global model R²
%       .Xmodel           [T x p]    design matrix as used in fitting (z-scored or raw)
%       .predictor_labels {1 x p+1}  predictor names (last entry = 'intercept')
%       .model_name       string
%       .fcontrasts       struct  (only present when contrasts is supplied and non-empty)
%           .<name>.Fmap       [1 x V]  omnibus F-statistic across N contrast rows
%           .<name>.eta2_p     [1 x V]  partial eta² from F-test
%           .<name>.df_effect  scalar   numerator df  = N (rows of C)
%           .<name>.df_error   scalar   denominator df = T - (p+1)
%
% Note: This is a private engine function. Users should call fonduta.glm.ols()
%       which accepts 3-D PDI data and returns spatially remapped 3-D results.
%
% See also: fonduta.glm.ols, fonduta.glm.prepare_data_matrix, fonduta.glm.remap_results

%% Defaults for optional arguments
if nargin < 5
    contrasts = [];
end
if nargin < 6 || isempty(skip_zscore)
    skip_zscore = false;
end

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

%% Z-score each predictor column before fitting (skip for FIR matrices)
if ~skip_zscore
    X = fonduta.glm.zscore_safe(X);
end
Xmodel = X;   % save design matrix (no intercept) for result struct

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

%% T-statistics and z-statistics for each non-intercept predictor
%  df = T - (p+1)  [one df per predictor + intercept]
%  MSE   [1 x V]   = SSE_full / df
%  SE_j  [1 x V]   = sqrt(MSE * (X'X)^{-1}_{jj})
%  t_j   [1 x V]   = betas(j,:) ./ SE_j
%  z_j   [1 x V]   = norminv(tcdf(t_j, df))

df     = T - (p + 1);                          % scalar
MSE    = SSE_full / df;                        % [1 x V]
XtXinv = (Xfull' * Xfull) \ eye(p + 1);      % [p+1 x p+1] — same for all voxels

tstat = zeros(p, V);
zstat = zeros(p, V);

for j = 1:p
    SE          = sqrt(XtXinv(j,j) .* MSE);   % [1 x V]
    t_j         = betas(j,:) ./ SE;           % [1 x V]
    tstat(j,:)  = t_j;
    zstat(j,:)  = norminv(tcdf(t_j, df));     % [1 x V]
end

%% Omnibus F-tests for FIR contrast blocks (optional)
%
% For each contrast c with matrix C [N x (p+1)]:
%   iCXC = inv(C * XtXinv * C')      [N x N]
%   b_c  = C * betas                  [N x V]
%   F    = (b_c' * iCXC * b_c) / N / sigma2   vectorized over V
%        = sum(b_c .* (iCXC * b_c), 1) / N ./ sigma2
%   eta2_p = (F * N) / (F * N + df_error)

fcontrasts = struct();
has_contrasts = ~isempty(contrasts) && isstruct(contrasts);

if has_contrasts
    df_error = df;                              % = T - (p+1)
    sigma2   = SSE_full / df_error;            % [1 x V]

    for ci = 1:numel(contrasts)
        c    = contrasts(ci);
        C    = c.C;                            % [N x (p+1)]
        N_c  = size(C, 1);                     % number of contrast rows

        % Validate contrast dimensions
        if size(C, 2) ~= (p + 1)
            error('fonduta:glm:engine:ContrastDimMismatch', ...
                  'Contrast ''%s'' has %d columns but Xfull has %d columns (p+1=%d).', ...
                  c.name, size(C, 2), p+1, p+1);
        end

        A_cxc     = C * XtXinv * C';          % [N_c x N_c]  symmetric positive definite
        b_c       = C * betas;                 % [N_c x V]
        solved    = A_cxc \ b_c;              % [N_c x V]  numerically stable solve
        quad_form = sum(b_c .* solved, 1);    % [1 x V]  vectorized quadratic form

        F_map  = (quad_form / N_c) ./ sigma2; % [1 x V]
        eta2_p = (F_map * N_c) ./ (F_map * N_c + df_error);

        % Guard against NaN/Inf from zero-variance voxels
        F_map (isnan(F_map)  | isinf(F_map))  = 0;
        eta2_p(isnan(eta2_p) | isinf(eta2_p)) = 0;

        fcontrasts.(c.name).Fmap      = F_map;
        fcontrasts.(c.name).eta2_p    = eta2_p;
        fcontrasts.(c.name).df_effect = N_c;
        fcontrasts.(c.name).df_error  = df_error;
    end
end

%% Pack results
results                  = struct();
results.betas            = betas;
results.eta2             = eta2;
results.tstat            = tstat;
results.zstat            = zstat;
results.R2               = R2;
results.Xmodel           = Xmodel;   % [T x p] design matrix as used (z-scored or raw)
results.predictor_labels = predictor_labels;
results.model_name       = model_name;

if has_contrasts
    results.fcontrasts = fcontrasts;
end

end
