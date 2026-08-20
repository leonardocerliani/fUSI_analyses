% FIR_ridge_simulation.m
%
% Simulation demonstrating HRF shape recovery using:
%   (A) Onset-delta + temporal shifts  [CORRECT approach]
%   (B) Sustained-boxcar + temporal shifts  [WRONG approach, mirrors fn.generate_fir_basis]
%
% Run each %% cell interactively in the MATLAB editor.
%
% CELLS:
%   1 — Setup & parameters
%   2 — Build simulated time course (boxcar → HRF convolution + noise)
%   3 — Build both design matrices + show their structure
%   4 — OLS fit on both matrices (no regularisation)
%   5 — Ridge LOO-CV on the correct (onset-delta) matrix
%   6 — Lambda selection curve


%% Cell 1 — Setup & parameters

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));
addpath(genpath('.'));

% ---- simulation parameters (edit freely) ----
TR              = 0.2;    % seconds per frame
T               = 6000;   % total frames
stim_dur_s      = 15;     % stimulus duration (s)

noise_std       = 0.3;    % noise std — increase to 2, 5 to see degradation
time_resampling = 1;      % FIR node spacing (s) — 27 nodes for 15+12 s window
time_window_after_offset = 12;  % post-stimulus window (s)
smooth_win_s    = 5;      % moving-average smoothing window applied to betas (s); 0 = off
lambda_grid     = logspace(-2, 4, 20);

% Trial onset frames (5 stimuli)
onset_frames = [1000, 2000, 3000, 4000, 5000];

% Canonical HRF to use for ground truth
chaoyi_hrfParams = [2.4  8  0.8  0.9  6  0  16];


%% Cell 2 — Build simulated time course

% ---- Sustained stimulus boxcar ----
stim_box   = zeros(T, 1);
stim_nframes = round(stim_dur_s / TR);
for oi = 1:numel(onset_frames)
    istart = onset_frames(oi);
    iend   = min(istart + stim_nframes - 1, T);
    stim_box(istart:iend) = 1;
end

% ---- Convolve boxcar with HRF ----
hrf_kernel = fonduta.signal.hrf(TR, chaoyi_hrfParams);
y_clean    = conv(stim_box, hrf_kernel(:));
y_clean    = y_clean(1:T);

% ---- Add Gaussian noise ----
rng(42);
y_noisy = y_clean + noise_std * randn(T, 1);

% ---- z-score (same as in the analysis script) ----
y = (y_noisy - mean(y_noisy)) / std(y_noisy);

% ---- Plot time course ----
t_min = (1:T) * TR / 60;   % time axis in minutes

figure('Name', 'Sim: time course', 'Position', [50 500 1200 350]);
subplot(2,1,1);
plot(t_min, stim_box, 'k', 'LineWidth', 1.2);
title('Stimulus boxcar'); ylabel('On/Off'); ylim([-0.2 1.4]);
for oi = 1:numel(onset_frames)
    xline(onset_frames(oi)*TR/60, '--b', 'LineWidth', 0.8);
end

subplot(2,1,2);
plot(t_min, y, 'Color', [0.5 0.5 0.5]); hold on;
plot(t_min, zscore(y_clean), 'r-', 'LineWidth', 1.8);
title(sprintf('Simulated signal  (noise\\_std = %.1f)', noise_std), 'Interpreter', 'none');
ylabel('z-score'); xlabel('Time (min)');
legend('Noisy', 'Ground truth (z-scored)');
box off;


%% Cell 3 — Build both design matrices + visualise their structure

node_step = max(1, round(time_resampling / TR));  % frames per node (e.g. 5 for 1 s at TR=0.2 s)
K         = round((stim_dur_s + time_window_after_offset) / time_resampling);

fprintf('\nK = %d FIR nodes   node_step = %d frames (%g s)  window = %g s\n', ...
    K, node_step, time_resampling, stim_dur_s + time_window_after_offset);

% =========================================================================
% CORRECT: onset-delta + shifts
% Column k+1 = 1 at each frame exactly k*node_step frames after a trial onset.
% Beta k+1  = average signal at lag k*time_resampling s after onset.
% =========================================================================
onset_delta = zeros(T, 1);
onset_delta(onset_frames) = 1;

X_delta = zeros(T, K);
for k = 0:K-1
    sf           = k * node_step;
    shifted      = circshift(onset_delta, sf);
    shifted(1:sf) = 0;
    X_delta(:, k+1) = shifted;
end

