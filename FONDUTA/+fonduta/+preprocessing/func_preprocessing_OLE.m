function do_preprocessing(anat_analysis_path, func_analysis_path, atlasPath)
% DO_PREPROCESSING - Preprocess functional ultrasound imaging (fUSI) data
%
% Syntax:
%   do_preprocessing(anat_analysis_path, func_analysis_path, atlasPath)
%   do_preprocessing()  % Interactive mode - prompts for paths
%
% Description:
%   Performs preprocessing of fUSI data including brain masking, motion
%   correction, outlier rejection, signal normalization, resampling,
%   filtering, and spatial smoothing.
%
% Inputs:
%   anat_analysis_path - (optional) Path to anatomical Data_analysis directory
%                        containing anatomic.mat and Transformation.mat
%                        Example: 'Data_analysis/ses-231215/run-113409-anat'
%   func_analysis_path - (optional) Path to functional Data_analysis directory
%                        containing PDI.mat (output from reconstruction)
%                        Example: 'Data_analysis/ses-231215/run-115047-func'
%   atlasPath          - (optional) Path to directory containing allen_brain_atlas.mat
%                        Example: '/path/to/atlas/directory'
%
%   If any input is not provided, a UI dialog will prompt for selection.
%
% Outputs:
%   Saves preprocessed data as prepPDI.mat in the functional data directory
%
% Example:
%   % Provide all paths directly
%   do_preprocessing('Data_analysis/ses-231215/run-113409-anat', ...
%                    'Data_analysis/ses-231215/run-115047-func', ...
%                    '/path/to/atlas')
%
%   % Interactive mode
%   do_preprocessing()
%
% See also: load_anat_and_func, Atlas2Individual, resamplePDI, DCThighpass, fillmissingTime

% Add src directory to path for helper functions
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

%% Handle optional input arguments

if nargin < 1
    anat_analysis_path = [];
end
if nargin < 2
    func_analysis_path = [];
end
if nargin < 3
    atlasPath = [];
end



%% Load all required data

fprintf('=== Loading Data ===\n');

% Load anatomical, functional, and atlas data
[PDI, anatomic, Transf, atlas] = load_anat_and_func(anat_analysis_path, func_analysis_path, atlasPath);

fprintf('=== Data Loading Complete ===\n\n');

%% Binary mask of the selected functional slice from Allen atlas taken to subject space

% In the anatomical preparation, we recorded the interesting slice
% as the 3rd value of the field anatomic.funSlice.
% 
% Now we need to create a mask from the allen atlas which will select the
% voxels in that slice for further processing.
% 
% To do so we first bring the atlas in the subject space using
% Transformation.mat
% 
% We select the corresponding anatomic.funSlice(3) and dilate it with a 
% filter of radius = 2
% 
% Finally, we store this in the PDI.mat
% 
% Note: For some reason the X and Z dimensions in anatomic.funcSlice
% are half of those in the anatomic/subAtlas. This requires investigation.

fprintf('=== Creating Brain Mask ===\n');

% Transform Allen atlas to subject (individual) space
subAtlas = Atlas2Individual(atlas, anatomic, Transf);

% Select the functional slice from the anatomic
% The slice number is the last element of anatomic.funcSlice
subRegions = subAtlas.Region.Data(:,:,anatomic.funcSlice(3));

% Create binary mask (1 = brain tissue, 0 = background)
bmask = double(subRegions > 1);

% Dilate the mask to include edge voxels
dilatation_radius = 2;
se = strel('disk', dilatation_radius);
bmask = imdilate(bmask, se);

% Store mask in PDI structure
PDI.bmask = bmask;

% Optional: Apply mask to functional data to zero out non-brain voxels
% This is commented out to preserve full data; mask can be applied during analysis
% PDI.PDI = bsxfun(@times, PDI.PDI, bmask);

fprintf('Brain mask created (dilation radius = %d)\n', dilatation_radius);

