function [fig, r_corr] = compare_hrf_fir_eta2(glm_results_path, run_number, model_name, normalize_flag)
% COMPARE_HRF_FIR_ETA2 Side-by-side HRF vs FIR eta2 overlay comparison.
%
% Usage:
%   [fig, r] = compare_hrf_fir_eta2('/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest', ...
%                                   '101347', 'M5_Behavior', true);

if nargin < 4, normalize_flag = true; end

%% 1. Model Definitions & Predictor Lookup
hrf_models = struct( ...
    'name',      {'M1_StimOnly', 'M8_SteadyVisual',     'M5_Behavior'}, ...
    'predictor', {'stim_hrf',    'stim_stationary_hrf', 'stim_hrf'} ...
);

fir_models = struct( ...
    'name',      {'M1_StimOnly', 'M8_SteadyVisual',   'M5_Behavior', 'M5_Behavior'}, ...
    'predictor', {'Visual_FIR',  'Visual_Steady_FIR', 'Visual_FIR',  'Wheel_FIR'} ...
);

% Match HRF predictor label
hrf_idx = find(strcmp({hrf_models.name}, model_name), 1);
if isempty(hrf_idx)
    error('Model "%s" not found in hrf_models struct.', model_name);
end
hrf_pred = hrf_models(hrf_idx).predictor;

% Match FIR predictor label
fir_idx = find(strcmp({fir_models.name}, model_name), 1);
if isempty(fir_idx)
    error('Model "%s" not found in fir_models struct.', model_name);
end
fir_pred = fir_models(fir_idx).predictor;

%% 2. Load File Data
if iscell(run_number), run_str = run_number{1}; else, run_str = char(run_number); end

hrf_file = fullfile(glm_results_path, ['glm_run-' run_str '.mat']);
fir_file = fullfile(glm_results_path, ['FIR_glm_run-' run_str '.mat']);

if ~exist(hrf_file, 'file'), error('File not found: %s', hrf_file); end
if ~exist(fir_file, 'file'), error('File not found: %s', fir_file); end

hrf_data = load(hrf_file).data;
fir_data = load(fir_file).data;

%% 3. Map Atlas & Histology to Subject Space
atlas = fonduta.atlas.load_atlas();
load(fullfile(hrf_data.anatPath, 'anatomic.mat'), 'anatomic');
Transf = hrf_data.Transf;
bmask  = double(hrf_data.bmask);   % [nx x ny]

subAtlas  = fonduta.atlas.atlas2individual(atlas, anatomic, Transf);
funcSlice = anatomic.funcSlice(3);

% Extract histology and region slices
subHisto   = double(squeeze(subAtlas.Histology.Data(:, :, funcSlice)));
subRegions = double(squeeze(subAtlas.Region.Data(:, :, funcSlice)));

% Reorient dorsal up
subHisto   = flipud(subHisto);
subRegions = flipud(subRegions);
subHisto   = subHisto / (max(subHisto(:)) + eps);

% Create thin 1-pixel green border overlay mask
subReg_named = subRegions;
subReg_named(subReg_named <= 1) = 0;
borders = (imgradient(subReg_named) > 0) & (subReg_named > 0);

%% 4. Extract & Process HRF Map
m_hrf = hrf_data.models.(model_name);
p_idx = find(strcmp(m_hrf.predictor_labels, hrf_pred));
if isempty(p_idx)
    error('Predictor "%s" missing in HRF model %s', hrf_pred, model_name);
end

raw_hrf_vol = m_hrf.eta2(p_idx, :, :);
hrf_map = reshape(raw_hrf_vol, size(bmask, 1), size(bmask, 2)) .* bmask;
hrf_map = flipud(hrf_map);

%% 5. Extract & Process FIR Map
m_fir = fir_data.models.(model_name);
if isfield(m_fir, 'fcontrasts') && isfield(m_fir.fcontrasts, fir_pred)
    fir_map = double(m_fir.fcontrasts.(fir_pred).eta2_p) .* bmask;
else
    error('F-contrast "%s" missing in FIR model %s', fir_pred, model_name);
end
fir_map = flipud(fir_map);

%% 6. Compute Spatial Pearson Correlation (masked voxels only)
valid_mask = bmask(:) > 0 & ~isnan(hrf_map(:)) & ~isnan(fir_map(:));
vec_hrf = hrf_map(valid_mask);
vec_fir = fir_map(valid_mask);

R = corrcoef(vec_hrf, vec_fir);
r_corr = R(1, 2);
fprintf('Spatial Correlation between HRF and FIR maps (Run %s, %s): r = %.4f\n', ...
    run_str, model_name, r_corr);

%% 7. Apply Normalization [0, 1] if requested
if normalize_flag
    if max(hrf_map(:), [], 'omitnan') > 0
        hrf_map = hrf_map / max(hrf_map(:), [], 'omitnan');
    end
    if max(fir_map(:), [], 'omitnan') > 0
        fir_map = fir_map / max(fir_map(:), [], 'omitnan');
    end
    c_limits = [0 1];
else
    max_val  = max([max(hrf_map(:), [], 'omitnan'), max(fir_map(:), [], 'omitnan')]);
    c_limits = [0, max_val];
end

%% 8. Plotting Side-by-Side Figure
fig = figure('Name', sprintf('HRF vs FIR - Run %s - %s', run_str, model_name), ...
    'Color', 'w', 'Position', [100 200 1200 600]);

% Setup background RGB layers
histoRGB  = cat(3, subHisto, subHisto, subHisto);
borderRGB = zeros([size(borders), 3]);
borderRGB(:, :, 2) = 1;  % Pure Green borders

% --- Left Subplot: HRF ---
ax1 = subplot(1, 2, 1);
render_map(ax1, histoRGB, hrf_map, borderRGB, borders, c_limits);
title(ax1, sprintf('HRF  |  Run %s\nModel: %s  (%s)', run_str, model_name, hrf_pred), ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');

% --- Right Subplot: FIR ---
ax2 = subplot(1, 2, 2);
render_map(ax2, histoRGB, fir_map, borderRGB, borders, c_limits);
title(ax2, sprintf('FIR  |  Run %s\nModel: %s  (%s)\nr = %.4f', run_str, model_name, fir_pred, r_corr), ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');

end

%% Helper function to overlay map onto histology
function render_map(ax, histoRGB, displayMap, borderRGB, borders, clims)
    hold(ax, 'on');
    imagesc(ax, histoRGB);
    
    % Render stat map overlay
    hb = imagesc(ax, displayMap, clims);
    set(hb, 'AlphaData', double(displayMap > 0) * 0.80);
    
    % Render thin green atlas borders (0.25 opacity for subtle outlines)
    hbord = imagesc(ax, borderRGB);
    set(hbord, 'AlphaData', double(borders) * 0.35);
    
    hold(ax, 'off');
    colormap(ax, hot(256));
    clim(ax, clims);
    
    % Remove axes ticks and bounding borders
    axis(ax, 'tight');
    axis(ax, 'off');
    
    xl = xlim(ax); yl = ylim(ax);
    mx = 0.05 * (xl(2) - xl(1));
    my = 0.05 * (yl(2) - yl(1));
    xlim(ax, [xl(1) - mx,  xl(2) + mx]);
    ylim(ax, [yl(1) - my,  yl(2) + my]);
end