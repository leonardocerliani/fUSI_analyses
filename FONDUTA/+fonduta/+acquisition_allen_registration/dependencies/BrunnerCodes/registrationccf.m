% Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Mace Lab  - Max Planck institute of Neurobiology
% Authors:  G. MONTALDO, E. MACE
% Review & test: C.BRUNNER, M. GRILLET
% March 2021
%
% Graphic interphase to register with the atlas.
%
%   registrationccf(atlas,scananatomy)
%   registrationccf(atlas,scananatomy, initialTransf)
%   atlas,          atlas structure  
%   scananatomy,    fus-structure of type volume
%   initialTrasf,   optional starting transformation (from aprevious execution of registrationccf)
%   
%   output:  a structure Trasf is saved in file Trasformation.mat 
%
% example: example01_registering
%%

classdef registrationccf < handle
    
    
    properties 
       fileName 
       T0
    end
    
    properties (Access=protected)
        H
        ms1
        ms2
        scale0
        scale
        r1
        r2
        r3
       
        atlas 
        x0
        y0
        z0
        nx
        ny
        nz
        colorComp
        colorData
 
        im1
        im2
        im3
        im4
        im5
        im6
        im4b
        im5b
        im6b
        line1x
        line1y
        line2x
        line2y
        line3x
        line3y
        line4x
        line4y
        line5x
        line5y
        line6x
        line6y
        linmap
        hlinesS
        hlinesC
        hlinesT
    end
    
    methods
        function R=registrationccf(atlas,scananatomy, initialTransf)
            
            % initial rotation
            if nargin==3
                R.T0=initialTransf.M;
                R.scale0=initialTransf.scale;
                R.scale=initialTransf.scale;
            else
                R.T0=eye(4); 
                R.scale0=ones(3,1);
                R.scale=ones(3,1);
            end
            
            try
            R.fileName=[scananatomy.savepath filesep 'Transformation']; %new name
            catch
                R.fileName=['Transformation']; %default name
            end
            R.atlas=atlas;
            [R.nx,R.ny,R.nz]=size(R.atlas.Histology);
            
            % equalize images
            scananatomy.Data=equalizeImages(scananatomy.Data);
            tmp=interpolate3D(atlas,scananatomy);
            % stupid method to have the same size eliminate
            m=affine3d(eye(4));
            ref=imref3d([R.nx,R.ny,R.nz]);
            R.ms2=imwarp(tmp.Data,m,'OutputView',ref);
            R.colorData.method='fix';
            R.colorData.cmap=hot(128);
            R.colorData.caxis=[median(scananatomy.Data(:)) max(scananatomy.Data(:))]; 
            
            R.H=guihandles(open('figviewscan.fig'));  % load GUI figure
             
            R.x0=round(R.nx/2);
            R.y0=round(R.ny/2);
            R.z0=round(R.nz/2);
            
            % set sliders
            R.H.slider1.Min=1;
            R.H.slider2.Min=1;
            R.H.slider3.Min=1;
            R.H.slider1.Max=R.nx;
            R.H.slider2.Max=R.ny;
            R.H.slider3.Max=R.nz;
            R.H.slider1.Value=R.x0;
            R.H.slider2.Value=R.y0;
            R.H.slider3.Value=R.z0;
            R.H.edit1.String=num2str(R.x0);      % set planes
            R.H.edit2.String=num2str(R.y0);
            R.H.edit3.String=num2str(R.z0);
            R.H.caxis.String=num2str(R.colorData.caxis);
            
            % set scale 
            R.H.scaleY.String=num2str(R.scale(1));
            R.H.scaleX.String=num2str(R.scale(2));
            R.H.scaleZ.String=num2str(R.scale(3));
            
            R.H.colormap.String='hot';              % set defoult colormap
            
            % create and init images to 0 in axes
            R.im1=imagesc(zeros(R.nx,R.nz),'parent',R.H.axes1);
            R.im2=imagesc(zeros(R.nx,R.ny),'parent',R.H.axes2);
            R.im3=imagesc(zeros(R.ny,R.nz),'parent',R.H.axes3);
            R.im4=imagesc(zeros(R.nx,R.nz),'parent',R.H.axes4);
            R.im5=imagesc(zeros(R.nx,R.ny),'parent',R.H.axes5);
            R.im6=imagesc(zeros(R.ny,R.nz),'parent',R.H.axes6);
            % creat overlay on the moving figure
            R.H.axes4b = copyobj(R.H.axes4,R.H.figure1);
            R.H.axes5b = copyobj(R.H.axes5,R.H.figure1);
            R.H.axes6b = copyobj(R.H.axes6,R.H.figure1);
            R.im4b=imagesc(zeros(R.nx,R.nz),'parent',R.H.axes4b);
            R.im5b=imagesc(zeros(R.nx,R.ny),'parent',R.H.axes5b);
            R.im6b=imagesc(zeros(R.ny,R.nz),'parent',R.H.axes6b);
            linkaxes([R.H.axes4b,R.H.axes4])
            R.H.axes4b.Visible = 'off';
            R.H.axes4b.XTick = [];
            R.H.axes4b.YTick = [];
            linkaxes([R.H.axes5b,R.H.axes5])
            R.H.axes5b.Visible = 'off';
            R.H.axes5b.XTick = [];
            R.H.axes5b.YTick = [];
            linkaxes([R.H.axes6b,R.H.axes6])
            R.H.axes6b.Visible = 'off';
            R.H.axes6b.XTick = [];
            R.H.axes6b.YTick = [];
            
            
            axis(R.H.axes1,'equal','tight');
            axis(R.H.axes2,'equal','tight');
            axis(R.H.axes3,'equal','tight');
            axis(R.H.axes4,'equal','tight');
            axis(R.H.axes5,'equal','tight');
            axis(R.H.axes6,'equal','tight');
            axis(R.H.axes4b,'equal','tight');
            axis(R.H.axes5b,'equal','tight');
            axis(R.H.axes6b,'equal','tight');
            
            % lines are created empty and wraw in refresh
            R.line1x= line([0,0],[0,0],'Parent',R.H.axes1,'Color',[1 1 1]);
            R.line1y= line([0,0],[0,0],'Parent',R.H.axes1,'Color',[1 1 1]);
            R.line2x= line([0,0],[0,0],'Parent',R.H.axes2,'Color',[1 1 1]);
            R.line2y= line([0,0],[0,0],'Parent',R.H.axes2,'Color',[1 1 1]);
            R.line3x= line([0,0],[0,0],'Parent',R.H.axes3,'Color',[1 1 1]);
            R.line3y= line([0,0],[0,0],'Parent',R.H.axes3,'Color',[1 1 1]);
            R.line4x= line([0,0],[0,0],'Parent',R.H.axes4b,'Color',[1 1 1]);
            R.line4y= line([0,0],[0,0],'Parent',R.H.axes4b,'Color',[1 1 1]);
            R.line5x= line([0,0],[0,0],'Parent',R.H.axes5b,'Color',[1 1 1]);
            R.line5y= line([0,0],[0,0],'Parent',R.H.axes5b,'Color',[1 1 1]);
            R.line6x= line([0,0],[0,0],'Parent',R.H.axes6b,'Color',[1 1 1]);
            R.line6y= line([0,0],[0,0],'Parent',R.H.axes6b,'Color',[1 1 1]);
            
            
            % set callbacks
            set(R.H.colormap,        'Callback', {@setcolormap,R});
            set(R.H.caxis,           'Callback', {@setcaxis,R});
            set(R.H.slider1,         'Callback', {@readslider, R});
            set(R.H.slider2,         'Callback', {@readslider, R});
            set(R.H.slider3,         'Callback', {@readslider, R});
            set(R.H.edit1,           'Callback', {@readvalues, R});
            set(R.H.edit2,           'Callback', {@readvalues, R});
            set(R.H.edit3,           'Callback', {@readvalues, R});
            set(R.H.colormap,        'Callback', {@colormap, R});
            set(R.H.caxis,           'Callback', {@coloraxis, R});
            set(R.H.scaleX,          'Callback', {@applyRescale,R});
            set(R.H.scaleY,          'Callback', {@applyRescale,R});
            set(R.H.scaleZ,          'Callback', {@applyRescale,R});
            set(R.H.transparency,        'Callback', {@settransparency,R});
            set(R.H.save,            'Callback', {@saveCall, R});
            set(R.H.comparaVascular, 'Callback', {@comparativeAtlas, R,'vascular'});
            set(R.H.comparaHistology,'Callback', {@comparativeAtlas, R,'histology'});
            set(R.H.comparaRegions,  'Callback', {@comparativeAtlas, R,'regions'});
            
            % other inits
            R.linmap=atlas.Lines;
            R.hlinesS=[];
            R.hlinesC=[];
            R.hlinesT=[];
           % R.Trot=eye(4);
            
            % start movement in the images
            R.r1=moveimage(R.H.axes4b,0);
            R.r2=moveimage(R.H.axes5b,0);
            R.r3=moveimage(R.H.axes6b,0);
            addlistener(R.r1,'movementDone', @(src,event)moveDone(src,event,R));
            addlistener(R.r2,'movementDone', @(src,event)moveDone(src,event,R));
            addlistener(R.r3,'movementDone', @(src,event)moveDone(src,event,R));
            
            comparativeAtlas([],[],R,'histology');
            R.refresh();
        end
                
        % refresh all the figure.
        function  refresh(V)
            V.line1x.XData= [0,   V.nz];   V.line1x.YData=[V.x0,V.x0];
            V.line1y.XData= [V.z0,V.z0];   V.line1y.YData=[0,   V.nx];         
            V.line2x.XData= [0,   V.ny];   V.line2x.YData=[V.x0,V.x0];
            V.line2y.XData= [V.y0,V.y0];   V.line2y.YData=[0,   V.nx];
            V.line3x.XData= [0,   V.nz];   V.line3x.YData=[V.y0,V.y0];
            V.line3y.XData= [V.z0,V.z0];   V.line3y.YData=[0,   V.ny];
            V.line4x.XData= [0,   V.nz];   V.line4x.YData=[V.x0,V.x0];
            V.line4y.XData= [V.z0,V.z0];   V.line4y.YData=[0,   V.nx];
            V.line5x.XData= [0,   V.ny];   V.line5x.YData=[V.x0,V.x0];
            V.line5y.XData= [V.y0,V.y0];   V.line5y.YData=[0,   V.nx];
            V.line6x.XData= [0,   V.nz];   V.line6x.YData=[V.y0,V.y0];
            V.line6y.XData= [V.z0,V.z0];   V.line6y.YData=[0,   V.ny];
     
            V.H.slider1.Value=V.x0; V.H.edit1.String=num2str(V.x0);
            V.H.slider2.Value=V.y0; V.H.edit2.String=num2str(V.y0);
            V.H.slider3.Value=V.z0; V.H.edit3.String=num2str(V.z0);
            
            % refresh lines objects
            delete(V.hlinesC);
            delete(V.hlinesT);
            delete(V.hlinesS);
            V.hlinesC=addLines(V.H.axes4b,V.linmap.Cor,V.y0);
            V.hlinesT=addLines(V.H.axes6b,V.linmap.Tra,V.x0);
            V.hlinesS=addLines(V.H.axes5b,V.linmap.Sag,V.z0);
            
            V.im1.CData=rgbfunc(squeeze(V.ms1(:,V.y0,:)),V.colorComp);
            V.im2.CData=rgbfunc(squeeze(V.ms1(:,:,V.z0)),V.colorComp);
            V.im3.CData=rgbfunc(squeeze(V.ms1(V.x0,:,:)),V.colorComp);
            V.im4.CData=rgbfunc(squeeze(V.ms1(:,V.y0,:)),V.colorComp);
            V.im5.CData=rgbfunc(squeeze(V.ms1(:,:,V.z0)),V.colorComp);
            V.im6.CData=rgbfunc(squeeze(V.ms1(V.x0,:,:)),V.colorComp);
            
            moveDone([],[],V);
            drawnow;
        end
    end
