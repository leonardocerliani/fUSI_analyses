function [anatomic] = s01_Register_Anatomic_2_Atlas
%   RegisterAnatomic performs the following steps:
%       1. Launches a UI to select a RUN folder from the DATA COLLECTION folder
%          containing the raw anatomical scan data.
%       2. Reads TTL information and the raw PDI data from the selected folder.
%       3. Crops and processes the 3D volume (if required).
%       4. Saves the processed anatomical data to the corresponding
%          DATA ANALYSIS folder.
%       5. Registers the processed scan to the Allen Brain Atlas.
%       6. Saves the transformation in 'Transformation.mat'.
%
%   If a Transformation.mat is already present, it is loaded instead of
%   launching the registration UI.
%
%   USAGE:
%       RegisterAnatomic;
%       % Follow terminal instructions and crop if needed
%       % Data and registration results are saved automatically
%
%   OUTPUT:
%       anatomic - struct containing the processed anatomical data and metadata:
%           VoxelSize      - voxel size in micrometers [Z X Y]
%           ScanPerSlice   - placeholder (to be added)
%           ScanRange      - placeholder (to be added)
%           Nslice         - placeholder (to be added)
%           oriData        - original raw PDI volume
%           Data           - processed/cropped volume
%           Planes         - plane indices
%           Type           - 'volume'
%           Direction      - anatomical orientation
%           datapath       - path to raw data
%           savepath       - path to save processed data
%           cDim           - cropped dimension info from CropData
%           cropWin        - cropping window
%
%   DEPENDENCIES:
%       - ./Registration/BrunnerCodes/registrationccf.m
%       - ./Registration/CropData.m
%       - ./Registration/allen_brain_atlas.mat
%
%
%   NOTES:
%       - On macOS, the folder selection dialog does not show a title.
%       - A message box with instructions appears while selecting the folder
%         and closes automatically once selection is made.
%
%   Original script in Chaoyi repository: RegisterAnatomicNew.m

%% Add all subfolders to path
addpath(genpath(pwd));

%% Folder selection
if nargin < 1
    h = msgbox('Follow the instructions in the terminal', 'Instructions');
    fprintf('Please select the DATA_COLLECTION RUN folder of the anatomical scan to register.\n');
    datapath = uigetdir;  % macOS native dialog
end

%% Read TTL info
try
    D = dir([datapath filesep 'TTL*.csv']);
    TTLinfo = readmatrix([D.folder filesep D.name]);
catch
    error('No TTL recording found!');
end

%% Load scan parameters
load([datapath filesep 'FUSI_data' filesep 'post_L22-14_PlaneWave_FUSI_data.mat'],'BFConfig')

%% Read raw PDI data
fid = fopen([datapath filesep 'FUSI_data' filesep 'fUS_block_PDI_float.bin'], 'r');
rawPDI = fread(fid,inf,'single');
fclose(fid);

%% Define savepath
savepath = strrep(datapath, 'Data_collection', 'Data_analysis');

%% Initialize anatomic struct
anatomic.VoxelSize = [BFConfig.ScaleZ,BFConfig.ScaleX,0.25*1e-3].*1e6; % in um
anatomic.ScanPerSlice = [];
anatomic.ScanRange = [];
anatomic.Nslice = [];
anatomic.oriData = reshape(rawPDI,BFConfig.Nz,BFConfig.Nx,[]);
anatomic.Type = 'volume';
anatomic.Direction = 'DV.LR.AP';
anatomic.datapath = datapath;
anatomic.savepath = savepath;

%% Check and concatenate data frames
PDITTL = find(diff(TTLinfo(:,3))<0);
sliceTTL = find(diff(TTLinfo(:,6))>0);
sliceTTL = [1;sliceTTL;size(TTLinfo,1)];

anatomic.Data = zeros(size(anatomic.oriData,1),size(anatomic.oriData,2),numel(sliceTTL)-1);

for islice = 1:numel(sliceTTL)-1
    sliceInd = PDITTL > sliceTTL(islice) & PDITTL < sliceTTL(islice+1);
    anatomic.Data(:,:,islice) = mean(anatomic.oriData(:,:,sliceInd),3);
end

anatomic.Planes = [0:size(anatomic.Data,3)-1]./10;

%% Crop the image
fprintf('Crop the data if necessary, otherwise just close the window.\n');
CropData

if isempty(gdata.cropWin)
    gdata.cropWin = [1,1;size(gdata.cropData,2),size(gdata.cropData,1)];
end

anatomic.Data = gdata.cropData;
anatomic.cDim = gdata.cDim;
anatomic.cropWin = gdata.cropWin;
anatomic.Direction = gdata.Direction;

clear global

%% Save anatomical data
fprintf('Choose the folder where anatomic.mat will be saved.\n');
if exist(savepath,'file')
    uisave('anatomic', [savepath filesep 'anatomic.mat'])
else
    mkdir(savepath)
    uisave('anatomic', [savepath filesep 'anatomic.mat'])
end

%% Registration with atlas
load('allen_brain_atlas.mat')
if exist([anatomic.savepath filesep 'Transformation.mat'],'file')
    fprintf('Loading the saved transformation.\n');
    load([anatomic.savepath filesep 'Transformation.mat'])
    registrationccf(atlas,anatomic,Transf);
else
    fprintf('Manually translate and rotate the functional scan to match the atlas.\n');
    registrationccf(atlas,anatomic);
end

%% Close instructions msgbox
if exist('h','var') && ishandle(h)
    close(h);
end

end
