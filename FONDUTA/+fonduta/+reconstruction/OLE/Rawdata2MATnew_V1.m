function PDI = Rawdata2MATnew_V1(datapath, savepath)
% RAWDATA2MATNEW Converts raw functional and structural ultrasound imaging data to MAT format.
%
%   PDI = RAWDATA2MATNEW(datapath, savepath)
%
%   Inputs:
%       datapath - (Optional) Path to the raw data directory. If not provided,
%                  a directory selection dialog will appear.
%       savepath - (Optional) Path to save the processed MAT file. If not provided,
%                  it will be generated based on the datapath.
%
%   Outputs:
%       PDI - A structure containing processed PDI data and related information.
%
%   Description:
%       This function reads raw ultrasound imaging data, scan parameters,
%       TTL timing information, and various stimulation event data. It
%       processes and aligns the data, then saves the results in a MAT file.
%
%   Dependencies:
%       - LagAnalysisFusi (function for lag analysis)
%
%   Example:
%       PDI = Rawdata2MATnew('/path/to/datapath', '/path/to/savepath');

    %% Input Handling and Path Setup

    % Select data directory if not provided
    if nargin < 1 || isempty(datapath)
        datapath = uigetdir('\\vs03\VS03-SBL-4\fUSI\', 'Please select the functional scan to analyze.');
        if datapath == 0
            error('Data path selection canceled by user.');
        end
    end

    % Generate save path if not provided
    if nargin < 2 || isempty(savepath)
        tmpInd1 = strfind(datapath, 'Data_collection');
        if isempty(tmpInd1)
            error('The datapath does not contain ''Data_collection''.');
        end
        tmpInd2 = tmpInd1 + length('Data_collection');
        savepath = fullfile(datapath(1:tmpInd1-1), 'Data_analysis', datapath(tmpInd2:end));
    end

    %% Locate FUSI Data Directory

    D = dir(fullfile(datapath, 'FUSI_data*'));
    if isempty(D)
        error('No FUSI_data* directory found in the specified datapath.');
    end
    fusDatapath = fullfile(D(1).folder, D(1).name);

    %% Load Scan Parameters

    scanParamFiles = {'post_L22-14_PlaneWave_FUSI_data.mat', 'L22-14_PlaneWave_FUSI_data.mat'};
    BFConfig = [];
    for i = 1:length(scanParamFiles)
        scanParamPath = fullfile(fusDatapath, scanParamFiles{i});
        if exist(scanParamPath, 'file')
            fprintf('Loading scan parameters from %s.\n', scanParamFiles{i});
            S = load(scanParamPath, 'BFConfig');
            BFConfig = S.BFConfig;
            break;
        end
    end
    if isempty(BFConfig)
        error('No scan parameter file found. Please check the fusDatapath.');
    end

    %% Read Raw PDI Data

    pdiFile = fullfile(fusDatapath, 'fUS_block_PDI_float.bin');
    if exist(pdiFile, 'file')
        fprintf('Loading PDI data from %s.\n', 'fUS_block_PDI_float.bin');
        fid = fopen(pdiFile, 'r');
        rawPDI = fread(fid, inf, 'single');
        fclose(fid);
    else
        error('No PDI data found. Please convert IQ data to PDI first.');
    end

    %% Read TTL Timing Information

    ttlFiles = dir(fullfile(datapath, 'TTL*.csv'));
    if ~isempty(ttlFiles)
        fprintf('Loading TTL data from %s.\n', ttlFiles(1).name);
        TTLinfo = readmatrix(fullfile(ttlFiles(1).folder, ttlFiles(1).name));
    else
        error('No TTL recording found. Please check the datapath.');
    end

    %% Read NIDAQ Logfile

    nidaqFiles = {'NIDAQ.csv', 'DAQ.csv'};
    NIDAQInfo = [];
    for i = 1:length(nidaqFiles)
        nidaqPath = fullfile(datapath, nidaqFiles{i});
        if exist(nidaqPath, 'file')
            fprintf('Loading NIDAQ logfile from %s.\n', nidaqFiles{i});
            NIDAQInfo = readtable(nidaqPath);
            break;
        end
    end
    if isempty(NIDAQInfo)
        error('No NIDAQ logfile found. Please check the datapath.');
    end

    %% Initialize PDI Structure

    PDI = struct;
    PDI.Dim.nx = BFConfig.Nx;
    PDI.Dim.nz = BFConfig.Nz;
    PDI.Dim.dx = BFConfig.ScaleX;
    PDI.Dim.dz = BFConfig.ScaleZ;
    PDI.Dim.nt = numel(rawPDI) / (BFConfig.Nx * BFConfig.Nz);

    % Reshape raw PDI data into [nz, nx, nt]
    pdi = reshape(rawPDI, [PDI.Dim.nz, PDI.Dim.nx, PDI.Dim.nt]);
    clear rawPDI;

    %% Realign Events Using TTL Information

    PDITTL = find(diff(TTLinfo(:,3)) < 0);
    numPDITTL = numel(PDITTL);
    numPDIframes = size(pdi, 3);

    if numPDITTL < numPDIframes
        pdi(:, :, numPDITTL+1:end) = [];
    elseif numPDITTL > numPDIframes
        PDITTL(numPDIframes+1:end) = [];
    end

    %% Correct for Lagged PDI and Interpolate
    % Removed because not working and not necessary    
 

    %% Read Experiment Event Information

    % FUStimulation
    if exist(fullfile(datapath, 'FUStimulation.csv'), 'file')
        fprintf('FUS stimulation found.\n');
        stimInfo = readtable(fullfile(datapath, 'FUStimulation.csv'));
        startTime = TTLinfo(diff(TTLinfo(:,4)) > 0 | diff(TTLinfo(:,5)) > 0 | diff(TTLinfo(:,12)) > 0, 1);
        endTime = TTLinfo(diff(TTLinfo(:,4)) < 0 | diff(TTLinfo(:,5)) < 0 | diff(TTLinfo(:,12)) < 0, 1);
        startTime(startTime < 0.1) = [];
        endTime(endTime < 0.1) = [];
        PDI.stimInfo.stimCond = stimInfo.event(2:end);
        PDI.stimInfo.startTime = startTime;
        PDI.stimInfo.endTime = endTime;
    end

    % ShockStimulation
    if exist(fullfile(datapath, 'ShockStimulation.csv'), 'file')
        fprintf('Shock stimulation found.\n');
        stimInfo = readtable(fullfile(datapath, 'ShockStimulation.csv'));
        if strcmp(stimInfo.event{2}, 'shock_tail')
            startTime = TTLinfo(diff(TTLinfo(:,5)) < 0 | diff(TTLinfo(:,12)) < 0, 1);
            endTime = TTLinfo(diff(TTLinfo(:,5)) > 0 | diff(TTLinfo(:,12)) > 0, 1);
            startTime(startTime < 0.1) = [];
            endTime(endTime < 0.1) = [];
            shockInfo = readtable(fullfile(datapath, 'shockIntensities_and_perceivedSqueaks.xlsx'));
            PDI.stimInfo = addvars(shockInfo, stimInfo.event(2:end), 'Before', 1, 'NewVariableNames', 'stimCond');
            PDI.stimInfo = addvars(PDI.stimInfo, startTime, 'Before', 2, 'NewVariableNames', 'startTime');
            PDI.stimInfo = addvars(PDI.stimInfo, endTime, 'Before', 3, 'NewVariableNames', 'endTime');
        else
            startTime = TTLinfo(diff(TTLinfo(:,4)) < 0 | diff(TTLinfo(:,12)) < 0, 1);
            endTime = TTLinfo(diff(TTLinfo(:,4)) > 0 | diff(TTLinfo(:,12)) > 0, 1);
            PDI.stimInfo.startTime = startTime;
            PDI.stimInfo.endTime = endTime;
            PDI.stimInfo.stimCond = stimInfo.event(2:end);
            PDI.stimInfo.stimCond = strrep(PDI.stimInfo.stimCond, 'shock_left', 'shockOBS');
            PDI.stimInfo.stimCond = strrep(PDI.stimInfo.stimCond, 'shock_right', 'shockCTL');
        end
    end

    % VisualStimulation
    if exist(fullfile(datapath, 'VisualStimulation.csv'), 'file')
        fprintf('Visual stimulation found.\n');
        stimInfo = readtable(fullfile(datapath, 'VisualStimulation.csv'));
        PDI.stimInfo.startTime = TTLinfo(diff(TTLinfo(:,10)) > 0, 1);
        PDI.stimInfo.endTime = TTLinfo(diff(TTLinfo(:,10)) < 0, 1);
        stimDuration = PDI.stimInfo.endTime - PDI.stimInfo.startTime;
        validStim = stimDuration >= 0.01;
        PDI.stimInfo.startTime = PDI.stimInfo.startTime(validStim);
        PDI.stimInfo.endTime = PDI.stimInfo.endTime(validStim);
        PDI.stimInfo.stimCond = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);

        if isempty(PDI.stimInfo.startTime)
            stimInfo.time = stimInfo.time - NIDAQInfo.time(1);
            PDI.stimInfo.startTime = stimInfo.time(strcmp('stim', stimInfo.event));
            PDI.stimInfo.endTime = stimInfo.time(strcmp('blank', stimInfo.event));
            PDI.stimInfo.stimCond = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);
        end
    end

    % AudioStimulation
    if exist(fullfile(datapath, 'AudioStimulation.csv'), 'file')
        fprintf('Auditory stimulation found.\n');
        stimInfo = readtable(fullfile(datapath, 'AudioStimulation.csv'));
        PDI.stimInfo.startTime = TTLinfo(diff(TTLinfo(:,11)) > 0, 1);
        PDI.stimInfo.endTime = TTLinfo(diff(TTLinfo(:,11)) < 0, 1);
        PDI.stimInfo.stimCond = stimInfo.event(strcmp('audio', stimInfo.event));

        if isempty(PDI.stimInfo.startTime)
            stimInfo.time = stimInfo.time - NIDAQInfo.time(1);
            PDI.stimInfo.startTime = stimInfo.time(strcmp('audio', stimInfo.event));
            PDI.stimInfo.endTime = PDI.stimInfo.startTime + stimInfo.duration(strcmp('audio', stimInfo.event));
            PDI.stimInfo.stimCond = stimInfo.event(strcmp('audio', stimInfo.event));
        end

        PDI.stimInfo.stimCond = strrep(PDI.stimInfo.stimCond, 'audio', 'CS');
    end

    % Pupil Camera Data
    if exist(fullfile(datapath, 'pupil_camera.csv'), 'file')
        fprintf('Loading pupil camera timestamp from pupil_camera.csv.\n');
        pupilCamData = readmatrix(fullfile(datapath, 'pupil_camera.csv'));
        pupilCamTime = pupilCamData(:,1) - NIDAQInfo.time(1);
    else
        pupilCamTime = [];
        warning('No video timestamp of flir_camera found!');
    end

    % Running Wheel Data
    if exist(fullfile(datapath, 'RunningWheel.csv'), 'file')
        fprintf('Running wheel data found.\n');
        wheelInfo = readtable(fullfile(datapath, 'RunningWheel.csv'));
        wheelInfo.time = wheelInfo.time - NIDAQInfo.time(1);
        % Uncomment below to compute wheel speed aligned with PDI time
        % wheelSpeed = interp1(wheelInfo.time, abs(wheelInfo.wheelspeed), PDItime, 'nearest', 'extrap');
    else
        wheelInfo = [];
        warning('No running wheel data found!');
    end

    % GSensor Data
    if exist(fullfile(datapath, 'GSensor.csv'), 'file')
        fprintf('G sensor data found.\n');
        gsensorInfo = readtable(fullfile(datapath, 'GSensor.csv'));
        gsensorInfo.time = gsensorInfo.time - NIDAQInfo.time(1);
        % Uncomment below to compute motion aligned with PDI time
        % gmotion.x = interp1(gsensorInfo.time, abs(gsensorInfo.x), PDItime, 'nearest', 'extrap');
        % gmotion.y = interp1(gsensorInfo.time, abs(gsensorInfo.y), PDItime, 'nearest', 'extrap');
        % gmotion.z = interp1(gsensorInfo.time, abs(gsensorInfo.z), PDItime, 'nearest', 'extrap');
    else
        gsensorInfo = [];
        warning('No GSensor data found!');
    end

    %% Assign Data to PDI Structure

    PDI.PDI = pdi;
    PDI.pupil.pupilTime = pupilCamTime;
    PDI.wheelInfo = wheelInfo;
    PDI.gsensorInfo = gsensorInfo;
    PDI.savepath = savepath;

    %% Save PDI Structure

    % Ensure the save directory exists
    if ~exist(savepath, 'dir')
        mkdir(savepath);
    end

    % Save the PDI structure
    matFilePath = fullfile(savepath, 'PDI.mat');
    save(matFilePath, 'PDI');
    fprintf('Data is saved to: %s\n', matFilePath);

    % Uncomment below to save in MATLAB v7 format for compatibility with scipy.io.loadmat
    % save(fullfile(savepath, 'pyPDI.mat'), '-struct', 'PDI', '-v7');

