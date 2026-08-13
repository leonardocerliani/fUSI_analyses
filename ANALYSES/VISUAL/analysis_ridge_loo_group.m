%% Load data and define parameters
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

addpath(genpath('.'))

atlas = fonduta.atlas.load_atlas();

condition    = 'VisualTest';   % experiment condition (passed to Datapath)

speedThresh  = 35;     % wheel speed threshold (counts/s) for running classification
minDuration  = 0.2;    % min running bout duration (s) to classify a trial as running

% SPM-style double-gamma HRF parameters:
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]

% % Chaoyi
% hrfParams    = [2.4  8  0.8  0.9  6  0  16];

% Chen2023
hrfParams = [4.95 8.69 1.1 1.1 1.8 0 32];

% Get the location of the data using Datapath
[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
resultPath = pwd;

%% Ridge CV-specific parameters

% Threshold on eta² from a standard GLM to identify active regions
eta2_thresh_val = 0.05;

% How many seconds to model after onset (10-20)
HRF_duration_s = 10;

% Consider whole allen region (false) or only suprathreshold voxels (true)
% when averaging the signal within a given allen region
use_suprathreshold_voxels = true;

% Use sessions with at least this many stationary trials (fewer → rank issues)
min_stationary_trials = 3;

% Ridge penalty candidates (log-spaced; CV selects the best per region per subject)
lambda_grid = logspace(-2, 4, 20);


%% Part 1 — Group ridge+CV analysis (loop over subjects)

nSubs = numel(subDataPath);

% regional_hrf: same structure as analysis_FIR_group.m
%   .hrf  [K x nSubsInRegion]  — ridge-estimated HRF betas per subject
%   .sim  [1 x nSubsInRegion]  — Pearson r with canonical HRF
%   .lam  [1 x nSubsInRegion]  — best lambda selected by LOO-CV per subject
%   .acr  char
%   .name char
regional_hrf = struct();

TR_all = nan(1, nSubs);

wb = waitbar(0, 'Running ridge+CV analysis...', 'Name', 'Group Ridge CV');

for isub = 1:nSubs

    fprintf('\n%s\n--- Sub %d / %d ---\n%s\n', repmat('-',1,40), isub, nSubs, repmat('-',1,40));
    waitbar(isub/nSubs, wb, sprintf('Subject %d / %d', isub, nSubs));

    try
        % --- Load session ---
        [PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
            subDataPath{isub}, subAnatPath{isub});

        TR = mean(diff(PDI.time));
        TR_all(isub) = TR;

        % --- Trial classification ---
        [stationaryTrialIdx, runningTrialIdx] = detect_running_trials( ...
            PDI, speedThresh, minDuration);

        if numel(stationaryTrialIdx) < min_stationary_trials
            fprintf('Sub %d: only %d stationary trial(s) — skipping (min = %d).\n', ...
                isub, numel(stationaryTrialIdx), min_stationary_trials);
            continue
        end

        % --- Masks ---
        [bmask, ~, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

        % --- Predictors ---
        [stim_all, stim_stationary] = build_visual_predictors( ...
            PDI, stationaryTrialIdx, runningTrialIdx);

        hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
        hrf        = @(ev) filter(hrf_kernel, 1, ev(:));

        [~, ~, runningFrameMask] = fn.build_wheel_signal(PDI, speedThresh, hrf_kernel);

        % --- Standard GLM to identify active regions ---
        stationaryFrames = ~runningFrameMask(:);
        PDI_steady       = PDI.PDI(:, :, stationaryFrames);
        M8_pred_steady   = hrf(stim_stationary(stationaryFrames));

        glm_std = fonduta.glm.ols( ...
            'M8_SteadyVisual', PDI_steady, bmask, ...
            M8_pred_steady, {'stim_stationary_hrf'});

        eta2      = squeeze(glm_std.eta2);
        eta2_mask = (eta2 > eta2_thresh_val) & (bmask == 1);

        active_region_ids = unique(allen_regions(eta2_mask));
        active_region_ids(active_region_ids <= 1) = [];

        if isempty(active_region_ids)
            fprintf('Sub %d: no active regions above eta2 threshold — skipping.\n', isub);
            continue
        end

        % --- FIR design matrix (onset deltas, K lags) ---
        T           = length(stim_stationary);
        onsets      = find(diff([0; stim_stationary(:)]) == 1);   % trial onset frames
        nTrials     = numel(onsets);

        onset_delta = zeros(T, 1);
        onset_delta(onsets) = 1;

        K           = round(HRF_duration_s / TR);
        lag_times_s = (0:K-1) * TR;

        X_fir = zeros(T, K);
        for k = 0:K-1
            shifted      = circshift(onset_delta, k);
            shifted(1:k) = 0;
            X_fir(:,k+1) = shifted;
        end

        % --- Extract ROI-averaged signals ---
        nROI     = numel(active_region_ids);
        T_frames = size(PDI.PDI, 3);
        Y_roi    = zeros(T_frames, nROI);

        for r = 1:nROI
            roi_all   = (allen_regions == active_region_ids(r)) & (bmask == 1);
            roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;

            if use_suprathreshold_voxels && any(roi_supra(:))
                sel_mask = roi_supra;
            else
                sel_mask = roi_all;
            end

            vox        = reshape(PDI.PDI, [], T_frames);
            Y_roi(:,r) = mean(vox(sel_mask(:), :), 1)';
        end

        % Z-score each ROI signal (same as engine.m does internally)
        Y_roi = zscore(Y_roi);

        % Align dimensions: stim_stationary may differ from PDI frame count by 1
        T_safe = min(T, T_frames);
        Y_roi  = Y_roi(1:T_safe, :);
        X_fir  = X_fir(1:T_safe, :);
        T      = T_safe;

        % Remove trials whose response window would exceed the (possibly trimmed) T
        valid_trials = onsets + K - 1 <= T;
        onsets       = onsets(valid_trials);
        nTrials      = numel(onsets);

        if nTrials < 2
            fprintf('Sub %d: fewer than 2 valid trials after trimming — skipping.\n', isub);
            continue
        end

        % --- LOO-CV ridge regression per region ---
        %
        % LOO is over trials, not timepoints. For each held-out trial t:
        %   - training frames: all timepoints NOT in trial t's response window
        %   - test frames    : onset(t) : onset(t)+K-1  (the K-lag response window)
        %
        % For each lambda candidate we accumulate MSE across LOO folds,
        % then refit with the best lambda on all data.

        % Build response windows for each trial: [nTrials x K] frame indices
        trial_frames = zeros(nTrials, K);
        for t = 1:nTrials
            trial_frames(t,:) = onsets(t) : onsets(t)+K-1;
        end
        % Clip to valid range (in case last trial extends past end of recording)
        trial_frames(trial_frames > T) = T;

        cv = cvpartition(nTrials, 'LeaveOut');

        hrf_betas    = zeros(K, nROI);
        lambda_best_all = zeros(1, nROI);

        for r = 1:nROI
            y = Y_roi(:, r);   % [T x 1] z-scored ROI signal

            % --- LOO-CV to select lambda ---
            cv_mse = zeros(numel(lambda_grid), 1);

            for li = 1:numel(lambda_grid)
                fold_mse = zeros(cv.NumTestSets, 1);

                for fold = 1:cv.NumTestSets
                    test_trial  = find(cv.test(fold));       % scalar trial index
                    train_trials = find(cv.training(fold));  % vector of trial indices

                    % Test frames: response window of the held-out trial
                    test_frames = trial_frames(test_trial, :);
                    test_frames = test_frames(test_frames >= 1 & test_frames <= T);

                    % Training frames: everything NOT in the test window
                    all_frames  = (1:T)';
                    train_frames_mask = true(T, 1);
                    train_frames_mask(test_frames) = false;
                    train_frames = all_frames(train_frames_mask);

                    if numel(train_frames) < K + 1
                        fold_mse(fold) = Inf;
                        continue
                    end

                    % Fit ridge on training frames (flag=0: return original-space betas).
                    % With flag=0 MATLAB prepends the intercept → drop first element.
                    B = ridge(y(train_frames), X_fir(train_frames,:), ...
                              lambda_grid(li), 0);
                    B = B(2:end);   % drop intercept; keep K predictor betas

                    % Predict held-out trial response window
                    test_frames_col = test_frames(:);   % ensure column index
                    y_pred = X_fir(test_frames_col,:) * B;
                    fold_mse(fold) = mean((y(test_frames_col) - y_pred).^2);
                end

                cv_mse(li) = mean(fold_mse(isfinite(fold_mse)));
            end

            [~, best_idx]     = min(cv_mse);
            lambda_best       = lambda_grid(best_idx);
            lambda_best_all(r) = lambda_best;

            % --- Final fit with best lambda on all data ---
            % ridge() with flag=0 returns [K+1 x 1] (intercept first) — drop it
            B_final = ridge(y, X_fir, lambda_best, 0);
            hrf_betas(:,r) = B_final(2:end);
        end

        % --- Compute similarity with canonical HRF ---
        hrf_prior = hrf_kernel(1:min(K, numel(hrf_kernel)));
        if numel(hrf_prior) < K; hrf_prior(end+1:K) = 0; end
        hrf_prior = hrf_prior(:) / max(hrf_prior);

        % --- Store results ---
        for r = 1:nROI
            rId = active_region_ids(r);

            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{rId};
                name = atlas.infoRegions.name{rId};
            else
                acr  = sprintf('ID_%d', rId);
                name = acr;
            end

            field   = matlab.lang.makeValidName(acr);
            sim_val = corr(hrf_betas(:,r), hrf_prior);

            if ~isfield(regional_hrf, field)
                regional_hrf.(field).hrf  = hrf_betas(:,r);
                regional_hrf.(field).sim  = sim_val;
                regional_hrf.(field).lam  = lambda_best_all(r);
                regional_hrf.(field).acr  = acr;
                regional_hrf.(field).name = name;
            else
                regional_hrf.(field).hrf  = [regional_hrf.(field).hrf,  hrf_betas(:,r)];
                regional_hrf.(field).sim  = [regional_hrf.(field).sim,  sim_val];
                regional_hrf.(field).lam  = [regional_hrf.(field).lam,  lambda_best_all(r)];
            end
        end

        fprintf('Sub %d: %d active regions  (lambda range: %.3g – %.3g)\n', ...
            isub, nROI, min(lambda_best_all), max(lambda_best_all));

    catch ME
        fprintf('Sub %d: ERROR — %s\n', isub, ME.message);
        fprintf('  In: %s  line %d\n', ME.stack(1).name, ME.stack(1).line);
    end


end

close(wb);

% Group-average TR and lag axis
TR_mean     = nanmean(TR_all);
lag_times_s = (0 : round(HRF_duration_s / TR_mean) - 1) * TR_mean;
K           = numel(lag_times_s);

% --- Save results ---
out_fname = fullfile(resultPath, sprintf('ridge_cv_group_eta2_%.2f_HRF_%dsec.mat', ...
    eta2_thresh_val, HRF_duration_s));

save(out_fname, 'regional_hrf', 'atlas', 'hrfParams', ...
    'eta2_thresh_val', 'HRF_duration_s', 'TR_mean', 'lag_times_s', 'K', ...
    'lambda_grid', 'use_suprathreshold_voxels', '-v7.3');

fprintf('\nResults saved to: %s\n', out_fname);


%% plot_group_hrf — Bar chart: mean ± std HRF similarity per region

% ---- parameters ----
mat_file         = 'ridge_cv_group_eta2_0.05_HRF_10sec.mat';   % or specify path directly
sim_thresh       = 0.5;         % threshold for correlation to canonical HRF
n_subject_thresh = 4;           % only plot regions present in >= this many subjects
summary_stat     = 'mean';      % 'mean' or 'median'
% --------------------

S = load(mat_file);

region_fields = fieldnames(S.regional_hrf);
nRegions = numel(region_fields);

acr_list  = cell(nRegions, 1);
mean_sim  = zeros(nRegions, 1);
std_sim   = zeros(nRegions, 1);
nsub_list = zeros(nRegions, 1);
name_list = cell(nRegions, 1);

for fi = 1:nRegions
    reg = S.regional_hrf.(region_fields{fi});
    acr_list{fi}  = reg.acr;
    name_list{fi} = reg.name;
    mean_sim(fi)  = mean(reg.sim);
    std_sim(fi)   = std(reg.sim);
    nsub_list(fi) = size(reg.hrf, 2);
end

% Filter by n_subject_thresh
keep      = nsub_list >= n_subject_thresh;
acr_list  = acr_list(keep);
name_list = name_list(keep);
mean_sim  = mean_sim(keep);
std_sim   = std_sim(keep);
nsub_list = nsub_list(keep);
nRegions  = sum(keep);

if nRegions == 0
    fprintf('No regions have >= %d subjects. Lower n_subject_thresh.\n', n_subject_thresh);
    return
end

% Sort descending
[mean_sim_sorted, sort_idx] = sort(mean_sim, 'descend');
std_sim_sorted = std_sim(sort_idx);
acr_sorted     = acr_list(sort_idx);
name_sorted    = name_list(sort_idx);
nsub_sorted    = nsub_list(sort_idx);

% Console report
fprintf('\nRidge CV — HRF similarity — %d regions with n >= %d subjects (sorted):\n\n', ...
    nRegions, n_subject_thresh);
fprintf('%-12s  %-45s  %5s  %s\n', 'Acronym', 'Full name', 'nSub', 'mean_sim ± std');
fprintf('%s\n', repmat('-', 1, 85));
for fi = 1:nRegions
    marker = '';
    if mean_sim_sorted(fi) >= sim_thresh; marker = '  ✓'; end
    fprintf('%-12s  %-45s  %5d  %.3f ± %.3f%s\n', ...
        acr_sorted{fi}, name_sorted{fi}, nsub_sorted(fi), ...
        mean_sim_sorted(fi), std_sim_sorted(fi), marker);
end
nSel = sum(mean_sim_sorted >= sim_thresh);
fprintf('\n%d / %d regions with mean similarity >= %.2f  (marked ✓)\n', nSel, nRegions, sim_thresh);

% Bar chart
figure('Name', sprintf('Ridge CV: HRF similarity  (n >= %d subs)', n_subject_thresh), ...
    'Position', [50 50 max(600, 30*nRegions) 420]);
hold on;
bar(1:nRegions, mean_sim_sorted, 'FaceColor', [0.25 0.65 0.45], 'EdgeColor', 'none');
errorbar(1:nRegions, mean_sim_sorted, std_sim_sorted, ...
    'k.', 'LineWidth', 1.2, 'CapSize', 4);
yline(sim_thresh, '--r', sprintf('sim = %.2f', sim_thresh), ...
    'LineWidth', 1.5, 'LabelHorizontalAlignment', 'right');
yline(0, ':k', 'LineWidth', 0.8);
hold off;
set(gca, 'XTick', 1:nRegions, 'XTickLabel', acr_sorted, ...
    'XTickLabelRotation', 45, 'FontSize', 9, 'TickLabelInterpreter', 'none');
ylabel('Pearson r  (vs canonical HRF)');
xlabel(sprintf('Brain region  (n \\geq %d subs)', n_subject_thresh));
title(sprintf('Ridge CV — HRF similarity  (n \\geq %d subs per region)', n_subject_thresh), ...
    'FontSize', 11, 'FontWeight', 'bold');
for fi = 1:nRegions
    text(fi, mean_sim_sorted(fi) + std_sim_sorted(fi) + 0.02, ...
        sprintf('n=%d', nsub_sorted(fi)), ...
        'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.3 0.3 0.3]);
end
ylim([min(-0.1, min(mean_sim_sorted - std_sim_sorted) - 0.05), ...
      max(1.0,  max(mean_sim_sorted + std_sim_sorted) + 0.12)]);
box off;


%% plot_group_hrf_region — Single region HRF deep-dive

% ---- parameters ----
mat_file     = 'ridge_cv_group_eta2_0.05_HRF_10sec.mat';   % or specify path directly
target_acr   = 'RSPv';    % Allen acronym (choose from table above)
summary_stat = 'median';     % 'mean' or 'median'
% --------------------

S = load(mat_file);

target_field = matlab.lang.makeValidName(target_acr);

if ~isfield(S.regional_hrf, target_field)
    fprintf('Region "%s" not found in results.\n', target_acr);
    return
end

reg  = S.regional_hrf.(target_field);
H    = reg.hrf;        % [K x nSub]
nSub = size(H, 2);

% Central tendency and spread
switch lower(summary_stat)
    case 'median'
        mu        = median(H, 2);
        err       = mad(H, 1, 2);
        stat_lbl  = 'median \pm MAD';
        stat_desc = 'median ± MAD';
    otherwise
        mu        = mean(H, 2);
        err       = std(H, 0, 2) / sqrt(nSub);
        stat_lbl  = 'mean \pm SE';
        stat_desc = 'mean ± SE';
end

% Canonical HRFs scaled to data amplitude
% Chen2023 (used for GLM)
hrf_prior_chen = fonduta.signal.hrf(S.TR_mean, hrfParams);
hrf_prior_chen = hrf_prior_chen(1:min(S.K, numel(hrf_prior_chen)));
if numel(hrf_prior_chen) < S.K; hrf_prior_chen(end+1:S.K) = 0; end
hrf_prior_chen = hrf_prior_chen(:) / max(hrf_prior_chen) * max(abs(mu));

% Chaoyi
chaoyi_hrfParams = [2.4 8 0.8 0.9 6 0 16];
hrf_prior_chaoyi = fonduta.signal.hrf(S.TR_mean, chaoyi_hrfParams);
hrf_prior_chaoyi = hrf_prior_chaoyi(1:min(S.K, numel(hrf_prior_chaoyi)));
if numel(hrf_prior_chaoyi) < S.K; hrf_prior_chaoyi(end+1:S.K) = 0; end
hrf_prior_chaoyi = hrf_prior_chaoyi(:) / max(hrf_prior_chaoyi) * max(abs(mu));

% Console summary
fprintf('\n%s — %s\n', reg.acr, reg.name);
fprintf('n subjects : %d\n', nSub);
fprintf('mean sim   : %.3f ± %.3f\n', mean(reg.sim), std(reg.sim));
fprintf('median sim : %.3f  (MAD = %.3f)\n\n', median(reg.sim), mad(reg.sim, 1));
fprintf('Per-subject lambda (best ridge penalty):\n');
for s = 1:nSub
    fprintf('  sub %02d : r = %.3f   lambda = %.4g\n', s, reg.sim(s), reg.lam(s));
end

% Plot
figure('Name', sprintf('Ridge CV HRF — %s  (%s)', reg.acr, stat_desc), ...
    'Position', [100 100 560 400]);
hold on;

for s = 1:nSub
    plot(S.lag_times_s, H(:,s), 'Color', [0.4 0.8 0.55 0.4], 'LineWidth', 0.8);
end

fill([S.lag_times_s, fliplr(S.lag_times_s)], ...
     [mu+err; flipud(mu-err)]', ...
     [0.1 0.55 0.3], 'FaceAlpha', 0.2, 'EdgeColor', 'none');

plot(S.lag_times_s, mu, 'Color', [0.05 0.45 0.2], 'LineWidth', 2.5);
plot(S.lag_times_s, hrf_prior_chen,   'k--',  'LineWidth', 2);
plot(S.lag_times_s, hrf_prior_chaoyi, '--', 'Color', [0.6 0.2 0.1], 'LineWidth', 2);

hold off;
yline(0, ':k', 'LineWidth', 0.8);

xlabel('Time after onset (s)');
ylabel('Beta (z-score units)');
title(sprintf('%s — %s  (n=%d,  r=%.2f \\pm %.2f)', ...
    reg.acr, reg.name, nSub, mean(reg.sim), std(reg.sim)), ...
    'Interpreter', 'tex');
legend({'individual subs', '', stat_lbl, 'Chen2023 HRF', 'Chaoyi HRF'}, ...
    'Location', 'northeast', 'Interpreter', 'tex');
box off;