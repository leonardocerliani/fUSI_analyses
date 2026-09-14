%% Mapping the information for the harm aversion experiment (droplets, touch, shock)

% NB: to run the following code you must have 
% - already run the Rawdata2MATnew_V5_droplet.m  - which loads the data from the mock experiment -
% up to the point where all the info are available, and the "only" thing 
% left is to extract the stimuli (droplet and shock) and response (touch) 
% information. 
% - make sure you have the latest experiment_config.json in the datapath of
% the mock experiment data

%% Cell 1: Identify Active TTL Channels
% WHAT WE ARE TESTING:
%   Determine which of the 13 TTL channels in TTLinfo contain data and signal state changes.
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Identifies non-zero columns and columns with active digital transitions (rising/falling edges).
%   - Confirms that only a subset of the 13 columns contain active signals for this experiment.

% 1. Find which columns have any non-zero values
activeCols = find(any(TTLinfo ~= 0, 1));
fprintf('Columns with non-zero values: %s\n', mat2str(activeCols));

% 2. Find which columns actually change state (digital transitions)
varyingCols = find(std(TTLinfo, 0, 1) > 0);
fprintf('Columns with signal state changes: %s\n', mat2str(varyingCols));


%% Cell 2: Visual Inspection of Active TTL Channels
% WHAT WE ARE TESTING:
%   Plot all active TTL channels to visually map hardware signals to behavioral events.
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Column 1: Hardware time vector (seconds).
%   - Columns 3 & 8: fUSI frame acquisition triggers (PDI signal).
%   - Columns 2, 5, 6: Dual handshake pulses around ~97 s marking software launch.
%   - Column 7: Single event marker at ~118 s.
%   - Column 10: Touch sensor 1 (touch1 - shock-paired dispenser).
%   - Column 11: Touch sensor 2 (touch2 - safe dispenser).
%   - Column 12: Shocker box activation (shock).

figure('Name', 'TTL Channel Inspector');
for i = 1:numel(varyingCols)
    colIdx = varyingCols(i);
    subplot(numel(varyingCols), 1, i);
    plot(TTLinfo(:, 1), TTLinfo(:, colIdx)); 
    title(sprintf('TTL Column %d', colIdx), 'FontSize', 16); % Set desired font size here
    xlabel('Time (s)');
    ylabel('Signal');
    grid on;
end



%% Cell 3: Initial Event Counting & Timestamp Offset Inspection
% WHAT WE ARE TESTING:
%   Extract rising edges from TTL columns 10, 11, 12, load DropletStimulation.csv, 
%   and compare event counts and initial timestamps aligned to NIDAQ time zero.
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Event counts match perfectly: 13 touch1, 10 touch2, and 24 drops (logged in CSV only).
%   - Column 12 (shock) shows 14 pulses vs 13 CSV shocks due to an initialization pulse at ~97 s.
%   - Single-event triggers on Columns 2/5 fire at ~97.16 s, revealing that the behavioral script 
%     started logging ~97 seconds after NIDAQ recording was armed.
%   - A constant offset of ~97.16 s exists between NIDAQ time zero and CSV epoch timestamps.

% --- Load NIDAQ Info for Time Zero Offset ---
nidaqFiles = cfg.file_names.nidaq_log;
NIDAQInfo = [];
for i = 1:length(nidaqFiles)
    nidaqPath = fullfile(datapath, nidaqFiles{i});
    if exist(nidaqPath, 'file')
        NIDAQInfo = readtable(nidaqPath);
        break;
    end
end
timeZero = NIDAQInfo.time(1);

% --- Load DropletStimulation.csv ---
dropTable = readtable(fullfile(datapath, 'DropletStimulation.csv'));
dropTable.aligned_time = dropTable.time - timeZero;

% --- Extract Edge Timestamps from TTL Columns ---
t1_onsets  = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
t2_onsets  = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
sh_onsets  = TTLinfo(diff(TTLinfo(:, 12)) > 0, 1);

c2_event = TTLinfo(diff(TTLinfo(:, 2)) ~= 0, 1);
c5_event = TTLinfo(diff(TTLinfo(:, 5)) ~= 0, 1);
c6_event = TTLinfo(diff(TTLinfo(:, 6)) ~= 0, 1);
c7_event = TTLinfo(diff(TTLinfo(:, 7)) ~= 0, 1);

