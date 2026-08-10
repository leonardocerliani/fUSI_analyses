function [bmask, nonBrainMask, allen_regions] = build_slice_masks(anatomic, Transf)
% fonduta.atlas.build_slice_masks  Generate binary brain masks for the functional slice.
%
% Maps the Allen Brain Atlas into the subject's fUSI space via
% fonduta.atlas.atlas2individual, extracts the functional slice, and creates:
%   - bmask        : dilated binary brain mask (1 = brain)
%   - nonBrainMask : logical complement of bmask (1 = outside brain)
%   - allen_regions: integer map of Allen Brain Atlas region IDs in subject space
%
% All outputs are 2D [nx x ny] — they correspond to the single 2D functional
% slice (anatomic.funcSlice), not the full 3D anatomical volume.
%
% Inputs:
%   anatomic - anatomical struct loaded from anatomic.mat
%              Must contain: .funcSlice (index of functional slice in atlas space)
%   Transf   - registration transformation struct loaded from Transformation.mat
%
% Outputs:
%   bmask         - [nx x ny] double binary mask (0/1); brain voxels = 1
%   nonBrainMask  - [nx x ny] logical mask; non-brain voxels = true
%   allen_regions - [nx x ny] int16 map of Allen Brain Atlas region IDs in subject
%                   space. Cross-reference with atlas.infoRegions.acr / .name
%                   (from fonduta.atlas.load_atlas()) to get region names.
%                   Region ID 0 = outside atlas coverage.
%
% Notes:
%   Loads allen_brain_atlas.mat from the same directory as this .m file.
%   This makes the atlas self-contained regardless of where FONDUTA is installed.
%   The brain mask is dilated by a disk of radius 2 pixels to include
%   border voxels that may have been clipped during registration.
%
% See also: fonduta.atlas.atlas2individual, fonduta.atlas.load_atlas

    %% Load atlas (path-independent via load_atlas)
    atlas = fonduta.atlas.load_atlas();

    %% Map atlas to subject space, extract functional slice
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

    %% Allen region IDs in subject space (before binarization)
    allen_regions = subRegions;

end
