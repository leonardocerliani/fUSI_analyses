% Set your root directory
root_dir = '/data00/leonardo/github/fUSI_analyses/ANALYSES/VISUAL/HRF_analysis_revision';

% File paths
ridge_file = fullfile(root_dir, 'results_ridge_loo', 'ridge_loo_M5_Behavior_eta003_HRF12s.mat');
simple_file = fullfile(root_dir, 'results_simple_average', 'simple_avg_M5_Behavior_eta003.mat');

% Load data structures
fprintf('Loading files...\n');
ridge_data = load(ridge_file, 'regional_avg');
simple_data = load(simple_file, 'regional_avg');

regions_ridge = fieldnames(ridge_data.regional_avg);
regions_simple = fieldnames(simple_data.regional_avg);

common_regions = intersect(regions_ridge, regions_simple);
fprintf('Found %d overlapping regions total.\n\n', numel(common_regions));
fprintf('--- Regions with > 10 subjects for both Ridge and SimpleAvg ---\n');

min_subjects_thresh = 10;
valid_regions_count = 0;

for i = 1:numel(common_regions)
    reg = common_regions{i};
    
    tc_ridge = ridge_data.regional_avg.(reg).tc;
    tc_simple = simple_data.regional_avg.(reg).tc;
    
    n_subj_ridge = size(tc_ridge, 2);
    n_subj_simple = size(tc_simple, 2);
    
    % Check if both exceed 10 subjects
    if n_subj_ridge > min_subjects_thresh && n_subj_simple > min_subjects_thresh
        fprintf('Region: %-15s | Ridge Subs: %d | SimpleAvg Subs: %d\n', reg, n_subj_ridge, n_subj_simple);
        valid_regions_count = valid_regions_count + 1;
    end
end

fprintf('\nTotal qualifying regions: %d\n', valid_regions_count);