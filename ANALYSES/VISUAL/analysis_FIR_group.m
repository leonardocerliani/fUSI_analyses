%% Load data for one sub and define parameters
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

addpath(genpath('.'))

atlas = fonduta.atlas.load_atlas();

condition    = 'VisualTest';   % experiment condition (passed to Datapath)
resultFolder = 'fir_example';           % output subfolder name

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
% Modify the resultPath so that it points to the current directory (only for this example)
resultPath = pwd;

%% FIR specific parameters

% We want to estimate the HRF only in regions where we expect to have an
% effect (there are 500+ regions...), therefore we first do a standard GLM
% with the hrf from Chen2023 and we retain regions with an eta2 > threshold
eta2_thresh_val = 0.01;

% How many seconds to model after onset (10-20)
HRF_duration_s = 10;   

% Consider whole allen region (false) or only suprathreshold voxels (true)
% when averaging the signal within a given allen region
use_suprathreshold_voxels = true;

% Use sessions where there are at least this number of stationary trials
min_stationary_trials = 3


%% Part 1 — Group FIR analysis (loop over subjects)

nSubs = numel(subDataPath);

% regional_hrf: struct with one field per Allen region acronym.
% Each field is itself a struct with:
%   .hrf    [K x nSubsInRegion]  — estimated HRF betas per subject
%   .sim    [1 x nSubsInRegion]  — Pearson r with a priori HRF
%   .acr    char                 — acronym (same as field name, sanitised)
%   .name   char                 — full region name from atlas
regional_hrf = struct();

% Record mean TR across subjects for later use
TR_all = nan(1, nSubs);

wb = waitbar(0, 'Running FIR analysis...', 'Name', 'Group FIR');

