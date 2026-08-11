# FIR Analysis — Visual Paradigm (Stationary Trials)

## What is FIR analysis?

A **Finite Impulse Response (FIR)** GLM is used to estimate the hemodynamic response function (HRF) directly from the data, without assuming a fixed shape (like the double-gamma used in `analysis_visual_FONDUTA.m`).

The idea: instead of convolving a predictor with a fixed HRF, we ask the GLM "at each time lag k after stimulus onset, what is the average BOLD response?" The betas at lags k = 0, 1, 2, ..., K directly trace out the HRF shape. Plotting them as a function of `k * TR` gives you the empirical HRF in seconds.

---

## From binary stimulus vector to FIR design matrix

### Step 1 — Extract onset times

`stim_stationary` is a binary vector (0 = no stimulus, 1 = stimulus on). For FIR we only need the **onset frame** of each trial — a single impulse per trial, not the full duration:

```matlab
% Find onset and offset frame indices
onsets  = find(diff([0; stim_stationary(:)]) ==  1);   % rising edges
offsets = find(diff([stim_stationary(:); 0]) == -1);   % falling edges

% Duration in frames and seconds
durations_in_frames  = offsets - onsets + 1;
durations_in_seconds = PDI.time(offsets) - PDI.time(onsets);
```

The **onset delta** vector has a single 1 at each trial start:

```
stim_stationary:  0 0 0 1 1 1 1 1 1 0 0 0 1 1 1 1 1 1 0 0 0
onset_delta:      0 0 0 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0
```

> **Why onset delta and not the full boxcar?**
>
> Approach 1 — **onset delta (standard FIR)**: the betas at each lag directly give you "average response k frames after onset" → they trace the HRF shape unambiguously.
>
> Approach 2 — **lagged boxcar**: betas are harder to interpret because each lag captures the marginal effect of an additional frame of stimulus duration, not the response at a specific time point.
>
> For HRF recovery, always use the onset delta.

```matlab
% Build the onset delta vector
T            = length(stim_stationary);   % number of timepoints
onset_delta  = zeros(T, 1);
onset_delta(onsets) = 1;
```

---

### Step 2 — Choose the number of lags K

K should cover the full duration of the expected HRF. Previous work (Nunez-Elizalde 2022, Chen 2023) estimated that the HRF returns to baseline ~20 seconds after onset.
A typical fUSI HRF lasts ~8-10 s after onset (Nunez-Elizalde 2022). With TR ≈ 0.2 s:

```matlab
HRF_duration_s = 20;                         % seconds to model after onset
K              = round(HRF_duration_s / TR); % number of lags (e.g. ~100)
lag_times_s    = (0:K-1) * TR;               % time axis for plotting betas
```

---

### Step 3 — Build the FIR design matrix

Create K lagged copies of `onset_delta`. Lag k shifts the delta k frames into the future:

```matlab
X_fir = zeros(T, K);

for k = 0 : K-1
    shifted = circshift(onset_delta, k);
    shifted(1:k) = 0;          % zero-pad at the start (no circular wrap-around)
    X_fir(:, k+1) = shifted;
end

% Build the predictor labels
predictor_labels = {};
for k = 0 : K-1
    predictor_labels{k+1} = sprintf('lag_%02d', k);
end
```

The resulting design matrix `X_fir` has shape `[T × K]`:

```
column 1 (lag 0):  1 at onset frames
column 2 (lag 1):  1 one frame after each onset
column 3 (lag 2):  1 two frames after each onset
...
column K (lag K-1): 1 K-1 frames after each onset
```

---

### Step 3.5 — Run a standard GLM first to identify active regions

Before fitting the expensive FIR model (K predictors per region), run a quick single-predictor GLM with the pre-defined HRF to find which regions actually respond to the stimulus. This avoids fitting the FIR model to flat/noise regions.

```matlab
% Standard GLM on stationary frames only
TR         = mean(diff(PDI.time));
hrf_kernel = fonduta.signal.hrf(TR, hrfParams);
hrf        = @(ev) filter(hrf_kernel, 1, ev(:));

stationaryFrames = ~runningFrameMask(:);
PDI_steady       = PDI.PDI(:, :, stationaryFrames);
M8_pred_steady   = hrf(stim_stationary(stationaryFrames));

all_results.M8_SteadyVisual = fonduta.glm.ols( ...
    'M8_SteadyVisual', PDI_steady, bmask, ...
    M8_pred_steady, {'stim_stationary_hrf'});

eta2 = squeeze(all_results.M8_SteadyVisual.eta2);   % [nx x ny]
```

