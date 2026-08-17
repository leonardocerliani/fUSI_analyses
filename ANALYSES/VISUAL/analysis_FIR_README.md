# FIR Analysis — Visual Paradigm (`analysis_visual_FONDUTA_FIR.m`)

## What is FIR analysis?

A **Finite Impulse Response (FIR)** GLM estimates the hemodynamic response function (HRF) directly from the data, without assuming a fixed shape (like the double-gamma used in `analysis_visual_FONDUTA_HRF.m`).

Instead of convolving a predictor with a fixed HRF, the GLM asks: *"at each time lag t after stimulus onset, what is the average vascular response?"* The betas at lags t₁, t₂, …, t_N directly trace the HRF shape. Plotting them as a function of their corresponding lag time gives you the empirical HRF in seconds.

This script is a **companion to `analysis_visual_FONDUTA_HRF.m`** and fits three FIR models:

| FIR model | HRF equivalent | What it models |
|---|---|---|
| **F1\_StimOnly** | M1\_StimOnly | Visual stimulus only — all trials |
| **F2\_Behavior** | M5\_Behavior | Stimulus + wheel speed + interaction — all trials |
| **F3\_SteadyVisual** | M8\_SteadyVisual | Visual stimulus only — stationary frames only |

This tutorial walks through **F2\_Behavior** step by step — the full behavior model with stimulus, wheel speed, and their interaction as FIR predictors.

---

## FIR parameters: time window and model resolution

Standard fMRI packages (e.g. SPM, FSL) typically ask for two parameters when setting up a FIR model:
- **Time window**: the total duration of the response to model (in seconds)
- **Model order**: how many bins to divide that window into

We use a slightly different but equivalent parametrisation, motivated by our experimental design:

**Time window** — rather than specifying a single total duration, we split it into two parts:
- `stim_duration` — the stimulus-on duration. This is **auto-detected per session** from `PDI.stimInfo`, because it can vary across sessions or paradigms.
- `time_window_after_offset` — the time to model **after the stimulus ends**, to capture the hemodynamic recovery. This is user-specified (default: 12 s).

The total FIR window is `W = stim_duration + time_window_after_offset`.

**Model resolution** — instead of a model order (number of bins), we specify `time_resampling` (seconds per node). The number of nodes N is derived automatically:

```
N = round(W / time_resampling)
```

This is more intuitive when TR is very short (e.g. 0.2 s): with a 27 s window, one node per frame would require model order 135, whereas `time_resampling = 0.5 s` gives a manageable N = 54. The effect is the same: it defines how many bins are used to model each FIR predictor.

---

## Step 0 — Import FONDUTA and load one subject

```matlab
%% Step 0 — Setup and load one session
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
resultPath = pwd;

isub = 33;

[PDI, anatomic, Transf] = fonduta.io.datapath.load_session( ...
    subDataPath{isub}, subAnatPath{isub});

% Brain mask and Allen atlas region map (same space as PDI.PDI)
[bmask, nonBrainMask, allen_regions] = fonduta.atlas.build_slice_masks(anatomic, Transf);

% Frame acquisition time
TR = mean(diff(PDI.time));

% Auto-detect stimulus duration from this session's stimInfo
stim_durations = PDI.stimInfo.endTime - PDI.stimInfo.startTime;
stim_duration  = mean(stim_durations);
fprintf('TR = %.3f s  |  stim_duration = %.2f s  |  nTrials = %d\n', ...
    TR, stim_duration, numel(stim_durations));

% Build a binary stimulus boxcar for all trials
%   stim_all(t) = 1 whenever the stimulus is on, 0 otherwise
T_frames = numel(PDI.time);
stim_all = zeros(T_frames, 1);
for tr = 1:numel(PDI.stimInfo.startTime)
    on_idx  = find(PDI.time >= PDI.stimInfo.startTime(tr), 1, 'first');
    off_idx = find(PDI.time <= PDI.stimInfo.endTime(tr),   1, 'last');
    if ~isempty(on_idx) && ~isempty(off_idx)
        stim_all(on_idx:off_idx) = 1;
    end
end
fprintf('stim_all: %.1f%% frames active\n', 100*mean(stim_all));
```

