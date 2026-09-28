function clean_fusi_data(matFilePath)
% CLEAN_FUSI_DATA Vectorized GLM cleaning to remove wheel running confounds.
% Fits all 509 ROIs simultaneously using OLS matrix decomposition (\).

    if ~exist(matFilePath, 'file')
        error('File "%s" not found.', matFilePath);
    end

    fprintf('Loading %s for vectorized running confound removal...\n', matFilePath);
    loadedData = load(matFilePath);
    
    structNames = fieldnames(loadedData);
    datasetName = structNames{1};
    dataset = loadedData.(datasetName);
    
    nSessions = numel(dataset.sessions);
    
    for isub = 1:nSessions
        fprintf('Cleaning session %d / %d...\n', isub, nSessions);
        subData = dataset.sessions{isub};
        
        fUSI_raw = subData.fUSI; % [509 x nFrames]
        [nRoi, nFrames] = size(fUSI_raw);
        t = subData.time;
        dt = subData.dt;
        
        % 1. HRF Kernel Computation
        hrf = hemodynamicResponse(dt, [2.4 8 0.8 0.9 6 0 16]);
        
        % 2. Build Stimulus Predictors
        nConds = numel(subData.stimInfo.cond);
        stim = zeros(nFrames, nConds);
        for ic = 1:nConds
            stim(:, ic) = double(subData.stimInfo.cond(ic).mask(:));
        end
        X_stim = filter(hrf, 1, stim);
        
        % 3. Build Wheel Predictors (Running & ConvRunning)
        if ~isempty(subData.wheel.time) && ~isempty(subData.wheel.speed)
            wheelSpeed = abs(interp1(subData.wheel.time, subData.wheel.speed, t, 'linear', 0))';
        else
            wheelSpeed = zeros(nFrames, 1);
        end
        wheelSpeedConv = filter(hrf, 1, wheelSpeed);
        
        % 4. Assemble Full Design Matrix with Intercept [nFrames x (1 + nConds + 2)]
        X = [ones(nFrames, 1), X_stim, wheelSpeed, wheelSpeedConv];
        
        % Column indices for Running and ConvRunning in X
        idxRunning = 1 + nConds + 1;     % +1 accounts for Intercept column
        idxConvRunning = 1 + nConds + 2;
        
        % 5. Exclusion Mask (baseline frames only)
        excludeMask = sum(stim, 2) > 0;
        includeFrames = ~excludeMask;
        
        % 6. Vectorized OLS Estimation across ALL ROIs simultaneously
        % Matrix Y is [nFrames x 509]
        Y = fUSI_raw'; 
        
        % Filter out bad/zero ROIs to prevent NaN propagation
        validRois = ~all(Y == 0, 1) & ~any(isnan(Y), 1);
        
        % Slice estimation matrices to non-excluded frames
        X_est = X(includeFrames, :);
        Y_est = Y(includeFrames, validRois);
        
        % Compute Beta weights for all valid ROIs at once: Beta = [nPredictors x nValidRois]
        Beta = X_est \ Y_est; 
        
        % 7. Reconstruct Running Artifacts Across ALL Frames [nFrames x 509]
        runningSignal = zeros(nFrames, nRoi);
        runningSignal(:, validRois) = X(:, idxRunning) * Beta(idxRunning, :) + ...
                                      X(:, idxConvRunning) * Beta(idxConvRunning, :);
        
        % Subtract running artifacts from raw signals [509 x nFrames]
        fUSI_clean = (Y - runningSignal)';
        
        % Store cleaned data
        dataset.sessions{isub}.fUSI_clean = fUSI_clean;
    end
    
    % Save updated struct back to file
    S = struct();
    S.(datasetName) = dataset;
    save(matFilePath, '-struct', 'S', '-v7.3');
    fprintf('Vectorized cleaning complete! Updated %s.\n', matFilePath);
end