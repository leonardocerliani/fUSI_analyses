%% Add path with all the scripts by Chaoyi

clear; clc;

addpath(genpath('/data08/fUSI/fUSI-Analysis/AnalysisFcn'))


%% SO - Shock Observation

% 1. Load Data Paths & Reference Atlas
conditionName = 'SO';
[subDataPath, subAnatPath, resultPath] = Datapath(conditionName);

% Include cFOS animals if present
[subDataPathc, subAnatPathc, ~] = Datapath('SOcFOS');
subDataPath = cat(1, subDataPath, subDataPathc);
subAnatPath = cat(1, subAnatPath, subAnatPathc);

% Load Allen Brain Atlas reference
load('atlas.mat', 'atlas');

% 2. Build Top-Level Structure Metadata
SO = struct();
SO.metadata = struct();
SO.metadata.condition = conditionName;
SO.metadata.atlasInfo = atlas.infoRegions; % Includes acronyms, names, rgb, volume

% 3. Loop over ALL Subjects
nSubjects = numel(subDataPath);
SO.sessions = cell(nSubjects, 1);

for isub = 1:nSubjects
    fprintf('Processing session %d / %d\n', isub, nSubjects);

    currentDataPath = subDataPath{isub};
    currentAnatPath = subAnatPath{isub};
    
    % Extract subject/session identifier from path
    [~, subID] = fileparts(currentDataPath);
    
    % Load subject's functional data
    tmp = load(fullfile(currentDataPath, 'Functional', 'ROIprepPDI.mat'));
    fn = fieldnames(tmp);
    PDI = tmp.(fn{1});
    
    % Load anatomical data
    anatomicData = load(fullfile(currentAnatPath, 'anatomic.mat'));
    transformData = load(fullfile(currentAnatPath, 'Transformation.mat'));
    
    % --- Time & Frame Computations ---
    fUSI_time = PDI.time(:)'; % Ensure row vector [1 x nFusiFrames]
    dt = mode(diff(fUSI_time));
    samplingRate = 1 / dt;
    
    % Map stimulus start and end times to fUSI frame indices
    [~, onsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.startTime);
    [~, offsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.endTime);
    
    % --- Process Stimulus Conditions ---
    condMat = deblank(PDI.stimInfo.stimCond);
    condMat = strrep(strrep(condMat, '.', ''), ' ', '');
    uniquePredictors = unique(condMat);
    
    nFrames = size(PDI.PDI, 2);
    condStructArray = []; % Reset clean for each subject
    
    for ip = 1:numel(uniquePredictors)
        condName = uniquePredictors{ip};
        trialIndices = find(strcmp(condMat, condName));
        
        % Binary mask initialization (1 = stimulus active, 0 = inactive)
        mask = zeros(1, nFrames);
        
        trialOnsets = onsetFrame(trialIndices);
        trialOffsets = offsetFrame(trialIndices);
        
        for iTrial = 1:numel(trialIndices)
            st = trialOnsets(iTrial);
            en = trialOffsets(iTrial);
            mask(st:en) = 1;
        end
        
        condStructArray(ip).name = condName;
        condStructArray(ip).mask = logical(mask);
        condStructArray(ip).onsetFrames = trialOnsets(:);
        condStructArray(ip).offsetFrames = trialOffsets(:);
        condStructArray(ip).onsetTimes = fUSI_time(trialOnsets)'; % Timestamps aligned to fUSI frame clock
        condStructArray(ip).offsetTimes = fUSI_time(trialOffsets)';
    end
    
    % --- Assemble Session Entry ---
    sessionEntry = struct();
    sessionEntry.subjectID = subID;
    sessionEntry.dataPath = currentDataPath;
    sessionEntry.anatPath = currentAnatPath;
    sessionEntry.time = fUSI_time;
    sessionEntry.dt = dt;
    sessionEntry.samplingRate = samplingRate;
    
    % fUSI time-series matrix [509 x nFusiFrames]
    sessionEntry.fUSI = PDI.PDI;
    
    % Wheel data schema
    sessionEntry.wheel = struct('time', [], 'speed', []);
    if isfield(PDI, 'wheelInfo') && ~isempty(PDI.wheelInfo)
        fprintf('  -> Wheel data found for session %d\n', isub);
        sessionEntry.wheel.time = PDI.wheelInfo.time;
        sessionEntry.wheel.speed = PDI.wheelInfo.wheelspeed;
    end
    
    % Stimulus condition metadata & events
    sessionEntry.stimInfo = struct();
    sessionEntry.stimInfo.uniqueConds = uniquePredictors';
    sessionEntry.stimInfo.cond = condStructArray;
    
    % Store in cell array
    SO.sessions{isub, 1} = sessionEntry;
end

