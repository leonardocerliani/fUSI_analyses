
%% Import fonduta package
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

%% View the results of a glm

results_dir='/data06/fUSIMethodsPaper/Data_analysis/sub-Group/VisualTest/Functional/LC'
fonduta.viz.view_glm(fullfile(results_dir, 'glm_run-142136.mat'));


%% Importing the data locations for all subs in one experiment

% Load the filenames for the Visual test experiment
[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.Datapath('VisualTest');

% Choose one subject's anatomic and explore it in the viewer
% (scroll across slices with the mouse wheel)
anatPath = subAnatPath{1}
load(fullfile(anatPath, 'anatomic.mat'), 'anatomic')
fonduta.viz.view_image(anatomic.Data, [], 3)    % 3 = coronal


%% Transformations

% Load the atlas
atlas = fonduta.atlas.load_atlas()

% load the anatomic of one sub
anatPath = subAnatPath{1}
load(fullfile(anatPath, 'anatomic.mat'), 'anatomic')
load(fullfile(anatPath, 'Transformation.mat'), 'Transf')

% anatomic -> atlas
output_anatomic2atlas = fonduta.atlas.individual2atlas(anatomic, atlas, Transf);

fonduta.viz.view_image(atlas.Histology, output_anatomic2atlas)


% atlas -> anatomic
output_atlas2individual = fonduta.atlas.atlas2individual(atlas, anatomic, Transf);

fonduta.viz.view_image(output_atlas2individual.Histology.Data, anatomic.Data, 3)



%% Visualization - simple viewer + overlay
fonduta.viz.view_image(atlas.Histology, atlas.Regions, 2)
fonduta.viz.view_image(anatomic.Data, [], 3)

%% View registration
FONDUTA_PATH = '/data00/leonardo/github/fUSI_analyses/FONDUTA';
addpath(genpath(FONDUTA_PATH));

atlas = fonduta.atlas.load_atlas()

[subDataPath, subAnatPath, resultPath] = fonduta.io.datapath.Datapath('VisualTest');
anatPath = subAnatPath{1}

load(fullfile(anatPath, 'anatomic.mat'),       'anatomic');
load(fullfile(anatPath, 'Transformation.mat'), 'Transf');

output_anatomic2atlas = fonduta.atlas.individual2atlas(anatomic, atlas, Transf);

fonduta.viz.view_registration(atlas, output_anatomic2atlas)