fprintf('--- Single Event Marker Timestamps (TTL s) ---\n');
fprintf('Col 2 event: %s\n', mat2str(c2_event));
fprintf('Col 5 event: %s\n', mat2str(c5_event));
fprintf('Col 6 event: %s\n', mat2str(c6_event));
fprintf('Col 7 event: %s\n', mat2str(c7_event));

csv_touch1 = dropTable(strcmp(dropTable.event, 'touch1'), :);
csv_touch2 = dropTable(strcmp(dropTable.event, 'touch2'), :);
csv_shock  = dropTable(strcmp(dropTable.event, 'shock'),  :);
csv_drop   = dropTable(strcmp(dropTable.event, 'drop'),   :);

fprintf('\n--- Event Count Verification ---\n');
fprintf('touch1 -> CSV count: %d | TTL Col 10 pulse count: %d\n', height(csv_touch1), numel(t1_onsets));
fprintf('touch2 -> CSV count: %d | TTL Col 11 pulse count: %d\n', height(csv_touch2), numel(t2_onsets));
fprintf('shock  -> CSV count: %d | TTL Col 12 pulse count: %d\n', height(csv_shock),  numel(sh_onsets));
fprintf('drop   -> CSV count: %d (Logged in CSV only)\n', height(csv_drop));

fprintf('\n--- First 5 Touch1 Timestamps (Aligned CSV vs TTL) ---\n');
n1 = min(5, min(height(csv_touch1), numel(t1_onsets)));
for k = 1:n1
    fprintf('Touch1 #%d: CSV = %.3f s | TTL = %.3f s | Diff = %.3f s\n', ...
        k, csv_touch1.aligned_time(k), t1_onsets(k), t1_onsets(k) - csv_touch1.aligned_time(k));
end

fprintf('\n--- First 5 Touch2 Timestamps (Aligned CSV vs TTL) ---\n');
n2 = min(5, min(height(csv_touch2), numel(t2_onsets)));
for k = 1:n2
    fprintf('Touch2 #%d: CSV = %.3f s | TTL = %.3f s | Diff = %.3f s\n', ...
        k, csv_touch2.aligned_time(k), t2_onsets(k), t2_onsets(k) - csv_touch2.aligned_time(k));
end

csvStartRelToNIDAQ = dropTable.time(1) - NIDAQInfo.time(1);
fprintf('Droplet CSV first event time (rel to NIDAQInfo): %.3f s\n', csvStartRelToNIDAQ);
fprintf('TTL Col 2/5 trigger timestamp:                  %.3f s\n', c2_event(1));
fprintf('Time difference (Clock drift/latency):          %.3f s\n', csvStartRelToNIDAQ - c2_event(1));


%% Cell 4: Primary Hardware vs. CSV Alignment Matrix
% WHAT WE ARE TESTING:
%   Attempt sequential 1-to-1 matching of CSV events to TTL channels using Column 5 
%   as the experiment start marker, filtering out initialization pulses (<100 s).
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Touch events show a strict, constant ~20.78 s offset across all trials.
%   - Sequential shock matching was shifted by 1 index because shock TTLs occur ~1.006 s 
%     AFTER touch1 events (hardware delivery window), proving shocks are directly tied to touch1.

ttlStartIdx = find(diff(TTLinfo(:, 5)) ~= 0, 1, 'first');
ttlStartTime = TTLinfo(ttlStartIdx, 1);
csvStartEpoch = dropTable.time(1);

t1_TTL = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1); 
t2_TTL = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
sh_TTL = TTLinfo(diff(TTLinfo(:, 12)) > 0, 1);
sh_TTL(sh_TTL < ttlStartTime) = []; 

eventList = {'touch1', 'touch2', 'shock'};
ttlMap    = {t1_TTL, t2_TTL, sh_TTL};
colMap    = [10, 11, 12];
summaryTable = table();

