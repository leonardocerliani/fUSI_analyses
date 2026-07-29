function behDesign = build_behavior_regressors(PDI, hrf_kernel, speedThresh)
% fn.build_behavior_regressors  Build running speed regressors and exclusion mask.
%
% Resamples wheel speed to scan frame timestamps, creates smoothed running
% speed signal, and computes a mask for timepoints contaminated by running
% (used in the steady-state visual analysis, model M8).
%
% Inputs:
%   PDI         - PDI data struct; must contain:
%                   .wheelInfo.time       wheel encoder timestamps (s)
%                   .wheelInfo.wheelspeed wheel speed samples
%                   .time                 [1 x nt] scan frame timestamps (s)
%   hrf_kernel  - [k x 1] HRF kernel vector (from fonduta.signal.hrf)
%   speedThresh - scalar speed threshold for steadyExcludeMask
%                 (same units as PDI.wheelInfo.wheelspeed)
%
% Output:
%   behDesign - struct with fields:
%     .wheelSpeedAbs     [nt x 1] absolute wheel speed resampled to scan frames
%     .wheelSpeedSmooth  [nt x 1] Gaussian-smoothed wheel speed (window = 10)
%     .steadyExcludeMask [nt x 1] logical; true where HRF-convolved thresholded
%                          speed > 0 (frames to exclude in steady visual analysis)
%
% Notes:
%   HRF convolution of wheel speed (hrf(wheel)) is applied explicitly in the
%   orchestrator, not here, to keep model specifications readable.
%   hrf_kernel is still needed here to build steadyExcludeMask.

    %% Resample wheel speed to scan frame timestamps
    wheelSpeedAbs = abs(interp1( ...
        PDI.wheelInfo.time, ...
        PDI.wheelInfo.wheelspeed, ...
        PDI.time, ...
        'linear', 'extrap'));

    wheelSpeedAbs = fillmissing(wheelSpeedAbs(:), 'nearest');

    %% Smoothed variant
    wheelSpeedSmooth = smoothdata(wheelSpeedAbs, 'gaussian', 10);

    %% Steady-state exclusion mask
    % Timepoints where HRF-convolved thresholded speed > 0 are excluded
    % from the stationary visual analysis (M8).
    wheelSpeedThresholded                             = wheelSpeedAbs;
    wheelSpeedThresholded(wheelSpeedThresholded < speedThresh) = 0;
    wheelSpeedConvThresholded = filter(hrf_kernel, 1, wheelSpeedThresholded);
    steadyExcludeMask         = wheelSpeedConvThresholded > 0;

    %% Pack output
    behDesign.wheelSpeedAbs     = wheelSpeedAbs;
    behDesign.wheelSpeedSmooth  = wheelSpeedSmooth;
    behDesign.steadyExcludeMask = steadyExcludeMask;

end
