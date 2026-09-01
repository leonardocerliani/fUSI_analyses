function view_glm(resultFile)
% fonduta.viz.view_glm  Interactive GLM viewer: brain slice + design matrix.
%
% Three-column layout:
%   Left   — model/predictor/stat selection, threshold slider, region label
%   Middle — stat map overlaid on Allen Atlas histology (subject space)
%   Right  — design matrix (Xmodel columns) for the selected model
%
% Supported statistics (via the Stat dropdown):
%   eta2  — partial eta² (positive only; threshold applied directly)
%   R2    — global model R² (positive only; predictor selection disabled)
%   betas — OLS parameter estimates (signed; threshold applied to |value|)
%   tstat — t-statistic (signed; default threshold 3.1)
%   zstat — z-statistic (signed; default threshold 3.1)
%
% Usage:
%   fonduta.viz.view_glm('path/to/glm_run-142136.mat')

%% ---- Load results ----
tmp = load(resultFile);
res = tmp.data;

%% ---- Inject F-contrast maps as synthetic predictors (FIR models only) ----
% For any model that has a .fcontrasts field (produced by the FIR pipeline),
% each contrast's eta2_p and Fmap are appended as extra rows to eta2/tstat
% so they appear in the Predictor listbox with a '[F] <name>' label.
% HRF models have no .fcontrasts field → this block is a no-op for them.
mnames_tmp = fieldnames(res.models);
for mi_tmp = 1:numel(mnames_tmp)
    mdata_tmp = res.models.(mnames_tmp{mi_tmp});
    if ~isfield(mdata_tmp, 'fcontrasts') || isempty(fieldnames(mdata_tmp.fcontrasts))
        continue
    end
    cnames_tmp = fieldnames(mdata_tmp.fcontrasts);
    for ci_tmp = 1:numel(cnames_tmp)
        cn_tmp  = cnames_tmp{ci_tmp};
        src_tmp = mdata_tmp.fcontrasts.(cn_tmp);
        % eta2_p  [nx x ny]  → unsqueeze to [1 x nx x ny] and append to eta2
        mdata_tmp.eta2  = cat(1, mdata_tmp.eta2,  reshape(src_tmp.eta2_p, [1, size(src_tmp.eta2_p)]));
        % Fmap    [nx x ny]  → unsqueeze to [1 x nx x ny] and append to tstat
        mdata_tmp.tstat = cat(1, mdata_tmp.tstat, reshape(src_tmp.Fmap,   [1, size(src_tmp.Fmap)]));
        % Insert label before 'intercept' (which is always the last entry)
        mdata_tmp.predictor_labels = [mdata_tmp.predictor_labels(1:end-1), ...
                                      {['[F] ' cn_tmp]}, ...
                                      mdata_tmp.predictor_labels(end)];
    end
    res.models.(mnames_tmp{mi_tmp}) = mdata_tmp;
end
clear mnames_tmp mi_tmp mdata_tmp cnames_tmp ci_tmp cn_tmp src_tmp

FONDUTA_ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(FONDUTA_ROOT));

%% ---- Load atlas and anatomic; map atlas → subject space ----
atlas = fonduta.atlas.load_atlas();
load(fullfile(res.anatPath, 'anatomic.mat'), 'anatomic');
Transf = res.Transf;
bmask  = double(res.bmask);   % [nx x ny]

fprintf('Mapping atlas to subject space...\n');
subAtlas  = fonduta.atlas.atlas2individual(atlas, anatomic, Transf);
funcSlice = anatomic.funcSlice(3);
fprintf('Done.\n');

% Extract functional slice — [nx x ny] same space as stat maps
subHisto   = double(squeeze(subAtlas.Histology.Data(:, :, funcSlice)));
subRegions = double(squeeze(subAtlas.Region.Data(:, :, funcSlice)));

% Flip vertically to get correct anatomical orientation (dorsal up)
subHisto   = flipud(subHisto);
subRegions = flipud(subRegions);

% Normalize histology [0,1]
subHisto = subHisto / (max(subHisto(:)) + eps);

% Region borders — exclude ID 0 (no label) and ID 1 (background root)
se           = strel('diamond', 1);
subReg_named = subRegions;
subReg_named(subReg_named <= 1) = 0;
borders = (imdilate(subReg_named, se) ~= imerode(subReg_named, se)) & ...
          (subReg_named > 0) & ...
          (imerode(subReg_named, se) > 0);

[nr, nc] = size(subRegions);

%% ---- Stat configuration ----
% Each entry: {field, isSigned, defaultThresh, sliderMax, colormap}
statNames   = {'eta2', 'R2', 'betas', 'tstat', 'zstat'};
statCfg = struct( ...
    'field',   statNames, ...
    'signed',  {false, false, true, true, true}, ...
    'thresh',  {0.05,  0.05,  0,    3.1,  3.1 }, ...
    'slMax',   {0.5,   1.0,   Inf,  10,   10  }  ...
);

