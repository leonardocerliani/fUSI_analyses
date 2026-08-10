function [stim_all, stim_stationary] = build_visual_predictors(PDI, stationaryTrialIdx, runningTrialIdx)
% fn.build_visual_predictors  Build visual stimulus boxcar EVs.
%
% Creates two explanatory variables (boxcar vectors) for the visual GLM:
%   stim_all        — all visual trials (stationary + running)
%   stim_stationary — stationary visual trials only
%
% HRF convolution is intentionally NOT applied here — it is done explicitly
% in the orchestrator via hrf(EV), making model specifications readable.
%
% Inputs:
%   PDI                - PDI data struct; must contain:
%                          .stimInfo.startTime  [nTrials x 1] onset times (s)
%                          .stimInfo.endTime    [nTrials x 1] offset times (s)
%                          .stimInfo.stimCond   [nTrials x 1] condition labels
%                          .time                [1 x nt] scan frame timestamps (s)
%   stationaryTrialIdx - row vector of trial indices where animal was stationary
%                        (from fn.detect_running_trials)
%   runningTrialIdx    - row vector of trial indices where animal was running
%                        (from fn.detect_running_trials)
%
% Outputs:
%   stim_all        [nt x 1] boxcar: 1 during any visual trial
%   stim_stationary [nt x 1] boxcar: 1 during stationary visual trials only

    nt      = numel(PDI.time);
    nTrials = numel(PDI.stimInfo.stimCond);

    % Map stimulus onset/offset times to nearest frame indices
    [~, onsetFrame]  = arrayfun(@(x) min(abs(x - PDI.time)), ...
                                PDI.stimInfo.startTime, 'UniformOutput', true);
    [~, offsetFrame] = arrayfun(@(x) min(abs(x - PDI.time)), ...
                                PDI.stimInfo.endTime,   'UniformOutput', true);

    % Build boxcars
    stim_all        = zeros(nt, 1);
    stim_stationary = zeros(nt, 1);

    allTrialIdx = [stationaryTrialIdx(:)', runningTrialIdx(:)'];

    for ii = 1:numel(allTrialIdx)
        idx = allTrialIdx(ii);
        stim_all(onsetFrame(idx):offsetFrame(idx)) = 1;
    end

    for ii = 1:numel(stationaryTrialIdx)
        idx = stationaryTrialIdx(ii);
        stim_stationary(onsetFrame(idx):offsetFrame(idx)) = 1;
    end

end