end





%% THIS PART WAS WRITTEN BY ME TO CHECK THE VISUAL STIMULUS TIMING OF THE 
%% CSV WITH THE INFO IN TTLINFO

% NB: the **primary** source for stimulus timing is the ttlinfo, while the
% csv is a fallback. This means that the logic has been written inside out.
% Only if the csv is found, the timing is extracted from the ttlinfo, which
% does not make any sense.

% VisualStimulation
if exist(fullfile(datapath, 'VisualStimulation.csv'), 'file')
    fprintf('Visual stimulation found.\n');
    stimInfo = readtable(fullfile(datapath, 'VisualStimulation.csv'));
    PDI.stimInfo.startTime = TTLinfo(diff(TTLinfo(:,10)) > 0, 1);
    PDI.stimInfo.endTime = TTLinfo(diff(TTLinfo(:,10)) < 0, 1);
    stimDuration = PDI.stimInfo.endTime - PDI.stimInfo.startTime;
    validStim = stimDuration >= 0.01;
    PDI.stimInfo.startTime = PDI.stimInfo.startTime(validStim);
    PDI.stimInfo.endTime = PDI.stimInfo.endTime(validStim);
    PDI.stimInfo.stimCond = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);

    if isempty(PDI.stimInfo.startTime)
        stimInfo.time = stimInfo.time - NIDAQInfo.time(1);
        PDI.stimInfo.startTime = stimInfo.time(strcmp('stim', stimInfo.event));
        PDI.stimInfo.endTime = stimInfo.time(strcmp('blank', stimInfo.event));
        PDI.stimInfo.stimCond = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);
    end
