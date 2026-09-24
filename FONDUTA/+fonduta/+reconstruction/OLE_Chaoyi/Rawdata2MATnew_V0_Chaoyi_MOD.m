function PDI = Rawdata2MATnew_V0_Chaoyi(datapath, savepath)
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

    % % Select data directory if not provided
    % if nargin < 1 || isempty(datapath)
    %     datapath = uigetdir('\\vs03\VS03-SBL-4\fUSI\', 'Please select the functional scan to analyze.');
    %     if datapath == 0
    %         error('Data path selection canceled by user.');
    %     end
    % end
    % 
    % % Generate save path if not provided
    % if nargin < 2 || isempty(savepath)
    %     tmpInd1 = strfind(datapath, 'Data_collection');
    %     if isempty(tmpInd1)
    %         error('The datapath does not contain ''Data_collection''.');
    %     end
    %     tmpInd2 = tmpInd1 + length('Data_collection');
    %     savepath = fullfile(datapath(1:tmpInd1-1), 'Data_analysis', datapath(tmpInd2:end));
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

    PDITTL = find(diff(TTLinfo(:,3)) < 0);
    numPDITTL = numel(PDITTL);
    numPDIframes = size(pdi, 3);

    if numPDITTL < numPDIframes
        pdi(:, :, numPDITTL+1:end) = [];
    elseif numPDITTL > numPDIframes
        PDITTL(numPDIframes+1:end) = [];
    end

    %% Correct for Lagged PDI and Interpolate

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

        PDItime = TTLinfo(PDITTL(1), 1) + timeTagsSec(acceptIndex);
        pdi = pdi(:, :, acceptIndex);
    catch
        % If no IQ data exists
        PDItime = TTLinfo(PDITTL, 1);
        blockDuration = mode(diff(PDItime));
    end


    %% Remove all frames before the start of the experiment

    % Adjust PDItime
    PDItime = PDItime + mean(diff(PDItime)); % PDI TTL marks the start of an acquisition

    % Align TTLinfo
    initTTL = find(diff(TTLinfo(:,6)) > 0);
    if isempty(initTTL)
        initTTL = find(diff(TTLinfo(:,5)) > 0);
    end
    TTLinfo(1:initTTL-1, :) = [];
    PDItime = PDItime - TTLinfo(1,1);
    TTLinfo(:,1) = TTLinfo(:,1) - TTLinfo(1,1);

    % Remove PDI frames with negative time
    validFrames = PDItime >= 0;
    pdi(:, :, ~validFrames) = [];
    PDItime(~validFrames) = [];

    PDI.time = PDItime;
    PDI.Dim.dt = blockDuration;

    % Review the TTLinfo after cropping
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
