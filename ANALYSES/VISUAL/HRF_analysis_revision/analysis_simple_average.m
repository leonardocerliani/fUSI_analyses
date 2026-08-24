function analysis_simple_average(glm_results_path, opts)
% analysis_simple_average  Group event-related averaging using saved GLM results.

%
% Reuses per-session GLM result files (glm_*.mat, saved by
% analysis_visual_FONDUTA.m) to avoid re-fitting a GLM per subject.
% Masks, region labels, eta2 maps, and predictor boxcars all come directly
% from those files.  The only data still loaded per subject is the raw PDI
% time-series (needed for epoch extraction).
%
% USAGE:
%   analysis_simple_average(glm_results_path, opts)
%
%   glm_results_path  folder with glm_*.mat files
%   opts              struct with:
%       .model                e.g. 'M8_SteadyVisual', 'M1_StimOnly'
%       .eta2_thresh_val      (default 0.03)
%       .before_stim_onset    (default 5  s)
%       .after_stim_offset    (default 20 s)
%       .min_stationary_trials (default 3)
%       .min_active_voxels    (default 5)
%       .resultPath           output directory (default pwd)
%
% OUTPUT:
%   <resultPath>/simple_avg_<model_name>_<eta_str>.mat
%   e.g. simple_avg_M8_SteadyVisual_eta003.mat
%
% EXAMPLE:
%   opts.model = 'M8_SteadyVisual';
%   opts.eta2_thresh_val = 0.03;
%   opts.resultPath = '/path/to/results';
%
%   analysis_simple_average(glm_path, opts);
%
% To view available model names:
%   tmp_files = dir(fullfile(glm_path, 'glm_*.mat'));
%   tmp = load(fullfile(tmp_files(1).folder, tmp_files(1).name));
%   fieldnames(tmp.data.models)
%
% For interactive plotting of the results, use:
%   analysis_simple_average_view_results.m

%
% =========================================================================
% *** IMPORTANT — M8 time-axis gotcha ***
% =========================================================================
% analysis_visual_FONDUTA.m fits M8_SteadyVisual on a TEMPORALLY SUBSAMPLED
% dataset (running frames + ~16 s HRF tail removed before fitting):
%
%     stationaryFrames = ~runningFrameMask(:);
%     PDI_steady       = PDI.PDI(:, :, stationaryFrames);
%
% => glm.models.M8_SteadyVisual.Xmodel  length ~4571  (SUBSAMPLED axis)
%    glm.predictors.stim_stationary      length  6028  (FULL, matches PDI)
%
% Using Xmodel to find trial onsets would silently misalign every epoch.
% We ALWAYS use glm.predictors.stim_all / stim_stationary for onset detection.
%
% Model-dependent boxcar choice:
%   model_name contains 'Steady' -> use stim_stationary (stationary trials only)
%   any other model              -> use stim_all (all trials)
% =========================================================================

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
fprintf(' analysis_simple_average\n');

fprintf(' model  : %s\n', model_name);
fprintf(' eta2 >= : %.3f\n', eta2_thresh_val);
fprintf(' nSubs  : %d\n', nSubs);
fprintf('%s\n\n', repmat('=',1,60));

regional_avg   = struct();
TR_all         = nan(1, nSubs);
stim_dur_s_all = nan(1, nSubs);

is_steady_model = contains(model_name, 'Steady', 'IgnoreCase', true);

wb = waitbar(0, sprintf('Simple-avg: %s', model_name), 'Name', 'Group Simple Avg');

for isub = 1:nSubs

    fprintf('\n%s\n--- Sub %d / %d ---\n%s\n', ...
        repmat('-',1,40), isub, nSubs, repmat('-',1,40));
    waitbar(isub/nSubs, wb, sprintf('Subject %d / %d', isub, nSubs));

    try
        glm = load(fullfile(glm_files(isub).folder, glm_files(isub).name)).data;

        % --- from saved GLM result --- no recomputation needed ---
        bmask         = glm.bmask;
        allen_regions = glm.allen_regions;

        if ~isfield(glm.models, model_name)
            fprintf('  model "%s" not found in this file - skipping.\n', model_name);
            continue
        end

        model_result = glm.models.(model_name);

        % Auto-locate the visual-stimulus predictor by label
        pred_idx = find(contains(model_result.predictor_labels, 'stim'), 1);
        if isempty(pred_idx)
            fprintf('  no "stim" predictor in model "%s" - skipping.\n', model_name);
            continue
        end

        eta2      = squeeze(model_result.eta2(pred_idx, :, :));
        eta2_mask = (eta2 > eta2_thresh_val) & (bmask == 1);

        % Use FULL-LENGTH predictor vectors for onset detection (NOT Xmodel)
        if is_steady_model
            stim_box = glm.predictors.stim_stationary;
        else
            stim_box = glm.predictors.stim_all;
        end
        stim_box     = stim_box(:);
        onset_frames = find(diff([0; stim_box]) == 1);

        if numel(onset_frames) < min_stationary_trials
            fprintf('  only %d trial(s) - skipping.\n', numel(onset_frames));
            continue
        end

        % Active region selection
        active_region_ids = unique(allen_regions(eta2_mask));
        active_region_ids(active_region_ids <= 1) = [];

        valid = false(size(active_region_ids));
        for ri = 1:numel(active_region_ids)
            n_vox     = sum(allen_regions(:) == active_region_ids(ri) & eta2_mask(:));
            valid(ri) = n_vox >= min_active_voxels;
        end
        active_region_ids = active_region_ids(valid);

        if isempty(active_region_ids)
            fprintf('  no regions with >= %d active voxels - skipping.\n', min_active_voxels);
            continue
        end

        % --- load raw PDI (only data not stored in the GLM result) ---
        [PDI, ~, ~] = fonduta.io.datapath.load_session(glm.dataPath, glm.anatPath);

        TR = mean(diff(PDI.time));
        TR_all(isub) = TR;

        stim_dur_s = mean(PDI.stimInfo.endTime - PDI.stimInfo.startTime);
        stim_dur_s_all(isub) = stim_dur_s;
        fprintf('  stim_dur_s = %.2f s\n', stim_dur_s);

        T             = size(PDI.PDI, 3);
        stim_frames   = round(stim_dur_s / TR);
        before_frames = round(before_stim_onset / TR);
        after_frames  = round(after_stim_offset / TR);
        W             = before_frames + stim_frames + after_frames;

        nTrials = numel(onset_frames);
        nROI    = numel(active_region_ids);

        for r = 1:nROI
            roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;
            vox       = reshape(PDI.PDI, [], T);
            y_roi     = mean(vox(roi_supra(:), :), 1)';

            epoch_mat = [];

            for tr = 1:nTrials
                t_start = onset_frames(tr) - before_frames;
                t_end   = t_start + W - 1;

                if t_start < 1 || t_end > T; continue; end

                epoch    = y_roi(t_start : t_end);
                baseline = mean(epoch(1:before_frames));
                epoch    = epoch - baseline;

                epoch_mat = [epoch_mat, epoch(:)];   %#ok<AGROW>
            end

            if isempty(epoch_mat); continue; end

            tc_sub = mean(epoch_mat, 2);

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

        fprintf('  %d active regions\n', nROI);

    catch ME
        fprintf('  ERROR: %s\n', ME.message);
        fprintf('    In: %s  line %d\n', ME.stack(1).name, ME.stack(1).line);
    end
end

close(wb);

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

end   % end analysis_simple_average

