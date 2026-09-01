function analysis_ridge_loo_ROI(glm_results_path, model_name, opts)
% analysis_ridge_loo_ROI  Group LOO-CV ridge regression for HRF shape recovery.
%
% Reuses per-session GLM result files (glm_*.mat, saved by
% analysis_visual_FONDUTA_HRF.m) to avoid re-fitting the HRF GLM.
% Masks, region labels, eta2 maps, and stimulus boxcars all come directly
% from those files.  The only data still loaded per subject is the raw PDI
% time-series (needed for ROI signal extraction).
%
% For each session and each active Allen region, fits a ridge regression
% with LOO-CV (leave-one-trial-out) to recover the empirical HRF shape
% from the ROI-averaged signal.
%
% Design matrix: onset-delta + temporal shifts (same approach as the old
% analysis_ridge_loo_group.m).  Column k of X_fir is 1 at each frame
% that is exactly k-1 TR after a trial onset, 0 elsewhere.  The resulting
% betas directly estimate the average signal at each lag after onset —
% i.e. the empirical HRF shape (HRF convolved with the stimulus boxcar).
% The window covers stim_dur_s + time_window_after_offset seconds.
%
% Raw beta estimates are saved per subject per region.  Smoothing and
% similarity with the canonical HRF are computed at display time in
% analysis_ridge_loo_ROI_view_results.m (same pattern as analysis_simple_average).
%
% USAGE:
%   analysis_ridge_loo_ROI(glm_results_path, model_name)
%   analysis_ridge_loo_ROI(glm_results_path, model_name, opts)
%
%   glm_results_path  folder with glm_*.mat files
%   model_name        e.g. 'M1_StimOnly', 'M5_Behavior', 'M8_SteadyVisual'
%   opts              optional struct with any of:
%       .eta2_thresh_val          (default 0.05)
%       .min_stationary_trials    (default 3)
%       .min_active_voxels        (default 5)
%       .time_window_after_offset (default 12 s)  post-stimulus window to model
%       .time_resampling          (default 1 s)   node spacing for shifted columns
%                                 e.g. 1 s → 35 nodes for 15+20 s window at TR=0.2 s
%       .lambda_grid              (default logspace(-2,4,20))
%       .resultPath               (default pwd)
%
% OUTPUT:
%   <resultPath>/results_ridge_loo/
%       ridge_loo_<model_name>_eta<str>_HRF<N>s.mat
%   e.g. ridge_loo_M1_StimOnly_eta005_HRF12s.mat  for default settings
%
% BATCH EXAMPLE:
%   glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
%   analysis_ridge_loo_ROI(glm_results_path, 'M1_StimOnly');
%
%   % Custom eta2 threshold (changes filename automatically):
%   opts.eta2_thresh_val = 0.03;
%   analysis_ridge_loo_ROI(glm_results_path, 'M8_SteadyVisual', opts);
%   % → ridge_loo_M8_SteadyVisual_eta003_HRF12s.mat
%
% For interactive plotting of the results, use:
%   analysis_ridge_loo_ROI_view_results.m
%
% =========================================================================
% *** NOTE — stimulus boxcar choice ***
% =========================================================================
% Onsets are detected from stim_stationary (M8/Steady models) or stim_all
% (all other models), same rule as analysis_simple_average.
% The design matrix uses onset-delta + shifts — it does NOT use the
% sustained boxcar.  The resulting betas trace the average signal at each
% lag after onset, i.e. the empirical response shape (HRF * boxcar).
% The canonical similarity reference in the view script is therefore
% conv(boxcar_one_trial, hrf_kernel) sampled at lag_times_s.
% =========================================================================

% ---- no arguments: print usage and return ----
if nargin == 0
    help analysis_ridge_loo_ROI
    return
end

if nargin < 3; opts = struct(); end

% ---- paths and packages ----
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
addpath(genpath(fileparts(mfilename('fullpath'))));

atlas = fonduta.atlas.load_atlas();

chaoyi_hrfParams   = [2.4  8  0.8  0.9  6  0  16];
chen2023_hrfParams = [4.95 8.69 1.1 1.1 1.8 0 32];

