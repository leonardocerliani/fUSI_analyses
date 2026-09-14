% allen_mat_2_niigz.m
%
% Export the Allen Brain Atlas .mat struct to NIfTI (.nii.gz) volumes and a
% JSON label file, suitable for use in ITK-SNAP, FSLeyes, or other viewers.
%
% OUTPUT FILES (written to the same folder as this script):
%   atlas_histology.nii.gz    — Histology volume  (uint8)
%   atlas_regions.nii.gz      — Parcellation map  (int16, values 1-509)
%   atlas_vascular.nii.gz     — Vascular map       (single)
%   atlas_regions_labels.json — Region lookup table (key = voxel value in Regions)
%
% VOXEL SIZE:
%   atlas.VoxelSize is in microns [50 50 50].
%   Converted to mm → PixelDimensions = [0.05 0.05 0.05].
%
% REGION INDEX CONVENTION:
%   Voxel value N in atlas_regions.nii.gz → JSON key "N"
%   i.e. value 1 = root / background, value 2 = MA3, ..., value 509 = last region.
%   There is no value 0 in the Regions volume.

clear; clc;

%% ── 0. Paths ─────────────────────────────────────────────────────────────────
script_dir  = fileparts(mfilename('fullpath'));
fonduta_dir = '/data00/leonardo/github/fUSI_analyses/FONDUTA';

if ~exist(fonduta_dir, 'dir')
    error('FONDUTA directory not found: %s', fonduta_dir);
end
addpath(genpath(fonduta_dir));

%% ── 1. Load atlas ────────────────────────────────────────────────────────────
fprintf('Loading atlas...\n');
atlas = fonduta.atlas.load_atlas();

vox_um = atlas.VoxelSize;          % [50 50 50] microns
vox_mm = vox_um / 1000;            % [0.05 0.05 0.05] mm
fprintf('  VoxelSize: [%s] µm  →  [%s] mm\n', num2str(vox_um), num2str(vox_mm));
fprintf('  Histology : %s  %s\n', mat2str(size(atlas.Histology)), class(atlas.Histology));
fprintf('  Regions   : %s  %s  (min=%d  max=%d)\n', mat2str(size(atlas.Regions)), ...
    class(atlas.Regions), min(atlas.Regions(:)), max(atlas.Regions(:)));
fprintf('  Vascular  : %s  %s\n', mat2str(size(atlas.Vascular)), class(atlas.Vascular));

%% ── 2. Build shared NIfTI header template ────────────────────────────────────
% We match the sform affine used in the existing FONDUTA .nii.gz files:
%   [ 0  0 -1  0 ]
%   [ 0 -1  0  0 ]
%   [ 1  0  0  0 ]
%   [ 0  0  0  1 ]
% PixelDimensions encodes the real voxel size (in mm).

% Read the existing histology header as a starting template
ref_file = fullfile(fonduta_dir, '+fonduta', '+atlas', 'atlas.nii.gz');
if ~exist(ref_file, 'file')
    error('Reference NIfTI not found: %s', ref_file);
end
hdr_template        = niftiinfo(ref_file);
hdr_template.PixelDimensions = vox_mm;           % real voxel size in mm
hdr_template.Description     = 'Allen Brain Atlas exported by allen_mat_2_niigz.m';

%% ── 3. Write Histology (uint8) ───────────────────────────────────────────────
% NOTE: niftiwrite(..., 'Compressed', true) appends .gz automatically.
%       Pass the .nii path; the output file will be .nii.gz.
out_hist     = fullfile(script_dir, 'atlas_histology.nii.gz');   % displayed name
out_hist_nii = fullfile(script_dir, 'atlas_histology.nii');      % passed to niftiwrite

hdr_hist          = hdr_template;
hdr_hist.Datatype = 'uint8';
hdr_hist.BitsPerPixel = 8;
hdr_hist.ImageSize    = size(atlas.Histology);

fprintf('Writing %s ...\n', out_hist);
niftiwrite(atlas.Histology, out_hist_nii, hdr_hist, 'Compressed', true);

%% ── 4. Write Regions (int16) ─────────────────────────────────────────────────
out_reg     = fullfile(script_dir, 'atlas_regions.nii.gz');
out_reg_nii = fullfile(script_dir, 'atlas_regions.nii');

hdr_reg          = hdr_template;
hdr_reg.Datatype = 'int16';
hdr_reg.BitsPerPixel = 16;
hdr_reg.ImageSize    = size(atlas.Regions);

fprintf('Writing %s ...\n', out_reg);
niftiwrite(atlas.Regions, out_reg_nii, hdr_reg, 'Compressed', true);

%% ── 5. Write Vascular (single) ───────────────────────────────────────────────
out_vasc     = fullfile(script_dir, 'atlas_vascular.nii.gz');
out_vasc_nii = fullfile(script_dir, 'atlas_vascular.nii');

hdr_vasc          = hdr_template;
hdr_vasc.Datatype = 'single';
hdr_vasc.BitsPerPixel = 32;
hdr_vasc.ImageSize    = size(atlas.Vascular);

fprintf('Writing %s ...\n', out_vasc);
niftiwrite(atlas.Vascular, out_vasc_nii, hdr_vasc, 'Compressed', true);

%% ── 6. Write JSON label file ─────────────────────────────────────────────────
% Key = voxel value in atlas_regions.nii.gz (1-based, matching atlas.Regions).
% "1" → root / background, "2" → MA3, ..., "509" → last region.

out_json = fullfile(script_dir, 'atlas_regions_labels.json');
n_regions = numel(atlas.infoRegions.acr);

fprintf('Writing %s  (%d regions)...\n', out_json, n_regions);

fid = fopen(out_json, 'w');
if fid == -1
    error('Cannot open %s for writing.', out_json);
end

fprintf(fid, '{\n');
for i = 1:n_regions
    acr  = atlas.infoRegions.acr{i};
    name = atlas.infoRegions.name{i};

    % Escape any double-quotes inside name/acr strings (JSON safety)
    name = strrep(name, '"', '\"');
    acr  = strrep(acr,  '"', '\"');

    if i < n_regions
        fprintf(fid, '  "%d": {"name": "%s", "acronym": "%s"},\n', i, name, acr);
    else
        fprintf(fid, '  "%d": {"name": "%s", "acronym": "%s"}\n',  i, name, acr);
    end
end
fprintf(fid, '}\n');
fclose(fid);

%% ── 7. Verify outputs ────────────────────────────────────────────────────────
fprintf('\n── Verification ──────────────────────────────────────────────────\n');
files = {out_hist, out_reg, out_vasc, out_json};
for f = 1:numel(files)
    d = dir(files{f});
    if ~isempty(d)
        fprintf('  %-40s  %.1f KB\n', d.name, d.bytes/1024);
    else
        fprintf('  %-40s  *** NOT FOUND ***\n', files{f});
    end
end

% Spot-check: re-read region header and confirm pixel dims
info_check = niftiinfo(out_reg);
fprintf('\nRegions header check:\n');
fprintf('  Datatype       : %s\n',   info_check.Datatype);
fprintf('  ImageSize      : [%s]\n', num2str(info_check.ImageSize));
fprintf('  PixelDimensions: [%s] mm\n', num2str(info_check.PixelDimensions));
fprintf('  SpaceUnits     : %s\n',   info_check.SpaceUnits);

fprintf('\nDone.\n');
