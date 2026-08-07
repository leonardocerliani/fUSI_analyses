function view_image(bg, overlay, dim, alpha)
%VIEW_IMAGE Interactive slice viewer for 3-D image volumes.
%
%   fonduta.viz.view_image(BG)
%       Displays the 3-D volume BG as a grayscale image stack.
%       Scroll through slices using the mouse wheel.
%
%   fonduta.viz.view_image(BG, OVERLAY)
%       Displays OVERLAY on top of BG using a hot colormap with
%       adjustable transparency. Zero-valued voxels in OVERLAY are
%       displayed as transparent.
%
%   fonduta.viz.view_image(BG, OVERLAY, DIM)
%       Selects the slicing direction:
%           DIM = 1 : sagittal
%           DIM = 2 : coronal (default)
%           DIM = 3 : axial
%
%   fonduta.viz.view_image(BG, OVERLAY, DIM, ALPHA)
%       Sets overlay transparency (default: 0.5).
%
%   DESCRIPTION
%       This function provides a simple interactive viewer for registered
%       3-D image volumes. The background image is displayed using a
%       grayscale colormap, while the optional overlay is displayed using
%       a hot colormap with independent transparency.
%
%   IMPORTANT
%       BG and OVERLAY must already be in the same voxel space.
%       The function assumes that both volumes have:
%           - identical dimensions
%           - identical orientation
%           - identical voxel spacing and slice ordering
%
%       No registration, resampling, or spatial transformation is
%       performed by this function.
%
%   EXAMPLES
%
%       % View anatomical volume only
%       fonduta.viz.view_image(atlas.Histology)
%
%       % View anatomical volume with registered overlay
%       fonduta.viz.view_image(atlas.Histology, vol_anatomic2atlas)
%
%       % View coronal slices with 70% overlay transparency
%       fonduta.viz.view_image(atlas.Histology, ...
%                              vol_anatomic2atlas, ...
%                              2, 0.7)
%
%   See also IMAGESC, COLORMAP, NIFTIREAD

if nargin < 2
    overlay = [];
end
if nargin < 3
    dim = 2;
end
if nargin < 4
    alpha = 0.5;
end

nSlices = size(bg, dim);
slice = round(nSlices/2);

fig = figure('Name','Overlay Slice Viewer');
set(fig,'WindowScrollWheelFcn',@scrollFcn);

ax1 = axes('Position',[0.05 0.05 0.9 0.9]);

if ~isempty(overlay)
    ax2 = axes('Position',ax1.Position,...
        'Color','none',...
        'Visible','off');
end

updateSlice();

    function scrollFcn(~,evt)
        slice = min(max(slice + evt.VerticalScrollCount,1), nSlices);
        updateSlice();
    end

    function updateSlice()

        switch dim
            case 1
                bgSlice = squeeze(bg(slice,:,:));
                if ~isempty(overlay), ovSlice = squeeze(overlay(slice,:,:)); end
            case 2
                bgSlice = squeeze(bg(:,slice,:));
                if ~isempty(overlay), ovSlice = squeeze(overlay(:,slice,:)); end
            case 3
                bgSlice = squeeze(bg(:,:,slice));
                if ~isempty(overlay), ovSlice = squeeze(overlay(:,:,slice)); end
        end

        cla(ax1)
        imagesc(ax1, bgSlice)
        axis(ax1,'image','off')
        colormap(ax1, gray)

        if ~isempty(overlay)
            cla(ax2)
            h = imagesc(ax2, ovSlice);
            axis(ax2,'image','off')
            colormap(ax2, hot)
            h.AlphaData = alpha * (ovSlice ~= 0);
            linkaxes([ax1 ax2])
        end

        title(ax1, sprintf('Slice %d / %d', slice, nSlices))
    end

end