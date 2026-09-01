function analysis_ridge_loo_ROI(glm_results_path, model_name, opts)
% analysis_ridge_loo_ROI  Group LOO-CV ridge regression for HRF shape recovery.
%
% Reuses per-session GLM result files (glm_*.mat, saved by
% analysis_visual_FONDUTA_HRF.m) to avoid re-fitting the HRF GLM.
% Masks, region labels, eta2 maps, and stimulus boxcars all come directly
% from those files. The only data still loaded per subject is the raw PDI
% time-series (needed for ROI signal extraction).
%
% USAGE:
%   analysis_ridge_loo_ROI(glm_results_path, model_name)
%   analysis_ridge_loo_ROI(glm_results_path, model_name, opts)
%
%   glm_results_path  folder with glm_*.mat files
%   model_name        e.g. 'M1_StimOnly', 'M5_Behavior', 'M8_SteadyVisual'
%   opts              optional struct with any of:
%       .eta2_thresh_val          (default 0.03)
%       .min_stationary_trials    (default 3)
%       .min_active_voxels        (default 5)
%       .before_stim_onset        (default 5 s)
%       .time_window_after_offset (default 12 s)
%       .time_resampling          (default 1 s)
%       .lambda_grid              (default logspace(-1,4,6))
%       .resultPath               (default pwd)
%       .nuisance_labels          (default {}) cell array of predictor strings
%                                 to project out before ridge regression

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
if ~isfield(opts, 'before_stim_onset');        opts.before_stim_onset        = 5;                 end
if ~isfield(opts, 'time_window_after_offset'); opts.time_window_after_offset = 12;                end
if ~isfield(opts, 'time_resampling');          opts.time_resampling          = 1;                 end
if ~isfield(opts, 'lambda_grid');              opts.lambda_grid              = logspace(-1,4,6);  end
if ~isfield(opts, 'resultPath');               opts.resultPath               = pwd;               end
if ~isfield(opts, 'nuisance_labels');          opts.nuisance_labels          = {};                end

eta2_thresh_val          = opts.eta2_thresh_val;
min_stationary_trials    = opts.min_stationary_trials;
min_active_voxels        = opts.min_active_voxels;
before_stim_onset        = opts.before_stim_onset;
time_window_after_offset = opts.time_window_after_offset;
time_resampling          = opts.time_resampling;
lambda_grid              = opts.lambda_grid;
resultPath               = opts.resultPath;
nuisance_labels          = opts.nuisance_labels;

do_nuisance = ~isempty(nuisance_labels);

% ---- build output filename ----
eta_str = sprintf('eta%03d', round(eta2_thresh_val * 100));
hrf_str = sprintf('HRF%ds',  time_window_after_offset);

if do_nuisance
    nuis_tag = ['_clean_' strjoin(nuisance_labels, '_')];
else
    nuis_tag = '';
end

out_dir   = fullfile(resultPath, 'results_ridge_loo');
out_fname = fullfile(out_dir, sprintf('ridge_loo_%s_%s_%s%s.mat', model_name, eta_str, hrf_str, nuis_tag));

