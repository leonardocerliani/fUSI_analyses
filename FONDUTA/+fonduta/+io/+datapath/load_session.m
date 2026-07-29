function [PDI, anatomic, Transf] = load_session(dataPath, anatPath)
% fonduta.io.datapath.load_session  Load functional data, anatomy and registration for one session.
%
% Loads the preprocessed PDI data, anatomical scan, and spatial transformation
% for a single recording session. Paths are provided directly (e.g., from
% fonduta.io.datapath.get_paths).
%
% Inputs:
%   dataPath - full path to the session's data folder (string)
%   anatPath - full path to the session's anatomy folder (string)
%
% Outputs:
%   PDI      - struct with fields: .PDI [nx x ny x nt], .time, .stimInfo,
%              .wheelInfo, .Dim, and more (contents depend on preprocessing)
%   anatomic - struct containing the anatomical B-mode ultrasound scan
%   Transf   - struct containing the affine registration transformation
%
% Notes:
%   The functional file is expected at: dataPath/functional/prepPDI.mat
%   The anatomy file is expected at:    anatPath/anatomic.mat
%   The transformation is expected at:  anatPath/Transformation.mat
%   The PDI file may contain the struct under any variable name; the first
%   field is extracted automatically.
%
% See also: fonduta.io.datapath.get_paths, fonduta.io.datapath.save_results

    %% Load functional data
    funcFile = fullfile(dataPath, 'functional', 'prepPDI.mat');

    if ~isfile(funcFile)
        error('fonduta:io:datapath:load_session:FileNotFound', ...
              'Functional file not found:\n  %s', funcFile);
    end

    tmp    = load(funcFile);
    fields = fieldnames(tmp);
    PDI    = tmp.(fields{1});
    PDI.savepath = dataPath;

    %% Load anatomical scan
    anatFile = fullfile(anatPath, 'anatomic.mat');

    if ~isfile(anatFile)
        error('fonduta:io:datapath:load_session:FileNotFound', ...
              'Anatomy file not found:\n  %s', anatFile);
    end

    load(anatFile, 'anatomic');

    %% Load spatial transformation
    transfFile = fullfile(anatPath, 'Transformation.mat');

    if ~isfile(transfFile)
        error('fonduta:io:datapath:load_session:FileNotFound', ...
              'Transformation file not found:\n  %s', transfFile);
    end

    load(transfFile, 'Transf');

end
