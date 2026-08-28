function eta2 = calculate_mean_eta2_maps( ...
    glm_files, datapaths, anatpaths, atlas, models, results_path, varargin)
%CALCULATE_MEAN_ETA2_MAPS Calculate and save mean eta2 maps in Allen space.
%
% Optional Name-Value Pairs:
%   'normalize' - (logical) If true, scales each subject's eta2 map to [0, 1]
%                 by its max value before averaging. Default is false.
%   'force'     - (logical) If true, recalculates and overwrites existing 
%                 files. Default is false.

%% 1. Parse Name-Value Arguments
p = inputParser;
addParameter(p, 'normalize', false, @islogical);
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});

normalize_flag = p.Results.normalize;
force_recalc   = p.Results.force;

%% 2. Check If All Files Already Exist
all_exist = true;
eta2 = struct();

for imodel = 1:numel(models)
    key = get_model_key(models(imodel), normalize_flag);
    mean_file = fullfile(results_path, [key '_eta2_mean.mat']);
    mask_file = fullfile(results_path, [key '_eta2_mask.mat']);
    
    if ~exist(mean_file, 'file') || ~exist(mask_file, 'file')
        all_exist = false;
        break;
    end
end

% Early exit if files exist and force calculation is off
if all_exist && ~force_recalc
    fprintf('All requested maps already exist in %s. Loading existing files...\n', results_path);
    for imodel = 1:numel(models)
        key = get_model_key(models(imodel), normalize_flag);
        mean_file = fullfile(results_path, [key '_eta2_mean.mat']);
        mask_file = fullfile(results_path, [key '_eta2_mask.mat']);
        
        eta2.(key).mean = load(mean_file).eta2_mean;
        eta2.(key).mask = load(mask_file).eta2_mask;
    end
    return;
end

%% 3. Compute Eta2 Maps
nsubj = numel(glm_files);
allen_dims = size(atlas.Histology);

eta2_mean = zeros(allen_dims);
eta2_mean_mask = eta2_mean;

for imodel = 1:numel(models)
    key = get_model_key(models(imodel), normalize_flag);
    eta2.(key) = struct( ...
        'mean', eta2_mean, ...
        'mask', eta2_mean_mask);
end

% Loop over subjects
for isub = 1:nsubj

    sub_glm_file = glm_files(isub).name;
    runID = regexp(sub_glm_file, 'run-\d+', 'match', 'once');

    fprintf('Processing sub %s (%d/%d)\n', runID, isub, nsubj);

    % Load anatomic and transformation
    idxData = find(contains(datapaths, runID));

    anatomic = load( ...
        fullfile(anatpaths(idxData), "anatomic.mat")).anatomic;

    Transf = load( ...
        fullfile(anatpaths(idxData), "Transformation.mat")).Transf;

    % Load GLM data
    data = load( ...
        fullfile(glm_files(isub).folder, sub_glm_file)).data;

    % Loop over models
    for imodel = 1:numel(models)

        model_name = models(imodel).name;
        predictor  = models(imodel).predictor;
        key        = get_model_key(models(imodel), normalize_flag);

        % Extract 2D eta2 volume in individual space
        if isfield(data.models.(model_name), 'fcontrasts') && ...
           isfield(data.models.(model_name).fcontrasts, predictor)
            
            % --- FIR MODEL ---
            raw_vol = data.models.(model_name).fcontrasts.(predictor).eta2_p;
            
        else
            
            % --- HRF MODEL ---
            eta2_vol_idx = find(strcmp( ...
                data.models.(model_name).predictor_labels, predictor));

            if isempty(eta2_vol_idx)
                error('Predictor "%s" not found in model "%s" for file %s', ...
                    predictor, model_name, sub_glm_file);
            end

            raw_vol = data.models.(model_name).eta2(eta2_vol_idx, :, :);
            
        end

        % Force conversion to exact 2D size matching anatomic slice
        sub_eta2_vol = reshape(raw_vol, size(anatomic.Data, 1), size(anatomic.Data, 2));

        % --- Subject-wise Normalization [0, 1] ---
        if normalize_flag
            max_val = max(sub_eta2_vol(:), [], 'omitnan');
            if max_val > 0
                sub_eta2_vol = sub_eta2_vol / max_val;
            end
        end

        % Embed in 3D volume
        anatomic_eta2 = anatomic;
        anatomic_eta2.Data = zeros(size(anatomic.Data));
        anatomic_eta2.Data(:, :, anatomic.funcSlice(3)) = sub_eta2_vol;

        % Transform to Allen space
        eta2_in_atlas = fonduta.atlas.individual2atlas( ...
            anatomic_eta2, atlas, Transf);

        % Create mask
        eta2_in_atlas_mask = (eta2_in_atlas > 0) .* 1;

        % Accumulate
        eta2.(key).mean = eta2.(key).mean + eta2_in_atlas;
        eta2.(key).mask = eta2.(key).mask + eta2_in_atlas_mask;

    end
end

%% 4. Save Resulting Eta2 Maps
if ~exist(results_path, 'dir'), mkdir(results_path); end

for imodel = 1:numel(models)

    key = get_model_key(models(imodel), normalize_flag);
    disp(key)

    eta2_mask = eta2.(key).mask;
    
    eta2_mean_vol = zeros(allen_dims);
    valid_vox = eta2_mask > 0;
    eta2_mean_vol(valid_vox) = eta2.(key).mean(valid_vox) ./ eta2_mask(valid_vox);

    % Update return struct with computed mean
    eta2.(key).mean = eta2_mean_vol;

    save(fullfile(results_path, [key '_eta2_mask.mat']), 'eta2_mask');
    save(fullfile(results_path, [key '_eta2_mean.mat']), 'eta2_mean_vol', '-v7.3');

end

end


%% Helper function for unique struct & filename keying
function key = get_model_key(m, normalize_flag)
    if isfield(m, 'prefix') && ~isempty(m.prefix)
        base_key = sprintf('%s_%s_%s', m.prefix, m.name, m.predictor);
    else
        base_key = sprintf('%s_%s', m.name, m.predictor);
    end
    
    if nargin > 1 && normalize_flag
        key = [base_key '_norm'];
    else
        key = base_key;
    end
end