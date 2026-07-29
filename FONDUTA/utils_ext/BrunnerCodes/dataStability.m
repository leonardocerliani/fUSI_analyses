% Urban Lab - NERF empowered by imec, KU Leuven and VIB
% Mace Lab  - Max Planck institute of Neurobiology
% Authors:  G. MONTALDO, E. MACE
% Review & test: C.BRUNNER, M. GRILLET
% September 2020
%
% Test the data stability and sugest a threshold to eliminate outliers
%
%   outliers=dataStability(scanfus)
%       scanfus, fus-structure of type fusvolume.
%
% example: example02_filter_average.m
%%
function outliers=dataStability(scanfus)

[~,~,nz,nt]=size(scanfus.Data);

% average the image and normalize by the median in each plane
% this value must be "stable" during all the acquisition.
s=squeeze(mean(mean(scanfus.Data)));
% for iz=1:nz
%     s(iz,:)=s(iz,:)./median(s(iz,:));
% end
s = s./median(s);
N=nz*nt;

% Important: the movement noise is always > 0 i.e outliers are in the
% positive part of the distribution. We compute the sigma with the low part
% of the distribution that is not affected by the outliers
sNoNoise=s(s<1); 
sigma=sqrt(mean((sNoNoise(:)-1).^2));
% sugest a threshold of 3 sigma
threshold=1+sigma*3;
% compute percent of rejencted images
outliers=s>threshold;
Nrejected=sum( outliers(:));

% histogram 
subplot(3,1,1)
hold on
[ha,hb]=hist(s(:),100);
bar(hb,ha);  
plot(hb, exp(-0.5*((hb-1)/sigma).^2)*(N-Nrejected)*(hb(2)-hb(1))/(sigma*sqrt(2*pi)) )
plot([threshold threshold],[0 max(ha)/2],'r');
txt=sprintf(' Threshold: %.1f\n Rejection: %.1f%%',threshold,Nrejected/N*100);
text(double(threshold),max(ha)/2.3,txt)
title('Intensity distribution');
xlabel('Normalized intensity');
ylabel('Number of images')
hold off

% outliers position
subplot(3,1,2)
hold on
% imagesc(scanfus.time,1,(1-outliers)'); colormap(gray);
Ls = bwconncomp(outliers,4); %?connected regions.
ylimit = get(gca,'ylim');
for ie = 1:numel(Ls.PixelIdxList)
    tmpPixelInd = Ls.PixelIdxList{ie};
    if numel(tmpPixelInd)>=1
        hArea(ie) = area([scanfus.time(min(tmpPixelInd)-1) scanfus.time(max(tmpPixelInd)+1)],[ylimit(2) ylimit(2)],ylimit(1),...
            'FaceAlpha',1,'FaceColor',0.5*ones(1,3));
    end
end
xlim([0 max(scanfus.time)])
title('Rejected images');
xlabel('time');
ylabel('planes')
end