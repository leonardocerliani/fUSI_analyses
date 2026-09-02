# Progress Log — HRF Analysis Revision

---

## Session 2026-09-02 — viewer stabilisation (CLOSED)

### Context
Continuing development of `view_eHRF_cHRF_corr_peristimulus.m`, an interactive viewer
comparing eHRF (ridge regression betas) vs cHRF (canonical) against peristimulus signal.

### Bugs fixed this session

#### 1. Invisible regions in map (generateComparisonMap)
- **Root cause:** used `intersect(fieldnames(eHRFData.regional_hrf), fieldnames(cHRFData.regional_avg))` 
  — regions with slightly different struct fieldnames across the two data files returned NaN in the map
- **Fix:** switch to ACR-based matching: loop over all atlas regions, find the entry whose `.acr` 
  attribute matches the target acronym in both structs independently

#### 2. T-values exploding to 250+ (generateComparisonMap)
- **Root cause:** `movmean` was applied to individual-subject ridge betas `hrf_e(:,s)` before 
  computing correlations; smoothing collapses per-subject variance → SE→0 → T→∞
- **Fix:** smooth `tc_c` (peristimulus signal) only, never `hrf_e`; 
  the smooth window still improves the signal's SNR before correlation

#### 3. T-value mismatch between map and info bar
- **Root cause:** `generateComparisonMap` was not smoothing `tc_c` while `plotRegionTimeCourse` 
  was — two different effective signals being correlated
- **Fix:** both functions now apply identical smoothing to `tc_c` using the same `hSmoothBox` value

#### 4. Info bar format string error (df missing)
- **Root cause:** format string lacked `%d` slot for df in both T-value displays
- **Fix:** format string updated to `T(%d) = %.2f, p = %.4f` for both directions

#### 5. Info bar p-value direction
- Confirmed: `p_eGTc = tcdf(-t_eGTc, df)` — right-tail one-tailed, correct

### Bugs identified but NOT fixed this session

#### 6. Smooth window has no effect on blue eHRF curve in plot panel
- **Root cause:** `mu_e = mean(tc_e, 2)` uses raw unsmoothed ridge betas; 
  no `movmean` applied to `mu_e` before plotting
- **Fix ready (not applied):** after computing `mu_e`, apply `movmean` to the post-averaged 
  mean only — see `activeContext.md` for exact code snippet
- **Critical constraint:** do NOT apply movmean to individual `tc_e` columns 
  (that is what caused bug #2 above)

### Session verdict
- Viewer is functional but the code is messy, hard to read, and has duplication
- Further development should start with a refactor of the function structure
- A clean rewrite splitting concerns (data loading, map generation, plot, stats, UI) 
  into separate well-defined private functions is strongly recommended

---

## Session 2026-08-XX — nuisance projection in simple average (CLOSED)

### Files modified
- `analysis_simple_average.m` — nuisance projection added before trial averaging
- `analysis_simple_average_parallel.m` — same change in parallel version

### What was done
Regressed out nuisance signals (motion, ventricle) from the peristimulus epochs before 
computing the simple average, matching what is done in the ridge regression pipeline.

---

## Persistent Notes

### Data structure conventions

**`eHRFData`** (from `ridge_loo_<model>_eta003_HRF12s.mat`):
- `regional_hrf.<fieldname>.hrf`  → `[K × nSub]` ridge betas = eHRF shape
- `regional_hrf.<fieldname>.acr`  → region acronym string (canonical identifier)
- `regional_hrf.<fieldname>.name` → full region name
- `lag_times_s`                   → `[1 × K]` time axis (s), onset = 0
- `TR_mean`, `before_stim_onset`, `chaoyi_hrfParams`

**`cHRFData`** (from `simple_avg_<model>_eta003.mat`):
- `regional_avg.<fieldname>.tc`   → `[nTime_c × nSub]` peristimulus signal
- `regional_avg.<fieldname>.acr`  → region acronym
- `TR_mean`, `stim_dur_s`, `before_stim_onset`, `after_stim_offset`, `chaoyi_hrfParams`

### Smoothing rules (DO NOT BREAK)

| Context | Smooth `tc_c`? | Smooth `hrf_e`/`tc_e`? | Why |
|---|---|---|---|
| `generateComparisonMap` (stats) | YES (per-subject columns) | NO | SE must not collapse |
| `plotRegionTimeCourse` (display) | YES (per-subject columns before mean) | NO individual cols; YES post-mean `mu_e` | Cosmetic on mean is safe |
| Info bar t-test | YES (already smoothed tc_c from plot section) | NO | Consistency with map |

### T-test convention
```
ttest(Ze - Zc) → tstat
t_eGTc =  tstat   (positive = eHRF fits better)
t_cGTe = -tstat   (positive = cHRF fits better)
p_eGTc = tcdf(-t_eGTc, df)   % one-tailed right tail
p_cGTe = tcdf(-t_cGTe, df)
```
