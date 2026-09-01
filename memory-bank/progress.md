# Project Progress

## Completed

### Visual GLM Pipeline — FONDUTA package + ANALYSES/VISUAL/
**Status: Implementation complete, committed to GitHub**

Full refactoring of `AnalysisFcn/fUSIMethodPaper/GLMVisual.m` into a clean, modular architecture split across a reusable toolbox (FONDUTA) and an experiment-specific analysis directory.

#### FONDUTA Package (`FONDUTA/+fonduta/`)
- `+atlas/load_atlas.m` — convenience loader: `atlas = fonduta.atlas.load_atlas()`
- `+atlas/build_brain_masks.m` — atlas → subject space brain mask
- `+atlas/atlas2individual.m`, `individual2atlas.m` — registration transforms
- `+glm/ols.m` — OLS engine (accepts 3D PDI, z-scores X internally, returns remapped maps)
- `+glm/prepare_data_matrix.m`, `remap_results.m`, `remap_vec.m`, `zscore_safe.m`, `regress_out_nuisance.m`, `engine.m`
- `+io/+datapath/load_session.m`, `save_results.m`
- `+signal/hrf.m`, `compute_pc1.m`
- `+utils/extract_pc1_signals.m`
- `utils_ext/BrunnerCodes/` — third-party registration tools (incl. `interpolate3D.m`)

#### Analysis Orchestrator (`ANALYSES/VISUAL/`)
- `analysis_visual_FONDUTA.m` — main orchestrator; calls `Datapath(condition)` directly
- `Datapath.m` — experiment-specific session path resolver (stays in analysis dir)
- `+fn/build_stimulus_design.m`, `build_behavior_regressors.m`, `detect_running_trials.m`

#### Architecture Principles
- `Datapath(condition)` called directly in orchestrator — FONDUTA has zero knowledge of session paths
- `hrf = @(ev) filter(hrf_kernel, 1, ev(:))` — TR from data; model specs read as formulas
- `fonduta.glm.ols()` z-scores X internally — callers pass raw signals
- Results in `glmresult.models.<ModelName>` (.betas, .eta2, .R2, .predictor_labels)
- 11 models: M1–M8 (including stationary, running, PC1 nuisance variants)

#### Repository
- GitHub: `leonardocerliani/fUSI_analyses`
- `.gitignore`: excludes `chaoyi_data08/`, `memory-bank/tasks/`, `*.asv`, `*.m~`, `*.mlx~`, `.DS_Store`, `Thumbs.db`
- `allen_brain_atlas.mat` (70 MB) committed directly

#### Bugs Fixed
- `fonduta.io.datapath.get_paths.m` — wrongly hardcoded session paths, deleted
- `atlas2individual.m` / `individual2atlas.m` — fixed `fonduta.utils.brunner.interpolate3D` → bare `interpolate3D` (from `utils_ext/BrunnerCodes/`)

### fonduta.glm — tstat and zstat added
**Status: Complete**

`engine.m` extended: computes `tstat [p x V]` and `zstat [p x V]` for each non-intercept predictor.
- `SE_j = sqrt(MSE * (X'X)^{-1}_{jj})` vectorized across all voxels
- `t_j = betas(j,:) ./ SE_j`
- `z_j = norminv(tcdf(t_j, df))` — note: numerically Inf for large df (T~6600); p-value computed as `2*normcdf(-|t|)` in viewer
- `remap_results.m` updated to remap both fields to `[p x nx x ny]`
- `ols.m` docstring updated
- **New results struct fields:** `.tstat`, `.zstat` (same shape as `.eta2`)

### Interactive GLM Viewer — fonduta.viz.view_glm
**Status: Complete (enhanced)**

`view_glmfit.m` superseded and deleted. Replaced by two new files:

**`FONDUTA/+fonduta/+viz/view_design_matrix.m`** — standalone design matrix viewer.
- Usage: `fonduta.viz.view_design_matrix(data.models.M7b_RunConv)`
- Plots each column of `Xmodel` as stacked subplots with default MATLAB fonts/rotation

