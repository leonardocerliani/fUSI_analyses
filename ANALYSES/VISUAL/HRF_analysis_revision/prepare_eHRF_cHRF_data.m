function prepare_eHRF_cHRF_data(model_name, atlas)
    root_dir = '/data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL/HRF_analysis_revision';

    if nargin < 1 || isempty(model_name), model_name = 'M5_Behavior'; end
    if nargin < 2 || isempty(atlas), atlas = fonduta.atlas.load_atlas(); end

    % Case-insensitive file finder using dir
    ridge_dir  = fullfile(root_dir, 'results_ridge_loo');
    simple_dir = fullfile(root_dir, 'results_simple_average');

    ridge_pattern  = sprintf('ridge_loo_%s_eta003_HRF12s.mat', model_name);
    simple_pattern = sprintf('simple_avg_%s_eta003.mat', model_name);

    ridge_file  = findFileCaseInsensitive(ridge_dir, ridge_pattern);
    simple_file = findFileCaseInsensitive(simple_dir, simple_pattern);

    assert(~isempty(ridge_file), 'Ridge file not found for model: %s', model_name);
    assert(~isempty(simple_file), 'Simple average file not found for model: %s', model_name);

    fprintf('Loading source structures:\n  -> %s\n  -> %s\n', ridge_file, simple_file);
    eData = load(ridge_file);
    sData = load(simple_file);

    common_regions = intersect(fieldnames(eData.regional_avg), fieldnames(sData.regional_avg));
    nReg = numel(common_regions);

    z_map    = nan(size(atlas.Regions));
    diff_map = nan(size(atlas.Regions));

    hWait = waitbar(0, sprintf('Processing regions for %s...', model_name), 'Name', 'Caching eHRF vs cHRF Maps');

    for fi = 1:nReg
        if ~ishandle(hWait), break; end
        waitbar(fi / nReg, hWait, sprintf('Processing region %d / %d: %s', fi, nReg, common_regions{fi}));

        regName = common_regions{fi};
        tc_e = eData.regional_avg.(regName).tc;
        tc_c = sData.regional_avg.(regName).tc;
        
        nSub = min(size(tc_e, 2), size(tc_c, 2));
        if nSub < 2, continue; end
        
        tc_e = tc_e(:, 1:nSub);
        tc_c = tc_c(:, 1:nSub);

        % Resample cHRF to match eHRF length if time lengths differ
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
        
        % Group mean signals (now guaranteed matching row dimensions)
        signal_e = mean(tc_e, 2, 'omitnan');
        signal_c = mean(tc_c, 2, 'omitnan');
        
        r_e = zeros(nSub, 1);
        r_c = zeros(nSub, 1);
        
        for s = 1:nSub
            r_e(s) = corr(tc_e(:, s), signal_e, 'rows', 'complete');
            r_c(s) = corr(tc_c(:, s), signal_c, 'rows', 'complete');
        end
        
        % Fisher Z-Transformation & paired t-test
        Z_e = 0.5 * log((1 + max(-0.99, min(0.99, r_e))) ./ (1 - max(-0.99, min(0.99, r_e))));
        Z_c = 0.5 * log((1 + max(-0.99, min(0.99, r_c))) ./ (1 - max(-0.99, min(0.99, r_c))));
        [~, ~, ~, stats] = ttest(Z_e, Z_c);
        
        acr_idx = find(strcmp(atlas.infoRegions.acr, eData.regional_avg.(regName).acr), 1);
        if ~isempty(acr_idx)
            z_map(atlas.Regions == acr_idx)    = stats.tstat;
            diff_map(atlas.Regions == acr_idx) = mean(r_e - r_c, 'omitnan');
        end
    end

    if ishandle(hWait), delete(hWait); end

    cache_dir = fullfile(root_dir, 'cached_maps');
    if ~exist(cache_dir, 'dir'), mkdir(cache_dir); end
    out_file = fullfile(cache_dir, sprintf('cached_map_%s.mat', model_name));
    save(out_file, 'z_map', 'diff_map', 'model_name', '-v7.3');
    fprintf('Successfully cached comparison maps to:\n  -> %s\n', out_file);
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