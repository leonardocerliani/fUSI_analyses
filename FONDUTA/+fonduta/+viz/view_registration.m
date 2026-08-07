function view_registration(atlas, image)
%VIEW_REGISTRATION Interactive atlas registration viewer (coronal only).
%
%   fonduta.viz.view_registration(atlas, image)
%
%   Displays:
%       Left  : atlas
%       Right : registered image
%
%   Both volumes must already be in the same voxel space.
%
%   Controls:
%       Mouse click  : move crosshair
%       Mouse wheel  : change coronal slice
%
%   Atlas modes:
%       Histology
%       Vascular
%       Regions
%
%   Region boundaries can be toggled ON/OFF.


%% Initial settings

atlasType = 'Histology';
atlasData = atlas.Histology;

showRegions = true;

crosshair = round(size(image)/2);

slice = crosshair(2);


%% Figure

fig = figure(...
    'Name','Registration Viewer',...
    'Position',[100 100 1600 900],...
    'Color','w',...
    'DefaultAxesFontSize',16,...
    'WindowScrollWheelFcn',@scrollCallback,...
    'WindowButtonDownFcn',@clickCallback);



axLeft = axes(fig,...
    'Position',[0.02 0.18 0.46 0.75]);

axRight = axes(fig,...
    'Position',[0.52 0.18 0.46 0.75]);



%% Controls

bg = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.02 0.05 0.35 0.06],...
    'SelectionChangedFcn',@atlasSelection);


uicontrol(bg,...
    'Style','radiobutton',...
    'String','Histology',...
    'Units','normalized',...
    'Position',[0 0 1/3 1],...
    'FontSize',14);


uicontrol(bg,...
    'Style','radiobutton',...
    'String','Vascular',...
    'Units','normalized',...
    'Position',[1/3 0 1/3 1],...
    'FontSize',14);


uicontrol(bg,...
    'Style','radiobutton',...
    'String','Regions',...
    'Units','normalized',...
    'Position',[2/3 0 1/3 1],...
    'FontSize',14);



bgLines = uibuttongroup(fig,...
    'Units','normalized',...
    'Position',[0.40 0.05 0.25 0.06],...
    'SelectionChangedFcn',@lineSelection);


uicontrol(bgLines,...
    'Style','radiobutton',...
    'String','Lines ON',...
    'Units','normalized',...
    'Position',[0 0 0.5 1],...
    'Value',1,...
    'FontSize',14);


uicontrol(bgLines,...
    'Style','radiobutton',...
    'String','Lines OFF',...
    'Units','normalized',...
    'Position',[0.5 0 0.5 1],...
    'FontSize',14);



txt = uicontrol(fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[0.02 0.12 0.96 0.05],...
    'BackgroundColor','w',...
    'FontSize',18,...
    'HorizontalAlignment','left');



%% Images

leftImage = imagesc(axLeft,extractSlice(atlasData));
rightImage = imagesc(axRight,extractSlice(image));


axis(axLeft,'image')
axis(axRight,'image')

axis(axLeft,'off')
axis(axRight,'off')


colormap(axLeft,gray)
colormap(axRight,gray)


hold(axLeft,'on')
hold(axRight,'on')



%% Handles

regionHandlesLeft=[];
regionHandlesRight=[];

crossLeft=[];
crossRight=[];



updateDisplay();



%% ============================================================
% CALLBACKS
% ============================================================


function scrollCallback(~,event)

    slice = slice + event.VerticalScrollCount;

    slice=max(1,min(slice,size(image,2)));

    crosshair(2)=slice;

    updateDisplay();

end



function clickCallback(~,~)

    ax = gca;

    cp = ax.CurrentPoint;

    z = round(cp(1,1));   % columns of imagesc = dimension 3
    x = round(cp(1,2));   % rows of imagesc    = dimension 1

    if x < 1 || z < 1
        return
    end

    crosshair = [x slice z];

    updateDisplay();

end



