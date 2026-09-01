# Active Context

## Current Focus

### `analysis_simple_average.m` — nuisance projection feature (session 2026-08-26)

**File:** `ANALYSES/VISUAL/HRF_analysis_revision/analysis_simple_average.m`
**Emergency backup:** `analysis_simple_average_MRGNCY.m` (made by user before edits)

#### What was added

New optional field `opts.nuisance_labels` (default `{}`):
- A cell array of predictor label strings drawn from `glm.models.(opts.model).predictor_labels`
- Specifies which columns of the saved `Xmodel` (z-scored design matrix) to project OUT of the raw PDI signal before epoch-averaging
- **Always uses the same model** for eta2 map, Xmodel, and betas — never cross-model mixing

#### Back-projection math (exact, no re-fitting)

```matlab
% Xnuis  [T × n_nuis]  — columns of model_result.Xmodel matching nuisance_labels
% Bnuis  [n_nuis × V]  — corresponding rows of model_result.betas (z-scored-predictor units)
Y_clean = Y - Xnuis * Bnuis;   % [T × V]
```

Both `Xmodel` and `betas` are already stored in compatible units in the `.mat` file — no re-z-scoring needed.

#### Key design decisions
- **Filename unchanged**: always `simple_avg_<model>_<eta_str>.mat` regardless of nuisance settings
- **`nuisance_labels` always saved** in the `.mat` file (`{}` when no cleaning applied) — user can inspect after loading
- **Validation**: missing labels trigger a per-session warning + fallback to raw signal (no crash)
- **`do_nuisance` flag** computed once at the top; `PDI_data` variable holds either cleaned or raw signal; the ROI loop uses `PDI_data` throughout

#### Usage example
```matlab
opts.model           = 'M5_Behavior';
opts.nuisance_labels = {'wheel', 'wheel_hrf', 'interaction_hrf'};
% stim_hrf is NOT listed → stays in signal
% intercept is never listed → not a column of Xmodel
opts.eta2_thresh_val = 0.03;
opts.resultPath      = '/path/to/results';
analysis_simple_average(glm_path, opts);
```

#### GLM result structure (reference)
```
glm.models.M5_Behavior
    .betas            [5 × nx × ny]   rows: stim_hrf, wheel, wheel_hrf, interaction_hrf, intercept
    .Xmodel           [T × 4]         z-scored design matrix (no intercept column)
    .predictor_labels {'stim_hrf' 'wheel' 'wheel_hrf' 'interaction_hrf' 'intercept'}
    .eta2             [4 × nx × ny]
```

---

### FIR simulation + conceptual clarification (session 2026-08-19)

**`ANALYSES/VISUAL/FIR_ridge_simulation.m`** — interactive 6-cell simulation demonstrating HRF shape recovery.

**Purpose:** Illustrate why the sustained-boxcar FIR design (used in `analysis_visual_FONDUTA_FIR.m`) cannot recover the HRF shape, and why the onset-delta + temporal shifts approach does.

**Key conceptual distinction now documented in `analysis_FIR_README.md`:**

| | FIR boxcar basis (`fn.generate_fir_basis`) | Onset-delta basis |
|---|---|---|
| Column k is | Sustained block shifted by k | Single spike at onset + k |
| Columns overlap? | Yes — highly collinear | No — non-overlapping |
| Beta k means | FIR filter coefficient | Average signal at lag k |
| Good for | F-test / η² maps (joint test) | HRF shape recovery |
| Bad for | HRF shape (individual betas) | F-test (too sparse for OLS) |

**Column structure (ASCII, for reference):**
```
Boxcar:     1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0   (15 s on, highly collinear)
Boxcar+1s:  0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0

Onset-delta:  1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0   (sparse, non-overlapping)
Delta+1s:     0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0   (5 frames = 1 s at TR=0.2 s)
```

**Ground-truth reference:** `conv(boxcar_one_trial, hrf)` sampled at node times — NOT the bare HRF kernel. For a sustained 15 s stimulus, the expected signal is the integral of the HRF over the stimulus, not the impulse response.

