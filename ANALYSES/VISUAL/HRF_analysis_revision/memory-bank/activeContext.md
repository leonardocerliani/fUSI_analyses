# Active Context — HRF Analysis Revision

**Last updated:** 2026-09-02  
**Session status:** CLOSED — memory-bank update only  
**Working directory:** `ANALYSES/VISUAL/HRF_analysis_revision/`

---

## Current Goal

Develop and validate `view_eHRF_cHRF_corr_peristimulus.m`: an interactive MATLAB viewer
that compares the empirical HRF (eHRF, from ridge regression) vs the canonical HRF (cHRF)
against the peristimulus time course, region by region.

---

## State at Session End

### What works
- Alpha masking: voxels outside `[cMin, cMax]` are transparent  
  (`inRange = ~isnan(sData) & sData ~= 0 & sData >= cMin & sData <= cMax`)
- `generateComparisonMap`: loops over all atlas regions, matches by `.acr` field (ACR-based), 
  NOT by fieldname intersection — fixes invisible regions caused by mismatched struct field names
- `generateComparisonMap`: smooths `tc_c` (peristimulus signal) only, NOT `hrf_e` (ridge betas), 
  using `hSmoothBox` value — critical to prevent T→∞ from SE collapsing
- `hSmoothBox` callback triggers `updateMapAndDisplay()` — changing smooth window regenerates map
- Info bar: shows `T(df) = ..., p = ...` for both directions (`%d` for df, correct format)
- Info bar p-values: one-tailed right-tail via `tcdf(-t, df)`
- Info bar always computes `ttest(Ze - Zc)` once; `t_eGTc = +tstat`, `t_cGTe = -tstat`
- Plot panel: smoothing of `tc_c` (Simple avg, black dotted) responds to smooth window

### Known bug (UNRESOLVED at session close)
- **Smooth window has no effect on the blue eHRF (Ridge) curve in the plot panel**
- Root cause: `mu_e = mean(tc_e, 2)` is computed from raw unsmoothed ridge betas `tc_e`; 
  no smoothing is applied to `mu_e` before plotting
- **Fix (planned, not applied):** after computing `mu_e`, apply `movmean` to the MEAN only 
  (cosmetic, post-averaging) — does NOT touch individual subject columns, 
  so map T-values and info bar T-values are unaffected:

```matlab
% In plotRegionTimeCourse(), after:
%   mu_e = mean(tc_e, 2, 'omitnan'); mu_e = mu_e(:);
% Add:
if ~isnan(smooth_win_s) && smooth_win_s > 0
    TR_e_plot = t_e(2) - t_e(1);          % step size of lag_times_s
    sf_e      = max(1, round(smooth_win_s / TR_e_plot));
    mu_e      = movmean(mu_e, sf_e);
end
```

---

## Key Design Decisions (Do Not Break)

| Decision | Rationale |
|---|---|
| Smooth `tc_c` (signal) in map generation, NOT `hrf_e` | Smoothing per-subject ridge betas collapses variance → SE→0 → T→250+ |
| Smooth only the MEAN `mu_e` in plot (not individual `tc_e`) | Cosmetic display; individual betas must remain unsmoothed for stats |
| ACR-based region matching (not fieldname intersection) | Fieldnames can differ between struct; `.acr` attribute is canonical |
| One-tailed p via `tcdf(-t, df)` | `p = P(T > t | H0)` right tail; small p = significant in that direction |
| `ttest(Ze - Zc)` once; flip sign for other direction | Avoids running two t-tests; `t_cGTe = -t_eGTc` |

---

## Code Quality Warning

The current `view_eHRF_cHRF_corr_peristimulus.m` (~628 lines) is acknowledged as difficult 
to read, maintain, and update. It grew organically across multiple sessions with incremental 
fixes layered on top of each other. Several specific issues:

- `mu_c` is computed twice (lines 443 and 446) — dead code
- Smoothing logic is duplicated between `generateComparisonMap` and `plotRegionTimeCourse` 
  but with different variable names, making them easy to get out of sync
- The plot function re-builds the canonical HRF from scratch every click (no caching)
- Info bar T-value computation repeats the correlation loop from `generateComparisonMap` 
  instead of reading the cached map value
- `ternary()` helper is defined but barely used

**Recommended future action:** refactor into separate well-named private functions with clear 
input/output contracts before adding further features.

---

## File Inventory

| File | Status | Notes |
|---|---|---|
| `view_eHRF_cHRF_corr_peristimulus.m` | Active, working but messy | Main viewer; 628 lines; known smoothing bug on blue curve |
| `view_eHRF_cHRF_corr_peristimulus_DOC.md` | Partially outdated | Smooth (s) doc still says it applies to `hrf_e` — wrong |
| `analysis_simple_average.m` | Done | Nuisance projection added |
| `analysis_simple_average_parallel.m` | Done | Same as above |
| `analysis_ridge_loo_ROI.m` | Done | Produces `eHRFData` |
| `memory-bank/activeContext.md` | This file | — |
| `memory-bank/progress.md` | See progress.md | Full session history |
