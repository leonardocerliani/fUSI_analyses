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
hrfParams    = [2.4  8  0.8  0.9  6  0  16];

% Chen2023
hrfParams = [4.95 8.69 1.1 1.1 1.8 0 32];

% Get the location of the data using Datapath
[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
% Modify the resultPath so that it points to the current directory (only for this example)
resultPath = pwd

% choose only one subject
isub = 33
disp('Loading data...')
[PDI, anatomic, Transf] = fonduta.io.datapath.load_session(...
    subDataPath{isub}, subAnatPath{isub});
disp('Done')


%% FIR specific parameters

% We want to estimate the HRF only in regions where we expect to have an
% effect (there are 500+ regions...), therefore we first do a standard GLM
% with the hrf from Chen2023 and we retain regions with an eta2 > threshold
eta2_thresh_val = 0.05;

% How many seconds to model after onset (10-20)
HRF_duration_s = 10;   

% Consider whole allen region (false) or only suprathreshold voxels (true)
% when averaging the signal within a given allen region
use_suprathreshold_voxels = true;

% Threshold of correlation with canonical HRF
% Set to 0 to show all active ROIs
sim_thresh = 0.5;




%% Define predictor with stationary trials

[stationaryTrialIdx, runningTrialIdx] = detect_running_trials(...
    PDI, speedThresh, minDuration);

% define the brain mask
[bmask, nonBrainMask, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);


% build the predictors
[stim_all, stim_stationary] = build_visual_predictors(...
    PDI, stationaryTrialIdx, runningTrialIdx);

% plot(PDI.time, stim_stationary)


%% Standard GLM with predefined HRF to filter task-related regions

TR         = mean(diff(PDI.time));
hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
hrf        = @(ev) filter(hrf_kernel, 1, ev(:));


[wheel, wheelSmooth, runningFrameMask] = fn.build_wheel_signal( ...
    PDI, speedThresh, hrf_kernel);

all_results = struct();


% --- M8: Stationary visual ---
%   GLM fitted only on stationary timepoints (runningFrameMask == false).
%   Subsetting both data and predictor excludes running-contaminated
%   frames from the fit, giving a clean estimate of visual response.
fprintf('  M8: Stationary visual\n');
stationaryFrames = ~runningFrameMask(:);
PDI_steady       = PDI.PDI(:, :, stationaryFrames);
M8_pred_steady   = hrf(stim_stationary(stationaryFrames));

all_results.M8_SteadyVisual = fonduta.glm.ols( ...
    'M8_SteadyVisual', PDI_steady, bmask, ...
    M8_pred_steady, {'stim_stationary_hrf'});

slice = anatomic.Data(:,:,anatomic.funcSlice(3));
eta2 = squeeze(all_results.M8_SteadyVisual.eta2);

% eta2_thresh_val = 0.05;  % now in the parameters above
eta2_thresh = eta2 .* (eta2 > eta2_thresh_val);

% View thresholded results
fonduta.viz.view_image(slice,eta2_thresh,3)


% Filter ROIs by eta2 threshold from standard GLM

% Which voxels pass the threshold (within brain mask)?
eta2_mask = (eta2 > eta2_thresh_val) & (bmask == 1);   % [nx x ny] logical

% Which Allen regions contain suprathreshold voxels?
active_region_ids = unique(allen_regions(eta2_mask));
active_region_ids(active_region_ids <= 1) = [];   % remove 0 (outside) and 1 (root)

%% FIR analysis on supra-threshold allen regions

% Find onset and offset frame indices
onsets  = find(diff([0; stim_stationary(:)]) ==  1);   % rising edges
offsets = find(diff([stim_stationary(:); 0]) == -1);   % falling edges

durations_in_frames = offsets - onsets + 1
durations_in_seconds = PDI.time(offsets) - PDI.time(onsets)


% Choose the number of lags K
T            = length(stim_stationary);   % number of timepoints
onset_delta  = zeros(T, 1);
onset_delta(onsets) = 1;

% HRF_duration_s = 10;   % seconds to model after onset - now in paramsabove
K              = round(HRF_duration_s / TR); % number of lags (e.g. ~50)
lag_times_s    = (0:K-1) * TR;               % time axis for plotting betas


% Build the FIR design matrix
% Create K lagged copies of `onset_delta`. Lag k shifts the delta k frames into the future:

X_fir = zeros(T, K);

for k = 0 : K-1
    shifted = circshift(onset_delta, k);
    shifted(1:k) = 0;          % zero-pad at the start (no circular wrap-around)
    X_fir(:, k+1) = shifted;
end

% Build the predictor labels
predictor_labels = {};
for k = 0 : K-1
    predictor_labels{k+1} = sprintf('lag_%02d', k);
end


% % Check alignment of allen_regions in individual space
% load(fullfile(subAnatPath{isub}, 'anatomic.mat'), 'anatomic')
% 
% fonduta.viz.view_image( ...
%     anatomic.Data(:,:,anatomic.funcSlice(3)), ...
%     allen_regions,3)
%
% masked_PDI = mode(PDI.PDI, 3);
% masked_PDI(bmask == 0) = NaN;   % NaN → transparent in imagesc/view_image
% 
% fonduta.viz.view_image( ...
%     masked_PDI, ...
%     double(allen_regions).*bmask,3)


%% Extract mean signal per active ROI
%
% Two averaging options (controlled by use_suprathreshold_voxels):
%
%   Option A (false) — average ALL voxels in the region within bmask.
%     Unbiased: the same voxels used to select the region are NOT re-used
%     to inflate the signal. Recommended for HRF estimation.
%
%   Option B (true) — average only suprathreshold voxels (eta2 > threshold).
%     Higher SNR but introduces selection bias: the voxels were chosen
%     because they already showed a strong response, so the estimated HRF
%     amplitude will be inflated.

% use_suprathreshold_voxels = true;   % now in params above

nROI     = numel(active_region_ids);
T_frames = size(PDI.PDI, 3);
Y_roi    = zeros(T_frames, nROI);

for r = 1:nROI
    roi_all   = (allen_regions == active_region_ids(r)) & (bmask == 1);
    roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;

    if use_suprathreshold_voxels && any(roi_supra(:))
        sel_mask = roi_supra;   % Option B
    else
        sel_mask = roi_all;     % Option A
    end

    vox         = reshape(PDI.PDI, [], T_frames);
    Y_roi(:, r) = mean(vox(sel_mask(:), :), 1)';
end

% Build region name labels (acronym from atlas)
region_names = cell(nROI, 1);
for r = 1:nROI
    rId = active_region_ids(r);
    if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
        region_names{r} = atlas.infoRegions.acr{rId};
    else
        region_names{r} = sprintf('ID_%d', rId);
    end
end

fprintf('Extracted signals from %d active ROIs\n', nROI);


%% Run the FIR GLM on ROI-averaged signals
glm_est = fonduta.glm.engine('M_FIR_stationary', Y_roi, X_fir, predictor_labels);
% glm_est.betas  [K+1 x nROI]  — rows 1..K = HRF lags; last row = intercept
% glm_est.tstat  [K x nROI]
% glm_est.R2     [1 x nROI]
disp('Done')


% Similarity between estimated HRF and a priori HRF kernel
hrf_betas = glm_est.betas(1:K, :);   % [K x nROI]

% Trim a priori kernel to K lags (zero-pad if kernel is shorter)
hrf_prior = hrf_kernel(1:min(K, numel(hrf_kernel)));
if numel(hrf_prior) < K
    hrf_prior(end+1:K) = 0;
end
hrf_prior = hrf_prior(:) / max(hrf_prior);   % [K x 1]  normalised to unit max

% Pearson correlation per ROI
hrf_similarity = zeros(1, nROI);
for r = 1:nROI
    hrf_similarity(r) = corr(hrf_betas(:, r), hrf_prior);
end


% Threshold: set to 0 to show all active ROIs
% sim_thresh = 0.5;  % now in params above

[sorted_sim, sort_idx] = sort(hrf_similarity, 'descend');
fprintf('\nHRF similarity (sorted):\n');
for i = 1:nROI
    r      = sort_idx(i);
    rId    = active_region_ids(r);
    acr    = region_names{r};
    name   = atlas.infoRegions.name{rId};
    marker = '';
    if hrf_similarity(r) >= sim_thresh; marker = '  ✓'; end
    fprintf('  %-12s  %-45s  r = %+.3f%s\n', acr, name, hrf_similarity(r), marker);
end

good_rois  = hrf_similarity >= sim_thresh;
fprintf('ROIs with HRF similarity >= %.2f : %d / %d\n', sim_thresh, sum(good_rois), nROI);


% Plot the estimated HRF per ROI (filtered by similarity)

% Scale a priori HRF to the amplitude range of the estimated betas for overlay
amp_scale  = max(abs(hrf_betas(:, good_rois)), [], 'all');
hrf_scaled = hrf_prior * amp_scale;

% All selected ROIs — one line per region, a priori HRF as thick dashed black
figure;
hold on;
plot(lag_times_s, hrf_betas(:, good_rois), 'LineWidth', 1);
plot(lag_times_s, hrf_scaled, 'k--', 'LineWidth', 2.5);
hold off;
xlabel('Time after onset (s)');
ylabel('Beta (z-score units)');
title(sprintf('FIR-estimated HRF — similarity \\geq %.2f  (%d / %d ROIs)', ...
    sim_thresh, sum(good_rois), nROI));
legend([region_names(good_rois); {'a priori HRF'}], ...
    'Interpreter', 'none', 'Location', 'eastoutside');
xline(0, '--k');  yline(0, ':k');


%% Single ROI (e.g. Anteromedial visual area)
target_acr = 'VISam';
rIdx = find(strcmp(region_names, target_acr));
if ~isempty(rIdx)
    figure;
    plot(lag_times_s, glm_est.betas(1:K, rIdx), 'b-o', 'LineWidth', 2);
    xlabel('Time after onset (s)');
    ylabel('Beta (z-score units)');
    title(sprintf('Estimated HRF — %s', target_acr));
    xline(0, '--k');  yline(0, ':k');
end



% %% Compute per-ROI HRF stats and paint onto brain map
% 
% hrf_betas = glm_est.betas(1:K, :);   % [K x nROI]
% 
% % --- Peak amplitude ---
% peak_amp = max(hrf_betas, [], 1);     % [1 x nROI]
% 
% % --- FWHM (in seconds) ---
% fwhm_s = zeros(1, nROI);
% for r = 1:nROI
%     h      = hrf_betas(:, r);
%     hmax   = max(h);
%     if hmax <= 0; continue; end        % no positive response — skip
%     half   = hmax / 2;
%     above  = h >= half;
%     % find first and last frame above half-max
%     idx    = find(above);
%     if numel(idx) < 2; continue; end
%     fwhm_s(r) = (idx(end) - idx(1)) * TR;
% end
% 
% % --- Paint ROI values onto [nx x ny] maps ---
% map_peak_amp = zeros(size(allen_regions));
% map_fwhm     = zeros(size(allen_regions));
% 
% for r = 1:nROI
%     roi_mask = (allen_regions == active_region_ids(r)) & (bmask == 1);
%     map_peak_amp(roi_mask) = peak_amp(r);
%     map_fwhm(roi_mask)     = fwhm_s(r);
% end
% 
% % Set non-brain to NaN for clean display
% map_peak_amp(bmask == 0) = NaN;
% map_fwhm(bmask == 0)     = NaN;
% 
% % --- Visualize ---
% slice = anatomic.Data(:,:,anatomic.funcSlice(3));
% 
% fonduta.viz.view_image(slice, map_peak_amp, 3)
% title('Peak amplitude (β_max)')
% 
% fonduta.viz.view_image(slice, map_fwhm, 3)
% title('FWHM (s)')
% 
% fonduta.viz.view_image(slice,eta2_thresh,3)
% title('GLM')
