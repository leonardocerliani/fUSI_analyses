function save_results(resultPath, resultFolder, isub, glmresult)
% fonduta.io.datapath.save_results  Save per-session GLM results to disk.
%
% Creates the output folder if it does not exist, then saves the glmresult
% struct as GLMSes<isub>.mat using parsave (safe for parfor contexts).
%
% Inputs:
%   resultPath   - base output directory (string), e.g. from fonduta.io.datapath.get_paths()
%   resultFolder - subfolder name for this analysis (string),
%                  e.g. 'GLMVisual_v1'
%   isub         - session index (integer), used to name the output file
%   glmresult    - struct containing all GLM output maps for this session
%
% Output file:
%   <resultPath>/<resultFolder>/GLMSes<isub>.mat
%   Contains variable 'data' (= glmresult). Load with:
%     tmp = load(filepath); glmresult = tmp.data;
%
% See also: fonduta.io.datapath.load_session, fonduta.io.datapath.get_paths

    outDir = fullfile(resultPath, resultFolder);

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    saveName = fullfile(outDir, sprintf('GLMSes%d.mat', isub));
    fonduta.io.parsave(saveName, glmresult);

    fprintf('Saved: %s\n', saveName);

end
