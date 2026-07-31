function save_results(resultPath, resultFolder, dataPath, glmresult)
% fonduta.io.datapath.save_results  Save per-session GLM results to disk.
%
% Creates the output folder if it does not exist, then saves the glmresult
% struct as glm_<runName>.mat, where runName is derived from the last
% non-empty component of dataPath (e.g. "run-142136").
%
% Inputs:
%   resultPath   - base output directory (string)
%   resultFolder - subfolder name for this analysis (string), e.g. 'LC'
%   dataPath     - session data path (string); the last non-empty path
%                  component is used as the run identifier, e.g.:
%                    "/data06/.../run-142136/"  →  filename: glm_run-142136.mat
%   glmresult    - struct containing all GLM output maps for this session
%
% Output file:
%   <resultPath>/<resultFolder>/glm_<runName>.mat
%   Contains variable 'data' (= glmresult). Load with:
%     tmp = load(filepath); glmresult = tmp.data;
%
% See also: fonduta.io.datapath.load_session

    % Extract run identifier from the last non-empty component of dataPath
    parts   = strsplit(dataPath, '/');
    parts   = parts(~cellfun(@isempty, parts));   % remove empty strings from trailing /
    runName = parts{end};                          % e.g. "run-142136"

    outDir   = fullfile(resultPath, resultFolder);
    saveName = fullfile(outDir, sprintf('glm_%s.mat', runName));

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fonduta.io.parsave(saveName, glmresult);

    fprintf('Saved: %s\n', saveName);

end
