%% Assess overlap in atlas space of the chosen slice across subjects
%
% For every VisualTest session, transform the binary mask of the selected
% functional slice into Allen Atlas space and accumulate all slices into a
% single count-map volume (voxel value = number of subjects whose slice
% passes through that atlas location).
%
% Output: registration_procedure/all_slices_in_allen.nii.gz
%
% Sessions that are missing anatomic.mat, Transformation.mat, or
% anatomic.funcSlice are silently skipped.

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

outDir = pwd;

%% ---- Get VisualTest anatomical paths ----
[~, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');
% [~, subAnatPath, ~] = fonduta.io.datapath.Datapath('ShockTest');

nSessions = numel(subAnatPath);
fprintf('Found %d VisualTest sessions.\n\n', nSessions);

%% ---- Load atlas once ----
atlas = fonduta.atlas.load_atlas();
atlasSize = size(atlas.Histology);   % [160 264 228]

%% ---- Accumulate slice masks in atlas space ----
allSlices  = zeros(atlasSize, 'single');
nProcessed = 0;
nSkipped   = 0;

for s = 1:nSessions
    anatPath = strtrim(subAnatPath{s});
    anatFile  = fullfile(anatPath, 'anatomic.mat');
    transfFile = fullfile(anatPath, 'Transformation.mat');

    % --- Skip if files missing ---
    if ~isfile(anatFile) || ~isfile(transfFile)
        fprintf('[%2d/%d] SKIP (files missing): %s\n', s, nSessions, anatPath);
        nSkipped = nSkipped + 1;
        continue
    end

    load(anatFile,   'anatomic');
    load(transfFile, 'Transf');

    % --- Skip if funcSlice not defined ---
    if ~isfield(anatomic, 'funcSlice') || isempty(anatomic.funcSlice)
        fprintf('[%2d/%d] SKIP (no funcSlice): %s\n', s, nSessions, anatPath);
        nSkipped = nSkipped + 1;
        continue
    end

    sliceIdx = anatomic.funcSlice(3);

    % --- Build binary mask: ones where brain tissue in the selected slice ---
    slicePlane = anatomic.Data(:, :, sliceIdx);
    if ~any(slicePlane(:))
        fprintf('[%2d/%d] SKIP (empty slice %d): %s\n', s, nSessions, sliceIdx, anatPath);
        nSkipped = nSkipped + 1;
        continue
    end

    maskVol               = zeros(size(anatomic.Data));
    maskVol(:, :, sliceIdx) = double(slicePlane > 0);
    anatomicMask          = anatomic;
    anatomicMask.Data     = maskVol;

    fprintf('[%2d/%d] Processing slice %d: %s\n', s, nSessions, sliceIdx, anatPath);

    % --- Transform binary mask slice to atlas space ---
    try
        sliceInAtlas = fonduta.atlas.individual2atlas(anatomicMask, atlas, Transf);
        allSlices    = allSlices + sliceInAtlas;
        nProcessed   = nProcessed + 1;
    catch ME
        fprintf('         ERROR: %s — skipping.\n', ME.message);
        nSkipped = nSkipped + 1;
    end
end

fprintf('\n--- Done: %d processed, %d skipped ---\n', nProcessed, nSkipped);

%% ---- Save accumulation map as NIfTI ----
outFile   = fullfile(outDir, 'all_slices_in_allen.nii.gz');
atlas_nii = fullfile(FONDUTA_PATH, '+fonduta', '+atlas', 'atlas.nii.gz');

if ~isfile(atlas_nii)
    error('atlas.nii.gz not found at: %s', atlas_nii);
end

hdr     = load_nifti(atlas_nii);
hdr.vol = allSlices;
save_nifti(hdr, outFile);

fprintf('Saved: %s\n', outFile);
fprintf('Max overlap: %d sessions\n', max(allSlices(:)));
