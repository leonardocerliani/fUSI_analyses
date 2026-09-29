function plot_fusi_onsets(matFilePath, isub, signalType)
% PLOT_FUSI_ONSETS Plots mean fUSI signal and stimulus onsets across all conditions.
%
% Usage:
%   plot_fusi_onsets('SO_dataset.mat', 5)               % Defaults to raw 'fUSI'
%   plot_fusi_onsets('SO_dataset.mat', 5, 'fUSI')         % Explicitly raw 'fUSI'
%   plot_fusi_onsets('SO_dataset.mat', 5, 'fUSI_clean')   % Cleaned 'fUSI_clean'

    % Set default signalType if not provided
    if nargin < 3 || isempty(signalType)
        signalType = 'fUSI';
    end

    % 1. Load the dataset file dynamically
    if ~exist(matFilePath, 'file')
        error('File "%s" not found. Please provide a valid path.', matFilePath);
    end
    
    fprintf('Loading %s...\n', matFilePath);
    loadedData = load(matFilePath);
    
    % Extract top-level struct (handles 'SO', 'FR', 'SS', etc.)
    structNames = fieldnames(loadedData);
    dataStruct = loadedData.(structNames{1});
    
    % 2. Validate subject index
    if isub > numel(dataStruct.sessions) || isub < 1
        error('Invalid subject index isub = %d. Dataset contains %d subjects.', isub, numel(dataStruct.sessions));
    end
    
    % 3. Extract subject data and requested signal field
    subData = dataStruct.sessions{isub};
    
    if ~isfield(subData, signalType)
        error('Field "%s" not found in session %d. Run clean_fusi_data first if requesting clean data.', signalType, isub);
    end
    
    signalData = subData.(signalType);
    meanSignal = mean(signalData, 1, 'omitnan'); % Average signal across 509 ROIs
    nFrames = length(meanSignal);
    
    % 4. Create Figure
    figure('Color', 'w');
    plot(1:nFrames, meanSignal, 'k-', 'LineWidth', 1, 'DisplayName', sprintf('Mean %s Signal', signalType));
    hold on;
    
    % 5. Plot Stem Onsets for All Conditions
    nConds = numel(subData.stimInfo.cond);
    colors = lines(nConds); % Distinct color per condition
    stemMax = max(meanSignal, [], 'omitnan') * 1.05;
    
    for ic = 1:nConds
        cond = subData.stimInfo.cond(ic);
        onsets = cond.onsetFrames;
        
        if ~isempty(onsets)
            stem(onsets, repmat(stemMax, size(onsets)), ...
                'Color', colors(ic, :), 'MarkerFaceColor', colors(ic, :), ...
                'LineWidth', 1.2, 'DisplayName', sprintf('%s Onsets', cond.name));
        end
    end
    
    hold off;
    
    % 6. Formatting & Annotations
    xlabel('fUSI Frame Index');
    ylabel(sprintf('Mean %s Signal', signalType));
    title(sprintf('%s Mean Timecourse & Stimulus Onsets (%s - Subject %d: %s)', ...
          signalType, dataStruct.metadata.condition, isub, subData.subjectID), 'Interpreter', 'none');
    legend('Location', 'best');
    grid on;
end