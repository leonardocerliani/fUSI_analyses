function B = generate_fir_basis(input_vector, TR, stim_duration, ...
                               time_window_after_offset, time_resampling, basis_type)
% fn.generate_fir_basis  Build an FIR temporal lag basis expansion for one predictor.
%
% Converts a 1-D input signal into an [T × N] FIR design matrix by convolving
% the signal with N causal basis functions (tent or boxcar), each centred at a
% different temporal lag within the response window W = stim_duration + time_window_after_offset.
%
% The function is agnostic to the type of input:
%   • Binary stimulus boxcar (0/1):
%       Column k captures how much stimulus energy at lag t_k seconds ago predicts
%       the current response.  The GLM then estimates the average HRF shape.
%   • Pre-centred continuous predictor (e.g., wheel_c = wheel - mean(wheel),
%     or interaction = stim_all .* wheel_c):
%       Column k captures how much of the modulator at lag t_k ago predicts
%       the current response — naturally scaling tent weights by amplitude.
%     IMPORTANT: always centre continuous signals before calling this function.
%
% Algorithm:
%   For each node k at lag t_k = (k-1) * time_resampling:
%     1. Build a causal kernel h_k of length W_frames, evaluated at lags 0, TR, 2*TR, ...
%        • tent   : h_k(tau) = max(0, 1 - |tau - t_k| / time_resampling)
%        • boxcar : h_k(tau) = 1  if  (k-1)*time_resampling <= tau < k*time_resampling, else 0
%     2. Column k of B = filter(h_k, 1, input_vector)
%        i.e., B(t, k) = sum_{j=0}^{W_frames} h_k(j*TR) * input_vector(t - j)
%
% Inputs:
%   input_vector            [T × 1] raw signal (binary or pre-centred continuous).
%   TR                      Frame acquisition time in seconds (e.g., 0.2 s).
%   stim_duration           Stimulus-on duration in seconds (e.g., 15 s).
%   time_window_after_offset Post-stimulus window in seconds (e.g., 12 s).
%   time_resampling         Node/bin spacing in seconds (default = 0.5 s).
%   basis_type              'tent' (default) or 'boxcar'.
%
% Output:
%   B  [T × N]  FIR design matrix block.
%               N = round(W / time_resampling),
%               where W = stim_duration + time_window_after_offset.
%               B is NOT z-scored — pass skip_zscore=true to fonduta.glm.engine.
%
% Examples:
%   % Binary stimulus
%   B_stim = fn.generate_fir_basis(stim_all, TR, 15, 12, 0.5, 'tent');
%   % → [T × 54] for TR=0.2, W=27 s, time_resampling=0.5 s
%
%   % Pre-centred continuous predictor
%   wheel_c = wheel - mean(wheel);
%   B_wheel = fn.generate_fir_basis(wheel_c, TR, 15, 12, 0.5, 'tent');
%
%   % Interaction (pre-computed before calling)
%   interact = stim_all .* wheel_c;
%   B_inter  = fn.generate_fir_basis(interact, TR, 15, 12, 0.5, 'tent');
%
% See also: analysis_visual_FONDUTA_FIR, fonduta.glm.engine

%% ---- Defaults --------------------------------------------------------
if nargin < 5 || isempty(time_resampling)
    time_resampling = 0.5;
end
if nargin < 6 || isempty(basis_type)
    basis_type = 'tent';
end

basis_type = lower(basis_type);
if ~ismember(basis_type, {'tent', 'boxcar'})
    error('fn:generate_fir_basis:UnknownBasis', ...
          'basis_type must be ''tent'' or ''boxcar''. Got: ''%s''.', basis_type);
end

%% ---- Derived quantities ----------------------------------------------
input_vector = input_vector(:);          % ensure [T × 1] column vector
T  = numel(input_vector);

W_s      = stim_duration + time_window_after_offset;   % total window (s)
N        = round(W_s / time_resampling);               % number of nodes/bins
W_frames = round(W_s / TR);                            % window length in frames

% Node centre times in seconds (relative to stimulus onset / lag 0)
t_nodes = (0 : N-1) * time_resampling;    % [1 × N]

% Lag-axis for building kernels: 0, TR, 2*TR, ... up to W_s
lag_times = (0 : W_frames) * TR;          % [1 × (W_frames+1)]

%% ---- Build FIR design matrix via causal filtering -------------------
% Each column k = filter(h_k, 1, input_vector), where h_k is the causal
% basis kernel for node k evaluated at lags lag_times.
%
% filter(b, 1, x) computes the linear convolution of b with x (IIR form),
% giving: B(t, k) = sum_{j=0}^{W_frames} h_k(j) * input_vector(t - j)
% Negative-index input_vector values are implicitly 0 (causal / zero-padded).

B = zeros(T, N);

for k = 1:N
    switch basis_type
        case 'tent'
            % Triangular hat centred at lag t_nodes(k)
            h_k = max(0, 1 - abs(lag_times - t_nodes(k)) / time_resampling);

        case 'boxcar'
            % Flat window covering [(k-1)*dt, k*dt)
            lo  = (k - 1) * time_resampling;
            hi  =  k      * time_resampling;
            h_k = double(lag_times >= lo & lag_times < hi);
    end

    % Causal filtering: convolve input with the basis kernel
    B(:, k) = filter(h_k(:), 1, input_vector);
end

end