Then threshold eta2 to find the **active voxels** and the **active regions** (Allen regions that contain at least one suprathreshold voxel):

```matlab
eta2_thresh_val   = 0.05;
eta2_mask         = (eta2 > eta2_thresh_val) & (bmask == 1);   % [nx x ny] logical

active_region_ids = unique(allen_regions(eta2_mask));
active_region_ids(active_region_ids <= 1) = [];   % remove 0 (outside) and 1 (root)

total_region_ids = unique(allen_regions(bmask == 1));
total_region_ids(total_region_ids <= 1) = [];
fprintf('Active regions: %d / %d\n', numel(active_region_ids), numel(total_region_ids));
```

The FIR model will be fitted only on `active_region_ids`.

---

### Step 4 — Extract ROI-averaged signals

Rather than fitting the GLM to every individual voxel, we average the fUSI signal within each active Allen Brain Atlas region. This is much faster, reduces noise, and produces interpretable per-region HRF estimates.

`allen_regions` is already available from `build_slice_masks` — it is a `[nx × ny]` integer map of Allen region IDs in the same subject space as `PDI.PDI`. **No additional registration is needed.** Cast to `double` before any arithmetic (`allen_regions` is `int16`).

#### Sanity check: verify alignment before signal extraction

Overlay the region map on the mean PDI image to confirm that `allen_regions` and `PDI.PDI` are in the same coordinate space (no flip needed):

```matlab
load(fullfile(subAnatPath{isub}, 'anatomic.mat'), 'anatomic')

fonduta.viz.view_image( ...
    anatomic.Data(:,:,anatomic.funcSlice(3)), ...
    allen_regions,3)

masked_PDI = mode(PDI.PDI, 3);
masked_PDI(bmask == 0) = NaN;   % NaN → transparent in imagesc/view_image

fonduta.viz.view_image( ...
    masked_PDI, ...
    double(allen_regions).*bmask,3)
```

If the brain outline in the overlay matches the bright area in the mean PDI, the alignment is correct.

> **Note:** `allen_regions` and `PDI.PDI` are both in raw subject space. The vertical flip in `view_glm` is only for display. Do **not** flip here.

#### Extract mean signal per active ROI (two options)

```matlab
% Option A (recommended): average ALL voxels in the region within bmask.
%   Unbiased — the same voxels used to select active regions are NOT
%   re-used to estimate the HRF. Avoids selection bias.
%
% Option B: average only suprathreshold voxels (eta2 > threshold).
%   Higher SNR but circular — voxels were chosen because they already
%   showed a strong response, so the estimated HRF amplitude is inflated.

use_suprathreshold_voxels = false;   % true → Option B

nROI     = numel(active_region_ids);
T_frames = size(PDI.PDI, 3);
Y_roi    = zeros(T_frames, nROI);

for r = 1:nROI
    roi_all   = (allen_regions == active_region_ids(r)) & (bmask == 1);
    roi_supra = (allen_regions == active_region_ids(r)) & eta2_mask;

    if use_suprathreshold_voxels && any(roi_supra(:))
        sel_mask = roi_supra;   % Option B
    else
        sel_mask = roi_all;     % Option A
    end

    vox         = reshape(PDI.PDI, [], T_frames);
    Y_roi(:, r) = mean(vox(sel_mask(:), :), 1)';
end

% Build region name labels (acronym from atlas)
region_names = cell(nROI, 1);
for r = 1:nROI
    rId = active_region_ids(r);
    if rId >= 1 && rId <= numel(atlas.infoRegions.acr)
        region_names{r} = atlas.infoRegions.acr{rId};
    else
        region_names{r} = sprintf('ID_%d', rId);
    end
end

fprintf('Extracted signals from %d active ROIs\n', nROI);
```

---

### Step 5 — Run the FIR GLM on ROI-averaged signals

Since `Y_roi` is already a `[T × nROI]` matrix, we call `fonduta.glm.engine` directly (which works on `[T × V]` matrices — no need for the 3D→2D flattening that `fonduta.glm.ols` does):

```matlab
glm_est = fonduta.glm.engine('M_FIR_stationary', Y_roi, X_fir, predictor_labels);
% glm_est.betas  [K+1 x nROI]  — rows 1..K = HRF lags; last row = intercept
% glm_est.tstat  [K x nROI]
% glm_est.R2     [1 x nROI]
```

---

### Step 6 — Plot the estimated HRF per ROI

