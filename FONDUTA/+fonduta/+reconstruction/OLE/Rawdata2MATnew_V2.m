function PDI = Rawdata2MATnew_V2(datapath, savepath)
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



    %% TMP MANUAL ASSIGNMENT OF datapath and savepath
    datapath='/Users/leonardo/Dropbox/fUSI/fUSI_TUT_NOT_UPDATED_TO_STORM/data/Data_collection/ses-231215/run-115047-func'
    
    savepath = strrep(datapath, 'Data_collection', 'Data_analysis');


    %% Initialize the PDI struct that will be saved
    % This contains both fUSI data, important parameters (e.g. dimensions)
    % as well as the predictors

    PDI = struct;

    %% Locate FUSI Data Directory
    % The raw functional data from the scanner (fUS_block_PDI_float.bin) 
    % **MUST** be contained in a subfolder called FUSI_data. 

    D = dir(fullfile(datapath, 'FUSI_data*'));
    if isempty(D)
        error('No FUSI_data* directory found in the specified datapath.');
    end
    fusDatapath = fullfile(D(1).folder, D(1).name);


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


    %% Load fUSI Scan Parameters (BFConfig)
    % Searches for and loads beamforming configuration parameters (BFConfig) from 
    % the MATLAB scanner metadata file (post_L22-14_PlaneWave_FUSI_data.mat or fallback 
    % L22-14_PlaneWave_FUSI_data.mat) located in 'fusDatapath'.
    %
    % 'BFConfig' contains essential spatial acquisition parameters that
    % will be used to reshape the data from the .bin file in the final 3D
    % version used for analysis.
    %   - BFConfig.Nx / BFConfig.Nz : Image grid dimensions (voxels along X and Z axes).
    %   - BFConfig.ScaleX / ScaleZ : Spatial resolution / pixel sizes (dx, dz in meters).

    scanParamFiles = {'post_L22-14_PlaneWave_FUSI_data.mat', 'L22-14_PlaneWave_FUSI_data.mat'};
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


    %% Write 3D-reshaped fUSI data in PDI
    PDI.Dim.nx = BFConfig.Nx;
    PDI.Dim.nz = BFConfig.Nz;
    PDI.Dim.dx = BFConfig.ScaleX;
    PDI.Dim.dz = BFConfig.ScaleZ;
    PDI.Dim.nt = numel(rawPDI) / (BFConfig.Nx * BFConfig.Nz);

    % Reshape raw PDI data into [nz, nx, nt]
    pdi = reshape(rawPDI, [PDI.Dim.nz, PDI.Dim.nx, PDI.Dim.nt]);
    clear rawPDI;



    %% Read Hardware TTL Timing Matrix (TTL*.csv)
    % Loads the high-frequency hardware signal matrix logged by the NIDAQ board at 5 kHz.
    %
    % Data Details ('TTLinfo' Matrix):
    %   - Column 1 : Master NIDAQ timestamps in seconds.
    %   - Column 3 : PDI frame trigger pulses (falling edges indicate frame completion).
    %   - Column 4, 5, 12 : FUS / Shock / Aux stimulation TTL channels.
    %   - Column 6 (or 5) : Experiment initialization pulse ('initTTL' master zero).
    %   - Column 10 : Default Visual stimulation TTL pulses.
    %   - Column 11 : Default Auditory stimulation TTL pulses.
    ttlFiles = dir(fullfile(datapath, 'TTL*.csv'));
    if ~isempty(ttlFiles)
        fprintf('Loading TTL data from %s.\n', ttlFiles(1).name);
        TTLinfo = readmatrix(fullfile(ttlFiles(1).folder, ttlFiles(1).name));
    else
        error('No TTL recording found. Please check the datapath.');
    end


    %% Realign PDI Volume Count with Hardware Trigger Pulses
    % Detects frame acquisition markers (falling edges on Column 3) in 'TTLinfo'.
    % Reconciles any count mismatch between binary PDI frames loaded from disk ('pdi')
    % and physical TTL pulses recorded by hardware by truncating the longer array.
    PDITTL = find(diff(TTLinfo(:,3)) < 0);
    numPDITTL = numel(PDITTL);
    numPDIframes = size(pdi, 3);
    if numPDITTL < numPDIframes
        pdi(:, :, numPDITTL+1:end) = [];
    elseif numPDITTL > numPDIframes
        PDITTL(numPDIframes+1:end) = [];
    end


    %% Read Software Acquisition Log (NIDAQ.csv / DAQ.csv)
    % Loads the higher-level software event log recorded by the DAQ control program.
    %
    % Data Details ('NIDAQInfo' Table):
    %   - Contains system clock timestamps (e.g., NIDAQInfo.time(1)) marking the exact 
    %     moment the software logging session started.
    %   - Used as a fallback time-zero reference for stimulus CSV files if hardware 
    %     TTL pulses are missing or unrecorded.
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



