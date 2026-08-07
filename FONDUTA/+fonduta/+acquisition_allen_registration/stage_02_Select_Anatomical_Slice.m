function [anatomic] = s02_Select_Anatomical_Slice
% Select_Anatomical_Slice opens a GUI to browse and select a functional slice from a 3D anatomical scan.
%
% USAGE:
%   anatomic = Select_Anatomical_Slice;
%
% DESCRIPTION:
%   - Prompts the user to select a folder containing:
%         - 'anatomic.mat' (MATLAB struct with anatomical data)
%         - 'Transformation.mat' (required for completeness)
%   - Loads the anatomical struct and initializes a GUI for slice inspection.
%   - Allows browsing through axial slices using 'Slice-' and 'Slice+' buttons.
%   - Displays the current motor location (if available) corresponding to the selected slice.
%   - The user can save the chosen slice using the 'Save' button, which adds a new field
%     'funcSlice' to the anatomical struct and saves it back to 'anatomic.mat'.
%   - The GUI can be closed using the 'Close' button.
%
% OUTPUTS:
%   anatomic - Struct containing the original anatomical data, with the additional field:
%       .funcSlice  -> Selected slice index along each dimension
%
% REQUIREMENTS:
%   - The selected folder must contain 'anatomic.mat' and 'Transformation.mat'.
%   - No additional dependencies.
%
% NOTES:
%   - If required files are missing, the function prints warnings and exits gracefully.
%   - The anatomical image is displayed with 'hot' colormap and axis scaled equally.
%   - The GUI blocks MATLAB execution until it is closed (uiwait).
%
% EXAMPLE:
%   % Select folder and open GUI to choose slice:
%   anatomic = Select_Anatomical_Slice;
%
%   % After choosing a slice and pressing 'Save', the struct now contains:
%   disp(anatomic.funcSlice);
%
% DEPENDENCIES: None
%
% SEE ALSO:
%   uigetdir, imagesc, msgbox


% NB: this script was refactored from the checkAnatomical.m in /data08


%% Prompt user to select directory
dataDir = uigetdir('', 'Select folder containing anatomic.mat and Transformation.mat');
if dataDir == 0
    warning('No folder selected. Exiting...');
    return
end

% Check if required files exist
anatomicFile = fullfile(dataDir, 'anatomic.mat');
transFile    = fullfile(dataDir, 'Transformation.mat');

if ~exist(anatomicFile, 'file')
    warning('anatomic.mat not found in the selected folder. Exiting...');
    return
end

if ~exist(transFile, 'file')
    warning('Transformation.mat not found in the selected folder. Exiting...');
    return
end

% Load anatomic
S = load(anatomicFile);
if isfield(S, 'anatomic')
    anatomic = S.anatomic;
else
    warning('The file anatomic.mat does not contain a variable named "anatomic". Exiting...');
    return
end

% Store datapath and savepath if not already present
if ~isfield(anatomic, 'datapath')
    anatomic.datapath = dataDir;
end
if ~isfield(anatomic, 'savepath')
    anatomic.savepath = dataDir;
end

%% Initialize global data for GUI
global gdata
gdata.CP     = ones(2,2); % initial cropping point
gdata.anat   = anatomic.Data;
gdata.fSlice = 1;
gdata.aDim   = 3; % browsing along 3rd dimension (axial)
gdata.aSlice = round(size(anatomic.Data)./2); % start from middle slice

%% Load motor/scan info if available
try
    if exist([anatomic.datapath filesep 'MotorScan.csv'],'file')
        D = dir([anatomic.datapath filesep 'MotorScan.csv']);
        MotorInfo = readmatrix([D.folder filesep D.name]);
        gdata.motorLoc = [MotorInfo(1,5)-diff(MotorInfo(1:2,5)); MotorInfo(:,5)];
    elseif exist([anatomic.datapath filesep 'Scan.csv'],'file')
        D = dir([anatomic.datapath filesep 'Scan.csv']);
        MotorInfo = readmatrix([D.folder filesep D.name]);
        gdata.motorLoc = [MotorInfo(1,2)-diff(MotorInfo(1:2,2)); MotorInfo(:,2)];
    end
catch
    warning('No Motor movement information!')
end

%% Create GUI
hf = figure('Units','normalized','Position',[0.1 0.2 0.5 0.6], ...
            'Name','Check Anatomical','NumberTitle','off');
hanat = axes(hf);

% Show middle slice with proper formatting
gdata.hanat = imagesc(hanat,squeeze(gdata.anat(:,:,gdata.aSlice(gdata.aDim))));
axis(hanat,'equal','tight');
colormap(hanat,'hot');

% Title label
uicontrol(hf,'style','text', ...
    'units','normalized', ...
    'String','Anatomical', ...
    'FontSize',16, ...
    'position',[0.25 0.94 0.08 0.04]);

% Slice navigation buttons
uicontrol(hf,'style','pushbutton', ...
    'units','normalized', ...
    'String','Slice-', ...
    'position',[0.16 0.94 0.06 0.04], ...
    'callback',@SwitchAnatSlice);

uicontrol(hf,'style','pushbutton', ...
    'units','normalized', ...
    'String','Slice+', ...
    'position',[0.36 0.94 0.06 0.04], ...
    'callback',@SwitchAnatSlice);

% Display current motor location
gdata.anatLocButton = uicontrol(hf,'style','text', ...
    'units','normalized', ...
    'String',['Current Location: ' num2str(gdata.motorLoc(gdata.aSlice(3)))], ...
    'FontSize',16, ...
    'position',[0.5 0.94 0.3 0.04]);

% Save button
uicontrol(hf,'style','pushbutton', ...
    'units','normalized', ...
    'String','Save', ...
    'position',[0.7 0.02 0.1 0.05], ...
    'callback',{@SaveAnat,anatomic});

% Close button
uicontrol(hf,'style','pushbutton', ...
    'units','normalized', ...
    'String','Close', ...
    'position',[0.82 0.02 0.1 0.05], ...
    'callback',@(src,evt) close(hf));

%% Pause until figure is closed
uiwait(hf)

clear global

end


%% --- Callback: Switch slice ---
function SwitchAnatSlice(~,~)
global gdata

if strcmp(get(gco,'String'),'Slice+')
    gdata.aSlice(gdata.aDim) = min([gdata.aSlice(gdata.aDim)+1, size(gdata.anat,gdata.aDim)]);
elseif strcmp(get(gco,'String'),'Slice-')
    gdata.aSlice(gdata.aDim) = max([gdata.aSlice(gdata.aDim)-1, 1]);
end

% Update displayed image
set(gdata.hanat,'CData',squeeze(gdata.anat(:,:,gdata.aSlice(gdata.aDim))));

% Update location label
set(gdata.anatLocButton,'String', ...
    ['Current Location: ' num2str(gdata.motorLoc(gdata.aSlice(3)))]);

end


%% --- Callback: Save anatomical struct ---
function SaveAnat(~,~,anatomic)
global gdata

disp('Saving anatomical scan...')

% Add chosen slice
anatomic.funcSlice = gdata.aSlice;

% Save struct back to file
save([anatomic.savepath filesep 'anatomic.mat'],'anatomic');

% Show confirmation with slice + path (monospace font)
msg = sprintf('funcSlice: [%s]\n\nSaved at:\n%s', ...
              num2str(anatomic.funcSlice), anatomic.savepath);
h = msgbox(msg,'Save Successful');

% Make text monospace
txt = findobj(h,'Type','Text');
set(txt,'FontName','Courier');

disp(['Anatomical scan is saved at: ' anatomic.savepath filesep 'anatomic.mat'])
end
