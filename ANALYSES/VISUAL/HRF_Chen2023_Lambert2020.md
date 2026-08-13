  # Chen 2023 + Lambert 2020

## Determination of the active voxels to consider
- FIR with 9 time-lagged predictors
- F-test across beta1..beta9 to determine significantly active regions(p<0.05)
  - only regions with at least 5 sig active voxels were considered

## Time courses preparation/selection
- time courses were temporally smoothed by a moving average with 5 s window (their TR is 1000 ms)

- then we determined whether the BOLD signals had a positive or negative time course on a voxel-by-voxel basis; 
  - to this end, we averaged the time series over 20 repetitions and normalized it to the baseline. 

- To allow successful fitting of the HRF using two gamma functions, time courses needed to meet 2 criteria: 
  - the amplitude of the BOLD response had to be at least 0.6% 
  - the BOLD signal had to decay by at least 40% following the maximum peak
  - note that only about 8% of the voxels meet these criteria in the original dataset

- Additionally, to avoid unphysiologic results, 
  - the time t_p, at which the HRF was at maximum, had to be smaller than the time t_u, at which the undershoot reached its minimum (t_p < t_u). 
  - the difference between tu and tp had to be less than 6 s (t_u - t_p <= 6 s). 

## Fitting procedure
Summarizing the selection procedures, only trial-specific time courses were included:
- in regions that had at least 5 significantly active voxels
- only positive haemodynamic response signals
- with an amplitude of at least 0.6% and a decay of 40% from the max
- physiologically valid (t_p < t_u AND t_u - t_p <= 6 s)

First, the fitting was done per animal:
- the signal was averaged among the included trials (Chen 2023) or across all the 20 trials (Lambert 2020) 
- this resulted in a single averaged time course of 30 seconds (note that TR=1000ms): 
  - 0-10 seconds : pre-stimulus baseline
  - 10-20 seconds : active mechanical stimulation
  - 20-30 seconds : post-stimulus recovery and undershoot phase

- Using matlab `multistart`, the optimization procedure was repeated 40K times with paramter limits (Suppl. Table 2):
- A = [0, 5]
- b = [0.1, 5]
- p1 = [1,50] 
- p2 = [5, 90]
- V = [1, 15] 

- This gives one specific set of parameters for each animal and for each considered brain region

- At this point, the individual HRF go through a second fitting process, with the same parameters (omitting A = Amplitude, since the curves are normalized to a max of 1)
- This time, it's the average HRF across animals and regions which represents the data for the fitting procedure.

- MSE is estimated for each fit, and returns a sorted list of the best fitting parameters
- at these points, some of the candidates are excluded:
  - the normalized MSE must be <= 0.1
  - the fitting curve must not show and early onset - meaning the BOLD signal starts to rise before the 10-second mark when the stimulation actually began
  - this results in the exclusion of 21% of the fitting results in the original publication

## To summarize
Fitting Procedure Summary (Chen 2023 & Lambert 2020)

1. Voxel and Structure Selection Criteria
- Active Clusters: Initially identified using a cluster size threshold of > 5 voxels via GLM analysis.
- Structure Inclusion: A specific brain structure was included for a scan only if it contained more than 4 voxels (5 or more) showing a positive time course.
- Response Shape: Included voxels were required to have a BOLD amplitude of at least 0.6% and a decay of at least 40% following the maximum peak.
- Physiological Validity: The time to peak (tp) must be earlier than the time to the undershoot minimum (tu), and the difference between them must be less than or equal to 6 seconds (tp < tu AND tu - tp <= 6 s).

2. Stage 1: Individual Fitting (Per Scan/Region)
- Averaging: BOLD signals were averaged over the 20 stimulus repetitions for each qualifying brain structure within an individual functional measurement.
- Data Window: A 30-second time course (30 data points at TR = 1000ms):
  - 0–10s: Pre-stimulus baseline.
  - 10–20s: Active mechanical stimulation period.
  - 20–30s: Post-stimulus recovery and undershoot phase.
- Optimization: The MATLAB multistart function was used to find the global minimum for the fit, repeating the procedure for 40,000 different starting points per dataset.
- Parameter Limits (Canonical HRF):
  - A (Amplitude): [1]
  - b (Dispersion): [0.1, 5.0]
  - p1 (Peak timing): [2, 3]
  - p2 (Undershoot timing): [1, 4]
  - V (Peak/Undershoot ratio): [2, 5]
- Output: This stage generates one specific set of five parameters for every successful brain region fit in every functional scan.

3. Stage 2: Mean HRF Generation
- Normalization: Individual HRF curves resulting from the first stage were normalized to a maximum peak height of 1.0.
- Pooling: All normalized individual curves that passed quality control (e.g., 484 successful fits in the mouse study) were pooled and averaged to create a single mean species-specific curve.
- Final Parameter Extraction: The double-gamma mathematical model was fitted one final time to this grand-average mean curve. This final fit excludes the amplitude (A) to determine the canonical parameters (b, p1, p2, V) for the species.

4. Final Quality Control (Exclusion Criteria)
- Error Threshold: Fits were excluded if the Normalized Mean Squared Error (MSE) was greater than 0.1 for mice.
- Onset Check: Fits were rejected if the fitted curve showed an "early onset," meaning the BOLD signal began to rise prior to the 10-second mark when stimulation actually started.
- Limit Check: Fits were excluded if any of the optimized parameters were "stuck" at the extreme upper or lower search limits, indicating a failed optimization.