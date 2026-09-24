function stimInfo = parse_AudioStimulation(datapath, TTLinfo, NIDAQInfo)
% PARSE_AUDIOSTIMULATION Extracts auditory stimulation start, end, and condition timestamps.
%
%   stimInfo = PARSE_AUDIOSTIMULATION(datapath, TTLinfo, NIDAQInfo)
%
%   Inputs:
%       datapath  - Path to directory containing AudioStimulation.csv
%       TTLinfo   - Aligned TTL matrix (where col 1 is time, col 11 is audio channel)
%       NIDAQInfo - Table containing NIDAQ recording timestamps (.time)
%
%   Outputs:
%       stimInfo  - Structure with fields: startTime, endTime, stimCond

    stimInfo.startTime = [];
    stimInfo.endTime   = [];
    stimInfo.stimCond  = {};

    audioCsvPath = fullfile(datapath, 'AudioStimulation.csv');
    if ~exist(audioCsvPath, 'file')
        warning('AudioStimulation.csv not found in %s', datapath);
        return;
    end

    csvData = readtable(audioCsvPath);

    % Primary: Hardware TTL (Channel 11)
    startTime = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
    endTime   = TTLinfo(diff(TTLinfo(:, 11)) < 0, 1);
    stimCond  = csvData.event(strcmp('audio', csvData.event));

    % Fallback: CSV Logfile timestamps if no hardware TTL pulses were detected
    if isempty(startTime)
        csvTime   = csvData.time - NIDAQInfo.time(1);
        isAudio   = strcmp('audio', csvData.event);
        startTime = csvTime(isAudio);
        endTime   = startTime + csvData.duration(isAudio);
        stimCond  = csvData.event(isAudio);
    end

    % Rename 'audio' events to 'CS' (Conditioned Stimulus)
    stimCond = strrep(stimCond, 'audio', 'CS');

    stimInfo.startTime = startTime;
    stimInfo.endTime   = endTime;
    stimInfo.stimCond  = stimCond;
end