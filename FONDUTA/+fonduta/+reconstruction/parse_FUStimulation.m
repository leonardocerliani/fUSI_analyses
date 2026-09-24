function stimInfo = parse_FUStimulation(datapath, TTLinfo)
% PARSE_FUSTIMULATION Extracts FUS stimulation conditions and start/end timestamps from TTL channels.
%
%   stimInfo = PARSE_FUSTIMULATION(datapath, TTLinfo)
%
%   Inputs:
%       datapath - Path to directory containing FUStimulation.csv
%       TTLinfo  - Aligned TTL matrix (where col 1 is time, cols 4, 5, 12 are stimulation channels)
%
%   Outputs:
%       stimInfo - Structure with fields: stimCond, startTime, endTime

    stimInfo.stimCond  = [];
    stimInfo.startTime = [];
    stimInfo.endTime   = [];

    fusCsvPath = fullfile(datapath, 'FUStimulation.csv');
    if ~exist(fusCsvPath, 'file')
        warning('FUStimulation.csv not found in %s', datapath);
        return;
    end

    csvData = readtable(fusCsvPath);

    % Detect rising edges across channels 4, 5, or 12
    startTime = TTLinfo(diff(TTLinfo(:,4)) > 0 | diff(TTLinfo(:,5)) > 0 | diff(TTLinfo(:,12)) > 0, 1);
    
    % Detect falling edges across channels 4, 5, or 12
    endTime   = TTLinfo(diff(TTLinfo(:,4)) < 0 | diff(TTLinfo(:,5)) < 0 | diff(TTLinfo(:,12)) < 0, 1);

    % Filter out pre-experiment noise (< 0.1s)
    startTime(startTime < 0.1) = [];
    endTime(endTime < 0.1)     = [];

    stimInfo.stimCond  = csvData.event(2:end);
    stimInfo.startTime = startTime;
    stimInfo.endTime   = endTime;
end