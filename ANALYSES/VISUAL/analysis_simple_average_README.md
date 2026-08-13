# analysis_simple_average — Event-Related Averaging HRF Analysis

Two MATLAB files implement the simple-average HRF analysis. The aim of this analysis is to assess the plausibility of the previously estimated canonical HRF in mice (Nunez-Elizalde 2022, Chen 2023, Lambers 2020) for the GLM analysis.

To do so, we extract the time course around the (visual) stimulus presentation and we average these time windows across trials and subjects. We do this only for those voxels and regions where the glm showed a substantial effect size in the initial GLM. 

Then we calculate the mean correlation ± sderr with the hrf convolved boxcar of the stimulus.

The time consuming part is the calculation of these results. We already reuse the results from the previous initial glm calculation, which informs about stimuli time courses, labels, and provides also the eta2 maps without the need to recalculate them.

All this is carried out by the `analysis_simple_average.m` function.

Once the results are calculated for each allen brain region where at least n voxels show a supra-threshold effect, we store the results in the `results_simple_average` directory.

From there, we can open the `analysis_simple_average_view_results.m` script and evaluate the two code chunks inside. 

- The first code chunk called `Similarity table` prints a text table of the regions with the highest correlation with the hrf (i.e. the hrf-convolved boxcar of the stimulus)

- The second chunk called `Single region plot` requires to specify one region and plots the average ± stderr empirical HRF against the canonical HRF.

Note that _not the time course of all trials ends in the average and related calculation of the correlation with the canonical hrf_. 
- A subject is included only if there are more than 3 stationary trials.
- A brain region is included only if it contains at least 5 voxels with supra-threshold eta2

Finally, before estimating the average and the correlation with the canonical HRF, all the time courses are smoothed with a sliding window of 5 sec to attenuate the noise. This reflects the procedure used in Lambers 2000 and Chen 2023 to estimate the canonical HRF.

<br>

**VERY IMPORTANT: IN ORDER TO RUN THESE SCRIPTS THE USER SHOULD HAVE ALREADY CARRIED OUT THE BASIC GLM ANALYSIS** which is implemented in the `analysis_visual_FONDUTA.m`

<br>


| File | Role |
|------|------|
| `analysis_simple_average.m` | MATLAB function — compute and save group results |
| `analysis_simple_average_view_results.m` | Interactive script — print table and plot results |

The old version of this analysis is archived in `OLE/analysis_simple_average_OLE.m`.

---

## Key design: reusing saved GLM results

`analysis_simple_average.m` reuses the per-session GLM result files
(`glm_*.mat`) produced by `analysis_visual_FONDUTA.m`. This avoids
re-fitting any GLM per subject.

Everything extracted directly from the saved GLM structs:
- `bmask`, `allen_regions` — brain mask and atlas region labels
- `eta2` map — used to select active voxels per region
- `predictor_labels` — used to auto-locate the visual stimulus predictor
- `predictors.stim_all` / `predictors.stim_stationary` — used to find
  trial onset frames (see **Important caveat** below)
- `dataPath`, `anatPath` — used to load the raw PDI time-series

The **only** data still loaded from disk per subject is the raw PDI
(`prepPDI.mat`), which is needed to extract the actual voxel time-series.

---

## `analysis_simple_average.m` — computation function

### Usage

```matlab
% Minimal call (all parameters at defaults):
% e.g. 
glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
model_name = 'M8_SteadyVisual'
analysis_simple_average(glm_results_path, model_name)

% With custom options:
analysis_simple_average(glm_results_path, model_name, opts)

% With no arguments — prints help text and returns immediately (nothing executed):
analysis_simple_average
```

### Batch example (run all models)

```matlab
glm_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
models   = {'M1_StimOnly', 'M3_SoftGlobalPC1', 'M7b_RunConv', 'M8_SteadyVisual'};
for k = 1:numel(models)
    analysis_simple_average(glm_path, models{k});
end
```

### To see available model names from a GLM file

```matlab
glm_path  = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
tmp_files = dir(fullfile(glm_path, 'glm_*.mat'));
tmp       = load(fullfile(tmp_files(1).folder, tmp_files(1).name));
fieldnames(tmp.data.models)
```

### Required inputs

| Input | Type | Description |
|-------|------|-------------|
| `glm_results_path` | string | Folder containing `glm_*.mat` files (one per session, saved by `analysis_visual_FONDUTA.m`) |
| `model_name` | string | Name of the GLM model whose `eta2` map is used for active-voxel selection. Must match a field of `glm.models`, e.g. `'M8_SteadyVisual'`, `'M1_StimOnly'`, `'M7b_RunConv'` |

### Optional `opts` struct fields

| Field | Default | Description |
|-------|---------|-------------|
| `opts.eta2_thresh_val` | `0.03` | Minimum eta² for a voxel to be considered active in a region |
| `opts.before_stim_onset` | `5` s | Baseline window before each trial onset |
| `opts.after_stim_offset` | `15` s | Post-stimulus window after each trial offset |
| `opts.min_stationary_trials` | `3` | Skip subject if fewer than this many trials are available |
| `opts.min_active_voxels` | `5` | Skip a region if it has fewer than this many active voxels |
| `opts.resultPath` | `pwd` | Parent folder for the `results_simple_average/` output subfolder |