for isub = 1:nSubs

    fprintf('\n%s\n--- Sub %d / %d ---\n%s\n', repmat('-',1,40), isub, nSubs, repmat('-',1,40));
    waitbar(isub/nSubs, wb, sprintf('Subject %d / %d', isub, nSubs));

    try
        % --- Load session ---
        [PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
            subDataPath{isub}, subAnatPath{isub});

        TR  = mean(diff(PDI.time));
        TR_all(isub) = TR;

        % --- Masks and predictors ---
        [stationaryTrialIdx, runningTrialIdx] = detect_running_trials( ...
            PDI, speedThresh, minDuration);

        % Skip subjects with too few stationary trials (rank-deficient design matrix)
        if numel(stationaryTrialIdx) < min_stationary_trials
            fprintf('Sub %d: only %d stationary trial(s) — skipping (min = %d).\n', ...
                isub, numel(stationaryTrialIdx), min_stationary_trials);
            continue
        end

        [bmask, ~, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

        [stim_all, stim_stationary] = build_visual_predictors( ...
            PDI, stationaryTrialIdx, runningTrialIdx);

        hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
        hrf        = @(ev) filter(hrf_kernel, 1, ev(:));

        [~, ~, runningFrameMask] = fn.build_wheel_signal(PDI, speedThresh, hrf_kernel);

        % --- Standard GLM to find active regions ---
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

        % --- Build FIR design matrix ---
        T           = length(stim_stationary);
        onset_delta = zeros(T, 1);
        onsets      = find(diff([0; stim_stationary(:)]) == 1);
        onset_delta(onsets) = 1;

        K           = round(HRF_duration_s / TR);
        lag_times_s = (0:K-1) * TR;

        X_fir = zeros(T, K);
        for k = 0:K-1
            shifted       = circshift(onset_delta, k);
            shifted(1:k)  = 0;
            X_fir(:,k+1) = shifted;
        end
        predictor_labels = arrayfun(@(k) sprintf('lag_%02d',k), 0:K-1, 'UniformOutput', false);

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

            vox         = reshape(PDI.PDI, [], T_frames);
            Y_roi(:,r)  = mean(vox(sel_mask(:), :), 1)';
        end

        % --- Run FIR GLM ---
        glm_fir   = fonduta.glm.engine('M_FIR', Y_roi, X_fir, predictor_labels);
        hrf_betas = glm_fir.betas(1:K, :);   % [K x nROI]

        % --- Compute similarity with a priori HRF ---
        hrf_prior = hrf_kernel(1:min(K, numel(hrf_kernel)));
        if numel(hrf_prior) < K; hrf_prior(end+1:K) = 0; end
        hrf_prior = hrf_prior(:) / max(hrf_prior);

        % --- Store results in regional_hrf struct ---
        for r = 1:nROI
            rId = active_region_ids(r);

            % Get acronym and full name from atlas
            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{rId};
                name = atlas.infoRegions.name{rId};
            else
                acr  = sprintf('ID_%d', rId);
                name = acr;
            end

            % Sanitise acronym for use as struct field name
            field = matlab.lang.makeValidName(acr);

            sim_val = corr(hrf_betas(:,r), hrf_prior);

            if ~isfield(regional_hrf, field)
                regional_hrf.(field).hrf  = hrf_betas(:,r);
                regional_hrf.(field).sim  = sim_val;
                regional_hrf.(field).acr  = acr;
                regional_hrf.(field).name = name;
            else
                regional_hrf.(field).hrf  = [regional_hrf.(field).hrf,  hrf_betas(:,r)];
                regional_hrf.(field).sim  = [regional_hrf.(field).sim,  sim_val];
            end
        end

        fprintf('Sub %d: %d active regions\n', isub, nROI);

    catch ME
        fprintf('Sub %d: ERROR — %s\n', isub, ME.message);
    end

end

close(wb);

% Compute mean TR across successful subjects
TR_mean = nanmean(TR_all);
lag_times_s = (0 : round(HRF_duration_s / TR_mean) - 1) * TR_mean;
K = numel(lag_times_s);

% --- Save results ---
out_fname = fullfile(resultPath, sprintf('FIR_group_eta2_%.2f_HRF_%dsec.mat', ...
    eta2_thresh_val, HRF_duration_s));

save(out_fname, 'regional_hrf', 'atlas', 'hrfParams', ...
    'eta2_thresh_val', 'HRF_duration_s', 'TR_mean', 'lag_times_s', 'K', ...
    'use_suprathreshold_voxels', '-v7.3');

fprintf('\nResults saved to: %s\n', out_fname);


%% plot_group_hrf — Bar chart: mean ± std HRF similarity per region

% ---- parameters ----
mat_file   = 'FIR_group_eta2_0.05_HRF_10sec.mat';   % or: 'FIR_group_eta2_0.05_HRF_10sec.mat'
sim_thresh = 0.5;         % threshold for correlation to canonical HRF
summary_stat = 'mean'     % can be 'mean' or 'median'
n_subject_thresh = 3
% --------------------

S = load(mat_file);

% Collect mean and std similarity for all regions
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

% Apply n_subject_thresh filter
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

% Sort by mean similarity (descending)
[mean_sim_sorted, sort_idx] = sort(mean_sim, 'descend');
std_sim_sorted  = std_sim(sort_idx);
acr_sorted      = acr_list(sort_idx);
name_sorted     = name_list(sort_idx);
nsub_sorted     = nsub_list(sort_idx);

% --- Console report (sorted) ---
fprintf('\nHRF similarity — %d regions with n >= %d subjects (sorted):\n\n', nRegions, n_subject_thresh);
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

% --- Bar chart ---
figure('Name', 'Group FIR: HRF similarity per region', ...
    'Position', [50 50 max(600, 30*nRegions) 420]);

hold on;
b = bar(1:nRegions, mean_sim_sorted, 'FaceColor', [0.35 0.55 0.85], 'EdgeColor', 'none');
errorbar(1:nRegions, mean_sim_sorted, std_sim_sorted, ...
    'k.', 'LineWidth', 1.2, 'CapSize', 4);
yline(sim_thresh, '--r', sprintf('sim = %.2f', sim_thresh), ...
    'LineWidth', 1.5, 'LabelHorizontalAlignment', 'right');
yline(0, ':k', 'LineWidth', 0.8);
hold off;

set(gca, 'XTick', 1:nRegions, 'XTickLabel', acr_sorted, ...
    'XTickLabelRotation', 45, 'FontSize', 9, 'TickLabelInterpreter', 'none');
ylabel('Pearson r  (vs canonical HRF)');
xlabel('Brain region (sorted by mean similarity)');
title(sprintf('Group FIR — HRF similarity  (n_{sub} shown per bar)', sim_thresh), ...
    'FontSize', 11, 'FontWeight', 'bold');

% Annotate each bar with nSub
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
mat_file    = 'FIR_group_eta2_0.05_HRF_10sec.mat';   % or: 'FIR_group_eta2_0.05_HRF_10sec.mat'
target_acr  = 'RSPd';    % Allen acronym to plot (choose from the table above)
summary_stat = ['median']     % can be 'mean' or 'median'
% --------------------

S = load(mat_file);

target_field = matlab.lang.makeValidName(target_acr);

if ~isfield(S.regional_hrf, target_field)
    fprintf('Region "%s" not found in results (no subject passed eta2 threshold).\n', target_acr);
    return
end

reg  = S.regional_hrf.(target_field);
H    = reg.hrf;        % [K x nSub]
nSub = size(H, 2);

% Compute central tendency and spread based on summary_stat
switch lower(summary_stat)
    case 'median'
        mu        = median(H, 2);
        err       = mad(H, 1, 2);   % median absolute deviation (flag=1 → median-based)
        stat_lbl  = 'median \pm MAD';
        stat_desc = 'median ± MAD';
    otherwise   % 'mean' (default)
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
fprintf('Per-subject HRF similarity:\n');
for s = 1:nSub
    fprintf('  sub %02d : r = %.3f\n', s, reg.sim(s));
end

% Plot
figure('Name', sprintf('FIR HRF — %s  (%s)', reg.acr, stat_desc), ...
    'Position', [100 100 560 400]);
hold on;

% Individual subject traces (thin, semi-transparent)
for s = 1:nSub
    plot(S.lag_times_s, H(:,s), 'Color', [0.6 0.7 1.0 0.4], 'LineWidth', 0.8);
end

% Central tendency ± spread shaded band
fill([S.lag_times_s, fliplr(S.lag_times_s)], ...
     [mu+err; flipud(mu-err)]', ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none');

% Central tendency line
plot(S.lag_times_s, mu, 'b-', 'LineWidth', 2.5);

% Canonical HRFs
plot(S.lag_times_s, hrf_prior_chen,   'k--', 'LineWidth', 2);
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
