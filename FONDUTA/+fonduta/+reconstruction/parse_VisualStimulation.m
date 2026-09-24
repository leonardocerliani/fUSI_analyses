function stimInfo = parse_VisualStimulation(datapath, TTLinfo, NIDAQInfo)
% PARSE_VISUALSTIMULATION Extracts visual stimulation start, end, and condition timestamps.
%
%   stimInfo = PARSE_VISUALSTIMULATION(datapath, TTLinfo, NIDAQInfo)
%
%   Inputs:
%       datapath  - Path to directory containing VisualStimulation.csv
%       TTLinfo   - Aligned TTL matrix (where col 1 is time, col 10 is visual channel)
%       NIDAQInfo - Table containing NIDAQ recording timestamps (.time)
%
%   Outputs:
%       stimInfo  - Structure with fields: startTime, endTime, stimCond

    stimInfo.startTime = [];
    stimInfo.endTime   = [];
    stimInfo.stimCond  = {};

    visCsvPath = fullfile(datapath, 'VisualStimulation.csv');
    if ~exist(visCsvPath, 'file')
        warning('VisualStimulation.csv not found in %s', datapath);
        return;
    end

    csvData = readtable(visCsvPath);

    % Primary: Hardware TTL (Channel 10)
    startTime = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
    endTime   = TTLinfo(diff(TTLinfo(:, 10)) < 0, 1);

    % Filter out short pulse glitches (< 10 ms)
    stimDuration = endTime - startTime;
    validStim    = stimDuration >= 0.01;

    startTime = startTime(validStim);
    endTime   = endTime(validStim);

    % Fallback: CSV Logfile timestamps if no valid TTL pulses were detected
    if isempty(startTime)
        csvTime = csvData.time - NIDAQInfo.time(1);
        startTime = csvTime(strcmp('stim', csvData.event));
        endTime   = csvTime(strcmp('blank', csvData.event));
    end

    stimInfo.startTime = startTime;
    stimInfo.endTime   = endTime;
    stimInfo.stimCond  = repmat({'visual'}, numel(startTime), 1);
end