for i = 1:numel(eventList)
    evName = eventList{i};
    ttls   = ttlMap{i};
    colNum = colMap(i);
    
    csvRows = dropTable(strcmp(dropTable.event, evName), :);
    csvAlignedToTTL = (csvRows.time - csvStartEpoch) + ttlStartTime;
    
    n = min(height(csvRows), numel(ttls));
    
    tmpTbl = table(...
        repmat({evName}, n, 1), ...
        (1:n)', ...
        repmat(colNum, n, 1), ...
        csvAlignedToTTL(1:n), ...
        ttls(1:n), ...
        (ttls(1:n) - csvAlignedToTTL(1:n)) * 1000, ...
        'VariableNames', {'Event', 'Trial', 'TTL_Col', 'CSV_Aligned_s', 'TTL_Hardware_s', 'Delta_ms'});
    
    summaryTable = [summaryTable; tmpTbl]; %#ok<AGROW>
end

summaryTable = sortrows(summaryTable, 'TTL_Hardware_s');
disp(summaryTable);


%% Cell 5: Refined Time-Zero Offset & Touch Alignment Verification
% WHAT WE ARE TESTING:
%   Calculate the exact software-to-hardware time offset (97.1592 s) using the first touch event,
%   re-align CSV timestamps, and evaluate sub-second alignment errors for touch1 and touch2.
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Exact offset calculated: 97.1592 seconds.
%   - Error_ms for all touch events stays bounded between 0 ms and -93 ms.
%   - This minor delay represents normal PC software logging latency following the hardware TTL pulse,
%     confirming high-precision synchronization.

csvTouch1_Time = dropTable.time(find(strcmp(dropTable.event, 'touch1'), 1)) - NIDAQInfo.time(1);
ttlTouch1_Time = t1_TTL(1);

timeOffset = ttlTouch1_Time - csvTouch1_Time;
fprintf('Calculated Time-Zero Offset: %.4f seconds\n', timeOffset);

dropTable.ttl_equivalent = (dropTable.time - NIDAQInfo.time(1)) + timeOffset;

eventsToTest = {'touch1', 'touch2'};
testTable = table();
for i = 1:numel(eventsToTest)
    evName = eventsToTest{i};
    csvRows = dropTable(strcmp(dropTable.event, evName), :);
    
    if strcmp(evName, 'touch1')
        ttls = t1_TTL;
    else
        ttls = t2_TTL;
    end
    
    n = min(height(csvRows), numel(ttls));
    tmpTbl = table(...
        repmat({evName}, n, 1), ...
        (1:n)', ...
        csvRows.ttl_equivalent(1:n), ...
        ttls(1:n), ...
        (ttls(1:n) - csvRows.ttl_equivalent(1:n)) * 1000, ...
        'VariableNames', {'Event', 'Index', 'CSV_In_TTL_Time_s', 'TTL_Hardware_s', 'Error_ms'});
    
    testTable = [testTable; tmpTbl]; %#ok<AGROW>
end

testTable = sortrows(testTable, 'TTL_Hardware_s');
disp(testTable);


%% Cell 6: Full Trial-by-Trial Behavioral & Reaction Time Verification
% WHAT WE ARE TESTING:
%   Build a comprehensive trial-by-trial table linking drop presentation, mouse choice (touch1/touch2),
%   shock delivery, and reaction time (Touch_TTL - Drop_TTL).
%
% WHAT RUNNING THIS CODE REVEALS:
%   - Trial 0 correctly registered as 'timeout' (no touch/shock).
%   - Reaction time (ReactionTime_s) is strictly positive (0.53 s to 2.25 s) across all active trials,
%     proving 'drop' represents droplet presentation prior to touch.
%   - touch2 trials show no shocks (NaN).
%   - touch1 trials trigger shocks with a precise ~1.006 s hardware delay (Shock_Err_ms).

csvFirstTouch1 = dropTable.time(find(strcmp(dropTable.event, 'touch1'), 1)) - NIDAQInfo.time(1);
t1_TTL = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
t2_TTL = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);
sh_TTL_raw = TTLinfo(diff(TTLinfo(:, 12)) > 0, 1);
sh_TTL = sh_TTL_raw(sh_TTL_raw > 100); 

timeOffset = t1_TTL(1) - csvFirstTouch1;
dropTable.ttl_time = (dropTable.time - NIDAQInfo.time(1)) + timeOffset;

trialRows = find(contains(dropTable.event, 'trial'));
numTrials = numel(trialRows);
trialVerificationTable = table();

