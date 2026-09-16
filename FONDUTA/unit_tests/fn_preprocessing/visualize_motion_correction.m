function visualize_motion_correction(time, motionParams)
% VISUALIZE_MOTION_CORRECTION - Display motion correction quality control plots
%
% Syntax:
%   visualize_motion_correction(time, motionParams)
%
% Description:
%   Creates diagnostic plots showing estimated motion parameters across time.
%   Useful for quality control and identifying problematic frames.
%
% Inputs:
%   time         - Frame timestamps [T × 1 double] in seconds
%   motionParams - Motion parameters [T × 2 double]
%                  Column 1: X translation (pixels)
%                  Column 2: Y translation (pixels)
%
% Example:
%   visualize_motion_correction(PDI.time, PDI.motionParams)

% Calculate total displacement
totalMotion = sqrt(motionParams(:,1).^2 + motionParams(:,2).^2);

% Create figure
figure('Name', 'Motion Correction Quality Control', 'Position', [100 100 1000 700]);

% Plot X translation
subplot(3,1,1);
plot(time, motionParams(:,1), 'b-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('X shift (pixels)');
title('Horizontal Motion');
grid on;
% ylim_x = max(abs(motionParams(:,1))) * 1.2;
% if ylim_x > 0
%     ylim([-ylim_x, ylim_x]);
% end

% Plot Y translation
subplot(3,1,2);
plot(time, motionParams(:,2), 'r-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Y shift (pixels)');
title('Vertical Motion');
grid on;
% ylim_y = max(abs(motionParams(:,2))) * 1.2;
% if ylim_y > 0
%     ylim([-ylim_y, ylim_y]);
% end

% Plot total displacement
subplot(3,1,3);
plot(time, totalMotion, 'k-', 'LineWidth', 1);
hold on;
plot(time, ones(size(time)) * mean(totalMotion), 'g--', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Total displacement (pixels)');
title('Total Motion Magnitude');
legend('Total motion', 'Mean', 'Location', 'best');
grid on;

% Add summary statistics as text
stats_text = sprintf('Motion Statistics:\nMean: %.2f px\nMax: %.2f px\nStd: %.2f px', ...
    mean(totalMotion), max(totalMotion), std(totalMotion));
annotation('textbox', [0.15, 0.02, 0.3, 0.08], 'String', stats_text, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white', 'EdgeColor', 'black');

end

