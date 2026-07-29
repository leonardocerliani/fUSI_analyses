function atlas = load_atlas()
% fonduta.atlas.load_atlas  Load the Allen Brain Atlas from the FONDUTA package.
%
% Locates and loads allen_brain_atlas.mat relative to this file's location,
% so it works regardless of where the FONDUTA directory is installed on disk.
%
% Usage:
%   atlas = fonduta.atlas.load_atlas();
%
% Output:
%   atlas - struct with fields: .Regions, .Histology, .Vascular,
%           .VoxelSize, .Direction, and others (see atlas .mat file)
%
% See also: fonduta.atlas.build_brain_masks,
%           fonduta.atlas.atlas2individual

    thisDir   = fileparts(mfilename('fullpath'));
    atlasFile = fullfile(thisDir, 'allen_brain_atlas.mat');

    if ~isfile(atlasFile)
        error('fonduta:atlas:load_atlas:FileNotFound', ...
              'Allen Brain Atlas not found at:\n  %s', atlasFile);
    end

    tmp   = load(atlasFile);
    field = fieldnames(tmp);
    atlas = tmp.(field{1});

end
