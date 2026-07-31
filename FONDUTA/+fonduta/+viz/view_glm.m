function view_glm(resultFile)
% fonduta.viz.view_glm  Interactive GLM viewer: brain slice + design matrix.
%
% Three-column layout:
%   Left   — model/predictor selection, η² threshold slider, region label
%   Middle — η² map overlaid on Allen Atlas histology (subject space)
%   Right  — design matrix (Xmodel columns) for the selected model
%
% Usage:
%   fonduta.viz.view_glm('path/to/glm_run-142136.mat')

%% ---- Load results ----
tmp = load(resultFile);
res = tmp.data;

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

% Extract functional slice — [nx x ny] same space as beta maps
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

%% ---- Model / predictor info ----
modelNames  = fieldnames(res.models);
nModels     = numel(modelNames);
curModel    = 1;
curPred     = 1;
lbModel     = [];
lbPred      = [];
eta2Thresh  = 0.05;

%% ---- Build figure (wider: 1700 x 740) ----
fig = figure('Name', 'GLM viewer', 'NumberTitle', 'off', ...
    'Color', [1 1 1], 'Position', [60 60 1700 740]);

% =========================================================
%  LEFT COLUMN  (0–18%)
% =========================================================

% ---- Model list ----
pModel = uipanel(fig, 'Title', 'Model', ...
    'ForegroundColor', [1 0 0], 'BackgroundColor', 'white', ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.50 0.155 0.49]);

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
    'Units', 'normalized', 'Position', [0.01 0.28 0.155 0.20]);

lbPred = uicontrol(pPred, 'Style', 'listbox', ...
    'String', {}, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white', 'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'Callback', @(src, ~) onPredChange(src.Value));

% ---- η² threshold slider ----
pThresh = uipanel(fig, 'Title', 'η² threshold', ...
    'ForegroundColor', 'w', 'BackgroundColor', [1 1 1], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.12 0.155 0.13]);

sliderThresh = uicontrol(pThresh, 'Style', 'slider', ...
    'Min', 0, 'Max', 0.5, 'Value', eta2Thresh, ...
    'SliderStep', [0.01/0.5, 0.05/0.5], ...
    'Units', 'normalized', 'Position', [0.04 0.15 0.70 0.50], ...
    'BackgroundColor', [1 1 1], ...
    'Callback', @onThreshChange);