for k = 1:numTrials
    idxStart = trialRows(k);
    if k < numTrials
        idxEnd = trialRows(k+1) - 1;
    else
        idxEnd = height(dropTable);
    end
    
    trialBlock = dropTable(idxStart:idxEnd, :);
    
    dropRow = trialBlock(strcmp(trialBlock.event, 'drop'), :);
    if isempty(dropRow), continue; end
    drop_TTL_time = dropRow.ttl_time(1);
    
    hasTouch1 = any(strcmp(trialBlock.event, 'touch1'));
    hasTouch2 = any(strcmp(trialBlock.event, 'touch2'));
    hasShock  = any(strcmp(trialBlock.event, 'shock'));
    
    touchType = 'timeout';
    touch_CSV_time = NaN;
    touch_TTL_time = NaN;
    touch_error_ms = NaN;
    
    shock_CSV_time = NaN;
    shock_TTL_time = NaN;
    shock_error_ms = NaN;
    
    if hasTouch1
        touchType = 'touch1';
        t1Row = trialBlock(strcmp(trialBlock.event, 'touch1'), :);
        touch_CSV_time = t1Row.ttl_time(1);
        
        [minDiff, minIdx] = min(abs(t1_TTL - touch_CSV_time));
        if minDiff < 0.5 
            touch_TTL_time = t1_TTL(minIdx);
            touch_error_ms = (touch_TTL_time - touch_CSV_time) * 1000;
        end
        
    elseif hasTouch2
        touchType = 'touch2';
        t2Row = trialBlock(strcmp(trialBlock.event, 'touch2'), :);
        touch_CSV_time = t2Row.ttl_time(1);
        
        [minDiff, minIdx] = min(abs(t2_TTL - touch_CSV_time));
        if minDiff < 0.5
            touch_TTL_time = t2_TTL(minIdx);
            touch_error_ms = (touch_TTL_time - touch_CSV_time) * 1000;
        end
    end
    
    if hasShock
        shRow = trialBlock(strcmp(trialBlock.event, 'shock'), :);
        shock_CSV_time = shRow.ttl_time(1);
        
        [minDiff, minIdx] = min(abs(sh_TTL - shock_CSV_time));
        if minDiff < 1.5 
            shock_TTL_time = sh_TTL(minIdx);
            shock_error_ms = (shock_TTL_time - shock_CSV_time) * 1000;
        end
    end
    
    reactionTime_sec = touch_TTL_time - drop_TTL_time;
    
    rowTbl = table(...
        k - 1, ...
        drop_TTL_time, ...
        {touchType}, ...
        touch_TTL_time, ...
        touch_error_ms, ...
        shock_TTL_time, ...
        shock_error_ms, ...
        reactionTime_sec, ...
        'VariableNames', {'Trial', 'Drop_TTL_s', 'Choice', 'Touch_TTL_s', 'Touch_Err_ms', 'Shock_TTL_s', 'Shock_Err_ms', 'ReactionTime_s'});
        
    trialVerificationTable = [trialVerificationTable; rowTbl]; %#ok<AGROW>
end

disp('--- Trial-by-Trial Alignment & Reaction Time Table ---');
disp(trialVerificationTable);

% =========================================================================
% SUMMARY OF TTL HARDWARE & CSV ALIGNMENT VERIFICATION
% =========================================================================
%
% 1. HARDWARE TTL CHANNEL MAPPING (TTLinfo Columns):
%    - Col 1  : Hardware timestamps (seconds)
%    - Col 3  : fUSI frame acquisition trigger pulses (PDI channel)
%    - Col 8  : Duplicate fUSI frame acquisition trigger line (identical to Col 3)
%    - Col 2, 5, 6 : Dual handshake pulses marking software launch (~97.16 s)
%    - Col 7  : Single setup marker at ~118 s
%    - Col 10 : Touch Sensor 1 (touch1 - shock-paired dispenser)
%    - Col 11 : Touch Sensor 2 (touch2 - safe dispenser)
%    - Col 12 : Shocker box activation pulse (shock)
%
% 2. ALIGNMENT LOGIC (CSV vs. TTLinfo):
%    - NIDAQInfo.time(1) sets hardware Time-Zero (0.000 s).
%    - Software-to-Hardware Offset: Computed via the first touch event 
%      [TTL_time - (CSV_time - NIDAQ_start)], yielding an exact 97.1592 s offset.
%    - CSV timestamps are mapped to hardware time via:
%      dropTable.ttl_time = (dropTable.time - NIDAQInfo.time(1)) + timeOffset;
%
% 3. FINAL TIMING VERIFICATION & BEHAVIORAL METRICS:
%    - Touch Precision : CSV touch events align with TTL Cols 10/11 within 
%                        0 to -93 ms (accounting for PC logging latency).
%    - Shock Delivery  : Shocks fire exactly ~1.006 s AFTER touch1 events on 
%                        hardware Col 12 (shocker box activation delay).
%    - Drop Event      : Exists only in CSV ('drop'). Always occurs 0.53 s to 
%                        2.25 s BEFORE touch1/touch2 across all trials.
%    - Mouse Behavior  : 'drop' reliably represents droplet presentation; 
%                        (Touch_TTL - Drop_TTL) calculates mouse reaction time.
% =========================================================================



