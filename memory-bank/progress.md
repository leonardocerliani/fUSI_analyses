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

### Interactive GLM Viewer — fonduta.viz.view_glm
**Status: Complete**

`view_glmfit.m` superseded and deleted. Replaced by two new files:

**`FONDUTA/+fonduta/+viz/view_design_matrix.m`** — standalone design matrix viewer.
- Usage: `fonduta.viz.view_design_matrix(data.models.M7b_RunConv)`
- Plots each column of `Xmodel` as stacked subplots with default MATLAB fonts/rotation

**`FONDUTA/+fonduta/+viz/view_glm.m`** — 3-column interactive viewer.
- Left column (0–18%): Model listbox → Predictor listbox → η² slider → region label
- Middle column (19–64%): η² overlay on atlas histology, vertical colorbar, `axis tight`
- Right column (65–98%): design matrix panel (stacked Xmodel subplots, 1/3 figure width)
  - Panel title: "Design matrix"
  - Formula text widget at top: `Y ~ pred1 + pred2 + ...` (updates on model change, avoids TeX `~` issue)
  - Selecting a different model updates both brain slice and design matrix simultaneously
- Figure: 1700×740 px

## In Progress
- `ANALYSES/VISUAL/analysis_HRF_CV_ridge.m` — ridge regression + HRF cross-validation

## Pending
- Build `ANALYSES/SHOCK/` pipeline using the same FONDUTA architecture
- Online documentation via MkDocs + GitHub Pages (deferred — MATLAB `help` works now)
- Future: split FONDUTA into its own git repo; reference from analysis repo via `FONDUTA_PATH`

## Known Issues / Notes
- `allen_brain_atlas.mat` is 70 MB — safe now, but consider Git LFS if atlas files grow
- Future split to separate FONDUTA repo: use as git submodule or simply set `FONDUTA_PATH`
