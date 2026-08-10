function result = individual2atlas(anatomic, atlas, Transf, varargin)
% fonduta.atlas.individual2atlas  Warp subject-space data into Allen Atlas space.
%
% Transforms the anatomical volume (or a single functional slice) from
% individual subject space into the Allen Brain Atlas space [160x264x228].
%
% USAGE
%   result = fonduta.atlas.individual2atlas(anatomic, atlas, Transf)
%   result = fonduta.atlas.individual2atlas(anatomic, atlas, Transf, 'mode', 'slice')
%   result = fonduta.atlas.individual2atlas(anatomic, atlas, Transf, 'save_nifti', true)
%   result = fonduta.atlas.individual2atlas(anatomic, atlas, Transf, 'save_nifti', true, 'nifti_path', '/out/dir')
%
% INPUTS
%   anatomic   - struct with fields:
%                  .Data      [nx x ny x nz] anatomical volume
%                  .VoxelSize [1x3] voxel size in mm
%                  .Direction axis orientation codes
%                  .funcSlice [1x3] (required for mode='slice')
%   atlas      - struct loaded by fonduta.atlas.load_atlas()
%   Transf     - struct with field .M (4x4 affine, subject -> atlas)
%
% NAME-VALUE OPTIONS
%   'mode'        - 'volume' (default) | 'slice'
%                    'volume' : warp the full 3D anatomic.Data -> atlas space
%                    'slice'  : warp only the plane at anatomic.funcSlice(3)
%   'save_nifti'  - false (default) | true
%                   Saves the result as a compressed NIfTI file.
%   'nifti_path'  - output directory (default: pwd)
%                   Output filename is hardcoded from mode:
%                     volume -> vol_anatomic_2_atlas.nii.gz
%                     slice  -> slice_anatomic_2_atlas.nii.gz
%
% OUTPUT
%   result  - 3D array [160x264x228] in atlas space (single precision)
%
% EXAMPLES
%   % Warp full volume (no NIfTI)
%   vol = fonduta.atlas.individual2atlas(anatomic, atlas, Transf);
%
%   % Warp functional slice, save NIfTI to current directory
%   slc = fonduta.atlas.individual2atlas(anatomic, atlas, Transf, ...
%       'mode', 'slice', 'save_nifti', true);
%
%   % Warp full volume, save NIfTI to specific directory
%   vol = fonduta.atlas.individual2atlas(anatomic, atlas, Transf, ...
%       'save_nifti', true, 'nifti_path', '/data/out');
%
% SEE ALSO
%   fonduta.atlas.atlas2individual, fonduta.atlas.load_atlas,
%   fonduta.atlas.build_slice_masks

%% ---- Parse inputs ----
p = inputParser;
addRequired(p,  'anatomic');
addRequired(p,  'atlas');
addRequired(p,  'Transf');
addParameter(p, 'mode',       'volume', @(x) ismember(x, {'volume','slice'}));
addParameter(p, 'save_nifti', false,    @islogical);
addParameter(p, 'nifti_path', '',       @ischar);
parse(p, anatomic, atlas, Transf, varargin{:});

mode        = p.Results.mode;
write_nifti = p.Results.save_nifti;   % renamed to avoid shadowing save_nifti()
nifti_path  = p.Results.nifti_path;

% Default output directory: current working directory
if write_nifti && isempty(nifti_path)
    nifti_path = pwd;
end

% Hardcoded output filename based on mode
switch mode
    case 'volume'; nifti_fname = 'vol_anatomic_2_atlas.nii.gz';
    case 'slice';  nifti_fname = 'slice_anatomic_2_atlas.nii.gz';
end

%% ---- Prepare input data ----
switch mode
    case 'volume'
        fprintf('[individual2atlas] mode   : volume\n');
        fprintf('[individual2atlas] source : anatomic.Data  [%d x %d x %d]\n', size(anatomic.Data));
        dataStruct = anatomic;

    case 'slice'
        if ~isfield(anatomic, 'funcSlice')
            error('fonduta:atlas:individual2atlas:MissingField', ...
                  'anatomic.funcSlice is required for mode = ''slice''.');
        end
        sliceIdx = anatomic.funcSlice(3);
        fprintf('[individual2atlas] mode   : slice\n');
        fprintf('[individual2atlas] source : anatomic.funcSlice(3) = %d\n', sliceIdx);

        % Embed the functional slice in a zero volume (preserve struct metadata)
        sliceData               = zeros(size(anatomic.Data));
        sliceData(:,:,sliceIdx) = anatomic.Data(:,:,sliceIdx);
        dataStruct              = anatomic;
        dataStruct.Data         = sliceData;
end

%% ---- Transform: individual --> atlas ----
% Step 1: resample to atlas voxel size & axis convention
dataInterp = interpolate3D(atlas, dataStruct);

% Step 2: apply forward affine, output onto atlas grid [160x264x228]
T      = affine3d(Transf.M);
ref    = imref3d(size(atlas.Histology));
result = single(imwarp(dataInterp.Data, T, 'nearest', 'OutputView', ref));

fprintf('[individual2atlas] output : atlas space  [%d x %d x %d]\n', size(result));

%% ---- Optional NIfTI save ----
if write_nifti
    thisDir   = fileparts(mfilename('fullpath'));
    atlas_nii = fullfile(thisDir, 'atlas.nii.gz');

    if ~isfile(atlas_nii)
        error('fonduta:atlas:individual2atlas:FileNotFound', ...
              'atlas.nii.gz not found at: %s', atlas_nii);
    end

    out_file = fullfile(nifti_path, nifti_fname);
    hdr      = load_nifti(atlas_nii);
    hdr.vol  = result;
    save_nifti(hdr, out_file);
    fprintf('[individual2atlas] saved  : %s\n', out_file);
end

end
