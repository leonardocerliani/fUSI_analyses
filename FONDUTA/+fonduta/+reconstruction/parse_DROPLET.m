function stimInfo = parse_DROPLET(datapath, TTLinfo, NIDAQInfo)
% PARSE_DROPLET Extracts droplet paradigm event timestamps from TTL hardware channels and CSV logfiles.
%
%   stimInfo = PARSE_DROPLET(datapath, TTLinfo, NIDAQInfo)
%
%   Inputs:
%       datapath  - Path to directory containing DropletStimulation.csv
%       TTLinfo   - Aligned TTL matrix (where col 1 is time, cols 10-12 are event channels)
%       NIDAQInfo - Table containing NIDAQ recording timestamps (.time)
%
%   Outputs:
%       stimInfo  - Structure with fields: dropTime, touch1, touch2, shockStart, shockEnd

    % Initialize structure fields
    stimInfo.dropTime   = [];
    stimInfo.touch1     = [];
    stimInfo.touch2     = [];
    stimInfo.shockStart = [];
    stimInfo.shockEnd   = [];

    dropCsvPath = fullfile(datapath, 'DropletStimulation.csv');
    if ~exist(dropCsvPath, 'file')
        warning('DropletStimulation.csv not found in %s', datapath);
        return;
    end

    dropTable = readtable(dropCsvPath);

    % -------------------------------------------------------------------
    % 1. DROP EVENT (No TTL available -> Software CSV only)
    % -------------------------------------------------------------------
    dropRows = strcmp(dropTable.event, 'drop');
    if any(dropRows)
        stimInfo.dropTime = dropTable.time(dropRows) - NIDAQInfo.time(1);
    end

    % -------------------------------------------------------------------
    % 2. TOUCH 1 (Hardware TTL: Col 10, Rising Edge)
    % -------------------------------------------------------------------
    idx_touch1 = find(diff(TTLinfo(:, 10)) > 0);
    if ~isempty(idx_touch1)
        stimInfo.touch1 = TTLinfo(idx_touch1, 1);
    else
        % Fallback to CSV
        t1Rows = strcmp(dropTable.event, 'touch1');
        stimInfo.touch1 = dropTable.time(t1Rows) - NIDAQInfo.time(1);
    end

    % -------------------------------------------------------------------
    % 3. TOUCH 2 (Hardware TTL: Col 11, Rising Edge)
    % -------------------------------------------------------------------
    idx_touch2 = find(diff(TTLinfo(:, 11)) > 0);
    if ~isempty(idx_touch2)
        stimInfo.touch2 = TTLinfo(idx_touch2, 1);
    else
        % Fallback to CSV
        t2Rows = strcmp(dropTable.event, 'touch2');
        stimInfo.touch2 = dropTable.time(t2Rows) - NIDAQInfo.time(1);
    end

    % -------------------------------------------------------------------
    % 4. SHOCK (Hardware TTL: Col 12, Active-Low -> Falling = Start, Rising = End)
    % -------------------------------------------------------------------
    idx_shockStart = find(diff(TTLinfo(:, 12)) < 0);
    idx_shockEnd   = find(diff(TTLinfo(:, 12)) > 0);

    if ~isempty(idx_shockStart) && ~isempty(idx_shockEnd)
        stimInfo.shockStart = TTLinfo(idx_shockStart, 1);
        stimInfo.shockEnd   = TTLinfo(idx_shockEnd, 1);
    else
        % Fallback to CSV
        shockRows = strcmp(dropTable.event, 'shock');
        stimInfo.shockStart = dropTable.time(shockRows) - NIDAQInfo.time(1);
        % Note: If CSV does not record shock duration, shockEnd falls back to start times
        stimInfo.shockEnd   = stimInfo.shockStart;
    end
end