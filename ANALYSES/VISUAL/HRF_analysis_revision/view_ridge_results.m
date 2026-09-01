function view_ridge_results(atlas)
% VIEW_RIDGE_RESULTS Interactive coronal viewer for Ridge Regression HRF results.
%
% Visualizes estimated regional HRFs (FIR time nodes) recovered via Leave-One-Trial-Out 
% Ridge Regression and projects subject-averaged canonical HRF correlation maps 
% onto Allen Atlas coronal slices.
%
% USAGE:
%   view_ridge_results()
%   view_ridge_results(atlas)

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
    
    % Active Ridge Results Data Storage
    ridgeData = [];
    
    %% Figure & Layout Configuration
    fig = figure('Name', 'Coronal HRF Ridge Regression Viewer', ...
        'Position', [80 80 1350 750], 'Color', 'w', ...
        'WindowScrollWheelFcn', @scrollCallback, ...
        'WindowButtonDownFcn',   @clickCallback);

    % Top Banner: Loaded File Indicator
    txtFileStatus = uicontrol(fig, 'Style', 'text', ...
        'String', 'Loaded file: None', ...
        'Units', 'normalized', 'Position', [0.08, 0.96, 0.85, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 11, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    % Left Main Axes: Coronal View
    ax = axes('Parent', fig, 'Position', [0.10, 0.20, 0.44, 0.70]);
    
    % Right Side Axes: Time-Course Plot
    axTC = axes('Parent', fig, 'Position', [0.64, 0.20, 0.32, 0.70]);
    title(axTC, 'Estimated Regional HRF', 'FontSize', 12);
    xlabel(axTC, 'Time from onset (s)');
    ylabel(axTC, 'HRF Amplitude (a.u.)');
    grid(axTC, 'on');
    box(axTC, 'off');

    % Initialize base image as truecolor RGB object
    hBase = image(ax, zeros([volSize(1) volSize(3) 3]));
    axis(ax, 'image', 'off');
    hold(ax, 'on');

    %% Control UI Elements (Bottom Bar)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Load Ridge Results MAT', ...
        'Units', 'normalized', 'Position', [0.08, 0.02, 0.22, 0.04], ...
        'FontSize', 10, 'Callback', @btnLoadRidge);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Overlays', ...
        'Units', 'normalized', 'Position', [0.31, 0.02, 0.10, 0.04], ...
        'FontSize', 10, 'Callback', @btnClearOverlays);
    uicontrol(fig, 'Style', 'togglebutton', 'String', 'Lines ON', ...
        'Value', 1, 'Units', 'normalized', 'Position', [0.42, 0.02, 0.08, 0.04], ...
        'FontSize', 10, 'Callback', @btnToggleLines);

    % Smoothing Control
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
        'Position', [0.08, 0.09, 0.88, 0.07], 'BackgroundColor', 'w', ...
        'FontSize', 11, 'HorizontalAlignment', 'left');

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

    function btnLoadRidge(~, ~)
        [filename, filepath] = uigetfile('*.mat', 'Select Ridge Results MAT File', pwd);
        if isequal(filename, 0), return; end
        
        fullPath = fullfile(filepath, filename);
        S = load(fullPath);
        if ~isfield(S, 'regional_hrf') || ~isfield(S, 'lag_times_s')
            errordlg('Selected file is not a valid ridge_loo_*.mat result file.', 'Invalid File');
            return;
        end
        ridgeData = S;
        txtFileStatus.String = sprintf('Loaded file: %s', filename);
        
        corrMap = generateCorrelationMap(S);
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

    %% Helper: On-the-Fly 3D Correlation Map Generation
    function corrMap = generateCorrelationMap(S)
        dt = S.time_resampling;
        t  = S.lag_times_s(:);
        K  = numel(t);
        
        % Generate expected canonical HRF response aligned with onset (t >= 0)
        hrf_ch = fonduta.signal.hrf(dt, S.chaoyi_hrfParams);
        boxcar = double(t >= 0 & t <= S.stim_dur_s);
        
        ap_ch = conv(boxcar, hrf_ch);
        ap_ch = ap_ch(1:K);
        if max(ap_ch) > 0, ap_ch = ap_ch / max(ap_ch); end
        
        corrMap = nan(size(atlas.Regions));
        region_fields = fieldnames(S.regional_hrf);
        
        for fi = 1:numel(region_fields)
            reg  = S.regional_hrf.(region_fields{fi});
            HRF  = reg.hrf; % [K x nSub]
            nSub = size(HRF, 2);
            if size(HRF, 1) ~= K || nSub < 1, continue; end
            
            sims = arrayfun(@(s) corr(HRF(:,s), ap_ch, 'rows', 'complete'), 1:nSub);
            similarity = mean(sims, 'omitnan');
            
            acr_idx = find(strcmp(atlas.infoRegions.acr, reg.acr), 1);
            if isempty(acr_idx), continue; end
            corrMap(atlas.Regions == acr_idx) = similarity;
        end
    end

