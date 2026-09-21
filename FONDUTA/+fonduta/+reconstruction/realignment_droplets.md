# NIDAQ Hardware & Software Event Alignment Documentation

This document explains the synchronization pipeline between software-logged task events (`dropTable`) and hardware-recorded TTL pulses (`TTLinfo`) acquired via NIDAQ.

There are three descriptors of the events:

- **`TTLinfo.csv`**
  - time in sec.msec on channel **1**
  - fusi on channel **3**
  - start of the experiment on channel **5** (fallback on channel 6)
- **`NIDAQ.csv`**
  - time (timestamp) in the first column
  - columns for touch1/2 and shock_left
  - touch1/2 ON = 1, OFF = 0
  - shock ON = 0, OFF = 1
  - shock_right (not required) always = 1
  - droplet always = 1 (not informative)
- **`DropletStimulation.csv`**
  - time (timestamp) in the first column
  - all events including droplet

The NIDAQ file is not really useful for the events, since the same event is logged on different rows, making the definition of the timing difficult. Plus it does not include the droplet.

However, we do need the NIDAQ CSV to extract the timing of the droplet, since the NIDAQ gives us the timestamp of TTLinfo start_experiment (ch 5) and DropletStimulation.

---

## 1. Overview & Theoretical Background

During experimental acquisition, event timestamps originate from two distinct clock domains:

1. **Software Domain (`dropTable` CSV):** Timestamps logged by the behavioral control script. Timestamps are referenced to script initialization, `t_script_init = dropTable.time(1)`.

2. **Hardware Domain (`TTLinfo` NIDAQ):** High-frequency analog/digital recordings starting when NIDAQ arms, `t_NIDAQ_arm = NIDAQInfo.time(1) = 0 s`.

### Clock Domain Relationships & Variables

- `t_NIDAQ_arm`: The baseline reference time (`0 s`) for all hardware channels in `TTLinfo`.
- `hardwareTaskStart`: Timestamp of the task launch trigger pulse on Channel 5 relative to `t_NIDAQ_arm`.
- `csvStartRelative`: Delay between software script initialization and NIDAQ arming.

  `csvStartRelative = dropTable.time(1) - NIDAQInfo.time(1)`

- `timeOffset`: Overall transformation offset required to project software timestamps onto the NIDAQ hardware timeline.

  `timeOffset = hardwareTaskStart - csvStartRelative`

### Timestamp Transformation Formulas

#### A. Transforming `dropTable` Events to NIDAQ Hardware Timeline

To map software timestamps (`event.time`) onto the NIDAQ hardware clock:

`onset_time = (event.time - NIDAQInfo.time(1)) + timeOffset`

Substituting:

`timeOffset = hardwareTaskStart - (dropTable.time(1) - NIDAQInfo.time(1))`

gives:

`onset_time = (event.time - dropTable.time(1)) + hardwareTaskStart`

#### B. Direct Synchronization Alignment

When aligning software events to match hardware event plots directly (accounted for pre-arm delay):

`onset_time_aligned = (event.time - dropTable.time(1)) + hardwareTaskStart + csvStartRelative`

---

## 2. Event Routing Strategy

In the `functional_reconstruction` pipeline:

- **Physiological / Physical Stimuli (`touch1`, `touch2`, `shock`):** Sourced directly from raw digital TTL hardware channels (`TTLinfo`). These serve as ground truth.
- **Secondary / Software-Only Events (`drop`):** Sourced from `dropTable` software logs and mapped to the NIDAQ timeline using `timeOffset`.

---

## 3. Full Processing & Verification MATLAB Pipeline

This document explains the synchronization pipeline between software-logged task events (`dropTable`) and hardware-recorded TTL pulses (`TTLinfo`) acquired via NIDAQ.


There are three descriptors of the events:

- **TTLinfo.csv** 
    - time in sec.msec on channel **1**
    - fusi on channel **3**
    - start of the experiment on channel **5** (fallback on channel 6)
- **NIDAQ.csv**
    - time (timestamp) in the first column
    - columns for touch1/2 and shock_left
    - touch1/2 ON = 1, OFF = 0 
    - shock ON = 0, OFF = 1 
    - shock_right (not required) always = 1
    - droplet always = 1 (not informative)
- **DropletStimulation.csv**
    - time (timestamp) in the first column
    - all events including droplet

The NIDAQ file is not really useful for the events, since the same event is logged on different rows, making the definition of the timing difficult. Plus it does not include the droplet.

