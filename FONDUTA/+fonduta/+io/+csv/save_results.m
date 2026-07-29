function save_results(resultPath, resultFolder, isub, glmresult)
% fonduta.io.csv.save_results  Save per-session GLM results to disk.
%
% [STUB — to be implemented]
%
% Identical in interface to fonduta.io.datapath.save_results, but intended
% for use in CSV-based workflows.
%
% See also: fonduta.io.csv.get_paths, fonduta.io.csv.load_session,
%           fonduta.io.datapath.save_results

    % Delegate to the same implementation for now
    fonduta.io.datapath.save_results(resultPath, resultFolder, isub, glmresult);

end