```matlab
% All ROIs — one line per region
figure;
plot(lag_times_s, glm_est.betas(1:K, :), 'LineWidth', 1);
xlabel('Time after onset (s)');
ylabel('Beta (z-score units)');
title('FIR-estimated HRF per ROI');
legend(region_names, 'Interpreter', 'none', 'Location', 'eastoutside');
xline(0, '--k');  yline(0, ':k');

% Single ROI (e.g. primary visual cortex)
target_acr = 'VISp';
rIdx = find(strcmp(region_names, target_acr));
if ~isempty(rIdx)
    figure;
    plot(lag_times_s, glm_est.betas(1:K, rIdx), 'b-o', 'LineWidth', 2);
    xlabel('Time after onset (s)');
    ylabel('Beta (z-score units)');
    title(sprintf('Estimated HRF — %s', target_acr));
    xline(0, '--k');  yline(0, ':k');
end
```

---

## HRF interpretation and considerations

### Which a priori HRF parameters to use?

> **The correct parameters for fUSI data are those published by Chen et al. (2023).** The script uses:
> ```matlab
> hrfParams = [4.95  8.69  1.1  1.1  1.8  0  32];
> %            dR    dU    dR   dU   ratio onset len(s)
> ```
>
> These were estimated specifically from fUSI data (cerebral blood volume, CBV) and should be the default choice.
>
> The alternative `[2.4  8  0.8  0.9  6  0  16]` is the SPM/FSL default, optimised for BOLD fMRI. It predicts a peak at ~1.5 s, which is too fast for CBV responses measured with fUSI. **Do not use SPM parameters with fUSI data.**

The FIR analysis serves precisely to validate this choice: after fitting the FIR model, compute the Pearson correlation between the estimated HRF and the Chen 2023 kernel. If the correlation is high (> 0.5 is a reasonable threshold), the assumed HRF is a good match for the data.

---

### The fUSI HRF is broader and slower than the BOLD HRF

The hemodynamic response in fUSI reflects **cerebral blood volume (CBV)**, not the BOLD signal. CBV responses are generally:

- **Slower to peak**: CBV peaks at ~3–5 s post-onset vs ~5–6 s for BOLD (both measured differently, but the CBV rise is driven by arteriolar dilation which takes a few seconds)
- **Broader**: the CBV response sustains longer because venous compliance and capillary recruitment add a secondary slow component
- **Larger undershoot**: the post-stimulus undershoot (venous constriction after arterial dilation) can be pronounced

This is why the Chen 2023 parameters (`delay_response = 4.95 s`) give a much better fit than the SPM defaults (`delay_response = 2.4 s`).

---

### Biphasic HRF: what it means

When looking at the FIR-estimated HRFs across regions, you may notice a **biphasic pattern**: a first peak at ~3–4 s followed by a dip and a second smaller peak at ~7–9 s. This is not a bug and is **not** caused by:

- **Trial-to-trial overlap** (ISI is 45 s — far too long to contaminate the HRF window)
- **Stimulus offset response** (stimulus duration is 15 s — the offset occurs at 15 s, outside the 10 s FIR window)

The most likely explanations are:

1. **Genuine biphasic CBV response**: arteriolar dilation (fast, ~2–4 s) creates the first peak; venous compliance and capillary recruitment (slower, ~7–9 s) create the second. This is a documented feature of the fUSI hemodynamic response.

2. **Post-inhibitory neural rebound**: after the initial response and the period of reduced activity, some regions — particularly those with strong inhibitory interneuron populations (e.g. visual cortex) — show a genuine secondary activation.

3. **Vascular rebound after undershoot**: the classic CBV undershoot can be followed by a small overshoot before returning to baseline, which appears as a second positive lobe.

**Practical implication**: a unimodal double-gamma kernel (as in Chen 2023) will not capture the second lobe. For analyses where the HRF shape matters (e.g. deconvolution, HRF model comparison), consider either:
- Extending the FIR window to 20 s to see the full response
- Fitting a sum of two gamma functions to the FIR betas

---

## Summary: FIR vs convolved GLM

| | Convolved GLM (`M1_StimOnly`) | FIR GLM |
|---|---|---|
| HRF assumed | Yes (double-gamma) | No |
| Design matrix | 1 column (HRF-convolved stim) | K columns (lagged deltas) |
| Betas | Amplitude of assumed HRF | Empirical HRF shape at each lag |
| Use when | HRF shape known/assumed | HRF shape unknown / to be estimated |
| df cost | low (1 df per predictor) | high (K df per predictor) |

The FIR result can then be used to validate the assumed HRF shape, or to fit a parametric model (e.g. double-gamma) to the recovered betas.
