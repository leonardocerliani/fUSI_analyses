function warpedAnatomic = s03_Transform_Individual_2_Atlas(anatomic_dir, dispFieldI2A)
% Individual_2_Atlas warps individual anatomy to atlas space and saves the result.
%
% USAGE:
%   warpedAnatomic = Individual_2_Atlas(anatomic_dir);
%   warpedAnatomic = Individual_2_Atlas(anatomic_dir, dispFieldI2A);
%
% INPUTS:
%   anatomic_dir   - Directory containing:
%                      - 'anatomic.mat' (struct with individual anatomy)
%                      - 'Transformation.mat' (affine transformation)
%   dispFieldI2A   - (optional) nonlinear deformation field to apply after affine
%
% OUTPUTS:
%   warpedAnatomic - Struct with anatomical data transformed to atlas space
%
% NOTES:
%   - Saves files in the same folder as 'anatomic.mat':
%       1. anatomic_2_atlas.mat  - MATLAB struct with transformed anatomy
%       2. anatomic_2_atlas.nii  - NIfTI file with transformed anatomy
%       3. slice_2_atlas.nii - NIfTI file with selected slice transformed (if funcSlice exists)
%       4. slice_2_atlas_mask.nii - Binary mask of selected slice in atlas space (if funcSlice exists)
%   - Opens a 16-slice visualization of the warped anatomy overlaid on the atlas.
%
% EXAMPLE:
%   % Using affine transformation only:
%   warpedAnatomic = Individual_2_Atlas('./DATA_ANALYSIS/Subject01');
%
%   % Using affine + nonlinear deformation:
%   warpedAnatomic = Individual_2_Atlas('./DATA_ANALYSIS/Subject01', dispFieldI2A);
%
% DEPENDENCIES:
%   - ./Registration/allen_brain_atlas.mat
%   - ./Registration/BrunnerCodes/interpolate3D.m
%   - ./Registration/freesurfer_matlab/load_nifti.m
%   - ./Registration/freesurfer_matlab/save_nifti.m
%
% SEE ALSO:
%   interpolate3D, load_nifti, save_nifti



% -------------------------
% Handle nargin == 0 (show help + open UI)
% -------------------------
if nargin == 0
    fprintf('\nUsage:\n');
    fprintf('  warpedAnatomic = Individual2Atlas(anatomic_dir);\n');
    fprintf('  warpedAnatomic = Individual2Atlas(anatomic_dir, dispFieldI2A);\n\n');
    fprintf('Select the DATA_ANALYSIS directory with anatomic.mat and Transformation.mat.\n\n');
    anatomic_dir = uigetdir(pwd, 'Select the DATA_ANALYSIS directory with anatomic.mat and Transformation.mat');
    if anatomic_dir == 0
        error("No directory selected. Aborting.");
    end
    dispFieldI2A = [];
end


% -------------------------
% Load atlas
% -------------------------
try
    load("allen_brain_atlas.mat", "atlas");
catch
    error("Ensure that the allen_brain_atlas.mat is in the path");
end


% -------------------------
% Load required files
% -------------------------
anatomic_file = fullfile(anatomic_dir, "anatomic.mat");
transf_file   = fullfile(anatomic_dir, "Transformation.mat");

if ~isfile(anatomic_file)
    error("anatomic.mat not found");
else
    load(anatomic_file, "anatomic");
end

if ~isfile(transf_file)
    error("no Transformation.mat found");
else
    load(transf_file, "Transf");
end

if nargin < 2
    dispFieldI2A = [];
end


% ------------------------------
% Prepare the anatomical data
% ------------------------------
c = anatomic;
c.Data = anatomic.Data;


% ------------------------------
% Transform to atlas space
% ------------------------------
anatomicInterp = interpolate3D(atlas, c);
T = affine3d(Transf.M);
ref = imref3d(size(atlas.Histology));
anatomicAffineTransformed = imwarp(anatomicInterp.Data, T, 'nearest', 'OutputView', ref);

if ~isempty(dispFieldI2A)
    warpedAnatomic = imwarp(anatomicAffineTransformed, dispFieldI2A, 'nearest');
else
    warpedAnatomic = anatomicAffineTransformed;
end



% ------------------------------
% Save the transformed anatomy
% ------------------------------
anatomic_2_atlas = struct();
anatomic_2_atlas.VoxelSize = atlas.VoxelSize;
anatomic_2_atlas.Direction = atlas.Direction;
anatomic_2_atlas.Data = warpedAnatomic;
anatomic_2_atlas.Regions = atlas.Regions;
anatomic_2_atlas.InfoRegions = atlas.infoRegions;
anatomic_2_atlas.Lines = atlas.Lines;

save(fullfile(anatomic_dir, 'anatomic_2_atlas.mat'), 'anatomic_2_atlas');



% -----------------------------------------------
% Save the transformed anatomic_2_atlas.nii NIFTI
% -----------------------------------------------

% Check that atlas.nii exists
atlas_nii_path = which('atlas.nii.gz');

if isempty(atlas_nii_path)
    error('atlas.nii not found. Ensure it is on the MATLAB path.');
else
    % Load the source header from atlas.nii
    hdr = load_nifti(atlas_nii_path);
    
    % Replace the volume with transformed data
    hdr.vol = anatomic_2_atlas.Data;
    
    % Save as NIFTI in the same folder as anatomic.mat
    save_nifti(hdr, fullfile(anatomic_dir, 'anatomic_2_atlas.nii'));