%% ---- Model / predictor / stat state ----
modelNames  = fieldnames(res.models);
nModels     = numel(modelNames);
curModel    = 1;
curPred     = 1;
curStatIdx  = 1;        % index into statNames (1 = eta2)
statThresh  = statCfg(curStatIdx).thresh;

lbModel    = [];
lbPred     = [];
ddStat     = [];
hCrosshair = [];   % handles [hH, hV] for the green crosshair lines
lastDisplayMap = [];  % cache of the current display map for value readout

%% ---- Build figure ----
fig = figure('Name', 'GLM viewer', 'NumberTitle', 'off', ...
    'Color', [1 1 1], 'Position', [60 60 1700 740]);

% =========================================================
%  LEFT COLUMN  (0–18%)
% =========================================================

% ---- Model list ----
pModel = uipanel(fig, 'Title', 'Model', ...
    'ForegroundColor', [1 0 0], 'BackgroundColor', 'white', ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.51 0.155 0.48]);

lbModel = uicontrol(pModel, 'Style', 'listbox', ...
    'String', strrep(modelNames, '_', ' '), ...
    'Value', 1, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white', 'ForegroundColor', 'w', ...
    'FontSize', 14, ...
    'Callback', @(src, ~) onModelChange(src.Value));

% ---- Predictor list ----
pPred = uipanel(fig, 'Title', 'Predictor', ...
    'ForegroundColor', 'w', 'BackgroundColor', 'white', ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.33 0.155 0.17]);

lbPred = uicontrol(pPred, 'Style', 'listbox', ...
    'String', {}, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white', 'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'Callback', @(src, ~) onPredChange(src.Value));

% ---- Stat dropdown ----
pStat = uipanel(fig, 'Title', 'Statistic', ...
    'ForegroundColor', [0 0.5 1], 'BackgroundColor', 'white', ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.24 0.155 0.08]);

ddStat = uicontrol(pStat, 'Style', 'popupmenu', ...
    'String', statNames, ...
    'Value', 1, ...
    'Units', 'normalized', 'Position', [0.04 0.15 0.92 0.65], ...
    'BackgroundColor', 'white', 'ForegroundColor', [0 0 0], ...
    'FontSize', 13, ...
    'Callback', @(src, ~) onStatChange(src.Value));

% ---- Threshold slider ----
pThresh = uipanel(fig, 'Title', 'Threshold', ...
    'ForegroundColor', 'w', 'BackgroundColor', [1 1 1], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.13 0.155 0.10]);

sliderThresh = uicontrol(pThresh, 'Style', 'slider', ...
    'Min', 0, 'Max', statCfg(curStatIdx).slMax, ...
    'Value', statThresh, ...
    'SliderStep', [0.01/0.5, 0.05/0.5], ...
    'Units', 'normalized', 'Position', [0.04 0.15 0.70 0.50], ...
    'BackgroundColor', [1 1 1], ...
    'Callback', @onThreshChange);

