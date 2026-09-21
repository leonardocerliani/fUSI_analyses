%% TTLinfo plot
datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'

configPath = fullfile(datapath, 'experiment_config.json');
cfg = jsondecode(fileread(configPath));


% Read TTLinfo
ttlFiles = dir(fullfile(datapath, cfg.file_names.ttl_pattern))
TTLinfo = readmatrix(fullfile(ttlFiles(1).folder, ttlFiles(1).name));

pdiFrameChan = cfg.processing_parameters.pdi_frame_channel;

% Finds column indices where the standard deviation is greater than 0
varyingCols = find(std(TTLinfo) > 0);

figure('Name', 'TTL Channels');
for i = 1:numel(varyingCols)
    colIdx = varyingCols(i);
    subplot(numel(varyingCols), 1, i);
    plot(TTLinfo(:, 1), TTLinfo(:, colIdx)); 
    title(sprintf('TTL Column %d', colIdx));
    xlabel('Time (s)');
    grid on;
end


%% Alignment of NIDAQ and DropletStimulation.csv

% The NIDAQ contains info about touch1, touch2 and shock_left, however
% there is a misplaced shock_right colums of only 1's and the droplet is
% also only 1's. Also, multiple rows define each event, which is confusing.
% Therefore we should use the DropletStimulation.csv as a reference.
%
% IMPORTANTLY, however, we need to use the NIDAQ to calculate the time zero
% of the fusi signal, which is recorded in the TTLinfo, therefore to align
% the DropletStimulation.csv to the fusi signal we still need one
% information from the NIDAQ.

%% Read NIDAQ
% NB: there are two possible filenames for the (NI)DAQ.csv, hence the loop
nidaqFiles = cfg.file_names.nidaq_log;
NIDAQInfo = [];
for i = 1:length(nidaqFiles)
    nidaqPath = fullfile(datapath, nidaqFiles{i});
    if exist(nidaqPath, 'file')
        fprintf('Loading NIDAQ logfile from %s.\n', nidaqFiles{i});
        NIDAQInfo = readtable(nidaqPath);
        break;
    end
end

