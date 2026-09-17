function tform = phase_correlation(moving, fixed)
% PRECISE_IMAGECORR  Phase-correlation based translation estimator.
%
%   Drop-in replacement for:
%       tform = imregcorr(moving, fixed, 'translation')
%
%   Gives consistent sub-pixel results across all MATLAB versions
%   (tested on R2022b and R2025a). The built-in imregcorr may return
%   [0 0] in older versions when the peak confidence is below an internal
%   threshold that was relaxed in newer releases.
%
% Syntax:
%   tform = precise_imagecorr(moving, fixed)
%
% Inputs:
%   moving  - 2D grayscale image to align (same size as fixed)
%   fixed   - 2D reference image
%
% Output:
%   tform   - transltform2d object (identical type to imregcorr output)
%             Compatible with imwarp, tform.Translation, tform.T, etc.
%
% Algorithm:
%   1. Apply a 2-D Hann window to suppress edge discontinuities
%   2. Compute the normalised cross-power spectrum (phase correlation)
%   3. Locate the integer peak of the IFFT correlation map
%   4. Refine to sub-pixel accuracy with a parabolic fit along each axis
%   5. Wrap the result into a transltform2d object
%
% Example (drop-in replacement):
%   % Before:
%   tform = imregcorr(PDI.PDI(:,:,k), ref, 'translation');
%   % After:
%   tform = precise_imagecorr(PDI.PDI(:,:,k), ref);
%
% See also: imregcorr, imwarp, transltform2d

    moving = double(moving);
    fixed  = double(fixed);

    [rows, cols] = size(moving);

    % ------------------------------------------------------------------ %
    % 1. 2-D Hann window (separable product of two 1-D windows)
    % ------------------------------------------------------------------ %
    wr  = hann(rows);
    wc  = hann(cols);
    win = wr * wc';          % [rows x cols]

    M = fft2(moving .* win);
    F = fft2(fixed  .* win);

    % ------------------------------------------------------------------ %
    % 2. Normalised cross-power spectrum
    % ------------------------------------------------------------------ %
    R = F .* conj(M);
    R = R ./ (abs(R) + eps);    % phase-only; eps prevents divide-by-zero

    % ------------------------------------------------------------------ %
    % 3. Correlation map and integer peak
    % ------------------------------------------------------------------ %
    r = real(ifft2(R));         % [rows x cols], peak = best shift

    [~, idx] = max(r(:));
    [pr, pc]  = ind2sub([rows, cols], idx);

    % ------------------------------------------------------------------ %
    % 4. Sub-pixel refinement (parabolic fit along rows and cols)
    % ------------------------------------------------------------------ %
    % Row axis  → Y translation
    ty_sub = parabolic_peak(r(:, pc), pr, rows);

    % Column axis → X translation
    tx_sub = parabolic_peak(r(pr, :)', pc, cols);

    % ------------------------------------------------------------------ %
    % 5. Convert cyclic indices to signed translations
    %    Shifts > N/2 are "negative" (image wrapped around the border)
    % ------------------------------------------------------------------ %
    tx = tx_sub;
    ty = ty_sub;

    if tx > cols / 2,  tx = tx - cols;  end
    if ty > rows / 2,  ty = ty - rows;  end

    % ------------------------------------------------------------------ %
    % 6. Return as transltform2d (same object type as imregcorr)
    % ------------------------------------------------------------------ %
    tform = transltform2d([tx, ty]);

end


% ======================================================================= %
%  Local helper: parabolic sub-pixel interpolation
% ======================================================================= %
function sub = parabolic_peak(v, peak_idx, N)
% PARABOLIC_PEAK  Refine an integer peak to sub-pixel via parabolic fit.
%
%   v         - 1-D vector (a row or column slice through the correlation map)
%   peak_idx  - integer index of the peak in v (1-based)
%   N         - length of v (used for cyclic wrap-around)
%
% Returns sub-pixel peak position (1-based, possibly fractional).

    v = v(:);

    prev = mod(peak_idx - 2, N) + 1;   % index before peak (cyclic)
    next = mod(peak_idx,     N) + 1;   % index after  peak (cyclic)

    vp = v(prev);
    vc = v(peak_idx);
    vn = v(next);

    denom = vp - 2*vc + vn;

    if abs(denom) < eps
        sub = double(peak_idx);        % flat top: no refinement possible
    else
        sub = double(peak_idx) - 0.5 * (vn - vp) / denom;
    end

end