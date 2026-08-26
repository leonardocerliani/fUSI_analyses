function analysis_simple_average(glm_results_path, opts)
% analysis_simple_average  Group event-related averaging using saved GLM results (Parallelized).

% ---- Hardcoded Parallel Settings ----
max_workers = 10; % <--- SET YOUR MAXIMUM NUMBER OF WORKERS HERE

% ---- no arguments: print usage and return ----
if nargin == 0
    help analysis_simple_average
    return
end

if nargin < 2
    error('Usage: analysis_simple_average(glm_results_path, opts)');
end

if ~isfield(opts, 'model')
    error('opts.model must be specified.');
end

model_name = opts.model;

% ---- paths and packages ----
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
addpath(genpath(fileparts(mfilename('fullpath'))));

% ---- Initialize Parallel Pool with max_workers limit ----
current_pool = gcp('nocreate');

if isempty(current_pool)
    parpool('local', max_workers);
elseif current_pool.NumWorkers > max_workers
    % Re-open pool if existing pool exceeds worker cap
    delete(current_pool);
    parpool('local', max_workers);
end

% Ensure all active workers have access to paths (MUST run after pool is active)
pctRunOnAll(sprintf("addpath(genpath('%s'))", FONDUTA_PATH));

atlas = fonduta.atlas.load_atlas();

chaoyi_hrfParams    = [2.4  8  0.8  0.9  6  0  16];
chen2023_hrfParams  = [4.95 8.69 1.1 1.1 1.8 0 32];

% ---- fill default opts ----
if ~isfield(opts, 'eta2_thresh_val');       opts.eta2_thresh_val       = 0.03; end
if ~isfield(opts, 'before_stim_onset');     opts.before_stim_onset     = 5;    end
if ~isfield(opts, 'after_stim_offset');     opts.after_stim_offset     = 20;   end
if ~isfield(opts, 'min_stationary_trials'); opts.min_stationary_trials = 3;    end
if ~isfield(opts, 'min_active_voxels');     opts.min_active_voxels     = 5;    end
if ~isfield(opts, 'resultPath');            opts.resultPath            = pwd;   end

eta2_thresh_val       = opts.eta2_thresh_val;
before_stim_onset     = opts.before_stim_onset;
after_stim_offset     = opts.after_stim_offset;
min_stationary_trials = opts.min_stationary_trials;
min_active_voxels     = opts.min_active_voxels;
resultPath            = opts.resultPath;

% ---- build output filename ----
eta_str   = sprintf('eta%03d', round(eta2_thresh_val * 100));
out_dir   = resultPath;
out_fname = fullfile(out_dir, sprintf('simple_avg_%s_%s.mat', model_name, eta_str));

% ---- check if results already exist ----
if isfile(out_fname)
    fprintf('\n[analysis_simple_average] Results already exist:\n');
    fprintf('  %s\n\n', out_fname);
    fprintf('Delete the file to re-run, or change eta2_thresh_val.\n\n');
    return
end

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% ---- run the analysis ----
glm_files = dir(fullfile(glm_results_path, 'glm_*.mat'));
nSubs     = numel(glm_files);

if nSubs == 0
    error('No glm_*.mat files found in:\n  %s', glm_results_path);
end

fprintf('\n%s\n', repmat('=',1,60));
fprintf(' analysis_simple_average (Parallel Run)\n');
fprintf(' model  : %s\n', model_name);
fprintf(' eta2 >= : %.3f\n', eta2_thresh_val);
fprintf(' nSubs  : %d\n', nSubs);
fprintf(' workers: %d\n', gcp().NumWorkers);
fprintf('%s\n\n', repmat('=',1,60));

TR_all         = nan(1, nSubs);
stim_dur_s_all = nan(1, nSubs);
is_steady_model = contains(model_name, 'Steady', 'IgnoreCase', true);

% Cell array to safely hold per-subject result structures inside parfor
sub_results = cell(1, nSubs);

