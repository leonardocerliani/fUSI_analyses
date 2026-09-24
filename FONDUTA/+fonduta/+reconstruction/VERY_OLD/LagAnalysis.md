
| Variable | Value / State BEFORE Code Runs | Value / State AFTER Code Runs |
| :--- | :--- | :--- |
| `PDI` | Complete raw image volume [Y x X x totalFrames], including pre-task pre-roll frames and potentially dropped frames. | Trimmed image volume [Y x X x validFrames]. Unstable/corrupted frames (if binary inspection works) and all pre-task frames (t < t_launch) are sliced out. |
| `PDItime` | Uninitialized OR raw timestamps from NIDAQ Channel 3. | Fully aligned, 1D column vector of timestamps (t >= 0.0 s), phase-shifted to frame completion and zero-anchored (t = 0.0 s) to the Task Launch trigger. |
| `PDI.time` | Unassigned / missing. | Assigned as PDItime (hardware-synchronized frame timestamps). |
| `PDI.Dim.dt` | Unassigned / missing. | Assigned as blockDuration (the dominant frame sampling interval dt in seconds). |
| `acceptIndex` | Uninitialized. | Logical array (true/false mask) indicating which raw fUSI blocks were kept (true) or flagged as corrupted (false). Defaults to all true if LagAnalysisFusi fails. |
| `blockDuration` | Uninitialized. | Calculated scalar value representing the frame acquisition period (e.g., 0.400 seconds). |
| `initTTL` | Uninitialized. | Row index in TTLinfo corresponding to the first rising edge of Channel 6 (or Channel 5). |
| `t_launch` | Uninitialized. | Timestamp (in NIDAQ seconds) of the Task Launch event. |
| `validFrames` | Uninitialized. | Logical mask indicating which frames occurred at or after task launch (t >= t_launch). |
| `TTLinfo` | Raw N x M matrix of NIDAQ signal channels and timestamps. | Unchanged (retains all original rows and raw time reference frame). |

