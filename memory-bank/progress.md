# Project Progress

## Completed

### Visual GLM Pipeline — `03_ANALYSES/VISUAL/`
**Status: Implementation complete, awaiting testing**

Full refactoring of `AnalysisFcn/fUSIMethodPaper/GLMVisual.m` into a clean, modular architecture.

#### What was built:
- `analysis_visual.m` — main orchestrator with explicit model specifications
- `UTILS/glm.m` — single GLM engine (OLS, partial eta², R²)
- `UTILS/remap_glm_results.m` — voxel-vector → 2D spatial maps
- `UTILS/prepare_data_matrix.m` — PDI 3D → [T×V] matrix
- `UTILS/remap_vec.m` — correlation vector → 2D map
- `+io/load_session.m`, `+io/save_results.m`
- `+prep/build_brain_masks.m`, `+prep/detect_running_trials.m`
- `+model/build_stimulus_design.m`, `+model/build_behavior_regressors.m`, `+model/extract_pc1.m`
- All existing `UTILS/` helper functions (hemodynamicResponse, zscoreSafe, parsave, etc.)

#### Architecture principles applied:
- Single `glm()` engine — no repeated OLS/eta² boilerplate
- `hrf = @(ev) filter(hrf_kernel, 1, ev(:))` — TR captured from data, no parameter passing
- Model specifications fully visible in orchestrator: `M5_predictors = [hrf(stim_all), wheel, hrf(wheel), hrf(stim_all.*wheel)]`
- `glm()` z-scores internally — callers pass raw signals
- Results in `glmresult.models.<ModelName>` (sub-struct per model)
- Saved separately from `prepPDI.mat` as `GLMSes<isub>.mat`

## In Progress
- Testing `analysis_visual.m` on one subject

## Pending
- Build `03_ANALYSES/SHOCK/` pipeline using the same architecture
- Memory bank task file update for refactor_GLMVisual task

## Known Issues / Notes
- `+model/build_stimulus_design.m` still computes HRF convolutions internally (not used by orchestrator anymore — only boxcars and metadata are used). Could be simplified in a future cleanup pass.
- `hrf` anonymous function variable is created fresh each session loop iteration (captures session-specific TR).