txtThresh = uicontrol(pThresh, 'Style', 'text', ...
    'String', sprintf('%.2f', eta2Thresh), ...
    'Units', 'normalized', 'Position', [0.76 0.10 0.22 0.60], ...
    'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'center');

% ---- Region label ----
txtRegion = uicontrol(fig, 'Style', 'text', ...
    'String', 'Click on a region to identify it', ...
    'Units', 'normalized', 'Position', [0.01 0.01 0.155 0.10], ...
    'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'left');

% =========================================================
%  MIDDLE COLUMN (19–64%): brain slice + vertical colorbar
% =========================================================
ax = axes(fig, 'Position', [0.19 0.05 0.42 0.90], ...
    'Color', 'k', 'XTick', [], 'YTick', []);
colormap(ax, hot(256));

cb = colorbar(ax, 'Color', 'w', 'Location', 'eastoutside');
cb.Label.String = 'eta2';
cb.Label.Color  = 'w';

% =========================================================
%  RIGHT COLUMN (65–98%): design matrix — 1/3 of figure width
% =========================================================
pDesign = uipanel(fig, 'Title', 'Design matrix', ...
    'ForegroundColor', 'k', 'BackgroundColor', 'w', ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.65 0.01 0.34 0.98]);

% Formula text widget at top of design panel (updated on model change)
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

        % Rebuild predictor list
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

    function onThreshChange(src, ~)
        eta2Thresh = src.Value;
        txtThresh.String = sprintf('%.2f', eta2Thresh);
        updateDisplay();
    end

    % ----------------------------------------------------------
    %  updateDisplay — redraws the brain-slice axes (middle col)
    % ----------------------------------------------------------
    function updateDisplay()
        mdata   = res.models.(modelNames{curModel});
        eta2Map = squeeze(double(mdata.eta2(curPred, :, :))) .* bmask;

        eta2Map = flipud(eta2Map);

        betaDisplay = eta2Map;
        betaDisplay(betaDisplay < eta2Thresh) = NaN;

        histoRGB  = cat(3, subHisto, subHisto, subHisto);
        borderRGB = zeros([size(borders), 3]);
        borderRGB(:,:,2) = 1;

        cla(ax);
        hold(ax, 'on');
        imagesc(ax, histoRGB);
        hb = imagesc(ax, betaDisplay);
        set(hb, 'AlphaData', double(~isnan(betaDisplay)) * 0.80);
        hbord = imagesc(ax, borderRGB);
        set(hbord, 'AlphaData', double(borders) * 0.35);
        hold(ax, 'off');

        axis(ax, 'tight');
        xl = xlim(ax);  yl = ylim(ax);
        mx = 0.05 * (xl(2) - xl(1));
        my = 0.05 * (yl(2) - yl(1));
        xlim(ax, [xl(1) - mx,  xl(2) + mx]);
        ylim(ax, [yl(1) - my,  yl(2) + my]);

        colormap(ax, hot(256));

        predLabel = mdata.predictor_labels{curPred};
        title(ax, sprintf('%s  —  %s', ...
            strrep(modelNames{curModel}, '_', ' '), ...
            strrep(predLabel, '_', ' ')), ...
            'Color', 'w', 'FontSize', 13, 'Interpreter', 'none');
    end

    % ----------------------------------------------------------
    %  updateDesignMatrix — redraws stacked subplots (right col)
    % ----------------------------------------------------------
    function updateDesignMatrix()
        % Delete all existing axes inside the design matrix panel
        delete(findobj(pDesign, 'Type', 'axes'));

        mdata  = res.models.(modelNames{curModel});
        X      = mdata.Xmodel;                    % [T x p]
        labels = mdata.predictor_labels(1:end-1); % drop 'intercept'
        [T, p] = size(X);

        % Build formula string and display in the formula text widget
        formula = ['Y ~ ' strjoin(strrep(labels, '_', ' '), ' + ')];
        txtFormula.String = formula;

        % Compute normalized positions inside pDesign for p subplots.
        % topMargin accounts for the formula text widget at the top (0.94–0.99).
        topMargin    = 0.10;   % leave room for formula widget above subplots
        bottomMargin = 0.07;   % fraction reserved at bottom for xlabel
        gapFraction  = 0.01;   % gap between subplots

        totalH = 1 - topMargin - bottomMargin - (p - 1) * gapFraction;
        axH    = totalH / p;

        lineColor = [0.15 0.15 0.15];

        for k = 1:p
            % Position: bottom of k-th subplot (k=1 is top)
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
    %  onAxesClick — identify clicked region in brain slice
    % ----------------------------------------------------------
    function onAxesClick(~, ~)
        pt = get(ax, 'CurrentPoint');
        x  = round(pt(1, 1));
        y  = round(pt(1, 2));
        xl = xlim(ax); yl = ylim(ax);
        if x < xl(1) || x > xl(2) || y < yl(1) || y > yl(2); return; end

        if x >= 1 && x <= nc && y >= 1 && y <= nr
            rId = subRegions(y, x);
            if rId >= 1 && rId <= numel(atlas.infoRegions.name)
                rname = atlas.infoRegions.name{rId};
                racr  = atlas.infoRegions.acr{rId};
                txtRegion.String = sprintf('%s\n(%s)  [ID %d]', rname, racr, rId);
            else
                txtRegion.String = sprintf('No label  [ID %d]', rId);
            end
        end
    end

end  % main function
