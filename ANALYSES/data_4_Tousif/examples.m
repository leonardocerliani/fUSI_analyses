%% Examples for using the [paradigm]_dataset.mat 
%  SO is used in these examples. FR and SS should also work fine.
%  It is assumed that the relevant cells in 
%  `prepare_dataset_4_extraction.m` have already been evaluated.

%  Inspect the struct created by evaluating the SO cell in 
%  `prepare_dataset_4_extraction.m`
root = pwd;
SO = load(fullfile(root, 'SO_dataset.mat')).SO;


%% Regress wheel speed from the fusi signal
clean_fusi_dataset(fullfile(root, 'SO_dataset.mat'));

% Reload the dataset to see the new field SO.sessions{isub}.fUSI_clean. 
SO = load(fullfile(root, 'SO_dataset.mat')).SO;

% Plot the mean signal (over the entire image) and the onsets
% for one subject.
% (I thought it would have been more informative)
isub = 1
plot_fusi_onsets('SO_dataset.mat', isub, 'fUSI_clean');


%% Extract peristimulus timecourses with given time range
pre_onset_sec = 5
post_offset_sec = 15
extract_peristimulus_dataset('SO_dataset.mat', ...
    pre_onset_sec, post_offset_sec, 'fUSI_clean');



%% View the peristimulus time course for on region across subjects
%  NB: not all subjects might have signal in a given ROI.

data = load('SO_peristimulus_dataset.mat');
psthStruct = data.SO_peristimulus;

nsubs = length(psthStruct.sessions);

roiIdx = 94; % Specific Allen ROI index
roiName = psthStruct.metadata.atlasInfo.name(roiIdx);
ic = 1;     % Condition index ('shockCTL')

figure
nrows = 5
tiledlayout(nrows,ceil(nsubs/nrows), 'TileSpacing','compact', 'Padding','compact')

for isub=1:nsubs
    
    nexttile
    tc = squeeze(psthStruct.sessions{isub}.periSignal(ic).signal(roiIdx, :,:)); 
    imagesc(tc');
    title(sprintf('sub %d',isub))
    xlabel('fusi frames')
    ylabel('trials')
    
end

sgtitle(roiName)


%% Single subj mean signal change across trials in one ROI

data = load('SO_peristimulus_dataset.mat');
psthStruct = data.SO_peristimulus;

roiIdx = 145; % Specific Allen ROI index
isub = 1;   % Subject index
ic = 2;     % Condition index ('shockCTL')

% Extract tensor: [509 x 101 x nTrials] -> [101 x nTrials]
roiTrials = squeeze(psthStruct.sessions{isub}.periSignal(ic).signal(roiIdx, :, :));
timeVec   = psthStruct.metadata.timeVec;

% Compute Mean and SEM across trials
meanTrace = mean(roiTrials, 2, 'omitnan');
semTrace  = std(roiTrials, 0, 2, 'omitnan') / sqrt(size(roiTrials, 2));

% Plot mean PSTH response with shaded error bar
figure('Color', 'w');
plot(timeVec, roiTrials, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5); hold on;
plot(timeVec, meanTrace, 'k-', 'LineWidth', 2, 'DisplayName', 'Mean Response');
xline(0, 'r--', 'Stimulus Onset', 'LineWidth', 1.2);
xlabel('Time from Onset (s)');
ylabel('fUSI Signal Change');
title(sprintf('ROI %d PSTH - Subject %s (%s)', roiIdx, ...
      psthStruct.sessions{isub}.subjectID, ...
      psthStruct.sessions{isub}.periSignal(ic).condName), 'Interpreter', 'none');
grid on;




%% Signal change in an ROI across subjects
%  NB: not all subjects might have signal in a given ROI.

% Load PSTH dataset
data = load('SO_peristimulus_dataset.mat');
psthStruct = data.SO_peristimulus;

roiIdx = 145; % Region index to plot
timeVec = psthStruct.metadata.timeVec;
nConds = numel(psthStruct.sessions{1}.periSignal);

figure('Color', 'w'); hold on;
colors = lines(nConds);

for ic = 1:nConds
    % Concatenate trials from all subjects into a single matrix [101 x totalTrials]
    allSubjectTrials = cellfun(@(s) squeeze(s.periSignal(ic).signal(roiIdx, :, :)), ...
                               psthStruct.sessions, 'UniformOutput', false);
    grandTrialMatrix = cat(2, allSubjectTrials{:});
    
    % Grand Mean and SEM
    grandMean = mean(grandTrialMatrix, 2, 'omitnan');
    grandSEM  = std(grandTrialMatrix, 0, 2, 'omitnan') / sqrt(size(grandTrialMatrix, 2));
    
    % Plot grand mean PSTH
    condName = psthStruct.sessions{1}.periSignal(ic).condName;
    plot(timeVec, grandMean, 'Color', colors(ic, :), 'LineWidth', 2, ...
         'DisplayName', sprintf('%s (N=%d trials)', condName, size(grandTrialMatrix, 2)));
end

xline(0, 'k--', 'Stimulus Onset', 'LineWidth', 1.2);
xlabel('Time from Onset (s)');
ylabel('fUSI Signal Change');
title(sprintf('Grand Average PSTH across Subjects (ROI #%d)', roiIdx));
legend('Location', 'best');
grid on;
