# Active Context

## Current Focus
FONDUTA package — stable. New interactive GLM viewer `fonduta.viz.view_glmfit` built and polished.
Next session: ridge regression / HRF CV analysis (`ANALYSES/VISUAL/analysis_HRF_CV_ridge.m`).

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
│       └── view_glmfit.m             ← Interactive eta2 viewer on Allen Atlas (NEW)
├── utils_ext/
│   └── BrunnerCodes/                 ← third-party registration tools (incl. interpolate3D.m)
└── README.md
```

**DELETED from FONDUTA:** `+fonduta/+io/+datapath/get_paths.m`
(was wrongly hardcoding session paths; Datapath.m lives in each analysis directory)

## fonduta.viz.view_glmfit — Interactive Viewer

### Usage
```matlab
fonduta.viz.view_glmfit('ANALYSES/VISUAL/GLMSes33.mat')
```

### Architecture
- Loads results file (`res.data`), loads atlas, maps atlas → subject space once via `atlas2individual`
- Displays the functional slice (`anatomic.funcSlice(3)`) of the registered atlas histology
- All display layers are `[nr × nc]` (subject-space functional slice size), pixel-aligned
- Data is `flipud`-ed for correct dorsal-up orientation

### Left-column controls
| Panel | Widget | Function |
|-------|--------|----------|
| Model | listbox | select model; predictor list auto-rebuilds |
| Predictor | listbox | select predictor from current model |
| η² threshold | slider 0–0.5 (default 0.05) | hide eta2 voxels below threshold |
| Region label | text (yellow) | shows name/acronym/ID on click |

### Display layers (updateDisplay)
1. Atlas histology (gray): `cat(3, subHisto, subHisto, subHisto)` — grayscale RGB
2. eta2 overlay (hot colormap, 80% opacity): `mdata.eta2(curPred,:,:)`, flipud, threshold applied
3. Region borders (green, 35% opacity): morphological edges excluding IDs 0 & 1

### Region border logic (IDs 0 and 1 suppressed)
```matlab
se           = strel('diamond', 1);
subReg_named = subRegions;
subReg_named(subReg_named <= 1) = 0;
borders = (imdilate(subReg_named, se) ~= imerode(subReg_named, se)) & ...
          (subReg_named > 0) & ...
          (imerode(subReg_named, se) > 0);
```

### Title / labels
- Title: `'Interpreter', 'none'` + `strrep(..., '_', ' ')` to avoid LaTeX rendering
- Panel titles: `FontSize 14, FontWeight bold` for visibility on dark background

### Click identification
- `onAxesClick` reads `subRegions(y, x)` (already flipud)
- Looks up `atlas.infoRegions.name{rId}` and `atlas.infoRegions.acr{rId}`

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
1. Continue `ANALYSES/VISUAL/analysis_HRF_CV_ridge.m` — ridge regression + HRF cross-validation
2. Eventually build `ANALYSES/SHOCK/` using the same FONDUTA architecture
3. Future: split FONDUTA into its own git repo; reference via `FONDUTA_PATH`
