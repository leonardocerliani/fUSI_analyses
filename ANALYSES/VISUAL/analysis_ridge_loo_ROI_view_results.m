% analysis_ridge_loo_ROI_view_results.m
%
% Interactive script for viewing results produced by analysis_ridge_loo_ROI.m.
% Open this file in the MATLAB editor and run each %% cell separately.
%
% Part 1 — Setup:   load packages (run this cell first)
% Part 2 — Table:   print sorted HRF-similarity table (mean ± std across subjects),
%                   filtered by n_subject_thresh and sim_thresh.
%                   Smoothing (movmean) and similarity (corr vs canonical HRF)
%                   are computed here, not in the main analysis script.
% Part 3 — Plot:    show recovered HRF for a single Allen region, with
%                   individual-subject curves, group mean ± SE, and both
%                   canonical HRF references (Chaoyi and Chen2023)
%
% The results .mat files live in:
%   results_ridge_loo/ridge_loo_<model_name>_<eta_str>_<HRF_str>.mat
%   e.g. ridge_loo_M1_StimOnly_eta005_HRF12s.mat
%
% To list available model names from a GLM file:
%   glm_path  = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
%   tmp_files = dir(fullfile(glm_path, 'glm_*.mat'));
%   tmp = load(fullfile(tmp_files(1).folder, tmp_files(1).name));
%   fieldnames(tmp.data.models)


%% Part 1 — Setup (run this cell first)

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
addpath(genpath('.'));

warning('off', 'all')

%% Part 2 — HRF similarity table

% ---- parameters ----
% mat_file         = fullfile(pwd, 'results_ridge_loo', 'ridge_loo_M8_SteadyVisual_eta003_HRF12s.mat');
% mat_file         = fullfile(pwd, 'results_ridge_loo', 'ridge_loo_M1_StimOnly_eta003_HRF12s.mat');
mat_file         = fullfile(pwd, 'results_ridge_loo', 'ridge_loo_M5_Behavior_eta003_HRF12s.mat');

target_acr   = 'RSPd';

sim_thresh       = 0.7;    % only show regions with Chaoyi r >= this
n_subject_thresh = 5;      % only show regions present in >= this many subjects
smooth_win_s     = 0;      % moving-average smoothing window in seconds (0 = off)
%                            applied to the N betas before computing similarity
% --------------------

S = load(mat_file);

% Betas are at time_resampling resolution → smooth window in nodes
smooth_win_nodes = max(1, round(smooth_win_s / S.time_resampling));

% Build canonical references sampled at the node lag times
stim_frames_one = round(S.stim_dur_s / S.TR_mean);
W_frames        = round((S.stim_dur_s + S.time_window_after_offset) / S.TR_mean);
boxcar_one      = [ones(stim_frames_one, 1); zeros(W_frames, 1)];

ref_chaoyi = build_canonical_ref(boxcar_one, S.TR_mean, S.chaoyi_hrfParams,   S.N_mean, S.time_resampling);
ref_chen   = build_canonical_ref(boxcar_one, S.TR_mean, S.chen2023_hrfParams, S.N_mean, S.time_resampling);

region_fields = fieldnames(S.regional_hrf);
nRegions      = numel(region_fields);

acr_list  = cell(nRegions, 1);
name_list = cell(nRegions, 1);
nsub_list = zeros(nRegions, 1);
mean_ch   = zeros(nRegions, 1);   std_ch  = zeros(nRegions, 1);
mean_c23  = zeros(nRegions, 1);   std_c23 = zeros(nRegions, 1);

for fi = 1:nRegions
    reg = S.regional_hrf.(region_fields{fi});
    H   = reg.hrf;          % [N × nSub]  raw betas
    nS  = size(H, 2);
    acr_list{fi}  = reg.acr;
    name_list{fi} = reg.name;
    nsub_list(fi) = nS;

    if nS < n_subject_thresh || size(H,1) ~= S.N_mean
        mean_ch(fi)  = NaN;  std_ch(fi)  = NaN;
        mean_c23(fi) = NaN;  std_c23(fi) = NaN;
        continue
    end

    % Smooth betas (in node-space), then compute per-subject similarity
    H_sm     = movmean(H, smooth_win_nodes, 1);
    sims_ch  = arrayfun(@(s) corr(H_sm(:,s), ref_chaoyi,  'rows','complete'), 1:nS);
    sims_c23 = arrayfun(@(s) corr(H_sm(:,s), ref_chen,    'rows','complete'), 1:nS);

    mean_ch(fi)  = mean(sims_ch);    std_ch(fi)  = std(sims_ch);
    mean_c23(fi) = mean(sims_c23);   std_c23(fi) = std(sims_c23);
