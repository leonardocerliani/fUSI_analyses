function figHandle = verify_droplet_reconstruction(PDI, TTLinfo, cfg, pdi)
% VERIFY_DROPLET_RECONSTRUCTION Plots aligned fUSI signal against behavioral events.

%% Handle Optional Inputs
if nargin < 2; TTLinfo = []; end
if nargin < 3; cfg = []; end
if nargin < 4; pdi = []; end

% Extract or format 2D image matrix [voxels x frames]
if isfield(PDI, 'pdi2d') && ~isempty(PDI.pdi2d)
    pdi2d = PDI.pdi2d;
elseif isfield(PDI, 'PDI') && ~isempty(PDI.PDI)
    pdi2d = reshape(PDI.PDI, [PDI.Dim.nx * PDI.Dim.nz, PDI.Dim.nt]);
elseif ~isempty(pdi)
    if isfield(PDI, 'Dim') && isfield(PDI.Dim, 'nx') && isfield(PDI.Dim, 'nz')
        nVoxels = PDI.Dim.nx * PDI.Dim.nz;
    else
        nVoxels = size(pdi, 1) * size(pdi, 2);
    end
    pdi2d = reshape(pdi, [nVoxels, size(pdi, 3)]);
else
    error('verify_droplet_reconstruction: missing image array.');
end

% -------------------------------------------------------------------------
% 1. TIME VECTOR & SIGNAL NORMALIZATION (% dS/S) - (Matches Manual Script)
% -------------------------------------------------------------------------
if isstruct(cfg) && isfield(cfg, 'processing_parameters') && isfield(cfg.processing_parameters, 'pdi_frame_channel')
    frameChan = cfg.processing_parameters.pdi_frame_channel;
else
    frameChan = 3; % Default Channel 3
end

if ~isempty(TTLinfo) && size(TTLinfo, 2) >= frameChan
    fusiTime = TTLinfo(diff(TTLinfo(:, frameChan)) > 0, 1);
    if numel(fusiTime) ~= size(pdi2d, 2)
        fusiTime = linspace(TTLinfo(1,1), TTLinfo(end,1), size(pdi2d, 2));
    end
else
    fusiTime = 1:size(pdi2d, 2);
end

rawSignal = median(pdi2d, 1);
s0 = prctile(rawSignal, 5); 
if s0 == 0; s0 = eps; end
fusiSignal_dS = ((rawSignal - s0) / s0) * 100; 

% -------------------------------------------------------------------------
% 2. DRAW SHOCK ARTIFACT SHADING BACKGROUND
% -------------------------------------------------------------------------
figHandle = figure('Color', 'w', 'Position', [100 100 1200 600], 'Name', 'fUSI Signal Timeline');
hold on;
c_shock = [0.4940 0.1840 0.5560]; % Purple
yLimits = [min(fusiSignal_dS)-2, max(fusiSignal_dS)+5];

if isfield(PDI, 'stimInfo') && isfield(PDI.stimInfo, 'shockInfo') && ~isempty(PDI.stimInfo.shockInfo)
    shockStarts = PDI.stimInfo.shockInfo.startTime;
    shockDuration = 1.5;
    
    for s = 1:numel(shockStarts)
        x_patch = [shockStarts(s), shockStarts(s)+shockDuration, shockStarts(s)+shockDuration, shockStarts(s)];
        y_patch = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
        
        if s == 1
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Shock Window');
        else
            patch(x_patch, y_patch, c_shock, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end
end

% -------------------------------------------------------------------------
% 3. PLOT CONTINUOUS fUSI SIGNAL (Left Y-Axis)
% -------------------------------------------------------------------------
yyaxis left
plot(fusiTime, fusiSignal_dS, 'Color', [0.00 0.45 0.74 0.9], 'LineWidth', 1.1, 'DisplayName', 'fUSI Signal (% \DeltaS/S_0)');
ylabel('% \DeltaS/S_0');
ylim(yLimits);
ax = gca;
ax.YColor = [0.15 0.15 0.15];

% -------------------------------------------------------------------------
% 4. PLOT DISCRETE EVENTS (Right Y-Axis)
% -------------------------------------------------------------------------
yyaxis right
ylabel('Behavioral Events');
ax.YColor = 'k';

y_drop = 1; y_t1 = 2; y_t2 = 3;
c_drop = [0.8500 0.3250 0.0980]; % Orange
c_t1   = [0.6350 0.0780 0.1840]; % Red (Touch 1)
c_t2   = [0.4660 0.6740 0.1880]; % Green (Touch 2)

if isfield(PDI, 'stimInfo')
    if isfield(PDI.stimInfo, 'dropInfo') && ~isempty(PDI.stimInfo.dropInfo)
        stem(PDI.stimInfo.dropInfo.startTime, repmat(y_drop, height(PDI.stimInfo.dropInfo), 1), ...
            'Color', c_drop, 'Marker', 'v', 'MarkerFaceColor', c_drop, 'LineWidth', 1.2, 'DisplayName', 'Drop');
    end
    if isfield(PDI.stimInfo, 'touch1Info') && ~isempty(PDI.stimInfo.touch1Info)
        stem(PDI.stimInfo.touch1Info.startTime, repmat(y_t1, height(PDI.stimInfo.touch1Info), 1), ...
            'Color', c_t1, 'Marker', 'o', 'MarkerFaceColor', c_t1, 'LineWidth', 1.2, 'DisplayName', 'Touch 1');
    end
    if isfield(PDI.stimInfo, 'touch2Info') && ~isempty(PDI.stimInfo.touch2Info)
        stem(PDI.stimInfo.touch2Info.startTime, repmat(y_t2, height(PDI.stimInfo.touch2Info), 1), ...
            'Color', c_t2, 'Marker', '^', 'MarkerFaceColor', c_t2, 'LineWidth', 1.2, 'DisplayName', 'Touch 2');
    end
end

ylim([-2 4]); 
yticks([y_drop, y_t1, y_t2]);
yticklabels({'Drop', 'Touch 1', 'Touch 2'});

% -------------------------------------------------------------------------
% 5. FORMATTING & LEGEND
% -------------------------------------------------------------------------
xlabel('Hardware Timestamp (NIDAQ s)');
title('fUSI Signal Timeline with Shock Artifact Verification');
grid on;
box off;
legend('Location', 'southoutside', 'Orientation', 'horizontal');
hold off;

end