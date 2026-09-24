function PDI = functional_reconstruction_V1(datapath, savepath)
% FUNCTIONAL_RECONSTRUCTION Converts raw functional ultrasound imaging (fUSI) data to a MAT structure.
%
%   PDI = FUNCTIONAL_RECONSTRUCTION(datapath, savepath)
%
%   Inputs:
%       datapath - Path to the directory containing raw fUSI binary data,
%                  TTL CSV recordings, NIDAQ logfiles, and stimulation CSVs.
%       savepath - (Optional) Destination folder to save PDI.mat.
%                  Defaults to replacing 'Data_collection' in datapath with 'Data_analysis'.
%
%   Outputs:
%       PDI - Structure containing:
%               .PDI             : Cleaned [nz, nx, nt] functional volume array
%               .Dim             : Dimension metadata (nx, nz, nt, dx, dz, dt)
%               .time            : Frame completion timestamps in seconds, aligned to t = 0 at NIDAQ start
%               .stimInfo        : Extracted event timestamps (drop, touch, shock) relative to NIDAQ start
%               .TTLinfo_CROPPED : Post-experiment-start TTL channel matrix
%               .savepath        : Directory path where PDI.mat was saved
%
%   Description:
%       Loads raw fUSI binary data (`fUS_block_PDI_float.bin`), extracts scan parameters, 
%       and synchronizes fUSI frames with external NIDAQ/TTL trigger channels. 
%       Trims pre-experiment frames, re-zeros timestamps relative to NIDAQ start, and 
%       parses droplet stimulation paradigms.
%
%   Example:
%       PDI = functional_reconstruction('/path/to/Data_collection/session1');
%
%   Version History:
%       V1 : Updated from Rawdata2MATnew_V0_Chaoyi_MOD.m. Added mandatory datapath check, 
%            standardized timing alignment to NIDAQ start (t = 0), and added droplet 
%            stimulation event extraction.

    % % Input Handling and Path Setup
    % % Enforce required datapath argument
    % if nargin < 1 || isempty(datapath)
    %     error('datapath was not provided. Execution terminated.');
    % end
    % 
    % % Derive savepath if not provided or left empty
    % if nargin < 2 || isempty(savepath)
    %     savepath = strrep(datapath, 'Data_collection', 'Data_analysis');
    % end


    
    % ------------ LOCAL ----------------
    datapath='/Users/leonardo/Dropbox/fUSI/data/fUSIHarmAversion/Data_collection/sub-mockexperiment/ses-999999/run-155150-func'
    savepath = strrep(datapath, 'Data_collection', 'Data_analysis');
    fprintf('CAREFUL!!! RUNNING TEST DATA %s.\n', datapath);


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
    %  Reconciles the count of detected TTL pulses and PDI frames by 
    %  truncating whichever array is longer (pdi frames or idx_PDITTL indices).

    idx_PDITTL = find(diff(TTLinfo(:,3)) < 0);
    numidx_PDITTL = numel(idx_PDITTL);
    numPDIframes = size(pdi, 3);

    if numidx_PDITTL < numPDIframes
        pdi(:, :, numidx_PDITTL+1:end) = [];
    elseif numidx_PDITTL > numPDIframes
        idx_PDITTL(numPDIframes+1:end) = [];
    end

    %% Correct for Lagged PDI and Interpolate
    %  Currently breaks, since there are not the original large .bin
    %  in the FUSI_data directory. Therefore timeTagsSec(acceptIndex) is
    %  just a vector of NaN's.
    %  However it should be run anyway since it sets the PDItime variable 
    %  which is used afterwards. 

    try
        [T_pdi_intended, timeTagsSec] = LagAnalysisFusi(fusDatapath);
        close all

        frameInterval = mode(diff(timeTagsSec));
        blockDuration = ceil(1 / frameInterval);
        acceptIndex = true(size(timeTagsSec));

        % Validate block intervals
        for it = 1:numel(timeTagsSec)-blockDuration
            rangeInterval = range(diff(timeTagsSec(it:it+blockDuration)));
            if rangeInterval > 0.01
                acceptIndex(it) = false;
            end
        end
        for it = numel(timeTagsSec)-blockDuration:numel(timeTagsSec)
            rangeInterval = range(diff(timeTagsSec(it-blockDuration:it)));
            if rangeInterval > 0.01
                acceptIndex(it) = false;
            end
        end
        
        % PDItime = TTL time when the fusi frames are acquired.
        % fusi acquisition starts at PDItime(1)
        PDItime = TTLinfo(idx_PDITTL(1), 1) + timeTagsSec(acceptIndex);
        pdi = pdi(:, :, acceptIndex);
    catch
        % If no IQ data exists
        PDItime = TTLinfo(idx_PDITTL, 1);
        blockDuration = mode(diff(PDItime));
    end


    %% Remove All Frames Before Experiment Start & Re-zero Time
    
    % Shift fUSI timestamps by +1 TR (blockDuration) so timestamps represent frame completion
    % (TTL pulse marks frame acquisition start)
    PDItime = PDItime + blockDuration;
    
    % Find NIDAQ start trigger (rising edge in column 6, fallback to col 5)
    idx_NIDAQ_start = find(diff(TTLinfo(:,6)) > 0, 1, 'first');
    if isempty(idx_NIDAQ_start)
        idx_NIDAQ_start = find(diff(TTLinfo(:,5)) > 0, 1, 'first');
    end
    
    if isempty(idx_NIDAQ_start)
        error('No NIDAQ start trigger found in TTLinfo (cols 5/6).');
    end
    
    % Extract absolute start time before modifying TTLinfo
    duration_before_NIDAQ_start = TTLinfo(idx_NIDAQ_start, 1);
    
    % Remove TTL records prior to NIDAQ start
    TTLinfo(1:idx_NIDAQ_start-1, :) = [];
    
    % Shift time vectors so t = 0 corresponds to NIDAQ start
    PDItime = PDItime - duration_before_NIDAQ_start;
    TTLinfo(:,1) = TTLinfo(:,1) - duration_before_NIDAQ_start;
    
    % Discard any fUSI frames acquired prior to t = 0
    validFrames = (PDItime >= 0);
    pdi(:, :, ~validFrames) = [];
    PDItime(~validFrames)   = [];
    
    % Update PDI structure metadata
    PDI.time = PDItime;
    PDI.Dim.dt = blockDuration;
    PDI.Dim.nt = numel(PDItime); % Keep frame count consistent after trimming

    % Review the TTLinfo after removing the time before NIDAQ starts
    % (plot only columns with some information i.e. std ~= 0)
    varyingCols = find(std(TTLinfo) > 0);
    
    figure('Name', 'TTL Channels');
    for i = 1:numel(varyingCols)
        colIdx = varyingCols(i);
        subplot(numel(varyingCols), 1, i);
        plot(TTLinfo(:, 1), TTLinfo(:, colIdx)); 
        title(sprintf('TTL Column %d', colIdx));
        xlabel('Time (s)');
        grid on;
    end




    %% Read Experiment Event Information
    %  Each paradigm is in a different code cell




    %% DropletStimulation
    if exist(fullfile(datapath, 'DropletStimulation.csv'), 'file')
        fprintf('Droplet stimulation found.\n');
        dropTable = readtable(fullfile(datapath, 'DropletStimulation.csv'));
        
        % Initialize structure fields
        PDI.stimInfo.dropTime   = [];
        PDI.stimInfo.touch1     = [];
        PDI.stimInfo.touch2     = [];
        PDI.stimInfo.shockStart = [];
        PDI.stimInfo.shockEnd   = [];
        
        % -------------------------------------------------------------------
        % 1. DROP EVENT (No TTL available -> Software CSV only)
        % -------------------------------------------------------------------
        dropRows = strcmp(dropTable.event, 'drop');
        if any(dropRows)
            PDI.stimInfo.dropTime = dropTable.time(dropRows) - NIDAQInfo.time(1);
        end
        
        % -------------------------------------------------------------------
        % 2. TOUCH 1 (Hardware TTL: Col 10, Rising Edge)
        % -------------------------------------------------------------------
        idx_touch1 = find(diff(TTLinfo(:, 10)) > 0);
        if ~isempty(idx_touch1)
            PDI.stimInfo.touch1 = TTLinfo(idx_touch1, 1);
        else
            % Fallback to CSV
            t1Rows = strcmp(dropTable.event, 'touch1');
            PDI.stimInfo.touch1 = dropTable.time(t1Rows) - NIDAQInfo.time(1);
        end
        
        % -------------------------------------------------------------------
        % 3. TOUCH 2 (Hardware TTL: Col 11, Rising Edge)
        % -------------------------------------------------------------------
        idx_touch2 = find(diff(TTLinfo(:, 11)) > 0);
        if ~isempty(idx_touch2)
            PDI.stimInfo.touch2 = TTLinfo(idx_touch2, 1);
        else
            % Fallback to CSV
            t2Rows = strcmp(dropTable.event, 'touch2');
            PDI.stimInfo.touch2 = dropTable.time(t2Rows) - NIDAQInfo.time(1);
        end
        
        % -------------------------------------------------------------------
        % 4. SHOCK (Hardware TTL: Col 12, Active-Low -> Falling = Start, Rising = End)
        % -------------------------------------------------------------------
        idx_shockStart = find(diff(TTLinfo(:, 12)) < 0);
        idx_shockEnd   = find(diff(TTLinfo(:, 12)) > 0);
        
        if ~isempty(idx_shockStart) && ~isempty(idx_shockEnd)
            PDI.stimInfo.shockStart = TTLinfo(idx_shockStart, 1);
            PDI.stimInfo.shockEnd   = TTLinfo(idx_shockEnd, 1);
        else
            % Fallback to CSV
            shockRows = strcmp(dropTable.event, 'shock');
            PDI.stimInfo.shockStart = dropTable.time(shockRows) - NIDAQInfo.time(1);
            % Note: If CSV does not record shock duration, shockEnd falls back to start times
            PDI.stimInfo.shockEnd   = PDI.stimInfo.shockStart;
        end
    end



    %% Assign Data to PDI Structure

    PDI.PDI = pdi;
    % PDI.pupil.pupilTime = pupilCamTime;
    % PDI.wheelInfo = wheelInfo;
    % PDI.gsensorInfo = gsensorInfo;
    PDI.savepath = savepath;


    % Save also the CROPPED TTLinfo
    PDI.TTLinfo_CROPPED = TTLinfo;

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