However, we do need the NIDAQ csv to extract the timing of the droplet, since the NIDAQ gives us the timestamp of TTLinfo start_experiment (ch 5) and DropletStimulation 

---

## 1. Overview & Theoretical Background

During experimental acquisition, event timestamps originate from two distinct clock domains:
1. **Software Domain (`dropTable` CSV):** Timestamps logged by the behavioral control script. Timestamps are referenced to script initialization ($t_{\text{script\_init}} = \text{dropTable.time}(1)$).
2. **Hardware Domain (`TTLinfo` NIDAQ):** High-frequency analog/digital recordings starting when NIDAQ arms ($t_{\text{NIDAQ\_arm}} = \text{NIDAQInfo.time}(1) = 0\text{ s}$).

### Clock Domain Relationships & Variables
- $t_{\text{NIDAQ\_arm}}$: The baseline reference time ($0\text{ s}$) for all hardware channels in `TTLinfo`.
- $\text{hardwareTaskStart}$: Timestamp of the task launch trigger pulse on Channel 5 relative to $t_{\text{NIDAQ\_arm}}$.
- $\text{csvStartRelative}$: Delay between software script initialization and NIDAQ arming:
  $$\text{csvStartRelative} = \text{dropTable.time}(1) - \text{NIDAQInfo.time}(1)$$
- $\text{timeOffset}$: Overall transformation offset required to project software timestamps onto the NIDAQ hardware timeline:
  $$\text{timeOffset} = \text{hardwareTaskStart} - \text{csvStartRelative}$$

### Timestamp Transformation Formulas

#### A. Transforming `dropTable` events to NIDAQ Hardware Timeline
To map software timestamps ($\text{event.time}$) onto the NIDAQ hardware clock:
$$\text{onset\_time} = (\text{event.time} - \text{NIDAQInfo.time}(1)) + \text{timeOffset}$$

Substituting $\text{timeOffset} = \text{hardwareTaskStart} - (\text{dropTable.time}(1) - \text{NIDAQInfo.time}(1))$:
$$\text{onset\_time} = (\text{event.time} - \text{dropTable.time}(1)) + \text{hardwareTaskStart}$$

#### B. Direct Synchronization Alignment
When aligning software events to match hardware event plots directly (accounted for pre-arm delay):
$$\text{onset\_time}_{\text{aligned}} = (\text{event.time} - \text{dropTable.time}(1)) + \text{hardwareTaskStart} + \text{csvStartRelative}$$

---

## 2. Event Routing Strategy

In the `functional_reconstruction` pipeline:
- **Physiological / Physical Stimuli (`touch1`, `touch2`, `shock`):** Sourced directly from raw digital TTL hardware channels (`TTLinfo`). These serve as ground truth.
- **Secondary / Software-Only Events (`drop`):** Sourced from `dropTable` software logs and mapped to the NIDAQ timeline using $\text{timeOffset}$.

---

## 3. Full Processing & Verification MATLAB Pipeline