After running this cell, the workspace contains: `PDI`, `bmask`, `allen_regions`, `TR`, `stim_duration`, `T_frames`, `stim_all`.

---

## Step 1 — Configure FIR window parameters

```matlab
%% Step 1 — FIR window parameters
time_window_after_offset = 12;     % seconds to model after stimulus offset
time_resampling          = 1;    % node spacing in seconds
basis_type               = 'tent'; % 'tent' (recommended) or 'boxcar'

W = stim_duration + time_window_after_offset;
N = round(W / time_resampling);
fprintf('FIR window: %.1f s  |  N = %d nodes  |  basis: %s\n', W, N, basis_type);
```

With the defaults and stim\_duration = 15 s: W = 27 s, N = 54 nodes. The nodes are centred at lags 0, 0.5, 1.0, …, 26.5 s after stimulus onset.

> **Collinearity and beta stability** — The choice of `time_resampling` involves a trade-off:
>
> - **Small `time_resampling`** (e.g. 0.5 s, N = 54): fine temporal resolution, but adjacent tent columns are highly correlated → OLS individual betas are wildly unstable (alternating sign, large variance). The **omnibus F-test is unaffected** by this collinearity — it tests the N betas *jointly* — but the individual beta time series cannot be trusted for HRF shape inspection.
>
> - **Large `time_resampling`** (e.g. 2 s, N = 14): fewer, more widely spaced nodes → less collinearity → stable, smooth individual betas → suitable for HRF shape inspection. The cost is coarser time resolution: with our very short TR (~0.2 s), using 2 s nodes means losing a lot of detail in the rising phase of the HRF.
>
> **Recommendation**: use `time_resampling = 0.5` (or even `= TR`) for voxelwise F-contrast maps (the main output of this analysis), and use a separate ROI-level analysis with ridge regression for clean HRF shape estimation (see below).

---

## Step 2 — Build wheel signal and centre continuous predictors

The F2\_Behavior model needs the wheel speed signal resampled to the fUSI frame rate. `fn.build_wheel_signal()` returns the raw speed, a smoothed variant, and a frame-level running mask (used in F3, not F2).

```matlab
%% Step 2 — Wheel signal and continuous predictor preparation

% HRF kernel (used internally by build_wheel_signal to build the running mask)
speedThresh = 35;   % wheel speed threshold (counts/s) for running classification
hrfParams   = [2.4  8  0.8  0.9  6  0  16];
hrf_kernel  = fonduta.signal.hrf(TR, hrfParams);

% Resample wheel speed to fUSI frame timestamps
[wheel, wheelSmooth, runningFrameMask] = fn.build_wheel_signal( ...
    PDI, speedThresh, hrf_kernel);
% wheel            [T × 1]  absolute speed in counts/s at each fUSI frame
% wheelSmooth      [T × 1]  Gaussian-smoothed speed
% runningFrameMask [T × 1]  logical; true at frames contaminated by running

% Centre wheel speed before FIR expansion (preserves 0 baseline during silence)
wheel_c = wheel - mean(wheel);

% Interaction: compute on pre-centred wheel speed, BEFORE FIR expansion
interaction = stim_all .* wheel_c;

fprintf('wheel_c: mean = %.4f (should be ~0)\n', mean(wheel_c));
```

> **Why centre continuous predictors?**
> FIR columns have exact zeros during silent periods. If a continuous predictor has a non-zero mean, its FIR columns also have a non-zero mean during silence — the intercept then absorbs part of the mean rather than the constant baseline, making the betas harder to interpret. Always centre before calling `fir()`.
>
> **Why compute interaction before FIR expansion?**
> The interaction is `stim_all .* wheel_c` — a point-wise product of two [T × 1] vectors, giving a [T × 1] modulated signal. FIR-expanding this product correctly models "how does the temporally lagged co-occurrence of stimulus and wheel speed predict the response?". Computing the product *after* expansion would mix up different lags.

