function [wheel, wheelSmooth, runningFrameMask] = build_wheel_signal(PDI, speedThresh, hrf_kernel)
% fn.build_wheel_signal  Resample wheel speed and compute running frame mask.
%
% Resamples wheel speed to scan frame timestamps, creates a smoothed variant,
% and computes a frame-level mask of timepoints contaminated by running.
%
% Inputs:
%   PDI         - PDI data struct; must contain:
%                   .wheelInfo.time       wheel encoder timestamps (s)
%                   .wheelInfo.wheelspeed wheel speed samples
%                   .time                 [1 x nt] scan frame timestamps (s)
%   speedThresh - scalar speed threshold (same units as PDI.wheelInfo.wheelspeed)
%   hrf_kernel  - [k x 1] HRF kernel vector (from fonduta.signal.hrf)
%
% Outputs:
%   wheel            [nt x 1] absolute wheel speed resampled to scan frames
%   wheelSmooth      [nt x 1] Gaussian-smoothed wheel speed (window = 10)
%   runningFrameMask [nt x 1] logical; true at frames contaminated by running.
%                    Built by HRF-convolving thresholded wheel speed: any
%                    frame where this convolved signal > 0 is marked, including
%                    ~16 s after a running bout ends (HRF tail). Used to
%                    select stationary timepoints for M8.

    %% Resample wheel speed to scan frame timestamps
    wheel = abs(interp1( ...
        PDI.wheelInfo.time, ...    % 202406 encoder timestamps
        PDI.wheelInfo.wheelspeed, ...  % 202406 speed values
        PDI.time, ...              % 6600 fUSI frame timestamps
        'linear', 'extrap'));


    wheel = fillmissing(wheel(:), 'nearest');

    %% Smoothed variant
    wheelSmooth = smoothdata(wheel, 'gaussian', 10);

    %% Running frame mask
    % Zero out subthreshold speed, convolve with HRF to capture the slow
    % hemodynamic tail after running bouts, then threshold at > 0.
    wheelThresholded                             = wheel;
    wheelThresholded(wheelThresholded < speedThresh) = 0;
    wheelConvThresholded = filter(hrf_kernel, 1, wheelThresholded);
    runningFrameMask     = wheelConvThresholded > 0;

end
