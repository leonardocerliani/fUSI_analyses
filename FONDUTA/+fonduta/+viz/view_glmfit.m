function view_glmfit(resultFile)
% fonduta.viz.view_glmfit  Interactive GLM results viewer on Allen Atlas.
%
% Displays eta2 maps overlaid on the Allen Atlas histology registered to
% subject space. Left column: model/predictor selection, eta2 threshold
% slider, and clicked-region label.
%
% Usage:
%   fonduta.viz.view_glmfit('path/to/GLMSes33.mat')

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
% to avoid horizontal lines spanning the image edges.
se           = strel('diamond', 1);
subReg_named = subRegions;
subReg_named(subReg_named <= 1) = 0;   % zero out IDs 0 and 1
borders = (imdilate(subReg_named, se) ~= imerode(subReg_named, se)) & ...
          (subReg_named > 0) & ...
          (imerode(subReg_named, se) > 0);

[nr, nc] = size(subRegions);   % for click bounds check

%% ---- Model / predictor info ----
modelNames  = fieldnames(res.models);
nModels     = numel(modelNames);
curModel    = 1;
curPred     = 1;
lbModel     = [];
lbPred      = [];
eta2Thresh  = 0.05;   % default threshold

%% ---- Build figure ----
fig = figure('Name', 'GLM on Allen Atlas', 'NumberTitle', 'off', ...
    'Color', [1 1 1], 'Position', [60 60 1200 740]);

% ---- Left column: model list ----
pModel = uipanel(fig, 'Title', 'Model', ...
    'ForegroundColor', [1 0 0], 'BackgroundColor', 'white' , ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.50 0.22 0.49]);

lbModel = uicontrol(pModel, 'Style', 'listbox', ...
    'String', strrep(modelNames, '_', ' '), ...
    'Value', 1, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white' , 'ForegroundColor', 'w', ...
    'FontSize', 14, ...
    'Callback', @(src, ~) onModelChange(src.Value));

% ---- Left column: predictor list ----
pPred = uipanel(fig, 'Title', 'Predictor', ...
    'ForegroundColor', 'w', 'BackgroundColor', 'white', ...
    'FontSize', 14, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.28 0.22 0.20]);

lbPred = uicontrol(pPred, 'Style', 'listbox', ...
    'String', {}, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'BackgroundColor', 'white' , 'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'Callback', @(src, ~) onPredChange(src.Value));

% ---- Left column: eta2 threshold slider ----
pThresh = uipanel(fig, 'Title', 'η² threshold', ...
    'ForegroundColor', 'w', 'BackgroundColor', [1 1 1] , ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'Units', 'normalized', 'Position', [0.01 0.12 0.22 0.13]);

sliderThresh = uicontrol(pThresh, 'Style', 'slider', ...
    'Min', 0, 'Max', 0.5, 'Value', eta2Thresh, ...
    'SliderStep', [0.01/0.5, 0.05/0.5], ...   % 0.01 minor, 0.05 major
    'Units', 'normalized', 'Position', [0.04 0.15 0.70 0.50], ...
    'BackgroundColor', [1 1 1], ...
    'Callback', @onThreshChange);

txtThresh = uicontrol(pThresh, 'Style', 'text', ...
    'String', sprintf('%.2f', eta2Thresh), ...
    'Units', 'normalized', 'Position', [0.76 0.10 0.22 0.60], ...
    'BackgroundColor', [1 1 1] , 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'center');

% ---- Left column: region label ----
txtRegion = uicontrol(fig, 'Style', 'text', ...
    'String', 'Click on a region to identify it', ...
    'Units', 'normalized', 'Position', [0.01 0.01 0.22 0.10], ...
    'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
    'FontSize', 12, 'HorizontalAlignment', 'left');

% ---- Right: image axes ----
ax = axes(fig, 'Position', [0.25 0.05 0.65 0.90], ...
    'Color', 'k', 'XTick', [], 'YTick', []);
colormap(ax, hot(256));

cb = colorbar(ax, 'Color', 'w', 'Location', 'eastoutside');
cb.Label.String = 'eta2';
cb.Label.Color  = 'w';

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

    function updateDisplay()
        mdata   = res.models.(modelNames{curModel});
        eta2Map = squeeze(double(mdata.eta2(curPred, :, :))) .* bmask;

        % Flip to match orientation
        eta2Map = flipud(eta2Map);

        % Apply threshold: hide voxels below threshold (NaN → transparent)
        betaDisplay = eta2Map;
        betaDisplay(betaDisplay < eta2Thresh) = NaN;

        % Prepare layers (all [nr x nc])
        histoRGB  = cat(3, subHisto, subHisto, subHisto);
        borderRGB = zeros([size(borders), 3]);   % black base
        borderRGB(:,:,2) = 1;                    % set green channel to 1 → pure green



        % --- Draw ---
        cla(ax);
        hold(ax, 'on');

        % 1. Atlas histology (gray background)
        imagesc(ax, histoRGB);

        % 2. eta2 overlay (hot, 80% opacity above threshold)
        hb = imagesc(ax, betaDisplay);
        set(hb, 'AlphaData', double(~isnan(betaDisplay)) * 0.80);

        % 3. Region borders (white, semi-transparent)
        hbord = imagesc(ax, borderRGB);
        set(hbord, 'AlphaData', double(borders) * 0.35);

        hold(ax, 'off');

        % Fill axes, then add a 5% proportional margin so the brain doesn't
        % touch the frame edges
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

    function onAxesClick(~, ~)
        pt = get(ax, 'CurrentPoint');
        x  = round(pt(1, 1));
        y  = round(pt(1, 2));
        xl = xlim(ax); yl = ylim(ax);
        if x < xl(1) || x > xl(2) || y < yl(1) || y > yl(2); return; end

        if x >= 1 && x <= nc && y >= 1 && y <= nr
            rId = subRegions(y, x);   % subRegions already flipped
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
