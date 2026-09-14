function PDI = functional_reconstruction(datapath, savepath)
% Based on OLE/Rawdata2MATnew_V5
%
% RAWDATA2MATNEW Converts raw functional ultrasound imaging (fUSI) data into 
% MAT format and extracts behavioural signals (e.g. wheelspeed) as well as
% stimulus timing (e.g. visual or auditory stimuli)
% 
%
% USAGE:
%   PDI = Rawdata2MATnew(datapath, savepath)
%   PDI = Rawdata2MATnew('/path/to/Data_collection/ses-01/run-01')
%
% INPUTS:
%   datapath - String. Path to the experimental data collection directory.
%              If empty or omitted, opens an interactive directory picker UI.
%   savepath - String. Path to save output PDI.mat file. If omitted, automatically
%              infers savepath by replacing 'Data_collection' with 'Data_analysis'.
%
% OUTPUTS:
%   PDI      - Output structure saved as 'PDI.mat' containing reshaped 3D fUSI
%              power Doppler data (pdi), spatial dimensions (Dim), configuration
%              parameters (cfg), and synchronized behavioral/stimulus events.
%
% REQUIRED INPUT FILES IN DATAPATH:
%   - experiment_config.json
%     Configuration file defining acquisition thresholds, target file patterns, 
%     and mappings for optional stimuli and behavioral recordings.
%
%   - fUS_block_PDI_float.bin (located inside 'FUSI_data*' folder)
%     Raw binary float file containing unshaped 1D power Doppler intensity (PDI) 
%     data streamed directly from the fUSI scanner.
%
%   - post_L22-14_PlaneWave_FUSI_data.mat OR L22-14_PlaneWave_FUSI_data.mat
%     MATLAB scanner metadata file containing beamforming configurations (BFConfig). 
%     Provides grid dimensions (Nx, Nz) and spatial resolutions (ScaleX, ScaleZ) 
%     used to reshape the 1D binary PDI stream into a 3D matrix [Nz x Nx x Nt].
%
%   - TTL*.csv
%     High-frequency (5 kHz) hardware signal matrix logged by NIDAQ. Used to detect 
%     falling edges on the frame acquisition channel to align fUSI volume counts, 
%     and to extract exact hardware onset/offset timing for stimuli via assigned channels.
%
%   - NIDAQ.csv OR DAQ.csv
%     Software acquisition log recorded by the DAQ program. Contains system clock 
%     timestamps marking the start of logging session (NIDAQInfo.time(1)), serving as 
%     a time-zero reference and timestamp fallback when hardware TTL channels are unused.
%

    %% Input Handling and Path Setup
    if nargin < 1 || isempty(datapath)
        datapath = uigetdir('\\vs03\VS03-SBL-4\fUSI\', 'Please select the functional scan to analyze.');
        if isequal(datapath, 0)
            error('Data path selection canceled by user.');
        end
    end

    if nargin < 2 || isempty(savepath)
        tmpInd1 = strfind(datapath, 'Data_collection');
        if isempty(tmpInd1)
            error('The datapath does not contain ''Data_collection''.');
        end
        tmpInd2 = tmpInd1 + length('Data_collection');
        savepath = fullfile(datapath(1:tmpInd1-1), 'Data_analysis', datapath(tmpInd2:end));
    end


    % %% TMP MANUAL ASSIGNMENT OF datapath and savepath - ONLY FOR DEV INTERACTIVE TEST
    % % datapath='/Users/leonardo/Dropbox/fUSI/fUSI_TUT_NOT_UPDATED_TO_STORM/data/Data_collection/ses-231215/run-115047-func'
    % datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'
    % 
    % savepath = strrep(datapath, 'Data_collection', 'Data_analysis');


    %% Load Configuration File
    configPath = fullfile(datapath, 'experiment_config.json');
    if exist(configPath, 'file')
        cfg = jsondecode(fileread(configPath));
    else
        error('Configuration file missing: %s', configPath);
    end

    %% Initialize the PDI struct that will be saved
    % This contains both fUSI data, important parameters (e.g. dimensions)
    % as well as the predictors
    
    PDI = struct;
    PDI.cfg = cfg;


    %% Locate FUSI Data Directory
    % The raw functional data from the scanner (fUS_block_PDI_float.bin) 
    % **MUST** be contained in a subfolder called FUSI_data. 

    D = dir(fullfile(datapath, cfg.file_names.fusi_folder_pattern));
    if isempty(D)
        error('No directory matching ''%s'' found in %s.', cfg.file_names.fusi_folder_pattern, datapath);
    end
    fusDatapath = fullfile(D(1).folder, D(1).name);

    %% Read Raw PDI Data
    % The rawPDI from the bin is one-dimensional. It will be reshaped to 3D
    % using the info about the scan parameters in the following chunk.
    pdiFile = fullfile(fusDatapath, cfg.file_names.pdi_binary);
    if exist(pdiFile, 'file')
        fprintf('Loading PDI data from %s.\n', cfg.file_names.pdi_binary);
        fid = fopen(pdiFile, 'r');
        rawPDI = fread(fid, inf, 'single');
        fclose(fid);
    else
        error('No PDI binary file found at %s.', pdiFile);
    end

    %% Read fUSI Scan Parameters (BFConfig)
    % Searches for and loads beamforming configuration parameters (BFConfig) from 
    % the MATLAB scanner metadata file (post_L22-14_PlaneWave_FUSI_data.mat or fallback 
    % L22-14_PlaneWave_FUSI_data.mat) located in 'fusDatapath'.
    %
    % 'BFConfig' contains essential spatial acquisition parameters that
    % will be used to reshape the data from the .bin file in the final 3D
    % version used for analysis.
    %   - BFConfig.Nx / BFConfig.Nz : Image grid dimensions (voxels along X and Z axes).
    %   - BFConfig.ScaleX / ScaleZ : Spatial resolution / pixel sizes (dx, dz in meters).

    scanParamFiles = cfg.file_names.scan_params;
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
        error('No valid scan parameter file found in %s.', fusDatapath);
    end

    %% Reshape PDI Data 1D -> 3D
    PDI.Dim.nx = BFConfig.Nx;
    PDI.Dim.nz = BFConfig.Nz;
    PDI.Dim.dx = BFConfig.ScaleX;
    PDI.Dim.dz = BFConfig.ScaleZ;
    PDI.Dim.nt = numel(rawPDI) / (BFConfig.Nx * BFConfig.Nz);

    pdi = reshape(rawPDI, [PDI.Dim.nz, PDI.Dim.nx, PDI.Dim.nt]);
    clear rawPDI;

    %% Read Hardware TTL Timing Matrix (TTL*.csv)
    % Loads the high-frequency hardware signal matrix logged by the NIDAQ board at 5 kHz.
    % Details about the channel content in the experiment_config.json file
    ttlFiles = dir(fullfile(datapath, cfg.file_names.ttl_pattern));
    if ~isempty(ttlFiles)
        fprintf('Loading TTL data from %s.\n', ttlFiles(1).name);
        TTLinfo = readmatrix(fullfile(ttlFiles(1).folder, ttlFiles(1).name));
    else
        error('No TTL recording files found matching ''%s''.', cfg.file_names.ttl_pattern);
    end

    %% Realign PDI Volume Count with Hardware Trigger Pulses
    % Detects frame acquisition markers (falling edges on Column 3) in 'TTLinfo'.
    % Reconciles any count mismatch between binary PDI frames loaded from disk ('pdi')
    % and physical TTL pulses recorded by hardware by truncating the longer array.
    pdiFrameChan = cfg.processing_parameters.pdi_frame_channel;
    PDITTL = find(diff(TTLinfo(:, pdiFrameChan)) < 0);
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
    nidaqFiles = cfg.file_names.nidaq_log;
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
        error('No NIDAQ software log found in %s.', datapath);
    end

    %% Correct for Lagged PDI and Interpolate
    % Removed because not working and not necessary    

    %% Explicit Processing of Stimuli & Behaviour
    minTimestamp = cfg.processing_parameters.min_event_timestamp_sec;
    minDuration  = cfg.processing_parameters.min_stim_duration_sec;

    % --- 1. FUS Stimuli ---
    if isfield(cfg.stimuli, 'fus_stimuli')
        fusCfg = cfg.stimuli.fus_stimuli;
        csvPath = fullfile(datapath, fusCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing FUS stimulation...\n');
            stimInfo = readtable(csvPath);
            chans = fusCfg.TTL_channel';
            
            onsetMask  = false(size(TTLinfo,1)-1, 1);
            offsetMask = false(size(TTLinfo,1)-1, 1);
            for c = chans
                if c <= size(TTLinfo, 2)
                    onsetMask  = onsetMask  | (diff(TTLinfo(:, c)) > 0);
                    offsetMask = offsetMask | (diff(TTLinfo(:, c)) < 0);
                end
            end
            
            startTime = TTLinfo(find(onsetMask), 1);
            endTime   = TTLinfo(find(offsetMask), 1);
            startTime(startTime < minTimestamp) = [];
            endTime(endTime < minTimestamp)     = [];

            PDI.stimInfo.stimCond  = stimInfo.event(2:end);
            PDI.stimInfo.startTime = startTime;
            PDI.stimInfo.endTime   = endTime;
        end
    end

    
    % --- 2. Shock Tail Stimuli ---
    if isfield(cfg.stimuli, 'shock_tail_stimuli')
        stCfg = cfg.stimuli.shock_tail_stimuli;
        csvPath = fullfile(datapath, stCfg.csv_filename);
        excelPath = fullfile(datapath, stCfg.metadata_excel);
        if exist(csvPath, 'file') && exist(excelPath, 'file')
            fprintf('Processing Shock Tail stimulation...\n');
            stimInfo = readtable(csvPath);
            if strcmp(stimInfo.event{2}, 'shock_tail')
                chans = stCfg.TTL_channel';
                onsetMask  = false(size(TTLinfo,1)-1, 1);
                offsetMask = false(size(TTLinfo,1)-1, 1);
                for c = chans
                    if c <= size(TTLinfo, 2)
                        onsetMask  = onsetMask  | (diff(TTLinfo(:, c)) < 0);
                        offsetMask = offsetMask | (diff(TTLinfo(:, c)) > 0);
                    end
                end
                startTime = TTLinfo(find(onsetMask), 1);
                endTime   = TTLinfo(find(offsetMask), 1);
                startTime(startTime < minTimestamp) = [];
                endTime(endTime < minTimestamp)     = [];

                shockInfo = readtable(excelPath);
                PDI.stimInfo = addvars(shockInfo, stimInfo.event(2:end), 'Before', 1, 'NewVariableNames', 'stimCond');
                PDI.stimInfo = addvars(PDI.stimInfo, startTime, 'Before', 2, 'NewVariableNames', 'startTime');
                PDI.stimInfo = addvars(PDI.stimInfo, endTime, 'Before', 3, 'NewVariableNames', 'endTime');
            end
        end
    end


    % --- 3. Shock Paw Stimuli ---
    if isfield(cfg.stimuli, 'shock_paw_stimuli')
        spCfg = cfg.stimuli.shock_paw_stimuli;
        csvPath = fullfile(datapath, spCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing Shock Paw stimulation...\n');
            stimInfo = readtable(csvPath);
            if ~strcmp(stimInfo.event{2}, 'shock_tail')
                chans = spCfg.TTL_channel';
                onsetMask  = false(size(TTLinfo,1)-1, 1);
                offsetMask = false(size(TTLinfo,1)-1, 1);
                for c = chans
                    if c <= size(TTLinfo, 2)
                        onsetMask  = onsetMask  | (diff(TTLinfo(:, c)) < 0);
                        offsetMask = offsetMask | (diff(TTLinfo(:, c)) > 0);
                    end
                end
                PDI.stimInfo.startTime = TTLinfo(find(onsetMask), 1);
                PDI.stimInfo.endTime   = TTLinfo(find(offsetMask), 1);
                PDI.stimInfo.stimCond  = stimInfo.event(2:end);
                PDI.stimInfo.stimCond  = strrep(PDI.stimInfo.stimCond, 'shock_left', 'shockOBS');
                PDI.stimInfo.stimCond  = strrep(PDI.stimInfo.stimCond, 'shock_right', 'shockCTL');
            end
        end
    end


    % --- 4. Visual Stimuli ---
    if isfield(cfg.stimuli, 'visual_stimuli')
        visCfg = cfg.stimuli.visual_stimuli;
        csvPath = fullfile(datapath, visCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing Visual stimulation...\n');
            stimInfo = readtable(csvPath);
            
            % Attempt hardware TTL extraction if channel exists
            if isfield(visCfg, 'TTL_channel') && visCfg.TTL_channel <= size(TTLinfo, 2)
                vChan = visCfg.TTL_channel;
                PDI.stimInfo.startTime = TTLinfo(diff(TTLinfo(:, vChan)) > 0, 1);
                PDI.stimInfo.endTime   = TTLinfo(diff(TTLinfo(:, vChan)) < 0, 1);
                
                stimDuration = PDI.stimInfo.endTime - PDI.stimInfo.startTime;
                validStim    = stimDuration >= minDuration;
                PDI.stimInfo.startTime = PDI.stimInfo.startTime(validStim);
                PDI.stimInfo.endTime   = PDI.stimInfo.endTime(validStim);
                PDI.stimInfo.stimCond  = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);
            end

            % Fallback to software NIDAQ log timestamps if TTL extraction was empty
            if ~isfield(PDI, 'stimInfo') || ~isfield(PDI.stimInfo, 'startTime') || isempty(PDI.stimInfo.startTime)
                stimInfo.time = stimInfo.time - NIDAQInfo.time(1);
                PDI.stimInfo.startTime = stimInfo.time(strcmp('stim', stimInfo.event));
                PDI.stimInfo.endTime   = stimInfo.time(strcmp('blank', stimInfo.event));
                PDI.stimInfo.stimCond  = repmat({'visual'}, numel(PDI.stimInfo.startTime), 1);
            end
        end
    end



    % --- 5. Audio / USV Stimuli ---
    if isfield(cfg.stimuli, 'audio_USV_stimuli')
        audCfg = cfg.stimuli.audio_USV_stimuli;
        csvPath = fullfile(datapath, audCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing Audio/USV stimulation...\n');
            stimInfo = readtable(csvPath);
            
            if isfield(audCfg, 'TTL_channel') && audCfg.TTL_channel <= size(TTLinfo, 2)
                aChan = audCfg.TTL_channel;
                PDI.stimInfo.startTime = TTLinfo(diff(TTLinfo(:, aChan)) > 0, 1);
                PDI.stimInfo.endTime   = TTLinfo(diff(TTLinfo(:, aChan)) < 0, 1);
                PDI.stimInfo.stimCond  = stimInfo.event(strcmp('audio', stimInfo.event));
            end

            if ~isfield(PDI, 'stimInfo') || ~isfield(PDI.stimInfo, 'startTime') || isempty(PDI.stimInfo.startTime)
                stimInfo.time = stimInfo.time - NIDAQInfo.time(1);
                PDI.stimInfo.startTime = stimInfo.time(strcmp('audio', stimInfo.event));
                PDI.stimInfo.endTime   = PDI.stimInfo.startTime + stimInfo.duration(strcmp('audio', stimInfo.event));
                PDI.stimInfo.stimCond  = stimInfo.event(strcmp('audio', stimInfo.event));
            end
            PDI.stimInfo.stimCond = strrep(PDI.stimInfo.stimCond, 'audio', 'CS');
        end
    end


    % --- 6. Droplet Stimuli & Behavior ---
    if isfield(cfg.stimuli, 'droplet_stimuli')
        dropCfg = cfg.stimuli.droplet_stimuli;
        csvPath = fullfile(datapath, dropCfg.csv_filename);
        
        if exist(csvPath, 'file')
            fprintf('Processing Droplet stimulation & behavior...\n');
            dropTable = readtable(csvPath);
            
            % -------------------------------------------------------------
            % EXTRACT HARDWARE TTL TIMESTAMPS (Pure NIDAQ Clock)
            % -------------------------------------------------------------
            % Hardware Task Launch Trigger (Col 5)
            startPulseIdx = find(diff(TTLinfo(:, 5)) ~= 0, 1, 'first');
            hardwareTaskStart = TTLinfo(startPulseIdx, 1);
            
            % Touch 1 (Col 10): Rising edge
            touch1_onset = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
            
            % Touch 2 (Col 11): Rising edge
            touch2_onset = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
            
            % Shock (Col 12): Active-low signal -> Falling edge marks trigger
            shock_onset = TTLinfo(diff(TTLinfo(:, 12)) < 0, 1);
            
            % Filter hardware timestamps by minimum experimental threshold if defined
            if exist('minTimestamp', 'var')
                touch1_onset(touch1_onset < minTimestamp) = [];
                touch2_onset(touch2_onset < minTimestamp) = [];
                shock_onset(shock_onset < minTimestamp)   = [];
            end
            
            % -------------------------------------------------------------
            % ALIGN CSV 'DROP' EVENTS VIA CHANNEL 5 HARDWARE START
            % -------------------------------------------------------------
            % Calculate session-specific offset between NIDAQ arming and Task launch
            csvStartRelative = dropTable.time(1) - NIDAQInfo.time(1);
            timeOffset = hardwareTaskStart - csvStartRelative;
            
            % Map software-only 'drop' events directly to NIDAQ hardware clock
            dropRows = dropTable(strcmp(dropTable.event, 'drop'), :);
            drop_onset = (dropRows.time - NIDAQInfo.time(1)) + timeOffset;
            
            % -------------------------------------------------------------
            % PACK SEPARATE PREDICTOR TABLES INTO PDI.stimInfo
            % -------------------------------------------------------------
            % 1. Drop Predictor Table
            PDI.stimInfo.dropInfo = table();
            PDI.stimInfo.dropInfo.stimCond  = repmat({'drop'}, numel(drop_onset), 1);
            PDI.stimInfo.dropInfo.startTime = drop_onset;
            PDI.stimInfo.dropInfo.endTime   = drop_onset;
            
            % 2. Touch 1 Predictor Table (Shock-paired)
            PDI.stimInfo.touch1Info = table();
            PDI.stimInfo.touch1Info.stimCond  = repmat({'touch1'}, numel(touch1_onset), 1);
            PDI.stimInfo.touch1Info.startTime = touch1_onset;
            PDI.stimInfo.touch1Info.endTime   = touch1_onset;
            
            % 3. Touch 2 Predictor Table (Safe)
            PDI.stimInfo.touch2Info = table();
            PDI.stimInfo.touch2Info.stimCond  = repmat({'touch2'}, numel(touch2_onset), 1);
            PDI.stimInfo.touch2Info.startTime = touch2_onset;
            PDI.stimInfo.touch2Info.endTime   = touch2_onset;
            
            % 4. Shock Predictor Table
            PDI.stimInfo.shockInfo = table();
            PDI.stimInfo.shockInfo.stimCond  = repmat({'shock'}, numel(shock_onset), 1);
            PDI.stimInfo.shockInfo.startTime = shock_onset;
            PDI.stimInfo.shockInfo.endTime   = shock_onset;
            
            % Store alignment metadata for reference
            PDI.stimInfo.UserData.timeOffset = timeOffset;
            PDI.stimInfo.UserData.hardwareTaskStart = hardwareTaskStart;
        end
    end





    
    % --- 7. Pupil Camera ---
    if isfield(cfg.behaviour, 'pupil_camera')
        pupilCfg = cfg.behaviour.pupil_camera;
        csvPath = fullfile(datapath, pupilCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing Pupil Camera timestamps...\n');
            pupilCamData = readmatrix(csvPath);
            PDI.pupil.pupilTime = pupilCamData(:, 1) - NIDAQInfo.time(1);
        end
    end

    % --- 8. Running Wheel ---
    if isfield(cfg.behaviour, 'running_wheel')
        wheelCfg = cfg.behaviour.running_wheel;
        csvPath = fullfile(datapath, wheelCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing Running Wheel data...\n');
            wheelInfo = readtable(csvPath);
            wheelInfo.time = wheelInfo.time - NIDAQInfo.time(1);
            PDI.wheelInfo = wheelInfo;
        end
    end

    % --- 9. GSensor ---
    if isfield(cfg.behaviour, 'gsensor')
        gsenCfg = cfg.behaviour.gsensor;
        csvPath = fullfile(datapath, gsenCfg.csv_filename);
        if exist(csvPath, 'file')
            fprintf('Processing GSensor data...\n');
            gsensorInfo = readtable(csvPath);
            gsensorInfo.time = gsensorInfo.time - NIDAQInfo.time(1);
            PDI.gsensorInfo = gsensorInfo;
        end
    end

    %% Finalize & Save Struct
    PDI.PDI = pdi;
    PDI.savepath = savepath;

    if ~exist(savepath, 'dir')
        mkdir(savepath);
    end

    matFilePath = fullfile(savepath, 'PDI.mat');
    save(matFilePath, 'PDI');
    fprintf('Data successfully saved to: %s\n', matFilePath);
end

