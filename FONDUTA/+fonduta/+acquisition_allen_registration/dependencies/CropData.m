
global gdata

try
    gdata.origData = anatomic.Data;
    gdata.cropData = anatomic.Data;
    gdata.Direction = anatomic.Direction;
    gdata.cSlice = round(size(anatomic.Data)./2);
catch
    gdata.origData = PDI.PDI;
    gdata.cropData = PDI.PDI;
    gdata.Direction = 'not-applicable';
    gdata.cSlice = round(size(PDI.PDI)./2);
end
gdata.CP = ones(2,2); % intial cropping point
gdata.cDim = 3;
gdata.cropWin = [];

hf = figure('Units','normalized','Position',[0.25 0.25 0.5 0.6]);
haxis = axes(hf,'NextPlot','replace');
gdata.hi = imagesc(squeeze(gdata.origData(:,:,gdata.cSlice(gdata.cDim))));
gdata.hi.PickableParts = 'none';
haxis.ButtonDownFcn = @SelectRegion;

axis(haxis,'square')

xlim(haxis,[1 size(gdata.cropData,2)])
ylim(haxis,[1 size(gdata.cropData,1)])

dim1Button = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Dim1', ...
    'position',[0.2 0.94 0.04 0.04],...
    'callback',@SelectDim);

dim2Button = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Dim2', ...
    'position',[0.25 0.94 0.04 0.04],...
    'callback',@SelectDim);

dim3Button = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Dim3', ...
    'position',[0.3 0.94 0.04 0.04],...
    'callback',@SelectDim);

slicemButton = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Slice-', ...
    'position',[0.4 0.94 0.08 0.04],...
    'callback',@SwitchSlice);

slicepButton = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Slice+', ...
    'position',[0.5 0.94 0.08 0.04],...
    'callback',@SwitchSlice);

cropButton = uicontrol(hf,'style','pushbutton', ...
    'units', 'normalized', ...
    'String','Crop', ...
    'position',[0.6 0.94 0.05 0.04],...
    'callback',@CropImage);

directionEdit = uicontrol(hf,'style','edit', ...
    'units', 'normalized', ...
    'String',gdata.Direction, ...
    'position',[0.7 0.94 0.06 0.04],...
    'callback',@EditDirection);

uiwait(hf)

if isempty(gdata.cropWin)
    gdata.cropWin = [1,1;size(gdata.origData,2),size(gdata.origData,1)];
else
    pdimask = ones(size(gdata.origData,2),size(gdata.origData,1));
    pdimask(min(gdata.cropWin(:,2)):max(gdata.cropWin(:,2)), ...
        min(gdata.cropWin(:,1)):max(gdata.cropWin(:,1))) = 0;
    
    for it = 1:size(gdata.origData,3)
        tmppdi = gdata.origData(:,:,it);
        PDI.outPDI(it) = mean(tmppdi(logical(pdimask)));
    end
    
end

%% callback functions
function SelectRegion(~,~)
global gdata

gdata.CP(1,:) = gdata.CP(2,:);
tmpPt= round(get(gca,'CurrentPoint'));
gdata.CP(2,:) = tmpPt(1,1:2);

if isfield(gdata,'hline')
    delete(gdata.hline)
end
hold on
gdata.hline(1) = plot([gdata.CP(1,1),gdata.CP(1,1)],[gdata.CP(1,2),gdata.CP(2,2)],'k','LineWidth',2);
gdata.hline(2) = plot([gdata.CP(2,1),gdata.CP(2,1)],[gdata.CP(1,2),gdata.CP(2,2)],'k','LineWidth',2);
gdata.hline(3) = plot([gdata.CP(1,1),gdata.CP(2,1)],[gdata.CP(1,2),gdata.CP(1,2)],'k','LineWidth',2);
gdata.hline(4) = plot([gdata.CP(1,1),gdata.CP(2,1)],[gdata.CP(2,2),gdata.CP(2,2)],'k','LineWidth',2);
hold off
end


function SwitchSlice(~,~)
global gdata

