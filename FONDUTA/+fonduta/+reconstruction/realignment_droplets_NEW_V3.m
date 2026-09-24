%% Sync of events from TTLinfo with those in DropletStimulation.csv 
%  using NIDAQ.time(1)

%% Load all files
datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'

configPath = fullfile(datapath, 'experiment_config.json');
cfg = jsondecode(fileread(configPath));

% Read TTLinfo.csv
ttlFile = dir(fullfile(datapath, 'TTL*.csv'))
TTLinfo = readmatrix(fullfile(ttlFile(1).folder, ttlFile(1).name));
% Create a simple variable for TTLinfo.time
timeTTL = TTLinfo(:,1);

% Read DropletStimulation.csv
dropCfg = cfg.stimuli.droplet_stimuli;
csvPath = fullfile(datapath, dropCfg.csv_filename);
dropTable = readtable(fullfile(datapath, 'DropletStimulation.csv'));

% Read NIDAQ.csv
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


%% IMPORTANT
dropTable.diff = dropTable.time - NIDAQInfo.time(1)

timeTTL = TTLinfo(:,1);

% Get the index of the fusi frames (FALLING edges)
idx_fusi_frames = diff(TTLinfo(:, 3)) < 0;
time_fusi_frames = timeTTL(idx_fusi_frames);
fprintf('\n fusi acquisition starts at %.2f sec\n', time_fusi_frames(1));

% Touch 1 from TTLinfo (Col/Channel 10): Rising edge
idx_onset_touch1 = find(diff(TTLinfo(:, 10)) > 0);
onset_touch1 = timeTTL(idx_onset_touch1);

% Touch 1 from dropTable (DropletStimulation.csv)
touch1_dropTable = dropTable(strcmp(dropTable.event, 'touch1'), :);

% Experiment start as mapped in TTLinfo
idx_exp_start = find(diff(TTLinfo(:,5)) < 0, 1, 'first');
exp_start = timeTTL(idx_exp_start);

touch1_dropTable.diff + exp_start; 
onset_touch1;

touch1_dropTable.onset = touch1_dropTable.time - NIDAQInfo.time(1) + exp_start

clc
table(onset_touch1, touch1_dropTable.diff + exp_start, ...
    'VariableNames',{'onset_from_TTLinfo','onset_from_dropTable'})



%% Plot the reconstruction made by Rawdata2MATnew_V0_Chaoyi_MOD.m

root_analysis = '/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_analysis/';
PDI_filename = 'sub-mockexperiment/ses-999999/run-155150-func/PDI.mat';

PDI = load(fullfile(root_analysis, PDI_filename)).PDI;


% Load the TTLinfo from PDI
% CAREFUL! THIS TTLINFO HAS ALREADY BEEN CROPPED SO THAT IT STARTS 
% AT THE FIRST RISING EDGE OF CHANNEL 5 
% OR EQUIVALENTLY AT NIDAQInfo.time(1)
TTLinfo = PDI.TTLinfo_CROPPED;
timeTTL = TTLinfo(:,1);


% Get the percent signal change over the whole image
nVoxels = size(PDI.PDI, 1) * size(PDI.PDI, 2);
pdi2d = reshape(PDI.PDI, [nVoxels, size(PDI.PDI, 3)]);
% figure
% imagesc(pdi2d); colormap gray

rawSignal = median(pdi2d, 1);
s0 = prctile(rawSignal, 5);
if s0 == 0; s0 = eps; end
fusiSignal_dS = ((rawSignal - s0) / s0) * 100;
% figure
% imagesc(fusiSignal_dS); colormap gray


% Get the index of the fusi frames (FALLING edges)
idx_fusi_frames = find(diff(TTLinfo(:, 3)) < 0);
time_fusi_frames = timeTTL(idx_fusi_frames);
% When does fusi start?
fprintf('\n fusi acquisition starts at %.2f sec\n', time_fusi_frames(1));


% Place the fusiSignal_dS on the timeTTL line to plot it 
% together with the events.
% (also interpolate to make it smoother, since we are only mapping
% the rising edges and not the time points inbetween)
ev_fusi = zeros(length(timeTTL),1);
ev_fusi(idx_fusi_frames) = fusiSignal_dS;
ev_fusi = interp1(time_fusi_frames, fusiSignal_dS, timeTTL, 'linear', 0);


figure
hold on

plot(timeTTL, ev_fusi, 'Color', [0.12, 0.47, 0.71], 'LineWidth', 1.5);

touch1_onset = PDI.stimInfo.touch1;
stem(touch1_onset, ones(length(touch1_onset))*7, ...
    'Color', [1,0,0], 'MarkerFaceColor', [1,0,0])

touch2_onset = PDI.stimInfo.touch2;
stem(touch2_onset, ones(length(touch2_onset))*3, ...
    'Color', [1,0,0], 'MarkerFaceColor', [1,1,0])

