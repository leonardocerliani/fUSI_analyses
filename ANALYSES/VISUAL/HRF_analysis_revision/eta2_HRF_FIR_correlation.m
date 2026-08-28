function res = eta2_HRF_FIR_correlation(HRF_glm_files, FIR_glm_files, model_HRF, pctile_steps)
% ETA2_HRF_FIR_CORRELATION Computes spatial correlation between HRF and FIR eta2 maps
% across all brain voxels as well as across percentile thresholds of top HRF activation.
%
% INPUTS:
%   HRF_glm_files - Struct array of HRF GLM file info (from dir)
%   FIR_glm_files - Struct array of FIR GLM file info (from dir)
%   model_HRF     - String: 'M1_StimOnly', 'M5_Behavior', or 'M8_SteadyVisual'
%   pctile_steps  - (Optional) Vector of percentile thresholds [0..100]. 
%                   Default: 0:5:95 (0% = all voxels, 95% = top 5% voxels)
%
% OUTPUT:
%   res           - Struct containing:
%                     .eta2_corrs      : [nSubs x nPredictors] correlation across ALL voxels
%                     .pctile_corr     : [nSubs x nPctiles x nPredictors] thresholded correlations
%                     .pctile_steps    : Vector of percentile thresholds evaluated
%                     .predictor_labels: Cell array of non-intercept predictor names

    %% Default Percentile Thresholds
    if nargin < 4 || isempty(pctile_steps)
        pctile_steps = 0:5:95; % 0 = all voxels, 95 = excluding bottom 95%
    end

    %% Model Mapping Setup
    switch model_HRF
        case 'M1_StimOnly'
            model_FIR = 'F1_StimOnly';
            HRF_eta2_idx = 1;
            FIR_contrasts = {'Visual_FIR'};

        case 'M5_Behavior'
            model_FIR = 'F2_Behavior';
            HRF_eta2_idx = [1 3 4];
            FIR_contrasts = {'Visual_FIR', 'Wheel_FIR', 'Interaction_FIR'};

        case 'M8_SteadyVisual'
            model_FIR = 'F3_SteadyVisual';
            HRF_eta2_idx = 1;
            FIR_contrasts = {'Visual_Steady_FIR'};

        otherwise
            error('No HRF/FIR mapping defined for model "%s".', model_HRF);
    end

    nSubs       = numel(HRF_glm_files);
    nPredictors = numel(HRF_eta2_idx);
    nPctiles    = numel(pctile_steps);

    %% Preallocate Outputs
    res.eta2_corrs   = nan(nSubs, nPredictors);
    res.pctile_corr  = nan(nSubs, nPctiles, nPredictors);
    res.pctile_steps = pctile_steps;

    %% Loop over Subjects
    for isub = 1:nSubs

        fprintf('%d over %d\n', isub, nSubs)

        HRF_onesub = load(fullfile(HRF_glm_files(isub).folder, HRF_glm_files(isub).name)).data;
        FIR_onesub = load(fullfile(FIR_glm_files(isub).folder, FIR_glm_files(isub).name)).data;

        % Extract non-intercept predictor labels on first subject
        if isub == 1 && isfield(HRF_onesub.models.(model_HRF), 'predictor_labels')
            all_labels = HRF_onesub.models.(model_HRF).predictor_labels;
            if strcmp(model_HRF, 'M5_Behavior')
                res.predictor_labels = all_labels([1, 3, 4]);
            else
                res.predictor_labels = all_labels(1);
            end
        end

        % Extract brain mask
        bmask_idx = find(HRF_onesub.bmask);

        % Loop over predictors
        for ipred = 1:nPredictors
            % Extract HRF map
            HRF_eta2_map = squeeze(HRF_onesub.models.(model_HRF).eta2(HRF_eta2_idx(ipred), :, :));
            
            % Extract FIR map
            contrast_name = FIR_contrasts{ipred};
            FIR_eta2_map  = FIR_onesub.models.(model_FIR).fcontrasts.(contrast_name).eta2_p;

            % Vectorize within brain mask
            HRF_vec = HRF_eta2_map(bmask_idx);
            FIR_vec = FIR_eta2_map(bmask_idx);

            % 1. Global correlation across ALL brain voxels
            res.eta2_corrs(isub, ipred) = corr(HRF_vec, FIR_vec, 'rows', 'complete');

            % 2. Percentile-thresholded correlation
            for ipct = 1:nPctiles
                p_exclude = pctile_steps(ipct);
            
                if p_exclude == 0
                    % 0% excluded -> keep all brain voxels
                    top_mask = true(size(HRF_vec));
                else
                    % Exclude the lowest p_exclude % of voxels
                    thresh = prctile(HRF_vec, p_exclude);
                    top_mask = (HRF_vec >= thresh);
                end
            
                % Correlate remaining top voxels
                HRF_top = HRF_vec(top_mask);
                FIR_top = FIR_vec(top_mask);
            
                if numel(HRF_top) > 2
                    res.pctile_corr(isub, ipct, ipred) = corr(HRF_top, FIR_top, 'rows', 'complete');
                end
            end
        end
    end
end