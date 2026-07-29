function [bmask, nonBrainMask] = build_brain_masks(anatomic, Transf)
% fonduta.atlas.build_brain_masks  Generate binary brain and non-brain masks in subject space.
%
% Maps the Allen Brain Atlas into the subject's fUSI space via
% fonduta.atlas.atlas2individual, extracts the functional slice, and creates:
%   - bmask        : dilated binary brain mask (1 = brain)
%   - nonBrainMask : logical complement of bmask (1 = outside brain)
%
% Inputs:
%   anatomic - anatomical struct loaded from anatomic.mat
%              Must contain: .funcSlice (index of functional slice in atlas space)
%   Transf   - registration transformation struct loaded from Transformation.mat
%
% Outputs:
%   bmask        - [nx x ny] double binary mask (0/1); brain voxels = 1
%   nonBrainMask - [nx x ny] logical mask; non-brain voxels = true
%
% Notes:
%   Loads allen_brain_atlas.mat from the same directory as this .m file.
%   This makes the atlas self-contained regardless of where FONDUTA is installed.
%   The brain mask is dilated by a disk of radius 2 pixels to include
%   border voxels that may have been clipped during registration.

    %% Load atlas (path-independent via load_atlas)
    atlas = fonduta.atlas.load_atlas();

    %% Map atlas to subject space
    subAtlas   = fonduta.atlas.atlas2individual(atlas, anatomic, Transf);
    subRegions = subAtlas.Region.Data(:, :, anatomic.funcSlice(3));

    %% Create binary brain mask
    bmask           = double(subRegions);
    bmask(bmask <= 1) = 0;
    bmask(bmask > 0)  = 1;

    % Dilate by radius-2 disk to capture border voxels
    se    = strel('disk', 2);
    bmask = imdilate(bmask, se);

    %% Non-brain mask (complement of dilated brain mask)
    nonBrainMask = bmask == 0;

end
