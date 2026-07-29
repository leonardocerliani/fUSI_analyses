function pc1 = compute_pc1(PDI3D, mask2D)
% fonduta.signal.compute_pc1  First principal component time course from masked voxels.
%
% Extracts all voxels inside mask2D, z-scores each voxel over time, runs
% PCA and returns the first PC as a z-scored time course.
%
% Inputs:
%   PDI3D  - [nx x ny x nt] fUSI data array
%   mask2D - [nx x ny] logical (or numeric) mask; non-zero voxels are included
%
% Output:
%   pc1    - [nt x 1] z-scored first PC time course
%            Returns zeros(nt,1) if fewer than 2 valid voxels exist.

    [nx, ny, nt] = size(PDI3D);

    if ~isequal(size(mask2D), [nx, ny])
        error('fonduta:signal:compute_pc1:DimensionMismatch', ...
              'mask2D size [%d %d] does not match PDI3D [%d %d].', ...
              size(mask2D,1), size(mask2D,2), nx, ny);
    end

    % Reshape to [nt x nVoxels] and select masked voxels
    Ymat    = reshape(PDI3D, nx * ny, nt)';   % [nt x nVoxels]
    maskVec = mask2D(:) > 0;
    Ymask   = Ymat(:, maskVec);               % [nt x nMasked]

    % Remove invalid voxels (non-finite or constant over time)
    validVox = all(isfinite(Ymask), 1) & std(Ymask, 0, 1) > eps;
    Ymask    = Ymask(:, validVox);

    if isempty(Ymask) || size(Ymask, 2) < 2
        warning('fonduta:signal:compute_pc1:NotEnoughVoxels', ...
                'Not enough valid voxels. Returning zeros.');
        pc1 = zeros(nt, 1);
        return
    end

    % Z-score each voxel over time before PCA
    YmaskZ = zscore(Ymask, 0, 1);
    YmaskZ(:, any(~isfinite(YmaskZ), 1)) = [];   % drop any remaining NaN columns

    if isempty(YmaskZ) || size(YmaskZ, 2) < 2
        warning('fonduta:signal:compute_pc1:NotEnoughVoxels', ...
                'Not enough finite z-scored voxels. Returning zeros.');
        pc1 = zeros(nt, 1);
        return
    end

    % PCA — extract first component
    [~, score] = pca(YmaskZ, 'NumComponents', 1);
    pc1        = zscore(score(:, 1));

    if any(~isfinite(pc1))
        warning('fonduta:signal:compute_pc1:NaNinPC1', ...
                'PC1 contains NaN/Inf. Returning zeros.');
        pc1 = zeros(nt, 1);
    end

end
