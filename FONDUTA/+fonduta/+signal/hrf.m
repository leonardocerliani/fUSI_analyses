% Source: https://github.com/neurodebian/spm12/blob/master/spm_hrf.m
% renamed function spm_hrf.m  2.8 Karl Friston 02/07/31

function [hrf_kernel, p] = hrf(RT, P)
% fonduta.signal.hrf  Returns a hemodynamic response function kernel.
%
% Computes an SPM-style double-gamma HRF for the given repetition time (TR).
% The returned kernel can be used directly with filter() to convolve a
% predictor signal:
%
%   hrf_kernel = fonduta.signal.hrf(TR);
%   hrf        = @(ev) filter(hrf_kernel, 1, ev(:));
%   stim_hrf   = hrf(stim_boxcar);
%
% FORMAT [hrf_kernel, p] = fonduta.signal.hrf(RT, [P])
%
% Inputs:
%   RT  - scan repetition time / TR (seconds)
%   P   - (optional) parameters of the double-gamma response function:
%           P(1) - delay of response (relative to onset)       default: 6
%           P(2) - delay of undershoot (relative to onset)     default: 16
%           P(3) - dispersion of response                      default: 1
%           P(4) - dispersion of undershoot                    default: 1
%           P(5) - ratio of response to undershoot             default: 6
%           P(6) - onset (seconds)                             default: 0
%           P(7) - length of kernel (seconds)                  default: 32
%
% Outputs:
%   hrf_kernel - hemodynamic response function vector (column)
%   p          - parameters actually used

% global parameter
global defaults
if ~isempty(defaults)
    fMRI_T = defaults.stats.fmri.t;
else
    fMRI_T = 16;
end

% default parameters
p = [6 16 1 1 6 0 32];
if nargin > 1
    p(1:length(P)) = P;
end

% modelled hemodynamic response function — mixture of Gammas
dt        = RT / fMRI_T;
u         = [0:(p(7)/dt)] - p(6)/dt;
hrf_kernel = spm_Gpdf(u, p(1)/p(3), dt/p(3)) - spm_Gpdf(u, p(2)/p(4), dt/p(4)) / p(5);
hrf_kernel = hrf_kernel(round([0:(p(7)/RT)] * fMRI_T + 1));
hrf_kernel = hrf_kernel' / sum(hrf_kernel);

end


% Source: https://github.com/neurodebian/spm12/blob/master/spm_Gpdf.m

function f = spm_Gpdf(x, h, l)
% spm_Gpdf  Probability Density Function of the Gamma distribution.
%
% FORMAT f = spm_Gpdf(x, h, l)
%
% x - Gamma-variate   (Gamma has range [0,Inf))
% h - Shape parameter (h>0)
% l - Scale parameter (l>0)
% f - PDF of Gamma-distribution with shape h and scale l

if nargin < 3
    error('Insufficient arguments');
end

ad = [ndims(x); ndims(h); ndims(l)];
rd = max(ad);
as = [             [size(x), ones(1, rd-ad(1))]; ...
                   [size(h), ones(1, rd-ad(2))]; ...
                   [size(l), ones(1, rd-ad(3))]  ];
rs = max(as);
xa = prod(as, 2) > 1;
if sum(xa) > 1 && any(any(diff(as(xa,:)), 1))
    error('non-scalar args must match in size');
end

f  = zeros(rs);
md = (ones(size(x)) & h > 0 & l > 0);
if any(~md(:))
    f(~md) = NaN;
    warning('Returning NaN for out of range arguments');
end

ml = (md & x == 0 & h < 1);  f(ml) = Inf;
ml = (md & x == 0 & h == 1); if xa(3), mll = ml; else, mll = 1; end
f(ml) = l(mll);

Q = find(md & x > 0);
if isempty(Q), return; end
if xa(1), Qx = Q; else, Qx = 1; end
if xa(2), Qh = Q; else, Qh = 1; end
if xa(3), Ql = Q; else, Ql = 1; end

f(Q) = exp( (h(Qh)-1) .* log(x(Qx)) + h(Qh) .* log(l(Ql)) ...
          - l(Ql) .* x(Qx) - gammaln(h(Qh)) );

end