%% Plot Aligned Behavioral Timeline (touch1, touch2, shock, drop)
% WHAT WE ARE TESTING:
%   Visualize touch1 (Col 10), touch2 (Col 11), and shock (Col 12) TTL waveforms 
%   aligned with CSV drop presentation markers on a unified hardware time axis.

% --- 1. Compute Alignment Offset & Filter CSV Drop Events ---
csvFirstTouch1 = dropTable.time(find(strcmp(dropTable.event, 'touch1'), 1)) - NIDAQInfo.time(1);
t1_TTL = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
timeOffset = t1_TTL(1) - csvFirstTouch1;

% Convert drop timestamps to hardware TTL time
dropRows = dropTable(strcmp(dropTable.event, 'drop'), :);
drop_TTL_times = (dropRows.time - NIDAQInfo.time(1)) + timeOffset;

% --- 2. Create Aligned Event Overlay Plot ---
figure('Name', 'Aligned Behavioral Event Timeline', 'Position', [100, 100, 1000, 700]);

% Subplot 1: Touch 1 (Shock Side)
subplot(4, 1, 1);
plot(TTLinfo(:, 1), TTLinfo(:, 10), 'b', 'LineWidth', 1.2);
ylabel('Touch 1');
title('Touch 1 (TTL Col 10 - Shock Side)');
grid on; xlim([min(drop_TTL_times)-5, max(TTLinfo(:, 1))]);

% Subplot 2: Touch 2 (Safe Side)
subplot(4, 1, 2);
plot(TTLinfo(:, 1), TTLinfo(:, 11), 'g', 'LineWidth', 1.2);
ylabel('Touch 2');
title('Touch 2 (TTL Col 11 - Safe Side)');
grid on; xlim([min(drop_TTL_times)-5, max(TTLinfo(:, 1))]);

% Subplot 3: Shock
subplot(4, 1, 3);
plot(TTLinfo(:, 1), TTLinfo(:, 12), 'r', 'LineWidth', 1.2);
ylabel('Shock');
title('Shock (TTL Col 12)');
grid on; xlim([min(drop_TTL_times)-5, max(TTLinfo(:, 1))]);

% Subplot 4: Droplet Presentation (CSV Drop Markers)
subplot(4, 1, 4);
stem(drop_TTL_times, ones(size(drop_TTL_times)), 'm', 'LineWidth', 1.5, 'Marker', 'o', 'MarkerFaceColor', 'm');
ylabel('Drop');
title('Droplet Presentation (CSV drop - Aligned to Hardware Time)');
xlabel('Hardware Time (s)');
ylim([0, 1.2]); grid on; xlim([min(drop_TTL_times)-5, max(TTLinfo(:, 1))]);

% --- 3. Overlay Vertical Drop Reference Lines Across All Subplots ---
for sp = 1:3
    subplot(4, 1, sp);
    hold on;
    for d = 1:numel(drop_TTL_times)
        xline(drop_TTL_times(d), '--m', 'Alpha', 0.5);
    end
    hold off;
end


%% Single-Axes Combined Behavioral Timeline Plot (Reordered & Inverted Shock)
% WHAT WE ARE TESTING:
%   Overlay touch1, shock, touch2 TTL signals and CSV drop events in a single figure.
%   Invert active-low shock signal so pulses point UP, and position shock directly 
%   above Touch 1 for visual clarity.

% --- 1. Compute Alignment Offset & Filter CSV Drop Events ---
csvFirstTouch1 = dropTable.time(find(strcmp(dropTable.event, 'touch1'), 1)) - NIDAQInfo.time(1);
t1_TTL = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
timeOffset = t1_TTL(1) - csvFirstTouch1;

