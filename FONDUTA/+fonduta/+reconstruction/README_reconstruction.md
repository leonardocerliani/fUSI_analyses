# Functional reconstruction

A typical functional scan returns many files, like in the following example from a mock scan with the Droplet paradigm.

Generic, i.e. for all paradigms:
- `TTL*.csv`
- `L22-14_PlaneWave_FUSI_data.mat`
- `fUS_block_PDI_float.bin`
- `post_L22-14_PlaneWave_FUSI_data.mat`

Paradigm specific:
- `DropletStimulation.csv`
- `Touchsensor.csv` 

```
sub-mockexperiment/
└── ses-999999
    └── run-155150-func
        ├── DAQ.csv
        ├── DropletStimulation.csv
        ├── FUSI_data
        │   ├── L22-14_PlaneWave_FUSI_data.mat
        │   ├── fUS_block_PDI_float.bin
        │   └── post_L22-14_PlaneWave_FUSI_data.mat
        ├── FUS_EXPERIMENT
        ├── TTL20260908T155016.csv
        ├── Touchsensor.csv
        └── settings.json
```

## Time synchronization between fusi and behavioural events

The fusi signal is (in the current setting) acquired on TTL channel 3. In order to synchronize the behavioural events with the fusi signal, it is of paramount importance to understand the temporal relation between `TTL*.csv` and `DAQ.csv`.

Note that time is registered differently:
- TTL : sec.msec
- DAQ and paradigm-specific csv: timestamp

Some stimuli/behaviour are logged in the channels of the TTL file, while others are not, and therefore the information must be taken from the paradigm-specific csv's.

**The most important information is that the first timestamp in DAQ is at the same time as the first rising edge in TTL channel 5 or 6 (current configuration)**. That is

```matlab
DAQ.time(1) = find(TTLinfo.time(:,5) > 0, 1 'first')
```

Having said that, it is always better to verify.


# What the code does (nontrivial parts)

## Reading fusi data bin and all the csv's
```matlab
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
```

## Reshape fusi bin in 3D and align number of frames in TTL and in fusi data
```matlab
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
```

## Lag analysis
⚠️ 🔴 Currently it does not work because probably it requires the original bin files to be present. However it is possible that it's not even necessary.
Make sure in any case to have the `LagaAnalysisFusi.m` in the pwd.

Even if the `try` breaks, the code should be executed since it creates the variable `PDItime` which is used afterwards. Currently, the `acceptIndex` is just a list of one's of the same length of the number of fusi frames.

```matlab
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
```



## Removing Data in TTL Before Experiment Start

⚠️ 🔴 **Crucial Alignment Step**: This step trims all pre-experiment rows from `TTLinfo`. The start of the experiment is marked by the first falling edge on **Channel 5** (or **Channel 6** depending on config), which corresponds precisely to the software timestamp `NIDAQInfo.time(1)`.

⚠️ 🔴 **IMPORTANT**: Frames recorded *after* the experiment start *but before* the actual onset of fUSi imaging (Channel 3) are strictly preserved. This means that $t_0$ for all stimulus events in `PDI.stimInfo` is referenced to the **beginning of the experiment**, *not* the start of fUSi acquisition.

To calculate when an event occurred **relative to the start of fUSi acquisition**, you must subtract the delay between experiment start and fUSi acquisition start:

$$t_{\text{fUSi\_relative}} = t_{\text{PDI}} - (t_{\text{fusi\_start}} - t_{\text{exp\_start}})$$

```matlab
% 1. Find indices using falling edges (< 0)
idx_exp_start  = find(diff(TTLinfo(:, 5)) < 0, 1, 'first'); % Or Col 6
idx_fusi_start = find(diff(TTLinfo(:, 3)) < 0, 1, 'first'); % fUSi frame pulses

% 2. Extract relative hardware timestamps (in seconds)
time_exp_start  = TTLinfo(idx_exp_start, 1);
time_fusi_start = TTLinfo(idx_fusi_start, 1);

% 3. Calculate temporal offset (delay between experiment trigger and fUSi onset)
time_offset_expstart_to_fusi = time_fusi_start - time_exp_start;

% 4. Align stimulus events relative to fUSi start (t = 0 at first fUSi frame)
PDI.stimInfo.event.onset_fusi = PDI.stimInfo.event.onset - time_offset_expstart_to_fusi;
```

**NB: This is a peculiar choice which is not common in glm software for fmri/fusi analysis. Usually the timing of the events which is provided to the model constructor assumes that $t_0$ is at the beginning of the fusi/fmri acquisition, and the model construction is carried out considering the TR (200msec in our case). Therefore we might change this in the future.** 


