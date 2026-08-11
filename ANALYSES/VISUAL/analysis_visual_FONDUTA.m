%% analysis_visual_FONDUTA.m — Visual GLM Analysis Orchestrator (FONDUTA version)
%
% Main script for the visual stimulation GLM analysis.
% Uses the FONDUTA package for all generic operations.
%
% USAGE:
%   1. Set FONDUTA_PATH below to the location of your FONDUTA directory.
%   2. Run from within ANALYSES/VISUAL/ so that Datapath.m and the local
%      +fn/ package are visible.  FONDUTA can be anywhere on disk.
%
% Fits 11 GLM models per session.  Each model is fully specified here with
% explicit predictor construction:
%
%   hrf(EV)  convolves EV with the canonical hemodynamic response function.
%            TR is captured automatically from the current session.
%
%   Model overview:
%     M1  : hrf(stim_all)                           — stimulus only
%     M2  : hrf(stim_all)  on hard PC1-removed data — hard global PC1 control
%     M3  : hrf(stim_all) + globalPC1               — soft global PC1 nuisance
%     M4  : hrf(stim_all) + nonBrainPC1             — soft non-brain PC1 nuisance
%     M5  : hrf(stim_all) + wheel + hrf(wheel) + hrf(stim_all.*wheel)
%     M6a : M5 + globalPC1
%     M6b : M5 + nonBrainPC1
%     M6c : M5 + globalPC1 + nonBrainPC1
%     M7a : wheelSmooth + (M5 nuisance)             — unique smooth running effect
%     M7b : hrf(wheel) + (M5 nuisance)              — unique conv running effect
%     M8  : hrf(stim_stationary) on stationary timepoints + correlation maps
%
% Each model result is stored as glmresult.models.<ModelName> with fields:
%     .betas            [p+1 x nx x ny]  rows 1..p = predictors; last = intercept
%     .eta2             [p   x nx x ny]  partial eta² per predictor
%     .R2               [nx  x ny]       global model R²
%     .Xmodel           [T x p]          z-scored design matrix (no intercept)
%     .predictor_labels                  cell array matching rows of betas / eta2
%     .model_name                        string identifier
%
% Raw predictor time-series are stored in glmresult.predictors (stim_all,
% stim_stationary, wheel, globalPC1, etc.) — separate from per-model Xmodel.
%
% Results are saved per session as glm_<runName>.mat, where runName is the
% last path component of the session data directory (e.g. "run-142136").
% Each file contains variable 'data' (= glmresult struct).
%
% Dependencies:
%   FONDUTA package  (set FONDUTA_PATH below)
%   Datapath.m       (in this directory — provides session paths)
%   +fn/             (in this directory):
%       fn.detect_running_trials
%       fn.build_visual_predictors
%       fn.build_wheel_signal

%% =========================================================================
%  CONFIGURATION — edit these parameters before running
%  =========================================================================

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

condition    = 'VisualTest';   % experiment condition (passed to Datapath)
resultFolder = 'LC';           % output subfolder name

speedThresh  = 35;     % wheel speed threshold (counts/s) for running classification
minDuration  = 0.2;    % min running bout duration (s) to classify a trial as running

% SPM-style double-gamma HRF parameters:
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]
hrfParams    = [2.4  8  0.8  0.9  6  0  16];


%% =========================================================================
%  LOAD DATASET PATHS  (via the local Datapath.m)
%  =========================================================================

