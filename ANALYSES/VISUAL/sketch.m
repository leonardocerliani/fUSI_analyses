%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));


% Import the Datapath for a given condition, in order to know where the
% data analysis files are stored

[subDataPath, subAnatPath, ~] = fonduta.io.datapath.Datapath('VisualTest');

%% View one image in coronal
anatomic = load(fullfile(subAnatPath{1},'anatomic.mat')).anatomic;

% fonduta.viz.view_image([background],[overlay],[orientation],[transparency])
fonduta.viz.view_image(anatomic.Data,[],3)

%% Add an overlay, e.g. a glm results map
anatomic = load(fullfile(subAnatPath{1},'anatomic.mat')).anatomic;
% The field anatomic.funcSlice(3) contains the index to the selected slice
anatomic_slice = anatomic.Data(:,:,anatomic.funcSlice(3));

results_dir='/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest/';

glm_res = load(fullfile(results_dir, 'glm_run-142136.mat')).data;

% brain mask on anatomic
fonduta.viz.view_image( ...
    anatomic_slice, ...
    glm_res.bmask, ...
    3, ...
    0.3)

% eta2 of stimulus effect on anatomic
eta2_stim = squeeze(glm_res.models.M5_Behavior.eta2(1,:,:));
% threshold the eta2 image
eta2_stim_thresh = eta2_stim;
eta2_stim_thresh(eta2_stim_thresh <= 0.01) = 0;


fonduta.viz.view_image( ...
    anatomic_slice, ...
    eta2_stim_thresh, ...
    3, ...
    0.7)

%% View image in atlas space
%  Images for overlay must be 3D matrices from a .mat file, having
%  the same dimension of the allen atlas.
%  Load e.g. the HRF_analysis_revision/eta2_mean_maps

fonduta.viz.view_atlas



%% View the results of a glm

glm_results_path = '/data06/fUSIMethodsPaper/Data_analysis/LC/VisualTest';

HRF_sub_results_file='glm_run-101347.mat';
FIR_sub_results_file='FIR_glm_run-101347.mat';

fonduta.viz.view_glm(fullfile(glm_results_path, HRF_sub_results_file))

% % View all the results in sequence
% list = dir(fullfile(glm_results_path, 'glm*.mat'));
% 
% for i = 1:3 %numel(list)
%     name = list(i).name;
%     fonduta.viz.view_glm(fullfile(glm_results_path, name));
%     pause;  % wait for user input before continuing
% end


%% Check registration of image in allen space
atlas = fonduta.atlas.load_atlas();
fonduta.viz.view_registration(atlas, atlas.Vascular)


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












