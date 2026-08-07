
function printRegionList(atlas,namefile)

if nargin==1
sa=atlas.infoRegions;
namefile='atlas';
else
sa=readFileList(namefile,atlas.infoRegions);
end

[~,name,~]=fileparts(namefile);

[acrs,idx]=sort(sa.acr);
names=sa.name(idx);
vols=sa.vol(idx);

fid=fopen([name '_alpha.txt'], 'w+t');
for i=1:length(idx)
    ac='               ';
    ac(1:length(acrs{i}))=acrs{i};
    fprintf(fid,'  %s %4d %6.2f %s\n',ac,idx(i),vols(i),names{i});
end
fclose(fid);

[vols,idx]=sort(sa.vol,'descend');
names=sa.name(idx);
acrs=sa.acr(idx);

fid=fopen([name '_volume.txt'], 'w+t');
for i=1:length(idx)
    ac='               ';
    ac(1:length(acrs{i}))=acrs{i};
    fprintf(fid,'  %s %4d %6.2f %s\n',ac,idx(i),vols(i),names{i});
end
fclose(fid);

% list index
acrs=sa.acr;
names=sa.name;
vols=sa.vol;
fid=fopen([name '_number.txt'], 'w+t');
for i=1:length(vols)
    ac='               ';
    ac(1:length(acrs{i}))=acrs{i};
    fprintf(fid,'  %s %4d %6.2f %s\n',ac,i,vols(i),names{i});
end
fclose(fid);

end