end

% Filter by n_subject_thresh and non-NaN
keep = nsub_list >= n_subject_thresh & ~isnan(mean_ch);

acr_list  = acr_list(keep);   name_list  = name_list(keep);
nsub_list = nsub_list(keep);
mean_ch   = mean_ch(keep);    std_ch     = std_ch(keep);
mean_c23  = mean_c23(keep);   std_c23    = std_c23(keep);

% Sort descending by Chaoyi similarity
[~, idx] = sort(mean_ch, 'descend');
acr_s    = acr_list(idx);   name_s   = name_list(idx);
nsub_s   = nsub_list(idx);
mch_s    = mean_ch(idx);    sch_s    = std_ch(idx);
mc23_s   = mean_c23(idx);   sc23_s   = std_c23(idx);

% Apply sim_thresh filter
above  = mch_s >= sim_thresh;
acr_s  = acr_s(above);    name_s  = name_s(above);    nsub_s  = nsub_s(above);
mch_s  = mch_s(above);    sch_s   = sch_s(above);
mc23_s = mc23_s(above);   sc23_s  = sc23_s(above);
nR     = sum(above);

clc
fprintf('\n[%s]  Ridge LOO — HRF similarity — %d regions (n >= %d subs):\n\n', ...
    S.model_name, nR, n_subject_thresh);
fprintf('%-12s  %-40s  %5s  %-22s  %-22s\n', ...
    'Acronym', 'Full name', 'nSub', 'Chaoyi r +/- std', 'Chen2023 r +/- std');
fprintf('%s\n', repmat('-', 1, 105));
for fi = 1:nR
    marker = '';
    if mch_s(fi) >= sim_thresh; marker = '  v'; end
    fprintf('%-12s  %-40s  %5d  %.3f +/- %.3f          %.3f +/- %.3f%s\n', ...
        acr_s{fi}, name_s{fi}, nsub_s(fi), ...
        mch_s(fi), sch_s(fi), mc23_s(fi), sc23_s(fi), marker);
end
fprintf('\n%d / %d regions with Chaoyi mean r >= %.2f  (marked v)\n', ...
    sum(mch_s >= sim_thresh), nR, sim_thresh);
fprintf('\nSettings:  TR_mean = %.3f s   time_resampling = %.2f s   N = %d nodes   post-stim = %d s\n', ...
    S.TR_mean, S.time_resampling, S.N_mean, S.time_window_after_offset);
fprintf('smooth_win_s = %.1f s   eta2_thresh = %.3f\n', smooth_win_s, S.eta2_thresh_val);


% Part 3 — Single region plot

% ---- parameters ----
% target_acr   = 'RSPv';      % Allen acronym — pick from Part 2 table
% smooth_win_s = 0;           % seconds (0 = off); applied to betas before plotting
% pre_onset_s  = 0;           % seconds of zero-baseline to prepend for display only
%                             (similarity is computed on post-onset betas only)
% --------------------

S = load(mat_file);

target_field = matlab.lang.makeValidName(target_acr);

if ~isfield(S.regional_hrf, target_field)
    fprintf('Region "%s" not found in:\n  %s\n', target_acr, mat_file);
    return
end

reg  = S.regional_hrf.(target_field);
H    = reg.hrf;        % [N × nSub]  raw betas
nSub = size(H, 2);
N    = S.N_mean;
lag  = S.lag_times_s;  % [1 × N]

% Smooth betas after fitting (betas at time_resampling resolution)
if smooth_win_s > 0
    smooth_win_nodes = max(1, round(smooth_win_s / S.time_resampling));
    H_plot = movmean(H, smooth_win_nodes, 1);
else
    H_plot = H;
end

mu = mean(H_plot, 2);
se = std(H_plot,  0, 2) / sqrt(nSub);

% ---- Build canonical references (conv(boxcar, hrf) sampled at FIR nodes) ----
stim_frames_one = round(S.stim_dur_s / S.TR_mean);
W_frames        = round((S.stim_dur_s + S.time_window_after_offset) / S.TR_mean);
boxcar_one      = [ones(stim_frames_one, 1); zeros(W_frames, 1)];

amp        = max(abs(mu));   % scale canonical to match data amplitude
ref_chaoyi = build_canonical_ref(boxcar_one, S.TR_mean, S.chaoyi_hrfParams,   N, S.time_resampling);
ref_chen   = build_canonical_ref(boxcar_one, S.TR_mean, S.chen2023_hrfParams, N, S.time_resampling);
ref_chaoyi = ref_chaoyi * amp;
ref_chen   = ref_chen   * amp;

