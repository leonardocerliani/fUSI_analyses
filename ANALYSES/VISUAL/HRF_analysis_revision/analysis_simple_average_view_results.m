classdef analysis_simple_average_view_results

    methods (Static)

        %% ================================================================
        function view_table(opts)

            % Defaults
            if ~isfield(opts, 'model')
                error('opts.model must be specified.');
            end

            if ~isfield(opts, 'sim_thresh')
                opts.sim_thresh = 0.85;
            end

            if ~isfield(opts, 'n_subject_thresh')
                opts.n_subject_thresh = 10;
            end

            if ~isfield(opts, 'smooth_win_s')
                opts.smooth_win_s = 0;
            end

            if ~isfield(opts, 'eta2_thresh_val')
                opts.eta2_thresh_val = 0.03;
            end
            
            eta_str = sprintf('eta%03d', round(opts.eta2_thresh_val * 100));

            % Locate result file
            results_path = fullfile( ...
                pwd, 'HRF_analysis_revision', 'results_simple_average');

            mat_file = fullfile( ...
                results_path, ...
                sprintf('simple_avg_%s_%s.mat', opts.model, eta_str));

            if ~isfile(mat_file)
                error('Results file not found:\n%s', mat_file);
            end

            S = load(mat_file);

            % Smoothing
            smooth_win_frames = max(1, ...
                round(opts.smooth_win_s / S.TR_mean));

            % HRF prediction
            stim_frames   = round(S.stim_dur_s / S.TR_mean);
            before_frames = round(S.before_stim_onset / S.TR_mean);
            after_frames  = round(S.after_stim_offset / S.TR_mean);

            W = before_frames + stim_frames + after_frames;

            boxcar = [ ...
                zeros(before_frames,1); ...
                ones(stim_frames,1); ...
                zeros(after_frames,1)];

            hrf_ch = fonduta.signal.hrf( ...
                S.TR_mean, S.chaoyi_hrfParams);

            ap_ch = conv(boxcar, hrf_ch);
            ap_ch = ap_ch(1:W);
            ap_ch = ap_ch / max(ap_ch);

            hrf_c23 = fonduta.signal.hrf( ...
                S.TR_mean, S.chen2023_hrfParams);

            ap_c23 = conv(boxcar, hrf_c23);
            ap_c23 = ap_c23(1:W);
            ap_c23 = ap_c23 / max(ap_c23);

            % Regions
            region_fields = fieldnames(S.regional_avg);
            nRegions = numel(region_fields);

            acr_list     = cell(nRegions,1);
            name_list    = cell(nRegions,1);
            nsub_list    = zeros(nRegions,1);
            mean_sim_ch  = nan(nRegions,1);
            std_sim_ch   = nan(nRegions,1);
            mean_sim_c23 = nan(nRegions,1);
            std_sim_c23  = nan(nRegions,1);

            for fi = 1:nRegions

                reg = S.regional_avg.(region_fields{fi});
                TC  = reg.tc;
                nS  = size(TC, 2);

                acr_list{fi}  = reg.acr;
                name_list{fi} = reg.name;
                nsub_list(fi) = nS;

                if nS < opts.n_subject_thresh || size(TC,1) ~= W
                    continue
                end

                TC_sm = movmean(TC, smooth_win_frames, 1);

                sims_ch = arrayfun(@(s) ...
                    corr(TC_sm(:,s), ap_ch, 'rows','complete'), ...
                    1:nS);

                sims_c23 = arrayfun(@(s) ...
                    corr(TC_sm(:,s), ap_c23, 'rows','complete'), ...
                    1:nS);

                mean_sim_ch(fi)  = mean(sims_ch);
                std_sim_ch(fi)   = std(sims_ch);

                mean_sim_c23(fi) = mean(sims_c23);
                std_sim_c23(fi)  = std(sims_c23);
            end

            % Filter
            keep = ...
                nsub_list >= opts.n_subject_thresh & ...
                ~isnan(mean_sim_ch) & ...
                mean_sim_ch >= opts.sim_thresh;

            acr_list     = acr_list(keep);
            name_list    = name_list(keep);
            nsub_list    = nsub_list(keep);
            mean_sim_ch  = mean_sim_ch(keep);
            std_sim_ch   = std_sim_ch(keep);
            mean_sim_c23 = mean_sim_c23(keep);
            std_sim_c23  = std_sim_c23(keep);

            % Sort by Chaoyi correlation
            [~, idx] = sort(mean_sim_ch, 'descend');

            acr_list     = acr_list(idx);
            name_list    = name_list(idx);
            nsub_list    = nsub_list(idx);
            mean_sim_ch  = mean_sim_ch(idx);
            std_sim_ch   = std_sim_ch(idx);
            mean_sim_c23 = mean_sim_c23(idx);
            std_sim_c23  = std_sim_c23(idx);

            % Print
            clc

            nR = numel(acr_list);

            fprintf('\n[%s] Simple average -- HRF similarity\n', ...
                S.model_name);

            fprintf('Regions with Chaoyi r >= %.2f, n >= %d\n\n', ...
                opts.sim_thresh, opts.n_subject_thresh);

            fprintf('%-12s  %-40s  %5s  %-18s  %-18s\n', ...
                'Acronym', 'Full name', 'nSub', ...
                'Chaoyi r+/-std', 'Chen2023 r+/-std');

            fprintf('%s\n', repmat('-',1,100));

            for fi = 1:nR

                fprintf('%-12s  %-40s  %5d  %.3f +/- %.3f      %.3f +/- %.3f\n', ...
                    acr_list{fi}, ...
                    name_list{fi}, ...
                    nsub_list(fi), ...
                    mean_sim_ch(fi), ...
                    std_sim_ch(fi), ...
                    mean_sim_c23(fi), ...
                    std_sim_c23(fi));
            end

            fprintf('\n%d regions shown.\n\n', nR);

        end


        %% ================================================================
        function plot_similarity(opts)

            if ~isfield(opts, 'model')
                error('opts.model must be specified.');
            end
            
            model_name = opts.model;
            
            if ~isfield(opts, 'target_acr')
                error('opts.target_acr must be specified.');
            end

            if ~isfield(opts, 'smooth_win_s')
                opts.smooth_win_s = 0;
            end

            if ~isfield(opts, 'eta2_thresh_val')
                opts.eta2_thresh_val = 0.03;
            end
            
            eta_str = sprintf('eta%03d', round(opts.eta2_thresh_val * 100));

            % Locate result file
            results_path = fullfile( ...
                pwd, 'HRF_analysis_revision', 'results_simple_average');

            mat_file = fullfile( ...
                results_path, ...
                sprintf('simple_avg_%s_%s.mat', model_name, eta_str));

            if ~isfile(mat_file)
                error('Results file not found:\n%s', mat_file);
            end

            S = load(mat_file);

            % Find region
            target_field = matlab.lang.makeValidName(opts.target_acr);

            if ~isfield(S.regional_avg, target_field)
                error('Region "%s" not found.', opts.target_acr);
            end

            reg = S.regional_avg.(target_field);

            TC = reg.tc;
            nSub = size(TC, 2);

            % Smooth
            if opts.smooth_win_s > 0

                smooth_win_frames = max(1, ...
                    round(opts.smooth_win_s / S.TR_mean));

                TC = movmean(TC, smooth_win_frames, 1);

            end

            % Mean and SE
            mu = mean(TC, 2);
            se = std(TC, 0, 2) / sqrt(nSub);

            % HRF predictions
            stim_frames   = round(S.stim_dur_s / S.TR_mean);
            before_frames = round(S.before_stim_onset / S.TR_mean);
            after_frames  = round(S.after_stim_offset / S.TR_mean);

            W = before_frames + stim_frames + after_frames;

            boxcar = [ ...
                zeros(before_frames,1); ...
                ones(stim_frames,1); ...
                zeros(after_frames,1)];

            hrf_ch = fonduta.signal.hrf( ...
                S.TR_mean, S.chaoyi_hrfParams);

            ap_ch = conv(boxcar, hrf_ch);
            ap_ch = ap_ch(1:W);
            ap_ch = ap_ch / max(ap_ch) * max(abs(mu));

            % Plot
            stim_on_s = [0, S.stim_dur_s];

            y_lo = min(mu-se) - 0.1;
            y_hi = max(mu+se) + 0.1;

            figure( ...
                'Name', sprintf('[%s] %s', model_name, reg.acr), ...
                'Position', [100 100 650 420]);

            hold on;

            fill( ...
                [stim_on_s(1) stim_on_s(2) stim_on_s(2) stim_on_s(1)], ...
                [y_lo y_lo y_hi y_hi], ...
                [0.9 0.95 1.0], ...
                'EdgeColor', 'none', ...
                'FaceAlpha', 0.6);

            fill( ...
                [S.t_window, fliplr(S.t_window)], ...
                [mu+se; flipud(mu-se)]', ...
                [0.2 0.4 0.8], ...
                'FaceAlpha', 0.25, ...
                'EdgeColor', 'none');

            plot(S.t_window, mu, 'b-', 'LineWidth', 2.5);
            plot(S.t_window, ap_ch, 'k--', 'LineWidth', 2);

            hold off;

            xline(0, ':k', 'onset', ...
                'LineWidth', 1, ...
                'LabelVerticalAlignment', 'bottom');

            xline(S.stim_dur_s, ':k', 'offset', ...
                'LineWidth', 1, ...
                'LabelVerticalAlignment', 'bottom');

            yline(0, ':k', 'LineWidth', 0.8);

            xlabel('Time relative to onset (s)');
            ylabel('\DeltaF/F  (baseline-corrected)');

            title( ...
                sprintf('[%s] %s -- %s  (n=%d)', ...
                S.model_name, reg.acr, reg.name, nSub), ...
                'Interpreter', 'none', ...
                'FontSize', 11);

            legend( ...
                {'stim period', '', 'mean \pm SE', 'Chaoyi HRF'}, ...
                'Location', 'northeast', ...
                'Interpreter', 'tex');

            box off;

        end

    end
end