end




%% Assumes PDI, TTLinfo, and NIDAQInfo are in workspace
stimChannel = 10; 

% 1. Locate Zero Reference (initTTL)
initTTL = find(diff(TTLinfo(:,6)) > 0, 1);
if isempty(initTTL)
    initTTL = find(diff(TTLinfo(:,5)) > 0, 1);
end

% The global offset between NIDAQ clock zero and initTTL start
nidaqToInitOffset = TTLinfo(initTTL, 1) - TTLinfo(1, 1);

% 2. Hardware TTL Timestamps (Zeroed to initTTL)
ttlTime = TTLinfo(:,1) - TTLinfo(initTTL, 1);

ttlStart = ttlTime(find(diff(TTLinfo(:, stimChannel)) > 0) + 1);
ttlEnd   = ttlTime(find(diff(TTLinfo(:, stimChannel)) < 0) + 1);

validPulse = (ttlEnd - ttlStart) >= 0.01;
ttlStart = ttlStart(validPulse);
ttlEnd   = ttlEnd(validPulse);

% 3. Adjust PDI / CSV Timestamps if they used NIDAQInfo fallback
pdiStart = PDI.stimInfo.startTime;
pdiEnd   = PDI.stimInfo.endTime;

% If PDI timestamps were computed relative to NIDAQInfo.time(1), align them to initTTL
if exist('NIDAQInfo', 'var') && ~isempty(NIDAQInfo)
    % Shift PDI timestamps to align with initTTL
    pdiStart_aligned = pdiStart - nidaqToInitOffset;
    pdiEnd_aligned   = pdiEnd - nidaqToInitOffset;
