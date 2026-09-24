function verify_DROPLET(savepath)
% VERIFY_DROPLET Interactive visualization tool to verify TTL synchronization and droplet events.
%
%   VERIFY_DROPLET(savepath)
%
%   Inputs:
%       savepath - Directory path where PDI.mat was saved by functional_reconstruction.
%                  Can also be the direct full path to PDI.mat.
%
%   Description:
%       Loads PDI.mat from savepath, calculates global fUSI percent signal change (% dS/S0),
%       plots hardware TTL channels alongside fUSI timelines and droplet events,
%       and attaches an interactive vertical cursor tracking line across subplots.

    %% 1. Input Validation & File Handling
    if nargin < 1 || isempty(savepath)
        error('savepath argument is required.');
    end

    % Support passing either the directory path or direct path to PDI.mat
    if endsWith(savepath, 'PDI.mat', 'IgnoreCase', true)
        pdiPath = savepath;
    else
        pdiPath = fullfile(savepath, 'PDI.mat');
    end

    if ~exist(pdiPath, 'file')
        error('File not found: %s', pdiPath);
    end

    fprintf('Loading PDI data from: %s ...\n', pdiPath);
    loadedData = load(pdiPath, 'PDI');
    if ~isfield(loadedData, 'PDI')
        error('Invalid file structure. PDI variable not found in %s', pdiPath);
    end
    PDI = loadedData.PDI;

    %% 2. Calculate Global Mean fUSI Signal (% dS/S0)
    TTLinfo = PDI.TTLinfo_CROPPED;
    timeTTL = TTLinfo(:, 1);

    % Flatten fUSI volume to [nVoxels x nt]
    nVoxels = size(PDI.PDI, 1) * size(PDI.PDI, 2);
    pdi2d   = reshape(PDI.PDI, [nVoxels, size(PDI.PDI, 3)]);

    % Compute median spatial signal across time
    rawSignal = median(pdi2d, 1);
    s0 = prctile(rawSignal, 5);
    if s0 == 0, s0 = eps; end
    fusiSignal_dS = ((rawSignal - s0) / s0) * 100;

    % Extract fUSI frame timestamps (falling edges on channel 3)
    idx_fusi_frames  = find(diff(TTLinfo(:, 3)) < 0);
    time_fusi_frames = timeTTL(idx_fusi_frames);

    if ~isempty(time_fusi_frames)
        fprintf('fUSI acquisition starts at %.2f sec\n', time_fusi_frames(1));
        ev_fusi = interp1(time_fusi_frames, fusiSignal_dS, timeTTL, 'linear', 0);
    else
        warning('No frame falling edges detected in TTL column 3.');
        ev_fusi = zeros(size(timeTTL));
    end

    %% 3. Plot Construction
    fig = figure('Name', 'TTL Channels and fUSI Events', 'Color', 'w');
    varyingCols   = find(std(TTLinfo) > 0);
    numTTL        = numel(varyingCols);
    totalGridRows = numTTL * 2;
    
    t   = tiledlayout(totalGridRows, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax  = gobjects(numTTL + 1, 1);

    % -------------------------------------------------------------------------
    % TOP SUBPLOTS: Varying TTL Channels
    % -------------------------------------------------------------------------
    for i = 1:numTTL
        colIdx = varyingCols(i);
        ax(i)  = nexttile(t, i);
        plot(ax(i), TTLinfo(:, 1), TTLinfo(:, colIdx)); 
        title(ax(i), sprintf('TTL Column %d', colIdx));
        grid(ax(i), 'on');
    end

    % -------------------------------------------------------------------------
    % BOTTOM SUBPLOT: fUSI Signal & Behavioral Events
    % -------------------------------------------------------------------------
    ax(end) = nexttile(t, numTTL + 1, [numTTL, 1]);
    hold(ax(end), 'on');

    % Shock Background Regions
    hShock = [];
    if isfield(PDI.stimInfo, 'shockStart') && ~isempty(PDI.stimInfo.shockStart)
        shockStart = PDI.stimInfo.shockStart;
        shockEnd   = PDI.stimInfo.shockEnd;
        for k = 1:numel(shockStart)
            if exist('xregion', 'file')
                hReg = xregion(ax(end), shockStart(k), shockEnd(k), ...
                    'FaceColor', [0.85, 0.78, 0.88], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
            else
                yl = [-3, 14];
                hReg = patch(ax(end), [shockStart(k) shockEnd(k) shockEnd(k) shockStart(k)], ...
                    [yl(1) yl(1) yl(2) yl(2)], [0.85, 0.78, 0.88], ...
                    'FaceAlpha', 0.4, 'EdgeColor', 'none');
            end
            if k == 1, hShock = hReg; end
        end
    end

    % fUSI Signal Trace
    hSignal = plot(ax(end), timeTTL, ev_fusi, 'Color', [0.12, 0.47, 0.71], 'LineWidth', 1.0);

    % Event Stems (BaseValue = 0)
    hTouch2 = []; hDrop = []; hTouch1 = [];
    if isfield(PDI.stimInfo, 'touch2') && ~isempty(PDI.stimInfo.touch2)
        touch2_onset = PDI.stimInfo.touch2;
        hTouch2 = stem(ax(end), touch2_onset, repmat(4.0, size(touch2_onset)), ...
            'LineStyle', ':', 'Color', [0.47, 0.67, 0.19], 'LineWidth', 1.0, ...
            'Marker', '^', 'MarkerFaceColor', [0.47, 0.67, 0.19], 'MarkerSize', 6, 'BaseValue', 0);
    end

    if isfield(PDI.stimInfo, 'dropTime') && ~isempty(PDI.stimInfo.dropTime)
        drop_onset = PDI.stimInfo.dropTime;
        hDrop = stem(ax(end), drop_onset, repmat(5.5, size(drop_onset)), ...
            'LineStyle', '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.0, ...
            'Marker', 'v', 'MarkerFaceColor', [0.85, 0.33, 0.10], 'MarkerSize', 6, 'BaseValue', 0);
    end

    if isfield(PDI.stimInfo, 'touch1') && ~isempty(PDI.stimInfo.touch1)
        touch1_onset = PDI.stimInfo.touch1;
        hTouch1 = stem(ax(end), touch1_onset, repmat(8.2, size(touch1_onset)), ...
            'LineStyle', '--', 'Color', [0.65, 0.05, 0.15], 'LineWidth', 1.0, ...
            'Marker', 'd', 'MarkerFaceColor', [0.65, 0.05, 0.15], 'MarkerSize', 6, 'BaseValue', 0);
    end

    % Subplot Formatting
    title(ax(end), 'fUSI Signal Timeline with Shock Artifact Verification', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel(ax(end), 'Hardware Timestamp (NIDAQ s)', 'FontSize', 10);
    ylabel(ax(end), '% \DeltaS/S_0', 'FontSize', 10);
    grid(ax(end), 'on');
    ax(end).GridColor = [0.85, 0.85, 0.85];
    ax(end).Box = 'off';

    yyaxis(ax(end), 'right');
    ax(end).YColor = 'k';
    ylim(ax(end), [-1, 9]);
    yticks(ax(end), [4.0, 5.5, 8.2]);
    yticklabels(ax(end), {'Touch 2', 'Drop', 'Touch 1'});
    ylabel(ax(end), 'Behavioral Events', 'FontSize', 10);

    % Legend Assembly
    legHandles = [hShock, hSignal, hDrop, hTouch1, hTouch2];
    legLabels  = {'Shock Window', 'fUSI Signal (% \DeltaS/S_0)', 'Drop', 'Touch 1', 'Touch 2'};
    validIdx   = arrayfun(@(x) isgraphics(x), legHandles);
    
    if any(validIdx)
        lgd = legend(ax(end), legHandles(validIdx), legLabels(validIdx), ...
            'Orientation', 'horizontal', 'Location', 'southoutside');
        lgd.FontSize = 8;
    end

    % Synchronize X-Axes
    linkaxes(ax, 'x');

    %% 4. Advanced 3-Tier Tick Configuration
    maxX = max(timeTTL);
    ticks5s = 0:5:ceil(maxX);
    tickLabels = cell(size(ticks5s));
    for k = 1:numel(ticks5s)
        if mod(ticks5s(k), 10) == 0
            tickLabels{k} = num2str(ticks5s(k));
        else
            tickLabels{k} = '';
        end
    end

    for i = 1:numel(ax)
        ax(i).XTick = ticks5s;
        ax(i).XTickLabel = tickLabels;
        ax(i).XMinorTick = 'on';
        ax(i).XAxis.MinorTickValues = 0:1:ceil(maxX);
        
        ax(i).XMinorGrid = 'off';
        ax(i).YMinorGrid = 'off';
        
        grid(ax(i), 'on');
        ax(i).GridColor = [0.85, 0.85, 0.85];
        ax(i).GridAlpha = 0.5;
        
        ax(i).TickLength = [0.003, 0.005];
        ax(i).TickDir = 'out';
    end

    %% 5. Continuous Interactive Line (Figure Canvas Callback)
    drawnow; % Force UI render to retrieve accurate pixel bounds
    fullLine = annotation(fig, 'line', [0.5 0.5], [0.1 0.95], ...
        'Color', [1 0 0], 'LineStyle', '--', 'LineWidth', 1.2);
        
    set(fig, 'WindowButtonMotionFcn', @(~, ~) moveFullLine(ax, fullLine));
end

%% Nested Callback Function for Interactive Cursor Line
function moveFullLine(axList, lineObj)
    cp   = get(axList(end), 'CurrentPoint');
    xVal = cp(1,1);
    xLim = axList(end).XLim;

    if xVal >= xLim(1) && xVal <= xLim(2)
        posBottom = getpixelposition(axList(end));
        posTop    = getpixelposition(axList(1));
        figPos    = getpixelposition(ancestor(axList(1), 'figure'));

        % Normalized horizontal position [0, 1]
        normX = posBottom(1) + (xVal - xLim(1)) / (xLim(2) - xLim(1)) * posBottom(3);
        normX = normX / figPos(3);

        % Vertical span spanning from bottom axis to top axis
        normY_bottom = posBottom(2) / figPos(4);
        normY_top    = (posTop(2) + posTop(4)) / figPos(4);

        set(lineObj, 'X', [normX, normX], 'Y', [normY_bottom, normY_top]);
    end
end