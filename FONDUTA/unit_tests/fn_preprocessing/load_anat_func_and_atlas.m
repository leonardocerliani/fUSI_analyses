function [PDI, anatomic, Transf, atlas] = load_anat_func_and_atlas(anatPath, funcPath)
% LOAD_ANAT_AND_FUNC - Load anatomical, functional, and atlas data for fUSI preprocessing
%
% Syntax:
%   [PDI, anatomic, Transf, atlas] = load_anat_and_func(anatPath, funcPath)
%
% Description:
%   Loads all required data for fUSI preprocessing including the Allen brain
%   atlas (via fonduta package), anatomical scan, transformation matrix, and functional scan.
%
% Inputs:
%   anatPath - Path to anatomical data directory containing anatomic.mat 
%              and Transformation.mat
%              Example: 'sample_data/Data_analysis/run-113409-anat'
%   funcPath - Path to functional data directory containing PDI.mat
%              Example: 'sample_data/Data_analysis/run-115047-func'
%
% Outputs:
%   PDI      - Structure containing functional data and metadata
%   anatomic - Structure containing anatomical data and metadata
%   Transf   - Transformation matrix for atlas-to-subject registration
%   atlas    - Allen brain atlas structure loaded via fonduta
%
% Example:
%   [PDI, anatomic, Transf, atlas] = load_anat_and_func(...
%       'sample_data/Data_analysis/run-113409-anat', ...
%       'sample_data/Data_analysis/run-115047-func');

%% Input argument handling and path validation

if nargin < 1 || isempty(anatPath)
    error('Anatomical path (anatPath) was not provided.');
elseif ~isfolder(anatPath)
    error('Anatomical data directory does not exist: %s', anatPath);
end

if nargin < 2 || isempty(funcPath)
    error('Functional path (funcPath) was not provided.');
elseif ~isfolder(funcPath)
    error('Functional data directory does not exist: %s', funcPath);
end

%% Load Allen Brain Atlas via fonduta

fprintf('Loading Allen Brain Atlas...\n');
atlas = fonduta.atlas.load_atlas();

%% Load anatomical scan and transformation matrix

fprintf('Loading anatomical data from: %s\n', anatPath);

anatFile = fullfile(anatPath, 'anatomic.mat');
if ~isfile(anatFile)
    error('Anatomical data file not found: %s', anatFile);
end
anatData = load(anatFile, 'anatomic');
anatomic = anatData.anatomic;

transfFile = fullfile(anatPath, 'Transformation.mat');
if ~isfile(transfFile)
    error('Transformation file not found: %s', transfFile);
end
transfData = load(transfFile, 'Transf');
Transf = transfData.Transf;

% Set storage path
anatomic.savepath = anatPath;

%% Load functional scan

fprintf('Loading functional data from: %s\n', funcPath);

funcFile = fullfile(funcPath, 'PDI.mat');
if ~isfile(funcFile)
    error('Functional data file not found: %s', funcFile);
end

pdiData = load(funcFile, 'PDI');
PDI = pdiData.PDI;

% Set storage path
PDI.savepath = funcPath;

fprintf('Data loading complete.\n');

end