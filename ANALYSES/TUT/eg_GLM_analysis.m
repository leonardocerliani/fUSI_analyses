%% Example of a simple GLM with all trials of visual stimuli

%% Load data and define parameters
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

addpath(genpath('.'))

atlas = fonduta.atlas.load_atlas();

condition    = 'VisualTest';   % experiment condition (passed to Datapath)
resultFolder = 'glm_example';           % output subfolder name

speedThresh  = 35;     % wheel speed threshold (counts/s) for running classification
minDuration  = 0.2;    % min running bout duration (s) to classify a trial as running

% SPM-style double-gamma HRF parameters:
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]
hrfParams    = [2.4  8  0.8  0.9  6  0  16];

% Get the location of the data using Datapath
[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
% Modify the resultPath so that it points to the current directory (only for this example)
resultPath = pwd

% choose only one subject
isub = 33
[PDI, anatomic, Transf] = fonduta.io.datapath.load_session(...
    subDataPath{isub}, subAnatPath{isub});


%% Detect stationary and running trials
[stationaryTrialIdx, runningTrialIdx] = detect_running_trials(...
    PDI, speedThresh, minDuration);


%% Build a slice mask and define the hrf convolution operator we will use later
[bmask, nonBrainMask, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

% -----------------------------------------------------------------
%    HRF convolution operator
%    hrf(EV) convolves any signal EV with the canonical HRF.
%    TR is derived from the current session's frame timestamps.
% -----------------------------------------------------------------
TR         = mean(diff(PDI.time));
hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
hrf        = @(ev) filter(hrf_kernel, 1, ev(:));


%% Build the predictors
[stim_all, stim_stationary] = build_visual_predictors(...
    PDI, stationaryTrialIdx, runningTrialIdx);


%% Prepare the struct where all the results will be saved
all_results = struct();


%% Run the GLMs

% --- M1: Stimulus only (all trials) ---
all_results.M1_StimOnly = fonduta.glm.ols( ...
    'M1_StimOnly', ...      % label of the model
    PDI.PDI, ...            % fusi data
    bmask, ...              % slice mask
    [hrf(stim_all)], ...    % array of convolved predictors
    [{'stim_hrf'}] ...      % array of predictor labels
    );        

disp('Done')

%% Assemble the struct
glmresult             = struct();
glmresult.dataPath    = subDataPath{isub};
glmresult.anatPath    = subAnatPath{isub};
glmresult.Transf      = Transf;
glmresult.bmask       = bmask;
glmresult.nonBrainMask  = nonBrainMask;
glmresult.allen_regions = allen_regions;

% Raw predictor time-series — the building blocks used by all models
glmresult.predictors.stim_all          = stim_all;

% Model results — each model contains .betas, .eta2, .R2,
%                 .Xmodel (z-scored design matrix), .predictor_labels
glmresult.models = all_results;



%% Save results
fonduta.io.datapath.save_results(resultPath, resultFolder, subDataPath{isub}, glmresult);


%% View results
fonduta.viz.view_glm("glm_example/glm_run-142136.mat")





