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

% Chaoyi 
chaoyi_hrfParams    = [2.4  8  0.8  0.9  6  0  16];

% Chen2023
chen2023_hrfParams = [4.95 8.69 1.1 1.1 1.8 0 32];

% Get the location of the data using Datapath
[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
% Modify the resultPath so that it points to the current directory (only for this example)
resultPath = pwd;

%% SIMPLE AVERAGE specific parameters

% We want to estimate the HRF only in regions where we expect to have an
% effect (there are 500+ regions...), therefore we first do a standard GLM
% with the hrf from Chen2023 and we retain regions with an eta2 > threshold
eta2_thresh_val = 0.03;

% How many time points to consider before stimulus onset and after stimulus
% offest
before_stim_onset = 5;
after_stim_offset = 15;

% Consider whole allen region (false) or only suprathreshold voxels (true)
% when averaging the signal within a given allen region
use_suprathreshold_voxels = true;

% Use sessions where there are at least this number of stationary trials
min_stationary_trials = 3;

% Minimum number of suprathreshold voxels for a region to be included
min_active_voxels = 5;


%% Part 1 — Group simple-average analysis (loop over subjects)

nSubs = numel(subDataPath);

% regional_avg: struct with one field per Allen region acronym.
% Each field has:
%   .tc   [W x nSubsInRegion]  — mean epoch time course per subject (baseline-corrected)
%   .acr  char
%   .name char
regional_avg = struct();

TR_all         = nan(1, nSubs);
stim_dur_s_all = nan(1, nSubs);

wb = waitbar(0, 'Running simple-average analysis...', 'Name', 'Group Simple Avg');

for isub = 1:nSubs

    fprintf('\n%s\n--- Sub %d / %d ---\n%s\n', repmat('-',1,40), isub, nSubs, repmat('-',1,40));
    waitbar(isub/nSubs, wb, sprintf('Subject %d / %d', isub, nSubs));

    try
        % --- Load session ---
        [PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
            subDataPath{isub}, subAnatPath{isub});

        TR = mean(diff(PDI.time));
        TR_all(isub) = TR;

        % --- Stimulus duration (verify ~15s) ---
        stim_dur_s      = mean(PDI.stimInfo.endTime - PDI.stimInfo.startTime);
        stim_dur_s_all(isub) = stim_dur_s;
        fprintf('  stim_dur_s = %.2f s\n', stim_dur_s);

        % --- Trial classification ---
        [stationaryTrialIdx, runningTrialIdx] = fn.detect_running_trials( ...
            PDI, speedThresh, minDuration);

        if numel(stationaryTrialIdx) < min_stationary_trials
            fprintf('Sub %d: only %d stationary trial(s) — skipping.\n', ...
                isub, numel(stationaryTrialIdx));
            continue
        end

        % --- Masks ---
        [bmask, ~, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

        % --- Predictors for standard GLM ---
        [stim_all, stim_stationary] = fn.build_visual_predictors( ...
            PDI, stationaryTrialIdx, runningTrialIdx);

        hrf_kernel = fonduta.signal.hrf(TR, chaoyi_hrfParams);
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

        % Keep only regions with >= min_active_voxels suprathreshold voxels
        active_region_ids = unique(allen_regions(eta2_mask));
        active_region_ids(active_region_ids <= 1) = [];

        % Filter by minimum voxel count
        valid = false(size(active_region_ids));
        for ri = 1:numel(active_region_ids)
            n_vox = sum(allen_regions(:) == active_region_ids(ri) & eta2_mask(:));
            valid(ri) = n_vox >= min_active_voxels;
        end
        active_region_ids = active_region_ids(valid);

        if isempty(active_region_ids)
            fprintf('Sub %d: no regions with >= %d active voxels — skipping.\n', ...
                isub, min_active_voxels);
            continue
        end

        % --- Window parameters (in frames) ---
        T              = size(PDI.PDI, 3);
        stim_frames    = round(stim_dur_s / TR);
        before_frames  = round(before_stim_onset / TR);
        after_frames   = round(after_stim_offset / TR);
        W              = before_frames + stim_frames + after_frames;   % total window length

        % Onset frame indices for stationary trials
        [~, onset_frames] = arrayfun(@(x) min(abs(x - PDI.time)), ...
                                     PDI.stimInfo.startTime(stationaryTrialIdx), ...
                                     'UniformOutput', true);
        nTrials = numel(stationaryTrialIdx);

        % --- Extract ROI signals and epoch ---
        nROI = numel(active_region_ids);

        for r = 1:nROI
            roi_all   = (allen_regions == active_region_ids(r)) & (bmask == 1);
            roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;

            sel_mask = roi_supra;   % use_suprathreshold_voxels = true

            vox   = reshape(PDI.PDI, [], T);   % [nVox x T]
            y_roi = mean(vox(sel_mask(:), :), 1)';   % [T x 1]

            % Accumulate valid trial epochs
            epoch_mat = [];   % will grow to [W x nValidTrials]

            for tr = 1:nTrials
                % Window is always exactly W frames, anchored to onset
                t_start = onset_frames(tr) - before_frames;
                t_end   = t_start + W - 1;

                % Skip trials where epoch extends outside recording
                if t_start < 1 || t_end > T
                    continue
                end

                epoch = y_roi(t_start : t_end);   % exactly W frames

                % Baseline-correct: subtract mean of pre-onset frames
                baseline = mean(epoch(1:before_frames));
                epoch    = epoch - baseline;

                epoch_mat = [epoch_mat, epoch(:)];   %#ok<AGROW>
            end

            if isempty(epoch_mat)
                continue
            end

            % Average across trials → single [W x 1] vector per subject
            tc_sub = mean(epoch_mat, 2);

            % Get region info
            rId = active_region_ids(r);
            if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
                acr  = atlas.infoRegions.acr{rId};
                name = atlas.infoRegions.name{rId};
            else
                acr  = sprintf('ID_%d', rId);
                name = acr;
            end
            field = matlab.lang.makeValidName(acr);

            if ~isfield(regional_avg, field)
                regional_avg.(field).tc   = tc_sub;
                regional_avg.(field).acr  = acr;
                regional_avg.(field).name = name;
            else
                regional_avg.(field).tc   = [regional_avg.(field).tc, tc_sub];
            end
        end

        fprintf('Sub %d: %d active regions\n', isub, nROI);

    catch ME
        fprintf('Sub %d: ERROR — %s\n', isub, ME.message);
        fprintf('  In: %s  line %d\n', ME.stack(1).name, ME.stack(1).line);
    end

end

close(wb);

TR_mean       = nanmean(TR_all);
stim_dur_s    = nanmean(stim_dur_s_all);
stim_frames   = round(stim_dur_s / TR_mean);
before_frames = round(before_stim_onset / TR_mean);
after_frames  = round(after_stim_offset / TR_mean);
W             = before_frames + stim_frames + after_frames;

% Time axis: seconds relative to stimulus onset
t_window = ((0:W-1) - before_frames) * TR_mean;

% --- Save ---
out_fname = fullfile(resultPath, 'analysis_simple_average.mat');
save(out_fname, 'regional_avg', 'atlas', ...
    'chaoyi_hrfParams', 'chen2023_hrfParams', ...
    'eta2_thresh_val', 'TR_mean', 'stim_dur_s', ...
    'before_stim_onset', 'after_stim_offset', ...
    'W', 't_window', '-v7.3');

fprintf('\nResults saved to: %s\n', out_fname);


%% Part 2 — Correlation table (a priori stimulus response vs subject averages)

mat_file         = 'analysis_simple_average_eta003.mat';
sim_thresh       = 0.6;
n_subject_thresh = 10;
smooth_win_s     = 5;    % moving average window in seconds (0 = no smoothing)
% -------------------------

S = load(mat_file);

smooth_win_frames = max(1, round(smooth_win_s / S.TR_mean));   % 5s → 25 frames at TR=200ms

% Build a priori boxcar template
stim_frames_ap   = round(S.stim_dur_s / S.TR_mean);
before_frames_ap = round(S.before_stim_onset / S.TR_mean);
after_frames_ap  = round(S.after_stim_offset / S.TR_mean);
W_ap             = before_frames_ap + stim_frames_ap + after_frames_ap;
boxcar_ap        = [zeros(before_frames_ap, 1); ones(stim_frames_ap, 1); zeros(after_frames_ap, 1)];

% Chaoyi a priori
hrf_ch = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);
ap_ch  = conv(boxcar_ap, hrf_ch);  ap_ch  = ap_ch(1:W_ap);  ap_ch  = ap_ch  / max(ap_ch);

% Chen2023 a priori
hrf_c23 = fonduta.signal.hrf(S.TR_mean, S.chen2023_hrfParams);
ap_c23  = conv(boxcar_ap, hrf_c23); ap_c23 = ap_c23(1:W_ap); ap_c23 = ap_c23 / max(ap_c23);

region_fields = fieldnames(S.regional_avg);
nRegions = numel(region_fields);

acr_list       = cell(nRegions, 1);
name_list      = cell(nRegions, 1);
nsub_list      = zeros(nRegions, 1);
mean_sim_ch    = zeros(nRegions, 1);   std_sim_ch    = zeros(nRegions, 1);
mean_sim_c23   = zeros(nRegions, 1);   std_sim_c23   = zeros(nRegions, 1);

for fi = 1:nRegions
    reg = S.regional_avg.(region_fields{fi});
    TC  = reg.tc;
    nS  = size(TC, 2);
    acr_list{fi}  = reg.acr;
    name_list{fi} = reg.name;
    nsub_list(fi) = nS;

    if nS < n_subject_thresh || size(TC, 1) ~= W_ap
        mean_sim_ch(fi)  = NaN;  std_sim_ch(fi)  = NaN;
        mean_sim_c23(fi) = NaN;  std_sim_c23(fi) = NaN;
        continue
    end

    % Apply moving-average smoothing column-by-column before computing correlation
    TC_sm = movmean(TC, smooth_win_frames, 1);

    sims_ch  = arrayfun(@(s) corr(TC_sm(:,s), ap_ch,  'rows', 'complete'), 1:nS);
    sims_c23 = arrayfun(@(s) corr(TC_sm(:,s), ap_c23, 'rows', 'complete'), 1:nS);
    mean_sim_ch(fi)  = mean(sims_ch);   std_sim_ch(fi)  = std(sims_ch);
    mean_sim_c23(fi) = mean(sims_c23);  std_sim_c23(fi) = std(sims_c23);
end

% Filter by n_subject_thresh and sort by Chaoyi similarity (descending)
keep = nsub_list >= n_subject_thresh & ~isnan(mean_sim_ch);
acr_list     = acr_list(keep);    name_list    = name_list(keep);
nsub_list    = nsub_list(keep);
mean_sim_ch  = mean_sim_ch(keep); std_sim_ch   = std_sim_ch(keep);
mean_sim_c23 = mean_sim_c23(keep);std_sim_c23  = std_sim_c23(keep);

[~, idx] = sort(mean_sim_ch, 'descend');
acr_s      = acr_list(idx);     name_s      = name_list(idx);
nsub_s     = nsub_list(idx);
mch_s      = mean_sim_ch(idx);  sch_s       = std_sim_ch(idx);
mc23_s     = mean_sim_c23(idx); sc23_s      = std_sim_c23(idx);
nR         = numel(idx);

fprintf('\nSimple average — HRF similarity — %d regions (n >= %d subs):\n\n', nR, n_subject_thresh);
fprintf('%-12s  %-40s  %5s  %-18s  %-18s\n', ...
    'Acronym', 'Full name', 'nSub', 'Chaoyi r±std', 'Chen2023 r±std');
fprintf('%s\n', repmat('-', 1, 100));
for fi = 1:nR
    marker = '';
    if mch_s(fi) >= sim_thresh; marker = '  ✓'; end
    fprintf('%-12s  %-40s  %5d  %.3f ± %.3f      %.3f ± %.3f%s\n', ...
        acr_s{fi}, name_s{fi}, nsub_s(fi), mch_s(fi), sch_s(fi), mc23_s(fi), sc23_s(fi), marker);
end
fprintf('\n%d / %d regions with Chaoyi mean r >= %.2f  (marked ✓)\n', ...
    sum(mch_s >= sim_thresh), nR, sim_thresh);


%% Part 3 — Single region plot

mat_file      = 'analysis_simple_average_eta003.mat';
target_acr    = 'LP';     % Allen acronym (choose from table above)
smooth_win_s  = 5;            % moving average window in seconds (0 = no smoothing)
% -------------------------

S = load(mat_file);

target_field = matlab.lang.makeValidName(target_acr);

if ~isfield(S.regional_avg, target_field)
    fprintf('Region "%s" not found.\n', target_acr);
    return
end

reg  = S.regional_avg.(target_field);
TC   = reg.tc;   % [W x nSubs]
nSub = size(TC, 2);

% Apply moving-average smoothing (same window as used in Part 2)
if smooth_win_s > 0
    smooth_win_frames = max(1, round(smooth_win_s / S.TR_mean));
    TC = movmean(TC, smooth_win_frames, 1);
end

mu  = mean(TC, 2);
se  = std(TC, 0, 2) / sqrt(nSub);

% Rebuild a priori
stim_frames_ap   = round(S.stim_dur_s / S.TR_mean);
before_frames_ap = round(S.before_stim_onset / S.TR_mean);
after_frames_ap  = round(S.after_stim_offset / S.TR_mean);
W_ap             = before_frames_ap + stim_frames_ap + after_frames_ap;

boxcar_ap = [zeros(before_frames_ap, 1); ones(stim_frames_ap, 1); zeros(after_frames_ap, 1)];

% Chaoyi a priori (black dashed)
hrf_ch    = fonduta.signal.hrf(S.TR_mean, S.chaoyi_hrfParams);
ap_ch     = conv(boxcar_ap, hrf_ch);
ap_ch     = ap_ch(1:W_ap) / max(ap_ch(1:W_ap)) * max(abs(mu));

% Chen2023 a priori (red dashed)
hrf_c23   = fonduta.signal.hrf(S.TR_mean, S.chen2023_hrfParams);
ap_c23    = conv(boxcar_ap, hrf_c23);
ap_c23    = ap_c23(1:W_ap) / max(ap_c23(1:W_ap)) * max(abs(mu));

% Stimulus-on shading
stim_on_s = [0, S.stim_dur_s];

figure('Name', sprintf('Simple avg HRF — %s', reg.acr), 'Position', [100 100 650 420]);
hold on;

% Shaded stimulus period
fill([stim_on_s(1) stim_on_s(2) stim_on_s(2) stim_on_s(1)], ...
     [min(mu-se)-0.1 min(mu-se)-0.1 max(mu+se)+0.1 max(mu+se)+0.1], ...
     [0.9 0.95 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.6);

% % Individual subject traces
% for s = 1:nSub
%     plot(S.t_window, TC(:,s), 'Color', [0.6 0.7 1.0 0.35], 'LineWidth', 0.8);
% end

% Mean ± SE band
fill([S.t_window, fliplr(S.t_window)], [mu+se; flipud(mu-se)]', ...
     [0.2 0.4 0.8], 'FaceAlpha', 0.25, 'EdgeColor', 'none');

% Mean
plot(S.t_window, mu,    'b-',  'LineWidth', 2.5);

% A priori: Chaoyi (black dashed) and Chen2023 (red dashed)
plot(S.t_window, ap_ch,  'k--', 'LineWidth', 2);
plot(S.t_window, ap_c23, 'r--', 'LineWidth', 2);

hold off;
xline(0,              ':k', 'onset',  'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
xline(S.stim_dur_s,   ':k', 'offset', 'LineWidth', 1, 'LabelVerticalAlignment', 'bottom');
yline(0, ':k', 'LineWidth', 0.8);

xlabel('Time relative to onset (s)');
ylabel('ΔF/F  (baseline-corrected)');
title(sprintf('%s — %s  (n=%d)', reg.acr, reg.name, nSub), ...
    'Interpreter', 'none', 'FontSize', 11);

% legend({'stim period', '', 'mean ± SE', 'Chaoyi HRF', 'Chen2023 HRF'}, 'Location', 'northeast');
legend({'stim period', '', 'mean ± SE', 'apriori HRF'}, 'Location', 'northeast');

box off;









