%% analysis_visual_FONDUTA.m — Visual GLM Analysis Orchestrator (FONDUTA version)
%
% Main script for the visual stimulation GLM analysis.
% Uses the FONDUTA package for all generic operations.
%
% USAGE:
%   Set FONDUTA_PATH below, then run from within ANALYSES/VISUAL/ so that
%   the local +fn/ package is visible.  FONDUTA can be anywhere on disk.
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
%     .predictor_labels                  cell array matching rows of betas / eta2
%     .model_name                        string identifier
%
% Results are saved per session as GLMSes<isub>.mat in the result folder.
% Each file contains variable 'data' (= glmresult struct).
%
% Dependencies:
%   FONDUTA package (set FONDUTA_PATH below)
%   +fn/  (local to this analysis folder):
%       fn.build_stimulus_design, fn.build_behavior_regressors,
%       fn.detect_running_trials

%% =========================================================================
%  CONFIGURATION — edit these parameters before running
%  =========================================================================

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';

condition    = 'VisualTest';   % experiment condition
resultFolder = 'LC';           % output subfolder name

speedThresh  = 35;     % wheel speed threshold (counts/s) for running classification
minDuration  = 0.2;    % min running bout duration (s) to classify a trial as running

% SPM-style double-gamma HRF parameters:
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]
hrfParams    = [2.4  8  0.8  0.9  6  0  16];

%% =========================================================================
%  PATH SETUP  — add FONDUTA (only; +fn/ is local and auto-visible)
%  =========================================================================

addpath(genpath(FONDUTA_PATH));

%% =========================================================================
%  LOAD DATASET PATHS
%  =========================================================================

[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.get_paths(condition);

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
        % -----------------------------------------------------------------
        [runningIdx, isIncluded] = fn.detect_running_trials(PDI, speedThresh, minDuration);

        if ~isIncluded
            continue
        end

        sesIncl = [sesIncl, isub]; %#ok<AGROW>

        % -----------------------------------------------------------------
        % 3. Brain masks
        % -----------------------------------------------------------------
        [bmask, nonBrainMask] = fonduta.atlas.build_brain_masks(anatomic, Transf);

        % -----------------------------------------------------------------
        % 4. HRF convolution operator
        %    hrf(EV) convolves any signal EV with the canonical HRF.
        %    TR is derived from the current session's frame timestamps.
        % -----------------------------------------------------------------
        TR         = mean(diff(PDI.time));
        hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
        hrf        = @(ev) filter(hrf_kernel, 1, ev(:));

        % -----------------------------------------------------------------
        % 5. Compute predictor signals
        %    Functions below return raw signals (boxcars, wheel speed, PC1).
        %    HRF convolution is applied explicitly in each model block below
        %    using hrf(signal), making the model specification self-documenting.
        % -----------------------------------------------------------------
        stimDesign = fn.build_stimulus_design(PDI, runningIdx);
        behDesign  = fn.build_behavior_regressors(PDI, hrf_kernel, speedThresh);
        tic
        pc1Signals = fonduta.utils.extract_pc1_signals(PDI, bmask, nonBrainMask);
        toc
        
        % Unpack into short named variables for readable model specification
        stim_all        = stimDesign.stimVisual + stimDesign.stimVisualRunning;
        stim_stationary = stimDesign.stimVisual;
        wheel           = behDesign.wheelSpeedAbs;
        wheelSmooth     = behDesign.wheelSpeedSmooth;
        globalPC1       = pc1Signals.globalPC1;
        nonBrainPC1     = pc1Signals.nonBrainPC1;

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
        %   GLM on stationary timepoints only + Pearson correlation reference maps
        fprintf('  M8: Stationary visual\n');
        includeSteady    = ~behDesign.steadyExcludeMask(:);
        PDI_steady       = PDI.PDI(:, :, includeSteady);
        M8_pred_steady   = hrf(stim_stationary(includeSteady));

        all_results.M8_SteadyVisual = fonduta.glm.ols( ...
            'M8_SteadyVisual', PDI_steady, bmask, ...
            M8_pred_steady, {'stim_stationary_hrf'});

        % Pearson correlation reference maps (need raw [T x V] matrices)
        Y        = fonduta.glm.prepare_data_matrix(PDI.PDI,  bmask);
        Y_steady = fonduta.glm.prepare_data_matrix(PDI_steady, bmask);

        all_results.M8_SteadyVisual.corrAll = fonduta.glm.remap_vec( ...
            corr(hrf(stim_all), Y), bmask);
        all_results.M8_SteadyVisual.corrSteady = fonduta.glm.remap_vec( ...
            corr(M8_pred_steady, Y_steady), bmask);

        % -----------------------------------------------------------------
        % 7. Assemble glmresult  (metadata + all model results)
        % -----------------------------------------------------------------
        glmresult                   = struct();
        glmresult.bmask             = bmask;
        glmresult.nonBrainMask      = nonBrainMask;
        glmresult.condMat           = stimDesign.condMat;
        glmresult.stim_all          = stim_all;
        glmresult.stim_stationary   = stim_stationary;
        glmresult.wheel             = wheel;
        glmresult.wheelSmooth       = wheelSmooth;
        glmresult.globalPC1         = globalPC1;
        glmresult.nonBrainPC1       = nonBrainPC1;
        glmresult.visualTrialIndex  = stimDesign.visualTrialIndex;
        glmresult.runningTrialIndex = stimDesign.visualRunningTrialIndex;
        glmresult.steadyExcludeMask = behDesign.steadyExcludeMask;
        glmresult.models            = all_results;

        % -----------------------------------------------------------------
        % 8. Save session result
        % -----------------------------------------------------------------
        fonduta.io.datapath.save_results(resultPath, resultFolder, isub, glmresult);

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
