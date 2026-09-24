function stimInfo = parse_ShockStimulation(datapath, TTLinfo)
% PARSE_SHOCKSTIMULATION Extracts shock stimulation events, intensities, and perceived squeaks.
%
%   stimInfo = PARSE_SHOCKSTIMULATION(datapath, TTLinfo)
%
%   Inputs:
%       datapath - Path to directory containing ShockStimulation.csv (and optional Excel file)
%       TTLinfo  - Aligned TTL matrix (where col 1 is time, cols 4, 5, 12 are shock channels)
%
%   Outputs:
%       stimInfo - Table (for shock_tail paradigm) or structure with fields:
%                  stimCond, startTime, endTime

    stimInfo = struct();
    shockCsvPath = fullfile(datapath, 'ShockStimulation.csv');

    if ~exist(shockCsvPath, 'file')
        warning('ShockStimulation.csv not found in %s', datapath);
        return;
    end

    csvData = readtable(shockCsvPath);

    if strcmp(csvData.event{2}, 'shock_tail')
        % Detect falling edges for start times (channels 5 or 12)
        startTime = TTLinfo(diff(TTLinfo(:,5)) < 0 | diff(TTLinfo(:,12)) < 0, 1);
        % Detect rising edges for end times (channels 5 or 12)
        endTime   = TTLinfo(diff(TTLinfo(:,5)) > 0 | diff(TTLinfo(:,12)) > 0, 1);

        % Filter out pre-experiment noise (< 0.1s)
        startTime(startTime < 0.1) = [];
        endTime(endTime < 0.1)     = [];

        excelPath = fullfile(datapath, 'shockIntensities_and_perceivedSqueaks.xlsx');
        if exist(excelPath, 'file')
            shockInfo = readtable(excelPath);
        else
            shockInfo = table();
        end

        % Build combined table output
        stimInfo = addvars(shockInfo, csvData.event(2:end), 'Before', 1, 'NewVariableNames', 'stimCond');
        stimInfo = addvars(stimInfo, startTime, 'Before', 2, 'NewVariableNames', 'startTime');
        stimInfo = addvars(stimInfo, endTime, 'Before', 3, 'NewVariableNames', 'endTime');
    else
        % Detect falling edges for start times (channels 4 or 12)
        startTime = TTLinfo(diff(TTLinfo(:,4)) < 0 | diff(TTLinfo(:,12)) < 0, 1);
        % Detect rising edges for end times (channels 4 or 12)
        endTime   = TTLinfo(diff(TTLinfo(:,4)) > 0 | diff(TTLinfo(:,12)) > 0, 1);

        stimCond = csvData.event(2:end);
        stimCond = strrep(stimCond, 'shock_left', 'shockOBS');
        stimCond = strrep(stimCond, 'shock_right', 'shockCTL');

        stimInfo.startTime = startTime;
        stimInfo.endTime   = endTime;
        stimInfo.stimCond  = stimCond;
    end
end