% ---- fill default opts ----
if ~isfield(opts, 'eta2_thresh_val');          opts.eta2_thresh_val          = 0.03;              end
if ~isfield(opts, 'min_stationary_trials');    opts.min_stationary_trials    = 3;                 end
if ~isfield(opts, 'min_active_voxels');        opts.min_active_voxels        = 5;                 end
if ~isfield(opts, 'time_window_after_offset'); opts.time_window_after_offset = 12;                end
if ~isfield(opts, 'time_resampling');          opts.time_resampling          = 1;                 end
if ~isfield(opts, 'lambda_grid');              opts.lambda_grid              = logspace(-2,4,20); end
if ~isfield(opts, 'resultPath');               opts.resultPath               = pwd;               end

eta2_thresh_val          = opts.eta2_thresh_val;
min_stationary_trials    = opts.min_stationary_trials;
min_active_voxels        = opts.min_active_voxels;
time_window_after_offset = opts.time_window_after_offset;
time_resampling          = opts.time_resampling;
lambda_grid              = opts.lambda_grid;
resultPath               = opts.resultPath;

% ---- build output filename (mirrors analysis_simple_average naming) ----
eta_str   = sprintf('eta%03d', round(eta2_thresh_val * 100));
hrf_str   = sprintf('HRF%ds',  time_window_after_offset);
out_dir   = fullfile(resultPath, 'results_ridge_loo');
out_fname = fullfile(out_dir, sprintf('ridge_loo_%s_%s_%s.mat', model_name, eta_str, hrf_str));

% ---- check if results already exist ----
if isfile(out_fname)
    fprintf('\n[analysis_ridge_loo_ROI] Results already exist:\n');
    fprintf('  %s\n\n', out_fname);
    fprintf('Delete the file to re-run, or change opts (eta2_thresh_val, time_window_after_offset).\n\n');
    return
end

if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% ---- load GLM files ----
glm_files = dir(fullfile(glm_results_path, 'glm_*.mat'));
nSubs     = numel(glm_files);

if nSubs == 0
    error('No glm_*.mat files found in:\n  %s', glm_results_path);
end

fprintf('\n%s\n', repmat('=',1,60));
fprintf(' analysis_ridge_loo_ROI\n');
fprintf(' model  : %s\n', model_name);
fprintf(' eta2 >= : %.3f\n', eta2_thresh_val);
fprintf(' post-stim window : %d s\n', time_window_after_offset);
fprintf(' time_resampling  : %.2f s\n', time_resampling);
fprintf(' output           : %s\n', out_fname);
fprintf(' nSubs  : %d\n', nSubs);
fprintf('%s\n\n', repmat('=',1,60));

regional_hrf   = struct();
TR_all         = nan(1, nSubs);
stim_dur_s_all = nan(1, nSubs);
N_all          = nan(1, nSubs);

is_steady_model = contains(model_name, 'Steady', 'IgnoreCase', true);

wb = waitbar(0, sprintf('Ridge LOO: %s', model_name), 'Name', 'Ridge LOO-CV');

