%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));


%% Test Visual from methods paper
experiment_root_folder = '/data03/fUSIMethodsPaper_LC'
fn_collection_path='Data_collection/sub-methods02/ses-231215/run-115047/';
datapath = fullfile(experiment_root_folder, fn_collection_path)

fonduta.reconstruction.functional_reconstruction(datapath)

% % Load the generated PDI for inspection
% PDI = load('/data03/fUSIMethodsPaper_LC/Data_analysis/sub-methods02/ses-231215/run-115047/PDI.mat').PDI


%% Test Droplets mock scan
experiment_root_folder = '/data03/fUSIHarmAversion';
fn_collection_path='/Data_collection/sub-mockexperiment/ses-999999/run-155150-func';
datapath = fullfile(experiment_root_folder, fn_collection_path)

fonduta.reconstruction.functional_reconstruction(datapath)

% % Load the generated PDI for inspection
% PDI = load('/data03/fUSIHarmAversion/Data_analysis/sub-mockexperiment/ses-999999/run-155150-func/PDI.mat').PDI


