[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.Datapath('VisualTest');

fprintf('\n=================================================\n');
fprintf(' analysis_visual_FONDUTA.m  |  condition: %s\n', condition);
fprintf(' Sessions found: %d\n\n', numel(subDataPath));
fprintf(' Results will be saved in:\n\n %s\n', fullfile(resultPath, resultFolder));
fprintf('=================================================\n\n');

%% =========================================================================
%  MAIN SESSION LOOP
%  =========================================================================

warning('off', 'all');
sesIncl = [];

% Load the atlas (always useful)
atlas = fonduta.atlas.load_atlas();

for isub = 1:numel(subDataPath)

    fprintf('\n--- Session %d / %d ---\n', isub, numel(subDataPath));

    try

        % -----------------------------------------------------------------
        % 1. Load data
        % -----------------------------------------------------------------
        [PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
            subDataPath{isub}, subAnatPath{isub});

        % -----------------------------------------------------------------
        % 2. Running trial detection & session inclusion check
        %    A session is usable only when it has both stationary AND running
        %    trials — otherwise there is either no reference (stationary)
        %    or experimental condition (running).
        % -----------------------------------------------------------------
        [stationaryTrialIdx, runningTrialIdx] = fn.detect_running_trials( ...
            PDI, speedThresh, minDuration);

        if isempty(stationaryTrialIdx) || isempty(runningTrialIdx)
            continue
        end

        sesIncl = [sesIncl, isub]; %#ok<AGROW>

        % -----------------------------------------------------------------
        % 3. Brain masks
        % -----------------------------------------------------------------
        [bmask, nonBrainMask, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

        % -----------------------------------------------------------------
        % 4. HRF convolution operator
        %    hrf(EV) convolves any signal EV with the canonical HRF.
        %    TR is derived from the current session's frame timestamps.
        % -----------------------------------------------------------------
        TR         = mean(diff(PDI.time));
        hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
        hrf        = @(ev) filter(hrf_kernel, 1, ev(:));

        % -----------------------------------------------------------------
        % 5. Build predictor signals
        %    HRF convolution is applied explicitly in each model block below
        %    using hrf(signal), making the model specification self-documenting.
        %
        %    Visual EVs:
        %      stim_all        — boxcar for all visual trials (running + stationary)
        %      stim_stationary — boxcar for stationary trials only
        %
        %    Wheel EVs:
        %      wheel           — absolute wheel speed at scan frames
        %      wheelSmooth     — Gaussian-smoothed wheel speed
        %      runningFrameMask — logical mask; true at frames contaminated by
        %                        running (including HRF tail ~16 s post-bout).
        %                        Used to select stationary timepoints for M8.
        % -----------------------------------------------------------------
        [stim_all, stim_stationary] = fn.build_visual_predictors( ...
            PDI, stationaryTrialIdx, runningTrialIdx);

        [wheel, wheelSmooth, runningFrameMask] = fn.build_wheel_signal( ...
            PDI, speedThresh, hrf_kernel);

        pc1Signals = fonduta.utils.extract_pc1_signals(PDI, bmask, nonBrainMask);

        globalPC1   = pc1Signals.globalPC1;
        nonBrainPC1 = pc1Signals.nonBrainPC1;

        % -----------------------------------------------------------------
        % 6. Fit GLM models
        %    fonduta.glm.ols(name, PDI3D, bmask, X, labels)
        %       → accepts 3D PDI data and returns spatially remapped results
        %       → output .eta2 [p x nx x ny], .betas [p+1 x nx x ny], .R2 [nx x ny]
        %    For M8 and correlation maps, prepare_data_matrix is called explicitly.
        % -----------------------------------------------------------------

        all_results = struct();

        %% --- M1: Stimulus only (all trials) ---
        fprintf('  M1: Stimulus only\n');
        all_results.M1_StimOnly = fonduta.glm.ols( ...
            'M1_StimOnly', PDI.PDI, bmask, ...
            hrf(stim_all), {'stim_hrf'});

        %% --- M2: Stimulus only on hard global-PC1-removed data ---
        fprintf('  M2: Hard global PC1\n');
        all_results.M2_HardGlobalPC1 = fonduta.glm.ols( ...
            'M2_HardGlobalPC1', pc1Signals.YhardGlobalPC1, bmask, ...
            hrf(stim_all), {'stim_hrf'});

        %% --- M3: Stimulus + soft global PC1 nuisance ---
        fprintf('  M3: Soft global PC1\n');
        all_results.M3_SoftGlobalPC1 = fonduta.glm.ols( ...
            'M3_SoftGlobalPC1', PDI.PDI, bmask, ...
            [hrf(stim_all), globalPC1], {'stim_hrf', 'globalPC1'});

        %% --- M4: Stimulus + soft non-brain PC1 nuisance ---
        fprintf('  M4: Soft non-brain PC1\n');
        all_results.M4_SoftNonBrainPC1 = fonduta.glm.ols( ...
            'M4_SoftNonBrainPC1', PDI.PDI, bmask, ...
            [hrf(stim_all), nonBrainPC1], {'stim_hrf', 'nonBrainPC1'});

        %% --- M5: Stimulus + running speed regressors (behavior model) ---
        fprintf('  M5: Behavior\n');
        all_results.M5_Behavior = fonduta.glm.ols( ...
            'M5_Behavior', PDI.PDI, bmask, ...
            [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all .* wheel)], ...
            {'stim_hrf', 'wheel', 'wheel_hrf', 'interaction_hrf'});

        %% --- M6a: M5 + soft global PC1 ---
        fprintf('  M6a: Behavior + soft global PC1\n');
        all_results.M6a_BehSoftGlobalPC1 = fonduta.glm.ols( ...
            'M6a_BehSoftGlobalPC1', PDI.PDI, bmask, ...
            [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all .* wheel), globalPC1], ...
            {'stim_hrf', 'wheel', 'wheel_hrf', 'interaction_hrf', 'globalPC1'});

        %% --- M6b: M5 + soft non-brain PC1 ---
        fprintf('  M6b: Behavior + soft non-brain PC1\n');
        all_results.M6b_BehSoftNonBrainPC1 = fonduta.glm.ols( ...
            'M6b_BehSoftNonBrainPC1', PDI.PDI, bmask, ...
            [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all .* wheel), nonBrainPC1], ...
            {'stim_hrf', 'wheel', 'wheel_hrf', 'interaction_hrf', 'nonBrainPC1'});

        %% --- M6c: M5 + soft global PC1 + soft non-brain PC1 ---
        fprintf('  M6c: Behavior + soft global + non-brain PC1\n');
        all_results.M6c_BehSoftBothPC1 = fonduta.glm.ols( ...
            'M6c_BehSoftBothPC1', PDI.PDI, bmask, ...
            [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all .* wheel), globalPC1, nonBrainPC1], ...
            {'stim_hrf', 'wheel', 'wheel_hrf', 'interaction_hrf', 'globalPC1', 'nonBrainPC1'});

        %% --- M7a: Unique effect of smooth running speed (within M5 design) ---
        %   wheelSmooth placed first → eta2(1,:,:) = its unique partial eta²
        fprintf('  M7a: Unique smooth running effect\n');
        all_results.M7a_RunSmooth = fonduta.glm.ols( ...
            'M7a_RunSmooth', PDI.PDI, bmask, ...
            [wheelSmooth, hrf(stim_all), hrf(wheel), hrf(stim_all .* wheel)], ...
            {'wheelSmooth', 'stim_hrf', 'wheel_hrf', 'interaction_hrf'});

        %% --- M7b: Unique effect of HRF-convolved running speed (within M5 design) ---
        %   hrf(wheel) placed first → eta2(1,:,:) = its unique partial eta²
        fprintf('  M7b: Unique conv running effect\n');
        all_results.M7b_RunConv = fonduta.glm.ols( ...
            'M7b_RunConv', PDI.PDI, bmask, ...
            [hrf(wheel), hrf(stim_all), wheelSmooth, hrf(stim_all .* wheel)], ...
            {'wheel_hrf', 'stim_hrf', 'wheelSmooth', 'interaction_hrf'});

        %% --- M8: Stationary visual ---
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

        disp('Done fitting models')

        %% --- Pearson correlation reference maps (need raw [T x V] matrices) ---
        Y        = fonduta.glm.prepare_data_matrix(PDI.PDI,    bmask);
        Y_steady = fonduta.glm.prepare_data_matrix(PDI_steady, bmask);

        all_results.M8_SteadyVisual.corrAll = fonduta.glm.remap_vec( ...
            corr(hrf(stim_all), Y), bmask);
        all_results.M8_SteadyVisual.corrSteady = fonduta.glm.remap_vec( ...
            corr(M8_pred_steady, Y_steady), bmask);

        % -----------------------------------------------------------------
        % 7. Assemble glmresult  (metadata + predictors sub-struct + models)
        % -----------------------------------------------------------------
        glmresult             = struct();
        glmresult.dataPath    = subDataPath{isub};
        glmresult.anatPath    = subAnatPath{isub};
        glmresult.Transf      = Transf;
        glmresult.bmask       = bmask;
        glmresult.nonBrainMask  = nonBrainMask;
        glmresult.allen_regions = allen_regions;

        % Raw predictor time-series — the building blocks used by all models
        glmresult.predictors.stim_all          = stim_all;
        glmresult.predictors.stim_stationary   = stim_stationary;
        glmresult.predictors.wheel             = wheel;
        glmresult.predictors.wheelSmooth       = wheelSmooth;
        glmresult.predictors.runningFrameMask  = runningFrameMask;
        glmresult.predictors.globalPC1         = globalPC1;
        glmresult.predictors.nonBrainPC1       = nonBrainPC1;
        glmresult.predictors.stationaryTrialIdx = stationaryTrialIdx;
        glmresult.predictors.runningTrialIdx   = runningTrialIdx;

        % Model results — each model contains .betas, .eta2, .R2,
        %                 .Xmodel (z-scored design matrix), .predictor_labels
        glmresult.models = all_results;

        % -----------------------------------------------------------------
        % 8. Save session result
        % -----------------------------------------------------------------
        fonduta.io.datapath.save_results(resultPath, resultFolder, subDataPath{isub}, glmresult);

    catch ME
        fprintf('ERROR in session %d: %s\n', isub, ME.message);
        fprintf('  File: %s  Line: %d\n', ME.stack(1).file, ME.stack(1).line);
        fprintf('Skipping session %d.\n', isub);
    end

end

toc;

fprintf('\n=================================================\n');
fprintf(' Included sessions (%d / %d):\n', numel(sesIncl), numel(subDataPath));
disp(sesIncl);
fprintf('=================================================\n');
