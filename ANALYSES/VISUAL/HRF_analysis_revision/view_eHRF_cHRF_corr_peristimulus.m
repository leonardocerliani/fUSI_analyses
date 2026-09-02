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

    uicontrol(hMetricGroup, 'Style', 'radiobutton', 'String', 'T value', ...
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
    axTC = axes('Parent', fig, 'Position', [0.62, 0.22, 0.34, 0.68]);
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
        'FontSize', 9, 'Callback', @(~,~) updateMapAndDisplay());


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
    uicontrol(fig, 'Style', 'text', 'String', 'Min subj per group:', ...
        'Units', 'normalized', 'Position', [0.79, 0.02, 0.05, 0.03], ...
        'BackgroundColor', 'w', 'FontSize', 9, 'HorizontalAlignment', 'right');
    hMinSubjBox = uicontrol(fig, 'Style', 'edit', 'String', '1', ...
        'Units', 'normalized', 'Position', [0.845, 0.02, 0.04, 0.04], ...
        'FontSize', 9, 'Callback', @(~,~) updateMapAndDisplay());


    txtInfo = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.08, 0.08, 0.88, 0.08], 'BackgroundColor', 'w', ...
        'FontSize', 12, 'HorizontalAlignment', 'left');

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

        min_subj_thresh = max(2, round(str2double(hMinSubjBox.String)));
        % floor at 2 because ttest requires at least 2 observations

        corrMap = nan(size(atlas.Regions));
        selMetric = get(hMetricGroup.SelectedObject, 'String');
        selDir    = get(hDirGroup.SelectedObject, 'String');

        % --- Build canonical HRF template once (same for all regions/subjects) ---
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

        % --- Iterate over ALL atlas regions, matching by .acr field (not fieldname) ---
        % This is the same lookup used in plotRegionTimeCourse so map and info bar agree.
        fNames_e = fieldnames(eHRFData.regional_hrf);
        fNames_c = fieldnames(cHRFData.regional_avg);

        for acr_idx = 1:numel(atlas.infoRegions.acr)
            acr_str = atlas.infoRegions.acr{acr_idx};

            % Find field in eHRFData whose .acr matches
            match_e = '';
            for k = 1:numel(fNames_e)
                if isfield(eHRFData.regional_hrf.(fNames_e{k}), 'acr') && ...
                   strcmp(eHRFData.regional_hrf.(fNames_e{k}).acr, acr_str)
                    match_e = fNames_e{k}; break;
                end
            end

            % Find field in cHRFData whose .acr matches
            match_c = '';
            for k = 1:numel(fNames_c)
                if isfield(cHRFData.regional_avg.(fNames_c{k}), 'acr') && ...
                   strcmp(cHRFData.regional_avg.(fNames_c{k}).acr, acr_str)
                    match_c = fNames_c{k}; break;
                end
            end

            if isempty(match_e) || isempty(match_c), continue; end

            hrf_e = eHRFData.regional_hrf.(match_e).hrf;  % [K x nSub] ridge betas
            tc_c  = cHRFData.regional_avg.(match_c).tc;   % [nTime_c x nSub] peristimulus

            nSub = min(size(hrf_e, 2), size(tc_c, 2));
            
            if nSub < min_subj_thresh, continue; end

            hrf_e = hrf_e(:, 1:nSub);
            tc_c  = tc_c(:,  1:nSub);

            % Apply same smoothing as info bar stats (5s fixed window, same as hSmoothBox default)
            smooth_win_s_map = str2double(hSmoothBox.String);
            if ~isnan(smooth_win_s_map) && smooth_win_s_map > 0
                sf_c_map = max(1, round(smooth_win_s_map / TR_map));
                tc_c     = movmean(tc_c, sf_c_map, 1);   % only smooth the signal, not the betas
            end



            % Build time axis for tc_c
            nTime_c = size(tc_c, 1);
            t_sig   = ((0:nTime_c-1)' - before_fr_map) * TR_map;

            % Interpolate ridge betas onto tc_c time grid
            hrf_e_on_sig = zeros(nTime_c, nSub);
            for s = 1:nSub
                hrf_e_on_sig(:, s) = interp1(eHRFData.lag_times_s(:), hrf_e(:, s), t_sig, 'linear', 'extrap');
            end

            % Interpolate canonical HRF template onto tc_c time grid
            chrf_on_sig = interp1(t_chrf, chrf_template, t_sig, 'linear', 'extrap');

            % Per-subject correlations: signal ~ eHRF and signal ~ cHRF
            r_e = zeros(nSub, 1);
            r_c = zeros(nSub, 1);
            for s = 1:nSub
                r_e(s) = corr(tc_c(:, s), hrf_e_on_sig(:, s), 'rows', 'complete');
                r_c(s) = corr(tc_c(:, s), chrf_on_sig,        'rows', 'complete');
            end

            % Fisher Z-transform
            Z_e = 0.5 * log((1 + max(-0.99, min(0.99, r_e))) ./ (1 - max(-0.99, min(0.99, r_e))));
            Z_c = 0.5 * log((1 + max(-0.99, min(0.99, r_c))) ./ (1 - max(-0.99, min(0.99, r_c))));

            % Always compute diff as eHRF - cHRF; direction flips the stored value
            [~, ~, ~, stats] = ttest(Z_e - Z_c);
            t_eGTc =  stats.tstat;   % positive = eHRF fits better
            t_cGTe = -stats.tstat;   % positive = cHRF fits better

            if strcmp(selDir, 'eHRF > cHRF')
                t_stat = t_eGTc;
            else
                t_stat = t_cGTe;
            end

            if strcmp(selMetric, 'T value')
                val = t_stat;

            elseif strcmp(selMetric, '1 - p value')
                % 1-p for the selected direction: large when t_stat >> 0
                val = tcdf(t_stat, stats.df);
                if val < 0.95
                    val = NaN;
                end

            else  % Simple difference
                if strcmp(selDir, 'eHRF > cHRF')
                    val = mean(r_e - r_c, 'omitnan');
                else
                    val = mean(r_c - r_e, 'omitnan');
                end
            end

            corrMap(atlas.Regions == acr_idx) = val;
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
        
        fNames_e = fieldnames(eHRFData.regional_hrf);   % ridge betas
        fNames_c = fieldnames(cHRFData.regional_avg);
        
        match_e = ''; match_c = '';
        for k = 1:numel(fNames_e)
            if isfield(eHRFData.regional_hrf.(fNames_e{k}), 'acr') && strcmp(eHRFData.regional_hrf.(fNames_e{k}).acr, acr)
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
        
        tc_e = eHRFData.regional_hrf.(match_e).hrf;  % [K x nSub] ridge betas
        tc_c = cHRFData.regional_avg.(match_c).tc;   % [nTime_c x nSub] peristimulus signal
        t_e  = eHRFData.lag_times_s(:);              % [K x 1]


        % Time axis for tc_c (simple avg at cHRFData TR)
        TR_c_plot      = cHRFData.TR_mean;
        before_fr_plot = round(cHRFData.before_stim_onset / TR_c_plot);
        nTime_c_plot   = size(tc_c, 1);
        t_c            = ((0:nTime_c_plot-1)' - before_fr_plot) * TR_c_plot;

        smooth_win_s = str2double(hSmoothBox.String);
        if ~isnan(smooth_win_s) && smooth_win_s > 0
            sf_c = max(1, round(smooth_win_s / TR_c_plot));
            tc_c = movmean(tc_c, sf_c, 1);   % only smooth the signal, not the betas
        end


        mu_e = mean(tc_e, 2, 'omitnan'); mu_e = mu_e(:);
        mu_c = mean(tc_c, 2, 'omitnan'); mu_c = mu_c(:);

        % Smooth displayed eHRF curve using the same window (cosmetic, post-averaging)
        if ~isnan(smooth_win_s) && smooth_win_s > 0
            TR_e_plot = t_e(2) - t_e(1);   % step size of lag_times_s
            sf_e      = max(1, round(smooth_win_s / TR_e_plot));
            mu_e      = movmean(mu_e, sf_e);
        end

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
        t_c_full    = ((0:W_c-1)' - before_fr_c) * TR_c;
        ap_c_interp = interp1(t_c_full, ap_c(:), t_e, 'linear', 'extrap');

        % Normalize all three to [0,1] over their positive peak for shape comparison
        norm1 = @(x) (x - min(x)) / (max(x) - min(x) + eps);
        mu_e_n      = norm1(mu_e);
        mu_c_interp = norm1(interp1(t_c, mu_c, t_e, 'linear', 'extrap'));
        ap_c_n      = norm1(ap_c_interp);

        stim_dur_plot = cHRFData.stim_dur_s;

        hold(axTC, 'on');
        % Light-blue stimulus period patch (drawn first, stays behind curves)
        yl = [-0.15 1.15];
        patch(axTC, [0 stim_dur_plot stim_dur_plot 0], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.68 0.85 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.35);
        plot(axTC, t_e, mu_e_n,      'b-',  'LineWidth', 2);
        plot(axTC, t_e, ap_c_n,      'r--', 'LineWidth', 1.8);
        plot(axTC, t_e, mu_c_interp, 'k:',  'LineWidth', 1.5);
        xline(axTC, 0,              ':k', 'onset',  'LineWidth', 1);
        xline(axTC, stim_dur_plot,  ':k', 'offset', 'LineWidth', 1);
        hold(axTC, 'off');

        xlim(axTC, [min(t_e) max(t_e)]);
        ylim(axTC, yl);
        xlabel(axTC, 'Time from onset (s)');
        ylabel(axTC, 'Normalised amplitude [0-1]');
        title(axTC, sprintf('[%s] %s', acr, eHRFData.regional_hrf.(match_e).name), 'Interpreter', 'none', 'FontSize', 11);
        legend(axTC, {'stim period', 'eHRF (Ridge)', 'canonical HRF', 'Simple avg'}, 'Location', 'northeast');
        grid(axTC, 'on');
        box(axTC, 'off');

        % Compute per-subject correlations and t-test for txtInfo display.
        % Matches generateComparisonMap: signal = tc_c, templates = tc_e (subject-
        % specific eHRF) and chrf (canonical HRF, same ap_c_interp built above).
        nSub_info = min(size(tc_e, 2), size(tc_c, 2));
        if nSub_info >= 2
            % Interpolate ridge betas (tc_e on t_e=lag_times_s) onto tc_c grid
            nTime_c_i = size(tc_c, 1);
            t_sig_i   = t_c(:);
            tc_e_on_c = zeros(nTime_c_i, nSub_info);
            for s_i = 1:nSub_info
                tc_e_on_c(:,s_i) = interp1(t_e, tc_e(:,s_i), t_sig_i, 'linear', 'extrap');
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
            % t_eGTc > 0 means eHRF fits better; t_cGTe = -t_eGTc
            t_eGTc =  st_info.tstat;
            t_cGTe = -st_info.tstat;
            % One-tailed p-values (right tail): small p = significant in that direction
            p_eGTc = tcdf(-t_eGTc, st_info.df);   % P(T > t_eGTc | H0)
            p_cGTe = tcdf(-t_cGTe, st_info.df);   % P(T > t_cGTe | H0)
            txtInfo.String = sprintf([ ...
                'Voxel [%d %d %d]  |  %s -- %s\n' ...
                'eHRF > cHRF: T(%d) = %.2f,  p = %.4f    |    cHRF > eHRF: T(%d) = %.2f,  p = %.4f'], ...
                crosshair, acr, eHRFData.regional_hrf.(match_e).name, ...
                st_info.df, t_eGTc, p_eGTc, st_info.df, t_cGTe, p_cGTe);


        else
            txtInfo.String = sprintf('Voxel [%d %d %d] | Region: %s -- %s  (n<2, no stats)', ...
                crosshair, acr, eHRFData.regional_hrf.(match_e).name);
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
            % cmap = parula(256);
            cmap = cool(256);
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
            % Mask pixels that are NaN, exactly zero (background), or
            % outside the user-specified [cMin, cMax] range so that
            % below-threshold voxels become fully transparent regardless
            % of which metric (T value / Simple difference / 1-p value)
            % is being displayed.
            inRange = ~isnan(sData) & sData ~= 0 & sData >= cMin & sData <= cMax;
            overlays(i).handle.AlphaData = 0.6 * inRange;
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