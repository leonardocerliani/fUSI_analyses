% LagAnalysisFusi.m

function [T_pdi_intended, timeTagsSec] = LagAnalysisFusi(datapath)
%% Load metadata and time tags from fUSI acquisition
% This function checks timing consistency of ultrasound acquisition blocks,
% and computes both the *recorded* block times and the *intended* (ideal) timeline.

%% 1. Load metadata
if nargin < 1
    % If no path is provided, open a dialog to choose the data folder
    IQpath = uigetdir('.', 'Please select the raw data folder');
    load(fullfile(IQpath,'post_L22-14_PlaneWave_FUSI_data.mat'))
else
    % Otherwise use the provided path
    IQpath = [datapath filesep];
    load(fullfile(IQpath,'post_L22-14_PlaneWave_FUSI_data.mat'))
end

%% 2. Update structures with data path
Pm.data_path_save = IQpath;
P.data_path_save = IQpath;
Pcont.data_path_save = IQpath;

% Use Pcont as the acquisition metadata reference
P = Pcont;

%% 3. Prepare to loop over acquisition blocks
nblocks = P.numBlocks;             % number of recorded data blocks
datafolder = P.data_path_save;     % folder containing the binary files
DISK_ROTATION = iscell(datafolder); % sometimes data is split across multiple disks

if iscell(datafolder)
    datafolders = datafolder; % keep all folder paths
end

% Choose filename pattern depending on whether RF data was saved
checkEnd = false;
if P.saveRF
    datanamepat = 'fUS_block_rf_%03i.bin';
else
    datanamepat = 'fUS_block_tt_%03i.bin';
    checkEnd = false; % (disabled, but code is there)
end

datatype = 'int16';                 % data precision in binary files
timeTagsSec    = NaN(nblocks, 1);   % preallocate for time tags (start)
timeTagsSecEND = NaN(nblocks, 1);   % preallocate for time tags (end, optional)

fprintf('Checking TimeTags of all recorded blocks\n');

%% 4. Loop through each block, read its timestamp
for kb = 1:nblocks
    % Print progress every 20 blocks
    if mod(kb, 20) == 0
        fprintf('Reading block % 4i of % 4i\n', kb, P.numBlocks)
    end
    
    % Construct filename for this block
    dataname = sprintf(datanamepat, kb);
    
    % Select the right folder (if multiple disks were used)
    if DISK_ROTATION
        datafolder = datafolders{rem(kb - 1, numel(datafolders)) + 1};
    end
    
    % Read the first 2 samples to extract time tag
    [timeTag, fileFound] = readBinFile(fullfile(datafolder, dataname), 2, datatype);
    
    if ~fileFound
        % If file is missing, record NaN
        fprintf('ERROR: Could not find all blocks.\n')
        timeTagsSec(kb) = NaN;
    else
        % Convert raw timeTag into seconds
        timeTagsSec(kb) = TimeTag2Sec(timeTag);
    end
    
    % (Optional) also check the last samples of the block
    if checkEnd
        [timeTagEND, fileFound] = readBinFile(fullfile(datafolder, dataname), 2, datatype, 0, -P.Nz_RF);
        if ~fileFound
            fprintf('ERROR: Could not find all blocks.\n')
            break;
        end
        timeTagsSecEND(kb) = TimeTag2Sec(timeTagEND);
    end
end

%% 5. Normalize time tags (start at zero)
% % timeTagsSecEND = timeTagsSecEND(1:nblocks);
timeTagsSecEND = timeTagsSecEND - nanmin(timeTagsSec);  % shift so min=0
timeTagsSec    = timeTagsSec(1:nblocks);
timeTagsSec    = timeTagsSec - nanmin(timeTagsSec);

%% 6. Compute expected (ideal) timeline
% Intended dt is the *mode* of the first 50 intervals
dt_intended = mode(diff(timeTagsSec(1:50)));

% Build intended timeline assuming perfect regular sampling
T_pdi_intended = (0:nblocks-1)' * dt_intended;

%% 7. Plot comparison: intended vs recorded
figure;
plot(T_pdi_intended, timeTagsSec)          % recorded
hold on 
plot(T_pdi_intended, T_pdi_intended,'k--') % perfect clock
title('Recorded vs Intended Time Tags')
xlabel('Intended time (s)')
ylabel('Recorded time (s)')
legend('Recorded', 'Ideal')

end

