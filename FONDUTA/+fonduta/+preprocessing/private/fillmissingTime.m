function volOut = fillmissingTime(volIn, method)
%INTERP_NAN_TIME  Fill NaNs of a (x,y,t) fUSI stack along the time axis.
%
% volIn  – single or double, size = [nx ny nt]
% method – 'linear' | 'pchip' | 'spline'  (default 'linear')
%
% Any leading / trailing NaNs are filled with nearest valid value
% to avoid edge effects.

if nargin < 2,  method = 'linear';  end

sz      = size(volIn);                  % [nx ny nt]
X       = reshape(volIn, [], sz(3));    % voxels × time
nanMask = isnan(X);

if any(nanMask(:))
    % 1-D interpolation voxel-by-voxel (vectorised with FILLMISSING)
    X = fillmissing(X, method, 2, 'EndValues', 'nearest');
end

volOut = reshape(X, sz);
end