%% Helper: Plot Regional HRF & Compute Statistics
    function plotRegionTimeCourse()
        cla(axTC);
        inside = crosshair(1)>=1 && crosshair(1)<=volSize(1) && ...
                 crosshair(2)>=1 && crosshair(2)<=volSize(2) && ...
                 crosshair(3)>=1 && crosshair(3)<=volSize(3);
        if ~inside || isempty(ridgeData)
            title(axTC, 'Regional HRF (Load Ridge MAT & click a region)', 'FontSize', 11);
            return;
        end
        label = double(atlas.Regions(crosshair(1), crosshair(2), crosshair(3)));
        if label <= 0 || label > numel(atlas.infoRegions.acr)
            title(axTC, 'Background (No Region Selected)', 'FontSize', 11);
            return;
        end
        acr = atlas.infoRegions.acr{label};
        field = matlab.lang.makeValidName(acr);
        if ~isfield(ridgeData.regional_hrf, field)
            title(axTC, sprintf('Region %s (No data in Ridge MAT)', acr), 'FontSize', 11);
            return;
        end
        
        S   = ridgeData;
        reg = S.regional_hrf.(field);
        HRF = reg.hrf; % [K x nSub]
        nSub = size(HRF, 2);
        t   = S.lag_times_s(:);
        K   = numel(t);
        
        % Smoothing logic
        smooth_win_s = str2double(hSmoothBox.String);
        if isnan(smooth_win_s) || smooth_win_s < 0
            smooth_win_s = 0;
            hSmoothBox.String = '0';
        end
        if smooth_win_s > 0
            smooth_win_frames = max(1, round(smooth_win_s / S.time_resampling));
            HRF = movmean(HRF, smooth_win_frames, 1);
        end
        
        % -----------------------------------------------------------------
        % Pre-stimulus Baseline Subtraction (Zero-Anchoring)
        % Comment/uncomment this block to toggle baseline correction
        % -----------------------------------------------------------------
        base_idx = (t < 0);
        if any(base_idx)
            base_offset = mean(HRF(base_idx, :), 1); % [1 x nSub]
            HRF = HRF - base_offset;
        end
        % -----------------------------------------------------------------
        
        mu = mean(HRF, 2);
        se = std(HRF, 0, 2) / sqrt(nSub);

        % Canonical Model Predictions aligned to t >= 0
        dt     = S.time_resampling;
        hrf_ch = fonduta.signal.hrf(dt, S.chaoyi_hrfParams);
        boxcar = double(t >= 0 & t <= S.stim_dur_s);
        
        ap_ch = conv(boxcar, hrf_ch);
        ap_ch = ap_ch(1:K);
        if max(ap_ch) > 0, ap_ch = ap_ch / max(ap_ch); end

        hrf_c23 = fonduta.signal.hrf(dt, S.chen2023_hrfParams);
        ap_c23  = conv(boxcar, hrf_c23);
        ap_c23  = ap_c23(1:K);
        if max(ap_c23) > 0, ap_c23 = ap_c23 / max(ap_c23); end

        % Subject-level Correlation Statistics
        sims_ch  = arrayfun(@(s) corr(HRF(:,s), ap_ch,  'rows', 'complete'), 1:nSub);
        sims_c23 = arrayfun(@(s) corr(HRF(:,s), ap_c23, 'rows', 'complete'), 1:nSub);

        mean_ch  = mean(sims_ch,  'omitnan');
        std_ch   = std(sims_ch, 0, 'omitnan');
        mean_c23 = mean(sims_c23, 'omitnan');
        std_c23  = std(sims_c23, 0, 'omitnan');

        % Scale canonical HRF for display matching empirical peak
        ap_ch_plot = ap_ch * max(mu);

        hold(axTC, 'on');
        % Stimulus period shading (0 to stim_dur_s)
        y_lo = min(mu-se) - 0.05;
        y_hi = max(mu+se) + 0.05;
        fill(axTC, [0, S.stim_dur_s, S.stim_dur_s, 0], ...
             [y_lo y_lo y_hi y_hi], [0.9 0.95 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        % Mean ± SE shaded region
        fill(axTC, [t; flipud(t)], ...
             [mu+se; flipud(mu-se)], [0.2 0.4 0.8], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
        % Time course plot line and canonical HRF
        plot(axTC, t, mu, 'b-', 'LineWidth', 2);
        plot(axTC, t, ap_ch_plot, 'k--', 'LineWidth', 1.8);
        xline(axTC, 0, ':k', 'onset', 'LineWidth', 1);
        xline(axTC, S.stim_dur_s, ':k', 'offset', 'LineWidth', 1);
        yline(axTC, 0, ':k', 'LineWidth', 0.8);
        hold(axTC, 'off');
        
        xlim(axTC, [min(t) max(t)]);
        xlabel(axTC, 'Time from onset (s)');
        ylabel(axTC, 'HRF Amplitude (a.u.)');
        title(axTC, sprintf('[%s] %s -- %s (n=%d)', S.model_name, reg.acr, reg.name, nSub), ...
              'Interpreter', 'none', 'FontSize', 11);
        legend(axTC, {'stim period', '', 'mean \pm SE', 'canonical HRF'}, ...
               'Location', 'northeast', 'Interpreter', 'tex');
        grid(axTC, 'on');
        box(axTC, 'off');

        % Update Info Banner
        mean_lambda = mean(reg.lam);
        voxelText  = sprintf('Voxel [%d %d %d]', crosshair);
        regionText = sprintf('    ID: %d  |  %s: %s  (n=%d, mean \\lambda=%.2e)', ...
            label, reg.acr, reg.name, nSub, mean_lambda);
        corrText   = sprintf('\n\nChaoyi r: %.3f ± %.3f  |  Chen2023 r: %.3f ± %.3f', ...
            mean_ch, std_ch, mean_c23, std_c23);
        txtInfo.String = [voxelText regionText corrText];
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
        
        % 3. Update Side Colorbar
        if ~isempty(overlays)
            colormap(ax, hot(256));
            if isempty(cbarHandle) || ~isvalid(cbarHandle)
                cbarHandle = colorbar(ax, 'westoutside', 'Position', [0.05, 0.20, 0.02, 0.70]);
            end
            clim(ax, overlays(end).clim);
            cbarHandle.Label.String = 'Correlation (r)';
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