function atlasSelection(~,event)


    atlasType=event.NewValue.String;


    switch atlasType

        case 'Histology'
            atlasData=atlas.Histology;

        case 'Vascular'
            atlasData=atlas.Vascular;

        case 'Regions'
            atlasData=atlas.Regions;

    end


    updateDisplay();

end



function lineSelection(~,event)

    showRegions=strcmp(event.NewValue.String,'Lines ON');

    updateDisplay();

end



%% ============================================================
% DISPLAY
% ============================================================


function updateDisplay()


    leftImage.CData=extractSlice(atlasData);
    rightImage.CData=extractSlice(image);

    switch atlasType

        case 'Regions'

            colormap(axLeft,atlas.infoRegions.rgb)

            caxis(axLeft,[1 509])

            leftImage.Interpolation='nearest';


        case 'Histology'

            colormap(axLeft,gray)

            caxis(axLeft,...
                [double(min(atlas.Histology(:))) ...
                double(max(atlas.Histology(:)))])


        case 'Vascular'

            colormap(axLeft,gray)

            % better for vascular maps:
            clim = prctile(atlas.Vascular(:),[1 99]);

            caxis(axLeft,clim)

    end


    colormap(axRight,gray)



    updateRegionLines();

    updateCrosshair();

    updateRegionInfo();


    drawnow;

end



%% ============================================================
% REGION LINES
% ============================================================


function updateRegionLines()


    delete(regionHandlesLeft)
    delete(regionHandlesRight)


    regionHandlesLeft=[];
    regionHandlesRight=[];


    if ~showRegions
        return
    end



    L=atlas.Lines.Cor{slice};



    for i=1:length(L)

        xy=L{i};


        regionHandlesLeft(end+1)=plot(axLeft,...
            xy(:,2),...
            xy(:,1),...
            'w',...
            'LineWidth',1);


        regionHandlesRight(end+1)=plot(axRight,...
            xy(:,2),...
            xy(:,1),...
            'w',...
            'LineWidth',1);

    end

end



%% ============================================================
% CROSSHAIR
% ============================================================


function updateCrosshair()

    delete(crossLeft)
    delete(crossRight)

    crossLeft=[];
    crossRight=[];


    % voxel coordinates
    x = crosshair(1);   % dimension 1 (rows)
    z = crosshair(3);   % dimension 3 (columns)


    % vertical line: display column = voxel z
    % horizontal line: display row = voxel x

    crossLeft(1)=xline(axLeft,z,...
        'r','LineWidth',1.5);

    crossLeft(2)=yline(axLeft,x,...
        'r','LineWidth',1.5);


    crossRight(1)=xline(axRight,z,...
        'r','LineWidth',1.5);

    crossRight(2)=yline(axRight,x,...
        'r','LineWidth',1.5);

end



%% ============================================================
% REGION INFORMATION
% ============================================================


function updateRegionInfo()

    voxelText = sprintf('Voxel [%d %d %d]',crosshair);

    regionText = '';


    % check voxel is inside atlas
    inside = ...
        crosshair(1)>=1 && crosshair(1)<=size(atlas.Regions,1) && ...
        crosshair(2)>=1 && crosshair(2)<=size(atlas.Regions,2) && ...
        crosshair(3)>=1 && crosshair(3)<=size(atlas.Regions,3);


    if inside

        label = double(atlas.Regions(...
            crosshair(1),...
            crosshair(2),...
            crosshair(3)));


        % atlas regions are 1-509, background is 0
        if label > 0 && label <= numel(atlas.infoRegions.acr)

            acr  = atlas.infoRegions.acr{label};
            name = atlas.infoRegions.name{label};

            regionText = sprintf(...
                '    ID: %d    %s: %s',...
                label,...
                acr,...
                name);

        else

            regionText = '    Background';

        end

    end


    txt.String = [voxelText regionText];


end



%% ============================================================
% SLICE EXTRACTION
% ============================================================


function sliceImg=extractSlice(vol)

    sliceImg=squeeze(vol(:,slice,:));

end


end