shock_onset = PDI.stimInfo.shockStart;
stem(shock_onset, ones(length(shock_onset))*6, ...
    'Color', [1,0,0], 'MarkerFaceColor', [0,1,0])

drop_onset = PDI.stimInfo.dropTime;
stem(drop_onset, ones(length(drop_onset))*4, ...
    'Color', [1,0,0], 'MarkerFaceColor', [0,1,1])

hold off

%% Plot with interactive line to check synchronization

root_analysis = '/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_analysis/';
PDI_filename = 'sub-mockexperiment/ses-999999/run-155150-func/PDI.mat';

PDI = load(fullfile(root_analysis, PDI_filename)).PDI;


% Load the TTLinfo from PDI
% CAREFUL! THIS TTLINFO HAS ALREADY BEEN CROPPED SO THAT IT STARTS 
% AT THE FIRST RISING EDGE OF CHANNEL 5 
% OR EQUIVALENTLY AT NIDAQInfo.time(1)
TTLinfo = PDI.TTLinfo_CROPPED;
timeTTL = TTLinfo(:,1);


% Get the percent signal change over the whole image
nVoxels = size(PDI.PDI, 1) * size(PDI.PDI, 2);
pdi2d = reshape(PDI.PDI, [nVoxels, size(PDI.PDI, 3)]);
% figure
% imagesc(pdi2d); colormap gray

rawSignal = median(pdi2d, 1);
s0 = prctile(rawSignal, 5);
if s0 == 0; s0 = eps; end
fusiSignal_dS = ((rawSignal - s0) / s0) * 100;
% figure
% imagesc(fusiSignal_dS); colormap gray


% Get the index of the fusi frames (FALLING edges)
idx_fusi_frames = find(diff(TTLinfo(:, 3)) < 0);
time_fusi_frames = timeTTL(idx_fusi_frames);
% When does fusi start?
fprintf('\n fusi acquisition starts at %.2f sec\n', time_fusi_frames(1));


% Place the fusiSignal_dS on the timeTTL line to plot it 
% together with the events.
% (also interpolate to make it smoother, since we are only mapping
% the rising edges and not the time points inbetween)
ev_fusi = zeros(length(timeTTL),1);
ev_fusi(idx_fusi_frames) = fusiSignal_dS;
ev_fusi = interp1(time_fusi_frames, fusiSignal_dS, timeTTL, 'linear', 0);


