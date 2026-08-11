FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));


TR         = 0.2;          % TR (seconds)


% Compute the Chaoyi HRF kernel
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]
chaoyi_hrfParams = [2.4 8 0.8 0.9 6 0 16];
[chaoyi_hrf_kernel, p_chaoyi] = fonduta.signal.hrf(TR, chaoyi_hrfParams);

% Compute the Chen 2023 HRF kernel
%   [delay_response, delay_undershoot, disp_response, disp_undershoot, ratio, onset, kernel_length_s]
chen2023_hrfParams = [4.95 8.69 1.1 1.1 1.8 0 32];
[chen2023_hrf_kernel, p_chen2023] = fonduta.signal.hrf(TR, chen2023_hrfParams);

% Build time axes
t_chaoyi = (0:length(chaoyi_hrf_kernel)-1) * TR;
t_chen2023 = (0:length(chen2023_hrf_kernel)-1) * TR;

% Plot both
figure;
hold on;

plot(t_chaoyi, chaoyi_hrf_kernel, 'LineWidth', 2);
plot(t_chen2023, chen2023_hrf_kernel, 'LineWidth', 2);

xlabel('Time (s)');
ylabel('Amplitude (a.u.)');
title('Comparison of HRF kernels');
legend('Chaoyi', 'Chen 2023', 'Location', 'best');
grid on;
hold off;


% Find maximum of each HRF
[max_chaoyi, idx_chaoyi] = max(chaoyi_hrf_kernel);
[max_chen2023, idx_chen2023] = max(chen2023_hrf_kernel);

% Convert indices to time
tmax_chaoyi = (idx_chaoyi - 1) * TR;
tmax_chen2023 = (idx_chen2023 - 1) * TR;

fprintf('Chaoyi HRF maximum: %.3f at %.2f s\n', max_chaoyi, tmax_chaoyi);
fprintf('Chen 2023 HRF maximum: %.3f at %.2f s\n', max_chen2023, tmax_chen2023);