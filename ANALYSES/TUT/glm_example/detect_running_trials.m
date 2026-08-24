function [stationaryTrialIdx, runningTrialIdx] = detect_running_trials(PDI, speedThresh, minDuration)
% fn.detect_running_trials  Classify stimulus trials as stationary or running.
%
% For each trial, checks whether the animal ran for at least minDuration
% seconds (continuous bout) at a speed exceeding speedThresh during
% the stimulus window.
%
% Inputs:
%   PDI          - PDI data struct; must contain:
%                    .stimInfo.startTime  [nTrials x 1] stimulus onset times (s)
%                    .stimInfo.endTime    [nTrials x 1] stimulus offset times (s)
%                    .wheelInfo.time      wheel encoder timestamps (s)
%                    .wheelInfo.wheelspeed wheel speed samples (arbitrary units)
%   speedThresh  - scalar speed threshold above which animal is considered
%                  running (same units as PDI.wheelInfo.wheelspeed)
%   minDuration  - minimum duration (seconds) of a continuous running bout
%                  required to classify a trial as a running trial
%
% Outputs:
%   stationaryTrialIdx - row vector of trial indices where animal was stationary
%   runningTrialIdx    - row vector of trial indices where animal was running
%
% Notes:
%   A session is usable only when both outputs are non-empty.
%   Check: if isempty(stationaryTrialIdx) || isempty(runningTrialIdx); continue; end

    nTrials     = numel(PDI.stimInfo.stimCond);
    timeDev     = mean(diff(PDI.wheelInfo.time));
    isRunning   = false(nTrials, 1);

    for itrl = 1:nTrials

        % Extract wheel speed during this trial's stimulus window
        inWindow = PDI.wheelInfo.time >= PDI.stimInfo.startTime(itrl) & ...
                   PDI.wheelInfo.time <= PDI.stimInfo.endTime(itrl);

        trialSpeed = PDI.wheelInfo.wheelspeed(inWindow);

        % Find connected components of speed > threshold
        CC     = bwconncomp(abs(trialSpeed) > speedThresh);
        CCsize = cellfun(@numel, CC.PixelIdxList);

        % Trial is a running trial if any bout lasts longer than minDuration
        if any(CCsize > minDuration / timeDev)
            isRunning(itrl) = true;
        end

    end

    runningTrialIdx    = find( isRunning)';
    stationaryTrialIdx = find(~isRunning)';

    nRunning    = numel(runningTrialIdx);
    nStationary = numel(stationaryTrialIdx);

    fprintf('Session: running %d / stationary %d / total %d', ...
        nRunning, nStationary, nTrials);

    if isempty(runningTrialIdx)
        fprintf(' — SKIPPED (no running trials)\n');
    elseif isempty(stationaryTrialIdx)
        fprintf(' — SKIPPED (all trials running)\n');
    else
        fprintf('\n');
    end

end
