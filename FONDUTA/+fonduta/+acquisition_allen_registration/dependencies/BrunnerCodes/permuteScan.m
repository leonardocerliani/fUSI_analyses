% permuteScan
% Reorders and flips the axes of a 3D/4D scan to match the orientation of a reference atlas.
%
% Inputs:
%   data  - Structure containing the scan data:
%           .Data      - 3D or 4D matrix
%           .VoxelSize - voxel spacing along each axis
%           .Direction - string codes for axis orientation (e.g., 'AP', 'ML', 'DV')
%   atlas - Structure containing the reference atlas, must include .Direction
%
% Outputs:
%   dataperm - Structure with:
%           .Data      - permuted (and possibly flipped) scan data
%           .VoxelSize - voxel sizes reordered according to new axes
%           .Direction - axes order now matches the atlas

function dataperm = permuteScan(data, atlas)

% Extract axis labels for scan and atlas
o = [data.Direction(1:3:end)' data.Direction(2:3:end)'];   % scan axes
f = [atlas.Direction(1:3:end)' atlas.Direction(2:3:end)']; % atlas axes

ndim = size(o,1);  % number of axes (3 or 4)

% Initialize arrays to track permutation and flipping
axfind = zeros(ndim,1);   % flag if axis is found
Perm   = zeros(ndim,1);   % stores permutation order
Flip   = zeros(ndim,1);   % stores which axes need to be flipped

% Determine permutation and flips
for i = 1:ndim
    for j = 1:3
        if strcmp(o(i,:), f(j,:))           % axis matches atlas
            Perm(j) = i;
            axfind(j) = 1;
        elseif strcmp(flip(o(i,:)), f(j,:)) % axis matches atlas when flipped
            Perm(j) = i;
            Flip(i) = 1;
            axfind(j) = 1;
        end
    end
end

% Handle time axis if present (4th dimension)
if ndim == 4
    for i = 1:ndim
        if strcmp(o(i,:), 'TM')
            Perm(ndim) = i;
            axfind(4) = 1;
        end
    end
end

% Check that all axes were found
if prod(axfind) == 0
    fprintf(' origin axis: %s\n destin axis: %s\n', axorig, axfinal);
    error('error in name of the axis')
end

% Apply flips along necessary axes
tmp = data.Data;
for i = 1:3
    if Flip(i) == 1
        tmp = flip(tmp, i);
    end
end

% Apply permutation to reorder axes
dataperm.Data = permute(tmp, Perm);

% Reorder voxel sizes to match new axes
dataperm.VoxelSize = data.VoxelSize(Perm(1:3));

% Set direction to match atlas
dataperm.Direction = atlas.Direction;

end
