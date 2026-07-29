# Technical Context

## Primary Language
**MATLAB** — all analysis code is written in MATLAB (`.m` files). Some live scripts (`.mlx`) exist for exploratory work.

## MATLAB Toolboxes Required
- **Image Processing Toolbox** — `imgaussfilt`, `imregcorr`, `imwarp`, `imdilate`, `strel`
- **Statistics and Machine Learning Toolbox** — `fitglm`, `zscore`
- **Parallel Computing Toolbox** — `parfor` (used in atlas registration loops)
- **Signal Processing Toolbox** — `filter`, `envelope`

## MATLAB MCP Server
A MATLAB MCP (Model Context Protocol) server is available in this environment, enabling:
- Running MATLAB code directly: `ciCG6n0mcp0evaluate_matlab_code`
- Running MATLAB script files: `ciCG6n0mcp0run_matlab_file`
- Static code analysis: `ciCG6n0mcp0check_matlab_code`
- Detecting installed toolboxes: `ciCG6n0mcp0detect_matlab_toolboxes`

Use these tools to test and validate new MATLAB code during development.

## External Tools
- **FSL (melodic)** — called via `unix()` for ICA denoising; must be installed on the compute server
- **NIfTI tools** — `load_nifti` / `save_nifti` from `AnalysisFcn/Registration/freesurfer_matlab/` (FreeSurfer MATLAB tools)
- **Git** — version control for this repository

## Development Environment
- **OS**: Linux 5.15 (primary compute environment)
- **IDE**: Visual Studio Code with MATLAB extension + Cline
- **Shell**: Bash
- **Data storage**:
  - `/data06/` — Emotion Contagion and Methods Paper data
  - `/data03/` — USS (Ultrasound Stimulation) data
  - `/data08/fUSI/fUSI-Analysis` — original legacy codebase (reference only)
  - `/data00/leonardo/github/fUSI_analyses` — this repository (current working directory)

## File Formats
| Format | Description |
|--------|-------------|
| `.mat` | Primary data format — MATLAB binary for PDI structs, atlas, transformations |
| `.nii` / `.nii.gz` | NIfTI format — for FSL/melodic ICA; atlas volumes |
| `.csv` | Atlas region metadata (`divisions.csv`, `structures.csv`, `substructures.csv`) |
| `.mlx` | MATLAB Live Scripts — exploratory analysis notebooks |
| `.mexa64` | Compiled MATLAB MEX file — `freadcomplex.mexa64` for reading raw data |

## Key File Naming Conventions (Legacy)
| Filename | Description |
|----------|-------------|
| `PDI.mat` | Raw, unreconstructed PDI data |
| `prepPDI.mat` | Preprocessed PDI |
| `prepnormPDI.mat` | Preprocessed + z-score normalized |
| `MCprepPDI.mat` | Motion corrected + preprocessed |
| `preprocPDI.mat` | General preprocessed (used in EmotionContagion) |
| `ROI<name>.mat` | ROI-projected version of PDI |
| `anatomic.mat` | Anatomical B-mode ultrasound scan |
| `Transformation.mat` | Registration transformation (Transf struct) |
| `DispFieldI2A.mat` | Deformable displacement field (Individual→Atlas) |
| `allen_brain_atlas.mat` | Allen Brain Atlas struct with region labels |

## Data Path Structure (per subject/session/run)
```
/data06/.../sub-<ID>/ses-<date>/run-<time>/
    PDI.mat               ← raw functional data
    Functional/
        preprocPDI.mat    ← preprocessed functional
        ROIpreprocPDI.mat ← ROI-projected
    anatomic.mat          ← anatomical scan
    Transformation.mat    ← registration
    GLM/                  ← GLM results
```

## Dependencies Within AnalysisFcn/
Key functions that new code will likely call or replicate:
- `Datapath(cond)` — returns subject paths for a given condition
- `Individual2Atlas(atlas, anatomic, data, Transf)` — registers data to atlas space
- `Atlas2Individual(atlas, anatomic, Transf)` — inverse registration
- `hemodynamicResponse(TR, params)` — generates HRF
- `resamplePDI(PDI, targetHz)` — temporal resampling
- `DCThighpass(data, TR, cutoff)` — DCT-based highpass filter
- `fillmissingTime(data, method)` — interpolates NaN frames
- `parsave(path, data)` — `save()` wrapper safe for `parfor`
- `ConvertVoxelToROI(...)` — projects voxel data to atlas ROIs
