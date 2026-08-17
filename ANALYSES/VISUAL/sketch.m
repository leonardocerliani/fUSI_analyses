%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

%% View the results of a glm

results_dir='/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest/';
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136.mat'));
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136_FIR.mat'));


list = dir('/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest/')

for i = 3:numel(list)
    name = list(i).name;
    fonduta.viz.view_glm(fullfile(results_dir, name));
    pause;  % wait for user input before continuing
end


%% FIR EXAMPLE


%% Step 0 — Setup and load one session
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
resultPath = pwd;

isub = 33;

[PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
    subDataPath{isub}, subAnatPath{isub});

% Brain mask and Allen atlas region map (same space as PDI.PDI)
[bmask, nonBrainMask, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

% Frame acquisition time
TR = mean(diff(PDI.time));

% Auto-detect stimulus duration from this session's stimInfo
stim_durations = PDI.stimInfo.endTime - PDI.stimInfo.startTime;
stim_duration  = mean(stim_durations);
fprintf('TR = %.3f s  |  stim_duration = %.2f s  |  nTrials = %d\n', ...
    TR, stim_duration, numel(stim_durations));

% Build a binary stimulus boxcar for all trials
%   stim_all(t) = 1 whenever the stimulus is on, 0 otherwise
T_frames = numel(PDI.time);
stim_all = zeros(T_frames, 1);
for tr = 1:numel(PDI.stimInfo.startTime)
    on_idx  = find(PDI.time >= PDI.stimInfo.startTime(tr), 1, 'first');
    off_idx = find(PDI.time <= PDI.stimInfo.endTime(tr),   1, 'last');
    if ~isempty(on_idx) && ~isempty(off_idx)
        stim_all(on_idx:off_idx) = 1;
    end
end
fprintf('stim_all: %.1f%% frames active\n', 100*mean(stim_all));

%% Step 1 — FIR window parameters
time_window_after_offset = 12;     % seconds to model after stimulus offset
time_resampling          = 2;    % node spacing in seconds
basis_type               = 'tent'; % 'tent' (recommended) or 'boxcar'

W = stim_duration + time_window_after_offset;
N = round(W / time_resampling);
fprintf('FIR window: %.1f s  |  N = %d nodes  |  basis: %s\n', W, N, basis_type);


%% Step 2 — Wheel signal and continuous predictor preparation

% HRF kernel (used internally by build_wheel_signal to build the running mask)
speedThresh = 35;   % wheel speed threshold (counts/s) for running classification
hrfParams   = [2.4  8  0.8  0.9  6  0  16];
hrf_kernel  = fonduta.signal.hrf(TR, hrfParams);

% Resample wheel speed to fUSI frame timestamps
[wheel, wheelSmooth, runningFrameMask] = fn.build_wheel_signal( ...
    PDI, speedThresh, hrf_kernel);
% wheel            [T × 1]  absolute speed in counts/s at each fUSI frame
% wheelSmooth      [T × 1]  Gaussian-smoothed speed
% runningFrameMask [T × 1]  logical; true at frames contaminated by running

% Centre wheel speed before FIR expansion (preserves 0 baseline during silence)
wheel_c = wheel - mean(wheel);

% Interaction: compute on pre-centred wheel speed, BEFORE FIR expansion
interaction = stim_all .* wheel_c;

fprintf('wheel_c: mean = %.4f (should be ~0)\n', mean(wheel_c));


%% Step 3 — FIR operator and design matrix blocks

fir = @(ev) fn.generate_fir_basis( ...
    ev, TR, stim_duration, time_window_after_offset, ...
    time_resampling, basis_type);

B_stim  = fir(stim_all);     % [T × N]  from binary stimulus boxcar
B_wheel = fir(wheel_c);      % [T × N]  from centred wheel speed
B_inter = fir(interaction);  % [T × N]  from pre-computed interaction

fprintf('FIR blocks: B_stim [%d×%d]  B_wheel [%d×%d]  B_inter [%d×%d]\n', ...
    size(B_stim,1), size(B_stim,2), ...
    size(B_wheel,1), size(B_wheel,2), ...
    size(B_inter,1), size(B_inter,2));


%% Step 4 — Assemble F2_Behavior design matrix

% Full design: [B_stim | wheel_c | B_wheel | B_inter]
%   Column ranges (1-indexed, intercept is added automatically by the GLM engine):
%     stim FIR  : 1 .. N
%     wheel raw : N+1   (a single column — instantaneous speed)
%     wheel FIR : N+2 .. 2N+1
%     inter FIR : 2N+2 .. 3N+1
X_F2 = [B_stim, wheel_c, B_wheel, B_inter];   % [T × (3N+1)]

% Predictor labels (one per column of X_F2, NOT including intercept)
labels_stim  = arrayfun(@(k) sprintf('stim_fir_%02d',  k), 1:N, 'UniformOutput', false);
labels_wheel = arrayfun(@(k) sprintf('wheel_fir_%02d', k), 1:N, 'UniformOutput', false);
labels_inter = arrayfun(@(k) sprintf('inter_fir_%02d', k), 1:N, 'UniformOutput', false);
labels_F2    = [labels_stim, {'wheel_raw'}, labels_wheel, labels_inter];

fprintf('X_F2: [%d × %d]   labels: %d\n', size(X_F2,1), size(X_F2,2), numel(labels_F2));



%% Step 5 — F-contrast matrices for F2_Behavior

% Xfull = [X_F2 (3N+1 cols) | intercept (1 col)]  →  p+1 = 3N+2 columns total
p_F2           = 3*N + 1;
ncols_Xfull_F2 = p_F2 + 1;   % = 3N+2

% Contrast for stim FIR block (columns 1..N of Xfull)
C_F2_stim = zeros(N, ncols_Xfull_F2);
C_F2_stim(:, 1:N) = eye(N);

% Contrast for wheel FIR block (columns N+2..2N+1 of Xfull)
C_F2_wheel = zeros(N, ncols_Xfull_F2);
C_F2_wheel(:, (N+2):(2*N+1)) = eye(N);

% Contrast for interaction FIR block (columns 2N+2..3N+1 of Xfull)
C_F2_inter = zeros(N, ncols_Xfull_F2);
C_F2_inter(:, (2*N+2):(3*N+1)) = eye(N);

% Pack into struct array
contrast_F2(1).name = 'Visual_FIR';      contrast_F2(1).C = C_F2_stim;
contrast_F2(2).name = 'Wheel_FIR';       contrast_F2(2).C = C_F2_wheel;
contrast_F2(3).name = 'Interaction_FIR'; contrast_F2(3).C = C_F2_inter;

fprintf('Contrasts: %d defined  |  C size: [%d × %d]\n', ...
    numel(contrast_F2), size(C_F2_stim,1), size(C_F2_stim,2));


%% Step 6 — Fit F2_Behavior FIR GLM
%
%   fonduta.glm.ols(model_name, PDI3D, bmask, X, labels, contrasts, skip_zscore)
%   skip_zscore = true   ← required for FIR (do NOT z-score the FIR columns)

tic
result_F2 = fonduta.glm.ols( ...
    'F2_Behavior', PDI.PDI, bmask, ...
    X_F2, labels_F2, contrast_F2, true);

toc

disp('F2_Behavior fitted. Fields:')
disp(fieldnames(result_F2))
% result_F2.betas    [(3N+2) × nx × ny]  — last row = intercept
% result_F2.eta2     [(3N+1) × nx × ny]  — per-node partial η² for each column
% result_F2.tstat    [(3N+1) × nx × ny]
% result_F2.zstat    [(3N+1) × nx × ny]
% result_F2.R2       [nx × ny]
% result_F2.fcontrasts.Visual_FIR       — omnibus F-test for stim block
% result_F2.fcontrasts.Wheel_FIR        — omnibus F-test for wheel block
% result_F2.fcontrasts.Interaction_FIR  — omnibus F-test for interaction block

%% Step 7 — Assemble result struct and save

% Build the glmresult struct (same format as the batch script output)
glmresult               = struct();
glmresult.dataPath      = subDataPath{isub};
glmresult.anatPath      = subAnatPath{isub};
glmresult.Transf        = Transf;
glmresult.bmask         = bmask;
glmresult.nonBrainMask  = nonBrainMask;
glmresult.allen_regions = allen_regions;

glmresult.predictors.stim_all   = stim_all;
glmresult.predictors.wheel      = wheel;
glmresult.predictors.wheel_centered = wheel_c;
glmresult.predictors.interaction    = interaction;

glmresult.fir_params.stim_duration            = stim_duration;
glmresult.fir_params.time_window_after_offset = time_window_after_offset;
glmresult.fir_params.time_resampling          = time_resampling;
glmresult.fir_params.basis_type               = basis_type;
glmresult.fir_params.N_nodes                  = N;
glmresult.fir_params.TR                       = TR;

glmresult.models.F2_Behavior = result_F2;

% Save — variable must be named 'data' for view_glm compatibility
outDir   = fullfile(resultPath, 'VisualTest');
if ~exist(outDir, 'dir'); mkdir(outDir); end

parts   = strsplit(subDataPath{isub}, '/');
parts   = parts(~cellfun(@isempty, parts));
runName = parts{end};

saveName = fullfile(outDir, sprintf('glm_%s_FIR_tutorial.mat', runName));
data = glmresult;
save(saveName, 'data');
fprintf('Saved: %s\n', saveName);

% Open in view_glm
fonduta.viz.view_glm(saveName);


%% Plot FIR-estimated HRF for primary visual cortex (VISp, Allen ID 669)

results = load('VisualTest/glm_run-142136_FIR_tutorial.mat').data

atlas = fonduta.atlas.load_atlas();

allen_ROI = 'RSPv'

N = results.fir_params.N_nodes;
time_resampling = results.fir_params.time_resampling;
stim_duration   = results.fir_params.stim_duration;
lag_times = (0 : N-1) * time_resampling;


% Extract stim FIR betas (rows 1..N of the full beta matrix)
betas_3d = results.models.F2_Behavior.betas;         % [(3N+2) × nx × ny]
betas_stim_2d = reshape(betas_3d(1:N,:,:), N, []);   % [N × nx*ny]

% Average across allen_ROI voxels within brain mask
idx_allen_region = find(strcmp(atlas.infoRegions.acr, allen_ROI))
roi_mask = (results.allen_regions == idx_allen_region) & results.bmask;
hrf_est  = mean(betas_stim_2d(:, roi_mask(:)), 2);   % [N × 1]

figure;
plot(lag_times, hrf_est, 'b-o', 'LineWidth', 2, 'MarkerSize', 4);
xline(stim_duration, '--r', 'Stim offset', 'LabelVerticalAlignment', 'bottom');
xline(0, ':k');
yline(0, ':k');
xlabel('Lag after stimulus onset (s)');
ylabel('Beta (stimulus-relative units)');
title(strcat('FIR-estimated HRF — ',allen_ROI));







