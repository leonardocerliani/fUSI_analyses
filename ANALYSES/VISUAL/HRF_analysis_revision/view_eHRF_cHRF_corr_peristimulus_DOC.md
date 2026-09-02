# `view_eHRF_cHRF_corr_peristimulus.m` — Documentation

## Motivation

> **Does the empirical HRF (eHRF), estimated per subject and per region via ridge regression, describe the trial-averaged peristimulus signal better than the canonical HRF (cHRF)?**

The cHRF is a deterministic prediction: convolution of the stimulus boxcar with the SPM double-gamma kernel. The eHRF is data-driven and free to take any shape. By correlating each subject's peristimulus signal with both templates and comparing those correlations with a paired t-test across subjects, the viewer identifies regions where one representation significantly outperforms the other.

---

## Input Files

| Variable | File pattern | Produced by |
|---|---|---|
| `eHRFData` | `results_ridge_loo/ridge_loo_<model>_eta003_HRF12s.mat` | `analysis_ridge_loo_ROI.m` |
| `cHRFData` | `results_simple_average/simple_avg_<model>_eta003.mat` | `analysis_simple_average.m` |

---

## Fields Used

### `eHRFData` (ridge LOO result)

| Field | Shape | Content |
|---|---|---|
| `regional_hrf.<ACR>.hrf` | `[K × nSub]` | **eHRF template.** Ridge regression betas = empirical HRF shape per subject, on the `lag_times_s` grid |
| `regional_hrf.<ACR>.acr/name` | string | Region acronym and full name |
| `lag_times_s` | `[1 × K]` | Time axis for ridge betas (s, onset = 0) |
| `TR_mean` | scalar | Mean TR across sessions (s) |
| `time_resampling` | scalar | FIR node spacing (s) |
| `before_stim_onset` | scalar | Pre-stimulus window (s) |
| `chaoyi_hrfParams` | `[1×7]` | SPM double-gamma parameters |

> `eHRFData.regional_avg` also exists (raw peristimulus average, used internally during ridge fitting) but is **not used** by this viewer.

### `cHRFData` (simple average result)

| Field | Shape | Content |
|---|---|---|
| `regional_avg.<ACR>.tc` | `[nTime_c × nSub]` | **Signal.** Trial-averaged, baseline-corrected peristimulus time course per subject |
| `regional_avg.<ACR>.acr/name` | string | Region acronym and full name |
| `TR_mean` | scalar | Mean TR (s) |
| `stim_dur_s` | scalar | Mean stimulus duration (s) |
| `before_stim_onset` | scalar | Pre-stimulus window (s) |
| `after_stim_offset` | scalar | Post-offset window (s) |
| `chaoyi_hrfParams` | `[1×7]` | Parameters used to build cHRF template on the fly |

---

## Computations

### 1. Canonical HRF template (built once, same for all regions/subjects)

```
boxcar        = [zeros(before_fr), ones(stim_fr), zeros(after_fr)]
cHRF_template = conv(boxcar, fonduta.signal.hrf(TR_c, chaoyi_hrfParams))(1:W_c)
```

### 2. Per-subject correlations (per region)

- **Signal:** `tc_c(:, s)` from `cHRFData.regional_avg`
- **eHRF template:** `hrf_e(:, s)` from `eHRFData.regional_hrf`, linearly interpolated onto the `tc_c` time grid
- **cHRF template:** `cHRF_template` interpolated onto the `tc_c` time grid

```
r_e(s) = corr( tc_c(:,s), hrf_e_interp(:,s) )   signal ~ subject's own eHRF
r_c(s) = corr( tc_c(:,s), chrf_interp       )   signal ~ canonical HRF
```

### 3. Fisher Z-transform and paired t-test

```
Z_e = atanh(clip(r_e, −0.99, 0.99))
Z_c = atanh(clip(r_c, −0.99, 0.99))

diff_vec = Z_e − Z_c   (direction "eHRF > cHRF")
         = Z_c − Z_e   (direction "cHRF > eHRF")

t_stat = ttest(diff_vec)
```

### 4. Map value

| Metric | Value |
|---|---|
| **Z score** | `t_stat` |
| **1 − p value** | `tcdf(t_stat, df)`. Values < 0.95 (p > 0.05) → `NaN` (transparent). |
| **Simple difference** | `mean(r_e − r_c)` or `mean(r_c − r_e)` |

---

## What the Viewer Shows

### Left panel — Brain map

Coloured overlay on Allen atlas coronal histology. Each anatomical region is coloured by its map value. Scroll to move through slices; click to select a region.

- `1 − p value`: `hot` colormap, CLim `[0.95, 1.00]`, sub-threshold transparent
- Other metrics: `parula`, symmetric CLim

### Right panel — Normalised time courses

Three curves plotted on a shared `[0, 1]` amplitude axis (all normalised via `(x−min)/(max−min)`):

| Curve | Colour | Source |
|---|---|---|
| **eHRF (Ridge)** | Blue solid | `mean(regional_hrf.<ACR>.hrf, 2)` on `lag_times_s` |
| **canonical HRF** | Red dashed | `conv(boxcar, hrf_kernel)` interpolated onto `lag_times_s` |
| **Simple avg** | Black dotted | `mean(regional_avg.<ACR>.tc, 2)` interpolated onto `lag_times_s` |

Light-blue patch marks the stimulus period; dotted lines mark onset and offset.

### Info bar

```
Voxel [x y z]  |  ACR -- Region name
t = X.XX  |  eHRF>cHRF: 1-p = 0.XXX  |  cHRF>eHRF: 1-p = 0.XXX
```

Both one-tailed `1 − p` values are always displayed.

---

## Controls

| Control | Effect |
|---|---|
| **Metric** radio | Z score / Simple difference / 1−p value |
| **Direction** radio | `eHRF > cHRF` or `cHRF > eHRF` |
| **Reload Model Files** | Re-loads `.mat` files |
| **Clear Overlays** | Removes overlay |
| **Lines ON/OFF** | Atlas region boundaries |
| **Smooth (s)** | Smoothing applied to `hrf_e` and `tc_c` before plotting |
| **Min / Max** | Manual colormap limit override |

---

## Script Relationships

```
analysis_ridge_loo_ROI.m   →  ridge_loo_*.mat    →  eHRFData.regional_hrf  (eHRF shape)
analysis_simple_average.m  →  simple_avg_*.mat   →  cHRFData.regional_avg  (peristimulus signal)
                                       ↓
               view_eHRF_cHRF_corr_peristimulus.m
```
