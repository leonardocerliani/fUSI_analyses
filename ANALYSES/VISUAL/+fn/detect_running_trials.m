function [runningTrialIndex, isIncluded] = detect_running_trials(PDI, speedThresh, minDuration)
% fn.detect_running_trials  Classify stimulus trials as running or stationary.
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
%   runningTrialIndex - row vector of trial indices classified as running
%   isIncluded        - logical scalar; true if the session has at least one
%                       running AND at least one stationary trial
%
% Notes:
%   Sessions where isIncluded = false should be skipped in the main loop.

    nTrials           = numel(PDI.stimInfo.stimCond);
    runningTrialIndex = [];
    timeDev           = mean(diff(PDI.wheelInfo.time));

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
            runningTrialIndex = [runningTrialIndex, itrl]; %#ok<AGROW>
        end

    end

    nRunning   = numel(runningTrialIndex);
    isIncluded = nRunning > 0 && nRunning < nTrials;

    fprintf('Session: running trials %d / %d', nRunning, nTrials);

    if ~isIncluded
        if nRunning == 0
            fprintf(' — SKIPPED (no running trials)\n');
        else
            fprintf(' — SKIPPED (all trials running)\n');
        end
    else
        fprintf('\n');
    end

end