### Output

Results are saved to:
```
<resultPath>/results_simple_average/simple_avg_<model_name>_<eta_str>.mat
```

where `eta_str = sprintf('eta%03d', round(eta2_thresh_val * 100))`, e.g.:
- `eta2_thresh_val = 0.03` → `eta003`
- `eta2_thresh_val = 0.05` → `eta005`

**The function skips saving if the output file already exists** and prints
a message. Delete the file to re-run.

### Saved `.mat` fields

| Field | Description |
|-------|-------------|
| `regional_avg` | Struct with one field per region (Allen acronym, made valid). Each field has `.tc [W × nSubs]`, `.acr`, `.name` |
| `atlas` | Full atlas struct (from `fonduta.atlas.load_atlas()`) |
| `model_name` | The model name used for active-voxel selection |
| `chaoyi_hrfParams` | HRF parameters for Chaoyi's a-priori reference curve |
| `chen2023_hrfParams` | HRF parameters for Chen 2023 a-priori reference curve |
| `eta2_thresh_val` | Active-voxel threshold used |
| `TR_mean` | Mean TR across subjects (seconds) |
| `stim_dur_s` | Mean stimulus duration across subjects (seconds) |
| `before_stim_onset` | Pre-onset window used (seconds) |
| `after_stim_offset` | Post-offset window used (seconds) |
| `W` | Epoch length in frames |
| `t_window` | Time axis in seconds (relative to onset = 0) |

---

## `analysis_simple_average_view_results.m` — interactive visualization

Open this file in the MATLAB editor and run each `%%` cell separately.

### Setup cell

Run first to add the required paths:
```matlab
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH)); addpath(genpath('.'));
```

### Part 2 — Similarity table

Loads a results `.mat`, computes the Pearson correlation of each region's
mean time course with the a-priori HRF responses (Chaoyi and Chen 2023),
and prints a sorted table filtered to regions above `sim_thresh`.

**Parameters to edit:**

| Parameter | Description |
|-----------|-------------|
| `mat_file` | Full path to a `simple_avg_*.mat` file |
| `sim_thresh` | Only show regions where Chaoyi mean r ≥ this value (default `0.7`) |
| `n_subject_thresh` | Only show regions present in ≥ this many subjects (default `5`) |
| `smooth_win_s` | Moving-average smoothing window in seconds applied before computing correlation (default `5`; set `0` to skip) |

**Output:** printed table sorted by Chaoyi r descending, with both
Chaoyi and Chen 2023 mean ± std columns.

### Part 3 — Single-region plot

Plots the group mean ± SE epoch for one region, with the a-priori Chaoyi
HRF reference curve overlaid (black dashed).

**Parameters to edit:**

| Parameter | Description |
|-----------|-------------|
| `mat_file` | Full path to a `simple_avg_*.mat` file |
| `target_acr` | Allen atlas acronym of the region to plot (pick from Part 2 table) |
| `smooth_win_s` | Moving-average smoothing in seconds (default `5`; set `0` to skip) |

---

## A-priori HRF reference curves

Both visualization cells use two double-gamma HRF kernels convolved with
a stimulus-duration boxcar as reference shapes:

| Name | Parameters `[d1 d2 b1 b2 r onset dur_s]` | Reference |
|------|-------------------------------------------|-----------|
| Chaoyi | `[2.4 8 0.8 0.9 6 0 16]` | Internal |
| Chen 2023 | `[4.95 8.69 1.1 1.1 1.8 0 32]` | Lambert 2020 / Chen 2023 |

The Chen 2023 curve is commented out in Part 3 by default; uncomment
`plot(S.t_window, ap_c23, 'r--', ...)` to show it.

---

## Important: M8 time-axis caveat

For `M8_SteadyVisual`, `analysis_visual_FONDUTA.m` fits the GLM on a
**temporally subsampled** dataset (running frames + ~16 s HRF tail
removed before fitting):

```matlab
stationaryFrames = ~runningFrameMask(:);
PDI_steady       = PDI.PDI(:, :, stationaryFrames);
M8_pred_steady   = hrf(stim_stationary(stationaryFrames));
```

As a consequence:

- `glm.models.M8_SteadyVisual.Xmodel` has length ~4571 (**subsampled** axis)
- `glm.predictors.stim_stationary` has length 6028 (**full** axis, matching raw PDI)

Using `Xmodel` to find trial onset frames would silently misalign every
epoch. `analysis_simple_average.m` always uses the **full-length**
`glm.predictors.stim_all` or `glm.predictors.stim_stationary` for onset
detection — never `Xmodel`.

### Model-dependent boxcar selection

| `model_name` contains | Boxcar used for onset detection |
|-----------------------|----------------------------------|
| `'Steady'` (case-insensitive) | `glm.predictors.stim_stationary` (stationary trials only) |
| anything else | `glm.predictors.stim_all` (all trials) |