% Visualize the mask overlay on anatomical slices
visualize_brain_mask(subAtlas, bmask, anatomic.funcSlice(3));

fprintf('=== Brain Mask Creation Complete ===\n\n');

%% Rigid in-plane motion correction
% Corrects for small head movements during acquisition using rigid (translation-only)
% registration. Each frame is aligned to a median reference image using normalized
% cross-correlation as the similarity metric.
%
% Why median reference: Robust to outliers, represents typical anatomy
% Why translation-only: Head is fixed, only small shifts occur
% Why cross-correlation: Optimal for same-modality alignment (all frames are PDI)

fprintf('=== Performing Motion Correction ===\n');

% Create median reference image from all frames
ref = median(PDI.PDI, 3);

% Get dimensions
[nY, nX, nFrames] = size(PDI.PDI);

% Preallocate corrected data and motion parameters
cPDI = zeros(nY, nX, nFrames, 'like', PDI.PDI);
motionParams = zeros(nFrames, 2);  % [X-shift, Y-shift] for each frame

% Progress bar
h = waitbar(0, 'Performing motion correction...');

% Correct each frame
for k = 1:nFrames
    % Estimate rigid transformation (translation only)

    % imregcorr in v2022 has very strict thresholds and returns almost no
    % detected motion. In v2025 this function is improved and uses gradient
    % correlation. We implement our version of phase correlation
    % which gives identical results in both versions

    % tform = imregcorr(PDI.PDI(:,:,k), ref, 'translation');

    tform = phase_correlation(PDI.PDI(:,:,k), ref);
    
    % Apply transformation
    cPDI(:,:,k) = imwarp(PDI.PDI(:,:,k), tform, 'OutputView', imref2d(size(ref)));
    
    % Store motion parameters (translation in pixels)
    % Version-agnostic translation extraction.
    % isprop() is unreliable for MATLAB value classes, so we use try/catch:
    %   - New-style objects (transltform2d, rigidtform2d — R2022b+): use .Translation
    %   - Legacy affine2d (R2025a on some datasets): use .T(3,1:2)
    try
        motionParams(k,1) = tform.Translation(1);  % X translation
        motionParams(k,2) = tform.Translation(2);  % Y translation
    catch
        motionParams(k,1) = tform.T(3,1);          % X translation (legacy)
        motionParams(k,2) = tform.T(3,2);          % Y translation (legacy)
    end
    
    % Update waitbar periodically
    if mod(k, 100) == 0 || k == nFrames
        waitbar(k/nFrames, h, sprintf('Correcting frame %d of %d', k, nFrames));
    end
end

close(h);

% Calculate motion statistics
totalMotion = sqrt(motionParams(:,1).^2 + motionParams(:,2).^2);
fprintf('Motion correction complete:\n');
fprintf('  Mean displacement: %.2f pixels\n', mean(totalMotion));
fprintf('  Max displacement: %.2f pixels\n', max(totalMotion));
fprintf('  Std displacement: %.2f pixels\n', std(totalMotion));

% Store motion parameters in PDI structure
PDI.motionParams = motionParams;

% Visualize motion parameters for quality control
visualize_motion_correction(PDI.time, motionParams);

% Update PDI data with motion-corrected version
PDI.PDI = cPDI;

fprintf('=== Motion Correction Complete ===\n\n');

%% Voxelwise outlier rejection and temporal interpolation
% Detects and interpolates extreme outlier values in individual voxel timeseries.
% This removes brief artifacts (electrical spikes, ultrasound glitches) without
% deleting entire frames. Uses voxel-specific z-score thresholding (5-sigma)
% followed by linear interpolation from neighboring timepoints.
%
% Why voxelwise: Different voxels have different outlier patterns
% Why 5-sigma: Conservative threshold - only catches extreme artifacts
% Why temporal interpolation: fUSI signal has temporal autocorrelation

fprintf('=== Performing Outlier Rejection ===\n');

% Set outlier detection threshold to 5 sd from the mean
std_threshold = 5; 

