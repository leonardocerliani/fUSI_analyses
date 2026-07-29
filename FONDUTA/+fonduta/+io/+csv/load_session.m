function [PDI, anatomic, Transf] = load_session(dataPath, anatPath)
% fonduta.io.csv.load_session  Load functional data, anatomy and registration for one session.
%
% [STUB — to be implemented]
%
% Identical in interface to fonduta.io.datapath.load_session, but intended
% for use in CSV-based workflows where paths come from fonduta.io.csv.get_paths.
%
% See also: fonduta.io.csv.get_paths, fonduta.io.csv.save_results,
%           fonduta.io.datapath.load_session

    % Delegate to the same implementation for now
    [PDI, anatomic, Transf] = fonduta.io.datapath.load_session(dataPath, anatPath);

end
