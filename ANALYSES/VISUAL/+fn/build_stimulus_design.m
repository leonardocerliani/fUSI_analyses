function stimDesign = build_stimulus_design(PDI, runningTrialIndex)
% fn.build_stimulus_design  Build stimulus boxcar vectors for visual experiment.
%
% Splits trials into stationary-visual and running-visual based on
% runningTrialIndex, and creates boxcar vectors.
% HRF convolution is intentionally NOT done here — it is applied explicitly
% in the orchestrator via  hrf(EV),  keeping model specifications readable.
%
% Inputs:
%   PDI               - PDI data struct; must contain:
%                         .stimInfo.startTime  [nTrials x 1] onset times (s)
%                         .stimInfo.endTime    [nTrials x 1] offset times (s)
%                         .stimInfo.stimCond   trial condition labels
%                         .time                [1 x nt] scan frame timestamps (s)
%   runningTrialIndex - row vector of trial indices classified as running
%
% Output:
%   stimDesign - struct with fields:
%     .stimVisual              [nt x 1] boxcar for stationary-visual trials
%     .stimVisualRunning       [nt x 1] boxcar for running-visual trials
%     .condMat                 [nTrials x 1] cell array of condition labels
%     .visualTrialIndex        indices of stationary visual trials
%     .visualRunningTrialIndex indices of running visual trials

    nt      = numel(PDI.time);
    nTrials = numel(PDI.stimInfo.stimCond);

    %% Map stimulus onset/offset times to frame indices
    [~, onsetFrame]  = arrayfun(@(x) min(abs(x - PDI.time)), ...
                                PDI.stimInfo.startTime, 'UniformOutput', true);
    [~, offsetFrame] = arrayfun(@(x) min(abs(x - PDI.time)), ...
                                PDI.stimInfo.endTime,   'UniformOutput', true);

    %% Assign trial labels
    condMat                    = repmat({'visual'}, nTrials, 1);
    condMat(runningTrialIndex) = {'visualRunning'};

    visualTrialIndex        = find(strcmp(condMat, 'visual'));
    visualRunningTrialIndex = find(strcmp(condMat, 'visualRunning'));

    %% Build boxcar vectors
    stimVisual        = zeros(nt, 1);
    stimVisualRunning = zeros(nt, 1);

    for ii = 1:numel(visualTrialIndex)
        idx = visualTrialIndex(ii);
        stimVisual(onsetFrame(idx):offsetFrame(idx)) = 1;
    end

    for ii = 1:numel(visualRunningTrialIndex)
        idx = visualRunningTrialIndex(ii);
        stimVisualRunning(onsetFrame(idx):offsetFrame(idx)) = 1;
    end

    %% Pack output
    stimDesign.stimVisual              = stimVisual;
    stimDesign.stimVisualRunning       = stimVisualRunning;
    stimDesign.condMat                 = condMat;
    stimDesign.visualTrialIndex        = visualTrialIndex;
    stimDesign.visualRunningTrialIndex = visualRunningTrialIndex;

end
