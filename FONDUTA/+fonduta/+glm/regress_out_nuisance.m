function Yres = regress_out_nuisance(Y, nuisance)
% fonduta.glm.regress_out_nuisance  Remove nuisance regressors from every column of Y.
%
% Fits an OLS model Y ~ intercept + nuisance for each voxel column and
% returns the residuals. The intercept is included so the mean of each
% time series is removed along with the nuisance.
%
% Inputs:
%   Y        - [nt x nVoxels] data matrix
%   nuisance - [nt x k] nuisance predictor matrix
%              Pass [] to return Y unchanged.
%
% Output:
%   Yres     - [nt x nVoxels] residualised data (same size as Y)
%
% Notes:
%   Rows with non-finite nuisance values are excluded from the regression
%   and preserved unchanged in the output.
%   Nuisance predictors are z-scored before fitting.

    if isempty(nuisance)
        Yres = Y;
        return
    end

    nuisance = nuisance(:, :);   % ensure 2-D

    if size(nuisance, 1) ~= size(Y, 1)
        error('fonduta:glm:regress_out_nuisance:DimensionMismatch', ...
              'nuisance and Y must have the same number of rows.');
    end

    validRows = all(isfinite(nuisance), 2);

    Yres = NaN(size(Y));

    X      = fonduta.glm.zscore_safe(nuisance(validRows, :));
    X      = [ones(size(X, 1), 1), X];
    Yvalid = Y(validRows, :);

    % Replace isolated NaN voxel values with column mean for stability
    for iv = 1:size(Yvalid, 2)
        y = Yvalid(:, iv);
        if any(~isfinite(y))
            y(~isfinite(y)) = mean(y, 'omitnan');
            Yvalid(:, iv)   = y;
        end
    end

    B              = X \ Yvalid;
    YhatNuisance   = X(:, 2:end) * B(2:end, :);   % exclude intercept from subtraction
    Yres(validRows, :) = Yvalid - YhatNuisance;

    % Preserve original invalid rows
    if any(~validRows)
        Yres(~validRows, :) = Y(~validRows, :);
    end

end