---

## Step 3 — Build the FIR design matrix

The FIR operator expands any [T × 1] predictor into a [T × N] block of temporally lagged columns via **causal convolution**.

```matlab
%% Step 3 — FIR operator and design matrix blocks

fir = @(ev) fn.generate_fir_basis( ...
    ev, TR, stim_duration, time_window_after_offset, ...
    time_resampling, basis_type);

B_stim  = fir(stim_all);     % [T × N]  from binary stimulus boxcar
B_wheel = fir(wheel_c);      % [T × N]  from centred wheel speed
B_inter = fir(interaction);  % [T × N]  from pre-computed interaction

fprintf('FIR blocks: B_stim [%d×%d]  B_wheel [%d×%d]  B_inter [%d×%d]\n', ...
    size(B_stim,1), size(B_stim,2), ...
    size(B_wheel,1), size(B_wheel,2), ...
    size(B_inter,1), size(B_inter,2));
```

### What "causal" means

**Causal** in signal processing means the output at time t depends only on **past and present** values of the input — never on future values. This reflects the physical constraint that the hemodynamic response at frame t can only be driven by stimulus energy that occurred at or before t.

Column k of the FIR matrix is:
```
B(t, k) = sum_{j=0}^{W_frames} h_k(j × TR) × input(t − j)
```
where `h_k` is a basis kernel centred at lag t_k, and `input(t − j)` is the predictor j frames in the past. MATLAB's `filter(h_k, 1, input)` computes this efficiently for all time points at once.

### Tent basis functions

Each node uses a **tent** (triangular hat) kernel:
```
h_k(τ) = max(0, 1 − |τ − t_k| / time_resampling)
```
Adjacent tents overlap, so any smooth HRF shape can be represented as a weighted sum of tent responses. This is the same parametrisation as SPM's FIR implementation (Josephs & Henson, 1999, *Phil Trans R Soc B*; SPM12 manual, Chapter 15).

---

## Step 4 — Assemble the F2\_Behavior design matrix

F2 combines all predictors into one design matrix X. Note that `wheel_c` enters directly as a single column (not FIR-expanded) to capture the instantaneous linear effect of speed, while `B_stim`, `B_wheel`, and `B_inter` capture the lagged (hemodynamic) effects.

```matlab
%% Step 4 — Assemble F2_Behavior design matrix

% Full design: [B_stim | wheel_c | B_wheel | B_inter]
%   Column ranges (1-indexed, intercept is added automatically by the GLM engine):
%     stim FIR  : 1 .. N
%     wheel raw : N+1   (a single column — instantaneous speed)
%     wheel FIR : N+2 .. 2N+1
%     inter FIR : 2N+2 .. 3N+1
X_F2 = [B_stim, wheel_c, B_wheel, B_inter];   % [T × (3N+1)]

% Predictor labels (one per column of X_F2, NOT including intercept)
labels_stim  = arrayfun(@(k) sprintf('stim_fir_%02d',  k), 1:N, 'UniformOutput', false);
labels_wheel = arrayfun(@(k) sprintf('wheel_fir_%02d', k), 1:N, 'UniformOutput', false);
labels_inter = arrayfun(@(k) sprintf('inter_fir_%02d', k), 1:N, 'UniformOutput', false);
labels_F2    = [labels_stim, {'wheel_raw'}, labels_wheel, labels_inter];

fprintf('X_F2: [%d × %d]   labels: %d\n', size(X_F2,1), size(X_F2,2), numel(labels_F2));
```

---

## Step 5 — Define F-contrasts (omnibus tests)

A single FIR node's `eta2` is very small — each of N nodes explains only ~1/N of the total explained variance. The omnibus F-test asks: **do all N nodes of this predictor jointly explain significant variance?**

Each contrast matrix `C` has shape `[N × (p+1)]` where p = 3N+1 (total predictors, excluding intercept) and the last column (intercept) is always 0.