% Calculate z-scores for each voxel across time
% zscore with 0 flag computes population std (divide by N)
% abs() because outliers can be high or low
zG = abs(zscore(PDI.PDI, 0, 3));

% Create mask of outlier voxel-timepoints (|z-score| > 5)
maskG = zG > std_threshold;

% Count outliers before interpolation
numOutliers = sum(maskG(:));
numTotal = numel(PDI.PDI);
outlierRatio = numOutliers / numTotal;

fprintf('Detected %d outliers (%.2f%% of all values)\n', numOutliers, outlierRatio * 100);

% Flag outliers as NaN for interpolation
PDI.PDI(maskG) = NaN;

% Interpolate NaN values using temporal neighbors
% fillmissingTime interpolates each voxel's timeseries independently
PDI.PDI = fillmissingTime(PDI.PDI, 'linear');

% Store outlier rejection parameters
PDI.voxelFrameRjection.std = std_threshold;
PDI.voxelFrameRjection.interpMethod = 'linear';
PDI.voxelFrameRjection.ratio = outlierRatio;

fprintf('Outlier rejection complete (threshold: %d-sigma, method: linear)\n', std_threshold);
fprintf('=== Outlier Rejection Complete ===\n\n');

%% Convert to percent signal change
% Normalizes each voxel's timeseries by its temporal mean, converting raw signal
% intensities to percent change. This removes baseline differences between voxels
% and provides interpretable units (e.g., "5% increase from baseline").
%
% Formula: PSC(t) = (S(t) - mean(S)) / mean(S) × 100
%
% Why percent signal change:
% - Removes baseline blood flow differences between voxels
% - Comparable signal magnitudes across brain regions
% - Standard for GLM analysis (better assumption compliance)
% - Interpretable activation magnitudes

fprintf('=== Converting to Percent Signal Change ===\n');

% Calculate temporal mean for each voxel
nFrames = size(PDI.PDI, 3);
mu = repmat(mean(PDI.PDI, 3), 1, 1, nFrames);

% Apply percent signal change formula
PDI.PDI = (PDI.PDI - mu) ./ mu .* 100;

fprintf('Signal converted to percent change (baseline = 0%%)\n');

% Alternative: Z-score normalization (commented out)
% Used for inter-subject correlation (ISC) analysis where relative timing
% matters more than absolute magnitude
% PDI.PDI = zscore(PDI.PDI, 0, 3);

fprintf('=== Percent Signal Change Complete ===\n\n');

%% Resample data to 5 Hz
% Resamples functional data to consistent 5 Hz temporal resolution using linear
% interpolation. This standardizes sampling rate across sessions and ensures
% regular time intervals for subsequent analysis (GLM requires uniform sampling).
%
% Why 5 Hz: Balance between temporal resolution and data size
% How: Linear interpolation along time dimension

fprintf('=== Resampling to 5 Hz ===\n');

resampling_rate = 5;  % Hz
original_rate = 1 / mean(diff(PDI.time));

fprintf('Original sampling rate: %.2f Hz\n', original_rate);
fprintf('Target sampling rate: %d Hz\n', resampling_rate);

% Resample PDI data and time vector
PDI = resamplePDI(PDI, resampling_rate);

fprintf('Data resampled to %d Hz (%d frames)\n', resampling_rate, size(PDI.PDI, 3));
fprintf('=== Resampling Complete ===\n\n');

%% Temporal highpass filtering
% Removes slow signal drifts using DCT (Discrete Cosine Transform) regression.
% Slow drifts can arise from scanner drift, physiological changes, or other
% non-neural sources. Highpass filtering improves detection of task-related
% or stimulus-evoked responses.
%
% Method: DCT basis functions (as in SPM)
% Cutoff: Remove components with period > cutoff_in_seconds

fprintf('=== Applying Temporal Highpass Filter ===\n');

