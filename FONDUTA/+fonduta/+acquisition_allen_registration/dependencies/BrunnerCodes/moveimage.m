% internal class to move an image with the mause. 

classdef moveimage < handle
    
   properties
        a            % original image
        at           % moved image data
        Trans        % affine transformation    
   end
    
   properties(Access=protected )
        T0
        v0
        draw
        himage
        figure
        flagmove
        axes
        ref
   end
    
    methods  
        function M=moveimage(axes,draw)
            if nargin==2
              M.draw=draw;  % if draw==0 it sends a notify but does not draw image
            end
            
            M.himage=searchImageInChildren(axes);
            M.figure=axes.Parent;
            M.axes=axes;
            M.a=M.himage.CData;
                       
            M.ref= imref2d(size(M.a));
            
            M.T0=eye(3);
            M.Trans=eye(3);
            M.v0=zeros(1,2);
                       
            M.flagmove=0;
            set(M.himage,'ButtonDownFcn',{@startrotation, M});
        end
             
    end
    
    events
        movementDone
    end
    
 
end

% sets the callbacks of the mause to start rotation-translation
function startrotation(~,~, M)
set (M.figure, 'WindowButtonUpFcn',    {@mouseUp,     M});
set (M.figure, 'WindowButtonDownFcn',  {@mouseDown,   M});
set (M.figure, 'WindowButtonMotionFcn',{@mouseMove,   M});
set (M.figure, 'Pointer','hand');
end


% callbacks mouse functions
function mouseUp (~,~,M)
M.flagmove=0;     % disable movement
M.T0=M.Trans; 
M.v0=zeros(1,2);
end

% set callbacks of the mouse to stops rotation-translation 
function mouseDown (~,~, M)
C0 = get (M.axes, 'CurrentPoint');
if isPointerInAxis(M.axes) 
   M.v0=C0(1,1:2);
   M.flagmove=1;  %enable movement
else
  set (M.figure, 'WindowButtonUpFcn',    '');
  set (M.figure, 'WindowButtonDownFcn',  '');
  set (M.figure, 'WindowButtonMotionFcn','');
  set (M.figure, 'Pointer','arrow');
end
end

% call at each movement of the mouse
function mouseMove (~,~, M)

% detect if the mouse is moving inside the figure
if(isPointerInAxis(M.axes))
    set (M.figure,'Pointer','hand');
else
    set (M.figure, 'WindowButtonUpFcn',    '');
    set (M.figure, 'WindowButtonDownFcn',  '');
    set (M.figure, 'WindowButtonMotionFcn','');
    set (M.figure, 'Pointer','arrow'); 
end

% if movement is activate drag the image
if  M.flagmove==1
    C0 = get (gca, 'CurrentPoint');
    v1=C0(1,1:2);
    
    if strcmp( M.figure.SelectionType,'alt')      %  right button = rotation
        tmp0=M.v0(1)+sqrt(-1)*M.v0(2);
        tmp1=v1(1)-sqrt(-1)*v1(2);
        alfa=angle(tmp0*tmp1)*180/pi;
        T1=rotz(alfa);
    else                                          % left button = translatin
        dv=v1-M.v0;
        T1=eye(3); T1(3,1:2)=dv;
    end
    
    M.Trans=M.T0*T1;                              % Accumulative transformation
    
    if M.draw==1
       M.himage.CData=M.at;
       m=affine2d(M.Trans);
       M.at=imwarp(M.a,m,'OutputView',M.ref); 
    end
    M.notify('movementDone');   
end
end

% auxiliar functions 
function h=searchImageInChildren(axes)
isit=0; 
for i=1:length(axes.Children)
     if isa(axes.Children(i),'matlab.graphics.primitive.Image')       
        isit=i;
     end
end
if isit==0
   error('no image in children of this axis');
end
h=axes.Children(isit);
end


% detect if the pointer is inside the figure area
function a=isPointerInAxis(axes)
 C0 = get (axes, 'CurrentPoint');  
 a= C0(1,1)>axes.XLim(1) && C0(1,1)<axes.XLim(2) && C0(1,2)>axes.YLim(1) && C0(1,2)<axes.YLim(2);
end

