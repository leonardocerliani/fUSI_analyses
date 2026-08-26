function view_simple_average_results(atlas)
% VIEW_ATLAS Enhanced coronal viewer with dynamic HRF correlation maps,
% customizable time-course smoothing, and non-overlapping layout.

    %% Load Atlas if not supplied
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

    baseVol   = atlas.Histology;
    volSize   = size(baseVol);
    slice     = round(volSize(2) / 2);
    crosshair = round(volSize / 2);
    
    showRegions = true;
    overlays    = struct('data', {}, 'handle', {}, 'clim', {});
    
    regionHandles = [];
    crossHandles  = [];
    cbarHandle    = [];

    % Active Simple-Average Data Storage
    simpleAvgData = [];

    %% Figure & Layout Configuration
    fig = figure('Name', 'Coronal HRF & Overlay Viewer', ...
        'Position', [80 80 1350 750], 'Color', 'w', ...
        'WindowScrollWheelFcn', @scrollCallback, ...
        'WindowButtonDownFcn',   @clickCallback);

    % Top Banner: Loaded File Indicator
    txtFileStatus = uicontrol(fig, 'Style', 'text', ...
        'String', 'Loaded file: None', ...
        'Units', 'normalized', 'Position', [0.08, 0.94, 0.85, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    % Left Main Axes: Coronal View (shifted right to leave room for left colorbar)
    ax = axes('Parent', fig, 'Position', [0.08, 0.22, 0.45, 0.68]);
    
    % Right Side Axes: Time-Course Plot
    axTC = axes('Parent', fig, 'Position', [0.61, 0.22, 0.35, 0.68]);
    title(axTC, 'Regional Time Course', 'FontSize', 12);
    xlabel(axTC, 'Time relative to onset (s)');
    ylabel(axTC, '$\Delta P / P_0$ (\% CBV change)', 'Interpreter', 'latex');
    grid(axTC, 'on');
    box(axTC, 'off');

    % Initialize base image as truecolor RGB object
    hBase = image(ax, zeros([volSize(1) volSize(3) 3]));
    axis(ax, 'image', 'off');
    hold(ax, 'on');

    %% Control UI Elements (Bottom Bar)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Load simple average results mat', ...
        'Units', 'normalized', 'Position', [0.08, 0.02, 0.22, 0.04], ...
        'FontSize', 10, 'Callback', @btnLoadSimpleAvg);

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Overlays', ...
        'Units', 'normalized', 'Position', [0.31, 0.02, 0.10, 0.04], ...
        'FontSize', 10, 'Callback', @btnClearOverlays);

    uicontrol(fig, 'Style', 'togglebutton', 'String', 'Lines ON', ...
        'Value', 1, 'Units', 'normalized', 'Position', [0.42, 0.02, 0.08, 0.04], ...
        'FontSize', 10, 'Callback', @btnToggleLines);

    % Time Course Smoothing Control Box
    uicontrol(fig, 'Style', 'text', 'String', 'Smooth (s):', ...
        'Units', 'normalized', 'Position', [0.51, 0.02, 0.07, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hSmoothBox = uicontrol(fig, 'Style', 'edit', 'String', '5', ...
        'Units', 'normalized', 'Position', [0.585, 0.02, 0.045, 0.04], ...
        'FontSize', 10, 'Callback', @(~,~) plotRegionTimeCourse());

    % Colorbar Limit Controls
    uicontrol(fig, 'Style', 'text', 'String', 'Overlay Min:', ...
        'Units', 'normalized', 'Position', [0.64, 0.02, 0.07, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hMinBox = uicontrol(fig, 'Style', 'edit', 'String', '0', ...
        'Units', 'normalized', 'Position', [0.715, 0.02, 0.05, 0.04], ...
        'FontSize', 10, 'Callback', @btnUpdateCLim);

    uicontrol(fig, 'Style', 'text', 'String', 'Overlay Max:', ...
        'Units', 'normalized', 'Position', [0.77, 0.02, 0.07, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hMaxBox = uicontrol(fig, 'Style', 'edit', 'String', '1', ...
        'Units', 'normalized', 'Position', [0.845, 0.02, 0.05, 0.04], ...
        'FontSize', 10, 'Callback', @btnUpdateCLim);

    % Info Banner below image
    txtInfo = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.08, 0.10, 0.88, 0.04], 'BackgroundColor', 'w', ...
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
            plotRegionTimeCourse();
        end
    end

    function btnLoadSimpleAvg(~, ~)
        [filename, filepath] = uigetfile('*.mat', 'Select Simple-Average MAT File', pwd);
        if isequal(filename, 0), return; end
        
        fullPath = fullfile(filepath, filename);
        S = load(fullPath);

        if ~isfield(S, 'regional_avg') || ~isfield(S, 'TR_mean')
            errordlg('Selected file is not a valid simple_avg_*.mat result file.', 'Invalid File');
            return;
        end

        simpleAvgData = S;
        txtFileStatus.String = sprintf('Loaded file: %s', filename);

        % Generate 3D correlation map
        corrMap = generateCorrelationMap(S);

        % Clear existing overlays before registering new result
        btnClearOverlays();
        addOverlay(corrMap);
        plotRegionTimeCourse();
    end

    function addOverlay(mapData)
        nonZeroVals = mapData(~isnan(mapData) & mapData > 0);
        if isempty(nonZeroVals)
            cMin = 0; cMax = 1;
        else
            cMin = min(nonZeroVals);
            cMax = prctile(nonZeroVals, 99);
            if cMin >= cMax, cMax = cMin + 1; end
        end

        hNew = image(ax, zeros([volSize(1) volSize(3) 3]));
        idx = numel(overlays) + 1;
        overlays(idx).data   = mapData;
        overlays(idx).handle = hNew;
        overlays(idx).clim   = [cMin cMax];

        hMinBox.String = num2str(cMin, '%.2f');
        hMaxBox.String = num2str(cMax, '%.2f');
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

    %% Helper: On-the-Fly 3D Map Generation
    function corrMap = generateCorrelationMap(S)
        stim_frames   = round(S.stim_dur_s / S.TR_mean);
        before_frames = round(S.before_stim_onset / S.TR_mean);
        after_frames  = round(S.after_stim_offset / S.TR_mean);
        W             = before_frames + stim_frames + after_frames;

        boxcar = [zeros(before_frames,1); ones(stim_frames,1); zeros(after_frames,1)];
        hrf_ch = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);

        ap_ch = conv(boxcar, hrf_ch);
        ap_ch = ap_ch(1:W);
        ap_ch = ap_ch / max(ap_ch);

        corrMap = nan(size(atlas.Regions));
        region_fields = fieldnames(S.regional_avg);

        for fi = 1:numel(region_fields)
            reg  = S.regional_avg.(region_fields{fi});
            TC   = reg.tc;
            nSub = size(TC, 2);

            if size(TC, 1) ~= W || nSub < 1, continue; end

            sims = arrayfun(@(s) corr(TC(:,s), ap_ch, 'rows', 'complete'), 1:nSub);
            similarity = mean(sims, 'omitnan');

            acr_idx = find(strcmp(atlas.infoRegions.acr, reg.acr), 1);
            if isempty(acr_idx), continue; end

            corrMap(atlas.Regions == acr_idx) = similarity;
        end
    end

    %% Helper: Plot Time Course with Optional Moving-Average Smoothing
    function plotRegionTimeCourse()
        cla(axTC);
        inside = crosshair(1)>=1 && crosshair(1)<=volSize(1) && ...
                 crosshair(2)>=1 && crosshair(2)<=volSize(2) && ...
                 crosshair(3)>=1 && crosshair(3)<=volSize(3);

        if ~inside || isempty(simpleAvgData)
            title(axTC, 'Regional Time Course (Load simple average results mat & click a region)', 'FontSize', 11);
            return;
        end

        label = double(atlas.Regions(crosshair(1), crosshair(2), crosshair(3)));
        if label <= 0 || label > numel(atlas.infoRegions.acr)
            title(axTC, 'Background (No Region Selected)', 'FontSize', 11);
            return;
        end

        acr = atlas.infoRegions.acr{label};
        field = matlab.lang.makeValidName(acr);

        if ~isfield(simpleAvgData.regional_avg, field)
            title(axTC, sprintf('Region %s (No data in simple-avg MAT)', acr), 'FontSize', 11);
            return;
        end

        S   = simpleAvgData;
        reg = S.regional_avg.(field);
        TC  = reg.tc;
        nSub = size(TC, 2);

        % Smoothing logic matching opts.smooth_win_s
        smooth_win_s = str2double(hSmoothBox.String);
        if isnan(smooth_win_s) || smooth_win_s < 0
            smooth_win_s = 0;
            hSmoothBox.String = '0';
        end

        if smooth_win_s > 0
            smooth_win_frames = max(1, round(smooth_win_s / S.TR_mean));
            TC = movmean(TC, smooth_win_frames, 1);
        end

        mu = mean(TC, 2);
        se = std(TC, 0, 2) / sqrt(nSub);

        stim_frames   = round(S.stim_dur_s / S.TR_mean);
        before_frames = round(S.before_stim_onset / S.TR_mean);
        after_frames  = round(S.after_stim_offset / S.TR_mean);
        W             = before_frames + stim_frames + after_frames;

        boxcar = [zeros(before_frames,1); ones(stim_frames,1); zeros(after_frames,1)];
        hrf_ch = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);

        ap_ch = conv(boxcar, hrf_ch);
        ap_ch = ap_ch(1:W);
        ap_ch = ap_ch / max(ap_ch) * max(abs(mu));

        hold(axTC, 'on');

        % Stimulus period shading
        y_lo = min(mu-se) - 0.05;
        y_hi = max(mu+se) + 0.05;
        fill(axTC, [0, S.stim_dur_s, S.stim_dur_s, 0], ...
             [y_lo y_lo y_hi y_hi], [0.9 0.95 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.6);

        % Mean ± SE shaded error region
        fill(axTC, [S.t_window, fliplr(S.t_window)], ...
             [mu+se; flipud(mu-se)]', [0.2 0.4 0.8], 'FaceAlpha', 0.25, 'EdgeColor', 'none');

        % Time course plot line and model HRF
        plot(axTC, S.t_window, mu, 'b-', 'LineWidth', 2);
        plot(axTC, S.t_window, ap_ch, 'k--', 'LineWidth', 1.8);

        xline(axTC, 0, ':k', 'onset', 'LineWidth', 1);
        xline(axTC, S.stim_dur_s, ':k', 'offset', 'LineWidth', 1);
        yline(axTC, 0, ':k', 'LineWidth', 0.8);

        hold(axTC, 'off');

        xlabel(axTC, 'Time relative to onset (s)');
        ylabel(axTC, '$\Delta P / P_0$ (\% CBV change)', 'Interpreter', 'latex');
        title(axTC, sprintf('[%s] %s -- %s (n=%d)', S.model_name, reg.acr, reg.name, nSub), ...
              'Interpreter', 'none', 'FontSize', 11);
        legend(axTC, {'stim period', '', 'mean \pm SE', 'canonical HRF'}, ...
               'Location', 'northeast', 'Interpreter', 'tex');
        grid(axTC, 'on');
        box(axTC, 'off');
    end

    %% Main Display Routine
    function updateDisplay()
        % 1. Render base histology
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
            
            % Alpha mask for values above min limit (ignoring NaNs)
            alphaMap = 0.6 * (sData > cMin & ~isnan(sData));
            overlays(i).handle.AlphaData = alphaMap;
            uistack(overlays(i).handle, 'top');
        end

        % 3. Update Side Colorbar (Positioned to the LEFT of the coronal slice image)
        if ~isempty(overlays)
            colormap(ax, hot(256));
            if isempty(cbarHandle) || ~isvalid(cbarHandle)
                cbarHandle = colorbar(ax, 'westoutside', 'Position', [0.035, 0.22, 0.02, 0.68]);
            end
            clim(ax, overlays(end).clim);
            cbarHandle.Label.String = 'Overlay Intensity';
            cbarHandle.FontSize = 10;
        end

        % 4. Redraw vector lines, crosshairs, and labels
        updateRegionLines();
        updateCrosshair();
        updateRegionInfo();
        title(ax, sprintf('Coronal Slice: %d / %d', slice, volSize(2)), 'FontSize', 13);
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
        inside = crosshair(1)>=1 && crosshair(1)<=volSize(1) && ...
                 crosshair(2)>=1 && crosshair(2)<=volSize(2) && ...
                 crosshair(3)>=1 && crosshair(3)<=volSize(3);
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