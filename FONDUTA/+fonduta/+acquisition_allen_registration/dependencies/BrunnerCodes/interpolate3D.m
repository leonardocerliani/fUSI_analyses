% interpolate3D
% Resamples a 3D scan to match the voxel size of a reference atlas.
% Ensures the scan axes are correctly permuted to align with the atlas using permuteScan.
%
% Inputs:
%   atlas       - Structure containing atlas information, including VoxelSize
%   scanNoperm  - Structure containing the scan data to interpolate. 
%                 Axes may not be aligned with the atlas. 
%                 Fields should include:
%                   .Data      - 3D scan volume
%                   .VoxelSize - voxel spacing along each axis
%                   .Direction - axis orientation labels
%
% Outputs:
%   scanInt     - Structure containing:
%                   .Data      - interpolated 3D scan data
%                   .VoxelSize - voxel size matching the atlas
%                   .Direction - axes order aligned with the atlas
%
% Notes:
%   - The first step is calling permuteScan(scanNoperm, atlas), which:
%       * Reorders axes to match the atlas
%       * Flips axes if necessary to align orientation
%       * Ensures 3D/4D scans have the same axis order as the atlas
%   - Uses nearest-neighbor interpolation ('nearest') to preserve discrete
%     labels (e.g., anatomical regions). Can be changed to 'linear' for smoother interpolation.
%   - Coordinates are carefully permuted to match MATLAB's meshgrid convention.
%   - Voxels outside the original scan volume are set to 0.


function scanInt = interpolate3D(atlas, scanNoperm)

% Permute scan axes to match atlas
scan = permuteScan(scanNoperm, atlas);


% Extract original and atlas voxel sizes
dz = scan.VoxelSize(1);  % spacing along original Z
dx = scan.VoxelSize(2);  % spacing along original X
dy = scan.VoxelSize(3);  % spacing along original Y

dzint = atlas.VoxelSize(1);  % desired spacing along Z
dxint = atlas.VoxelSize(2);  % desired spacing along X
dyint = atlas.VoxelSize(3);  % desired spacing along Y


% Compute size of the resampled volume
[nz, nx, ny] = size(scan.Data);

n1x = round((nx-1) * dx / dxint) + 1;
n1y = round((ny-1) * dy / dyint) + 1;
n1z = round((nz-1) * dz / dzint) + 1;


% Create 3D query grid for interpolation
% Warning: X and Y are permuted in MATLAB meshgrid
%   axis1 = Y, axis2 = X, axis3 = Z
[Xq, Yq, Zq] = meshgrid( ...
    (0:n1x-1) * dxint / dx + 1, ...  % X coordinates in original scan
    (0:n1z-1) * dzint / dz + 1, ...  % Z coordinates in original scan
    (0:n1y-1) * dyint / dy + 1);     % Y coordinates in original scan


% Interpolate the scan data using nearest neighbor
ai = interp3(scan.Data, Xq, Yq, Zq, 'nearest', 0);


% Return interpolated scan structure
scanInt.Data      = ai;                  
scanInt.VoxelSize = atlas.VoxelSize;     
scanInt.Direction = scan.Direction;      


% end of function
end
