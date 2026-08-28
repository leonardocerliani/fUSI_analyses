function res = eta2_HRF_FIR_correlation(HRF_glm_files, FIR_glm_files, model_HRF, results_path, varargin)
% ETA2_HRF_FIR_CORRELATION Computes and saves spatial correlation between 
% HRF and FIR eta2 maps across brain voxels and percentile thresholds.

%% 1. Parse Inputs & Check Disk Cache
p = inputParser;
addParameter(p, 'pctile_steps', 0:5:95, @isnumeric);
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});

pctile_steps = p.Results.pctile_steps;
force_recalc = p.Results.force;

save_file = fullfile(results_path, sprintf('res_%s.mat', model_HRF));

if exist(save_file, 'file') && ~force_recalc
    fprintf('Loading existing correlation results for %s...\n', model_HRF);
    loaded_data = load(save_file, 'res');
    res = loaded_data.res;
    return;
end

fprintf('Computing correlation for model %s...\n', model_HRF);

%% 2. Model Mapping Setup
switch model_HRF
    case 'M1_StimOnly'
        model_FIR = 'M1_StimOnly';
        HRF_eta2_idx = 1;
        FIR_contrasts = {'Visual_FIR'};

    case 'M5_Behavior'
        model_FIR = 'M5_Behavior';
        HRF_eta2_idx = [1 3 4];
        FIR_contrasts = {'Visual_FIR', 'Wheel_FIR', 'Interaction_FIR'};

    case 'M8_SteadyVisual'
        model_FIR = 'M8_SteadyVisual';
        HRF_eta2_idx = 1;
        FIR_contrasts = {'Visual_Steady_FIR'};

    otherwise
        error('No HRF/FIR mapping defined for model "%s".', model_HRF);
end

nSubs       = numel(HRF_glm_files);
nPredictors = numel(HRF_eta2_idx);
nPctiles    = numel(pctile_steps);

%% 3. Preallocate Outputs
res.eta2_corrs   = nan(nSubs, nPredictors);
res.pctile_corr  = nan(nSubs, nPctiles, nPredictors);
res.pctile_steps = pctile_steps;

%% 4. Loop over Subjects
for isub = 1:nSubs

    disp(isub)

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

    bmask_idx = find(HRF_onesub.bmask);

    for ipred = 1:nPredictors
        HRF_eta2_map = squeeze(HRF_onesub.models.(model_HRF).eta2(HRF_eta2_idx(ipred), :, :));
        contrast_name = FIR_contrasts{ipred};
        FIR_eta2_map  = FIR_onesub.models.(model_FIR).fcontrasts.(contrast_name).eta2_p;

        HRF_vec = HRF_eta2_map(bmask_idx);
        FIR_vec = FIR_eta2_map(bmask_idx);

        % Global correlation across ALL brain voxels
        res.eta2_corrs(isub, ipred) = corr(HRF_vec, FIR_vec, 'rows', 'complete');

        % Percentile-thresholded correlation
        for ipct = 1:nPctiles
            p_exclude = pctile_steps(ipct);
            if p_exclude == 0
                top_mask = true(size(HRF_vec));
            else
                thresh = prctile(HRF_vec, p_exclude);
                top_mask = (HRF_vec >= thresh);
            end

            HRF_top = HRF_vec(top_mask);
            FIR_top = FIR_vec(top_mask);

            if numel(HRF_top) > 2
                res.pctile_corr(isub, ipct, ipred) = corr(HRF_top, FIR_top, 'rows', 'complete');
            end
        end
    end
end

%% 5. Save Results
if ~exist(results_path, 'dir'), mkdir(results_path); end
save(save_file, 'res');

end