end

% changes the atlas to compare (vascular, histology or regions)
function comparativeAtlas(~,~,R,map)
switch map
    case 'histology'
        R.ms1=R.atlas.Histology;
        R.colorComp.method='fix';
        R.colorComp.cmap=gray(256);
        R.colorComp.caxis=[0 256];
    case 'vascular'
        R.ms1=R.atlas.Vascular;
        R.colorComp.method='auto';
        R.colorComp.cmap=gray(128);
        R.colorComp.caxis=[0 128];
    case 'regions'
        R.ms1=R.atlas.Regions;
        R.colorComp.method='index';
        R.colorComp.cmap=R.atlas.infoRegions.rgb;
        R.colorComp.caxis=[0 128];
end
R.refresh();
end

function moveDone(~,~,R)
[nx0,ny0,nz0]=size(R.ms2);
R.ms2(1)=0;

tot=build3DrotationDif(R);
m=affine3d(tot);
[nx,ny,nz]=size(R.ms1);

[Y,X,Z] = meshgrid(R.y0,(1:nx),(1:nz));
convert();
p=reshape(p,[nx,nz]);
R.im4b.CData=rgbfunc(p,R.colorData);

[Y,X,Z] = meshgrid((1:ny),R.x0,(1:nz));
convert();
p=reshape(p,[ny,nz]);
R.im6b.CData=rgbfunc(p,R.colorData);

