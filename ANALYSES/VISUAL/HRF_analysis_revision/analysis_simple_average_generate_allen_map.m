function analysis_simple_average_generate_allen_map(opts)
%ANALYSIS_SIMPLE_AVERAGE_GENERATE_ALLEN_MAP
% Generate an Allen-atlas 3D map of regional HRF correlations.
%
% INPUT
%   opts.model
%       Model name, e.g. 'M8_SteadyVisual'
%
%   opts.eta2_thresh_val
%       Eta2 threshold used for the simple-average analysis.
%       Default: 0.03
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
%       Must match the value used for the similarity table.
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
% The map is also saved as:
%
%   simple_avg_<model_name>_eta<etavalue>_map.mat
%
% in:
%
%   HRF_analysis_revision/results_simple_average/

%% Defaults

if ~isfield(opts, 'eta2_thresh_val')
    opts.eta2_thresh_val = 0.03;
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

%% Paths

results_path = fullfile( ...
    pwd, 'HRF_analysis_revision', 'results_simple_average');

eta_str = sprintf( ...
    'eta%03d', round(opts.eta2_thresh_val * 100));

input_file = fullfile( ...
    results_path, ...
    sprintf('simple_avg_%s_%s.mat', opts.model, eta_str));

output_file = fullfile( ...
    results_path, ...
    sprintf('simple_avg_%s_%s_map.mat', opts.model, eta_str));

%% Check input

if ~isfile(input_file)
    error('Simple-average result file not found:\n%s', input_file);
end

%% Load results

S = load(input_file);

%% Build canonical HRF

stim_frames = round(S.stim_dur_s / S.TR_mean);
before_frames = round(S.before_stim_onset / S.TR_mean);
after_frames = round(S.after_stim_offset / S.TR_mean);

W = before_frames + stim_frames + after_frames;

boxcar = [ ...
    zeros(before_frames,1); ...
    ones(stim_frames,1); ...
    zeros(after_frames,1)];

hrf_ch = fonduta.signal.hrf( ...
    S.TR_mean, S.chaoyi_hrfParams);

ap_ch = conv(boxcar, hrf_ch);
ap_ch = ap_ch(1:W);
ap_ch = ap_ch / max(ap_ch);

%% Initialize map

correlation_map = nan(size(S.atlas.Regions));

%% Loop over regions

region_fields = fieldnames(S.regional_avg);

for fi = 1:numel(region_fields)

    reg = S.regional_avg.(region_fields{fi});

    TC = reg.tc;
    nSub = size(TC, 2);

    % Subject threshold
    if nSub < opts.n_subject_thresh
        continue
    end

    % Smooth time courses
    if opts.smooth_win_s > 0
        smooth_win_frames = max(1, ...
            round(opts.smooth_win_s / S.TR_mean));

        TC = movmean(TC, smooth_win_frames, 1);
    end

    % Check time dimension
    if size(TC, 1) ~= W
        warning('Skipping region %s: unexpected time dimension.', ...
            reg.acr);
        continue
    end

    % Subject-level correlations
    sims = arrayfun(@(s) ...
        corr(TC(:,s), ap_ch, 'rows', 'complete'), ...
        1:nSub);

    % Regional statistic
    switch lower(opts.statistic)

        case 'mean'
            similarity = mean(sims, 'omitnan');

        case 'median'
            similarity = median(sims, 'omitnan');

        otherwise
            error( ...
                'opts.statistic must be ''mean'' or ''median''.');
    end

    % Similarity threshold
    if similarity < opts.sim_thresh
        continue
    end

    %% Find Allen region ID

    acr_idx = find(strcmp(S.atlas.infoRegions.acr, reg.acr), 1);

    if isempty(acr_idx)
        warning('Region %s not found in atlas.infoRegions.acr.', ...
            reg.acr);
        continue
    end

    %% Fill region in 3D map

    region_mask = S.atlas.Regions == acr_idx;

    correlation_map(region_mask) = similarity;

end

%% Save

save(output_file, 'correlation_map', '-v7.3');

fprintf('\nAllen correlation map saved to:\n%s\n\n', output_file);

end