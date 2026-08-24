function eta2 = calculate_mean_eta2_maps( ...
    HRF_glm_files, datapaths, anatpaths, atlas, models, results_path)
%CALCULATE_ETA2_MAPS Calculate and save mean eta2 maps in Allen space.
%
% eta2 = calculate_eta2_maps(HRF_glm_files, datapaths, anatpaths, ...
%                            atlas, models, results_path)

nsubj = numel(HRF_glm_files);

% Initialize eta2 maps
allen_dims = size(atlas.Histology);

eta2_mean = zeros(allen_dims);
eta2_mean_mask = eta2_mean;

eta2 = struct();

  for imodel = 1:numel(models)

      model_name = models(imodel).name;

      eta2.(model_name) = struct( ...
          'mean', eta2_mean, ...
          'mask', eta2_mean_mask);

  end


  %% Loop over subjects

  for isub = 1:nsubj

      sub_glm_file = HRF_glm_files(isub).name;
      runID = regexp(sub_glm_file, 'run-\d+', 'match', 'once');

      fprintf('Processing sub %s\n\n', runID)

      % Load anatomic and transformation
      idxData = find(contains(datapaths, runID));

      anatomic = load( ...
          fullfile(anatpaths(idxData), "anatomic.mat")).anatomic;

      Transf = load( ...
          fullfile(anatpaths(idxData), "Transformation.mat")).Transf;

      % Load GLM data
      data = load( ...
          fullfile(HRF_glm_files(isub).folder, sub_glm_file)).data;


      %% Loop over models

      for imodel = 1:numel(models)

          model_name = models(imodel).name;
          predictor = models(imodel).predictor;

          % Find the predictor
          eta2_vol_idx = find(strcmp( ...
              data.models.(model_name).predictor_labels, predictor));

          % Get eta2 volume in individual space
          sub_eta2_vols = data.models.(model_name).eta2;
          sub_eta2_vol = squeeze(sub_eta2_vols(eta2_vol_idx,:,:));

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
          eta2.(model_name).mean = ...
              eta2.(model_name).mean + eta2_in_atlas;

          eta2.(model_name).mask = ...
              eta2.(model_name).mask + eta2_in_atlas_mask;

      end
  end


  %% Save resulting eta2 maps

  for imodel = 1:numel(models)

      model_name = models(imodel).name;
      disp(model_name)

      eta2_mask = eta2.(model_name).mask;
      eta2_mean = eta2.(model_name).mean ./ eta2_mask;

      save(fullfile(results_path, ...
          [model_name '_eta2_mask.mat']), 'eta2_mask')

      save(fullfile(results_path, ...
          [model_name '_eta2_mean.mat']), 'eta2_mean')

  end

end