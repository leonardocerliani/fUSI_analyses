function Xz = zscore_safe(X)
% fonduta.glm.zscore_safe  Z-scores each column of X. Constant or all-NaN columns → zero.
%
% Inputs:
%   X  - [n x k] matrix or [n x 1] vector
%
% Output:
%   Xz - [n x k] z-scored matrix; constant / all-NaN columns become zeros
%
% Notes:
%   Uses omitnan statistics so a single NaN does not break the column.
%   After z-scoring, any remaining non-finite values are set to 0.

    Xz = X;

    for ii = 1:size(X, 2)

        col = X(:, ii);

        if all(~isfinite(col)) || std(col, 'omitnan') <= eps
            Xz(:, ii) = zeros(size(col));
        else
            mu    = mean(col, 'omitnan');
            sigma = std(col,  0, 'omitnan');
            Xz(:, ii) = (col - mu) ./ sigma;
            Xz(~isfinite(Xz(:, ii)), ii) = 0;
        end

    end

end
