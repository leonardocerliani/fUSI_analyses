% Alan Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Author: Gabriel MONTALDO
% Review & Test: Clément BRUNNER, Micheline GRILLET
% May 2020

%% Draw the border of the brain regions in coronal, sagittal or transversal planes.
% drawBorders(atlas, orientation, plane)
%   atlas, the Allen Mouse Brain Atlas provided in the 'allen_brain_atlas.mat' file,
%   orientation, a string containing 'coronal', 'sagittal' or 'transversal' indicating the orientation of the section.
%   plane, number of plane to display in the section.
% The edges of the regions from the selected plane are displayed in the current figure. 

% Example: example03_correlation.m

function drawBorders(atlas,orientation,plane)

if    strcmp(orientation,'coronal')
   L=atlas.Lines.Cor{plane}; 
elseif  strcmp(orientation,'sagittal')
   L=atlas.Lines.Sag{plane}; 
elseif strcmp(orientation,'transversal')
   L=atlas.Lines.Tra{plane}; 
else
   error('cut must be: coronal sagittal or transversal')
end

hold on;
nb=length(L);
for ib=1:nb
    x=L{ib};
    plot(x(:,2),x(:,1),'k:');        % change the color of the line
end
hold off
end
