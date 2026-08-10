function pc1Signals = extract_pc1_signals(PDI, bmask, nonBrainMask)
% fonduta.utils.extract_pc1_signals  Extract global and non-brain PC1 signals; residualise data.
%
% Computes the first principal component of:
%   1. The whole-image (global) signal across all voxels.
%   2. The non-brain background signal (outside the dilated brain mask).
%
% Also produces a hard-residualised version of PDI.PDI with the global
% PC1 regressed out from every voxel time series.
%
% Inputs:
%   PDI          - PDI data struct; must contain .PDI [nx x ny x nt]
%   bmask        - [nx x ny] binary brain mask (from fonduta.atlas.build_slice_masks)
%   nonBrainMask - [nx x ny] logical non-brain mask (from fonduta.atlas.build_slice_masks)
%
% Output:
%   pc1Signals - struct with fields:
%     .globalPC1        [nt x 1] z-scored first PC of whole image
%     .nonBrainPC1      [nt x 1] z-scored first PC of non-brain voxels
%     .YhardGlobalPC1   [nx x ny x nt] PDI.PDI with globalPC1 regressed out
%
% See also: fonduta.signal.compute_pc1, fonduta.glm.regress_out_nuisance

    [nx, ny, nt] = size(PDI.PDI);

    %% Global PC1 (all voxels, no masking)
    globalMask = true(nx, ny);
    globalPC1  = fonduta.signal.compute_pc1(PDI.PDI, globalMask);

    %% Non-brain PC1 (background voxels only)
    nonBrainPC1 = fonduta.signal.compute_pc1(PDI.PDI, nonBrainMask);

    %% Hard global PC1 removal: regress globalPC1 out of every voxel
    Ymat           = reshape(PDI.PDI, nx * ny, nt)';   % [nt x nVoxels]
    YmatResid      = fonduta.glm.regress_out_nuisance(Ymat, globalPC1);
    YhardGlobalPC1 = reshape(YmatResid', nx, ny, nt);

    %% Pack output
    pc1Signals.globalPC1      = globalPC1;
    pc1Signals.nonBrainPC1    = nonBrainPC1;
    pc1Signals.YhardGlobalPC1 = YhardGlobalPC1;

end