**Fixes applied to `FIR_ridge_simulation.m` (session 2026-08-19):**
- `hrf_gt` corrected: now uses `conv(boxcar_one_trial, hrf_kernel)` sampled at node times
- `smooth_win_s = 5` (s) parameter added — `movmean` applied to betas in Cells 4 and 5 before r and plot
- `step` renamed to `node_step` everywhere to avoid MATLAB Control Toolbox `step()` collision
- `stim_dur_s` line cleaned (had stray `close all` appended)

**`analysis_FIR_README.md` additions (session 2026-08-19):**
New section **"Why the FIR boxcar basis cannot recover the HRF shape — and what to use instead"** inserted after "Inspecting the estimated HRF shape":
- ASCII column-structure illustration
- Explanation of why collinearity destroys individual betas but not the omnibus F-test
- Summary table
- Points to `FIR_ridge_simulation.m` cells 3–5 for live demonstration
- Recommended workflow: boxcar FIR for η²/F maps; onset-delta + ridge for HRF shape

**Recommended workflow (now clearly documented):**
- **Voxelwise maps** (η², F-stat): `analysis_visual_FONDUTA_FIR.m` with `fn.generate_fir_basis` — boxcar F-test detects *which* regions respond
- **HRF shape recovery**: `analysis_ridge_loo_ROI.m` — onset-delta + ridge LOO-CV on ROI-averaged signals

---

## File Structure (current)

```
ANALYSES/VISUAL/
├── analysis_visual_FONDUTA_HRF.m       ← Standard GLM, 11 models (M1–M8)
├── analysis_visual_FONDUTA_FIR.m       ← Voxelwise FIR GLM (F1–F3), boxcar basis, F-tests
├── analysis_ridge_loo_ROI.m            ← ROI-level HRF shape recovery (onset-delta + ridge LOO-CV)
├── analysis_ridge_loo_ROI_view_results.m
├── FIR_ridge_simulation.m              ← Simulation: boxcar vs onset-delta, OLS vs ridge
├── analysis_FIR_README.md              ← FIR tutorial (Steps 0–7 + HRF shape section)
├── HRF_Chen2023_Lambert2020.md
├── show_hrf_kernel.m
├── sketch.m
├── +fn/
│   ├── build_visual_predictors.m
│   ├── build_wheel_signal.m
│   ├── detect_running_trials.m
│   └── generate_fir_basis.m
└── HRF_analysis_revision/              ← active development subdirectory
    ├── analysis_simple_average.m           ← Event-related averaging (+ nuisance_labels feature)
    ├── analysis_simple_average_MRGNCY.m    ← Emergency backup (pre-nuisance edits)
    ├── analysis_simple_average_parallel.m
    ├── analysis_simple_average_view_results.m
    ├── view_simple_average_results.m
    ├── analysis_simple_average_generate_allen_map.m
    ├── analysis_simple_average_README.md
    ├── calculate_mean_eta2_maps.m
    ├── eta2_mean_maps/
    ├── results_simple_average/
    └── results_ridge_loo/
```

---

## FONDUTA Package — Current State

```
FONDUTA/+fonduta/
├── +atlas/     load_atlas, atlas2individual, individual2atlas, build_slice_masks, build_brain_masks
├── +glm/       engine (F-contrasts ✓), ols (skip_zscore ✓), remap_results (fcontrasts ✓), ...
├── +io/        parsave, +datapath/
├── +signal/    hrf, compute_pc1
├── +utils/     extract_pc1_signals, tree_struct
└── +viz/       view_glm (F-injection ✓, CLim NaN-guard ✓), view_design_matrix, view_image, view_registration
```

### fonduta.glm.ols() — current signature
```matlab
result = fonduta.glm.ols(model_name, PDI3D, bmask, X, predictor_labels)
result = fonduta.glm.ols(model_name, PDI3D, bmask, X, predictor_labels, contrasts)
result = fonduta.glm.ols(model_name, PDI3D, bmask, X, predictor_labels, contrasts, skip_zscore)
```
- `contrasts`: struct array with `.name` and `.C` fields; each C is `[N_rows × (p+1)]`
- `skip_zscore`: logical (default false); pass `true` for FIR models

### Key Design Principle: Datapath Separation
- `Datapath(condition)` called directly in orchestrators — FONDUTA has zero knowledge of session paths
- Each analysis directory owns its own `Datapath.m`
