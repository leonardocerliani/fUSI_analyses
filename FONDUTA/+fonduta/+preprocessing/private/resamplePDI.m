function PDI = resamplePDI(PDI,frequency)
% resample PDI data to a desired sampling frequency

oldtime = PDI.time;
PDI.time = min(PDI.time):1/frequency:max(PDI.time);
PDI.PDI(isnan(PDI.PDI))=0;
PDIres = interp1(oldtime,permute(PDI.PDI,[3,1,2]),PDI.time);
PDI.PDI = permute(PDIres,[2,3,1]);

% resample running speed to the same frequency
% wheelInfo = [];
% wheelInfo.time = PDI.time;
% wheelInfo.wheelspeed = interp1(PDI.wheelInfo.time,PDI.wheelInfo.wheelspeed,PDI.time);
% PDI.wheelInfoRS = wheelInfo;

% resample envelope of g sensor activity to the same frequency
% gsensorInfo = [];
% gsensorInfo.time = PDI.time;
% gsensorInfo.x = interp1(PDI.gsensorInfo.time,PDI.gsensorInfo.x,PDI.time);
% gsensorInfo.y = interp1(PDI.gsensorInfo.time,PDI.gsensorInfo.y,PDI.time);
% gsensorInfo.z = interp1(PDI.gsensorInfo.time,PDI.gsensorInfo.z,PDI.time);
% PDI.gsensorInfoRS = gsensorInfo;

% resample envelope of g sensor activity to the same frequency
% if isfield(PDI,'pupil')
%     PDI.pupil.pupilTime = interp1(PDI.pupil.pupilTime,PDI.pupil.pupilSize,PDI.time);
% end