[Y,X,Z] = meshgrid((1:ny),(1:nx),R.z0);
convert();
p=reshape(p,[nx,ny]);
R.im5b.CData=rgbfunc(p,R.colorData);

alpha(R.H.axes4b,str2num(R.H.transparency.String))
alpha(R.H.axes5b,str2num(R.H.transparency.String))
alpha(R.H.axes6b,str2num(R.H.transparency.String))
            
    function convert()
        [Yt,Xt,Zt]=transformPointsInverse(m,Y,X,Z);
        Xt=round(Xt-1);  Xt(Xt<0)=NaN; Xt(Xt>=nx0)=NaN;
        Yt=round(Yt-1);  Yt(Yt<0)=NaN; Yt(Yt>=ny0)=NaN;
        Zt=round(Zt-1);  Zt(Zt<0)=NaN; Zt(Zt>=nz0)=NaN;
        pos=Xt(:)+nx0*Yt(:)+nx0*ny0*Zt(:)+1;
        pos(isnan(pos))=1; 
        p=R.ms2(pos);
    end
end

% changes colormap
function colormap(h,~,R)
R.colorData.cmap=evalin('base',h.String);
R.refresh();
end

% changest coloraxis
function coloraxis(h, ~,R)
R.colorData.caxis=str2num(h.String);
R.refresh();
end