```matlab
%% Step 5 — F-contrast matrices for F2_Behavior

% Xfull = [X_F2 (3N+1 cols) | intercept (1 col)]  →  p+1 = 3N+2 columns total
p_F2           = 3*N + 1;
ncols_Xfull_F2 = p_F2 + 1;   % = 3N+2

% Contrast for stim FIR block (columns 1..N of Xfull)
C_F2_stim = zeros(N, ncols_Xfull_F2);
C_F2_stim(:, 1:N) = eye(N);

% Contrast for wheel FIR block (columns N+2..2N+1 of Xfull)
C_F2_wheel = zeros(N, ncols_Xfull_F2);
C_F2_wheel(:, (N+2):(2*N+1)) = eye(N);

% Contrast for interaction FIR block (columns 2N+2..3N+1 of Xfull)
C_F2_inter = zeros(N, ncols_Xfull_F2);
C_F2_inter(:, (2*N+2):(3*N+1)) = eye(N);

% Pack into struct array
contrast_F2(1).name = 'Visual_FIR';      contrast_F2(1).C = C_F2_stim;
contrast_F2(2).name = 'Wheel_FIR';       contrast_F2(2).C = C_F2_wheel;
contrast_F2(3).name = 'Interaction_FIR'; contrast_F2(3).C = C_F2_inter;

fprintf('Contrasts: %d defined  |  C size: [%d × %d]\n', ...
    numel(contrast_F2), size(C_F2_stim,1), size(C_F2_stim,2));
```

The F-statistic at each voxel tests whether the N FIR betas for that block are jointly non-zero:
```
F = (b_C' × (C × XtX⁻¹ × C')⁻¹ × b_C) / N / σ²
η²_p = (F × N) / (F × N + df_error)
```
This η²_p is directly comparable to the per-predictor η² in the HRF models.

---

## Step 6 — Fit the GLM

> [!NOTE]
> The code in this cell is very computationally intensive, since it's where the GLM is fitted to the FIR predictors. It might require 8-10 minutes to complete.

```matlab
%% Step 6 — Fit F2_Behavior FIR GLM
%
%   fonduta.glm.ols(model_name, PDI3D, bmask, X, labels, contrasts, skip_zscore)
%   skip_zscore = true   ← required for FIR (do NOT z-score the FIR columns)

result_F2 = fonduta.glm.ols( ...
    'F2_Behavior', PDI.PDI, bmask, ...
    X_F2, labels_F2, contrast_F2, true);

disp('F2_Behavior fitted. Fields:')
disp(fieldnames(result_F2))
% result_F2.betas    [(3N+2) × nx × ny]  — last row = intercept
% result_F2.eta2     [(3N+1) × nx × ny]  — per-node partial η² for each column
% result_F2.tstat    [(3N+1) × nx × ny]
% result_F2.zstat    [(3N+1) × nx × ny]
% result_F2.R2       [nx × ny]
% result_F2.fcontrasts.Visual_FIR       — omnibus F-test for stim block
% result_F2.fcontrasts.Wheel_FIR        — omnibus F-test for wheel block
% result_F2.fcontrasts.Interaction_FIR  — omnibus F-test for interaction block
```

### Why not z-score FIR columns?

FIR basis columns have exact zeros during silent periods. Z-scoring would shift those zeros to negative values and destroy the physical amplitude scale of the betas. The `skip_zscore = true` flag (7th argument) bypasses z-scoring in `fonduta.glm.engine`. The standard HRF models use `skip_zscore = false` (default) — the flag is fully backward-compatible.

---

## Step 7 — Assemble result struct and save