switch gdata.cDim
    case 1
        if strcmp(get(gco,'String'),'Slice+')
            gdata.cSlice(gdata.cDim) = min([gdata.cSlice(gdata.cDim)+1,size(gdata.cropData,gdata.cDim)]);
            
        elseif strcmp(get(gco,'String'),'Slice-')
            gdata.cSlice(gdata.cDim) = max([gdata.cSlice(gdata.cDim)-1,1]);
        end
        set(gdata.hi,'CData',squeeze(gdata.cropData(gdata.cSlice(gdata.cDim),:,:)));
    case 2
        if strcmp(get(gco,'String'),'Slice+')
            gdata.cSlice(gdata.cDim) = min([gdata.cSlice(gdata.cDim)+1,size(gdata.cropData,gdata.cDim)]);
            
        elseif strcmp(get(gco,'String'),'Slice-')
            gdata.cSlice(gdata.cDim) = max([gdata.cSlice(gdata.cDim)-1,1]);
        end
        set(gdata.hi,'CData',squeeze(gdata.cropData(:,gdata.cSlice(gdata.cDim),:)));
    case 3
        if strcmp(get(gco,'String'),'Slice+')
            gdata.cSlice(gdata.cDim) = min([gdata.cSlice(gdata.cDim)+1,size(gdata.cropData,gdata.cDim)]);
            
        elseif strcmp(get(gco,'String'),'Slice-')
            gdata.cSlice(gdata.cDim) = max([gdata.cSlice(gdata.cDim)-1,1]);
        end
        set(gdata.hi,'CData',squeeze(gdata.cropData(:,:,gdata.cSlice(gdata.cDim))));
end
end

function SelectDim(~,~)
global gdata
gdata.cropData = gdata.origData;
gdata.cropWin = [];

switch get(gco,'String')
    
    case 'Dim1'
        gdata.cDim = 1;
        set(gdata.hi,'CData',squeeze(gdata.cropData(gdata.cSlice(gdata.cDim),:,:)));
    case 'Dim2'
        gdata.cDim = 2;
        set(gdata.hi,'CData',squeeze(gdata.cropData(:,gdata.cSlice(gdata.cDim),:)));
    case 'Dim3'
        gdata.cDim = 3;
        set(gdata.hi,'CData',squeeze(gdata.cropData(:,:,gdata.cSlice(gdata.cDim))));
        
        
end

end


function CropImage(~,~)
global gdata

if ~isempty(gdata.cropWin)
    warndlg('Only One crop window was allowed, press dim to reset crop window')
    return
end

if isfield(gdata,'hline')
    delete(gdata.hline)
end

switch gdata.cDim
    
    case 1
        if all(gdata.CP(:,1)<=size(gdata.cropData,3) & gdata.CP(:,1)>=1 & ...
                gdata.CP(:,2)<=size(gdata.cropData,2) & gdata.CP(:,2)>=1)
            gdata.cropData = gdata.cropData(:,min(gdata.CP(:,2)):max(gdata.CP(:,2)),min(gdata.CP(:,1)):max(gdata.CP(:,1)));
            set(gdata.hi,'CData',squeeze(gdata.cropData(gdata.cSlice(gdata.cDim),:,:)));
            gdata.cropWin = gdata.CP;
        else
            errordlg('Wrong cropping window!')
        end
    case 2
        if all(gdata.CP(:,1)<=size(gdata.cropData,3) & gdata.CP(:,1)>=1 & ...
                gdata.CP(:,2)<=size(gdata.cropData,1) & gdata.CP(:,2)>=1)
            gdata.cropData = gdata.cropData(min(gdata.CP(:,2)):max(gdata.CP(:,2)),:,min(gdata.CP(:,1)):max(gdata.CP(:,1)));
            set(gdata.hi,'CData',squeeze(gdata.cropData(:,gdata.cSlice(gdata.cDim),:)));
            gdata.cropWin = gdata.CP;
        else
            errordlg('Wrong cropping window!')
        end

    case 3
                if all(gdata.CP(:,1)<=size(gdata.cropData,2) & gdata.CP(:,1)>=1 & ...
                gdata.CP(:,2)<=size(gdata.cropData,1) & gdata.CP(:,2)>=1)
            gdata.cropData = gdata.cropData(min(gdata.CP(:,2)):max(gdata.CP(:,2)),min(gdata.CP(:,1)):max(gdata.CP(:,1)),:);
            set(gdata.hi,'CData',squeeze(gdata.cropData(:,:,gdata.cSlice(gdata.cDim))));
            gdata.cropWin = gdata.CP;

        else
            errordlg('Wrong cropping window!')
                end

end

end



function EditDirection(hObject,~)
global gdata

gdata.Direction = get(hObject,'String');

end