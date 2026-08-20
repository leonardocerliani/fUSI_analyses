%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

%% View the results of a glm

results_dir='/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest/';
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136.mat'));
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136_FIR.mat'));


list = dir('/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest/')

for i = 3:numel(list)
    name = list(i).name;
    fonduta.viz.view_glm(fullfile(results_dir, name));
    pause;  % wait for user input before continuing
end


%% view glm results

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';
sub_results_file='glm_run-101347.mat';
fonduta.viz.view_glm(fullfile(glm_results_path, sub_results_file))

atlas = fonduta.atlas.load_atlas();

fonduta.viz.view_registration(atlas, atlas.Vascular)


%% testing the new loo-cv ridge ROI

glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';

% Custom eta2 (default: 0.05):
opts.eta2_thresh_val = 0.03;

% Model Name from the saved glm results file
% model_name = 'M1_StimOnly';
model_name = 'M8_SteadyVisual';

tic
analysis_ridge_loo_ROI(glm_results_path, model_name, opts);
toc

% 'results_ridge_loo/ridge_loo_M8_SteadyVisual_eta003_HRF12s.mat'
% 'results_ridge_loo/ridge_loo_M1_StimOnly_eta003_HRF12s.mat'


%% mean eta2 map on allen atlas

FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';

glm_files = dir(fullfile(glm_results_path, 'glm*.mat'));

atlas = fonduta.atlas.load_atlas();

[datapaths, anatpaths, ~] = fonduta.io.datapath.Datapath('VisualTest');

nsubj = length(glm_files);

reference_model='M8_SteadyVisual';

allen_dims = size(atlas.Histology);
eta2_mean = zeros([allen_dims(1),allen_dims(2), allen_dims(3)]);
eta2_mean_mask = eta2_mean;


eta2_vol_idx = find(strcmp(tmp.models.(reference_model).predictor_labels, 'stim_stationary_hrf'));


for isub = 1 : nsubj

    disp(isub)

    sub_glm_file = glm_files(isub).name
    runID = regexp(sub_glm_file, 'run-\d+', 'match', 'once')

    idxData = find(contains(datapaths, runID));
    anatomic = load(fullfile(anatpaths(idxData),"anatomic.mat")).anatomic;
    Transf = load(fullfile(anatpaths(idxData),"Transformation.mat")).Transf;

    data = load(fullfile(glm_files(isub).folder, sub_glm_file)).data;

    % get the eta2 volume in individual space
    sub_eta2_vols = data.models.(reference_model).eta2;
    sub_eta2_stim_vol = squeeze(sub_eta2_vols(eta2_vol_idx,:,:));

    % embed it in a 3D volume (the anatomic) at the specific slice where it
    % was taken
    anatomic_eta2 = anatomic;
    anatomic_eta2.Data = zeros(size(anatomic.Data));
    anatomic_eta2.Data(:, :, anatomic.funcSlice(3)) = sub_eta2_stim_vol;

    % transform in allen space
    eta2_in_atlas = fonduta.atlas.individual2atlas(anatomic_eta2, atlas, Transf);
    eta2_in_atlas_mask = (eta2_in_atlas > 0).*1; 

    % add to the mean
    eta2_mean = eta2_mean + eta2_in_atlas;
    eta2_mean_mask = eta2_mean_mask + eta2_in_atlas_mask;

end


eta2_mean = eta2_mean ./ eta2_mean_mask;

save('pippo.mat','eta2_mean');
save('pippo_mask.mat','eta2_mean_mask');

fonduta.viz.view_atlas