dropRows = dropTable(strcmp(dropTable.event, 'drop'), :);
drop_TTL_times = (dropRows.time - NIDAQInfo.time(1)) + timeOffset;

% Invert active-low shock line (Column 12) so pulses point UP (1 -> 0 becomes 0 -> 1)
shock_inverted = max(TTLinfo(:, 12)) - TTLinfo(:, 12);

% --- 2. Plot Overlay in Single Axes ---
figure('Name', 'Combined Behavioral Event Overlay', 'Position', [100, 100, 1100, 600]);
hold on;

% Plot TTL signals with vertical offsets (+2)
h1 = plot(TTLinfo(:, 1), TTLinfo(:, 10), 'b', 'LineWidth', 1.5);             % Touch 1 (0 to 1)
h3 = plot(TTLinfo(:, 1), shock_inverted + 2, 'r', 'LineWidth', 1.5);         % Shock   (2 to 3)
h2 = plot(TTLinfo(:, 1), TTLinfo(:, 11) + 4, 'g', 'LineWidth', 1.5);         % Touch 2 (4 to 5)

% Overlay Vertical Drop Lines across full height
for d = 1:numel(drop_TTL_times)
    if d == 1
        h4 = xline(drop_TTL_times(d), '--m', 'LineWidth', 1.2); % Reference handle for legend
    else
        xline(drop_TTL_times(d), '--m', 'LineWidth', 1.2);
    end
end

% --- 3. Formatting & Styling ---
title('Combined Behavioral Event Overlay (Aligned Hardware Time)');
xlabel('Hardware Time (s)');
ylabel('Event Signal (Offset for Clarity)');

% Set Y-limits and custom Y-tick labels reflecting new order
ylim([-0.5, 6]);
yticks([0.5, 2.5, 4.5]);
yticklabels({'Touch 1 (Shock Side)', 'Shock Trigger', 'Touch 2 (Safe Side)'});

% Set X-limits to zoom around active behavioral window
xlim([min(drop_TTL_times) - 5, max(TTLinfo(:, 1))]);

grid on;
legend([h1, h3, h2, h4], {'Touch 1 (Col 10)', 'Shock (Col 12 - Inverted)', 'Touch 2 (Col 11)', 'Drop (CSV Aligned)'}, ...
    'Location', 'northeast');
hold off;


%% Understanding the alignment
nidaq_time = datetime(NIDAQInfo.time, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
nidaq_time.Format = 'yyyy-MM-dd HH:mm:ss.SSS';

csv_time = datetime(dropTable.time, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
csv_time.Format = 'yyyy-MM-dd HH:mm:ss.SSS';


dropTable.time - NIDAQInfo.time(1)


%% Aligning using the first touch1
% 1. Get the hardware TTL timestamp of the first touch1 event (Channel 10)
t1_TTL = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);
first_TTL_touch1 = t1_TTL(1); 

% 2. Get the raw epoch time of the first touch1 event from the CSV
first_CSV_touch1_raw = dropTable.time(find(strcmp(dropTable.event, 'touch1'), 1));

% 3. Convert raw CSV time to relative time (seconds since NIDAQ arming)
first_CSV_touch1_relative = first_CSV_touch1_raw - NIDAQInfo.time(1);

% 4. Calculate the exact timeOffset
timeOffset = first_TTL_touch1 - first_CSV_touch1_relative;

% Display the high-precision result
fprintf('Exact Time Offset: %.6f seconds\n', timeOffset);


%% Aligning using the pulse on channels 2,5,6

% 1. Get the hardware timestamp of the software launch trigger (Col 5 falling edge)
ttlStartIdx = find(diff(TTLinfo(:, 5)) ~= 0, 1, 'first');
ttlStartTime = TTLinfo(ttlStartIdx, 1); % ~97.1600 s

% 2. Get the relative time of the first CSV entry
csvStartRelative = dropTable.time(1) - NIDAQInfo.time(1); % ~0.0008 s

% 3. Calculate offset using Channel 5
timeOffset_Ch5 = ttlStartTime - csvStartRelative;

fprintf('Time Offset via Ch 5: %.6f seconds\n', timeOffset_Ch5);

dropTable.time - NIDAQInfo.time(1) +  timeOffset_Ch5
