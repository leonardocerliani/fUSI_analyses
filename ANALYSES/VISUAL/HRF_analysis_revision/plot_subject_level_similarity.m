function plot_subject_level_similarity(res_M1, res_M5, res_M8, HRF_glm_files)
% PLOT_SUBJECT_LEVEL_CORRELATIONS Displays boxplots with outlier labels, 
% prints statistical summaries, and plots ROC threshold curves for GLM models.

%% 1. Data Preparation
models = {res_M1, res_M8, res_M5};
names  = {'M1', 'M8', 'M5'};
colors = {'b', 'k', 'r'};

data_matrix = [res_M1.eta2_corrs(:,1), res_M8.eta2_corrs(:,1), res_M5.eta2_corrs(:,1)];
sub_labels  = erase({HRF_glm_files.name}, {'glm_run-', '.mat'});

%% 2. Boxplot across Models with Outlier Labels
figure('Color', 'w', 'Name', 'Subject Correlations Boxplot');
h = boxplot(data_matrix, 'Labels', names);
ylabel('Spatial Correlation (r)');
grid on; box off;

outliers = findobj(h, 'Tag', 'Outliers');
for iCol = 1:numel(outliers)
    x = get(outliers(iCol), 'XData');
    y = get(outliers(iCol), 'YData');
    
    for k = 1:numel(y)
        sub_idx = find(data_matrix(:, x(k)) == y(k), 1);
        text(x(k) + 0.08, y(k), sub_labels{sub_idx}, ...
            'Interpreter', 'none', 'FontSize', 8, 'VerticalAlignment', 'middle');
    end
end

%% 3. Print Summary Statistics
fprintf('\n--- Subject-Level Correlation Summary ---\n');
for i = 1:numel(models)
    r = models{i}.eta2_corrs(:, 1);
    fprintf('%s: median = %.3f (IQR: %.3f) | mean = %.3f (std: %.3f)\n', ...
        names{i}, median(r), iqr(r), mean(r), std(r));
end
fprintf('\n');

%% 4. Plot ROC Curves
res_list   = {res_M1, res_M5, res_M8};
roc_labels = {'M1: Stim Only', 'M5: Behavior', 'M8: Steady Visual'};
roc_colors = {'b', 'r', 'k'};

figure('Color', 'w', 'Name', 'Activation Threshold ROC Curves');
hold on;

for i = 1:numel(res_list)
    res = res_list{i};
    plot(res.pctile_steps, ...
        mean(res.pctile_corr(:, :, 1), 1, 'omitnan'), ...
        '-o', 'Color', roc_colors{i}, 'LineWidth', 2, ...
        'MarkerFaceColor', roc_colors{i}, 'DisplayName', roc_labels{i});
end

hold off;
grid on; box off;
xlabel('Lowest \eta^2 Voxels Excluded (%)');
ylabel('Spatial Correlation (r)');
title('HRF vs FIR Spatial Correlation vs Activation Threshold');
legend('Location', 'southwest');

end