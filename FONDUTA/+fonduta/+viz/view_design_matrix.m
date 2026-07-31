function view_design_matrix(mdata)
% fonduta.viz.view_design_matrix  Plot the design matrix columns of a GLM model.
%
% Displays each column of mdata.Xmodel as a stacked subplot, labelled with
% the corresponding predictor name.  Xmodel is the z-scored design matrix
% stored inside each model result struct.
%
% Usage:
%   view_design_matrix(data.models.M7b_RunConv)
%
% Input:
%   mdata - one model struct from glmresult.models, containing:
%               .Xmodel           [T x p]   design matrix
%               .predictor_labels {1 x p+1} names (last = 'intercept', excluded)
%               .model_name       string

X      = mdata.Xmodel;                    % [T x p]
labels = mdata.predictor_labels(1:end-1); % drop 'intercept' column
[T, p] = size(X);

fig = figure('Color', 'w', ...
    'Name', ['Design matrix — ' strrep(mdata.model_name, '_', ' ')], ...
    'NumberTitle', 'off');

for k = 1:p
    ax = subplot(p, 1, k);

    plot(ax, 1:T, X(:, k), 'Color', [0.15 0.15 0.15], 'LineWidth', 0.8);

    ylabel(ax, strrep(labels{k}, '_', ' '), 'Interpreter', 'none');

    xlim(ax, [1 T]);
    set(ax, 'TickDir', 'out', 'Box', 'off');

    if k < p
        set(ax, 'XTickLabel', []);
    end
end

xlabel('Frame');
sgtitle(strrep(mdata.model_name, '_', ' '), ...
    'Interpreter', 'none', 'FontWeight', 'bold');

end