**`FONDUTA/+fonduta/+viz/view_glm.m`** — 3-column interactive viewer.
- Left column (0–18%): Model listbox → Predictor listbox → **Stat dropdown** → Threshold slider → region/value label
- Middle column (19–64%): Stat map on atlas histology, vertical colorbar (black ticks), `axis tight`
- Right column (65–98%): design matrix panel (stacked Xmodel subplots, 1/3 figure width)
  - Panel title: "Design matrix"
  - Formula text widget at top: `Y ~ pred1 + pred2 + ...`
  - Selecting a different model updates both brain slice and design matrix simultaneously
- Figure: 1700×740 px

**Stat selector features:**
- Dropdown: `eta2 | R2 | betas | tstat | zstat`
- Per-stat threshold defaults: eta2/R2 → 0.05, betas → 0, tstat/zstat → 3.1
- Unsigned stats (eta2, R2): `hot` colormap; signed (betas/tstat/zstat): `bwr` (blue→white→red)
- R2 disables predictor listbox (model-level stat)
- Colorbar tick labels now visible (black, `cb.Color = [0 0 0]`)

**Click interaction:**
- Thin green crosshair at clicked voxel (replaces previous on next click)
- Bottom-left shows: region name, acronym, ID + `tstat = 28.432,  p = 2e-05`
- p-value via normal approximation `2*normcdf(-|t|)`; engineering notation for p < 0.001

## Completed (continued)

### Group FIR Analysis — `ANALYSES/VISUAL/analysis_FIR_group.m`
**Status: Complete**

Two-stage FIR analysis pipeline:

1. **Main loop** (Part 1): loops over all subjects; per subject runs M8 standard GLM → keeps only regions with η² > threshold → fits FIR design matrix (K lagged deltas) on ROI-averaged signals → stores per-region HRF betas and Pearson r with canonical HRF in `regional_hrf` struct → saves `.mat`.

2. **`plot_group_hrf`** section: loads results, computes mean ± std similarity for every region, prints sorted console table (✓ marks regions above `sim_thresh`), then plots a **bar chart** (one bar per region sorted descending) with error bars = ±std and red dashed threshold line. Subcount (`n=`) annotated above each bar. Workflow: run → pick acronym from table or bar chart.

3. **`plot_group_hrf_region`** section: loads results, takes `target_acr` string, prints per-subject similarity table, plots individual HRF traces (semi-transparent) + mean ± SE shaded band + canonical HRF (dashed black, amplitude-matched).

Saved output: `FIR_group_eta2_<thresh>_HRF_<dur>sec.mat`  
Fields: `regional_hrf`, `atlas`, `hrfParams`, `eta2_thresh_val`, `HRF_duration_s`, `TR_mean`, `lag_times_s`, `K`, `use_suprathreshold_voxels`

## Completed (continued)

### FIR Group Analysis — improvements (session 2026-08-11)

**`analysis_FIR_group.m` improvements:**
- Added `min_stationary_trials = 3` parameter; `continue` guard fires immediately after `detect_running_trials` if insufficient stationary trials → eliminates rank-deficient GLM warnings
- Per-subject `--- Sub X / N ---` separator printed at start of each loop iteration
- `n_subject_thresh` parameter added to `plot_group_hrf` bar chart; regions with fewer subjects are filtered before sorting/plotting
- `summary_stat` parameter in `plot_group_hrf_region`: `'mean'` → mean±SE, `'median'` → median±MAD (MATLAB `mad(H,1,2)`)
- Both `plot_group_hrf_region` sections (FIR and ridge) now plot two **convolved boxcar** references (stimulus boxcar ★ HRF, trimmed to K lags), not bare HRF kernels: Chen2023 (black dashed) and Chaoyi (dark red dashed `[0.6 0.2 0.1]`), each peak-normalized then scaled to `max(abs(mu))`
- **Conceptual fix**: FIR/ridge betas reflect response to the boxcar stimulus (not an impulse), so the correct reference is `conv(boxcar, hrf_kernel)` truncated to K lags. `stim_dur_s` is computed from `PDI.stimInfo.endTime - startTime`, saved to `.mat` as `stim_dur_s_saved`, and used in plot sections to reconstruct the boxcar. The `.sim` (Pearson r) in the main loop was also corrected to use this convolved reference.

