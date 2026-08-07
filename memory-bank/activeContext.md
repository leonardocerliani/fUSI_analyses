# Active Context

## Current Focus
GLM viewer `fonduta.viz.view_glm` complete (3-column layout with design matrix panel).
Next session:
1. Add `uigetdir` to `view_glm.m` so the user can point it to any results directory at launch
2. Start FIR / CV ridge regression (`ANALYSES/VISUAL/analysis_HRF_CV_ridge.m`)

## What Was Built: FONDUTA Package

A reusable MATLAB toolbox (`FONDUTA/`) extracted from the visual GLM analysis.
Lives at `FONDUTA/+fonduta/` and is used by the orchestrator `ANALYSES/VISUAL/analysis_visual_FONDUTA.m`.

### Package Structure
```
FONDUTA/
├── +fonduta/
│   ├── +atlas/
│   │   ├── allen_brain_atlas.mat     ← atlas data file
│   │   ├── load_atlas.m              ← convenience loader: atlas = fonduta.atlas.load_atlas()
│   │   ├── build_brain_masks.m       ← calls load_atlas() internally
│   │   ├── atlas2individual.m        ← atlas → subject space
│   │   └── individual2atlas.m        ← subject → atlas space
│   ├── +glm/
│   │   ├── engine.m                  ← dispatches to ols.m
│   │   ├── ols.m                     ← OLS engine: accepts 3D PDI, returns remapped results
│   │   ├── prepare_data_matrix.m     ← [nx x ny x T] → [T x V]
│   │   ├── regress_out_nuisance.m
│   │   ├── remap_results.m           ← [* x V] → [* x nx x ny]
│   │   ├── remap_vec.m               ← [1 x V] → [nx x ny]
│   │   └── zscore_safe.m
│   ├── +io/
│   │   ├── parsave.m
│   │   └── +datapath/
│   │       ├── load_session.m        ← loads prepPDI.mat, anatomic.mat, Transformation.mat
│   │       └── save_results.m        ← saves GLMSes<isub>.mat
│   ├── +signal/
│   │   ├── hrf.m                     ← SPM double-gamma HRF kernel
│   │   └── compute_pc1.m
│   ├── +utils/
│   │   └── extract_pc1_signals.m     ← globalPC1, nonBrainPC1, YhardGlobalPC1
│   └── +viz/
│       ├── view_design_matrix.m      ← standalone design matrix viewer
│       └── view_glm.m                ← 3-column interactive viewer (brain + design matrix)
├── utils_ext/
│   └── BrunnerCodes/                 ← third-party registration tools (incl. interpolate3D.m)
└── README.md
```

**DELETED from FONDUTA:** `+fonduta/+io/+datapath/get_paths.m`
(was wrongly hardcoding session paths; Datapath.m lives in each analysis directory)

## fonduta.viz.view_glm — 3-column Interactive Viewer

### Usage
```matlab
fonduta.viz.view_glm('ANALYSES/VISUAL/glm_run-142136.mat')
```

### Layout (1700×740 px)
| Column | Position | Contents |
|--------|----------|---------|
| Left | 0–18% | Model listbox, Predictor listbox, η² slider, region label |
| Middle | 19–64% | η² map on atlas histology, vertical colorbar (`eastoutside`) |
| Right | 65–98% | Design matrix panel (1/3 figure width) |

### Middle column — brain slice (updateDisplay)
- `axis tight` + 5% margin expansion (same as original `view_glmfit`)
- Layers: atlas histology (gray) → η² overlay (hot, 80% opacity) → green borders (35%)
- Region border logic: morphological edges, IDs 0 & 1 suppressed
- Click-to-identify: `onAxesClick` → `subRegions(y,x)` → `atlas.infoRegions.name/acr`

### Right column — design matrix (updateDesignMatrix)
- `uipanel` with `uicontrol` text widget at top showing formula: `Y ~ pred1 + pred2 + ...`
  - **Important:** formula uses `uicontrol` text (not `uipanel.Title`) to avoid TeX `~` interpretation
  - `topMargin = 0.10` to leave room for formula widget above subplots
