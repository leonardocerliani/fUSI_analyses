function [subDataPath, subAnatPath, resultPath] = get_paths(csvFile, cond)
% fonduta.io.csv.get_paths  Resolve session paths from a CSV file.
%
% [STUB — to be implemented]
%
% Reads a CSV file that maps experimental conditions to session data paths,
% anatomy paths, and result directories.
%
% Inputs:
%   csvFile - full path to the CSV file (string)
%   cond    - string specifying the condition to extract
%
% Outputs:
%   subDataPath - {N x 1} cell array of session data folders
%   subAnatPath - {N x 1} cell array of corresponding anatomy folders
%   resultPath  - string, base output directory for this condition
%
% Expected CSV columns:
%   condition, dataPath, anatPath, resultPath
%
% See also: fonduta.io.csv.load_session, fonduta.io.csv.save_results

    error('fonduta:io:csv:get_paths:NotImplemented', ...
          'fonduta.io.csv.get_paths is not yet implemented.');

    % TODO: implement CSV parsing
    % T          = readtable(csvFile);
    % idx        = strcmp(T.condition, cond);
    % subDataPath = T.dataPath(idx);
    % subAnatPath = T.anatPath(idx);
    % resultPath  = T.resultPath{find(idx, 1)};

end