end


% -----------------------------------------------
% Transform selected functional slice if it exists
% -----------------------------------------------
if isfield(anatomic, 'funcSlice')
    fprintf('\n→ Found funcSlice: [%d, %d, %d]\n', anatomic.funcSlice(1), anatomic.funcSlice(2), anatomic.funcSlice(3));
    
    % Extract the selected slice from the individual anatomy
    slice_individual = zeros(size(anatomic.Data));
    slice_individual(:, :, anatomic.funcSlice(3)) = anatomic.Data(:, :, anatomic.funcSlice(3));
    
    % Prepare slice structure for interpolation
    slice_struct = anatomic;
    slice_struct.Data = slice_individual;
    
    % Transform slice to atlas space
    fprintf('→ Transforming selected slice to atlas space...\n');
    sliceInterp = interpolate3D(atlas, slice_struct);
    sliceAffineTransformed = imwarp(sliceInterp.Data, T, 'nearest', 'OutputView', ref);
    
    if ~isempty(dispFieldI2A)
        slice_2_atlas = imwarp(sliceAffineTransformed, dispFieldI2A, 'nearest');
    else
        slice_2_atlas = sliceAffineTransformed;
    end
    
    % Save slice_2_atlas.nii
    hdr_slice = load_nifti(atlas_nii_path);
    hdr_slice.vol = slice_2_atlas;
    save_nifti(hdr_slice, fullfile(anatomic_dir, 'slice_2_atlas.nii'));
    fprintf('✓ Saved: slice_2_atlas.nii\n');
    
    
    % -----------------------------------------------
    % Create and transform binary mask of selected slice
    % -----------------------------------------------
    fprintf('→ Creating binary mask of selected slice...\n');
    
    % Create binary mask in individual space
    mask_individual = zeros(size(anatomic.Data));
    mask_individual(:, :, anatomic.funcSlice(3)) = 1;
    
    % Prepare mask structure for interpolation
    mask_struct = anatomic;
    mask_struct.Data = mask_individual;
    
    % Transform mask to atlas space
    maskInterp = interpolate3D(atlas, mask_struct);
    maskAffineTransformed = imwarp(maskInterp.Data, T, 'nearest', 'OutputView', ref);
    
    if ~isempty(dispFieldI2A)
        slice_2_atlas_mask = imwarp(maskAffineTransformed, dispFieldI2A, 'nearest');
    else
        slice_2_atlas_mask = maskAffineTransformed;
    end
    
    % Save slice_2_atlas_mask.nii
    hdr_mask = load_nifti(atlas_nii_path);
    hdr_mask.vol = slice_2_atlas_mask;
    save_nifti(hdr_mask, fullfile(anatomic_dir, 'slice_2_atlas_mask.nii'));
    fprintf('✓ Saved: slice_2_atlas_mask.nii\n\n');
    
else
    fprintf('\n→ No funcSlice found. Skipping slice transformation.\n');
    fprintf('  (Run s02_Select_Anatomical_Slice to define a functional slice)\n\n');
end



% ------------------------------
% Visualize 16 slices
% ------------------------------

% Coronal
figure('Color', 'w');
numSlices = 16;
step = round(size(warpedAnatomic,2) / numSlices);

for i = 1:numSlices
    sliceIdx = (i-1)*step + 1;
    subplot(4,4,i);

    % Coronal histology slice
    histSlice = squeeze(atlas.Histology(:, sliceIdx, :));
    imshow(histSlice, [], 'InitialMagnification', 'fit');
    hold on;

    % Coronal anatomy slice
    anatSlice = squeeze(warpedAnatomic(:, sliceIdx, :));

    if any(anatSlice(:))
        anat_norm = mat2gray(anatSlice);
        anat_rgb = ind2rgb(im2uint8(anat_norm), hot(256));
        alphaData = 0.5 * (anatSlice > 0);
        h = imshow(anat_rgb);
        set(h, 'AlphaData', alphaData);
    end

    title(['Coronal slice ' num2str(sliceIdx)]);
    axis image off;
end


% % Sagittal
% % ------------------------------
% % Visualize 16 slices
% % ------------------------------
% figure('Color', 'w');
% numSlices = 16;
% step = round(size(warpedAnatomic,3)/numSlices);
% 
% for i = 1:numSlices
%     sliceIdx = (i-1)*step + 1;
%     subplot(4,4,i);
% 
%     % Show atlas histology in grayscale
%     histSlice = squeeze(atlas.Histology(:,:,sliceIdx));
%     imshow(histSlice, [], 'InitialMagnification', 'fit');
%     hold on;
% 
%     % Overlay transformed anatomy
%     anatSlice = warpedAnatomic(:,:,sliceIdx);
%     if any(anatSlice(:))
%         anat_norm = mat2gray(anatSlice);
%         anat_rgb = ind2rgb(im2uint8(anat_norm), hot(256));
%         alphaData = 0.5 * (anatSlice > 0);
%         h = imshow(anat_rgb);
%         set(h, 'AlphaData', alphaData);
%     end
% 
%     title(['Slice ' num2str(sliceIdx)]);
%     axis image off;
% end
% 
% sgtitle('Warped Anatomy Overlaid on Atlas Histology');


% end of function
end
