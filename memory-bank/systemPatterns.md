# System Patterns

## Repository Structure
```
fUSI_analyses/
├── 01_ANAT_REGISTRATION/       # Anatomical registration workflows
├── 02_RECON+PREPROC/           # Reconstruction and preprocessing
├── 03_ANALYSES/                # NEW: paradigm-specific analyses
│   ├── VISUAL/                 # Visual stimulation
│   └── SHOCK/                  # Shock/fear paradigm
├── AnalysisFcn/                # LEGACY: all original analysis functions
│   ├── Registration/           # Atlas & registration tools
│   ├── EmotionContagion/       # Emotion contagion experiment scripts
│   ├── fUSIMethodPaper/        # Methods paper scripts
│   ├── USS/                    # Ultrasound stimulation
│   ├── Utilities/              # Shared utility functions
│   ├── Madline/                # Student project scripts
│   ├── OldFiles/               # Deprecated scripts
│   └── Test/                   # Test/scratch scripts
├── ATLAS/                      # Atlas files (NIfTI, .mat)
├── UTILS/                      # NEW: shared utility functions
└── memory-bank/                # Project memory bank (this system)
```

## Core Data Structure: PDI Struct
The PDI (Power Doppler Imaging) struct is the universal data container:
```matlab
PDI.PDI          % 3D array [x × z × timepoints] — brain image time series
PDI.time         % [1 × T] time vector in seconds
PDI.stimInfo     % Stimulus information (startTime, endTime, stimCond)
PDI.wheelInfo    % Running wheel data (time, wheelspeed)
PDI.gmotion      % Global motion estimates (x, y, z)
PDI.bmask        % Brain mask [x × z] binary
PDI.savepath     % Output path for this subject
PDI.spatialSigma % Spatial smoothing parameter
PDI.voxelFrameRejection % Outlier rejection parameters
```

## Data Flow Pattern
```
Raw:    PDI.mat
        ↓ Preprocessing.m
Proc:   preprocPDI.mat  (or prepnormPDI.mat, MCprepPDI.mat — legacy naming)
        ↓ ConvertVoxelToROI.m
ROI:    ROIpreprocPDI.mat  (shape: nROIs × timepoints)
        ↓ Analysis (GLM, ISC, FIR, ICA)
Results: GLM/, ISC/, figures/
```

## Standard Preprocessing Pipeline (Preprocessing.m)
1. Load `PDI.mat` (raw)
2. Brain mask via `Atlas2Individual()` → `PDI.bmask`
3. (Optional) Rigid in-plane motion correction via `imregcorr`
4. Voxel-wise outlier rejection: z-score > 5σ → NaN → `fillmissingTime()`
5. Resample to 5 Hz via `resamplePDI()`
6. Temporal highpass filter: `DCThighpass(PDI.PDI, 5, 500)`
7. Normalize: z-score (`zscore()`) or percent-signal-change
8. Spatial smoothing: `imgaussfilt()` with σ=1 pixel

## Path Management Pattern
```matlab
[subDataPath, subAnatPath, resultPath] = Datapath(cond);
% cond ∈ {'VisualTest', 'ShockTest', 'SO', 'FR', 'SS', 'SOFC',
%          'SOcFOS', 'SOcFOSctl', 'VisualTestMultiSlice',
%          'USStimulation', 'ElectrodeTest', ...}
```
Data lives on Linux at `/data06/` (Emotion Contagion, Methods Paper) and `/data03/` (USS).
Windows paths map via `\\vs03\VS03-SBL-4` and `\\vs03\VS03-SBL-1`.

## Atlas Registration Pattern
```matlab
load('allen_brain_atlas.mat')    % → atlas struct
load('anatomic.mat')             % → anatomic struct
load('Transformation.mat')       % → Transf struct

% Individual fUSI space → Atlas space
atlasFrame = Individual2Atlas(atlas, anatomic, dataFrame, Transf);

% Atlas space → Individual fUSI space
subAtlas = Atlas2Individual(atlas, anatomic, Transf);
```

## Analysis Patterns

### GLM (voxel-wise or ROI-wise)
- Design matrix built from stimulus onsets convolved with HRF
- `hemodynamicResponse(TR, params)` generates HRF
- Running speed (`wheelSpeedConv`) included as nuisance regressor
- `fitglm()` or `FitGLMfUSI()` used for estimation

### ICA (Melodic via FSL)
- Data exported to NIfTI (`save_nifti`)
- FSL `melodic` called via `unix()`
- Components correlated with running/head-motion regressors for artifact identification

### ISC (Inter-Subject Correlation)
- `InterSubjectCorrelation2.m`, `InterSubjectFunctionalCorrelation.m`

### FIR Basis Set
- Finite Impulse Response for HRF estimation per voxel/ROI

## Key Design Decisions
- **Parallel processing**: `parfor` used for time-consuming atlas registration loops (requires Parallel Computing Toolbox)
- **File existence checks**: Always check `exist(...,'file')` before saving to avoid re-computation
- **`parsave()`**: Used instead of `save()` inside `parfor` loops to avoid parallel write conflicts
