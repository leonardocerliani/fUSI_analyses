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
        'Position', [0.14, 0.90, 0.22, 0.04], 'BackgroundColor', 'w', ... % Expanded width to 0.30
        'SelectionChangedFcn', @(~,~) updateMapAndDisplay());

    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', 'Z score', ...
        'Units', 'normalized', 'Position', [0.02, 0.1, 0.30, 0.8], 'BackgroundColor', 'w', 'FontSize', 9, 'Value', 1);
    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', 'Simple difference', ...
        'Units', 'normalized', 'Position', [0.34, 0.1, 0.33, 0.8], 'BackgroundColor', 'w', 'FontSize', 9);
    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', '1 - p value', ...
        'Units', 'normalized', 'Position', [0.68, 0.1, 0.30, 0.8], 'BackgroundColor', 'w', 'FontSize', 9);

    uicontrol(fig, 'Style', 'text', 'String', 'Direction:', ...
        'Units', 'normalized', 'Position', [0.37, 0.91, 0.06, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 10, 'HorizontalAlignment', 'right');
    hDirGroup = uibuttongroup(fig, 'Units', 'normalized', ...
        'Position', [0.44, 0.90, 0.18, 0.04], 'BackgroundColor', 'w', ...
        'SelectionChangedFcn', @(~,~) updateMapAndDisplay());
    uicontrol(hDirGroup, 'Style', 'radiobutton', 'String', 'eHRF > cHRF', ...
        'Units', 'normalized', 'Position', [0.05, 0.1, 0.45, 0.8], 'BackgroundColor', 'w', 'FontSize', 9, 'Value', 1);
    uicontrol(hDirGroup, 'Style', 'radiobutton', 'String', 'cHRF > eHRF', ...
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
        
        selMetric = get(hMetricGroup.SelectedObject, 'String');
        
        % Reset bounds automatically to full range [0 1] to see all values clear
        if strcmp(selMetric, '1 - p value')
            hMinBox.String = '0.95';
            hMaxBox.String = '1.00';
        else
            hMinBox.String = 'NaN'; 
            hMaxBox.String = 'NaN';
        end
        
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

        % --- Build canonical HRF template once (same for all regions/subjects) ---
        % Signal is always tc_c (simple avg peristimulus); templates are:
        %   eHRF: subject-specific tc_e from ridge LOO
        %   cHRF: conv(boxcar, hrf_kernel) at cHRFData TR, trimmed to W_c
        TR_map        = cHRFData.TR_mean;
        stim_fr_map   = round(cHRFData.stim_dur_s        / TR_map);
        before_fr_map = round(cHRFData.before_stim_onset / TR_map);
        after_fr_map  = round(cHRFData.after_stim_offset / TR_map);
        W_map         = before_fr_map + stim_fr_map + after_fr_map;
        boxcar_map    = [zeros(before_fr_map,1); ones(stim_fr_map,1); zeros(after_fr_map,1)];
        hrf_ker_map   = fonduta.signal.hrf(TR_map, cHRFData.chaoyi_hrfParams);
        chrf_template = conv(boxcar_map, hrf_ker_map);
        chrf_template = chrf_template(1:W_map);
        chrf_template = chrf_template(:);
        t_chrf        = ((0:W_map-1)' - before_fr_map) * TR_map;

        for fi = 1:numel(common_regions)
            regName = common_regions{fi};
            tc_e = eHRFData.regional_avg.(regName).tc;   % [nTime_e x nSub_e]  eHRF shape per subject
            tc_c = cHRFData.regional_avg.(regName).tc;   % [nTime_c x nSub_c]  peristimulus signal per subject

            nSub = min(size(tc_e, 2), size(tc_c, 2));
            if nSub < 2, continue; end

            tc_e = tc_e(:, 1:nSub);
            tc_c = tc_c(:, 1:nSub);

            % Build time axis for tc_c (the signal)
            nTime_c = size(tc_c, 1);
            t_sig   = ((0:nTime_c-1)' - before_fr_map) * TR_map;

            % Interpolate eHRF template onto tc_c time grid (handles TR differences)
            nTime_e  = size(tc_e, 1);
            TR_e     = eHRFData.TR_mean;
            before_e = round(eHRFData.before_stim_onset / TR_e);
            t_ehrf   = ((0:nTime_e-1)' - before_e) * TR_e;
            tc_e_on_sig = zeros(nTime_c, nSub);
            for s = 1:nSub
                tc_e_on_sig(:, s) = interp1(t_ehrf, tc_e(:, s), t_sig, 'linear', 'extrap');
            end

            % Interpolate canonical HRF template onto tc_c time grid
            chrf_on_sig = interp1(t_chrf, chrf_template, t_sig, 'linear', 'extrap');

            % Per-subject correlations: signal ~ eHRF and signal ~ cHRF
            r_e = zeros(nSub, 1);
            r_c = zeros(nSub, 1);

            for s = 1:nSub
                r_e(s) = corr(tc_c(:, s), tc_e_on_sig(:, s), 'rows', 'complete');
                r_c(s) = corr(tc_c(:, s), chrf_on_sig,       'rows', 'complete');
            end

            % Fisher Z-transform
            Z_e = 0.5 * log((1 + max(-0.99, min(0.99, r_e))) ./ (1 - max(-0.99, min(0.99, r_e))));
            Z_c = 0.5 * log((1 + max(-0.99, min(0.99, r_c))) ./ (1 - max(-0.99, min(0.99, r_c))));
            
            if strcmp(selDir, 'eHRF > cHRF')
                diff_vec = Z_e - Z_c;
            else
                diff_vec = Z_c - Z_e;
            end
            
            [~, ~, ~, stats] = ttest(diff_vec);
            t_stat = stats.tstat;

            if strcmp(selMetric, 'Z score')
                val = t_stat;

            elseif strcmp(selMetric, '1 - p value')
                % One-tailed p-value for the direction already encoded in
                % diff_vec (flipped by the direction selector above).
                % tcdf(t_stat, df) = P(T <= t_stat) = 1 - p_right_tail,
                % so it is large (close to 1) when t_stat >> 0, i.e. when
                % the selected direction is significant.
                % Mask sub-threshold voxels (p > 0.05, i.e. val < 0.95) to
                % NaN so they are transparent in the overlay.
                df  = stats.df;
                val = tcdf(t_stat, df);   % = 1 - p_one_tailed_right
                if val < 0.95
                    val = NaN;
                end

            else % Simple difference
                if strcmp(selDir, 'eHRF > cHRF')
                    val = mean(r_e - r_c, 'omitnan');
                else % cHRF > eHRF
                    val = mean(r_c - r_e, 'omitnan');
                end
            end
            
            acr_idx = find(strcmp(atlas.infoRegions.acr, eHRFData.regional_avg.(regName).acr), 1);
            if ~isempty(acr_idx)
                corrMap(atlas.Regions == acr_idx) = val;
            end
        end
    end

    function addOverlay(mapData)
        selMetric = get(hMetricGroup.SelectedObject, 'String');

        valMin = str2double(hMinBox.String);
        valMax = str2double(hMaxBox.String);
        
        if isnan(valMin) || isnan(valMax) || valMin >= valMax
            nonZeroVals = mapData(~isnan(mapData) & mapData ~= 0);
            if isempty(nonZeroVals)
                cMin = 0; cMax = 1;
            else
                if strcmp(selMetric, '1 - p value')
                    cMin = 0.95;
                    cMax = 1;
                else
                    maxAbs = max(abs([prctile(nonZeroVals, 5), prctile(nonZeroVals, 95)]));
                    if maxAbs == 0, maxAbs = 1; end
                    cMin = -maxAbs;
                    cMax = maxAbs;
                end
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
        if isfield(eHRFData, 'lag_times_s') && ~isempty(eHRFData.lag_times_s) ...
                && numel(eHRFData.lag_times_s) == size(tc_e, 1)
            t_e = eHRFData.lag_times_s(:);
        else
            t_e = linspace(eHRFData.lag_times_s(1), eHRFData.lag_times_s(end), size(tc_e, 1))';
        end

        if isfield(cHRFData, 'lag_times_s') && ~isempty(cHRFData.lag_times_s) ...
                && numel(cHRFData.lag_times_s) == size(tc_c, 1)
            t_c = cHRFData.lag_times_s(:);
        else
            t_c = linspace(t_e(1), t_e(end), size(tc_c, 1))';
        end

        smooth_win_s = str2double(hSmoothBox.String);
        if ~isnan(smooth_win_s) && smooth_win_s > 0
            sf_e = max(1, round(smooth_win_s / eHRFData.TR_mean));
            sf_c = max(1, round(smooth_win_s / cHRFData.TR_mean));
            tc_e = movmean(tc_e, sf_e, 1);
            tc_c = movmean(tc_c, sf_c, 1);
        end
        
        mu_e = mean(tc_e, 2, 'omitnan'); mu_e = mu_e(:);
        mu_c = mean(tc_c, 2, 'omitnan'); mu_c = mu_c(:);
        
        smooth_win_s = str2double(hSmoothBox.String);
        if ~isnan(smooth_win_s) && smooth_win_s > 0
            sf_e = max(1, round(smooth_win_s / eHRFData.TR_mean));
            sf_c = max(1, round(smooth_win_s / cHRFData.TR_mean));
            tc_e = movmean(tc_e, sf_e, 1);
            tc_c = movmean(tc_c, sf_c, 1);
        end

        mu_e = mean(tc_e, 2, 'omitnan'); mu_e = mu_e(:);
        mu_c = mean(tc_c, 2, 'omitnan'); mu_c = mu_c(:);

        % --- Build smooth canonical HRF curve on the fly ---
        % conv(boxcar, hrf_kernel), trimmed to W_c and scaled to
        % the peak amplitude of mu_e for visual comparison.
        TR_c         = cHRFData.TR_mean;
        stim_fr_c    = round(cHRFData.stim_dur_s        / TR_c);
        before_fr_c  = round(cHRFData.before_stim_onset / TR_c);
        after_fr_c   = round(cHRFData.after_stim_offset / TR_c);
        W_c          = before_fr_c + stim_fr_c + after_fr_c;
        boxcar_c     = [zeros(before_fr_c,1); ones(stim_fr_c,1); zeros(after_fr_c,1)];
        hrf_kernel_c = fonduta.signal.hrf(TR_c, cHRFData.chaoyi_hrfParams);
        ap_c         = conv(boxcar_c, hrf_kernel_c);
        ap_c         = ap_c(1:W_c);
        ap_max       = max(ap_c);
        if ap_max > 0
            ap_c = ap_c / ap_max * max(mu_e);  % scale to eHRF peak
        end
        t_c_full    = ((0:W_c-1)' - before_fr_c) * TR_c;
        ap_c_interp = interp1(t_c_full, ap_c(:), t_e, 'linear', 'extrap');

        hold(axTC, 'on');
        plot(axTC, t_e, mu_e,        'b-',  'LineWidth', 2);
        plot(axTC, t_e, ap_c_interp, 'r--', 'LineWidth', 1.8);
        plot(axTC, t_c, mu_c,        'k:',  'LineWidth', 1.5);
        xline(axTC, 0, ':k', 'onset', 'LineWidth', 1);
        hold(axTC, 'off');

        xlim(axTC, [min(t_e) max(t_e)]);
        xlabel(axTC, 'Time from onset (s)');
        ylabel(axTC, 'Amplitude (a.u.)');
        title(axTC, sprintf('[%s] %s', acr, eHRFData.regional_avg.(match_e).name), 'Interpreter', 'none', 'FontSize', 11);
        legend(axTC, {'eHRF (Ridge)', 'canonical HRF', 'Simple avg'}, 'Location', 'northeast');
        grid(axTC, 'on');
        box(axTC, 'off');

        % Compute per-subject correlations and t-test for txtInfo display.
        % Matches generateComparisonMap: signal = tc_c, templates = tc_e (subject-
        % specific eHRF) and chrf (canonical HRF, same ap_c_interp built above).
        nSub_info = min(size(tc_e, 2), size(tc_c, 2));
        if nSub_info >= 2
            % Interpolate each subject's eHRF (tc_e) onto the tc_c time grid (t_c)
            nTime_e_i  = size(tc_e, 1);
            TR_e_i     = eHRFData.TR_mean;
            before_e_i = round(eHRFData.before_stim_onset / TR_e_i);
            t_ehrf_i   = ((0:nTime_e_i-1)' - before_e_i) * TR_e_i;
            nTime_c_i  = size(tc_c, 1);
            t_sig_i    = t_c(:);   % time axis already built for tc_c
            tc_e_on_c  = zeros(nTime_c_i, nSub_info);
            for s_i = 1:nSub_info
                tc_e_on_c(:,s_i) = interp1(t_ehrf_i, tc_e(:,s_i), t_sig_i, 'linear', 'extrap');
            end
            % cHRF template on tc_c grid (ap_c already built on t_e above;
            % re-interpolate onto t_c to be safe)
            chrf_on_c_i = interp1(t_c_full, ap_c(:) / max(ap_c(:)), t_sig_i, 'linear', 'extrap');
            r_e_info = zeros(nSub_info, 1);
            r_c_info = zeros(nSub_info, 1);
            for s_i = 1:nSub_info
                r_e_info(s_i) = corr(tc_c(:,s_i), tc_e_on_c(:,s_i), 'rows', 'complete');
                r_c_info(s_i) = corr(tc_c(:,s_i), chrf_on_c_i,      'rows', 'complete');
            end
            Ze_info = 0.5 * log((1 + max(-0.99,min(0.99,r_e_info))) ./ (1 - max(-0.99,min(0.99,r_e_info))));
            Zc_info = 0.5 * log((1 + max(-0.99,min(0.99,r_c_info))) ./ (1 - max(-0.99,min(0.99,r_c_info))));
            [~, ~, ~, st_info] = ttest(Ze_info - Zc_info);
            t_info  = st_info.tstat;
            p1_info = tcdf( t_info, st_info.df);   % 1-p for eHRF>cHRF
            p2_info = tcdf(-t_info, st_info.df);   % 1-p for cHRF>eHRF
            txtInfo.String = sprintf([ ...
                'Voxel [%d %d %d]  |  %s -- %s\n' ...
                't = %.2f  |  eHRF>cHRF: 1-p = %.3f  |  cHRF>eHRF: 1-p = %.3f'], ...
                crosshair, acr, eHRFData.regional_avg.(match_e).name, ...
                t_info, p1_info, p2_info);
        else
            txtInfo.String = sprintf('Voxel [%d %d %d] | Region: %s -- %s  (n<2, no stats)', ...
                crosshair, acr, eHRFData.regional_avg.(match_e).name);
        end
    end

    %% Main Display Routine
    function updateDisplay()
        baseSlice = double(squeeze(baseVol(:, slice, :)));
        bMin = min(baseSlice(:)); bMax = max(baseSlice(:));
        if bMin == bMax, bMax = bMin + 1; end
        normBase = (baseSlice - bMin) / (bMax - bMin);
        idxBase = floor(normBase * 255) + 1;
        hBase.CData = ind2rgb(idxBase, gray(256));
        
        selMetric_disp = get(hMetricGroup.SelectedObject, 'String');
        if strcmp(selMetric_disp, '1 - p value')
            cmap = hot(256);
        else
            cmap = parula(256);
        end
        for i = 1:numel(overlays)
            sData = squeeze(overlays(i).data(:, slice, :));
            cMin = overlays(i).clim(1);
            cMax = overlays(i).clim(2);
            normData = (sData - cMin) / (cMax - cMin);
            normData = max(0, min(1, normData));
            idxImg = floor(normData * 255) + 1;
            rgbImg = ind2rgb(idxImg, cmap);
            overlays(i).handle.CData = rgbImg;
            overlays(i).handle.AlphaData = 0.6 * (~isnan(sData) & sData ~= 0);
            uistack(overlays(i).handle, 'top');
        end
        
        if ~isempty(overlays)
            colormap(ax, cmap);
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