for isub = 1:nSubs

    fprintf('\n%s\n--- Sub %d / %d ---\n%s\n', ...
        repmat('-',1,40), isub, nSubs, repmat('-',1,40));
    waitbar(isub/nSubs, wb, sprintf('Subject %d / %d', isub, nSubs));

    try
        % --- Load saved GLM result ---
        glm = load(fullfile(glm_files(isub).folder, glm_files(isub).name)).data;

        bmask         = glm.bmask;
        allen_regions = glm.allen_regions;

        if ~isfield(glm.models, model_name)
            fprintf('  model "%s" not found in this file — skipping.\n', model_name);
            continue
        end

        model_result = glm.models.(model_name);

        % Auto-locate the visual-stimulus predictor by label
        pred_idx = find(contains(model_result.predictor_labels, 'stim'), 1);
        if isempty(pred_idx)
            fprintf('  no "stim" predictor in model "%s" — skipping.\n', model_name);
            continue
        end

        eta2      = squeeze(model_result.eta2(pred_idx, :, :));
        eta2_mask = (eta2 > eta2_thresh_val) & (bmask == 1);

        % Use FULL-LENGTH predictor vectors for onset detection (NOT Xmodel)
        % (same caution as analysis_simple_average — see header comment there)
        if is_steady_model
            stim_box = glm.predictors.stim_stationary;
        else
            stim_box = glm.predictors.stim_all;
        end
        stim_box     = stim_box(:);
        onset_frames = find(diff([0; stim_box]) == 1);

        if numel(onset_frames) < min_stationary_trials
            fprintf('  only %d trial(s) — skipping (min = %d).\n', ...
                numel(onset_frames), min_stationary_trials);
            continue
        end

        % Active region selection: η² > threshold AND >= min_active_voxels
        active_region_ids = unique(allen_regions(eta2_mask));
        active_region_ids(active_region_ids <= 1) = [];

        valid = false(size(active_region_ids));
        for ri = 1:numel(active_region_ids)
            n_vox     = sum(allen_regions(:) == active_region_ids(ri) & eta2_mask(:));
            valid(ri) = n_vox >= min_active_voxels;
        end
        active_region_ids = active_region_ids(valid);

        if isempty(active_region_ids)
            fprintf('  no regions with >= %d active voxels — skipping.\n', min_active_voxels);
            continue
        end

        % --- Load raw PDI (only data not stored in the GLM result) ---
        [PDI, ~, ~] = fonduta.io.datapath.load_session(glm.dataPath, glm.anatPath);

        TR         = mean(diff(PDI.time));
        TR_all(isub) = TR;

        stim_dur_s = mean(PDI.stimInfo.endTime - PDI.stimInfo.startTime);
        stim_dur_s_all(isub) = stim_dur_s;
        fprintf('  TR = %.3f s   stim_dur = %.2f s\n', TR, stim_dur_s);

        T    = size(PDI.PDI, 3);
        nROI = numel(active_region_ids);

        % --- Build onset-delta design matrix (K temporal shifts) ---
        % Column k+1 is the onset-delta shifted by k * step frames, where
        % step = round(time_resampling / TR).  Beta k+1 estimates the average
        % signal at lag k * time_resampling seconds after onset — directly
        % tracing the empirical HRF shape at time_resampling resolution.
        % K nodes cover stim_dur_s + time_window_after_offset.
        step   = max(1, round(time_resampling / TR));
        K      = round((stim_dur_s + time_window_after_offset) / time_resampling);
        T_safe = min(T, numel(stim_box));

        onset_delta = zeros(T_safe, 1);
        of_safe     = onset_frames(onset_frames <= T_safe);
        onset_delta(of_safe) = 1;

        X_fir = zeros(T_safe, K);
        for k = 0:K-1
            shift_frames = k * step;
            shifted      = circshift(onset_delta, shift_frames);
            shifted(1:shift_frames) = 0;
            X_fir(:, k+1) = shifted;
        end

        N           = K;
        N_all(isub) = N;

        % Remove trials whose response window extends beyond T_safe
        % (window = K nodes × step frames each)
        valid_trials = (onset_frames + K * step - 1) <= T_safe;
        onset_frames = onset_frames(valid_trials);
        nTrials      = numel(onset_frames);

        if nTrials < 2
            fprintf('  fewer than 2 valid trials after trimming — skipping.\n');
            continue
        end

        % Build response windows for LOO: [nTrials × (K*step)] frame indices
        % (the full frame window, not just node frames)
        win_len = K * step;
        trial_frames = zeros(nTrials, win_len);
        for t = 1:nTrials
            trial_frames(t,:) = onset_frames(t) : onset_frames(t) + win_len - 1;
        end
        % Clip to valid range (safety)
        trial_frames(trial_frames > T_safe) = T_safe;

        % --- Extract ROI-averaged signals and run ridge LOO-CV ---
        hrf_betas       = zeros(N, nROI);
        lambda_best_all = zeros(1, nROI);

        for r = 1:nROI
            roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;
            vox       = reshape(PDI.PDI, [], T);
            y_full    = mean(vox(roi_supra(:), :), 1)';   % [T × 1]

            % Trim and z-score
            y = y_full(1:T_safe);
            y = (y - mean(y)) / (std(y) + eps);

            % --- LOO-CV to select lambda ---
            cv     = cvpartition(nTrials, 'LeaveOut');
            cv_mse = zeros(numel(lambda_grid), 1);

            for li = 1:numel(lambda_grid)
                fold_mse = zeros(cv.NumTestSets, 1);

                for fold = 1:cv.NumTestSets
                    test_trial = find(cv.test(fold));   % scalar

                    % Test frames: response window of the held-out trial
                    test_frames = trial_frames(test_trial, :);
                    test_frames = test_frames(test_frames >= 1 & test_frames <= T_safe);

                    % Training frames: everything NOT in the test window
                    train_mask = true(T_safe, 1);
                    train_mask(test_frames) = false;
                    train_frames = find(train_mask);

                    if numel(train_frames) < N + 1
                        fold_mse(fold) = Inf;
                        continue
                    end

                    % ridge(y, X, lambda, flag=0):
                    %   flag=0 → returns [N+1 × 1] in original (un-standardised) space,
                    %   intercept is first element → drop it.
                    B = ridge(y(train_frames), X_fir(train_frames,:), ...
                              lambda_grid(li), 0);
                    B = B(2:end);   % drop intercept

                    y_pred = X_fir(test_frames(:),:) * B;
                    fold_mse(fold) = mean((y(test_frames(:)) - y_pred).^2);
                end

                cv_mse(li) = mean(fold_mse(isfinite(fold_mse)));
            end

            [~, best_idx]      = min(cv_mse);
            lambda_best        = lambda_grid(best_idx);
            lambda_best_all(r) = lambda_best;

            % Final fit with best lambda on all data
            % Raw betas are stored — smoothing and similarity are computed
            % at display time in analysis_ridge_loo_ROI_view_results.m.
            B_final = ridge(y, X_fir, lambda_best, 0);
            hrf_betas(:,r) = B_final(2:end);
        end

        % --- Store per-region results ---
        for r = 1:nROI
            rId = active_region_ids(r);
            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{rId};
                name = atlas.infoRegions.name{rId};
            else
                acr  = sprintf('ID_%d', rId);
                name = acr;
            end
            field = matlab.lang.makeValidName(acr);

            if ~isfield(regional_hrf, field)
                regional_hrf.(field).hrf  = hrf_betas(:,r);
                regional_hrf.(field).lam  = lambda_best_all(r);
                regional_hrf.(field).acr  = acr;
                regional_hrf.(field).name = name;
            else
                regional_hrf.(field).hrf  = [regional_hrf.(field).hrf, hrf_betas(:,r)];
                regional_hrf.(field).lam  = [regional_hrf.(field).lam, lambda_best_all(r)];
            end
        end

        fprintf('  %d active regions  (lambda range: %.3g – %.3g)\n', ...
            nROI, min(lambda_best_all), max(lambda_best_all));

    catch ME
        fprintf('  ERROR: %s\n', ME.message);
        fprintf('    In: %s  line %d\n', ME.stack(1).name, ME.stack(1).line);
    end

end

close(wb);

TR_mean    = mean(TR_all,         'omitnan');
stim_dur_s = mean(stim_dur_s_all, 'omitnan');
N_mean     = round(mean(N_all,    'omitnan'));

% Lag-time axis: one entry per node, at time_resampling resolution
lag_times_s = (0 : N_mean-1) * time_resampling;

% ---- Save results ----
save(out_fname, ...
    'regional_hrf', 'atlas', 'model_name', ...
    'chaoyi_hrfParams', 'chen2023_hrfParams', ...
    'eta2_thresh_val', 'TR_mean', 'stim_dur_s', ...
    'time_window_after_offset', 'time_resampling', 'N_mean', 'lag_times_s', 'lambda_grid', ...
    '-v7.3');

fprintf('\nResults saved to:\n  %s\n\n', out_fname);

end   % end analysis_ridge_loo_ROI
