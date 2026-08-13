% analysis_simple_average_view_results_NEW.m
%
% Interactive script for viewing results produced by analysis_simple_average_NEW.m.
% Open this file in the MATLAB editor and run each %% cell separately.
%
% Part 2 — prints the HRF similarity table (sorted by Chaoyi r, filtered)
% Part 3 — plots the mean +/- SE epoch for a single region of interest
%
% The results .mat files live in:
%   results_simple_average/simple_avg_<model_name>_<eta_str>.mat
%
% To view available model names from a GLM file, run:
%   glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
%   tmp_files = dir(fullfile(glm_results_path, 'glm_*.mat'));
%   tmp = load(fullfile(tmp_files(1).folder, tmp_files(1).name));
%   fieldnames(tmp.data.models)


%% Setup (run this cell first)

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
addpath(genpath('.'));


%% Part 2 — Similarity table

% --- parameters ---
mat_file         = fullfile(pwd, 'results_simple_average', 'simple_avg_M8_SteadyVisual_eta003.mat');
% mat_file         = fullfile(pwd, 'results_simple_average', 'simple_avg_M1_StimOnly_eta003.mat');

sim_thresh       = 0.7;   % only show regions with Chaoyi r >= this
n_subject_thresh = 10;     % only show regions present in >= this many subjects
smooth_win_s     = 5;     % moving-average smoothing window in seconds (0 = off)
% ------------------

S = load(mat_file);

smooth_win_frames = max(1, round(smooth_win_s / S.TR_mean));

stim_frames_ap   = round(S.stim_dur_s / S.TR_mean);
before_frames_ap = round(S.before_stim_onset / S.TR_mean);
after_frames_ap  = round(S.after_stim_offset / S.TR_mean);
W_ap             = before_frames_ap + stim_frames_ap + after_frames_ap;
boxcar_ap        = [zeros(before_frames_ap,1); ones(stim_frames_ap,1); zeros(after_frames_ap,1)];

hrf_ch  = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);
ap_ch   = conv(boxcar_ap, hrf_ch);  ap_ch  = ap_ch(1:W_ap);  ap_ch  = ap_ch / max(ap_ch);

hrf_c23 = fonduta.signal.hrf(S.TR_mean, S.chen2023_hrfParams);
ap_c23  = conv(boxcar_ap, hrf_c23); ap_c23 = ap_c23(1:W_ap); ap_c23 = ap_c23 / max(ap_c23);

region_fields = fieldnames(S.regional_avg);
nRegions      = numel(region_fields);
acr_list      = cell(nRegions,1);
name_list     = cell(nRegions,1);
nsub_list     = zeros(nRegions,1);
mean_sim_ch   = zeros(nRegions,1);  std_sim_ch  = zeros(nRegions,1);
mean_sim_c23  = zeros(nRegions,1);  std_sim_c23 = zeros(nRegions,1);

for fi = 1:nRegions
    reg = S.regional_avg.(region_fields{fi});
    TC  = reg.tc;
    nS  = size(TC, 2);
    acr_list{fi}  = reg.acr;
    name_list{fi} = reg.name;
    nsub_list(fi) = nS;

    if nS < n_subject_thresh || size(TC,1) ~= W_ap
        mean_sim_ch(fi)  = NaN;  std_sim_ch(fi)  = NaN;
        mean_sim_c23(fi) = NaN;  std_sim_c23(fi) = NaN;
        continue
    end

    TC_sm    = movmean(TC, smooth_win_frames, 1);
    sims_ch  = arrayfun(@(s) corr(TC_sm(:,s), ap_ch,  'rows','complete'), 1:nS);
    sims_c23 = arrayfun(@(s) corr(TC_sm(:,s), ap_c23, 'rows','complete'), 1:nS);
    mean_sim_ch(fi)  = mean(sims_ch);   std_sim_ch(fi)  = std(sims_ch);
    mean_sim_c23(fi) = mean(sims_c23);  std_sim_c23(fi) = std(sims_c23);
end

keep = nsub_list >= n_subject_thresh & ~isnan(mean_sim_ch);
acr_list     = acr_list(keep);     name_list    = name_list(keep);
nsub_list    = nsub_list(keep);
mean_sim_ch  = mean_sim_ch(keep);  std_sim_ch   = std_sim_ch(keep);
mean_sim_c23 = mean_sim_c23(keep); std_sim_c23  = std_sim_c23(keep);

[~, idx] = sort(mean_sim_ch, 'descend');
acr_s  = acr_list(idx);    name_s  = name_list(idx);
nsub_s = nsub_list(idx);
mch_s  = mean_sim_ch(idx); sch_s   = std_sim_ch(idx);
mc23_s = mean_sim_c23(idx); sc23_s = std_sim_c23(idx);