dt = datetime(NIDAQInfo.time, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
dt.Format = 'HH:mm:ss.SSSS';
NIDAQInfo.dt = dt;
clear dt


%% Read DropletStimulation.csv
dropCfg = cfg.stimuli.droplet_stimuli;
csvPath = fullfile(datapath, dropCfg.csv_filename);
dropTable = readtable(csvPath);

dt = datetime(dropTable.time, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
dt.Format = 'HH:mm:ss.SSSS';
dropTable.dt = dt;
clear dt
head(dropTable, 5)

clc
head(NIDAQInfo, 8)
head(dropTable, 8)


%% Locating Task Baseline: Searches NIDAQ channels for the first rising edge
% marking session initialization (checks Channel 6 first, falls back to Channel 5).
% NB: Parametrize this for ALL experiments would be a nightmare, so
% please make sure that you hardware launch channels are 5 and/or 6.
initTTL = find(diff(TTLinfo(:, 6)) > 0, 1, 'first');
if isempty(initTTL)
    initTTL = find(diff(TTLinfo(:, 5)) > 0, 1, 'first');
end
t_launch = TTLinfo(initTTL, 1);

startPulseIdx = find(diff(TTLinfo(:, 5)) ~= 0, 1, 'first');
hardwareTaskStart = TTLinfo(startPulseIdx, 1);

% EXTRACT HARDWARE EVENTS FROM TTLinfo
touch1_onset = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
touch2_onset = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
shock_onset  = TTLinfo(diff(TTLinfo(:, 12)) < 0, 1);

% ALIGN CSV EVENTS VIA TIME OFFSET
csvStartRelative = dropTable.time(1) - NIDAQInfo.time(1);
timeOffset = hardwareTaskStart - csvStartRelative;

dropRows = dropTable(strcmp(dropTable.event, 'drop'), :);
drop_onset = (dropRows.time - NIDAQInfo.time(1)) + timeOffset;

%% Events table based on TTLinfo
events = [repmat({'touch1'}, numel(touch1_onset), 1); ...
          repmat({'touch2'}, numel(touch2_onset), 1); ...
          repmat({'shock'},  numel(shock_onset),  1); ...
          repmat({'drop'},   numel(drop_onset),   1)];
onsets = [touch1_onset; ...
          touch2_onset; ...
          shock_onset; ...
          drop_onset];

eventTable_TTLinfo = table(events, onsets, 'VariableNames', {'event', 'onset_time'});
eventTable_TTLinfo = sortrows(eventTable_TTLinfo, 'onset_time');

%% Events table based on dropTable
targetEvents = ["drop", "touch1", "touch2", "shock"];
mask = matches(dropTable.event, targetEvents);
csvEventsTable = dropTable(mask, {'event', 'time'});

% Shift software timestamps by csvStartRelative to match hardware clock
csvEventsTable.onset_time = (csvEventsTable.time - dropTable.time(1)) + hardwareTaskStart + csvStartRelative;

eventTable_dropTable = csvEventsTable(:, {'event', 'onset_time'});
eventTable_dropTable = sortrows(eventTable_dropTable, 'onset_time');

%% PLOT ALIGNED HARDWARE VS SOFTWARE EVENTS
c_touch1 = [0.10, 0.80, 0.30];
c_touch2 = [0.90, 0.50, 0.10];
c_shock  = [0.90, 0.10, 0.10];

figure('Name', 'Aligned Hardware vs Software Events', 'Color', 'w', 'Position', [100, 100, 1200, 600]);

% Top Subplot: Hardware Events (TTLinfo)
ax1 = subplot(2, 1, 1);
hold(ax1, 'on');

ttl_no_drops = eventTable_TTLinfo(~strcmp(eventTable_TTLinfo.event, 'drop'), :);

for i = 1:height(ttl_no_drops)
    ev = ttl_no_drops.event{i};
    t  = ttl_no_drops.onset_time(i);
    if strcmp(ev, 'shock')
        xline(ax1, t, '--', 'Color', c_shock, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        is_t1 = strcmp(ev, 'touch1');
        col = is_t1 * c_touch1 + (~is_t1) * c_touch2;
        stem(ax1, t, 1, 'Color', col, 'LineWidth', 1.2, 'Marker', 'o', 'MarkerFaceColor', col, 'HandleVisibility', 'off');
    end
end

title(ax1, 'Hardware Events from TTLinfo (touch1, touch2, shock)');
xlabel(ax1, 'Time (s)'); ylabel(ax1, 'Event');
ylim(ax1, [0, 1.5]); grid(ax1, 'on');

% Bottom Subplot: Software Events (dropTable)
ax2 = subplot(2, 1, 2);
hold(ax2, 'on');

csv_no_drops = eventTable_dropTable(~strcmp(eventTable_dropTable.event, 'drop'), :);

for i = 1:height(csv_no_drops)
    ev = csv_no_drops.event{i};
    t  = csv_no_drops.onset_time(i);
    if strcmp(ev, 'shock')
        xline(ax2, t, '--', 'Color', c_shock, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        is_t1 = strcmp(ev, 'touch1');
        col = is_t1 * c_touch1 + (~is_t1) * c_touch2;
        stem(ax2, t, 1, 'Color', col, 'LineWidth', 1.2, 'Marker', 'o', 'MarkerFaceColor', col, 'HandleVisibility', 'off');
    end
end

title(ax2, 'Software Events from dropTable (touch1, touch2, shock)');
xlabel(ax2, 'Time (s)'); ylabel(ax2, 'Event');
ylim(ax2, [0, 1.5]); grid(ax2, 'on');

linkaxes([ax1, ax2], 'x');
xlim(ax1, [80, 280]);









