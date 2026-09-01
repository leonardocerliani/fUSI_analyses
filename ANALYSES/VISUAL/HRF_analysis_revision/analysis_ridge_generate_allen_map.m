function analysis_ridge_generate_allen_map(opts)
% ANALYSIS_RIDGE_GENERATE_ALLEN_MAP
% Generate an Allen-atlas 3D map of regional eHRF-cHRF correlations for Ridge LOO-CV.
%
% INPUT
%   opts.model
%       Model name, e.g. 'M8_SteadyVisual', 'M1_StimOnly', 'M5_Behavior'
%
%   opts.eta2_thresh_val
%       Eta2 threshold used for the ridge analysis.
%       Default: 0.03
%
%   opts.time_window_after_offset
%       Post-stimulus window length in seconds.
%       Default: 12
%
%   opts.nuisance_labels
%       Cell array of nuisance labels used during fitting.
%       Default: {}
%
%   opts.baseline_correct
%       Boolean flag to perform pre-stimulus (t < 0s) zero-baseline subtraction.
%       Default: true
%
%   opts.sim_thresh
%       Minimum mean/median correlation to include a region.
%       Default: 0
%
%   opts.n_subject_thresh
%       Minimum number of subjects contributing to a region.
%       Default: 1
%
%   opts.smooth_win_s
%       Moving-average smoothing window in seconds.
%       Default: 0
%
%   opts.statistic
%       'mean' or 'median'.
%       Default: 'mean'
%
% OUTPUT
%   correlation_map
%       3D Allen-atlas volume containing the selected regional
%       correlation statistic. Regions that do not qualify are NaN.
%
% The map is saved as:
%   ridge_loo_<model_name>_<eta>_<hrf>[_clean_<nuisance>]_map.mat
% in:
%   HRF_analysis_revision/results_ridge_loo/

%% Defaults

if ~isfield(opts, 'eta2_thresh_val')
    opts.eta2_thresh_val = 0.03;
end

if ~isfield(opts, 'time_window_after_offset')
    opts.time_window_after_offset = 12;
end

if ~isfield(opts, 'nuisance_labels')
    opts.nuisance_labels = {};
end

if ~isfield(opts, 'baseline_correct')
    opts.baseline_correct = true;
end

if ~isfield(opts, 'sim_thresh')
    opts.sim_thresh = 0;
end

if ~isfield(opts, 'n_subject_thresh')
    opts.n_subject_thresh = 1;
end

if ~isfield(opts, 'smooth_win_s')
    opts.smooth_win_s = 0;
end

if ~isfield(opts, 'statistic')
    opts.statistic = 'mean';
end

%% Paths and Filenames

results_path = fullfile(pwd, 'HRF_analysis_revision', 'results_ridge_loo');

eta_str = sprintf('eta%03d', round(opts.eta2_thresh_val * 100));
hrf_str = sprintf('HRF%ds',  opts.time_window_after_offset);

if ~isempty(opts.nuisance_labels)
    nuis_tag = ['_clean_' strjoin(opts.nuisance_labels, '_')];
else
    nuis_tag = '';
end

base_name   = sprintf('ridge_loo_%s_%s_%s%s', opts.model, eta_str, hrf_str, nuis_tag);
input_file  = fullfile(results_path, [base_name '.mat']);
output_file = fullfile(results_path, [base_name '_map.mat']);

%% Check input

if ~isfile(input_file)
    error('Ridge LOO result file not found:\n%s', input_file);
end

%% Load results

S = load(input_file);

%% Build canonical HRF predictor

dt = S.time_resampling;
t  = S.lag_times_s(:);
K  = numel(t);

% Boxcar starting strictly at t >= 0 up to stim_dur_s
boxcar = double(t >= 0 & t <= S.stim_dur_s);

hrf_ch = fonduta.signal.hrf(dt, S.chaoyi_hrfParams);

ap_ch = conv(boxcar, hrf_ch);
ap_ch = ap_ch(1:K);
if max(ap_ch) > 0
    ap_ch = ap_ch / max(ap_ch);
end

%% Initialize map

correlation_map = nan(size(S.atlas.Regions));

%% Loop over regions

region_fields = fieldnames(S.regional_hrf);

for fi = 1:numel(region_fields)

    reg  = S.regional_hrf.(region_fields{fi});
    HRF  = reg.hrf; % [K x nSub]
    nSub = size(HRF, 2);

    % Subject threshold
    if nSub < opts.n_subject_thresh
        continue
    end

    % Smoothing
    if opts.smooth_win_s > 0
        smooth_win_frames = max(1, round(opts.smooth_win_s / dt));
        HRF = movmean(HRF, smooth_win_frames, 1);
    end

    % Pre-stimulus zero-baseline correction
    if opts.baseline_correct
        base_idx = (t < 0);
        if any(base_idx)
            base_offset = mean(HRF(base_idx, :), 1); % [1 x nSub]
            HRF = HRF - base_offset;
        end
    end

    % Check time dimension
    if size(HRF, 1) ~= K
        warning('Skipping region %s: time dimension mismatch.', reg.acr);
        continue
    end

    % Subject-level correlations
    sims = arrayfun(@(s) corr(HRF(:,s), ap_ch, 'rows', 'complete'), 1:nSub);

    % Regional statistic
    switch lower(opts.statistic)
        case 'mean'
            similarity = mean(sims, 'omitnan');
        case 'median'
            similarity = median(sims, 'omitnan');
        otherwise
            error('opts.statistic must be ''mean'' or ''median''.');
    end

    % Similarity threshold
    if similarity < opts.sim_thresh
        continue
    end

    %% Find Allen region ID

    acr_idx = find(strcmp(S.atlas.infoRegions.acr, reg.acr), 1);

    if isempty(acr_idx)
        warning('Region %s not found in atlas.infoRegions.acr.', reg.acr);
        continue
    end

    %% Fill region in 3D map

    region_mask = S.atlas.Regions == acr_idx;
    correlation_map(region_mask) = similarity;

end

%% Save

save(output_file, 'correlation_map', '-v7.3');

fprintf('\nAllen Ridge correlation map saved to:\n  %s\n\n', output_file);

end