```matlab

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
```

## Mapping events from TTLinfo or from paradigm-specific csv's
⚠️ 🔴 In this case, only the droplet. It would be nice to have a separate function for each paradigm, to shorten the code and to allow more thorough comments for each paradigm.

⚠️ 🔴 Note that the channels and the csv filenames are currently hard-coded, which is not the best. It would be better to have these definition at the beginning of the script (or in an external configuration file, but that would make things more complex without real necessity for the time being).  

```matlab
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
```

## Writing the data to the PDI that will be saved
⚠️ 🔴 Note that this experiment was a mock scan, therefore there is no pupil, wheel or gsensor. Remember to uncomment the lines during the actual experiment.

Also save a copy of the TTLinfo _after_ removing all the frames before the start of the experiment. Just for futher verification.

```matlab
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
```


## Important note for subsequent GLM model construction

> [!CAUTION]
> The first frame of the fUSI image matrix `PDI.PDI(:,:,1)` corresponds to time `PDI.time(1)`, NOT $t = 0$ in the `PDI.stiminfo.time`. By referencing design matrices to the `PDI.time` grid, event regressors and continuous predictors remain synchronized with the functional imaging volume.

It is very important to remember that the timing of the events in `PDI.stimInfo` does _not_ have the start of the fUSI acquisition as its $t_0$. Instead, the time $t_0$ of all events is set to `NIDAQ.time(1)` (the start of the experimental protocol). 

This is reflected in the fact that the vector `PDI.time`—which contains the exact acquisition timestamps for each fUSI frame—has as its first value (`PDI.time(1)`) the duration between the beginning of the experiment (`NIDAQ.time(1)`) and the actual acquisition time of the first fUSI frame. In our preprocessing pipeline:

1. All TTL records prior to `NIDAQ.time(1)` are cropped from `TTLinfo`.
2. The initial timestamp `duration_before_NIDAQ_start = TTLinfo(idx_NIDAQ_start, 1)` is subtracted from both `TTLinfo(:,1)` and `PDItime`.
3. An offset of $+1\text{ TR}$ (`blockDuration`) is added to `PDItime` so that timestamps represent the completion time of each frame acquisition.

In other words, the temporal offset between the start of event logging and the first acquired fUSI frame is:

$$timeOffset_{fusi, PDI.stiminfo.time} = TTLinfo_{orig}(first fusi frame,1) - NIDAQ.time(1)$$

and since in all the time values were extracted after subtracting `NIDAQ.time(1)` in the saved PDI, including `PDI.time`

$$timeOffset_{fusi, PDI.stiminfo.time} = PDI.time(1)$$



### How this offset is handled during GLM model construction

Because the event timestamps in `PDI.stimInfo` are referenced to $t = 0$ (NIDAQ start), while the $k$-th frame in `PDI.PDI` was acquired at time $t = \text{PDI.time}(k)$, GLM regressors must explicitly bridge this offset. In our pipeline, this is handled via **nearest-frame index mapping** and **direct grid interpolation**:

1. **Discrete Boxcar Regressors (Stimulus Onsets / Offsets):**
   Instead of shifting event times mathematically, event onsets and offsets are mapped directly to their closest discrete fUSI frame index $k$:
   ```matlab
   [~, onsetFrame]  = arrayfun(@(x) min(abs(x - PDI.time)), PDI.stimInfo.startTime);
   [~, offsetFrame] = arrayfun(@(x) min(abs(x - PDI.time)), PDI.stimInfo.endTime);
   ```
   Because `PDI.time` starts at `PDI.time(1)` (e.g., $0.4\text{ s}$), `onsetFrame` places the boxcar onset at the exact frame index $k$ matching that physical time point. Convolving this frame-indexed boxcar with the HRF preserves alignment with `PDI.PDI(:,:,k)`.

2. **Continuous Regressors (e.g., Running Wheel Speed):**
   Continuous behavioral channels logged on the NIDAQ clock are interpolated directly onto the evaluation points given by `PDI.time`:
   ```matlab
   wheelSpeedAbs = interp1(PDI.wheelInfo.time, PDI.wheelInfo.wheelspeed, PDI.time, 'linear', 'extrap');
   ```
   Evaluating the continuous regressor at `PDI.time` automatically aligns frame index $k = 1$ with `wheelSpeedAbs(1)`, naturally absorbing `PDI.time(1)`.

<br>

