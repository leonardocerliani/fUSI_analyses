%% Transformation examples: individual <-> atlas space
%
% Demonstrates fonduta.atlas.individual2atlas and fonduta.atlas.atlas2individual.

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

% Load the allen atlas
atlas = fonduta.atlas.load_atlas();

% Define output dir for the (optional) nifti files
outDir = '/data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL/examples';

% Load the anatomical paths for VisualTest
[~, allAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');

% Select one specific subject
anatPath = allAnatPath{1};

% Load anatomic.mat and Transformation.mat
load(fullfile(anatPath, 'anatomic.mat'),       'anatomic');
load(fullfile(anatPath, 'Transformation.mat'), 'Transf');


%% ---- individual -> atlas space ----
%
% 'mode' = 'volume' (default): warp anatomic volume -> atlas, retain full volume
% 'mode' = 'slice'           : warp anatomic volume -> atlas, retain only selected slice
%
% 'save_nifti' = true (default: false): save output as NIfTI
% 'nifti_path': full path to output file (default: pwd/anatomic_in_atlas.nii.gz)

output_anatomic2atlas = fonduta.atlas.individual2atlas( ...
    anatomic, atlas, Transf, ...
    'mode',       'volume', ...
    'save_nifti', true, ...
    'nifti_path', outDir ...
    );

figure
atlas_slice = 150;
ax1 = axes;
imagesc(ax1, squeeze(atlas.Histology(:,atlas_slice,:)))
axis(ax1,'image'); colormap(ax1, gray); hold(ax1,'on')

ax2 = axes('Position', ax1.Position, 'Color','none');
h = imagesc(ax2, squeeze(output_anatomic2atlas(:,atlas_slice,:)));
axis(ax2,'image'); colormap(ax2, hot); h.AlphaData = 0.9;

linkaxes([ax1 ax2])
ax2.Visible = 'off';
title(ax1, sprintf('Anatomic in atlas space (coronal slice %d)', atlas_slice));


%% ---- atlas -> individual space ----
%
% 'mode' = 'volume' (default): warp atlas volume -> anatomic, retain full volume
% 'mode' = 'slice'           : warp atlas volume -> anatomic, retain only selected slice
%
% 'save_nifti' = true (default: false): save Region, Histology and Vascular as NIfTI
% 'nifti_path': base path (no extension). Saves <base>_Region.nii.gz, <base>_Histology.nii.gz, <base>_Vascular.nii.gz

output_atlas2anatomic = fonduta.atlas.atlas2individual( ...
    atlas, anatomic, Transf, ...
    'mode',       'volume', ...
    'save_nifti', true, ...
    'nifti_path', outDir ...
    );

% Show the functional slice: anatomic (gray) + vascular overlay (hot)
funcSlice = anatomic.funcSlice(3);

figure
ax3 = axes;
imagesc(ax3, squeeze(anatomic.Data(:,:,funcSlice)))
axis(ax3, 'image'); colormap(ax3, gray); hold(ax3, 'on')

ax4 = axes('Position', ax3.Position, 'Color', 'none');


if ndims(output_atlas2anatomic.Vascular.Data) == 3
    h2 = imagesc(ax4, squeeze(output_atlas2anatomic.Vascular.Data(:,:,funcSlice)));
else
    h2 = imagesc(ax4, squeeze(output_atlas2anatomic.Vascular.Data));
end

axis(ax4, 'image'); colormap(ax4, hot); h2.AlphaData = 0.6;

linkaxes([ax3 ax4])
ax4.Visible = 'off';
title(ax3, sprintf('Anatomic + Atlas Vascular overlay (slice %d)', funcSlice));

%%

nii = niftiread("vol_anatomic_2_atlas.nii.gz");

sliceViewer(nii, 'Colormap','hot');

orthosliceViewer(nii)

