function subAtlas = atlas2individual(atlas, anatomic, Transf, varargin)
% fonduta.atlas.atlas2individual  Map Allen Brain Atlas into subject (individual) space.
%
% Applies affine registration to warp the atlas Regions, Histology, and
% Vascular volumes into subject space.
%
% USAGE
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf)
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, 'mode', 'slice')
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, 'save_nifti', true)
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, 'save_nifti', true, 'nifti_path', '/out/dir')
%
% INPUTS
%   atlas    - struct with fields: .Regions, .Histology, .Vascular
%   anatomic - struct containing the anatomical scan (from load_session)
%   Transf   - struct with field .M (4x4 affine matrix, from Transformation.mat)
%
% NAME-VALUE OPTIONS
%   'mode'        - 'volume' (default) | 'slice'
%                    'volume' : warp all atlas volumes to subject space [nx x ny x nz]
%                    'slice'  : warp all volumes then extract slice at anatomic.funcSlice(3)
%                               returning 2D fields [nx x ny] in each subAtlas field.
%                               Requires anatomic.funcSlice to be defined.
%   'save_nifti'  - false (default) | true
%                   Save each warped volume as a compressed NIfTI file.
%   'nifti_path'  - output directory (default: pwd)
%                   Output filenames are hardcoded from mode:
%                     volume -> vol_atlas_2_anatomic_Region.nii.gz
%                               vol_atlas_2_anatomic_Histology.nii.gz
%                               vol_atlas_2_anatomic_Vascular.nii.gz
%                     slice  -> slice_atlas_2_anatomic_Region.nii.gz
%                               slice_atlas_2_anatomic_Histology.nii.gz
%                               slice_atlas_2_anatomic_Vascular.nii.gz
%
% OUTPUT
%   subAtlas - struct with fields (each a sub-struct with .Data, .VoxelSize, .Direction):
%       .Region    - atlas regions warped to subject space
%       .Histology - atlas histology warped to subject space
%       .Vascular  - atlas vascular map warped to subject space
%
% EXAMPLES
%   % Standard use (backward compatible)
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf);
%   funcSlice = anatomic.funcSlice(3);
%   regionSlice = subAtlas.Region.Data(:,:,funcSlice);
%
%   % Slice mode: returns 2D slices directly
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, 'mode', 'slice');
%   regionSlice = subAtlas.Region.Data;   % already 2D
%
%   % Save NIfTI to current directory
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, 'save_nifti', true);
%
%   % Save NIfTI to specific directory
%   subAtlas = fonduta.atlas.atlas2individual(atlas, anatomic, Transf, ...
%       'save_nifti', true, 'nifti_path', '/data/out');
%
% SEE ALSO
%   fonduta.atlas.individual2atlas, fonduta.atlas.load_atlas,
%   fonduta.atlas.build_slice_masks

%% ---- Parse name-value options ----
p = inputParser;
addRequired(p,  'atlas');
addRequired(p,  'anatomic');
addRequired(p,  'Transf');
addParameter(p, 'mode',       'volume', @(x) ismember(x, {'volume','slice'}));
addParameter(p, 'save_nifti', false,    @islogical);
addParameter(p, 'nifti_path', '',       @ischar);
parse(p, atlas, anatomic, Transf, varargin{:});

mode        = p.Results.mode;
write_nifti = p.Results.save_nifti;    % renamed to avoid shadowing save_nifti()
nifti_path  = p.Results.nifti_path;

if strcmp(mode, 'slice')
    if ~isfield(anatomic, 'funcSlice') || isempty(anatomic.funcSlice)
        error('fonduta:atlas:atlas2individual:MissingField', ...
              'anatomic.funcSlice is required for mode = ''slice''.');
    end
    funcSlice = anatomic.funcSlice(3);
end

% Default output directory: current working directory
if write_nifti && isempty(nifti_path)
    nifti_path = pwd;
end

% Hardcoded output filenames based on mode
switch mode
    case 'volume'; prefix = 'vol_atlas_2_anatomic';
    case 'slice';  prefix = 'slice_atlas_2_anatomic';
end

%% ---- Transform: interpolate atlas -> anatomic voxel grid, then apply inverse affine ----
% (transformation code identical to atlas2individual_OLE.m)
anatomicInterp = interpolate3D(atlas, anatomic);
T   = affine3d(Transf.M);
ref = imref3d(size(anatomicInterp.Data));

atlasRegionAffine    = imwarp(atlas.Regions,   T.invert, 'nearest', 'OutputView', ref);
atlasHistologyAffine = imwarp(atlas.Histology, T.invert, 'nearest', 'OutputView', ref);
atlasVascularAffine  = imwarp(atlas.Vascular,  T.invert, 'nearest', 'OutputView', ref);

anatomicInterp.Data = atlasRegionAffine;
subAtlas.Region     = interpolate3D(anatomic, anatomicInterp, 'nearest');
anatomicInterp.Data = atlasHistologyAffine;
subAtlas.Histology  = interpolate3D(anatomic, anatomicInterp, 'nearest');
anatomicInterp.Data = atlasVascularAffine;
subAtlas.Vascular   = interpolate3D(anatomic, anatomicInterp, 'nearest');

fprintf('[atlas2individual] mode   : %s\n', mode);
fprintf('[atlas2individual] output : subject space  [%d x %d x %d]\n', size(subAtlas.Region.Data));

%% ---- Slice mode: extract funcSlice from each field ----
if strcmp(mode, 'slice')
    fprintf('[atlas2individual] extracting slice %d\n', funcSlice);
    subAtlas.Region.Data    = subAtlas.Region.Data(:,:,funcSlice);
    subAtlas.Histology.Data = subAtlas.Histology.Data(:,:,funcSlice);
    subAtlas.Vascular.Data  = subAtlas.Vascular.Data(:,:,funcSlice);
end

%% ---- Optional NIfTI save ----
if write_nifti
    thisDir   = fileparts(mfilename('fullpath'));
    atlas_nii = fullfile(thisDir, 'atlas.nii.gz');

    if ~isfile(atlas_nii)
        error('fonduta:atlas:atlas2individual:FileNotFound', ...
              'atlas.nii.gz not found at: %s', atlas_nii);
    end

    hdr = load_nifti(atlas_nii);

    out_file = fullfile(nifti_path, [prefix '_Region.nii.gz']);
    hdr.vol  = subAtlas.Region.Data;
    save_nifti(hdr, out_file);
    fprintf('[atlas2individual] saved  : %s\n', out_file);

    out_file = fullfile(nifti_path, [prefix '_Histology.nii.gz']);
    hdr.vol  = subAtlas.Histology.Data;
    save_nifti(hdr, out_file);
    fprintf('[atlas2individual] saved  : %s\n', out_file);

    out_file = fullfile(nifti_path, [prefix '_Vascular.nii.gz']);
    hdr.vol  = subAtlas.Vascular.Data;
    save_nifti(hdr, out_file);
    fprintf('[atlas2individual] saved  : %s\n', out_file);
end

end