parfor isub = 1:nSubs
    fprintf('Processing Subject %d / %d...\n', isub, nSubs);
    
    % Temporary structure to hold outputs per worker
    sub_struct = struct();

    try
        file_path = fullfile(glm_files(isub).folder, glm_files(isub).name);
        tmp_glm   = load(file_path);
        glm       = tmp_glm.data;

        % --- from saved GLM result --- no recomputation needed ---
        bmask         = glm.bmask;
        allen_regions = glm.allen_regions;

        if ~isfield(glm.models, model_name)
            fprintf('  Sub %d: model "%s" not found - skipping.\n', isub, model_name);
            continue
        end

        model_result = glm.models.(model_name);

        % Auto-locate the visual-stimulus predictor by label
        pred_idx = find(contains(model_result.predictor_labels, 'stim'), 1);
        if isempty(pred_idx)
            fprintf('  Sub %d: no "stim" predictor in model "%s" - skipping.\n', isub, model_name);
            continue
        end

        eta2      = squeeze(model_result.eta2(pred_idx, :, :));
        eta2_mask = (eta2 >= eta2_thresh_val) & (bmask == 1);

        % Use FULL-LENGTH predictor vectors for onset detection (NOT Xmodel)
        if is_steady_model
            stim_box = glm.predictors.stim_stationary;
        else
            stim_box = glm.predictors.stim_all;
        end
        stim_box     = stim_box(:);
        onset_frames = find(diff([0; stim_box]) == 1);

        if numel(onset_frames) < min_stationary_trials
            fprintf('  Sub %d: only %d trial(s) - skipping.\n', isub, numel(onset_frames));
            continue
        end

        active_region_ids = unique(allen_regions);
        active_region_ids(active_region_ids <= 1) = [];

        if isempty(active_region_ids)
            fprintf('  Sub %d: no anatomical regions found - skipping.\n', isub);
            continue
        end

        % --- load raw PDI ---
        [PDI, ~, ~] = fonduta.io.datapath.load_session(glm.dataPath, glm.anatPath);

        TR = mean(diff(PDI.time));
        TR_all(isub) = TR;

        stim_dur_s = mean(PDI.stimInfo.endTime - PDI.stimInfo.startTime);
        stim_dur_s_all(isub) = stim_dur_s;

        T             = size(PDI.PDI, 3);
        stim_frames   = round(stim_dur_s / TR);
        before_frames = round(before_stim_onset / TR);
        after_frames  = round(after_stim_offset / TR);
        W             = before_frames + stim_frames + after_frames;

        nTrials = numel(onset_frames);
        nROI    = numel(active_region_ids);

        for r = 1:nROI
            rId = active_region_ids(r);

            roi_mask  = (allen_regions == rId) & (bmask == 1);
            roi_supra = roi_mask & eta2_mask;

            n_supra = sum(roi_supra(:));
            n_roi   = sum(roi_mask(:));

            if n_supra >= min_active_voxels
                roi_vox_mask = roi_supra;
            else
                roi_indices = find(roi_mask);
                roi_eta2    = eta2(roi_indices);

                n_top = max(1, ceil(0.05 * n_roi));

                [~, sort_idx] = sort(roi_eta2, 'descend', 'MissingPlacement', 'last');
                top_indices = roi_indices(sort_idx(1:n_top));

                roi_vox_mask = false(size(roi_mask));
                roi_vox_mask(top_indices) = true;
            end

            vox   = reshape(PDI.PDI, [], T);
            y_roi = mean(vox(roi_vox_mask(:), :), 1)';

            epoch_mat = nan(W, nTrials);
            valid_tr_cnt = 0;

            for tr = 1:nTrials
                t_start = onset_frames(tr) - before_frames;
                t_end   = t_start + W - 1;

                if t_start < 1 || t_end > T; continue; end

                epoch    = y_roi(t_start : t_end);
                baseline = mean(epoch(1:before_frames));
                
                valid_tr_cnt = valid_tr_cnt + 1;
                epoch_mat(:, valid_tr_cnt) = epoch - baseline;
            end

            if valid_tr_cnt == 0; continue; end

            tc_sub = mean(epoch_mat(:, 1:valid_tr_cnt), 2);

            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{rId};
                name = atlas.infoRegions.name{rId};
            else
                acr  = sprintf('ID_%d', rId);
                name = acr;
            end
            field = matlab.lang.makeValidName(acr);

            sub_struct.(field).tc   = tc_sub;
            sub_struct.(field).acr  = acr;
            sub_struct.(field).name = name;
        end

    catch ME
        fprintf('  ERROR Sub %d: %s\n', isub, ME.message);
    end

    sub_results{isub} = sub_struct;
end

% ---- Consolidate parallel results into regional_avg ----
regional_avg = struct();

for isub = 1:nSubs
    sub_data = sub_results{isub};
    if isempty(sub_data); continue; end

    fields = fieldnames(sub_data);
    for f = 1:numel(fields)
        fn = fields{f};
        if ~isfield(regional_avg, fn)
            regional_avg.(fn).tc   = sub_data.(fn).tc;
            regional_avg.(fn).acr  = sub_data.(fn).acr;
            regional_avg.(fn).name = sub_data.(fn).name;
        else
            regional_avg.(fn).tc   = [regional_avg.(fn).tc, sub_data.(fn).tc];
        end
    end
end

% ---- Save final outputs ----
TR_mean       = mean(TR_all,         'omitnan');
stim_dur_s    = mean(stim_dur_s_all, 'omitnan');
before_frames = round(before_stim_onset / TR_mean);
W             = before_frames + round(stim_dur_s/TR_mean) + round(after_stim_offset/TR_mean);
t_window      = ((0:W-1) - before_frames) * TR_mean;

save(out_fname, 'regional_avg', 'atlas', 'model_name', ...
    'chaoyi_hrfParams', 'chen2023_hrfParams', ...
    'eta2_thresh_val', 'TR_mean', 'stim_dur_s', ...
    'before_stim_onset', 'after_stim_offset', ...
    'W', 't_window', '-v7.3');

fprintf('\nResults saved to:\n  %s\n\n', out_fname);

% ---- Shutdown parallel pool ----
delete(gcp('nocreate'));

end