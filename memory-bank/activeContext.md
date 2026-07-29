# Active Context

## Current Focus
Visual GLM analysis pipeline (`03_ANALYSES/VISUAL/`) — refactoring complete, awaiting user testing on one subject.

## What Was Built
A complete, clean GLM analysis pipeline for the visual stimulation paradigm. The architecture follows the ALTERNATIVE_Analysis_MethodPaper pattern: one `glm()` engine, model specifications visible in the orchestrator.

## Final Architecture (03_ANALYSES/VISUAL/)

```
analysis_visual.m       ← Main orchestrator (run from this directory)
Datapath.m              ← Path resolver for all conditions

UTILS/
  glm.m                 ← Single GLM engine (z-scores X internally)
  remap_glm_results.m   ← [* x V] → [* x nx x ny] spatial maps
  prepare_data_matrix.m ← [nx x ny x T] → [T x V], brain voxels only
  remap_vec.m           ← [1 x V] → [nx x ny] for correlation maps
  hemodynamicResponse.m ← SPM double-gamma HRF kernel
  zscoreSafe.m          ← Z-score columns; constant → zero (not NaN)
  parsave.m             ← Save wrapper safe for parfor
  computePC1FromMask.m  ← Extract z-scored PC1 from masked voxels
  regressOutNuisance.m  ← Regress nuisance from Y matrix

ATLAS/
  allen_brain_atlas.mat
  Atlas2Individual.m

+io/
  load_session.m        ← Loads prepPDI.mat, anatomic.mat, Transformation.mat
  save_results.m        ← Saves GLMSes<isub>.mat via parsave

+prep/
  build_brain_masks.m   ← Atlas-based bmask + dilated nonBrainMask
  detect_running_trials.m ← bwconncomp-based running classification

+model/
  build_stimulus_design.m     ← Raw boxcars (stimVisual, stimVisualRunning) + trial metadata
  build_behavior_regressors.m ← wheel speed signals + steadyExcludeMask
  extract_pc1.m               ← globalPC1, nonBrainPC1, YhardGlobalPC1
```

**Deleted:** `+glm/` package (8 files), `+model/assemble_predictors.m`

## Key Design Decisions

### hrf() anonymous function
```matlab
TR         = mean(diff(PDI.time));          % computed from data
hrf_kernel = hemodynamicResponse(TR, hrfParams);
hrf        = @(ev) filter(hrf_kernel, 1, ev(:));
```
Predictor lines then read as formulas:
```matlab
M5_predictors = [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all .* wheel)];
```

### glm() signature
```matlab
results = glm(model_name, Y, X, predictor_labels)
```
- `Y`: `[T x V]` from `prepare_data_matrix()`
- `X`: raw signals (NO pre-z-scoring required; `glm.m` calls `zscoreSafe(X)` internally)
- Intercept auto-appended as last column
- Returns `.betas [p+1 x V]`, `.eta2 [p x V]`, `.R2 [1 x V]`

### Partial eta² formula (reduced-model approach)
```matlab
eta2_j = max(0, SSE_reduced_j - SSE_full) / (max(0, SSE_reduced_j - SSE_full) + SSE_full)
```

### Result structure
```matlab
glmresult.models.M1_StimOnly       % .betas, .eta2, .R2, .predictor_labels
glmresult.models.M2_HardGlobalPC1
...
glmresult.models.M8_SteadyVisual   % + .corrAll, .corrSteady
```
Saved per session as `GLMSes<isub>.mat` (variable `data`).

## Models in analysis_visual.m
| Name | Predictors |
|------|-----------|
| M1_StimOnly | `hrf(stim_all)` |
| M2_HardGlobalPC1 | `hrf(stim_all)` on `Y_hardPC1` |
| M3_SoftGlobalPC1 | `[hrf(stim_all), globalPC1]` |
| M4_SoftNonBrainPC1 | `[hrf(stim_all), nonBrainPC1]` |
| M5_Behavior | `[hrf(stim_all), wheel, hrf(wheel), hrf(stim_all.*wheel)]` |
| M6a_BehSoftGlobalPC1 | M5 + `globalPC1` |
| M6b_BehSoftNonBrainPC1 | M5 + `nonBrainPC1` |
| M6c_BehSoftBothPC1 | M5 + `globalPC1` + `nonBrainPC1` |
| M7a_RunSmooth | `[wheelSmooth, hrf(stim_all), hrf(wheel), hrf(stim_all.*wheel)]` — wheelSmooth first |
| M7b_RunConv | `[hrf(wheel), hrf(stim_all), wheelSmooth, hrf(stim_all.*wheel)]` — wheel_hrf first |
| M8_SteadyVisual | `hrf(stim_stationary(includeSteady))` on `Y_steady` + correlation maps |

## Next Steps
1. **User will test** `analysis_visual.m` step-by-step for one subject
2. Fix any issues that arise during testing
3. Eventually build `03_ANALYSES/SHOCK/` using the same architecture