% =========================================================================
% WRONG: sustained-boxcar + shifts  (what fn.generate_fir_basis does)
% Column k+1 = sustained boxcar shifted forward by k*node_step frames.
% Beta k+1  is a FIR *filter coefficient* — NOT the response at lag k.
% All columns are 1 during the stimulus → severe collinearity.
% =========================================================================
X_boxcar = zeros(T, K);
for k = 0:K-1
    sf           = k * node_step;
    shifted      = circshift(stim_box, sf);
    shifted(1:sf) = 0;
    X_boxcar(:, k+1) = shifted;
end

% ---- Visualise a zoom window around the first onset ----
zoom = 850:1250;

figure('Name', 'Sim: design matrices', 'Position', [50 100 1200 420]);
subplot(1,2,1);
imagesc(zoom * TR, 1:K, X_delta(zoom,:)'); colorbar;
xlabel('Time (s)'); ylabel('FIR node'); title('Onset-delta + shifts  [CORRECT]');
xline(onset_frames(1)*TR, '--w', 'onset', 'LineWidth', 1.5, 'LabelVerticalAlignment','bottom');

subplot(1,2,2);
imagesc(zoom * TR, 1:K, X_boxcar(zoom,:)'); colorbar;
xlabel('Time (s)'); ylabel('FIR node'); title('Boxcar + shifts  [WRONG]');
xline(onset_frames(1)*TR, '--w', 'onset', 'LineWidth', 1.5, 'LabelVerticalAlignment','bottom');
colormap('hot');

% ---- Column correlation matrices ----
figure('Name', 'Sim: column correlations', 'Position', [50 100 800 370]);
subplot(1,2,1);
imagesc(corr(X_delta));  colorbar; axis square; colormap('hot');
title('Column corr: Onset-delta  [sparse → low collinearity]');
xlabel('Node'); ylabel('Node');

subplot(1,2,2);
imagesc(corr(X_boxcar)); colorbar; axis square;
title('Column corr: Boxcar  [sustained → HIGH collinearity]');
xlabel('Node'); ylabel('Node');


%% Cell 4 — OLS fit on both design matrices

% Ground-truth reference: conv(one-trial boxcar, hrf) sampled at node times.
% This is what the onset-delta betas estimate: the average signal at each
% lag after onset for a sustained 15 s stimulus.  NOT the bare HRF kernel.
lag_times_s      = (0:K-1) * time_resampling;
boxcar_one_trial = [ones(stim_nframes, 1); zeros(K * node_step, 1)];
y_gt_conv        = conv(boxcar_one_trial, hrf_kernel(:));
node_frames_gt   = (0:K-1) * node_step + 1;
node_frames_gt   = min(node_frames_gt, numel(y_gt_conv));
hrf_gt           = y_gt_conv(node_frames_gt);
hrf_gt           = hrf_gt(:) / max(hrf_gt);   % peak-normalised to [0,1]

% Also keep the bare HRF for reference in the plot
node_frames_hrf = min(node_frames_gt, numel(hrf_kernel));
hrf_bare        = hrf_kernel(node_frames_hrf);
hrf_bare        = hrf_bare(:) / max(hrf_bare);

% ---- OLS via pseudoinverse ----
B_delta_ols  = pinv(X_delta)  * y;
B_boxcar_ols = pinv(X_boxcar) * y;

% Smooth betas (in node space) before plotting and similarity
smooth_win_nodes = max(1, round(smooth_win_s / time_resampling));
if smooth_win_s > 0
    B_delta_ols  = movmean(B_delta_ols,  smooth_win_nodes);
    B_boxcar_ols = movmean(B_boxcar_ols, smooth_win_nodes);
end

% Peak-normalise for visual comparison
norm_to_gt = @(b) b / (max(abs(b)) + eps) * max(hrf_gt);
B_delta_ols_n  = norm_to_gt(B_delta_ols);
B_boxcar_ols_n = norm_to_gt(B_boxcar_ols);

r_delta_ols  = corr(B_delta_ols(:),  hrf_gt);
r_boxcar_ols = corr(B_boxcar_ols(:), hrf_gt);

figure('Name', 'Sim: OLS recovery', 'Position', [50 100 1100 430]);
subplot(1,2,1);
plot(lag_times_s, hrf_gt,           'k--', 'LineWidth', 2.5); hold on;
plot(lag_times_s, B_delta_ols_n,    'b-',  'LineWidth', 2);
xline(stim_dur_s, ':k', 'offset', 'LabelVerticalAlignment', 'bottom');
yline(0, ':k');
title(sprintf('OLS — Onset-delta [CORRECT]   r = %.3f', r_delta_ols));
xlabel('Lag after onset (s)'); ylabel('Amplitude (a.u.)');
legend('Canonical HRF', 'OLS betas'); box off;

subplot(1,2,2);
plot(lag_times_s, hrf_gt,           'k--', 'LineWidth', 2.5); hold on;
plot(lag_times_s, B_boxcar_ols_n,   'r-',  'LineWidth', 2);
xline(stim_dur_s, ':k', 'offset', 'LabelVerticalAlignment', 'bottom');
yline(0, ':k');
title(sprintf('OLS — Boxcar FIR [WRONG]   r = %.3f', r_boxcar_ols));
xlabel('Lag after onset (s)');
legend('Canonical HRF', 'OLS betas'); box off;

fprintf('\nOLS  onset-delta : r = %.3f\n', r_delta_ols);
fprintf('OLS  boxcar FIR  : r = %.3f\n\n', r_boxcar_ols);


%% Cell 5 — Ridge LOO-CV on the correct (onset-delta) design matrix

% Build full response windows for LOO (K*node_step frames per trial)
win_len = K * node_step;
nTrials = numel(onset_frames);

trial_frames = zeros(nTrials, win_len);
for t = 1:nTrials
    trial_frames(t,:) = onset_frames(t) : onset_frames(t) + win_len - 1;
end
trial_frames(trial_frames > T) = T;

% ---- LOO-CV to select lambda ----
cv_mse = zeros(numel(lambda_grid), 1);

for li = 1:numel(lambda_grid)
    fold_mse = zeros(nTrials, 1);

    for fold = 1:nTrials
        test_f  = trial_frames(fold, :);
        test_f  = test_f(test_f >= 1 & test_f <= T);

        train_mask = true(T, 1);
        train_mask(test_f) = false;
        train_f = find(train_mask);

        B = ridge(y(train_f), X_delta(train_f,:), lambda_grid(li), 0);
        B = B(2:end);

        fold_mse(fold) = mean((y(test_f) - X_delta(test_f,:) * B).^2);
    end

    cv_mse(li) = mean(fold_mse(isfinite(fold_mse)));
end

[~, best_idx]  = min(cv_mse);
lambda_best    = lambda_grid(best_idx);

% ---- Final ridge fit with best lambda ----
B_ridge = ridge(y, X_delta, lambda_best, 0);
B_ridge = B_ridge(2:end);

% Smooth ridge betas (same window as OLS above)
if smooth_win_s > 0
    B_ridge = movmean(B_ridge, smooth_win_nodes);
end

B_ridge_n = norm_to_gt(B_ridge);

r_ridge = corr(B_ridge(:), hrf_gt);

% ---- Plot OLS vs Ridge vs ground truth ----
figure('Name', 'Sim: OLS vs Ridge (onset-delta)', 'Position', [50 100 680 430]);
hold on;
plot(lag_times_s, hrf_gt,          'k--', 'LineWidth', 2.5);
plot(lag_times_s, B_delta_ols_n,   'b-',  'LineWidth', 1.5);
plot(lag_times_s, B_ridge_n,       'g-',  'LineWidth', 2.5);
xline(stim_dur_s, ':k', 'offset', 'LabelVerticalAlignment', 'bottom');
yline(0, ':k');
hold off;

xlabel('Lag after onset (s)'); ylabel('Amplitude (a.u.)');
title(sprintf('Onset-delta design:  OLS r=%.3f  |  Ridge r=%.3f   (\\lambda=%.3g)', ...
    r_delta_ols, r_ridge, lambda_best), 'Interpreter', 'tex');
legend('Canonical HRF', sprintf('OLS  (r=%.3f)', r_delta_ols), ...
       sprintf('Ridge (r=%.3f)', r_ridge), 'Location', 'northeast');
box off;

fprintf('OLS  onset-delta : r = %.3f\n', r_delta_ols);
fprintf('Ridge onset-delta: r = %.3f   (best lambda = %.4g)\n', r_ridge, lambda_best);
fprintf('OLS  boxcar FIR  : r = %.3f  ← wrong approach\n\n', r_boxcar_ols);


%% Cell 6 — Lambda selection curve

figure('Name', 'Sim: LOO-CV lambda selection', 'Position', [50 100 560 380]);
semilogx(lambda_grid, cv_mse, 'b-o', 'MarkerFaceColor', 'b', 'MarkerSize', 5);
hold on;
semilogx(lambda_best, cv_mse(best_idx), 'r*', 'MarkerSize', 14, 'LineWidth', 2);
hold off;
xlabel('\lambda'); ylabel('Mean LOO MSE');
title(sprintf('Ridge LOO-CV:  best \\lambda = %.4g', lambda_best), 'Interpreter', 'tex');
legend('CV MSE', sprintf('Best \\lambda = %.4g', lambda_best), 'Interpreter', 'tex');
box off;
