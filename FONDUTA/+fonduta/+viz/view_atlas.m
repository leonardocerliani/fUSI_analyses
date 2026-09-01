function view_atlas()
% VIEW_ATLAS_OVERLAY Single coronal viewer with hot overlays, colorbar & CLim controls.
% atlas must be the struct of the allen atlas, available in the environment.
% overlays are .mat file containing *only* one 3d matrix of the same dimensions of the atlas

    % If no atlas argument is passed, attempt loading via package or workspace
    if nargin < 1 || isempty(atlas)
        try
            atlas = fonduta.atlas.load_atlas();
        catch
            if evalin('base', 'exist(''atlas'', ''var'')')
                atlas = evalin('base', 'atlas');
            else
                error('No atlas provided and fonduta.atlas.load_atlas() failed to execute.');
            end
        end
    end

    baseVol = atlas.Histology;
    volSize = size(baseVol);
    slice = round(volSize(2) / 2);
    crosshair = round(volSize / 2);
    showRegions = true;

    overlays = struct('data', {}, 'handle', {}, 'clim', {});
    regionHandles = [];
    crossHandles = [];
    cbarHandle = [];

    %% Figure & Layout
    fig = figure('Name', 'Coronal Overlay Viewer', ...
        'Position', [100 100 1000 750], 'Color', 'w', ...
        'WindowScrollWheelFcn', @scrollCallback, ...
        'WindowButtonDownFcn', @clickCallback);

    ax = axes('Parent', fig, 'Position', [0.08, 0.22, 0.75, 0.70]);

    % Initialize base image as truecolor RGB object
    hBase = image(ax, zeros([volSize(1) volSize(3) 3]));
    axis(ax, 'image', 'off');
    hold(ax, 'on');

    %% Control UI Elements
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Load Overlay (.mat)', ...
        'Units', 'normalized', 'Position', [0.08, 0.02, 0.18, 0.04], ...
        'FontSize', 10, 'Callback', @btnLoadOverlay);

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Overlays', ...
        'Units', 'normalized', 'Position', [0.27, 0.02, 0.15, 0.04], ...
        'FontSize', 10, 'Callback', @btnClearOverlays);

    uicontrol(fig, 'Style', 'togglebutton', 'String', 'Lines ON', ...
        'Value', 1, 'Units', 'normalized', 'Position', [0.43, 0.02, 0.12, 0.04], ...
        'FontSize', 10, 'Callback', @btnToggleLines);

    % Colorbar Limit Controls
    uicontrol(fig, 'Style', 'text', 'String', 'Overlay Min:', ...
        'Units', 'normalized', 'Position', [0.57, 0.02, 0.09, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');

    hMinBox = uicontrol(fig, 'Style', 'edit', 'String', '0', ...
        'Units', 'normalized', 'Position', [0.67, 0.02, 0.06, 0.04], ...
        'FontSize', 10, 'Callback', @btnUpdateCLim);

    uicontrol(fig, 'Style', 'text', 'String', 'Overlay Max:', ...
        'Units', 'normalized', 'Position', [0.74, 0.02, 0.09, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');

    hMaxBox = uicontrol(fig, 'Style', 'edit', 'String', '1', ...
        'Units', 'normalized', 'Position', [0.84, 0.02, 0.06, 0.04], ...
        'FontSize', 10, 'Callback', @btnUpdateCLim);

    txtInfo = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.08, 0.08, 0.82, 0.04], 'BackgroundColor', 'w', ...
        'FontSize', 12, 'HorizontalAlignment', 'left');

    updateDisplay();

    %% Callbacks
    function scrollCallback(~, event)
        slice = slice + event.VerticalScrollCount;
        slice = max(1, min(slice, volSize(2)));
        crosshair(2) = slice;
        updateDisplay();
    end

    function clickCallback(~, ~)
        if gca ~= ax, return; end
        cp = ax.CurrentPoint;

        z = round(cp(1,1));
        x = round(cp(1,2));

        if x >= 1 && x <= volSize(1) && z >= 1 && z <= volSize(3)
            crosshair = [x, slice, z];
            updateDisplay();
        end
    end

    function btnLoadOverlay(~, ~)
        [filename, filepath] = uigetfile('*.mat', 'Select Overlay MAT File', pwd);
        if isequal(filename, 0), return; end

        fullPath = fullfile(filepath, filename);
        matData = load(fullPath);
        fields = fieldnames(matData);

        newOverlay = [];
        for f = 1:numel(fields)
            candidate = matData.(fields{f});
            if isnumeric(candidate) && isequal(size(candidate), volSize)
                newOverlay = double(candidate);
                break;
            end
        end

        if isempty(newOverlay)
            fprintf('Error: No 3D matrix matching %s found in "%s".\n', ...
                mat2str(volSize), filename);
            return;
        end

        % Auto-calculate limits
        nonZeroVals = newOverlay(newOverlay > 0);
        if isempty(nonZeroVals)
            cMin = 0; cMax = 1;
        else
            cMin = min(nonZeroVals);
            cMax = prctile(nonZeroVals, 99);
            if cMin >= cMax, cMax = cMin + 1; end
        end

        hNew = image(ax, zeros([volSize(1) volSize(3) 3]));

        idx = numel(overlays) + 1;
        overlays(idx).data = newOverlay;
        overlays(idx).handle = hNew;
        overlays(idx).clim = [cMin cMax];

        hMinBox.String = num2str(cMin, '%g');
        hMaxBox.String = num2str(cMax, '%g');

        updateDisplay();
    end

    function btnClearOverlays(~, ~)
        for i = 1:numel(overlays)
            if isvalid(overlays(i).handle), delete(overlays(i).handle); end
        end
        overlays = struct('data', {}, 'handle', {}, 'clim', {});
        if ~isempty(cbarHandle) && isvalid(cbarHandle)
            delete(cbarHandle);
            cbarHandle = [];
        end
        updateDisplay();
    end

    function btnUpdateCLim(~, ~)
        if isempty(overlays), return; end

        valMin = str2double(hMinBox.String);
        valMax = str2double(hMaxBox.String);

        if isnan(valMin) || isnan(valMax) || valMin >= valMax
            disp('Invalid limits specified.');
            return;
        end

        overlays(end).clim = [valMin valMax];
        updateDisplay();
    end

    function btnToggleLines(src, ~)
        showRegions = get(src, 'Value');
        set(src, 'String', sprintf('Lines %s', ternary(showRegions, 'ON', 'OFF')));
        updateDisplay();
    end

    %% Display Routine
    function updateDisplay()
        % 1. Render base histology as TrueColor Grayscale RGB
        baseSlice = double(squeeze(baseVol(:, slice, :)));
        bMin = min(baseSlice(:)); bMax = max(baseSlice(:));
        if bMin == bMax, bMax = bMin + 1; end
        normBase = (baseSlice - bMin) / (bMax - bMin);
        idxBase = floor(normBase * 255) + 1;
        hBase.CData = ind2rgb(idxBase, gray(256));

        % 2. Truecolor overlay mapping with 'hot' colormap
        cmapHot = hot(256);
        for i = 1:numel(overlays)
            sData = squeeze(overlays(i).data(:, slice, :));
            cMin = overlays(i).clim(1);
            cMax = overlays(i).clim(2);

            normData = (sData - cMin) / (cMax - cMin);
            normData = max(0, min(1, normData));
            idxImg = floor(normData * 255) + 1;

            rgbImg = ind2rgb(idxImg, cmapHot);
            overlays(i).handle.CData = rgbImg;

            % Alpha mask for values above lower limit
            alphaMap = 0.6 * (sData > cMin);
            overlays(i).handle.AlphaData = alphaMap;

            uistack(overlays(i).handle, 'top');
        end

        % 3. Update Side Colorbar independently
        if ~isempty(overlays)
            colormap(ax, hot(256));
            
            if isempty(cbarHandle) || ~isvalid(cbarHandle)
                cbarHandle = colorbar(ax, 'Position', [0.85, 0.22, 0.025, 0.70]);
            end
            
            clim(ax, overlays(end).clim);
            cbarHandle.Label.String = 'Overlay Intensity';
            cbarHandle.FontSize = 10;
        end

        % 4. Redraw vector lines, crosshairs, and labels
        updateRegionLines();
        updateCrosshair();
        updateRegionInfo();

        title(ax, sprintf('Coronal Slice: %d / %d', slice, volSize(2)), 'FontSize', 14);
        drawnow;
    end

    function updateRegionLines()
        delete(regionHandles);
        regionHandles = [];

        if ~showRegions || ~isfield(atlas, 'Lines') || ~isfield(atlas.Lines, 'Cor')
            return;
        end

        if slice <= numel(atlas.Lines.Cor)
            L = atlas.Lines.Cor{slice};
            for i = 1:length(L)
                xy = L{i};
                regionHandles(end+1) = plot(ax, xy(:,2), xy(:,1), 'w', 'LineWidth', 1);
            end
        end
    end

    function updateCrosshair()
        delete(crossHandles);
        crossHandles = [];

        x = crosshair(1);
        z = crosshair(3);

        crossHandles(1) = xline(ax, z, 'r', 'LineWidth', 1.5);
        crossHandles(2) = yline(ax, x, 'r', 'LineWidth', 1.5);
    end

    function updateRegionInfo()
        voxelText = sprintf('Voxel [%d %d %d]', crosshair);
        regionText = '';

        inside = crosshair(1)>=1 && crosshair(1)<=size(atlas.Regions,1) && ...
                 crosshair(2)>=1 && crosshair(2)<=size(atlas.Regions,2) && ...
                 crosshair(3)>=1 && crosshair(3)<=size(atlas.Regions,3);

        if inside
            label = double(atlas.Regions(crosshair(1), crosshair(2), crosshair(3)));

            if label > 0 && label <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{label};
                name = atlas.infoRegions.name{label};
                regionText = sprintf('    ID: %d    %s: %s', label, acr, name);
            else
                regionText = '    Background';
            end
        end

        txtInfo.String = [voxelText regionText];
    end

    function out = ternary(cond, valT, valF)
        if cond, out = valT; else, out = valF; end
    end
end