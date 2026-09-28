function extract_peristimulus_dataset(matFilePath, preStimSec, postStimSec, signalType)
% EXTRACT_PERISTIMULUS_DATASET Extracts peri-stimulus timecourses for fUSI data.
%
% Usage:
%   extract_peristimulus_dataset('SO_dataset.mat', 5, 15)                % Defaults to 'fUSI_clean'
%   extract_peristimulus_dataset('FR_dataset.mat', 5, 15, 'fUSI_clean')
%   extract_peristimulus_dataset('SS_dataset.mat', 5, 15, 'fUSI')

    % 1. Set Defaults
    if nargin < 2 || isempty(preStimSec),  preStimSec = 5; end
    if nargin < 3 || isempty(postStimSec), postStimSec = 15; end
    if nargin < 4 || isempty(signalType),  signalType = 'fUSI_clean'; end

    % 2. Validate input file
    if ~exist(matFilePath, 'file')
        error('File "%s" not found.', matFilePath);
    end

    fprintf('Loading %s for peri-stimulus extraction...\n', matFilePath);
    loadedData = load(matFilePath);
    
    structNames = fieldnames(loadedData);
    datasetName = structNames{1};
    dataset = loadedData.(datasetName);
    
    % Use sampling rate and dt from the first session (assumed uniform)
    dt = dataset.sessions{1}.dt;
    samplingRate = dataset.sessions{1}.samplingRate;
    
    % Compute frame counts relative to onset
    preFrames = round(preStimSec * samplingRate);
    postFrames = round(postStimSec * samplingRate);
    frameOffsets = -preFrames : postFrames; % Frame relative indices
    nPSTHFrames = numel(frameOffsets);
    timeVec = frameOffsets * dt;          % Relative time vector in seconds
    
    % 3. Build Top-Level Output Structure
    outStruct = struct();
    outStruct.metadata = struct();
    outStruct.metadata.condition    = dataset.metadata.condition;
    outStruct.metadata.signalSource = signalType;
    outStruct.metadata.preStimSec   = preStimSec;
    outStruct.metadata.postStimSec  = postStimSec;
    outStruct.metadata.preFrames    = preFrames;
    outStruct.metadata.postFrames   = postFrames;
    outStruct.metadata.nPSTHFrames  = nPSTHFrames;
    outStruct.metadata.timeVec      = timeVec;
    outStruct.metadata.atlasInfo    = dataset.metadata.atlasInfo;
    
    nSessions = numel(dataset.sessions);
    outStruct.sessions = cell(nSessions, 1);
    
    % 4. Loop across all subjects/sessions
    for isub = 1:nSessions
        subData = dataset.sessions{isub};
        fprintf('Extracting peristimulus from session %d / %d...\n', isub, nSessions);
        
        % Validate requested signal presence
        if ~isfield(subData, signalType)
            error('Field "%s" not found in session %d. Run clean_fusi_data first or select "fUSI".', signalType, isub);
        end
        
        signalData = subData.(signalType); % [509 x nFusiFrames]
        [nRoi, totalFrames] = size(signalData);
        
        % Build session entry
        sessionEntry = struct();
        sessionEntry.subjectID = subData.subjectID;
        sessionEntry.dataPath  = subData.dataPath;
        sessionEntry.anatPath  = subData.anatPath;
        
        nConds = numel(subData.stimInfo.cond);
        periCondArray = struct([]);
        
        for ic = 1:nConds
            cond = subData.stimInfo.cond(ic);
            onsets = cond.onsetFrames(:);
            nTrials = numel(onsets);
            
            % Preallocate tensor: [509 x nPSTHFrames x nTrials]
            trialTensor = nan(nRoi, nPSTHFrames, nTrials);
            
            for iTrial = 1:nTrials
                onsetIdx = onsets(iTrial);
                
                % Skip invalid or NaN onsets
                if isnan(onsetIdx) || onsetIdx < 1
                    continue;
                end
                
                targetFrames = onsetIdx + frameOffsets;
                
                % Handle potential boundary out-of-bounds with NaN padding
                validTargetMask = targetFrames >= 1 & targetFrames <= totalFrames;
                validFrames = targetFrames(validTargetMask);
                
                if ~isempty(validFrames)
                    % Explicitly index all 3 dimensions (ROIs, timePoints, trial)
                    trialTensor(1:nRoi, validTargetMask, iTrial) = signalData(1:nRoi, validFrames);
                end
            end
            
            % Store condition peri-signal struct
            periCondArray(ic).condName    = cond.name;
            periCondArray(ic).signal      = trialTensor;
            periCondArray(ic).nTrials     = nTrials;
            periCondArray(ic).trialOnsets = onsets;
        end
        
        sessionEntry.periSignal = periCondArray;
        outStruct.sessions{isub, 1} = sessionEntry;
    end
    
    % 5. Save output file (e.g. SO_peristimulus_dataset.mat)
    outFileName = sprintf('%s_peristimulus_dataset.mat', dataset.metadata.condition);
    outFilePath = fullfile(fileparts(matFilePath), outFileName);
    
    % Wrap dynamic variable name for saving
    S = struct();
    S.(sprintf('%s_peristimulus', dataset.metadata.condition)) = outStruct;
    
    save(outFilePath, '-struct', 'S', '-v7.3');
    fprintf('Successfully saved PSTH dataset to %s!\n', outFilePath);
end