fig = figure('Name', 'TTL Channels and fUSi Events', 'Color', 'w');
varyingCols = find(std(TTLinfo) > 0);
numTTL = numel(varyingCols);
totalGridRows = numTTL * 2; 
t = tiledlayout(totalGridRows, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = gobjects(numTTL + 1, 1);

% -------------------------------------------------------------------------
% 1. TOP SUBPLOTS: TTL CHANNELS
% -------------------------------------------------------------------------
for i = 1:numTTL
    colIdx = varyingCols(i);
    ax(i) = nexttile(t, i);
    plot(TTLinfo(:, 1), TTLinfo(:, colIdx)); 
    title(sprintf('TTL Column %d', colIdx));
    grid on;
end

% -------------------------------------------------------------------------
% 2. BOTTOM SUBPLOT: STYLED fUSi SIGNAL & BEHAVIORAL EVENTS
% -------------------------------------------------------------------------
ax(end) = nexttile(t, numTTL + 1, [numTTL, 1]);
hold(ax(end), 'on');

% Shock Background Regions
shockStart = PDI.stimInfo.shockStart;
shockEnd   = PDI.stimInfo.shockEnd;
hShock = [];
for k = 1:numel(shockStart)
    if exist('xregion', 'file')
        hReg = xregion(ax(end), shockStart(k), shockEnd(k), ...
            'FaceColor', [0.85, 0.78, 0.88], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    else
        yl = [-3, 14];
        hReg = patch(ax(end), [shockStart(k) shockEnd(k) shockEnd(k) shockStart(k)], ...
            [yl(1) yl(1) yl(2) yl(2)], [0.85, 0.78, 0.88], ...
            'FaceAlpha', 0.4, 'EdgeColor', 'none');
    end
    if k == 1, hShock = hReg; end
end

% fUSi Signal Trace
hSignal = plot(ax(end), timeTTL, ev_fusi, 'Color', [0.12, 0.47, 0.71], 'LineWidth', 1.0);

% Event Stems (BaseValue = 0)
touch2_onset = PDI.stimInfo.touch2;
hTouch2 = stem(ax(end), touch2_onset, repmat(4.0, size(touch2_onset)), ...
    'LineStyle', ':', 'Color', [0.47, 0.67, 0.19], 'LineWidth', 1.0, ...
    'Marker', '^', 'MarkerFaceColor', [0.47, 0.67, 0.19], 'MarkerSize', 6, 'BaseValue', 0);

drop_onset = PDI.stimInfo.dropTime;
hDrop = stem(ax(end), drop_onset, repmat(5.5, size(drop_onset)), ...
    'LineStyle', '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.0, ...
    'Marker', 'v', 'MarkerFaceColor', [0.85, 0.33, 0.10], 'MarkerSize', 6, 'BaseValue', 0);

touch1_onset = PDI.stimInfo.touch1;
hTouch1 = stem(ax(end), touch1_onset, repmat(8.2, size(touch1_onset)), ...
    'LineStyle', '--', 'Color', [0.65, 0.05, 0.15], 'LineWidth', 1.0, ...
    'Marker', 'd', 'MarkerFaceColor', [0.65, 0.05, 0.15], 'MarkerSize', 6, 'BaseValue', 0);

% Labels & Right Y-Axis
title(ax(end), 'fUSi Signal Timeline with Shock Artifact Verification', 'FontSize', 11, 'FontWeight', 'bold');
xlabel(ax(end), 'Hardware Timestamp (NIDAQ s)', 'FontSize', 10);
ylabel(ax(end), '% \DeltaS/S_0', 'FontSize', 10);
grid(ax(end), 'on');
ax(end).GridColor = [0.85, 0.85, 0.85];
ax(end).Box = 'off';

yyaxis(ax(end), 'right');
ax(end).YColor = 'k';
ylim(ax(end), [-1, 9]);
yticks(ax(end), [4.0, 5.5, 8.2]);
yticklabels(ax(end), {'Touch 2', 'Drop', 'Touch 1'});
ylabel(ax(end), 'Behavioral Events', 'FontSize', 10);

% Bottom Legend
legHandles = [hShock, hSignal, hDrop, hTouch1, hTouch2];
legLabels  = {'Shock Window', 'fUSi Signal (% \DeltaS/S_0)', 'Drop', 'Touch 1', 'Touch 2'};
validIdx   = arrayfun(@(x) isgraphics(x), legHandles);
lgd = legend(ax(end), legHandles(validIdx), legLabels(validIdx), ...
    'Orientation', 'horizontal', 'Location', 'southoutside');
lgd.FontSize = 8;

% Link x-axes
linkaxes(ax, 'x');

% -------------------------------------------------------------------------
% 3. ADVANCED 3-TIER TICK CONFIGURATION
% -------------------------------------------------------------------------
maxX = max(timeTTL);

% Set Major Ticks every 5 seconds (5s mid-ticks + 10s major ticks)
ticks5s = 0:5:ceil(maxX);
tickLabels = cell(size(ticks5s));
for k = 1:numel(ticks5s)
    if mod(ticks5s(k), 10) == 0
        tickLabels{k} = num2str(ticks5s(k)); % Label only 10s multiples
    else
        tickLabels{k} = '';                  % Blank label for x5 mid-ticks
    end
end

for i = 1:numel(ax)
    ax(i).XTick = ticks5s;
    ax(i).XTickLabel = tickLabels;
    ax(i).XMinorTick = 'on';
    ax(i).XAxis.MinorTickValues = 0:1:ceil(maxX); % 1-second minor ticks
    
    ax(i).XMinorGrid = 'off';
    ax(i).YMinorGrid = 'off';
    
    grid(ax(i), 'on');
    ax(i).GridColor = [0.85, 0.85, 0.85];
    ax(i).GridAlpha = 0.5;
    
    % Makes ticks clearly visible outside the axes frame
    ax(i).TickLength = [0.003, 0.005];
    ax(i).TickDir = 'out';
end

% -------------------------------------------------------------------------
% 4. CONTINUOUS FULL-HEIGHT INTERACTIVE LINE (OVERALL FIGURE SPAN)
% -------------------------------------------------------------------------
drawnow; % Ensure layout renders so we can query true pixel coordinates

% Create a single annotation line across the full figure window
fullLine = annotation(fig, 'line', [0.5 0.5], [0.1 0.95], ...
    'Color', [1 0 0], 'LineStyle', '--', 'LineWidth', 1.2);

set(fig, 'WindowButtonMotionFcn', @(src, evt) moveFullLine(ax, fullLine));

function moveFullLine(axList, lineObj)
    % Get cursor x-data position in data units from reference axis
    cp = get(axList(end), 'CurrentPoint');
    xVal = cp(1,1);
    xLim = axList(end).XLim;
    
    if xVal >= xLim(1) && xVal <= xLim(2)
        % Map bottom subplot bounds to normalize figure coordinates [0, 1]
        posBottom = getpixelposition(axList(end));
        posTop    = getpixelposition(axList(1));
        figPos    = getpixelposition(gcf);
        
        % Calculate normalized horizontal ratio
        normX = posBottom(1) + (xVal - xLim(1)) / (xLim(2) - xLim(1)) * posBottom(3);
        normX = normX / figPos(3);
        
        % Normalize vertical span from bottom of fUSi plot to top of TTL 1
        normY_bottom = posBottom(2) / figPos(4);
        normY_top    = (posTop(2) + posTop(4)) / figPos(4);
        
        % Update continuous line position across the entire figure canvas
        set(lineObj, 'X', [normX, normX], 'Y', [normY_bottom, normY_top]);
    end
end