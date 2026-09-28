%% single sub
% Load dataset
data = load('SO_peristimulus_dataset.mat');
psthStruct = data.SO_peristimulus;

roiIdx = 145; % Specific Allen ROI index
isub = 1;   % Subject index
ic = 1;     % Condition index ('shockCTL')

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




%% group level
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
