function visualize_brain_mask(subAtlas, bmask, funcSliceIdx)
% VISUALIZE_BRAIN_MASK - Display anatomical slices with brain mask overlay
%
% Syntax:
%   visualize_brain_mask(subAtlas, bmask, funcSliceIdx)
%
% Description:
%   Creates a tiled figure showing all anatomical slices from the subject
%   atlas, with the brain mask overlaid in red on the functional slice.
%
% Inputs:
%   subAtlas     - Subject-space atlas structure with Region.Data field
%   bmask        - Binary brain mask [Y, X] (1 = brain, 0 = outside)
%   funcSliceIdx - Index of the functional slice to overlay mask on
%
% Example:
%   visualize_brain_mask(subAtlas, bmask, anatomic.funcSlice(3))

% Create figure with tiled layout
figure('Position', [100 100 1200 900]);
tiledlayout(5, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

% Get all slices
numSlices = size(subAtlas.Region.Data, 3);
sliceIdx = 1:numSlices;

% Display each slice
for i = 1:numSlices
    ax = nexttile;
    
    % Display anatomical slice in grayscale
    imagesc(subAtlas.Region.Data(:,:,sliceIdx(i)));
    colormap(ax, gray);
    axis(ax, 'square');
    hold(ax, 'on');
    
    % Overlay mask only on the functional slice
    if sliceIdx(i) == funcSliceIdx
        % Create red RGB overlay from binary mask
        redMask = cat(3, bmask, zeros(size(bmask)), zeros(size(bmask)));
        h = imshow(redMask, 'XData', [1 size(redMask,2)], 'YData', [1 size(redMask,1)]);
        set(h, 'AlphaData', bmask * 0.3);
        axis(ax, 'square');
    end
    
    title(ax, ['Slice ' num2str(sliceIdx(i))]);
end

sgtitle('Subject Anatomy with Brain Mask Overlay');

end