### Ridge + LOO-CV HRF Analysis — `ANALYSES/VISUAL/analysis_ridge_loo_group.m`
**Status: Complete (tested, running successfully)**

Same pipeline as `analysis_FIR_group.m` but replaces OLS with ridge regression + leave-one-out cross-validation for λ selection.

**Key design:**
- LOO is over **trials** (not timepoints): `cvpartition(nTrials, 'LeaveOut')`
- Test frames = response window of held-out trial (onset : onset+K-1)
- Training frames = all timepoints NOT in the test window
- `lambda_grid = logspace(-2, 4, 20)` — 20 candidates; best λ selected per region per subject
- Final fit: `ridge(y, X_fir, lambda_best, 0)` (flag=0 = original-space betas)
- **MATLAB gotcha**: `ridge(..., 0)` returns `[K+1 × 1]` with intercept as first element → `B = B(2:end)` applied everywhere
- `T_safe = min(T, T_frames)` alignment before CV loop (stim vector and PDI may differ by 1 frame)
- Y_roi is z-scored before fitting (consistent with `engine.m`)
- Stores `.lam [1 × nSubs]` per region (best λ per subject) in addition to `.hrf` and `.sim`
- Output: `ridge_cv_group_eta2_<thresh>_HRF_<dur>sec.mat`
- Visualization sections identical to `analysis_FIR_group.m` (bar chart + per-region deep-dive, green color scheme)

### Simple-average HRF Analysis — `ANALYSES/VISUAL/analysis_simple_average.m`
**Status: Complete (tested, running successfully)**

Event-related averaging HRF estimation. Refactored into **3 local functions** at bottom of file + 3 cell sections at top. Each cell is self-contained — Parts 2 and 3 only load the `.mat`, no re-run of Part 1 needed.

**Pipeline (Part 1 / `run_group_analysis`):**
1. Standard GLM (M8, Chaoyi HRF) → `eta2_mask`; keep regions with ≥ `min_active_voxels` suprathreshold voxels
2. Mean signal of suprathreshold voxels → `y_roi [T×1]`
3. Per stationary trial: window anchored to onset: `t_start = onset − before_frames`, `t_end = t_start + W − 1` (always exactly W frames); baseline-correct; skip if out of bounds
4. Average across trials → `[W×1]` per subject per region; stored in `regional_avg.(field).tc [W × nSubs]`

**Window**: `before_stim_onset=5s` + `stim_dur_s` (~15s) + `after_stim_offset=15s`

**A priori responses** (Parts 2 & 3): boxcar convolved with Chaoyi HRF (black dashed) AND Chen2023 HRF (red dashed), each trimmed to W and normalised to peak=1 (scaled to `max(abs(mu))` in plot)

**Smoothing**: `smooth_win_s = 5` → `movmean(TC, 25, 1)` applied before correlation (Part 2) and before `mu`/`se` (Part 3). Set `smooth_win_s = 0` to skip.

**Part 2 / `plot_similarity_table`**: correlation table, sorted by Chaoyi r descending, **filtered to rows ≥ sim_thresh** (not just marked). Two extra columns: `Chaoyi r±std` and `Chen2023 r±std`.

**Part 3 / `plot_region`**: mean±SE shaded band (blue) + Chaoyi a priori (black dashed) + Chen2023 a priori (red dashed) + blue stimulus-on shading + onset/offset lines.

**Saved `.mat`**: `regional_avg`, `atlas`, `chaoyi_hrfParams`, `chen2023_hrfParams`, `eta2_thresh_val`, `TR_mean`, `stim_dur_s`, `before_stim_onset`, `after_stim_offset`, `W`, `t_window`

**Bugs fixed during development:**
- Epoch extraction: `t_end = offset_frames + after_frames` → `t_end = t_start + W - 1` (always exactly W frames, no `numel ~= W` rejection)
- `n_subject_thresh` filter was rejecting all regions when testing with 1 subject
- `sim_thresh` was only marking rows, not filtering them