above  = mch_s >= sim_thresh;
acr_s  = acr_s(above);  name_s  = name_s(above);  nsub_s  = nsub_s(above);
mch_s  = mch_s(above);  sch_s   = sch_s(above);
mc23_s = mc23_s(above); sc23_s  = sc23_s(above);
nR     = sum(above);

clc
fprintf('\n[%s]  Simple avg -- HRF similarity -- %d regions (n >= %d subs):\n\n', ...
    S.model_name, nR, n_subject_thresh);
fprintf('%-12s  %-40s  %5s  %-18s  %-18s\n', ...
    'Acronym', 'Full name', 'nSub', 'Chaoyi r+/-std', 'Chen2023 r+/-std');
fprintf('%s\n', repmat('-',1,100));
for fi = 1:nR
    marker = '';
    if mch_s(fi) >= sim_thresh; marker = '  v'; end
    fprintf('%-12s  %-40s  %5d  %.3f +/- %.3f      %.3f +/- %.3f%s\n', ...
        acr_s{fi}, name_s{fi}, nsub_s(fi), mch_s(fi), sch_s(fi), mc23_s(fi), sc23_s(fi), marker);
end
fprintf('\n%d / %d regions with Chaoyi mean r >= %.2f  (marked v)\n', ...
    sum(mch_s >= sim_thresh), nR, sim_thresh);


%% Part 3 — Single region plot

% --- parameters ---
mat_file         = fullfile(pwd, 'results_simple_average', 'simple_avg_M8_SteadyVisual_eta003.mat');
% mat_file         = fullfile(pwd, 'results_simple_average', 'simple_avg_M1_StimOnly_eta003.mat');

target_acr   = 'RSPv';    % Allen acronym — pick from Part 2 table
smooth_win_s = 5;         % seconds (0 = off)
% ------------------

S = load(mat_file);

target_field = matlab.lang.makeValidName(target_acr);

if ~isfield(S.regional_avg, target_field)
    fprintf('Region "%s" not found in:\n  %s\n', target_acr, mat_file);
    return
end

reg  = S.regional_avg.(target_field);
TC   = reg.tc;
nSub = size(TC, 2);

if smooth_win_s > 0
    smooth_win_frames = max(1, round(smooth_win_s / S.TR_mean));
    TC = movmean(TC, smooth_win_frames, 1);
end

mu = mean(TC, 2);
se = std(TC, 0, 2) / sqrt(nSub);

stim_frames_ap   = round(S.stim_dur_s / S.TR_mean);
before_frames_ap = round(S.before_stim_onset / S.TR_mean);
W_ap             = before_frames_ap + stim_frames_ap + round(S.after_stim_offset / S.TR_mean);
boxcar_ap        = [zeros(before_frames_ap,1); ones(stim_frames_ap,1); ...
                    zeros(round(S.after_stim_offset / S.TR_mean),1)];

hrf_ch  = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);
ap_ch   = conv(boxcar_ap, hrf_ch);
ap_ch   = ap_ch(1:W_ap) / max(ap_ch(1:W_ap)) * max(abs(mu));

hrf_c23 = fonduta.signal.hrf(S.TR_mean, S.chen2023_hrfParams);
ap_c23  = conv(boxcar_ap, hrf_c23);
ap_c23  = ap_c23(1:W_ap) / max(ap_c23(1:W_ap)) * max(abs(mu));

stim_on_s = [0, S.stim_dur_s];
y_lo = min(mu-se) - 0.1;
y_hi = max(mu+se) + 0.1;

figure('Name', sprintf('[%s]  %s', S.model_name, reg.acr), 'Position', [100 100 650 420]);
hold on;

fill([stim_on_s(1) stim_on_s(2) stim_on_s(2) stim_on_s(1)], ...
     [y_lo y_lo y_hi y_hi], [0.9 0.95 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.6);

fill([S.t_window, fliplr(S.t_window)], [mu+se; flipud(mu-se)]', ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.25, 'EdgeColor', 'none');

plot(S.t_window, mu,    'b-',  'LineWidth', 2.5);
plot(S.t_window, ap_ch, 'k--', 'LineWidth', 2);
% plot(S.t_window, ap_c23, 'r--', 'LineWidth', 2);

hold off;
xline(0,            ':k', 'onset',  'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
xline(S.stim_dur_s, ':k', 'offset', 'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
yline(0, ':k', 'LineWidth', 0.8);

xlabel('Time relative to onset (s)');
ylabel('\DeltaF/F  (baseline-corrected)');
title(sprintf('[%s]  %s -- %s  (n=%d)', S.model_name, reg.acr, reg.name, nSub), ...
    'Interpreter', 'none', 'FontSize', 11);
legend({'stim period', '', 'mean \pm SE', 'Chaoyi HRF'}, ...
    'Location', 'northeast', 'Interpreter', 'tex');
box off;