% Saving the struct
save(fullfile(pwd, 'SO_dataset.mat'), 'SO', '-v7.3');

fprintf('SO structure successfully created for all %d subjects!\n', nSubjects);








%% FR - Fear Recall

clear; clc;

% 1. Load Data Paths & Reference Atlas
conditionName = 'FR';
[subDataPath, subAnatPath, resultPath] = Datapath(conditionName);

% Load Allen Brain Atlas reference
load('atlas.mat', 'atlas');

% 2. Build Top-Level Structure Metadata
FR = struct();
FR.metadata = struct();
FR.metadata.condition = conditionName;
FR.metadata.atlasInfo = atlas.infoRegions; % Includes acronyms, names, rgb, volume

% 3. Loop over ALL Subjects
nSubjects = numel(subDataPath);
FR.sessions = cell(nSubjects, 1);

for isub = 1:nSubjects
    fprintf('Processing session %d / %d\n', isub, nSubjects);
    
    currentDataPath = subDataPath{isub};
    currentAnatPath = subAnatPath{isub};
    
    % Extract subject/session identifier from path
    [~, subID] = fileparts(currentDataPath);
    
    % Load subject's functional data
    tmp = load(fullfile(currentDataPath, 'Functional', 'ROIprepPDI.mat'));
    fn = fieldnames(tmp);
    PDI = tmp.(fn{1});
   
    % --- Time & Frame Computations ---
    fUSI_time = PDI.time(:)'; % Ensure row vector [1 x nFusiFrames]
    dt = mode(diff(fUSI_time));
    samplingRate = 1 / dt;
    
    % Map stimulus start and end times to fUSI frame indices
    [~, onsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.startTime);
    [~, offsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.endTime);
    
    % --- Process Stimulus Conditions ---
    condMat = deblank(PDI.stimInfo.stimCond);
    condMat = strrep(strrep(condMat, '.', ''), ' ', '');
    uniquePredictors = unique(condMat);
    
    nFrames = size(PDI.PDI, 2);
    condStructArray = []; % Reset clean for each subject
    
    for ip = 1:numel(uniquePredictors)
        condName = uniquePredictors{ip};
        trialIndices = find(strcmp(condMat, condName));
        
        % Binary mask initialization (1 = stimulus active, 0 = inactive)
        mask = zeros(1, nFrames);
        
        trialOnsets = onsetFrame(trialIndices);
        trialOffsets = offsetFrame(trialIndices);
        
        for iTrial = 1:numel(trialIndices)
            st = trialOnsets(iTrial);
            en = trialOffsets(iTrial);
            mask(st:en) = 1;
        end
        
        condStructArray(ip).name = condName;
        condStructArray(ip).mask = logical(mask);
        condStructArray(ip).onsetFrames = trialOnsets(:);
        condStructArray(ip).offsetFrames = trialOffsets(:);
        condStructArray(ip).onsetTimes = fUSI_time(trialOnsets)'; % Timestamps aligned to fUSI frame clock
        condStructArray(ip).offsetTimes = fUSI_time(trialOffsets)';
    end
    
    % --- Assemble Session Entry ---
    sessionEntry = struct();
    sessionEntry.subjectID = subID;
    sessionEntry.dataPath = currentDataPath;
    sessionEntry.anatPath = currentAnatPath;
    sessionEntry.time = fUSI_time;
    sessionEntry.dt = dt;
    sessionEntry.samplingRate = samplingRate;
    
    % fUSI time-series matrix [509 x nFusiFrames]
    sessionEntry.fUSI = PDI.PDI;
    
    % Wheel data schema
    sessionEntry.wheel = struct('time', [], 'speed', []);
    if isfield(PDI, 'wheelInfo') && ~isempty(PDI.wheelInfo)
        fprintf('  -> Wheel data found for session %d\n', isub);
        sessionEntry.wheel.time = PDI.wheelInfo.time;
        sessionEntry.wheel.speed = PDI.wheelInfo.wheelspeed;
    end
    
    % Stimulus condition metadata & events
    sessionEntry.stimInfo = struct();
    sessionEntry.stimInfo.uniqueConds = uniquePredictors';
    sessionEntry.stimInfo.cond = condStructArray;
    
    % Store in cell array
    FR.sessions{isub, 1} = sessionEntry;
end

% Saving the struct
save(fullfile(pwd, 'FR_dataset.mat'), 'FR', '-v7.3');

fprintf('FR structure successfully created for all %d subjects!\n', nSubjects);


%% SS : Self-Shock

clear; clc;

% 1. Load Data Paths & Reference Atlas
conditionName = 'SS';
[subDataPath, subAnatPath, resultPath] = Datapath(conditionName);

% Load Allen Brain Atlas reference
load('atlas.mat', 'atlas');