```matlab
% Build the glmresult struct (same format as the batch script output)
glmresult               = struct();
glmresult.dataPath      = subDataPath{isub};
glmresult.anatPath      = subAnatPath{isub};
glmresult.Transf        = Transf;
glmresult.bmask         = bmask;
glmresult.nonBrainMask  = nonBrainMask;
glmresult.allen_regions = allen_regions;

glmresult.predictors.stim_all   = stim_all;
glmresult.predictors.wheel      = wheel;
glmresult.predictors.wheel_centered = wheel_c;
glmresult.predictors.interaction    = interaction;

glmresult.fir_params.stim_duration            = stim_duration;
glmresult.fir_params.time_window_after_offset = time_window_after_offset;
glmresult.fir_params.time_resampling          = time_resampling;
glmresult.fir_params.basis_type               = basis_type;
glmresult.fir_params.N_nodes                  = N;
glmresult.fir_params.TR                       = TR;

glmresult.models.F2_Behavior = result_F2;

% Save — variable must be named 'data' for view_glm compatibility
outDir   = fullfile(resultPath, 'VisualTest');
if ~exist(outDir, 'dir'); mkdir(outDir); end

parts   = strsplit(subDataPath{isub}, '/');
parts   = parts(~cellfun(@isempty, parts));
runName = parts{end};

saveName = fullfile(outDir, sprintf('glm_%s_FIR_tutorial.mat', runName));
data = glmresult;   % variable must be named 'data' for view_glm compatibility
save(saveName, 'data');
fprintf('Saved: %s\n', saveName);

% Open in view_glm
fonduta.viz.view_glm(saveName);
```

---

## Viewing results in `fonduta.viz.view_glm`

```matlab
% Alternatively, open any saved FIR result directly:
fonduta.viz.view_glm('VisualTest/glm_run-142136_FIR_tutorial.mat')
```

`view_glm` automatically injects the F-contrast maps as extra entries in the Predictor listbox:

```
stim fir 01  ...  stim fir 54
[F] Visual FIR          ← omnibus F-test for stim block
wheel raw
wheel fir 01  ...  wheel fir 54
[F] Wheel FIR           ← omnibus F-test for wheel block
inter fir 01  ...  inter fir 54
[F] Interaction FIR     ← omnibus F-test for interaction block
intercept
```

- Select **`[F] Visual FIR`** + stat **`eta2`** → omnibus partial η² map for the stimulus (comparable to HRF model M5 stim eta2)
- Select **`[F] Wheel FIR`** + stat **`eta2`** → partial η² for running modulation
- Select **`stim fir 12`** + stat **`betas`** → HRF amplitude map at lag 12 × 0.5 s = 6 s post-onset

> **Tip:** Always use the `[F]` omnibus maps for region-level significance assessment. Individual per-node eta2 values are ~1/N of the total explained variance by design.

---

## Inspecting the estimated HRF shape

```matlab
%% Plot FIR-estimated HRF for primary visual cortex (VISp, Allen ID 669)

results = load('VisualTest/glm_run-142136_FIR_tutorial.mat').data

atlas = fonduta.atlas.load_atlas();

allen_ROI = 'RSPv'

N = results.fir_params.N_nodes;
time_resampling = results.fir_params.time_resampling;
stim_duration   = results.fir_params.stim_duration;
lag_times = (0 : N-1) * time_resampling;


% Extract stim FIR betas (rows 1..N of the full beta matrix)
betas_3d = results.models.F2_Behavior.betas;         % [(3N+2) × nx × ny]
betas_stim_2d = reshape(betas_3d(1:N,:,:), N, []);   % [N × nx*ny]

% Average across allen_ROI voxels within brain mask
idx_allen_region = find(strcmp(atlas.infoRegions.acr, allen_ROI))
roi_mask = (results.allen_regions == idx_allen_region) & results.bmask;
hrf_est  = mean(betas_stim_2d(:, roi_mask(:)), 2);   % [N × 1]

figure;
plot(lag_times, hrf_est, 'b-o', 'LineWidth', 2, 'MarkerSize', 4);
xline(stim_duration, '--r', 'Stim offset', 'LabelVerticalAlignment', 'bottom');
xline(0, ':k');
yline(0, ':k');
xlabel('Lag after stimulus onset (s)');
ylabel('Beta (stimulus-relative units)');
title(strcat('FIR-estimated HRF — ',allen_ROI));
```

---

## HRF interpretation and considerations

### The fUSI HRF is broader and slower than the BOLD HRF