cutoff_in_seconds = 500;  % Remove drift with period > 500 seconds
sampling_rate = resampling_rate;  % Use resampled rate

fprintf('Filter parameters:\n');
fprintf('  Cutoff period: %d seconds\n', cutoff_in_seconds);
fprintf('  Sampling rate: %d Hz\n', sampling_rate);

% Apply DCT-based highpass filter
PDI.PDI = DCThighpass(PDI.PDI, sampling_rate, cutoff_in_seconds);

fprintf('Temporal highpass filtering complete\n');
fprintf('=== Highpass Filtering Complete ===\n\n');

%% Spatial smoothing 
% Apply Gaussian smoothing to reduce noise and improve spatial signal-to-noise ratio.
% Smoothing with sigma=1 pixel corresponds to FWHM = 2.355 pixels.
%
% Why smoothing:
% - Reduces high-frequency noise
% - Improves signal-to-noise ratio
% - Matches functional signal spread (hemodynamic blur)
% - Standard preprocessing for fMRI/fUSI
%
% The relationship FWHM = 2.355 × σ comes from Gaussian mathematics:
% - FWHM = Full Width at Half Maximum
% - FWHM = 2√(2ln2) × σ ≈ 2.355 × σ

fprintf('=== Applying Spatial Smoothing ===\n');

spatial_sigma = 1;  % Gaussian kernel width (pixels)
[nY, nX, nFrames] = size(PDI.PDI);

fprintf('Smoothing parameters:\n');
fprintf('  Sigma: %.1f pixels\n', spatial_sigma);
fprintf('  FWHM: %.2f pixels\n', 2.355 * spatial_sigma);
fprintf('  Effective smoothing radius: ~%d pixels\n', ceil(3*spatial_sigma));

% Apply Gaussian filter to each frame
for k = 1:nFrames
    PDI.PDI(:,:,k) = imgaussfilt(PDI.PDI(:,:,k), spatial_sigma);
end

% Store smoothing parameter in PDI structure
PDI.spatialSigma = spatial_sigma;

fprintf('Spatial smoothing complete\n');
fprintf('=== Spatial Smoothing Complete ===\n\n');

%% Save preprocessed data
% Save the fully preprocessed PDI data to the functional data directory.
% The output filename is 'prepPDI.mat' to distinguish it from the raw data.
%
% What's included:
% - Preprocessed imaging data (PDI.PDI)
% - Brain mask (PDI.bmask)
% - Motion parameters (PDI.motionParams)
% - Outlier rejection info (PDI.voxelFrameRjection)
% - Smoothing parameters (PDI.spatialSigma)
% - All original metadata (time, Dim, stimInfo, etc.)

fprintf('=== Saving Preprocessed Data ===\n');

% Define output path (same directory as input functional data)
output_filename = 'prepPDI.mat';
output_path = fullfile(PDI.savepath, output_filename);

fprintf('Output location: %s\n', output_path);
fprintf('Saving preprocessed data...\n');

% Save using parsave (parallel-safe save function)
parsave(output_path, PDI);

fprintf('Preprocessed data saved successfully\n');
fprintf('=== Preprocessing Complete ===\n\n');

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║                   PREPROCESSING SUMMARY                        ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');
fprintf('  Output file: %s\n', output_filename);
fprintf('  Final dimensions: [%d × %d × %d]\n', size(PDI.PDI, 1), size(PDI.PDI, 2), size(PDI.PDI, 3));
fprintf('  Sampling rate: 5 Hz\n');
fprintf('  Processing steps completed: 10/10\n');
fprintf('  ✓ Brain masking\n');
fprintf('  ✓ Motion correction\n');
fprintf('  ✓ Outlier rejection\n');
fprintf('  ✓ Signal normalization (PSC)\n');
fprintf('  ✓ Temporal resampling\n');
fprintf('  ✓ Highpass filtering\n');
fprintf('  ✓ Spatial smoothing\n');
fprintf('  ✓ Data saved\n');
fprintf('\n');

end