% Per-subject similarity — computed on post-onset betas only (before prepending zeros)
sims_ch  = arrayfun(@(s) corr(H_plot(:,s), ref_chaoyi/amp, 'rows','complete'), 1:nSub);
sims_c23 = arrayfun(@(s) corr(H_plot(:,s), ref_chen/amp,   'rows','complete'), 1:nSub);

% ---- Prepend pre-onset baseline for display (zeros) ----
n_pre           = round(pre_onset_s / S.time_resampling);
lag_display     = [(-n_pre:-1) * S.time_resampling, lag];
H_display       = [zeros(n_pre, nSub); H_plot];
mu_display      = [zeros(n_pre, 1);    mu];
se_display      = [zeros(n_pre, 1);    se];
ref_ch_display  = [zeros(n_pre, 1);    ref_chaoyi];
ref_c23_display = [zeros(n_pre, 1);    ref_chen];

% % ---- Console summary ----
% fprintf('\n%s — %s\n', reg.acr, reg.name);
% fprintf('N nodes      : %d   (time_resampling = %.2f s,  TR = %.3f s)\n', N, S.time_resampling, S.TR_mean);
% fprintf('Post-offset  : %d s   stim_dur = %.2f s\n', S.time_window_after_offset, S.stim_dur_s);
% fprintf('n subjects   : %d\n', nSub);
% fprintf('Chaoyi sim   : %.3f +/- %.3f\n', mean(sims_ch),  std(sims_ch));
% fprintf('Chen2023 sim : %.3f +/- %.3f\n', mean(sims_c23), std(sims_c23));
% fprintf('\nPer-subject results:\n');
% for s = 1:nSub
%     fprintf('  sub %02d :  r_chaoyi = %.3f   r_chen = %.3f   lambda = %.4g\n', ...
%         s, sims_ch(s), sims_c23(s), reg.lam(s));
% end

% ---- Plot ----
figure('Name', sprintf('[%s]  Ridge LOO HRF — %s', S.model_name, reg.acr), ...
    'Position', [100 100 620 430]);
hold on;

% % Individual subject curves (thin, semi-transparent)
% for s = 1:nSub
%     plot(lag_display, H_display(:,s), 'Color', [0.4 0.75 0.55 0.35], 'LineWidth', 0.8);
% end

% Group mean ± SE shaded band
fill([lag_display, fliplr(lag_display)], [mu_display+se_display; flipud(mu_display-se_display)]', ...
     [0.1 0.5 0.3], 'FaceAlpha', 0.2, 'EdgeColor', 'none');

% Group mean
h_mean = plot(lag_display, mu_display, 'Color', [0.05 0.4 0.2], 'LineWidth', 2.5);

% Canonical references (peak-scaled to data amplitude)
h_chaoyi = plot(lag_display, ref_ch_display,  'k--', 'LineWidth', 2);
h_chen   = plot(lag_display, ref_c23_display, '--',  'LineWidth', 2, 'Color', [0.75 0.2 0.1]);

hold off;

% Baseline / onset / offset markers
xline(-pre_onset_s, ':k', 'LineWidth', 0.6);
xline(0,             ':k', 'onset',  'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
xline(S.stim_dur_s,  ':k', 'offset', 'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
yline(0, ':k', 'LineWidth', 0.8);

xlabel('Time after stimulus onset (s)');
ylabel('Beta  (z-score units)');
title(sprintf('[%s]  %s — %s  (n=%d,  r_{Chaoyi}=%.2f)', ...
    S.model_name, reg.acr, reg.name, nSub, mean(sims_ch)), ...
    'Interpreter', 'tex', 'FontSize', 11, 'FontWeight', 'bold');
legend([h_mean, h_chaoyi, h_chen], ...
    {'mean \pm SE', 'Chaoyi HRF', 'Chen2023 HRF'}, ...
    'Location', 'northeast', 'Interpreter', 'tex');
box off;


% =========================================================================
% Local helper: build canonical HRF reference at node times.
%
% Convolves a single-trial stimulus boxcar with the HRF kernel, then
% samples at N node times spaced time_resampling apart from stimulus onset.
% Peak-normalises to [0, 1].
% =========================================================================
function ref = build_canonical_ref(boxcar_one, TR, hrfParams, N, time_resampling)
    hrf_kernel  = fonduta.signal.hrf(TR, hrfParams);
    full_conv   = conv(boxcar_one(:), hrf_kernel(:));
    step        = max(1, round(time_resampling / TR));
    node_frames = (0:N-1) * step + 1;   % 1-based frame indices
    node_frames = min(node_frames, numel(full_conv));
    ref         = full_conv(node_frames);
    ref         = ref(:);
    mx          = max(ref);
    if mx > 0; ref = ref / mx; end
end
