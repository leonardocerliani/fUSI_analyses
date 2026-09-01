function view_eHRF_cHRF_corr_peristimulus(model_name, atlas)
% VIEW_EHRF_CHRF_CORR_PERISTIMULUS Interactive viewer for eHRF vs cHRF peristimulus correlation.
%
% USAGE:
%   view_eHRF_cHRF_corr_peristimulus('M5_Behavior')
%   view_eHRF_cHRF_corr_peristimulus('M5_Behavior', atlas)

    root_dir = '/data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL/HRF_analysis_revision';

    %% Handle Input Arguments
    if nargin < 1 || isempty(model_name)
        model_name = 'M5_Behavior';
    end
    
    if nargin < 2 || isempty(atlas)
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
    
    eHRFData = []; 
    cHRFData = []; 

    %% Figure & Layout Configuration
    fig = figure('Name', sprintf('eHRF vs cHRF Correlation Viewer [%s]', model_name), ...
        'Position', [80 80 1400 780], 'Color', 'w', ...
        'WindowScrollWheelFcn', @scrollCallback, ...
        'WindowButtonDownFcn',   @clickCallback);

    txtFileStatus = uicontrol(fig, 'Style', 'text', ...
        'String', 'Initializing files...', ...
        'Units', 'normalized', 'Position', [0.08, 0.95, 0.85, 0.04], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    % Selectors
    uicontrol(fig, 'Style', 'text', 'String', 'Metric:', ...
        'Units', 'normalized', 'Position', [0.08, 0.91, 0.05, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hMetricGroup = uibuttongroup(fig, 'Units', 'normalized', ...
        'Position', [0.14, 0.90, 0.22, 0.04], 'BackgroundColor', 'w', ...
        'SelectionChangedFcn', @(~,~) updateMapAndDisplay());
    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', 'Z score', ...
        'Units', 'normalized', 'Position', [0.05, 0.1, 0.45, 0.8], 'BackgroundColor', 'w', 'FontSize', 9, 'Value', 1);
    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', 'Simple difference', ...
        'Units', 'normalized', 'Position', [0.52, 0.1, 0.45, 0.8], 'BackgroundColor', 'w', 'FontSize', 9);

    uicontrol(fig, 'Style', 'text', 'String', 'Direction:', ...
        'Units', 'normalized', 'Position', [0.38, 0.91, 0.06, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hDirGroup = uibuttongroup(fig, 'Units', 'normalized', ...
        'Position', [0.45, 0.90, 0.25, 0.04], 'BackgroundColor', 'w', ...
        'SelectionChangedFcn', @(~,~) updateMapAndDisplay());
    uicontrol(hDirGroup, 'Style', 'radiobutton', 'String', 'eHRF > cHRF', ...
        'Units', 'normalized', 'Position', [0.05, 0.1, 0.45, 0.8], 'BackgroundColor', 'w', 'FontSize', 9, 'Value', 1);
    uicontrol(hDirGroup, 'Style', 'radiobutton', 'String', 'eHRF < cHRF', ...
        'Units', 'normalized', 'Position', [0.52, 0.1, 0.45, 0.8], 'BackgroundColor', 'w', 'FontSize', 9);

    ax = axes('Parent', fig, 'Position', [0.08, 0.18, 0.48, 0.70]);
    axTC = axes('Parent', fig, 'Position', [0.62, 0.18, 0.34, 0.70]);
    title(axTC, 'Regional Responses & Signal', 'FontSize', 12);
    xlabel(axTC, 'Time from onset (s)');
    ylabel(axTC, 'Amplitude (a.u.)');
    grid(axTC, 'on');
    box(axTC, 'off');

    hBase = image(ax, zeros([volSize(1) volSize(3) 3]));
    axis(ax, 'image', 'off');
    hold(ax, 'on');

    %% Control UI Elements
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reload Model Files', ...
        'Units', 'normalized', 'Position', [0.08, 0.02, 0.16, 0.04], ...
        'FontSize', 9, 'Callback', @(~,~) loadModelData(model_name));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Overlays', ...
        'Units', 'normalized', 'Position', [0.26, 0.02, 0.10, 0.04], ...
        'FontSize', 9, 'Callback', @btnClearOverlays);
    uicontrol(fig, 'Style', 'togglebutton', 'String', 'Lines ON', ...
        'Value', 1, 'Units', 'normalized', 'Position', [0.38, 0.02, 0.07, 0.04], ...
        'FontSize', 9, 'Callback', @btnToggleLines);

    uicontrol(fig, 'Style', 'text', 'String', 'Smooth (s):', ...
        'Units', 'normalized', 'Position', [0.47, 0.02, 0.06, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 9, 'HorizontalAlignment', 'right');
    hSmoothBox = uicontrol(fig, 'Style', 'edit', 'String', '5', ...
        'Units', 'normalized', 'Position', [0.535, 0.02, 0.035, 0.04], ...
        'FontSize', 9, 'Callback', @(~,~) plotRegionTimeCourse());

    uicontrol(fig, 'Style', 'text', 'String', 'Min:', ...
        'Units', 'normalized', 'Position', [0.59, 0.02, 0.04, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 9, 'HorizontalAlignment', 'right');
    hMinBox = uicontrol(fig, 'Style', 'edit', 'String', '-10', ...
        'Units', 'normalized', 'Position', [0.635, 0.02, 0.045, 0.04], ...
        'FontSize', 9, 'Callback', @btnUpdateCLim);
    uicontrol(fig, 'Style', 'text', 'String', 'Max:', ...
        'Units', 'normalized', 'Position', [0.69, 0.02, 0.04, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 9, 'HorizontalAlignment', 'right');
    hMaxBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units', 'normalized', 'Position', [0.735, 0.02, 0.045, 0.04], ...
        'FontSize', 9, 'Callback', @btnUpdateCLim);

    txtInfo = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.08, 0.08, 0.88, 0.08], 'BackgroundColor', 'w', ...
        'FontSize', 10, 'HorizontalAlignment', 'left');

    loadModelData(model_name);

    %% Data Loading
    function loadModelData(mName)
        ridge_dir  = fullfile(root_dir, 'results_ridge_loo');
        simple_dir = fullfile(root_dir, 'results_simple_average');

        ridge_pattern  = sprintf('ridge_loo_%s_eta003_HRF12s.mat', mName);
        simple_pattern = sprintf('simple_avg_%s_eta003.mat', mName);

        ridge_file  = findFileCaseInsensitive(ridge_dir, ridge_pattern);
        simple_file = findFileCaseInsensitive(simple_dir, simple_pattern);
        
        if isempty(ridge_file) || isempty(simple_file)
            errordlg(sprintf('Could not find files matching model %s in:\n%s\nor\n%s', mName, ridge_dir, simple_dir), 'File Error');
            return;
        end
        
        rData = load(ridge_file);
        sData = load(simple_file);
        
        if ~isfield(rData, 'regional_avg') || ~isfield(sData, 'regional_avg')
            errordlg('Loaded files missing regional_avg structure.', 'Structure Error');
            return;
        end
        
        eHRFData = rData;
        cHRFData = sData;
        
        txtFileStatus.String = sprintf('Model: %s | eHRF & cHRF loaded successfully', mName);
        updateMapAndDisplay();
    end

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

    function updateMapAndDisplay()
        if isempty(eHRFData) || isempty(cHRFData), return; end
        corrMap = generateComparisonMap();
        btnClearOverlays();
        addOverlay(corrMap);
        plotRegionTimeCourse();
    end

    function corrMap = generateComparisonMap()
        corrMap = nan(size(atlas.Regions));
        selMetric = get(hMetricGroup.SelectedObject, 'String');
        selDir    = get(hDirGroup.SelectedObject, 'String');
        
        common_regions = intersect(fieldnames(eHRFData.regional_avg), fieldnames(cHRFData.regional_avg));
        
        for fi = 1:numel(common_regions)
            regName = common_regions{fi};
            tc_e = eHRFData.regional_avg.(regName).tc;
            tc_c = cHRFData.regional_avg.(regName).tc;
            
            nSub = min(size(tc_e, 2), size(tc_c, 2));
            if nSub < 2, continue; end
            
            tc_e = tc_e(:, 1:nSub);
            tc_c = tc_c(:, 1:nSub);

            nTime_e = size(tc_e, 1);
            nTime_c = size(tc_c, 1);
            if nTime_e ~= nTime_c
                tc_c_interp = zeros(nTime_e, nSub);
                t_orig = linspace(0, 1, nTime_c);
                t_targ = linspace(0, 1, nTime_e);
                for s = 1:nSub
                    tc_c_interp(:, s) = interp1(t_orig, tc_c(:, s), t_targ, 'linear', 'extrap');
                end
                tc_c = tc_c_interp;
            end

            signal_e = mean(tc_e, 2, 'omitnan');
            signal_c = mean(tc_c, 2, 'omitnan');
            
            r_e = zeros(nSub, 1);
            r_c = zeros(nSub, 1);
            
            for s = 1:nSub
                r_e(s) = corr(tc_e(:, s), signal_e, 'rows', 'complete');
                r_c(s) = corr(tc_c(:, s), signal_c, 'rows', 'complete');
            end
            
            % Compute metric based on direction toggle directly
            if strcmp(selDir, 'eHRF > cHRF')
                vecA = r_e; vecB = r_c;
            else
                vecA = r_c; vecB = r_e; % Swap order to invert contrast sign
            end
            
            if strcmp(selMetric, 'Z score')
                Z_A = 0.5 * log((1 + max(-0.99, min(0.99, vecA))) ./ (1 - max(-0.99, min(0.99, vecA))));
                Z_B = 0.5 * log((1 + max(-0.99, min(0.99, vecB))) ./ (1 - max(-0.99, min(0.99, vecB))));
                [~, ~, ~, stats] = ttest(Z_A, Z_B);
                val = stats.tstat;
            else
                diffs = vecA - vecB;
                val = mean(diffs, 'omitnan');
            end
            
            acr_idx = find(strcmp(atlas.infoRegions.acr, eHRFData.regional_avg.(regName).acr), 1);
            if ~isempty(acr_idx)
                corrMap(atlas.Regions == acr_idx) = val;
            end
        end
    end

    function addOverlay(mapData)
        % Read current text box limits to preserve symmetric bounds when toggling directions
        valMin = str2double(hMinBox.String);
        valMax = str2double(hMaxBox.String);
        
        if isnan(valMin) || isnan(valMax) || valMin >= valMax
            nonZeroVals = mapData(~isnan(mapData) & mapData ~= 0);
            if isempty(nonZeroVals)
                cMin = -1; cMax = 1;
            else
                maxAbs = max(abs([prctile(nonZeroVals, 5), prctile(nonZeroVals, 95)]));
                if maxAbs == 0, maxAbs = 1; end
                cMin = -maxAbs;
                cMax = maxAbs;
            end
            hMinBox.String = num2str(cMin, '%.2f');
            hMaxBox.String = num2str(cMax, '%.2f');
        else
            cMin = valMin;
            cMax = valMax;
        end

        hNew = image(ax, zeros([volSize(1) volSize(3) 3]));
        idx = numel(overlays) + 1;
        overlays(idx).data   = mapData;
        overlays(idx).handle = hNew;
        overlays(idx).clim   = [cMin cMax];
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
        if isnan(valMin) || isnan(valMax) || valMin >= valMax, return; end
        overlays(end).clim = [valMin valMax];
        updateDisplay();
    end

    function btnToggleLines(src, ~)
        showRegions = get(src, 'Value');
        set(src, 'String', sprintf('Lines %s', ternary(showRegions, 'ON', 'OFF')));
        updateDisplay();
    end

    %% Plot Time Courses
    function plotRegionTimeCourse()
        cla(axTC);
        inside = crosshair(1)>=1 && crosshair(1)<=volSize(1) && ...
                 crosshair(2)>=1 && crosshair(2)<=volSize(2) && ...
                 crosshair(3)>=1 && crosshair(3)<=volSize(3);
        if ~inside || isempty(eHRFData) || isempty(cHRFData)
            title(axTC, 'Select Voxel & Load Model Data', 'FontSize', 11);
            return;
        end
        label = double(atlas.Regions(crosshair(1), crosshair(2), crosshair(3)));
        if label <= 0 || label > numel(atlas.infoRegions.acr)
            title(axTC, 'Background (No Region Selected)', 'FontSize', 11);
            return;
        end
        acr = atlas.infoRegions.acr{label};
        
        fNames_e = fieldnames(eHRFData.regional_avg);
        fNames_c = fieldnames(cHRFData.regional_avg);
        
        match_e = ''; match_c = '';
        for k = 1:numel(fNames_e)
            if isfield(eHRFData.regional_avg.(fNames_e{k}), 'acr') && strcmp(eHRFData.regional_avg.(fNames_e{k}).acr, acr)
                match_e = fNames_e{k}; break;
            end
        end
        for k = 1:numel(fNames_c)
            if isfield(cHRFData.regional_avg.(fNames_c{k}), 'acr') && strcmp(cHRFData.regional_avg.(fNames_c{k}).acr, acr)
                match_c = fNames_c{k}; break;
            end
        end

        if isempty(match_e) || isempty(match_c)
            title(axTC, sprintf('Region %s (Missing in model data)', acr), 'FontSize', 11);
            return;
        end
        
        tc_e = eHRFData.regional_avg.(match_e).tc;
        tc_c = cHRFData.regional_avg.(match_c).tc;

        % --- FIX: build time axes from the ACTUAL size of this region's tc,
        % instead of assuming the global lag_times_s always matches it.
        % (Different regions can have different numbers of time samples,
        % as already handled in generateComparisonMap; this function
        % previously did not account for that, causing a length mismatch
        % between mu_e and mu_c_interp below.)

        % --- Build t_e safely ---
        if isfield(eHRFData, 'lag_times_s') && ~isempty(eHRFData.lag_times_s)
            t_start_e = eHRFData.lag_times_s(1);
            t_end_e   = eHRFData.lag_times_s(end);
        else
            t_start_e = 0;
            t_end_e   = (size(tc_e, 1) - 1) * eHRFData.TR_mean;
        end
        t_e = linspace(t_start_e, t_end_e, size(tc_e, 1))';

        % --- Build t_c safely ---
        if isfield(cHRFData, 'lag_times_s') && ~isempty(cHRFData.lag_times_s)
            t_start_c = cHRFData.lag_times_s(1);
            t_end_c   = cHRFData.lag_times_s(end);
        else
            t_start_c = t_e(1);
            t_end_c   = t_e(end);
        end
        t_c = linspace(t_start_c, t_end_c, size(tc_c, 1))';

        smooth_win_s = str2double(hSmoothBox.String);
        if ~isnan(smooth_win_s) && smooth_win_s > 0
            sf_e = max(1, round(smooth_win_s / eHRFData.TR_mean));
            sf_c = max(1, round(smooth_win_s / cHRFData.TR_mean));
            tc_e = movmean(tc_e, sf_e, 1);
            tc_c = movmean(tc_c, sf_c, 1);
        end
        
        mu_e = mean(tc_e, 2, 'omitnan'); mu_e = mu_e(:);
        mu_c = mean(tc_c, 2, 'omitnan'); mu_c = mu_c(:);
        
        % Force mu_c to match t_e length & grid via interpolation
        mu_c_interp = interp1(t_c, mu_c, t_e, 'linear', 'extrap');
        mu_c_interp = mu_c_interp(:);
        
        signal_proxy = (mu_e + mu_c_interp) / 2; 

        hold(axTC, 'on');
        plot(axTC, t_e, mu_e, 'b-', 'LineWidth', 2);
        plot(axTC, t_c, mu_c, 'r--', 'LineWidth', 1.8);
        plot(axTC, t_e, signal_proxy, 'k:', 'LineWidth', 1.5);
        xline(axTC, 0, ':k', 'onset', 'LineWidth', 1);
        hold(axTC, 'off');
        
        xlim(axTC, [min(t_e) max(t_e)]);
        xlabel(axTC, 'Time from onset (s)');
        ylabel(axTC, 'Amplitude (a.u.)');
        title(axTC, sprintf('[%s] %s', acr, eHRFData.regional_avg.(match_e).name), 'Interpreter', 'none', 'FontSize', 11);
        legend(axTC, {'eHRF (Ridge)', 'cHRF (Simple)', 'Peristimulus Signal'}, 'Location', 'northeast');
        grid(axTC, 'on');
        box(axTC, 'off');

        txtInfo.String = sprintf('Voxel [%d %d %d] | Region: %s -- %s', crosshair, acr, eHRFData.regional_avg.(match_e).name);
    end

    %% Main Display Routine
    function updateDisplay()
        baseSlice = double(squeeze(baseVol(:, slice, :)));
        bMin = min(baseSlice(:)); bMax = max(baseSlice(:));
        if bMin == bMax, bMax = bMin + 1; end
        normBase = (baseSlice - bMin) / (bMax - bMin);
        idxBase = floor(normBase * 255) + 1;
        hBase.CData = ind2rgb(idxBase, gray(256));
        
        cmapParula = parula(256);
        for i = 1:numel(overlays)
            sData = squeeze(overlays(i).data(:, slice, :));
            cMin = overlays(i).clim(1);
            cMax = overlays(i).clim(2);
            normData = (sData - cMin) / (cMax - cMin);
            normData = max(0, min(1, normData));
            idxImg = floor(normData * 255) + 1;
            rgbImg = ind2rgb(idxImg, cmapParula);
            overlays(i).handle.CData = rgbImg;
            overlays(i).handle.AlphaData = 0.6 * (~isnan(sData) & sData ~= 0);
            uistack(overlays(i).handle, 'top');
        end
        
        if ~isempty(overlays)
            colormap(ax, parula(256));
            if isempty(cbarHandle) || ~isvalid(cbarHandle)
                cbarHandle = colorbar(ax, 'westoutside', 'Position', [0.03, 0.18, 0.02, 0.70]);
            end
            clim(ax, overlays(end).clim);
            cbarHandle.Label.String = get(hMetricGroup.SelectedObject, 'String');
            cbarHandle.FontSize = 9;
        end
        
        updateRegionLines();
        updateCrosshair();
        title(ax, sprintf('Coronal Slice: %d / %d', slice, volSize(2)), 'FontSize', 12);
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

    function out = ternary(cond, valT, valF)
        if cond, out = valT; else, out = valF; end
    end
end

function full_path = findFileCaseInsensitive(target_dir, filename)
    full_path = '';
    files = dir(target_dir);
    for i = 1:numel(files)
        if strcmpi(files(i).name, filename)
            full_path = fullfile(target_dir, files(i).name);
            break;
        end
    end
end