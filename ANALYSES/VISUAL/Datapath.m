function [subDataPath, subAnatPath, resultPath] = Datapath(cond)
    % DATAPATH Returns data and anatomical paths based on the condition.
    %
    %   [subDataPath, subAnatPath, resultPath] = DATAPATH(cond)
    %
    %   Inputs:
    %       cond - A string specifying the condition (e.g., 'VisualTest', 'ShockTest', etc.)
    %
    %   Outputs:
    %       subDataPath - Cell array of subject data paths
    %       subAnatPath - Cell array of corresponding anatomical paths
    %       resultPath  - Path for storing results

    % Initialize default path for Emotion Contagion
% corresponding anatomical session
subAnatPath{1,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-122938';
subAnatPath{2,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-112016';
subAnatPath{3,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-110153';
subAnatPath{4,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-123552';
subAnatPath{5,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-111330';
subAnatPath{6,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-103522';
subAnatPath{7,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-095114';
subAnatPath{8,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-092146';
subAnatPath{9,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-104237';
subAnatPath{10,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-102748';
subAnatPath{11,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-102319';
subAnatPath{12,1} = '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad15/ses-240621/run-101917';
resultPath  = ['/data06/fUSIEmotionalContagion/Data_analysis/sub-Group/' cond];

    % Define paths based on the condition
    switch cond
        %% VisualTest
        case 'VisualTest'
            % Data Paths for VisualTest
            subDataPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231215/run-115047/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231218/run-152539/', ... % RunningTrials4/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240104/run-125448/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240105/run-103457/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240104/run-142825/', ... % RunningTrials7/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240105/run-114946/', ... % RunningTrials6/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240123/run-145033/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240124/run-114404/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-125114/', ... % RunningTrials3/5
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-105516/', ... % RunningTrials5/5
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231221/run-164739/', ... % RunningTrials9/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-124507/', ... % RunningTrials4/5
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-142450/', ... % RunningTrials3/5
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-114737/', ... % RunningTrials2/5
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231220/run-153002/', ... % loose wheel, RunningTrials7/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231220/run-142742/', ... % loose wheel, RunningTrials6/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231221/run-152916/', ... % loose wheel, RunningTrials6/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-142230/', ... % RunningTrials10/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-144522/', ... % RunningTrials9/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-150701/', ... % RunningTrials8/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240110/run-104841/', ... % RunningTrials9/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240110/run-111054/', ... % RunningTrials4/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240111/run-140450/', ... % RunningTrials9/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240111/run-142648/', ... % RunningTrials4/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-161356/', ... % RunningTrials5/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-163615/', ... % RunningTrials5/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240110/run-115826/', ... % RunningTrials5/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240110/run-122011/', ... % RunningTrials5/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240111/run-152201/', ... % RunningTrials7/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240111/run-154343/', ... % RunningTrials5/10
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240126/run-101347/', ... % RunningTrials11/20
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240129/run-112118/', ... % RunningTrials12/20
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231219/run-142136/', ... % RunningTrials9/30
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240125/run-143014/'  ... % RunningTrials27/30
            };

            % Corresponding Anatomical Paths for VisualTest
            subAnatPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231215/run-113409/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231218/run-144557/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240104/run-123823/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240105/run-102041/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240104/run-140723/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240105/run-113659/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240123/run-143248/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240124/run-112840/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231221/run-163714/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231220/run-150626/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231220/run-134717/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231221/run-150820/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-140635/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-140635/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240108/run-140635/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240110/run-103350/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240110/run-103350/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240111/run-135158/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240111/run-135158/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-154044/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240108/run-154044/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240110/run-114616/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240110/run-114616/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240111/run-150224/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240111/run-150224/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240126/run-100106/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240129/run-110828/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231219/run-140232/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240125/run-141727/' ...
            };

            % Define result path for VisualTest
            resultPath = fullfile('/data06/fUSIMethodsPaper/Data_analysis/sub-Group', cond, 'Functional');

            %% ShockTest
        case 'ShockTest'
            % Data Paths for ShockTest
            subDataPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-240103/run-142553/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240104/run-155221/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240105/run-141931/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240112/run-104836/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240115/run-151028/',
                % '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240115/run-170706/',
                % very likely in this session the animal was not shocked
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240116/run-105152/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240119/run-100517/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240116/run-123050/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240119/run-120725/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240201/run-101850/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240202/run-101117/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240207/run-160841/' ...
            };

            % Corresponding Anatomical Paths for ShockTest
            subAnatPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-240103/run-140517/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240104/run-151641/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240105/run-134709/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-240112/run-102532/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240115/run-145032/',
                % '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240115/run-164239/',
                % very likely in this session the animal was not shocked
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240116/run-103209/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240119/run-094051/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240116/run-120905/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240119/run-115020/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240201/run-100114/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240202/run-095105/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240207/run-154622/' ...
            };

            % Define result path for ShockTest
            resultPath =  fullfile('/data06/fUSIMethodsPaper/Data_analysis/sub-Group', cond, 'Functional');

        case 'VS'
            % Data Paths for VS
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-124214/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-113508/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-112050/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-124111/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-112648/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-104749/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-100831/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-093719/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-105516/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-103830/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-104317/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad15/ses-240621/run-103333/' ...
            };

            % Define result path for VS
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

            %% Shock Observation
        case 'SO'
            % Data Paths for Shock Observation (SO)
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-130900',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-115007',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-113759',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-125033',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-113731',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-110127',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-102200',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-101329',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-110855',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-105230',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-105628',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad15/ses-240621/run-104740' ...
            };

            % Define result path for SO
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

            %% Fear Recall
        case 'FR'
            % Data Paths for Fear Conditioning (FC)
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-135532',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-122859',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-121425',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-132829',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-121704',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-114141',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-105859',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-104011',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-114617',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-113126',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-113713',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad15/ses-240621/run-112656' ...
            };

            % Define result path for FC
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

            %% Self Shock
        case 'SS'
            % Data Paths for Single Session (SS)
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-SS/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-124007/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-122652/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-135524/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-123843/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-120210/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-112203/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-110140/',  % Note: This animal did not receive any shocks due to a loose connection
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-120808/', 
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-115354/', 
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-115946/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad15/ses-240621/run-114914/'
            };

            % Define result path for SS
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

                        %% Shock Observation (cFOS)
        case 'SOcFOS'
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS04/ses-240315/run-123308/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS06/ses-240412/run-092440/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS07/ses-240510/run-104955/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS09/ses-240531/run-123216/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS12/ses-240628/run-101833/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS14/ses-240705/run-122838/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS16/ses-240711/run-102901/',
                };

               % Corresponding Anatomical Paths 
            subAnatPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS04/ses-240315/run-122301/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS06/ses-240412/run-091059/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS07/ses-240510/run-103230/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS09/ses-240531/run-121756/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS12/ses-240628/run-100447/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS14/ses-240705/run-121655/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS16/ses-240711/run-101826/',
                };

            % Define result path
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

        case 'SOcFOSctl'
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS03/ses-240315/run-100823/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS05/ses-240412/run-114408/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS08/ses-240510/run-132003/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS10/ses-240531/run-101858/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS11/ses-240628/run-124458/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS13/ses-240705/run-102003/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS15/ses-240711/run-123656/',
                };

               % Corresponding Anatomical Paths 
            subAnatPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS03/ses-240315/run-095424/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS05/ses-240412/run-112926/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS08/ses-240510/run-130852/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS10/ses-240531/run-100440/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS11/ses-240628/run-122058/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS13/ses-240705/run-100517/',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-CFOS15/ses-240711/run-122604/',
                };

            % Define result path
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

        case 'SOFC'
            % Data Paths for Combined Shock Observation and Fear Conditioning (SOFC)
            subDataPath = {
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad01/ses-230329/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad02/ses-230331/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad03/ses-230330/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad05/ses-230615/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad07/ses-230623/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad09/ses-240216/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad10/ses-240308/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad11/ses-240301/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad12/ses-240524/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad13/ses-240607/run-SOFC',
                '/data06/fUSIEmotionalContagion/Data_analysis/sub-Dyad14/ses-240614/run-SOFC' ...
            };

            % Define result path for SOFC
            resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);

            %% VisualTestMultiSlice
        case 'VisualTestMultiSlice'
            % Data Paths for VisualTest with Multiple Slices
            subDataPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-123247/', ... % LGN -2mm
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-124213/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-125114/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-130049/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-130938/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-131817/', ... # first
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-110441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-111350/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-105516/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-112248/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-113310/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-114148/', ... # second
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-125708/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-130859/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-124507/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-132130/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-133322/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-134457/', ... # third
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-143648/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-144839/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-142450/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-150046/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-151308/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-152524/', ... # fourth
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-115947/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-121204/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-114737/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-122426/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-123701/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-124910/' ... # fifth
            };

            % Corresponding Anatomical Paths for VisualTestMultiSlice
            subAnatPath = {
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods01/ses-231222/run-120552/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods02/ses-231222/run-102916/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods03/ses-240112/run-123417/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods04/ses-240112/run-141441/', ...
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/',
                '/data06/fUSIMethodsPaper/Data_analysis/sub-methods05/ses-240130/run-112415/' ...
            };

            % Define result path for VisualTestMultiSlice
            resultPath = fullfile('/data06/fUSIMethodsPaper/Data_analysis/sub-Group', cond);

            %% FUStimulation
        case 'USStimulation'
            % Data Paths for Focused Ultrasound Stimulation (FUStimulation)
            subDataPath = {
                '/data03/USS/Data_analysis/animal1/ses-240916/run-165644/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-144409/',
                '/data03/USS/Data_analysis/animal1/ses-240917/run-122601/',
                '/data03/USS/Data_analysis/animal1/ses-240917/run-125149/',
                '/data03/USS/Data_analysis/animal1/ses-240917/run-131126/',
                '/data03/USS/Data_analysis/animal2/ses-240917/run-160022/',
                '/data03/USS/Data_analysis/animal2/ses-240917/run-163257/',
                '/data03/USS/Data_analysis/animal2/ses-240917/run-170411/',
                '/data03/USS/Data_analysis/animal1/ses-240918/run-165905/',
                '/data03/USS/Data_analysis/animal1/ses-240918/run-172355/',
                '/data03/USS/Data_analysis/animal1/ses-240918/run-174256/',
                '/data03/USS/Data_analysis/animal2/ses-240918/run-123230/',
                '/data03/USS/Data_analysis/animal2/ses-240918/run-125830/',
                '/data03/USS/Data_analysis/animal2/ses-240918/run-131734/',
                '/data03/USS/Data_analysis/animal1/ses-240920/run-123223/',
                '/data03/USS/Data_analysis/animal1/ses-240920/run-130147/',
                '/data03/USS/Data_analysis/animal1/ses-240920/run-132200/',
                '/data03/USS/Data_analysis/animal2/ses-240920/run-164354/',
                '/data03/USS/Data_analysis/animal2/ses-240920/run-171217/',
                '/data03/USS/Data_analysis/animal3/ses-241209/run-173809/',
                '/data03/USS/Data_analysis/animal3/ses-241209/run-180013/',
                '/data03/USS/Data_analysis/animal3/ses-241209/run-182002/',
                '/data03/USS/Data_analysis/animal4/ses-241209/run-144141/',
                '/data03/USS/Data_analysis/animal4/ses-241209/run-151140/',
                '/data03/USS/Data_analysis/animal4/ses-241209/run-153048/',
                '/data03/USS/Data_analysis/animal3/ses-241210/run-122338/',
                '/data03/USS/Data_analysis/animal3/ses-241210/run-124702/',
                '/data03/USS/Data_analysis/animal3/ses-241210/run-130646/',
                '/data03/USS/Data_analysis/animal4/ses-241210/run-164455/',
                '/data03/USS/Data_analysis/animal4/ses-241210/run-170916/',
                '/data03/USS/Data_analysis/animal4/ses-241210/run-172834/',
                '/data03/USS/Data_analysis/animal3/ses-241211/run-155426/',
                '/data03/USS/Data_analysis/animal3/ses-241211/run-164719/',
                '/data03/USS/Data_analysis/animal3/ses-241213/run-122759/',
                '/data03/USS/Data_analysis/animal3/ses-241213/run-125227/',
                '/data03/USS/Data_analysis/animal3/ses-241213/run-131305/',
                '/data03/USS/Data_analysis/animal4/ses-241211/run-120846/',
                '/data03/USS/Data_analysis/animal4/ses-241211/run-124120/',
                '/data03/USS/Data_analysis/animal4/ses-241211/run-130027/',
                '/data03/USS/Data_analysis/animal4/ses-241213/run-162050/',
                '/data03/USS/Data_analysis/animal4/ses-241213/run-164339/',
                '/data03/USS/Data_analysis/animal4/ses-241213/run-170236/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-125612/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-131851/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-133737/',
                '/data03/USS/Data_analysis/animal5/ses-250128/run-145540/',
                '/data03/USS/Data_analysis/animal5/ses-250128/run-152058/',
                '/data03/USS/Data_analysis/animal5/ses-250128/run-154033/',
                '/data03/USS/Data_analysis/animal5/ses-250129/run-155806/',
                '/data03/USS/Data_analysis/animal5/ses-250129/run-162039/',
                '/data03/USS/Data_analysis/animal5/ses-250129/run-164045/',
                '/data03/USS/Data_analysis/animal5/ses-250131/run-120417/',
                '/data03/USS/Data_analysis/animal5/ses-250131/run-122648/',
                '/data03/USS/Data_analysis/animal5/ses-250131/run-124742/'...
            };

            % Corresponding Anatomical Paths for FUStimulation
            subAnatPath = {
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal1/ses-240916/run-163205/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal2/ses-240916/run-141934/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal3/ses-241206/run-125538/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal4/ses-241206/run-153342/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/',
                '/data03/USS/Data_analysis/animal5/ses-250127/run-122411/'...
            };

            % Define result path for FUStimulation
            resultPath = fullfile('/data03/USS/Data_analysis/sub-Group', cond);

            %% ElectrodeTest
        case 'ElectrodeTest'
            % Data Paths for Electrode Test
            subDataPath = {
                '/data03/USS/Data_analysis/animal1/ses-240903/run-161022/', % With electrode, 8min baseline
                '/data03/USS/Data_analysis/animal1/ses-240904/run-143907/', % With electrode, 1min baseline
                '/data03/USS/Data_analysis/animal2/ses-240903/run-182111/', % With electrode, 6min baseline
                '/data03/USS/Data_analysis/animal2/ses-240904/run-112838/', % With electrode, 1min baseline
                '/data03/USS/Data_analysis/animal1/ses-240904/run-135955/', % Without electrode, 11min baseline
                '/data03/USS/Data_analysis/animal2/ses-240904/run-110108/'  % Without electrode, 11min baseline
            };

            % Corresponding Anatomical Paths for ElectrodeTest
            subAnatPath = {
                '/data03/USS/Data_analysis/animal1/ses-240903/run-153439/',
                '/data03/USS/Data_analysis/animal1/ses-240903/run-153439/',
                '/data03/USS/Data_analysis/animal2/ses-240903/run-174638/',
                '/data03/USS/Data_analysis/animal2/ses-240903/run-174638/',
                '/data03/USS/Data_analysis/animal1/ses-240903/run-153439/',
                '/data03/USS/Data_analysis/animal2/ses-240903/run-174638/' ...
            };

            % Define result path for ElectrodeTest
            resultPath = fullfile('/data03/USS/Data_analysis/sub-Group', cond);

        otherwise
            error('Unknown condition: %s', cond);
    end

    % Define Result Path for specific cases if not already defined
    if isempty(resultPath) && ~isempty(cond)
        resultPath = fullfile('/data06/fUSIEmotionalContagion/Data_analysis/sub-Group', cond);
    end

    % Path adjustments for Windows systems
    if ispc
        % Replace forward slashes with backslashes
        subDataPath = strrep(subDataPath, '/', '\');
        subAnatPath = strrep(subAnatPath, '/', '\');

        % Replace base directories
        subDataPath = strrep(subDataPath, 'data06', '\vs03\VS03-SBL-4');
        subDataPath = strrep(subDataPath, 'data03', '\vs03\VS03-SBL-1');

        subAnatPath = strrep(subAnatPath, 'data06', '\vs03\VS03-SBL-4');
        subAnatPath = strrep(subAnatPath, 'data03', '\vs03\VS03-SBL-1');

        if ~isempty(resultPath)
            resultPath = strrep(resultPath, '/', '\');
            resultPath = strrep(resultPath, 'data06', '\vs03\VS03-SBL-4');
            resultPath = strrep(resultPath, 'data03', '\vs03\VS03-SBL-1');
        end
    end

    % Create result folder if it does not exist
    if ~isempty(resultPath) && ~exist(resultPath, 'dir')
        mkdir(resultPath);
    end
end
