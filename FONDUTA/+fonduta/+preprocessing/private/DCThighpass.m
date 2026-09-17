function VolHP = DCThighpass(Vol, fs, cutoff_sec, mask)
% DCT_HIGHPASS3  High-pass fUSI/fMRI stack (x,y,t) via DCT regression.
%
% Vol  (nx × ny × nt)   – single or double
% fs   – frame-rate [Hz]
% cutoff_sec – high-pass cut-off in seconds (remove drift < 1/cutoff)
% mask (optional) (nx × ny) – logical brain mask
%
% Returns VolHP with the same size & class as Vol.

% -------------------------------------------------------------------------
[nx,ny,T] = size(Vol);      V = nx*ny;

% ---------- reshape to vox × time ----------------------------------------
Vol2D = reshape(Vol, V, T);

% ---------- choose voxels to process ------------------------------------
if nargin < 4 || isempty(mask)
    idx = 1:V;
else
    idx = find(mask(:));
end
Y   = double(Vol2D(idx,:));           % rows = voxels

% ---------- build DCT basis  (SPM formula) -------------------------------
%   number of columns whose period ≥ cutoff_sec :
%   K = floor( 2 * (scan length) / cutoff )
K = floor( 2*T / (cutoff_sec*fs) );

if K < 1                  %  cut-off longer than run → nothing to remove
    warning('DCT-high-pass: cutoff too low -- returning input unchanged.');
    VolHP = Vol;  return
end

t   = (0:T-1)';
C   = zeros(T,K);
for k = 1:K
    C(:,k) = cos( pi*(2*t+1)*k / (2*T) );
end
C = C - mean(C,1);        % centre each column

% ---------- regress out drift -------------------------------------------
beta   = (C' * C) \ (C' * Y.');      % K × Nv
Yhp    = Y.' - C * beta;             % T × Nv → Nv × T
Yhp    = Yhp.';

% ---------- put filtered voxels back & reshape --------------------------
Vol2D(idx,:) = cast(Yhp, class(Vol));
VolHP        = reshape(Vol2D, nx, ny, T);
end