txtThresh = uicontrol(pThresh, 'Style', 'text', ...
    'String', sprintf('%.2f', statThresh), ...
    'Units', 'normalized', 'Position', [0.76 0.10 0.22 0.60], ...
    'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'center');

% ---- Region label ----
txtRegion = uicontrol(fig, 'Style', 'text', ...
    'String', 'Click on a region to identify it', ...
    'Units', 'normalized', 'Position', [0.01 0.01 0.155 0.11], ...
    'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'left');

% =========================================================
%  MIDDLE COLUMN (19–64%): brain slice + vertical colorbar
% =========================================================
ax = axes(fig, 'Position', [0.19 0.05 0.42 0.90], ...
    'Color', 'k', 'XTick', [], 'YTick', []);

cb = colorbar(ax, 'Color', [0 0 0], 'Location', 'eastoutside');
cb.Label.String = statNames{curStatIdx};
cb.Label.Color  = [0 0 0];

% =========================================================
%  RIGHT COLUMN (65–98%): design matrix
% =========================================================
pDesign = uipanel(fig, 'Title', 'Design matrix', ...
    'ForegroundColor', 'k', 'BackgroundColor', 'w', ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.65 0.01 0.34 0.98]);

txtFormula = uicontrol(pDesign, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.01 0.94 0.98 0.05], ...
    'BackgroundColor', 'w', 'ForegroundColor', [0.2 0.2 0.2], ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left', 'String', '');

set(fig, 'WindowButtonDownFcn', @onAxesClick);

%% ---- Initialize ----
onModelChange(1);


%% ========== Nested callbacks ==========

    function onModelChange(idx)
        curModel = idx;
        curPred  = 1;
        lbModel.Value = idx;

        % Rebuild predictor list (drop 'intercept')
        mdata  = res.models.(modelNames{idx});
        labels = strrep(mdata.predictor_labels(1:end-1), '_', ' ');
        lbPred.String = labels;
        lbPred.Value  = 1;

        updateDisplay();
        updateDesignMatrix();
    end

    function onPredChange(idx)
        curPred = idx;
        updateDisplay();
    end

    function onStatChange(idx)
        curStatIdx = idx;
        cfg = statCfg(idx);

        % Update threshold to stat-specific default
        statThresh = cfg.thresh;

        % Update slider range and value
        slMax = cfg.slMax;
        if isinf(slMax)
            % betas: set max to current data range dynamically
            mdata = res.models.(modelNames{curModel});
            if isfield(mdata, 'betas')
                slMax = max(abs(mdata.betas(:)), [], 'omitnan');
                slMax = max(slMax, 0.01);
            else
                slMax = 1;
            end
        end
        set(sliderThresh, 'Min', 0, 'Max', slMax, 'Value', statThresh);
        txtThresh.String = sprintf('%.2f', statThresh);

        % Disable predictor list for R2 (model-level stat, no predictor index)
        if strcmp(cfg.field, 'R2')
            lbPred.Enable = 'off';
        else
            lbPred.Enable = 'on';
        end

        % Update colorbar label
        cb.Label.String = statNames{idx};

        updateDisplay();
    end

    function onThreshChange(src, ~)
        statThresh = src.Value;
        txtThresh.String = sprintf('%.2f', statThresh);
        updateDisplay();
    end

    % ----------------------------------------------------------
    %  updateDisplay — redraws the brain-slice axes (middle col)
    % ----------------------------------------------------------
    function updateDisplay()
        mdata = res.models.(modelNames{curModel});
        cfg   = statCfg(curStatIdx);

        %% Extract stat map
        if strcmp(cfg.field, 'R2')
            % R2 is [nx x ny] — no predictor dimension
            statMap = double(mdata.R2) .* bmask;
        elseif isfield(mdata, cfg.field)
            statMap = squeeze(double(mdata.(cfg.field)(curPred, :, :))) .* bmask;
        else
            % Field not available for this model (e.g. older result without tstat)
            statMap = zeros(size(bmask));
        end

        statMap = flipud(statMap);

        %% Apply threshold
        if cfg.signed
            % Signed: mask out |value| < threshold, keep sign
            displayMap = statMap;
            displayMap(abs(displayMap) < statThresh) = NaN;
        else
            % Unsigned: mask out value < threshold
            displayMap = statMap;
            displayMap(displayMap < statThresh) = NaN;
        end

        %% Choose colormap
        if cfg.signed
            cmap = bwr(256);
            clim_abs = max(abs(displayMap(:)), [], 'omitnan');
            if isempty(clim_abs) || clim_abs == 0 || isnan(clim_abs); clim_abs = 1; end
            clims = [-clim_abs, clim_abs];
        else
            cmap  = hot(256);
            clims = [0, max(displayMap(:), [], 'omitnan')];
            if isempty(clims(2)) || clims(2) == 0 || isnan(clims(2)); clims(2) = 1; end
        end

        %% Render
        histoRGB  = cat(3, subHisto, subHisto, subHisto);
        borderRGB = zeros([size(borders), 3]);
        borderRGB(:,:,2) = 1;

        cla(ax);
        hold(ax, 'on');
        imagesc(ax, histoRGB);
        hb = imagesc(ax, displayMap, clims);
        set(hb, 'AlphaData', double(~isnan(displayMap)) * 0.80);
        hbord = imagesc(ax, borderRGB);
        set(hbord, 'AlphaData', double(borders) * 0.35);
        hold(ax, 'off');

        colormap(ax, cmap);
        clim(ax, clims);

        axis(ax, 'tight');
        xl = xlim(ax);  yl = ylim(ax);
        mx = 0.05 * (xl(2) - xl(1));
        my = 0.05 * (yl(2) - yl(1));
        xlim(ax, [xl(1) - mx,  xl(2) + mx]);
        ylim(ax, [yl(1) - my,  yl(2) + my]);

        %% Cache display map for click readout (crosshair redrawn on next click)
        lastDisplayMap = displayMap;
        hCrosshair = [];

        %% Update title
        if strcmp(cfg.field, 'R2')
            titleStr = sprintf('%s  —  R²', strrep(modelNames{curModel}, '_', ' '));
        else
            predLabel = mdata.predictor_labels{curPred};
            titleStr  = sprintf('%s  —  %s  [%s]', ...
                strrep(modelNames{curModel}, '_', ' '), ...
                strrep(predLabel, '_', ' '), ...
                statNames{curStatIdx});
        end
        title(ax, titleStr, 'Color', 'w', 'FontSize', 13, 'Interpreter', 'none');
    end

    % ----------------------------------------------------------
    %  updateDesignMatrix — redraws stacked subplots (right col)
    % ----------------------------------------------------------
    function updateDesignMatrix()
        delete(findobj(pDesign, 'Type', 'axes'));

        mdata  = res.models.(modelNames{curModel});
        X      = mdata.Xmodel;
        labels = mdata.predictor_labels(1:end-1);
        [T, p] = size(X);

        formula = ['Y ~ ' strjoin(strrep(labels, '_', ' '), ' + ')];
        txtFormula.String = formula;

        topMargin    = 0.10;
        bottomMargin = 0.07;
        gapFraction  = 0.01;

        totalH = 1 - topMargin - bottomMargin - (p - 1) * gapFraction;
        axH    = totalH / p;

        lineColor = [0.15 0.15 0.15];

        for k = 1:p
            yBot = 1 - topMargin - k * axH - (k - 1) * gapFraction;

            axk = axes('Parent', pDesign, ...
                'Units', 'normalized', ...
                'Position', [0.12, yBot, 0.84, axH]);

            plot(axk, 1:T, X(:, k), 'Color', lineColor, 'LineWidth', 0.8);
            ylabel(axk, strrep(labels{k}, '_', ' '), 'Interpreter', 'none');
            xlim(axk, [1 T]);
            set(axk, 'TickDir', 'out', 'Box', 'off');

            if k < p
                set(axk, 'XTickLabel', []);
            else
                xlabel(axk, 'Frame');
            end
        end
    end

    % ----------------------------------------------------------
    %  onAxesClick — identify clicked region; draw crosshair; show stat value
    % ----------------------------------------------------------
    function onAxesClick(~, ~)
        pt = get(ax, 'CurrentPoint');
        x  = round(pt(1, 1));
        y  = round(pt(1, 2));
        xl = xlim(ax); yl = ylim(ax);
        if x < xl(1) || x > xl(2) || y < yl(1) || y > yl(2); return; end

        if x < 1 || x > nc || y < 1 || y > nr; return; end

        %% Delete previous crosshair
        if ~isempty(hCrosshair) && all(isvalid(hCrosshair))
            delete(hCrosshair);
        end

        %% Draw thin green crosshair
        hold(ax, 'on');
        hH = plot(ax, xl, [y y], '-', 'Color', [0 0.85 0], 'LineWidth', 0.8);
        hV = plot(ax, [x x], yl, '-', 'Color', [0 0.85 0], 'LineWidth', 0.8);
        hold(ax, 'off');
        hCrosshair = [hH, hV];

        %% Region label
        rId = subRegions(y, x);
        if rId >= 1 && rId <= numel(atlas.infoRegions.name)
            rname = atlas.infoRegions.name{rId};
            racr  = atlas.infoRegions.acr{rId};
            regionStr = sprintf('%s\n(%s)  [ID %d]', rname, racr, rId);
        else
            regionStr = sprintf('No label  [ID %d]', rId);
        end

        %% Stat value (+ p-value for tstat/zstat) at clicked voxel
        statLabel = statNames{curStatIdx};
        if ~isempty(lastDisplayMap) && x <= size(lastDisplayMap, 2) && y <= size(lastDisplayMap, 1)
            val = lastDisplayMap(y, x);
            if isnan(val)
                valStr = sprintf('%s = (below threshold)', statLabel);
            else
                valStr = sprintf('%s = %.3f', statLabel, val);

                % Append p-value for t/z stats using normal approximation (valid for large df)
                if ismember(statLabel, {'tstat', 'zstat'})
                    p = 2 * normcdf(-abs(val));
                    if p >= 0.001
                        valStr = sprintf('%s,  p = %.3f', valStr, p);
                    else
                        valStr = sprintf('%s,  p = %.0e', valStr, p);
                    end
                end
            end
        else
            valStr = '';
        end

        txtRegion.String = sprintf('%s\n%s', regionStr, valStr);
    end

end  % main function


% =========================================================
%  LOCAL helper: blue–white–red diverging colormap
% =========================================================
function cmap = bwr(n)
    n2 = floor(n / 2);
    nr = n - n2;
    % Blue (0,0,1) → White (1,1,1): first half
    r_lo = linspace(0, 1, n2)';
    g_lo = linspace(0, 1, n2)';
    b_lo = ones(n2, 1);
    % White (1,1,1) → Red (1,0,0): second half
    r_hi = ones(nr, 1);
    g_hi = linspace(1, 0, nr)';
    b_hi = linspace(1, 0, nr)';
    cmap = [r_lo, g_lo, b_lo; r_hi, g_hi, b_hi];
end
