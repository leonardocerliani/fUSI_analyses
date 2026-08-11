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
- Both `plot_group_hrf_region` sections (FIR and ridge) now plot two canonical HRF references: Chen2023 (black dashed) and Chaoyi (dark red dashed `[0.6 0.2 0.1]`), each normalized to its own peak then scaled to `max(abs(mu))`

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

## Pending
- Build `ANALYSES/SHOCK/` pipeline using the same FONDUTA architecture
- Online documentation via MkDocs + GitHub Pages (deferred — MATLAB `help` works now)
- Future: split FONDUTA into its own git repo; reference from analysis repo via `FONDUTA_PATH`

## Known Issues / Notes
- `allen_brain_atlas.mat` is 70 MB — safe now, but consider Git LFS if atlas files grow
- Future split to separate FONDUTA repo: use as git submodule or simply set `FONDUTA_PATH`