% rescale
function applyRescale(~, ~,R)
R.scale=[ str2double(get(R.H.scaleY,'String')), str2double(get(R.H.scaleX,'String')),str2double(get(R.H.scaleZ,'String'))] ;
R.refresh();
set (R.H.figure1,'Pointer','arrow');
end

function settransparency(~,~,V)
refresh(V);
end

function saveCall(~,~,R)
Transf.M= build3DrotationDif(R);
Transf.size=[R.nx, R.ny, R.nz];
Transf.VoxelSize=R.atlas.VoxelSize;
Transf.scale=R.scale;
if exist([R.fileName '.mat'],'file')
    movefile([R.fileName '.mat'],[R.fileName datestr(now,30) '.mat'])
    save(R.fileName,'Transf');
    msgbox(['Transformation matrix exist and is backed up, new Transformation matrix is successfully saved to: ' R.fileName])
else
    save(R.fileName,'Transf');
    msgbox(['Transformation matrix is successfully saved to: ' R.fileName])
end

end

function  setcaxis(h, ~,V)
V.caxis=str2double(h.String);
refresh(V);
end

function  setcolormap(h, ~,V)
eval(['tmp=' h.String '(128);']);
V.cmap=tmp;
refresh(V);
end

function  readslider(~, ~,V)
V.x0=round(V.H.slider1.Value);
V.y0=round(V.H.slider2.Value);
V.z0=round(V.H.slider3.Value);
V.refresh();
end

function  readvalues(~, ~,V)
px=round(str2double(V.H.edit1.String));
py=round(str2double(V.H.edit2.String));
pz=round(str2double(V.H.edit3.String));
if px>1 && px<V.nx, V.x0=px; V.x0=px; end
if py>1 && py<V.ny, V.y0=py; V.y0=py; end
if pz>1 && pz<V.nz, V.z0=pz; V.z0=pz; end
refresh(V);
end

