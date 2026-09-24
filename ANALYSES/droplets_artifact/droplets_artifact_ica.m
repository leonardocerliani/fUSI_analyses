%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

%% Reconstruction
experiment_root_folder = '/data03/fUSIHarmAversion';
fn_collection_path='/Data_collection/sub-mockexperiment/ses-999999/run-155150-func';
datapath = fullfile(experiment_root_folder, fn_collection_path)

savepath = strrep(datapath, 'Data_collection', 'Data_analysis');

fonduta.reconstruction.functional_reconstruction(datapath, savepath)


%% Plot mean fusi signal and events
figHandle = figure('Color', 'w', 'Position', [100 100 500 150], 'Name', 'fUSI Signal Timeline');
hold on

%% Mean fusi signal
PDI = load(fullfile(savepath, "PDI.mat")).PDI;

nVoxels = size(PDI.PDI, 1) * size(PDI.PDI, 2);
pdi2d = reshape(PDI.PDI, [nVoxels, size(PDI.PDI, 3)]);
% imagesc(pdi2d); colormap gray

rawSignal = median(pdi2d, 1);
s0 = prctile(rawSignal, 5); 
if s0 == 0; s0 = eps; end
fusiSignal_dS = ((rawSignal - s0) / s0) * 100;
plot(PDI.time, fusiSignal_dS)


%% Shock windows
c_shock = [0.4940 0.1840 0.5560]; % Purple
yLimits = [min(fusiSignal_dS)-2, max(fusiSignal_dS)+5];

time_offset = 97.158;

if isfield(PDI, 'stimInfo') && isfield(PDI.stimInfo, 'shockInfo') && ~isempty(PDI.stimInfo.shockInfo)
    shockStarts = PDI.stimInfo.shockInfo.startTime;
    shockDuration = 1.5;
    
    for s = 1:numel(shockStarts)
        s_start = shockStarts(s) - time_offset;
        x_patch = [s_start, s_start+shockDuration, s_start+shockDuration, s_start];
        y_patch = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
        
        if s == 1
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Shock Window');
        else
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end
end


%% Other events
yyaxis right
ylabel('Behavioral Events');
ax.YColor = 'k';

y_drop = 1; y_t1 = 2; y_t2 = 3;
c_drop = [0.8500 0.3250 0.0980]; % Orange
c_t1   = [0.6350 0.0780 0.1840]; % Red (Touch 1)
c_t2   = [0.4660 0.6740 0.1880]; % Green (Touch 2)

stem(PDI.stimInfo.dropInfo.startTime - time_offset, repmat(y_drop, height(PDI.stimInfo.dropInfo), 1), ...
    'Color', c_drop, 'Marker', 'v', 'MarkerFaceColor', c_drop, 'LineWidth', 1.2, 'DisplayName', 'Drop');

stem(PDI.stimInfo.touch1Info.startTime - time_offset, repmat(y_t1, height(PDI.stimInfo.touch1Info), 1), ...
    'Color', c_t1, 'Marker', 'o', 'MarkerFaceColor', c_t1, 'LineWidth', 1.2, 'DisplayName', 'Touch 1');

stem(PDI.stimInfo.touch2Info.startTime - time_offset, repmat(y_t2, height(PDI.stimInfo.touch2Info), 1), ...
    'Color', c_t2, 'Marker', '^', 'MarkerFaceColor', c_t2, 'LineWidth', 1.2, 'DisplayName', 'Touch 2');


ylim([-2 4]); 
yticks([y_drop, y_t1, y_t2]);
yticklabels({'Drop', 'Touch 1', 'Touch 2'});


%% Formatting and legend
xlabel('Hardware Timestamp (NIDAQ s)');
title('fUSI Signal Timeline with Shock Artifact Verification');
grid on;
box off;
legend('Location', 'southoutside', 'Orientation', 'horizontal');
hold off;