The hemodynamic response in fUSI reflects **cerebral blood volume (CBV)**, not BOLD signal. CBV responses are generally:
- **Slower to peak**: ~3–5 s post-onset (arteriolar dilation)
- **Broader**: sustained longer due to venous compliance and capillary recruitment
- **Larger undershoot**: post-stimulus venous constriction

The FIR model can validate the HRF assumed in the convolution-based analysis. Compute the Pearson correlation between the FIR betas and the canonical kernel — high correlation (> 0.5) confirms the assumed HRF is a good match.

### Biphasic HRF: what it means

A **biphasic pattern** (first peak ~3–4 s, dip, second peak ~7–9 s) is **not** caused by:
- **Trial-to-trial overlap** (ISI ~45 s)
- **Stimulus offset** (occurs at ~15 s, well after the early peak)

Most likely explanations:
1. Genuine biphasic CBV response (arteriolar dilation + venous compliance)
2. Post-inhibitory neural rebound
3. Vascular rebound after undershoot

**Practical implication**: a unimodal double-gamma kernel will not capture the second lobe. Consider extending `time_window_after_offset` to characterise the full recovery.

---

## Running the full batch script

### Interactive

```matlab
cd /data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL
analysis_visual_FONDUTA_FIR
```

### Headless

```bash
cd /data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL

# nohup
nohup matlab -nodisplay -nosplash -r "analysis_visual_FONDUTA_FIR; exit" \
    > fir_analysis.log 2>&1 &
tail -f fir_analysis.log

# tmux
tmux new -s fir_analysis
matlab -nodisplay -nosplash -r "analysis_visual_FONDUTA_FIR; exit" 2>&1 | tee fir_analysis.log
# Ctrl+B D to detach  |  tmux attach -t fir_analysis to reattach
```

---

## Output file structure

Each session saved as `glm_<runName>_FIR.mat` (variable `data`):

```
data
├── dataPath, anatPath, Transf
├── bmask, allen_regions   [nx × ny]
├── predictors
│   ├── stim_all, stim_stationary
│   ├── wheel, wheel_centered, wheelSmooth, interaction
│   ├── runningFrameMask, globalPC1, nonBrainPC1
│   └── stationaryTrialIdx, runningTrialIdx
├── fir_params
│   ├── stim_duration  (s, auto-detected)
│   ├── time_window_after_offset, time_resampling, basis_type
│   ├── N_nodes, TR
└── models
    ├── F1_StimOnly      — fcontrasts: Visual_FIR
    ├── F2_Behavior      — fcontrasts: Visual_FIR, Wheel_FIR, Interaction_FIR
    └── F3_SteadyVisual  — fcontrasts: Visual_Steady_FIR
```

Each model contains: `.betas`, `.eta2`, `.tstat`, `.zstat`, `.R2`, `.Xmodel`, `.predictor_labels`, `.model_name`, `.fcontrasts`

Each fcontrasts entry contains: `.Fmap [nx×ny]`, `.eta2_p [nx×ny]`, `.df_effect`, `.df_error`

---

## Summary: FIR vs convolved GLM

| | HRF convolved GLM | FIR GLM |
|---|---|---|
| HRF assumed | Yes (double-gamma) | No |
| Columns per predictor | 1 | N (e.g. 54) |
| Betas | HRF amplitude | HRF shape at each lag |
| Significance test | t-test / η² per predictor | omnibus F-test across N nodes |
| Continuous predictors | Yes (z-scored) | Yes (centred, not z-scored) |

---

## References

- Josephs, O. & Henson, R.N.A. (1999). Event-related fMRI: modelling, inference and optimization. *Phil Trans R Soc B*, 354, 1215–1228. — tent basis functions for FIR in neuroimaging
- SPM12 manual, Chapter 15 — FIR model and `spm_get_bf`
- Chen, X. et al. (2023) — HRF parameters for fUSI / CBV data
- Lambert, B. et al. (2020) — fUSI hemodynamics reference
- [FIR on Andy's Brain Book](https://andysbrainbook.readthedocs.io/en/latest/FIR/FIR_Overview.html)
