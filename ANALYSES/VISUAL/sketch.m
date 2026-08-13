
% Load the results of a glm on a single subject

condition    = 'VisualTest';   % experiment condition (passed to Datapath)
resultFolder = condition;           % output subfolder name

resultPath = '/data06/fUSIMethodsPaper/Data_analysis/LC'

glm_results_path = fullfile(resultPath, resultFolder)

glm_results = load(fullfile(glm_results_path, 'glm_run-163615.mat')).data;

% % see all the nested fields at once
% fonduta.utils.tree_struct(glm_results)

% The outermost layer of the struct contains the anatomic and datapath, as
% well as other useful stuff like the individual -> atlas transformation
% and the mask of the selected functional slice
glm_results

%   struct with fields:
% 
%          dataPath: '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-163615/'
%          anatPath: '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-154044/'
%            Transf: [1x1 struct]
%             bmask: [158x90 double]
%      nonBrainMask: [158x90 logical]
%     allen_regions: [158x90 int16]
%        predictors: [1x1 struct]
%            models: [1x1 struct]


% The .predictors field contains the raw predictor before convolution.
% Whether a predictor requires or not convolution is determined by the
% formula passed to the glm
glm_results.predictors

%               condMat: {10x1 cell}
%              stim_all: [6028x1 double]
%       stim_stationary: [6028x1 double]
%                 wheel: [6028x1 double]
%           wheelSmooth: [6028x1 double]
%             globalPC1: [6028x1 double]
%           nonBrainPC1: [6028x1 double]
%      visualTrialIndex: [5x1 double]
%     runningTrialIndex: [5x1 double]
%     steadyExcludeMask: [6028x1 logical]

% For instance this plots the predictor for all the stimuli (visual in this case)
plot(glm_results.predictors.stim_all)
title('raw predictors (1 during stimulus, 0 elsewhere)')


% The models which were fitted are in .models. Each one is a struct with 
% the actual predictors used for that model, as well as labels and results
% (maps)
glm_results.models

%                M1_StimOnly: [1x1 struct]
%           M2_HardGlobalPC1: [1x1 struct]
%           M3_SoftGlobalPC1: [1x1 struct]
%         M4_SoftNonBrainPC1: [1x1 struct]
%                M5_Behavior: [1x1 struct]
%       M6a_BehSoftGlobalPC1: [1x1 struct]
%     M6b_BehSoftNonBrainPC1: [1x1 struct]
%         M6c_BehSoftBothPC1: [1x1 struct]
%              M7a_RunSmooth: [1x1 struct]
%                M7b_RunConv: [1x1 struct]
%            M8_SteadyVisual: [1x1 struct]



% Differently from the .predictors field, the .models.(model).Xmodel 
% contains the predictors *after* hrf convolution, that is the actual
% predictors used in that model.
% The corresponding labels are in .models.(model).predictor_labels
model='M7b_RunConv'
visual_predictor_idx = 2 % always with label stim_hrf

plot(glm_results.models.(model).Xmodel(:,visual_predictor_idx))
title(glm_results.models.(model).predictor_labels{visual_predictor_idx},'Interpreter','none')

% These can also be visualized with fonduta.viz.view_design_matrix()
fonduta.viz.view_design_matrix(glm_results.models.(model))

% as well as when viewing the results of the glm
fonduta.viz.view_glm(fullfile(glm_results_path, 'glm_run-163615.mat'))


% the results of the glm analysis (maps in the single subject space) can be
% found in .models.(model), e.g.

glm_results.models.(model)

%                betas: [5x158x90 double]
%                 eta2: [4x158x90 double]
%                   R2: [158x90 double]
%               Xmodel: [6028x4 double]
%     predictor_labels: {'wheel_hrf'  'stim_hrf'  'wheelSmooth'  'interaction_hrf'  'intercept'}
%           model_name: 'M7b_RunConv'


% To view the results manually (without using fonduta.viz.view_glm) we can
% use fonduta.viz.view_image()
load(fullfile(glm_results.anatPath, 'anatomic.mat'), 'anatomic');
anatomic_funcslice = anatomic.Data(:,:,anatomic.funcSlice(3));

eta2 = squeeze(glm_results.models.M7a_RunSmooth.eta2(2,:,:));

fonduta.viz.view_image(anatomic_funcslice, eta2, 3)