% 2. Build Top-Level Structure Metadata
SS = struct();
SS.metadata = struct();
SS.metadata.condition = conditionName;
SS.metadata.atlasInfo = atlas.infoRegions; % Includes acronyms, names, rgb, volume

% 3. Loop over ALL Subjects
nSubjects = numel(subDataPath);
SS.sessions = cell(nSubjects, 1);

for isub = 1:nSubjects
    fprintf('Processing session %d / %d\n', isub, nSubjects);
    
    currentDataPath = subDataPath{isub};
    currentAnatPath = subAnatPath{isub};
    
    % Extract subject/session identifier from path
    [~, subID] = fileparts(currentDataPath);
    
    % Load subject's functional data (Note: roosROIprepPDI.mat for SS)
    tmp = load(fullfile(currentDataPath, 'Functional', 'roosROIprepPDI.mat'));
    fn = fieldnames(tmp);
    PDI = tmp.(fn{1});
   
    % --- Time & Frame Computations ---
    fUSI_time = PDI.time(:)'; % Ensure row vector [1 x nFusiFrames]
    dt = mode(diff(fUSI_time));
    samplingRate = 1 / dt;
    
    % Map stimulus start and end times to fUSI frame indices
    [~, onsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.startTime);
    [~, offsetFrame] = arrayfun(@(x) min(abs(x - fUSI_time)), PDI.stimInfo.endTime);
    
    % --- Filter NaNs & Categorize Shock Intensity Conditions ---
    delivered_mA = deblank(PDI.stimInfo.delivered_mA_);
    
    % Remove NaN trials
    validMask = ~isnan(delivered_mA);
    onsetFrame = onsetFrame(validMask);
    offsetFrame = offsetFrame(validMask);
    delivered_mA = delivered_mA(validMask);
    
    % Categorize into Zero, Low, and High intensity conditions
    condMat = cell(size(delivered_mA));
    condMat(delivered_mA <= 0.01) = {'Zero'};
    condMat(delivered_mA > 0.01 & delivered_mA < 0.3) = {'Low'};
    condMat(delivered_mA >= 0.3) = {'High'};
    
    uniquePredictors = {'Zero'; 'Low'; 'High'};
    
    nFrames = size(PDI.PDI, 2);
    condStructArray = []; % Reset clean for each subject
    
    for ip = 1:numel(uniquePredictors)
        condName = uniquePredictors{ip};
        trialIndices = find(strcmp(condMat, condName));
        
        % Binary mask initialization (1 = stimulus active, 0 = inactive)
        mask = zeros(1, nFrames);
        
        trialOnsets = onsetFrame(trialIndices);
        trialOffsets = offsetFrame(trialIndices);
        
        for iTrial = 1:numel(trialIndices)
            st = trialOnsets(iTrial);
            en = trialOffsets(iTrial);
            mask(st:en) = 1;
        end
        
        condStructArray(ip).name = condName;
        condStructArray(ip).mask = logical(mask);
        condStructArray(ip).onsetFrames = trialOnsets(:);
        condStructArray(ip).offsetFrames = trialOffsets(:);
        condStructArray(ip).onsetTimes = fUSI_time(trialOnsets)'; % Timestamps aligned to fUSI frame clock
        condStructArray(ip).offsetTimes = fUSI_time(trialOffsets)';
    end
    
    % --- Assemble Session Entry ---
    sessionEntry = struct();
    sessionEntry.subjectID = subID;
    sessionEntry.dataPath = currentDataPath;
    sessionEntry.anatPath = currentAnatPath;
    sessionEntry.time = fUSI_time;
    sessionEntry.dt = dt;
    sessionEntry.samplingRate = samplingRate;
    
    % fUSI time-series matrix [509 x nFusiFrames]
    sessionEntry.fUSI = PDI.PDI;
    
    % Wheel data schema
    sessionEntry.wheel = struct('time', [], 'speed', []);
    if isfield(PDI, 'wheelInfo') && ~isempty(PDI.wheelInfo)
        fprintf('  -> Wheel data found for session %d\n', isub);
        sessionEntry.wheel.time = PDI.wheelInfo.time;
        sessionEntry.wheel.speed = PDI.wheelInfo.wheelspeed;
    end
    
    % Stimulus condition metadata & events
    sessionEntry.stimInfo = struct();
    sessionEntry.stimInfo.uniqueConds = uniquePredictors';
    sessionEntry.stimInfo.cond = condStructArray;
    
    % Store in cell array
    SS.sessions{isub, 1} = sessionEntry;
end

fprintf('SS structure successfully created for all %d subjects!\n', nSubjects);

% Save Output Structure
save(fullfile(pwd, 'SS_dataset.mat'), 'SS', '-v7.3');
fprintf('SS dataset successfully saved to %s\n', fullfile(resultPath, 'SS_dataset.mat'));