### Simple-average HRF Analysis (v2) — `ANALYSES/VISUAL/analysis_simple_average_NEW.m`
**Status: Complete (implemented, pending end-to-end validation against real GLM .mat files)**

Refactor of `analysis_simple_average.m` that **reuses saved GLM results** (`glm_<runName>.mat`, produced by `analysis_visual_FONDUTA.m`) instead of re-fitting a GLM (M8) and re-detecting stationary trials per subject.

**What changed vs the old script:**
- No `Datapath` call — `run_group_analysis` globs `glm_*.mat` directly in `glm_results_path`
- `bmask`, `allen_regions` read directly from the GLM struct (no `build_slice_masks` call)
- `eta2` map for active-voxel masking comes from `glm.models.(model_name).eta2` — **any of the 11 already-fitted models** can be selected via a single new parameter `model_name` (e.g. `'M1_StimOnly'`, `'M7b_RunConv'`, `'M8_SteadyVisual'`), with zero re-fitting
- Visual-stimulus predictor row auto-located via `predictor_labels` containing `'stim'` (works for `'stim_hrf'` and `'stim_stationary_hrf'` alike)
- Still calls `fonduta.io.datapath.load_session(glm.dataPath, glm.anatPath)` — unavoidable, since raw voxel time-series are not stored in the GLM result, only derived stats

**Important gotcha discovered & documented prominently in the script header:**
`M8_SteadyVisual` is fit by `analysis_visual_FONDUTA.m` on a **temporally subsampled** dataset (running frames + ~16s HRF tail removed before fitting: `PDI_steady = PDI.PDI(:,:,stationaryFrames)`). Consequently `glm.models.M8_SteadyVisual.Xmodel` has a **different (shorter) length** (~4571) than `glm.predictors.stim_stationary` (6028, full/original axis matching raw `PDI.PDI`). Using `Xmodel` to find trial onsets would silently misalign every epoch. **Fix**: onset frames are always found via `find(diff([0; stim_box]) == 1)` on `glm.predictors.stim_all`/`stim_stationary` (never `Xmodel`).

