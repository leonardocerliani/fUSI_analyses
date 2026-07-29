# Product Context

## Why This Project Exists
Functional Ultrasound Imaging (fUSI) is a novel neuroimaging modality that measures brain hemodynamics (blood volume changes) at high spatial (~100 µm) and temporal (~10 Hz) resolution in awake, behaving rodents. The lab has accumulated a significant body of experimental data and analysis code across multiple projects. The existing codebase (`AnalysisFcn/`) grew organically and became difficult to maintain, extend, and share.

This repository is a **clean-slate refactoring** of that codebase with the goals of:
- Making analyses reproducible and understandable by other lab members
- Enabling reuse of core functions across different experiments
- Supporting new analysis paradigms with minimal friction

## Problems It Solves
1. **Fragmented scripts**: Legacy code lives in `AnalysisFcn/` as a mix of functions and scripts without clear organization. Different experiments had copy-pasted variants.
2. **Hard-coded paths**: `Datapath.m` hardcodes hundreds of subject/session paths; refactoring should enable more flexible path management.
3. **No separation of concerns**: Preprocessing, analysis, and visualization were mixed together in large scripts (e.g., `MainAnalysis.m`).
4. **Undocumented workflows**: It is unclear which scripts to run in which order for a given experiment.

## How It Should Work
The pipeline should follow a clear flow:

```
Raw Data (PDI.mat)
    ↓  [Preprocessing]
preprocPDI.mat (resampled, filtered, z-scored, spatially smoothed)
    ↓  [Atlas Registration]
ROI-based signals (ROIpreprocPDI.mat)
    ↓  [Analysis: GLM / ISC / ICA / FIR]
Results (.mat, figures)
```

Each experiment paradigm (Visual, Shock, EmotionContagion, USS) gets its own subfolder in `03_ANALYSES/`.

## User Experience Goals
- A new lab member should be able to run a complete analysis by following a README or script within a paradigm folder
- Functions should have clear MATLAB docstrings explaining inputs, outputs, and usage examples
- Results should be saved in organized subfolders, separate from raw data
- Code should be readable, not clever — favor clarity over brevity
