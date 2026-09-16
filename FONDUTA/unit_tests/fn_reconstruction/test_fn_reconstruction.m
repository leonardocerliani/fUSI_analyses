%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

%%

% cerliani@storm:/data03/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999$ tree
% .
% ├── run-142930-anat
% │   ├── DAQ.csv
% │   ├── FUSI_data
% │   │   ├── fUS_block_PDI_float.bin
% │   │   ├── L22-14_PlaneWave_FUSI_data.mat
% │   │   └── post_L22-14_PlaneWave_FUSI_data.mat
% │   ├── FUS_SCAN
% │   ├── Scan.csv
% │   ├── settings.json
% │   └── TTL20260908T142915.csv
% └── run-155150-func
%     ├── DAQ.csv
%     ├── DropletStimulation.csv
%     ├── experiment_config.json
%     ├── FUS_EXPERIMENT
%     ├── FUSI_data
%     │   ├── fUS_block_PDI_float.bin
%     │   ├── L22-14_PlaneWave_FUSI_data.mat
%     │   └── post_L22-14_PlaneWave_FUSI_data.mat
%     ├── notes_channels.txt
%     ├── settings.json
%     ├── __SUCCESS
%     ├── Touchsensor.csv
%     └── TTL20260908T155016.csv

% help fonduta.reconstruction.functional_reconstruction


%% Test Visual from methods paper
experiment_root_folder = '/data03/fUSIMethodsPaper_LC'
fn_collection_path='Data_collection/sub-methods02/ses-231215/run-115047/';
datapath = fullfile(experiment_root_folder, fn_collection_path)

fonduta.reconstruction.functional_reconstruction(datapath)

% % Load the generated PDI for inspection
% PDI = load('/data03/fUSIMethodsPaper_LC/Data_analysis/sub-methods02/ses-231215/run-115047/PDI.mat').PDI


%% Test Droplets mock scan
experiment_root_folder = '/data03/fUSIHarmAversion';
fn_collection_path='/Data_collection/sub-mockexperiment/ses-999999/run-155150-func';
datapath = fullfile(experiment_root_folder, fn_collection_path)

fonduta.reconstruction.functional_reconstruction(datapath)

% % Load the generated PDI for inspection
% PDI = load('/data03/fUSIHarmAversion/Data_analysis/sub-mockexperiment/ses-999999/run-155150-func/PDI.mat').PDI



%% EXTRA CHECK FOR DROPLET PARADIGM

% The plot below shows the alignment of the shock artifact with the shock
% stimulus, providing a convincing test of the correct alignment carried
% out in the reconstruction script.
% To do the plot, we need to have all the variables internally created in 
% functional_reconstruction(datapath), therefore we should open it an
% execute it manually after having defined the datapath

datapath='/data03/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'

open fonduta.reconstruction.functional_reconstruction
% Now execute all the code inside, then execute the next cell to get the
% plot that verifies that everything is temporally aligned


%% Visualization of fUSI Signal & Behavioral Events Highlighting the artifact ---
figure('Color', 'w', 'Position', [100 100 1200 600]);

% -------------------------------------------------------------------------
% 0. RESHAPE PDI vox-by-time AND TAKE THE MEAN/MEDIAN
%    TO HIGHLIGHT THE SHOCK ARTIFACT ON FUSI SIGNAL
% -------------------------------------------------------------------------

pdi2d = reshape(PDI.PDI, [PDI.Dim.nx * PDI.Dim.nz, PDI.Dim.nt]);
% imagesc(pdi2d); colormap gray
% plot(median(pdi2d, 1))

% -------------------------------------------------------------------------
% 1. TIME VECTOR & SIGNAL NORMALIZATION (% dS/S)
% -------------------------------------------------------------------------
frameChan = cfg.processing_parameters.pdi_frame_channel;
if exist('TTLinfo', 'var') && size(TTLinfo, 2) >= frameChan
    fusiTime = TTLinfo(diff(TTLinfo(:, frameChan)) > 0, 1);
    if numel(fusiTime) ~= size(pdi2d, 2)
        fusiTime = linspace(TTLinfo(1,1), TTLinfo(end,1), size(pdi2d, 2));
    end
else
    fusiTime = 1:size(pdi2d, 2);
end