**Model-dependent boxcar for onset detection:**
- `model_name` contains `'Steady'` → `glm.predictors.stim_stationary` (M8's purpose: response with negligible motion)
- any other model → `glm.predictors.stim_all` (all trials)

**Saved `.mat`**: same fields as v1 plus `model_name`. Parts 2 & 3 (correlation table, single-region plot) unchanged except titles now show `[model_name]`.

Old `analysis_simple_average.m` intentionally left untouched as a reference/fallback.

### Voxelwise FIR GLM — `ANALYSES/VISUAL/analysis_visual_FONDUTA_FIR.m`
**Status: Complete and validated (session 2026-08-17)**

Companion to `analysis_visual_FONDUTA_HRF.m`. Replaces HRF convolution with an FIR tent/boxcar basis, allowing the data to estimate the hemodynamic response shape directly. Three models: F1_StimOnly (≡ M1), F2_Behavior (≡ M5), F3_SteadyVisual (≡ M8).

**New files:**
- `ANALYSES/VISUAL/analysis_visual_FONDUTA_FIR.m` — batch script
- `ANALYSES/VISUAL/+fn/generate_fir_basis.m` — FIR basis builder (tent/boxcar via causal `filter()`)
- `ANALYSES/VISUAL/analysis_FIR_README.md` — full tutorial (Steps 0–7, F2_Behavior executable end-to-end)

**FONDUTA extensions:**
- `fonduta.glm.ols()`: 6th arg `contrasts` (struct array with `.name`, `.C`), 7th arg `skip_zscore` (default false)
- `fonduta.glm.engine()`: omnibus F-test from contrast matrix → `eta2_p`, `Fmap`, `df_effect`, `df_error` stored in `result.fcontrasts.<name>`
- `fonduta.glm.remap_results()`: remaps `fcontrasts` fields to [nx × ny]
- `fonduta.viz.view_glm`: (1) CLim NaN-guard prevents crash when all-NaN display map; (2) injects F-contrast maps as synthetic `[F] <name>` predictors at load time (in-memory only)

**Key design:**
- `stim_duration` auto-detected per session from `PDI.stimInfo`
- Window = `stim_duration + time_window_after_offset`; nodes = `round(W / time_resampling)`
- Continuous predictors centred before FIR expansion; `skip_zscore = true` for all FIR models
- Interaction term computed before FIR expansion: `stim_all .* wheel_c`

**Known limitation:** With fine `time_resampling` (< 2 s), adjacent tent columns are highly collinear → OLS individual betas oscillate wildly. The omnibus F-test (η²_p) is unaffected. For HRF shape estimation, ridge regression on ROI-averaged signals is needed (see Next Goal).

---

### FIR simulation + conceptual clarification — session 2026-08-19
**Status: Complete**

**`ANALYSES/VISUAL/FIR_ridge_simulation.m`** — interactive 6-cell script demonstrating HRF shape recovery.

Cells:
1. Setup & parameters (`TR`, `noise_std`, `time_resampling`, `smooth_win_s`, `onset_frames`, `lambda_grid`)
2. Simulated time course: sustained boxcar → HRF convolution + Gaussian noise
3. Both design matrices (onset-delta + boxcar) + imagesc + column correlation plots
4. OLS fit on both: shows onset-delta recovers HRF shape, boxcar does not
5. Ridge LOO-CV on onset-delta: clean, regularised HRF shape even with 5 trials
6. Lambda selection curve (LOO-CV MSE vs λ)

**Key fixes during development:**
- `hrf_gt` corrected: `conv(boxcar_one_trial, hrf_kernel)` sampled at node times (not bare HRF kernel) — for a sustained stimulus, the expected signal is the HRF integrated over the stimulus duration
- `smooth_win_s = 5` (s) added — `movmean` over `round(smooth_win_s/time_resampling)` nodes applied in Cells 4 & 5
- `step` → `node_step` renamed everywhere to avoid MATLAB Control Toolbox `step()` function collision

**`analysis_FIR_README.md` new section:** "Why the FIR boxcar basis cannot recover the HRF shape — and what to use instead" — ASCII column illustrations, collinearity explanation, summary table, simulation reference, recommended workflow.

**Conceptual insight now documented:**
- Boxcar FIR: each column active for 15 s → extreme collinearity → individual betas are FIR filter coefficients, not lag responses → **only valid for omnibus F-test / η² maps**
- Onset-delta: each column is 1 at exactly one frame per trial → non-overlapping → betas = average signal at each lag → **valid for HRF shape recovery**
- Ground truth for comparison: `conv(boxcar_one_trial, hrf)` not the bare HRF kernel

### `analysis_simple_average.m` — nuisance projection (session 2026-08-26)
**Status: Implemented, user running end-to-end validation**

Added `opts.nuisance_labels` to `ANALYSES/VISUAL/HRF_analysis_revision/analysis_simple_average.m`:
- Cell array of predictor label strings (e.g. `{'wheel','wheel_hrf','interaction_hrf'}`)
- Matched against `glm.models.(opts.model).predictor_labels` by label name (not column index)
- Projects out the matched Xmodel columns × betas from raw PDI before epoch-averaging
- Filename unchanged; `nuisance_labels` always saved in output `.mat` for self-documentation
- Backward compatible: default `{}` = original behaviour, no code path changes

Emergency backup at `analysis_simple_average_MRGNCY.m`.

## Pending
- Confirm `analysis_simple_average.m` nuisance projection end-to-end on real data
- Apply "reuse saved GLM results" pattern to `analysis_FIR_group.m` and `analysis_ridge_loo_group.m`
- Build `ANALYSES/SHOCK/` pipeline using the same FONDUTA architecture
- Online documentation via MkDocs + GitHub Pages (deferred — MATLAB `help` works now)
- Future: split FONDUTA into its own git repo; reference from analysis repo via `FONDUTA_PATH`

## Known Issues / Notes
- `allen_brain_atlas.mat` is 70 MB — safe now, but consider Git LFS if atlas files grow
- Future split to separate FONDUTA repo: use as git submodule or simply set `FONDUTA_PATH`
