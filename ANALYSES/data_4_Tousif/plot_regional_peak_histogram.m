function sortedTable = plot_regional_peak_histogram(psthFilePath, condIdx, topN)
% PLOT_REGIONAL_PEAK_HISTOGRAM Computes and plots mean peak fUSI responses across ROIs.
%
% Usage:
%   sortedTable = plot_regional_peak_histogram('SS_peristimulus_dataset.mat');
%   sortedTable = plot_regional_peak_histogram('SO_peristimulus_dataset.mat', 1, 30); % Plot top 30 ROIs

    if nargin < 2 || isempty(condIdx), condIdx = 1; end
    if nargin < 3 || isempty(topN),    topN = 25; end % Default top N ROIs to display

    % 1. Load PSTH Dataset
    if ~exist(psthFilePath, 'file')
        error('File "%s" not found.', psthFilePath);
    end
    
    fprintf('Loading %s...\n', psthFilePath);
    loadedData = load(psthFilePath);
    structNames = fieldnames(loadedData);
    psthStruct = loadedData.(structNames{1});
    
    metadata = psthStruct.metadata;
    sessions = psthStruct.sessions;
    nSessions = numel(sessions);
    atlas = metadata.atlasInfo;
    
    condName = sessions{1}.periSignal(condIdx).condName;
    nRoi = size(sessions{1}.periSignal(condIdx).signal, 1);
    
    % 2. Extract Max Response per Subject and ROI
    subjectPeaks = nan(nRoi, nSessions);
    
    for isub = 1:nSessions
        % [509 x nPSTHFrames x nTrials]
        signalTensor = sessions{isub}.periSignal(condIdx).signal;
        
        % Average across trials for this subject -> [509 x nPSTHFrames]
        meanPSTH = mean(signalTensor, 3, 'omitnan');
        
        % Find peak (maximum value) across post-onset PSTH timeframes (t >= 0)
        postOnsetMask = metadata.timeVec >= 0;
        postOnsetSignal = meanPSTH(:, postOnsetMask);
        
        % Max response per ROI for this subject
        subjectPeaks(:, isub) = max(postOnsetSignal, [], 2, 'omitnan');
    end
    
    % 3. Aggregate across Subjects
    meanPeaks = mean(subjectPeaks, 2, 'omitnan');
    semPeaks  = std(subjectPeaks, 0, 2, 'omitnan') / sqrt(nSessions);
    
    % Filter out empty/NaN regions (outside FOV)
    validRoiMask = ~isnan(meanPeaks);
    validIndices = find(validRoiMask);
    
    validMeanPeaks = meanPeaks(validIndices);
    validSemPeaks  = semPeaks(validIndices);
    validAcronyms  = atlas.acr(validIndices);
    validNames     = atlas.name(validIndices);
    
    % 4. Rank/Sort ROIs by Mean Peak Magnitude (Descending)
    [sortedPeaks, sortIdx] = sort(validMeanPeaks, 'descend');
    sortedSem      = validSemPeaks(sortIdx);
    sortedRoiIdx   = validIndices(sortIdx);
    sortedAcronyms = validAcronyms(sortIdx);
    sortedNames    = validNames(sortIdx);
    
    % Ensure column vectors
    sortedRoiIdx   = sortedRoiIdx(:);
    sortedAcronyms = sortedAcronyms(:);
    sortedNames    = sortedNames(:);
    sortedPeaks    = sortedPeaks(:);
    sortedSem      = sortedSem(:);
    
    % Build full summary table for ALL valid ROIs
    sortedTable = table(sortedRoiIdx, sortedAcronyms, sortedNames, sortedPeaks, sortedSem, ...
                        'VariableNames', {'ROI_Index', 'Acronym', 'Region_Name', 'Mean_Peak', 'SEM_Peak'});
                    
    % 5. Select Top N ROIs for Display
    nPlot = min(topN, numel(sortedPeaks));
    
    % Reverse order for horizontal plotting (so #1 rank sits at the top of the y-axis)
    plotPeaks    = sortedPeaks(nPlot:-1:1);
    plotSem      = sortedSem(nPlot:-1:1);
    plotAcronyms = sortedAcronyms(nPlot:-1:1);
    
    % 6. Plot Horizontal Bar Chart
    figure('Color', 'w', 'Position', [150, 100, 700, 800]);
    
    % Horizontal Bars
    b = barh(1:nPlot, plotPeaks, 'FaceColor', [0.2 0.45 0.75], 'EdgeColor', 'none'); hold on;
    
    % Horizontal Error Bars (using errorbar with xneg/xpos)
    errorbar(plotPeaks, 1:nPlot, plotSem, 'horizontal', 'k.', 'LineWidth', 1, 'CapSize', 3);
    
    % Formatting
    yticks(1:nPlot);
    yticklabels(plotAcronyms);
    ylabel('Allen Brain Regions');
    xlabel('Mean Peak Response');
    title(sprintf('Top %d Responsive Regions (%s - %s)', ...
          nPlot, metadata.condition, condName), 'Interpreter', 'none');
      
    xline(0, 'k--', 'LineWidth', 0.8);
    grid on;
    set(gca, 'FontSize', 10);
    
    fprintf('\n=== Top 10 Most Responsive ROIs for %s (%s) ===\n', metadata.condition, condName);
    disp(sortedTable(1:min(10, numel(sortedPeaks)), :));
end