rawSignal = median(pdi2d, 1);
% Calculate % Change from baseline (using 5th percentile as S0)
s0 = prctile(rawSignal, 5); 
fusiSignal_dS = ((rawSignal - s0) / s0) * 100; 

% -------------------------------------------------------------------------
% 2. DRAW SHOCK ARTIFACT SHADING BACKGROUND
% -------------------------------------------------------------------------
hold on
c_shock = [0.4940 0.1840 0.5560]; % Purple

yLimits = [min(fusiSignal_dS)-2, max(fusiSignal_dS)+5];

if isfield(PDI.stimInfo, 'shockInfo') && ~isempty(PDI.stimInfo.shockInfo)
    shockStarts = PDI.stimInfo.shockInfo.startTime;
    shockDuration = 1.5; % 1.5s highlight window
    
    for s = 1:numel(shockStarts)
        x_patch = [shockStarts(s), shockStarts(s)+shockDuration, shockStarts(s)+shockDuration, shockStarts(s)];
        y_patch = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
        
        if s == 1
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Shock Window');
        else
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end
end

% -------------------------------------------------------------------------
% 3. PLOT CONTINUOUS fUSI SIGNAL (Left Y-Axis)
% -------------------------------------------------------------------------
yyaxis left

% plot(fusiTime, fusiSignal_dS, 'Color', [0.15 0.15 0.15 0.5], 'LineWidth', 1.1, 'DisplayName', 'fUSI Signal (% \DeltaS/S_0)');
plot(fusiTime, fusiSignal_dS, 'Color', [0.00 0.45 0.74 0.9], 'LineWidth', 1.1, 'DisplayName', 'fUSI Signal (% \DeltaS/S_0)');

ylabel('% \DeltaS/S_0');
ylim(yLimits);
ax = gca;
ax.YColor = [0.15 0.15 0.15];

% -------------------------------------------------------------------------
% 4. PLOT DISCRETE EVENTS (Right Y-Axis)
% -------------------------------------------------------------------------
yyaxis right
ylabel('Behavioral Events');
ax.YColor = 'k';

y_drop = 1;
y_t1   = 2;
y_t2   = 3;

c_drop = [0.8500 0.3250 0.0980]; % Orange
c_t1   = [0.6350 0.0780 0.1840]; % Red (Touch 1)
c_t2   = [0.4660 0.6740 0.1880]; % Green (Touch 2)

if isfield(PDI.stimInfo, 'dropInfo') && ~isempty(PDI.stimInfo.dropInfo)
    stem(PDI.stimInfo.dropInfo.startTime, repmat(y_drop, height(PDI.stimInfo.dropInfo), 1), ...
        'Color', c_drop, 'Marker', 'v', 'MarkerFaceColor', c_drop, 'LineWidth', 1.2, 'DisplayName', 'Drop');
end

if isfield(PDI.stimInfo, 'touch1Info') && ~isempty(PDI.stimInfo.touch1Info)
    stem(PDI.stimInfo.touch1Info.startTime, repmat(y_t1, height(PDI.stimInfo.touch1Info), 1), ...
        'Color', c_t1, 'Marker', 'o', 'MarkerFaceColor', c_t1, 'LineWidth', 1.2, 'DisplayName', 'Touch 1');
end

if isfield(PDI.stimInfo, 'touch2Info') && ~isempty(PDI.stimInfo.touch2Info)
    stem(PDI.stimInfo.touch2Info.startTime, repmat(y_t2, height(PDI.stimInfo.touch2Info), 1), ...
        'Color', c_t2, 'Marker', '^', 'MarkerFaceColor', c_t2, 'LineWidth', 1.2, 'DisplayName', 'Touch 2');
end

% Position markers cleanly above signal
ylim([-2 4]); 
yticks([y_drop, y_t1, y_t2]);
yticklabels({'Drop', 'Touch 1', 'Touch 2'});

% % Uncomment the line below to plot only when there is fusi signal
% xlim([min(fusiTime), max(fusiTime)]);

% -------------------------------------------------------------------------
% 5. FORMATTING & LEGEND
% -------------------------------------------------------------------------
xlabel('Hardware Timestamp (NIDAQ s)');
title('fUSI Signal Timeline with Shock Artifact Verification');
grid on;
box off;
legend('Location', 'southoutside', 'Orientation', 'horizontal');


hold off;