%
% auxiliar functions
%


function tot=build3DrotationDif(R)
tot=eye(4);
tot(1,1)=R.scale(1)/R.scale0(1);
tot(2,2)=R.scale(2)/R.scale0(2);
tot(3,3)=R.scale(3)/R.scale0(3);

tmpx=R.r1.Trans; 
tmpx(1:2,1:2)=tmpx(1:2,1:2)'; tmpx(3,1:2)=fliplr(tmpx(3,1:2));
tmp=[ zeros(1,3); tmpx(1:end,:)];
tmp=[ zeros(4,1), tmp(:,1:end)];
tmp(1,1)=1; tot=tot*tmp;


tmpx=R.r2.Trans;
tmp=[tmpx(1:2,:); zeros(1,3); tmpx(3:end,:)];
tmp=[tmp(:,1:2), zeros(4,1), tmp(:,3:end)];
tmp(3,3)=1; tot=tot*tmp;

tmpx=R.r3.Trans;
tmpx(1:2,1:2)=tmpx(1:2,1:2)';  tmpx(3,1:2)=fliplr(tmpx(3,1:2));
tmp=[tmpx(1,:); zeros(1,3); tmpx(2:end,:)];
tmp=[tmp(:,1), zeros(4,1), tmp(:,2:end)];
tmp(2,2)=1; tot=tot*tmp;

tot=R.T0*tot;
   
end

% draw border lines
function h=addLines(ax,LL,ip)
L=LL{ip};
hold(ax,'on');
nb=length(L);
h=gobjects(nb,1);
for ib=1:nb
    x=L{ib};
    h(ib)=plot(ax,x(:,2),x(:,1),'w:');        % change the color trae line etc here!
end
hold(ax,'off');
end


function b=rgbfunc(a,colorstr)
[nx,ny]=size(a);
aa=double(a(:));
method=colorstr.method;
cmap=colorstr.cmap;
caxis=colorstr.caxis;
if strcmp(method,'auto')
    norm=max(aa)-min(aa);
    aa=(aa-min(aa))/norm;
    aa=uint16(round(aa(:)*(length(cmap)-1)+1));
    aa(aa==0)=1;
    b=cmap(aa,:);
    b=reshape(b,nx,ny,3);
elseif strcmp(method,'fix')
    aa=(aa-caxis(1))/(caxis(2)-caxis(1));
    aa=uint16(round(aa(:)*(length(cmap)-1)+1));
    aa(aa<1)=1;
    aa(aa>length(cmap))=length(cmap);
    b=cmap(aa,:);
    b=reshape(b,nx,ny,3);
elseif strcmp(method,'index')
    aa(aa==0)=1;
    b=cmap(abs(aa),:);
    b=reshape(b,nx,ny,3);
else
    error('mapscan unknown rgb method')
end
end


% normalize data for view
function DataNorm=equalizeImages(Data)
% DataNorm=Data-min(Data(:));
% DataNorm=DataNorm./max(DataNorm(:));
% m=median(DataNorm(:));
% comp=-2/log2(m);
% DataNorm=DataNorm.^comp;
% DataNorm=DataNorm-min(DataNorm(:));
% DataNorm=DataNorm./max(DataNorm(:));

% modified by Chaoyi Qin at 20220820
logData = 10 * log(Data+1);

meanPDI = mean(mean(logData,1),2);
DataNorm = logData./repmat(meanPDI,size(logData,1),size(logData,2),1);
end



%        % apply partial rotation to all volume
%         function apply(R)
%             tot=build3DrotationDif(R); % compose 3D partial rotation
%             m=affine3d(tot);
%             ref=imref3d(size(R.ms1.D));
%             dataTransf=imwarp(R.ms2,m,'OutputView',ref);
%             R.im4.CData=squeeze(dataTransf(:,R.y0,:));
%             R.im5.CData=squeeze(dataTransf(:,:,R.z0));
%             R.im6.CData=squeeze(dataTransf(R.x0,:,:));
%             drawnow;
%             pause(2);
%         end

