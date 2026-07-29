function parsave(fullfilename, data)
% fonduta.io.parsave  Save data safely inside parfor loops.
%
% MATLAB's built-in save() cannot be called inside parfor with a
% workspace variable name. This wrapper accepts data as an argument
% and saves it to disk under the variable name 'data'.
%
% Inputs:
%   fullfilename - full path to the .mat output file (string)
%   data         - any MATLAB variable to save
%
% Notes:
%   The saved file will contain a variable named 'data'.
%   When loading: tmp = load(fullfilename); result = tmp.data;

    save(fullfilename, 'data');

end