if isfile(out_fname)
    fprintf('\n[analysis_ridge_loo_ROI] Results already exist:\n');
    fprintf('  %s\n\n', out_fname);
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
fprintf(' model            : %s\n', model_name);
fprintf(' eta2 >=          : %.3f\n', eta2_thresh_val);
fprintf(' pre-stim window  : %d s\n', before_stim_onset);
fprintf(' post-stim window : %d s\n', time_window_after_offset);
fprintf(' time_resampling  : %.2f s\n', time_resampling);
fprintf(' output           : %s\n', out_fname);
fprintf(' nSubs            : %d\n', nSubs);
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
        glm = load(fullfile(glm_files(isub).folder, glm_files(isub).name)).data;

        bmask         = glm.bmask;
        allen_regions = glm.allen_regions;

        if ~isfield(glm.models, model_name)
            fprintf('  model "%s" not found in this file — skipping.\n', model_name);
            continue
        end

        model_result = glm.models.(model_name);

        pred_idx = find(contains(model_result.predictor_labels, 'stim'), 1);
        if isempty(pred_idx)
            fprintf('  no "stim" predictor in model "%s" — skipping.\n', model_name);
            continue
        end

        eta2      = squeeze(model_result.eta2(pred_idx, :, :));
        eta2_mask = (eta2 > eta2_thresh_val) & (bmask == 1);

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

        [PDI, ~, ~] = fonduta.io.datapath.load_session(glm.dataPath, glm.anatPath);

        TR           = mean(diff(PDI.time));
        TR_all(isub) = TR;

        stim_dur_s   = mean(PDI.stimInfo.endTime - PDI.stimInfo.startTime);
        stim_dur_s_all(isub) = stim_dur_s;
        fprintf('  TR = %.3f s   stim_dur = %.2f s\n', TR, stim_dur_s);

        T    = size(PDI.PDI, 3);
        nROI = numel(active_region_ids);

        % -----------------------------------------------------------------
        % Nuisance projection
        % -----------------------------------------------------------------
        if do_nuisance
            all_labels = model_result.predictor_labels(1:end-1); % exclude 'intercept'
            nuis_cols  = find(ismember(all_labels, nuisance_labels));

            missing_labels = nuisance_labels(~ismember(nuisance_labels, all_labels));
            if ~isempty(missing_labels)
                fprintf('  WARNING: nuisance_labels not found in model "%s": %s\n', ...
                    model_name, strjoin(missing_labels, ', '));
                fprintf('  Available labels: %s\n', strjoin(all_labels, ', '));
                fprintf('  Skipping nuisance projection for this session — using raw signal.\n');
                PDI_data = PDI.PDI;
            else
                found_labels = all_labels(nuis_cols);
                fprintf('  Nuisance projection: removing [%s]\n', strjoin(found_labels, ', '));

                [nx, ny, ~] = size(PDI.PDI);
                V        = nx * ny;
                Y        = reshape(PDI.PDI, V, T)';             % [T x V]
                Xnuis    = model_result.Xmodel(:, nuis_cols);   % [T x n_nuis]
                Bnuis    = reshape(model_result.betas(nuis_cols, :, :), numel(nuis_cols), V); % [n_nuis x V]
                Y_clean  = Y - Xnuis * Bnuis;                   % [T x V]
                PDI_data = reshape(Y_clean', nx, ny, T);        % [nx x ny x T]
            end
        else
            PDI_data = PDI.PDI;
        end

        % --- Build onset-delta design matrix with pre-stimulus lags ---
        step         = max(1, round(time_resampling / TR));
        k_before     = round(before_stim_onset / time_resampling);
        k_after      = round((stim_dur_s + time_window_after_offset) / time_resampling);
        lag_indices  = -k_before : k_after;
        K            = numel(lag_indices);
        T_safe       = min(T, numel(stim_box));

        onset_delta          = zeros(T_safe, 1);
        of_safe              = onset_frames(onset_frames <= T_safe);
        onset_delta(of_safe) = 1;

        X_fir = zeros(T_safe, K);
        for k_idx = 1:K
            shift_frames = lag_indices(k_idx) * step;
            if shift_frames >= 0
                shifted = circshift(onset_delta, shift_frames);
                shifted(1:shift_frames) = 0;
            else
                shifted = circshift(onset_delta, shift_frames);
                shifted(end+shift_frames+1:end) = 0;
            end
            X_fir(:, k_idx) = shifted;
        end

        N           = K;
        N_all(isub) = N;

        valid_trials = ((onset_frames - k_before * step) >= 1) & ...
                       ((onset_frames + k_after * step) <= T_safe);
        onset_frames = onset_frames(valid_trials);
        nTrials      = numel(onset_frames);

        if nTrials < 2
            fprintf('  fewer than 2 valid trials after trimming — skipping.\n');
            continue
        end

        win_len = K * step;
        trial_frames = zeros(nTrials, win_len);
        for t = 1:nTrials
            start_frame = onset_frames(t) - k_before * step;
            trial_frames(t,:) = start_frame : start_frame + win_len - 1;
        end
        trial_frames(trial_frames > T_safe) = T_safe;
        trial_frames(trial_frames < 1)      = 1;

        % --- Extract ROI-averaged signals and run ridge LOO-CV ---
        hrf_betas       = zeros(N, nROI);
        lambda_best_all = zeros(1, nROI);
        r2_best_all     = zeros(1, nROI);

        for r = 1:nROI
            rId = active_region_ids(r);
            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                region_label = atlas.infoRegions.acr{rId};
            else
                region_label = sprintf('ID_%d', rId);
            end

            fprintf('    [%2d/%2d] Fitting ROI: %-10s ... ', r, nROI, region_label);

            roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;
            vox       = reshape(PDI_data, [], T);
            y_full    = mean(vox(roi_supra(:), :), 1)';         % [T × 1]

            y = y_full(1:T_safe);
            y = (y - mean(y)) / (std(y) + eps);

            cv     = cvpartition(nTrials, 'LeaveOut');
            cv_mse = zeros(numel(lambda_grid), 1);

            for li = 1:numel(lambda_grid)
                fold_mse = zeros(cv.NumTestSets, 1);

                for fold = 1:cv.NumTestSets
                    test_trial  = find(cv.test(fold));
                    test_frames = trial_frames(test_trial, :);
                    test_frames = test_frames(test_frames >= 1 & test_frames <= T_safe);

                    train_mask = true(T_safe, 1);
                    train_mask(test_frames) = false;
                    train_frames = find(train_mask);

                    if numel(train_frames) < N + 1
                        fold_mse(fold) = Inf;
                        continue
                    end

                    B = ridge(y(train_frames), X_fir(train_frames,:), ...
                              lambda_grid(li), 0);
                    B = B(2:end);

                    y_pred = X_fir(test_frames(:),:) * B;
                    fold_mse(fold) = mean((y(test_frames(:)) - y_pred).^2);
                end

                cv_mse(li) = mean(fold_mse(isfinite(fold_mse)));
            end

            [~, best_idx]      = min(cv_mse);
            lambda_best        = lambda_grid(best_idx);
            lambda_best_all(r) = lambda_best;

            % --- Out-of-sample prediction performance (CV-R2) ---
            y_pred_cv = zeros(T_safe, 1);
            cv_eval   = cvpartition(nTrials, 'LeaveOut');
            
            for fold = 1:cv_eval.NumTestSets
                test_trial  = find(cv_eval.test(fold));
                test_frames = trial_frames(test_trial, :);
                test_frames = test_frames(test_frames >= 1 & test_frames <= T_safe);

                train_mask = true(T_safe, 1);
                train_mask(test_frames) = false;
                train_frames = find(train_mask);

                B_fold = ridge(y(train_frames), X_fir(train_frames, :), lambda_best, 0);
                B_fold = B_fold(2:end);

                y_pred_cv(test_frames(:)) = X_fir(test_frames(:), :) * B_fold;
            end

            test_mask_all = false(T_safe, 1);
            for t = 1:nTrials
                tf = trial_frames(t, :);
                test_mask_all(tf(tf >= 1 & tf <= T_safe)) = true;
            end
            
            y_eval      = y(test_mask_all);
            y_pred_eval = y_pred_cv(test_mask_all);
            
            ss_res = sum((y_eval - y_pred_eval).^2);
            ss_tot = sum((y_eval - mean(y_eval)).^2);
            r2_best_all(r) = max(0, 1 - (ss_res / (ss_tot + eps)));

            % Final full-dataset fit for FIR beta estimation
            B_final = ridge(y, X_fir, lambda_best, 0);
            hrf_betas(:,r) = B_final(2:end);

            fprintf('done (lambda = %.2e, CV-R2 = %.3f)\n', lambda_best, r2_best_all(r));
        end

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
                regional_hrf.(field).hrf   = hrf_betas(:,r);
                regional_hrf.(field).lam   = lambda_best_all(r);
                regional_hrf.(field).cv_r2 = r2_best_all(r);
                regional_hrf.(field).acr   = acr;
                regional_hrf.(field).name  = name;
            else
                regional_hrf.(field).hrf   = [regional_hrf.(field).hrf, hrf_betas(:,r)];
                regional_hrf.(field).lam   = [regional_hrf.(field).lam, lambda_best_all(r)];
                regional_hrf.(field).cv_r2 = [regional_hrf.(field).cv_r2, r2_best_all(r)];
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

TR_mean       = mean(TR_all,         'omitnan');
stim_dur_s    = mean(stim_dur_s_all, 'omitnan');
N_mean        = round(mean(N_all,    'omitnan'));
k_before_mean = round(before_stim_onset / time_resampling);
k_after_mean  = round((stim_dur_s + time_window_after_offset) / time_resampling);
lag_times_s   = (-k_before_mean : k_after_mean) * time_resampling;

save(out_fname, ...
    'regional_hrf', 'atlas', 'model_name', ...
    'chaoyi_hrfParams', 'chen2023_hrfParams', ...
    'eta2_thresh_val', 'nuisance_labels', 'TR_mean', 'stim_dur_s', ...
    'before_stim_onset', 'time_window_after_offset', 'time_resampling', 'N_mean', 'lag_times_s', 'lambda_grid', ...
    '-v7.3');

fprintf('\nResults saved to:\n  %s\n\n', out_fname);

end