```matlab
% =========================================================================
% 1. LOCATE HARDWARE TASK BASELINE
% =========================================================================
% Search NIDAQ channels for the first rising edge marking session launch.
initTTL = find(diff(TTLinfo(:, 6)) > 0, 1, 'first');
if isempty(initTTL)
    initTTL = find(diff(TTLinfo(:, 5)) > 0, 1, 'first');
end
t_launch = TTLinfo(initTTL, 1);

% Identify exact task launch trigger on Channel 5
startPulseIdx = find(diff(TTLinfo(:, 5)) ~= 0, 1, 'first');
hardwareTaskStart = TTLinfo(startPulseIdx, 1);

% =========================================================================
% 2. EXTRACT HARDWARE EVENTS FROM TTLinfo (GROUND TRUTH)
% =========================================================================
% Touch 1 (Col 10): Rising edge
touch1_onset = TTLinfo(diff(TTLinfo(:, 10)) > 0, 1);

% Touch 2 (Col 11): Rising edge
touch2_onset = TTLinfo(diff(TTLinfo(:, 11)) > 0, 1);

% Shock (Col 12): Active-low signal -> Falling edge marks trigger
shock_onset  = TTLinfo(diff(TTLinfo(:, 12)) < 0, 1);

% =========================================================================
% 3. ALIGN SOFTWARE 'DROP' EVENTS VIA TIME OFFSET
% =========================================================================
% Calculate pre-arm delay between software script init and NIDAQ arming
csvStartRelative = dropTable.time(1) - NIDAQInfo.time(1);

% Compute unified transformation offset
timeOffset = hardwareTaskStart - csvStartRelative;

% Map software-only 'drop' events directly to NIDAQ hardware clock
dropRows = dropTable(strcmp(dropTable.event, 'drop'), :);
drop_onset = (dropRows.time - NIDAQInfo.time(1)) + timeOffset;

% =========================================================================
% 4. BUILD HARDWARE EVENTS TABLE (TTLinfo)
% =========================================================================
events = [repmat({'touch1'}, numel(touch1_onset), 1); ...
          repmat({'touch2'}, numel(touch2_onset), 1); ...
          repmat({'shock'},  numel(shock_onset),  1); ...
          repmat({'drop'},   numel(drop_onset),   1)];
onsets = [touch1_onset; ...
          touch2_onset; ...
          shock_onset; ...
          drop_onset];

eventTable_TTLinfo = table(events, onsets, 'VariableNames', {'event', 'onset_time'});
eventTable_TTLinfo = sortrows(eventTable_TTLinfo, 'onset_time');

% =========================================================================
% 5. BUILD SOFTWARE EVENTS TABLE (dropTable) WITH EXACT SHIFT
% =========================================================================
targetEvents = ["drop", "touch1", "touch2", "shock"];
mask = matches(dropTable.event, targetEvents);
csvEventsTable = dropTable(mask, {'event', 'time'});

% Transform software timestamps to lay directly on top of hardware timeline
csvEventsTable.onset_time = (csvEventsTable.time - dropTable.time(1)) + hardwareTaskStart + csvStartRelative;

eventTable_dropTable = csvEventsTable(:, {'event', 'onset_time'});
eventTable_dropTable = sortrows(eventTable_dropTable, 'onset_time');

% =========================================================================
% 6. VISUALIZE ALIGNED HARDWARE VS SOFTWARE EVENTS
% =========================================================================
c_touch1 = [0.10, 0.80, 0.30]; % Green
c_touch2 = [0.90, 0.50, 0.10]; % Orange
c_shock  = [0.90, 0.10, 0.10]; % Red

figure('Name', 'Aligned Hardware vs Software Events', 'Color', 'w', 'Position', [100, 100, 1200, 600]);

% --- Top Subplot: Hardware Events (TTLinfo) ---
ax1 = subplot(2, 1, 1);
hold(ax1, 'on');

ttl_no_drops = eventTable_TTLinfo(~strcmp(eventTable_TTLinfo.event, 'drop'), :);

for i = 1:height(ttl_no_drops)
    ev = ttl_no_drops.event{i};
    t  = ttl_no_drops.onset_time(i);
    if strcmp(ev, 'shock')
        xline(ax1, t, '--', 'Color', c_shock, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        is_t1 = strcmp(ev, 'touch1');
        col = is_t1 * c_touch1 + (~is_t1) * c_touch2;
        stem(ax1, t, 1, 'Color', col, 'LineWidth', 1.2, 'Marker', 'o', 'MarkerFaceColor', col, 'HandleVisibility', 'off');
    end
end

title(ax1, 'Hardware Events from TTLinfo (touch1, touch2, shock)');
xlabel(ax1, 'Time (s)'); ylabel(ax1, 'Event');
ylim(ax1, [0, 1.5]); grid(ax1, 'on');

% --- Bottom Subplot: Software Events (dropTable) ---
ax2 = subplot(2, 1, 2);
hold(ax2, 'on');

csv_no_drops = eventTable_dropTable(~strcmp(eventTable_dropTable.event, 'drop'), :);

for i = 1:height(csv_no_drops)
    ev = csv_no_drops.event{i};
    t  = csv_no_drops.onset_time(i);
    if strcmp(ev, 'shock')
        xline(ax2, t, '--', 'Color', c_shock, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        is_t1 = strcmp(ev, 'touch1');
        col = is_t1 * c_touch1 + (~is_t1) * c_touch2;
        stem(ax2, t, 1, 'Color', col, 'LineWidth', 1.2, 'Marker', 'o', 'MarkerFaceColor', col, 'HandleVisibility', 'off');
    end
end

title(ax2, 'Software Events from dropTable (touch1, touch2, shock)');
xlabel(ax2, 'Time (s)'); ylabel(ax2, 'Event');
ylim(ax2, [0, 1.5]); grid(ax2, 'on');

% Link axes for simultaneous panning/zooming
linkaxes([ax1, ax2], 'x');
xlim(ax1, [80, 280]);
```
'''