else
    pdiStart_aligned = pdiStart;
    pdiEnd_aligned   = pdiEnd;
end

% 4. Compare
nEvents = min([numel(ttlStart), numel(pdiStart_aligned)]);
ttlStart = ttlStart(1:nEvents);
ttlEnd   = ttlEnd(1:nEvents);
pdiStart_aligned = pdiStart_aligned(1:nEvents);
pdiEnd_aligned   = pdiEnd_aligned(1:nEvents);

startDiffMs = (ttlStart - pdiStart_aligned) * 1000;
endDiffMs   = (ttlEnd - pdiEnd_aligned) * 1000;

% Construct Output Table
eventID = (1:nEvents)';
comparisonTable = table(eventID, ttlStart, pdiStart_aligned, startDiffMs, ttlEnd, pdiEnd_aligned, endDiffMs, ...
    'VariableNames', {'Event', 'TTL_Start_s', 'PDI_Start_Aligned_s', 'Start_Diff_ms', 'TTL_End_s', 'PDI_End_Aligned_s', 'End_Diff_ms'});

disp(comparisonTable);

% 5. Plot Residual Differences
figure('Name', 'Aligned Stimulus Timing Check', 'Color', 'w');

subplot(2,1,1);
plot(1:nEvents, startDiffMs, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
ylabel('Start Offset (ms)');
xlabel('Event #');
title('Residual Start Offset (TTL vs CSV Aligned)');
grid on;

subplot(2,1,2);
plot(1:nEvents, endDiffMs, '-s', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
ylabel('End Offset (ms)');
xlabel('Event #');
title('Residual End Offset (TTL vs CSV Aligned)');
grid on;

%% HOW TIMING IN STIMINFO GETS CONVERTED TO FRAMES
% 1. Initialize a blank predictor (3652 frames x 1)
numFrames = PDI.Dim.nt; % 3652
predictor = zeros(numFrames, 1);

% 2. Loop through each stimulus event and find matching frame ranges
for i = 1:numel(PDI.stimInfo.startTime)
    st = PDI.stimInfo.startTime(i);
    et = PDI.stimInfo.endTime(i);
    
    % Find the frame indices closest in time to 'st' and 'et'
    [~, startFrame] = min(abs(PDI.time - st));
    [~, endFrame]   = min(abs(PDI.time - et));
    
    % Set the predictor to 1 for all frames during the stimulus
    predictor(startFrame:endFrame) = 1;
end