- Stacked `axes` inside panel, one per predictor (`Xmodel` column), default MATLAB fonts
- Updates when model changes (same callback as brain slice update)

### Key design notes
- `axis tight` (NOT `axis image`) for brain slice — matches expected stretch from original viewer
- `pDesign.Title` is static ("Design matrix"); formula is in `txtFormula.String`
- Do NOT set custom FontSize on ylabel or axes ticks — use MATLAB defaults

## Analysis Orchestrator Architecture

```
ANALYSES/VISUAL/
├── analysis_visual_FONDUTA.m    ← Main orchestrator
├── analysis_HRF_CV_ridge.m      ← Ridge regression / HRF cross-validation (IN PROGRESS)
├── Datapath.m                   ← Session path resolver (experiment-specific, stays here)
└── +fn/
    ├── build_stimulus_design.m
    ├── build_behavior_regressors.m
    └── detect_running_trials.m
```

### Key Design Principle: Datapath Separation
- `Datapath(condition)` is called directly in the orchestrator — NOT via FONDUTA
- FONDUTA has zero knowledge of session paths
- Each analysis directory owns its own `Datapath.m`

### hrf() anonymous function
```matlab
TR         = mean(diff(PDI.time));
hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
hrf        = @(ev) filter(hrf_kernel, 1, ev(:));
```

### fonduta.glm.ols() signature
```matlab
result = fonduta.glm.ols(model_name, PDI3D, bmask, X, predictor_labels)
```
- Accepts 3D `PDI.PDI [nx x ny x T]` directly
- Z-scores X internally (callers pass raw signals)
- Returns `.betas [p+1 x nx x ny]`, `.eta2 [p x nx x ny]`, `.R2 [nx x ny]`

## Results File Structure
```matlab
% GLMSes33.mat → res = tmp.data
res.models.M8_SteadyVisual.betas          % [p+1 x nx x ny]
res.models.M8_SteadyVisual.eta2           % [p x nx x ny]
res.models.M8_SteadyVisual.predictor_labels  % cell array
res.anatPath                               % path to anatomic.mat
res.Transf                                 % Transf.M = subject→atlas affine
res.bmask                                  % [nx x ny] brain mask
```

## Models Implemented (11 total)
| Name | Predictors |
|------|-----------|
| M1_StimOnly | `hrf(stim_all)` |
| M2_HardGlobalPC1 | `hrf(stim_all)` on `YhardGlobalPC1` |
| M3_SoftGlobalPC1 | `[hrf(stim_all), globalPC1]` |
| M4_SoftNonBrainPC1 | `[hrf(stim_all), nonBrainPC1]` |
| M5_Behavior | `[hrf(stim_all), wheel, hrf(wheel), hrf(stim_all.*wheel)]` |
| M6a_BehSoftGlobalPC1 | M5 + `globalPC1` |
| M6b_BehSoftNonBrainPC1 | M5 + `nonBrainPC1` |
| M6c_BehSoftBothPC1 | M5 + `globalPC1` + `nonBrainPC1` |
| M7a_RunSmooth | `[wheelSmooth, hrf(stim_all), hrf(wheel), hrf(stim_all.*wheel)]` |
| M7b_RunConv | `[hrf(wheel), hrf(stim_all), wheelSmooth, hrf(stim_all.*wheel)]` |
| M8_SteadyVisual | `hrf(stim_stationary)` on steady timepoints + correlation maps |

## Repository
- GitHub: `leonardocerliani/fUSI_analyses`
- `.gitignore` excludes: `chaoyi_data08/`, `memory-bank/tasks/`, `*.asv`, `*.m~`, `*.mlx~`, `.DS_Store`, `Thumbs.db`
- `allen_brain_atlas.mat` (70 MB) committed directly (under GitHub's 100 MB limit)

## Next Steps (next session)
1. Add `uigetdir` to `view_glm.m` — let user pick the results `.mat` file at launch (no hardcoded path)
2. Start FIR / CV ridge regression in `ANALYSES/VISUAL/analysis_HRF_CV_ridge.m`
3. Eventually build `ANALYSES/SHOCK/` using the same FONDUTA architecture
4. Future: split FONDUTA into its own git repo; reference via `FONDUTA_PATH`
