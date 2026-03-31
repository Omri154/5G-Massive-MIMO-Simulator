classdef ResultsManager < handle
% RESULTSMANAGER - Comprehensive results saving and visualization
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class handles the post-simulation processing, organizing the output
% data, and generating visual and tabular reports.
%
% Features:
%   - Saves separate CSV files per UE and a combined dataset
%   - Creates multiple detailed visualizations (spatial, temporal, statistical)
%   - Generates an HTML summary report
%   - Manages an organized output directory structure with timestamps
%   - Performs statistical analysis on the CSI metrics
%
% Properties:
%   config          - Simulation configuration struct
%   engine          - Struct containing simulation execution data and managers
%   csi_data        - Struct containing all generated CSI reports
%   output_dir      - Main output directory path

    properties
        config          
        engine          
        csi_data        
        output_dir      
        
        % Sub-directories
        csv_dir         
        figures_dir     
        reports_dir     
        
        % Statistics
        stats           
    end
    
    methods
        
        function obj = ResultsManager(config, engine, csi_data)
            % RESULTSMANAGER Constructor
            %
            % Input:
            %   config    - simulation configuration struct
            %   engine    - simulation data struct containing managers and logs
            %   csi_data  - CSI data structure with all reports
            
            obj.config = config;
            obj.engine = engine;
            obj.csi_data = csi_data;
            
            % Create output directory structure
            obj.create_output_directories();
            
            fprintf('[ResultsManager] Initialized\n');
            fprintf('  Output directory: %s\n', obj.output_dir);
        end
        
        
        function create_output_directories(obj)
            % CREATE_OUTPUT_DIRECTORIES Create organized directory structure
            
            % Main output directory with timestamp
            timestamp_str = datestr(now, 'yyyymmdd_HHMMSS');
            obj.output_dir = sprintf('./results/simulation_%s/', timestamp_str);
            
            % Create subdirectories
            obj.csv_dir = [obj.output_dir, 'csv/'];
            obj.figures_dir = [obj.output_dir, 'figures/'];
            obj.reports_dir = [obj.output_dir, 'reports/'];
            
            % Create all directories
            if ~exist(obj.output_dir, 'dir'), mkdir(obj.output_dir); end
            if ~exist(obj.csv_dir, 'dir'), mkdir(obj.csv_dir); end
            if ~exist(obj.figures_dir, 'dir'), mkdir(obj.figures_dir); end
            if ~exist(obj.reports_dir, 'dir'), mkdir(obj.reports_dir); end
            
            fprintf('[ResultsManager] Created directory structure:\n');
            fprintf('  %s\n', obj.output_dir);
            fprintf('    |-- csv/\n');
            fprintf('    |-- figures/\n');
            fprintf('    |-- reports/\n');
        end
        
        
        function save_all_results(obj)
            % SAVE_ALL_RESULTS Master function to save everything
            
            fprintf('\n========================================\n');
            fprintf('  Saving All Results\n');
            fprintf('========================================\n\n');
            
            % 1. Calculate statistics
            fprintf('[1/4] Calculating statistics...\n');
            obj.calculate_statistics();
            
            % 2. Save CSV files
            fprintf('[2/4] Saving CSV files...\n');
            obj.save_csv_files();
            
            % 3. Create visualizations
            fprintf('[3/4] Creating visualizations...\n');
            obj.create_all_visualizations();
            
            % 4. Generate HTML report
            fprintf('[4/4] Generating HTML report...\n');
            obj.generate_html_report();
            
            fprintf('\n========================================\n');
            fprintf('  All Results Saved Successfully!\n');
            fprintf('========================================\n');
            fprintf('Output directory: %s\n\n', obj.output_dir);
        end
        
        
        function calculate_statistics(obj)
            % CALCULATE_STATISTICS Calculate overall statistics
            
            obj.stats = struct();
            
            % Get valid indices
            valid_mask = obj.csi_data.ue_id > 0;
            
            % Overall statistics
            obj.stats.num_ues = obj.config.ue.num;
            obj.stats.num_reports = sum(valid_mask);
            obj.stats.duration = obj.config.timing.total_duration;
            
            % CSI statistics
            obj.stats.rsrp_mean = mean(obj.csi_data.rsrp(valid_mask));
            obj.stats.rsrp_std = std(obj.csi_data.rsrp(valid_mask));
            obj.stats.rsrp_min = min(obj.csi_data.rsrp(valid_mask));
            obj.stats.rsrp_max = max(obj.csi_data.rsrp(valid_mask));
            
            obj.stats.sinr_mean = mean(obj.csi_data.sinr(valid_mask));
            obj.stats.sinr_std = std(obj.csi_data.sinr(valid_mask));
            obj.stats.sinr_min = min(obj.csi_data.sinr(valid_mask));
            obj.stats.sinr_max = max(obj.csi_data.sinr(valid_mask));
            
            obj.stats.cqi_mean = mean(obj.csi_data.cqi(valid_mask));
            
            % Per-UE statistics
            obj.stats.per_ue = struct();
            for ue_id = 1:obj.stats.num_ues
                ue_mask = obj.csi_data.ue_id == ue_id;
                obj.stats.per_ue(ue_id).rsrp_mean = mean(obj.csi_data.rsrp(ue_mask));
                obj.stats.per_ue(ue_id).sinr_mean = mean(obj.csi_data.sinr(ue_mask));
                obj.stats.per_ue(ue_id).cqi_mean = mean(obj.csi_data.cqi(ue_mask));
                obj.stats.per_ue(ue_id).num_reports = sum(ue_mask);
            end
            
            fprintf('  Statistics calculated\n');
        end
        
        
        function save_csv_files(obj)
            % SAVE_CSV_FILES Save CSV files (per UE + combined)
            
            valid_mask = obj.csi_data.ue_id > 0;
            
            % 1. Save combined CSV (all UEs)
            fprintf('  [CSV] Saving combined file...\n');
            combined_filename = [obj.csv_dir, 'all_ues_combined.csv'];
            
            combined_table = table(...
                obj.csi_data.timestamp(valid_mask), ...
                obj.csi_data.ue_id(valid_mask), ...
                obj.csi_data.x(valid_mask), ...
                obj.csi_data.y(valid_mask), ...
                obj.csi_data.area_id(valid_mask), ...
                obj.csi_data.rsrp(valid_mask), ...
                obj.csi_data.rsrq(valid_mask), ...
                obj.csi_data.sinr(valid_mask), ...
                obj.csi_data.cqi(valid_mask), ...
                obj.csi_data.serving_bs(valid_mask), ...
                obj.csi_data.distance(valid_mask), ...
                'VariableNames', {'timestamp', 'ue_id', 'x', 'y', 'area_id', ...
                                 'rsrp', 'rsrq', 'sinr', 'cqi', 'serving_bs', 'distance'});
            
            writetable(combined_table, combined_filename);
            fprintf('    Combined: %s (%.2f MB)\n', combined_filename, ...
                dir(combined_filename).bytes / 1e6);
            
            % 2. Save per-UE CSV files
            fprintf('  [CSV] Saving per-UE files...\n');
            for ue_id = 1:obj.stats.num_ues
                ue_mask = obj.csi_data.ue_id == ue_id;
                
                ue_filename = sprintf('%sue_%03d.csv', obj.csv_dir, ue_id);
                
                ue_table = table(...
                    obj.csi_data.timestamp(ue_mask), ...
                    obj.csi_data.x(ue_mask), ...
                    obj.csi_data.y(ue_mask), ...
                    obj.csi_data.area_id(ue_mask), ...
                    obj.csi_data.rsrp(ue_mask), ...
                    obj.csi_data.rsrq(ue_mask), ...
                    obj.csi_data.sinr(ue_mask), ...
                    obj.csi_data.cqi(ue_mask), ...
                    obj.csi_data.serving_bs(ue_mask), ...
                    obj.csi_data.distance(ue_mask), ...
                    'VariableNames', {'timestamp', 'x', 'y', 'area_id', ...
                                     'rsrp', 'rsrq', 'sinr', 'cqi', 'serving_bs', 'distance'});
                
                writetable(ue_table, ue_filename);
                
                % Print progress every 10 UEs
                if mod(ue_id, 10) == 0 || ue_id == obj.stats.num_ues
                    fprintf('    Progress: %d/%d UEs\n', ue_id, obj.stats.num_ues);
                end
            end
            
            fprintf('  CSV files saved\n');
        end
        
        
        function create_all_visualizations(obj)
            % CREATE_ALL_VISUALIZATIONS Create all visualization figures
            
            % Figure 1: Network Overview
            obj.plot_network_overview();
            
            % Figure 2: CSI Distributions
            obj.plot_csi_distributions();
            
            % Figure 3: Temporal Evolution
            obj.plot_temporal_evolution();
            
            % Figure 4: Spatial Analysis
            obj.plot_spatial_analysis();
            
            % Figure 5: Per-UE Performance
            obj.plot_per_ue_performance();
            
            % Figure 6: Area Analysis
            obj.plot_area_analysis();
            
            % Figure 7: Mobility Analysis
            obj.plot_mobility_analysis();
            
            % Figure 8: CQI Analysis
            obj.plot_cqi_analysis();
            
            fprintf('  All visualizations created\n');
        end
        
        
        function plot_network_overview(obj)
            % PLOT_NETWORK_OVERVIEW Network layout and trajectories
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Network Overview', 'Position', [50, 50, 1400, 900], 'Visible', visibility);
            
            % Get data
            bs_pos = obj.engine.bs_manager.get_all_positions();
            final_pos = obj.engine.ue_manager.get_all_positions();
            num_areas = length(obj.engine.areas);
            seeds = zeros(num_areas, 2);
            for i = 1:num_areas
                seeds(i, :) = obj.engine.areas(i).seed;
            end
            
            % Subplot 1: Full trajectories
            subplot(2, 3, 1);
            hold on; grid on;
            num_to_plot = min(20, obj.stats.num_ues);
            colors = lines(num_to_plot);
            for i = 1:num_to_plot
                traj = obj.engine.trajectory_data{i};
                plot(traj(:,1), traj(:,2), '-', 'Color', colors(i,:), 'LineWidth', 1.2);
                plot(traj(1,1), traj(1,2), 'o', 'MarkerSize', 7, ...
                    'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
                plot(traj(end,1), traj(end,2), 's', 'MarkerSize', 7, ...
                    'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            end
            scatter(bs_pos(:,1), bs_pos(:,2), 250, 'r', '^', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 2);
            xlabel('X [m]', 'FontWeight', 'bold'); 
            ylabel('Y [m]', 'FontWeight', 'bold');
            title(sprintf('UE Trajectories (%d UEs shown)', num_to_plot), 'FontWeight', 'bold');
            axis equal; xlim([0, obj.config.area_width]); ylim([0, obj.config.area_height]);
            legend({'Trajectory', 'Start', 'End'}, 'Location', 'best');
            hold off;
            
            % Subplot 2: Voronoi areas
            subplot(2, 3, 2);
            hold on; grid on;
            if num_areas >= 3
                voronoi(seeds(:,1), seeds(:,2), 'k-');
            end
            scatter(final_pos(:,1), final_pos(:,2), 35, 'b', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1);
            scatter(bs_pos(:,1), bs_pos(:,2), 250, 'r', '^', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 2);
            scatter(seeds(:,1), seeds(:,2), 120, 'g', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 2);
            % Add area labels
            for i = 1:num_areas
                text(seeds(i,1)+3, seeds(i,2)+3, sprintf('A%d', i), ...
                    'FontSize', 10, 'FontWeight', 'bold', ...
                    'BackgroundColor', 'white', 'EdgeColor', 'black');
            end
            xlabel('X [m]', 'FontWeight', 'bold');
            ylabel('Y [m]', 'FontWeight', 'bold');
            title('Final Positions & Voronoi Areas', 'FontWeight', 'bold');
            axis equal; xlim([0, obj.config.area_width]); ylim([0, obj.config.area_height]);
            legend({'' , 'Voronoi Edges', 'UEs', 'Base Stations', 'Area Seeds'}, 'Location', 'best');
            hold off;
            
            % Subplot 3: Area transitions
            subplot(2, 3, 3);
            if ~isempty(obj.engine.transition_log)
                hold on; grid on;
                scatter(seeds(:,1), seeds(:,2), 120, 'g', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 2);
                trans_pos = vertcat(obj.engine.transition_log.position);
                scatter(trans_pos(:,1), trans_pos(:,2), 50, 'r', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
                xlabel('X [m]', 'FontWeight', 'bold');
                ylabel('Y [m]', 'FontWeight', 'bold');
                title(sprintf('Area Transitions (%d events)', length(obj.engine.transition_log)), ...
                    'FontWeight', 'bold');
                axis equal; xlim([0, obj.config.area_width]); ylim([0, obj.config.area_height]);
                legend({'Area Seeds', 'Transition Points'}, 'Location', 'best');
                hold off;
            else
                text(0.5, 0.5, 'No transitions detected', ...
                    'HorizontalAlignment', 'center', 'FontSize', 12);
                axis off;
            end
            
            % Subplot 4: BS coverage
            subplot(2, 3, 4);
            hold on; grid on;
            valid_mask = obj.csi_data.ue_id > 0;
            serving_bs_data = obj.csi_data.serving_bs(valid_mask);
            x_data = obj.csi_data.x(valid_mask);
            y_data = obj.csi_data.y(valid_mask);
            
            % Plot points colored by serving BS
            scatter(x_data(serving_bs_data == 1), y_data(serving_bs_data == 1), ...
                20, 'b', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.3);
            scatter(x_data(serving_bs_data == 2), y_data(serving_bs_data == 2), ...
                20, 'r', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.3);
            scatter(bs_pos(:,1), bs_pos(:,2), 250, 'k', '^', 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 2);
            
            xlabel('X [m]', 'FontWeight', 'bold');
            ylabel('Y [m]', 'FontWeight', 'bold');
            title('BS Coverage Areas', 'FontWeight', 'bold');
            axis equal; xlim([0, obj.config.area_width]); ylim([0, obj.config.area_height]);
            legend({'Served by BS1', 'Served by BS2', 'Base Stations'}, 'Location', 'best');
            hold off;
            
            % Subplot 5: RSRP heatmap
            subplot(2, 3, 5);
            obj.plot_heatmap(x_data, y_data, obj.csi_data.rsrp(valid_mask), 'RSRP [dBm]');
            
            % Subplot 6: SINR heatmap
            subplot(2, 3, 6);
            obj.plot_heatmap(x_data, y_data, obj.csi_data.sinr(valid_mask), 'SINR [dB]');
            
            % Save figure
            saveas(fig, [obj.figures_dir, '01_network_overview.png']);
            saveas(fig, [obj.figures_dir, '01_network_overview.fig']);
        end
        
        
        function plot_heatmap(obj, x, y, values, title_str)
            % PLOT_HEATMAP Helper function to create heatmap
            
            % Create grid
            [X, Y] = meshgrid(...
                linspace(0, obj.config.area_width, 50), ...
                linspace(0, obj.config.area_height, 50));
            
            % Interpolate
            F = scatteredInterpolant(x, y, values, 'natural', 'none');
            Z = F(X, Y);
            
            % Plot
            hold on;
            imagesc([0, obj.config.area_width], [0, obj.config.area_height], Z);
            colormap(jet);
            colorbar;
            
            % Overlay BS positions
            bs_pos = obj.engine.bs_manager.get_all_positions();
            scatter(bs_pos(:,1), bs_pos(:,2), 150, 'w', '^', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 2);
            
            xlabel('X [m]', 'FontWeight', 'bold');
            ylabel('Y [m]', 'FontWeight', 'bold');
            title(title_str, 'FontWeight', 'bold');
            axis equal tight;
            hold off;
        end
        
        
        function plot_csi_distributions(obj)
            % PLOT_CSI_DISTRIBUTIONS Histograms and CDFs of CSI metrics

            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'CSI Distributions', 'Position', [100, 100, 1400, 900], 'Visible', visibility);
            
            valid_mask = obj.csi_data.ue_id > 0;
            
            % RSRP
            subplot(3, 3, 1);
            histogram(obj.csi_data.rsrp(valid_mask), 40, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('RSRP [dBm]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('RSRP Distribution', 'FontWeight', 'bold');
            grid on;
            
            subplot(3, 3, 2);
            [f, x] = ecdf(obj.csi_data.rsrp(valid_mask));
            plot(x, f, 'b-', 'LineWidth', 2);
            xlabel('RSRP [dBm]', 'FontWeight', 'bold');
            ylabel('CDF', 'FontWeight', 'bold');
            title('RSRP CDF', 'FontWeight', 'bold');
            grid on;
            
            subplot(3, 3, 3);
            boxplot(obj.csi_data.rsrp(valid_mask));
            ylabel('RSRP [dBm]', 'FontWeight', 'bold');
            title('RSRP Boxplot', 'FontWeight', 'bold');
            grid on;
            
            % SINR
            subplot(3, 3, 4);
            histogram(obj.csi_data.sinr(valid_mask), 40, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('SINR [dB]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('SINR Distribution', 'FontWeight', 'bold');
            grid on;
            
            subplot(3, 3, 5);
            [f, x] = ecdf(obj.csi_data.sinr(valid_mask));
            plot(x, f, 'g-', 'LineWidth', 2);
            xlabel('SINR [dB]', 'FontWeight', 'bold');
            ylabel('CDF', 'FontWeight', 'bold');
            title('SINR CDF', 'FontWeight', 'bold');
            grid on;
            
            subplot(3, 3, 6);
            boxplot(obj.csi_data.sinr(valid_mask));
            ylabel('SINR [dB]', 'FontWeight', 'bold');
            title('SINR Boxplot', 'FontWeight', 'bold');
            grid on;
            
            % CQI
            subplot(3, 3, 7);
            histogram(obj.csi_data.cqi(valid_mask), 0:15, 'FaceColor', 'r', 'EdgeColor', 'k');
            xlabel('CQI', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('CQI Distribution', 'FontWeight', 'bold');
            grid on;
            xlim([-0.5, 15.5]);
            
            subplot(3, 3, 8);
            [f, x] = ecdf(obj.csi_data.cqi(valid_mask));
            stairs(x, f, 'r-', 'LineWidth', 2);
            xlabel('CQI', 'FontWeight', 'bold');
            ylabel('CDF', 'FontWeight', 'bold');
            title('CQI CDF', 'FontWeight', 'bold');
            grid on;
            
            subplot(3, 3, 9);
            boxplot(obj.csi_data.cqi(valid_mask));
            ylabel('CQI', 'FontWeight', 'bold');
            title('CQI Boxplot', 'FontWeight', 'bold');
            grid on;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '02_csi_distributions.png']);
            saveas(fig, [obj.figures_dir, '02_csi_distributions.fig']);
        end
        
        
        function plot_temporal_evolution(obj)
            % PLOT_TEMPORAL_EVOLUTION CSI metrics over time
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Temporal Evolution', 'Position', [150, 150, 1400, 700], 'Visible', visibility);
            
            valid_mask = obj.csi_data.ue_id > 0;
            
            % Plot sample UEs
            num_ues_to_plot = min(10, obj.stats.num_ues);
            colors = lines(num_ues_to_plot);
            
            % RSRP over time
            subplot(2, 2, 1);
            hold on; grid on;
            for i = 1:num_ues_to_plot
                ue_mask = obj.csi_data.ue_id == i;
                plot(obj.csi_data.timestamp(ue_mask), obj.csi_data.rsrp(ue_mask), ...
                    'o-', 'Color', colors(i,:), 'LineWidth', 1.5, 'MarkerSize', 4);
            end
            xlabel('Time [s]', 'FontWeight', 'bold');
            ylabel('RSRP [dBm]', 'FontWeight', 'bold');
            title(sprintf('RSRP Evolution (%d UEs)', num_ues_to_plot), 'FontWeight', 'bold');
            legend(arrayfun(@(x) sprintf('UE %d', x), 1:num_ues_to_plot, 'UniformOutput', false), ...
                'Location', 'best', 'NumColumns', 2);
            hold off;
            
            % SINR over time
            subplot(2, 2, 2);
            hold on; grid on;
            for i = 1:num_ues_to_plot
                ue_mask = obj.csi_data.ue_id == i;
                plot(obj.csi_data.timestamp(ue_mask), obj.csi_data.sinr(ue_mask), ...
                    'o-', 'Color', colors(i,:), 'LineWidth', 1.5, 'MarkerSize', 4);
            end
            xlabel('Time [s]', 'FontWeight', 'bold');
            ylabel('SINR [dB]', 'FontWeight', 'bold');
            title(sprintf('SINR Evolution (%d UEs)', num_ues_to_plot), 'FontWeight', 'bold');
            hold off;
            
            % Average metrics over time
            subplot(2, 2, 3);
            unique_times = unique(obj.csi_data.timestamp(valid_mask));
            avg_rsrp = zeros(length(unique_times), 1);
            avg_sinr = zeros(length(unique_times), 1);
            for i = 1:length(unique_times)
                time_mask = obj.csi_data.timestamp == unique_times(i);
                avg_rsrp(i) = mean(obj.csi_data.rsrp(time_mask));
                avg_sinr(i) = mean(obj.csi_data.sinr(time_mask));
            end
            yyaxis left;
            plot(unique_times, avg_rsrp, 'b-o', 'LineWidth', 2, 'MarkerSize', 5);
            ylabel('Average RSRP [dBm]', 'FontWeight', 'bold');
            yyaxis right;
            plot(unique_times, avg_sinr, 'r-s', 'LineWidth', 2, 'MarkerSize', 5);
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            xlabel('Time [s]', 'FontWeight', 'bold');
            title('Network-Wide Average Metrics', 'FontWeight', 'bold');
            grid on;
            
            % CQI over time
            subplot(2, 2, 4);
            hold on; grid on;
            for i = 1:num_ues_to_plot
                ue_mask = obj.csi_data.ue_id == i;
                stairs(obj.csi_data.timestamp(ue_mask), obj.csi_data.cqi(ue_mask), ...
                    'Color', colors(i,:), 'LineWidth', 1.5);
            end
            xlabel('Time [s]', 'FontWeight', 'bold');
            ylabel('CQI', 'FontWeight', 'bold');
            title(sprintf('CQI Evolution (%d UEs)', num_ues_to_plot), 'FontWeight', 'bold');
            ylim([0, 15]);
            hold off;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '03_temporal_evolution.png']);
            saveas(fig, [obj.figures_dir, '03_temporal_evolution.fig']);
        end
        
        
        function plot_spatial_analysis(obj)
            % PLOT_SPATIAL_ANALYSIS Spatial distribution analysis
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Spatial Analysis', 'Position', [200, 200, 1400, 700], 'Visible', visibility);
            
            valid_mask = obj.csi_data.ue_id > 0;
            x = obj.csi_data.x(valid_mask);
            y = obj.csi_data.y(valid_mask);
            
            % Distance to BS vs RSRP
            subplot(2, 3, 1);
            scatter(obj.csi_data.distance(valid_mask), obj.csi_data.rsrp(valid_mask), ...
                20, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
            xlabel('Distance to Serving BS [m]', 'FontWeight', 'bold');
            ylabel('RSRP [dBm]', 'FontWeight', 'bold');
            title('RSRP vs Distance', 'FontWeight', 'bold');
            grid on;
            
            % Distance to BS vs SINR
            subplot(2, 3, 2);
            scatter(obj.csi_data.distance(valid_mask), obj.csi_data.sinr(valid_mask), ...
                20, 'g', 'filled', 'MarkerFaceAlpha', 0.5);
            xlabel('Distance to Serving BS [m]', 'FontWeight', 'bold');
            ylabel('SINR [dB]', 'FontWeight', 'bold');
            title('SINR vs Distance', 'FontWeight', 'bold');
            grid on;
            
            % 2D density plot
            subplot(2, 3, 3);
            histogram2(x, y, 20, 'DisplayStyle', 'tile', 'ShowEmptyBins', 'on');
            colorbar;
            xlabel('X [m]', 'FontWeight', 'bold');
            ylabel('Y [m]', 'FontWeight', 'bold');
            title('UE Position Density', 'FontWeight', 'bold');
            axis equal tight;
            
            % RSRP by BS
            subplot(2, 3, 4);
            bs1_mask = valid_mask & obj.csi_data.serving_bs == 1;
            bs2_mask = valid_mask & obj.csi_data.serving_bs == 2;
            histogram(obj.csi_data.rsrp(bs1_mask), 30, 'FaceColor', 'b', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            hold on;
            histogram(obj.csi_data.rsrp(bs2_mask), 30, 'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            xlabel('RSRP [dBm]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('RSRP by Serving BS', 'FontWeight', 'bold');
            legend({'BS 1', 'BS 2'}, 'Location', 'best');
            grid on;
            hold off;
            
            % SINR by BS
            subplot(2, 3, 5);
            histogram(obj.csi_data.sinr(bs1_mask), 30, 'FaceColor', 'b', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            hold on;
            histogram(obj.csi_data.sinr(bs2_mask), 30, 'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            xlabel('SINR [dB]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('SINR by Serving BS', 'FontWeight', 'bold');
            legend({'BS 1', 'BS 2'}, 'Location', 'best');
            grid on;
            hold off;
            
            % Distance distribution
            subplot(2, 3, 6);
            histogram(obj.csi_data.distance(valid_mask), 40, 'FaceColor', 'm', 'EdgeColor', 'k');
            xlabel('Distance to Serving BS [m]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('Distance Distribution', 'FontWeight', 'bold');
            grid on;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '04_spatial_analysis.png']);
            saveas(fig, [obj.figures_dir, '04_spatial_analysis.fig']);
        end
        
        
        function plot_per_ue_performance(obj)
            % PLOT_PER_UE_PERFORMANCE Performance comparison across UEs
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Per-UE Performance', 'Position', [250, 250, 1400, 700], 'Visible', visibility);
            
            % Calculate per-UE averages
            ue_ids = 1:obj.stats.num_ues;
            avg_rsrp = zeros(obj.stats.num_ues, 1);
            avg_sinr = zeros(obj.stats.num_ues, 1);
            avg_cqi = zeros(obj.stats.num_ues, 1);
            
            for ue_id = ue_ids
                avg_rsrp(ue_id) = obj.stats.per_ue(ue_id).rsrp_mean;
                avg_sinr(ue_id) = obj.stats.per_ue(ue_id).sinr_mean;
                avg_cqi(ue_id) = obj.stats.per_ue(ue_id).cqi_mean;
            end
            
            % Average RSRP per UE
            subplot(2, 2, 1);
            bar(ue_ids, avg_rsrp, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('UE ID', 'FontWeight', 'bold');
            ylabel('Average RSRP [dBm]', 'FontWeight', 'bold');
            title('Average RSRP per UE', 'FontWeight', 'bold');
            grid on;
            
            % Average SINR per UE
            subplot(2, 2, 2);
            bar(ue_ids, avg_sinr, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('UE ID', 'FontWeight', 'bold');
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('Average SINR per UE', 'FontWeight', 'bold');
            grid on;
            
            % Average CQI per UE
            subplot(2, 2, 3);
            bar(ue_ids, avg_cqi, 'FaceColor', 'r', 'EdgeColor', 'k');
            xlabel('UE ID', 'FontWeight', 'bold');
            ylabel('Average CQI', 'FontWeight', 'bold');
            title('Average CQI per UE', 'FontWeight', 'bold');
            grid on;
            
            % Ranking
            subplot(2, 2, 4);
            [sorted_sinr, sorted_idx] = sort(avg_sinr, 'descend');
            top_10 = sorted_idx(1:min(10, length(sorted_idx)));
            bottom_10 = sorted_idx(max(1, end-9):end);
            
            hold on;
            bar(1:min(10, length(top_10)), avg_sinr(top_10), 'FaceColor', 'g', 'EdgeColor', 'k');
            bar((11):(10+length(bottom_10)), avg_sinr(bottom_10), 'FaceColor', 'r', 'EdgeColor', 'k');
            xlabel('Rank', 'FontWeight', 'bold');
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('Top 10 and Bottom 10 UEs by SINR', 'FontWeight', 'bold');
            legend({'Top 10', 'Bottom 10'}, 'Location', 'best');
            grid on;
            hold off;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '05_per_ue_performance.png']);
            saveas(fig, [obj.figures_dir, '05_per_ue_performance.fig']);
        end
        
        
        function plot_area_analysis(obj)
            % PLOT_AREA_ANALYSIS Performance by area
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Area Analysis', 'Position', [300, 300, 1400, 700], 'Visible', visibility);
            
            valid_mask = obj.csi_data.ue_id > 0;
            num_areas = length(obj.engine.areas);
            
            % Calculate per-area statistics
            area_rsrp_mean = zeros(num_areas, 1);
            area_sinr_mean = zeros(num_areas, 1);
            area_counts = zeros(num_areas, 1);
            
            for area_id = 1:num_areas
                area_mask = valid_mask & obj.csi_data.area_id == area_id;
                if sum(area_mask) > 0
                    area_rsrp_mean(area_id) = mean(obj.csi_data.rsrp(area_mask));
                    area_sinr_mean(area_id) = mean(obj.csi_data.sinr(area_mask));
                    area_counts(area_id) = sum(area_mask);
                end
            end
            
            % RSRP by area
            subplot(2, 2, 1);
            bar(1:num_areas, area_rsrp_mean, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('Area ID', 'FontWeight', 'bold');
            ylabel('Average RSRP [dBm]', 'FontWeight', 'bold');
            title('Average RSRP by Area', 'FontWeight', 'bold');
            grid on;
            
            % SINR by area
            subplot(2, 2, 2);
            bar(1:num_areas, area_sinr_mean, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('Area ID', 'FontWeight', 'bold');
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('Average SINR by Area', 'FontWeight', 'bold');
            grid on;
            
            % Samples per area
            subplot(2, 2, 3);
            bar(1:num_areas, area_counts, 'FaceColor', 'r', 'EdgeColor', 'k');
            xlabel('Area ID', 'FontWeight', 'bold');
            ylabel('Number of Samples', 'FontWeight', 'bold');
            title('Samples per Area', 'FontWeight', 'bold');
            grid on;
            
            % Area types
            subplot(2, 2, 4);
            area_type_labels = cell(num_areas, 1);
            for i = 1:num_areas
                area_type_labels{i} = sprintf('A%d: %s', i, strrep(obj.engine.areas(i).area_type, '_', ' '));
            end
            
            bar(1:num_areas, area_sinr_mean);
            set(gca, 'XTick', 1:num_areas, 'XTickLabel', area_type_labels, 'XTickLabelRotation', 45);
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('SINR by Area Type', 'FontWeight', 'bold');
            grid on;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '06_area_analysis.png']);
            saveas(fig, [obj.figures_dir, '06_area_analysis.fig']);
        end
        
        
        function plot_mobility_analysis(obj)
            % PLOT_MOBILITY_ANALYSIS Mobility patterns
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'Mobility Analysis', 'Position', [350, 350, 1400, 700], 'Visible', visibility);
            
            % Calculate mobility statistics per UE
            ue_distances = zeros(obj.stats.num_ues, 1);
            ue_velocities = zeros(obj.stats.num_ues, 1);
            
            for ue_id = 1:obj.stats.num_ues
                traj = obj.engine.trajectory_data{ue_id};
                if size(traj, 1) > 1
                    diffs = diff(traj);
                    distances = sqrt(sum(diffs.^2, 2));
                    ue_distances(ue_id) = sum(distances);
                    ue_velocities(ue_id) = mean(distances) / obj.config.timing.position_update_dt;
                end
            end
            
            % Total distance traveled
            subplot(2, 2, 1);
            histogram(ue_distances, 30, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('Total Distance [m]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('Total Distance Traveled per UE', 'FontWeight', 'bold');
            grid on;
            
            % Average velocity
            subplot(2, 2, 2);
            histogram(ue_velocities, 30, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('Average Velocity [m/s]', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('Average Velocity per UE', 'FontWeight', 'bold');
            grid on;
            
            % Distance vs SINR
            subplot(2, 2, 3);
            valid_mask = obj.csi_data.ue_id > 0;
            ue_avg_sinr = zeros(obj.stats.num_ues, 1);
            for ue_id = 1:obj.stats.num_ues
                ue_mask = obj.csi_data.ue_id == ue_id;
                ue_avg_sinr(ue_id) = mean(obj.csi_data.sinr(ue_mask));
            end
            scatter(ue_distances, ue_avg_sinr, 50, 'r', 'filled');
            xlabel('Total Distance Traveled [m]', 'FontWeight', 'bold');
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('Mobility Impact on SINR', 'FontWeight', 'bold');
            grid on;
            
            % Velocity vs SINR
            subplot(2, 2, 4);
            scatter(ue_velocities, ue_avg_sinr, 50, 'm', 'filled');
            xlabel('Average Velocity [m/s]', 'FontWeight', 'bold');
            ylabel('Average SINR [dB]', 'FontWeight', 'bold');
            title('Velocity Impact on SINR', 'FontWeight', 'bold');
            grid on;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '07_mobility_analysis.png']);
            saveas(fig, [obj.figures_dir, '07_mobility_analysis.fig']);
        end
        
        
        function plot_cqi_analysis(obj)
            % PLOT_CQI_ANALYSIS Detailed CQI analysis
            
            if obj.config.output.show_figures
                visibility = 'on';
            else
                visibility = 'off';
            end
            fig = figure('Name', 'CQI Analysis', 'Position', [400, 400, 1400, 700], 'Visible', visibility);
            
            valid_mask = obj.csi_data.ue_id > 0;
            
            % CQI distribution
            subplot(2, 3, 1);
            histogram(obj.csi_data.cqi(valid_mask), 0:15, 'FaceColor', 'b', 'EdgeColor', 'k');
            xlabel('CQI', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('CQI Distribution', 'FontWeight', 'bold');
            grid on;
            xlim([-0.5, 15.5]);
            
            % CQI percentage
            subplot(2, 3, 2);
            cqi_counts = histcounts(obj.csi_data.cqi(valid_mask), 0:16);
            cqi_percent = 100 * cqi_counts / sum(cqi_counts);
            bar(0:15, cqi_percent, 'FaceColor', 'g', 'EdgeColor', 'k');
            xlabel('CQI', 'FontWeight', 'bold');
            ylabel('Percentage [%]', 'FontWeight', 'bold');
            title('CQI Percentage', 'FontWeight', 'bold');
            grid on;
            
            % CQI vs SINR
            subplot(2, 3, 3);
            scatter(obj.csi_data.sinr(valid_mask), obj.csi_data.cqi(valid_mask), ...
                20, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
            xlabel('SINR [dB]', 'FontWeight', 'bold');
            ylabel('CQI', 'FontWeight', 'bold');
            title('CQI vs SINR', 'FontWeight', 'bold');
            grid on;
            
            % CQI by BS
            subplot(2, 3, 4);
            bs1_mask = valid_mask & obj.csi_data.serving_bs == 1;
            bs2_mask = valid_mask & obj.csi_data.serving_bs == 2;
            histogram(obj.csi_data.cqi(bs1_mask), 0:15, 'FaceColor', 'b', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            hold on;
            histogram(obj.csi_data.cqi(bs2_mask), 0:15, 'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.5);
            xlabel('CQI', 'FontWeight', 'bold');
            ylabel('Count', 'FontWeight', 'bold');
            title('CQI by Serving BS', 'FontWeight', 'bold');
            legend({'BS 1', 'BS 2'}, 'Location', 'best');
            grid on;
            xlim([-0.5, 15.5]);
            hold off;
            
            % CQI over time (aggregate)
            subplot(2, 3, 5);
            unique_times = unique(obj.csi_data.timestamp(valid_mask));
            avg_cqi = zeros(length(unique_times), 1);
            for i = 1:length(unique_times)
                time_mask = obj.csi_data.timestamp == unique_times(i);
                avg_cqi(i) = mean(obj.csi_data.cqi(time_mask));
            end
            plot(unique_times, avg_cqi, 'b-o', 'LineWidth', 2, 'MarkerSize', 5);
            xlabel('Time [s]', 'FontWeight', 'bold');
            ylabel('Average CQI', 'FontWeight', 'bold');
            title('Average CQI Evolution', 'FontWeight', 'bold');
            grid on;
            
            % CQI statistics
            subplot(2, 3, 6);
            cqi_stats = [
                sum(obj.csi_data.cqi(valid_mask) >= 12) / sum(valid_mask) * 100;
                sum(obj.csi_data.cqi(valid_mask) >= 9) / sum(valid_mask) * 100;
                sum(obj.csi_data.cqi(valid_mask) >= 6) / sum(valid_mask) * 100;
                sum(obj.csi_data.cqi(valid_mask) >= 3) / sum(valid_mask) * 100;
            ];
            bar(categorical({'CQI>=12', 'CQI>=9', 'CQI>=6', 'CQI>=3'}), cqi_stats, ...
                'FaceColor', 'm', 'EdgeColor', 'k');
            ylabel('Percentage [%]', 'FontWeight', 'bold');
            title('CQI Thresholds', 'FontWeight', 'bold');
            grid on;
            
            % Save figure
            saveas(fig, [obj.figures_dir, '08_cqi_analysis.png']);
            saveas(fig, [obj.figures_dir, '08_cqi_analysis.fig']);
        end
        
        
        function generate_html_report(obj)
            % GENERATE_HTML_REPORT Create HTML summary report
            
            html_file = [obj.reports_dir, 'simulation_report.html'];
            fid = fopen(html_file, 'w');
            
            % HTML header
            fprintf(fid, '<!DOCTYPE html>\n');
            fprintf(fid, '<html>\n<head>\n');
            fprintf(fid, '<title>QuaDRiGa Simulation Report</title>\n');
            fprintf(fid, '<style>\n');
            fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 40px; }\n');
            fprintf(fid, 'h1 { color: #2c3e50; }\n');
            fprintf(fid, 'h2 { color: #34495e; border-bottom: 2px solid #3498db; padding-bottom: 10px; }\n');
            fprintf(fid, 'table { border-collapse: collapse; width: 100%%; margin: 20px 0; }\n');
            fprintf(fid, 'th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n');
            fprintf(fid, 'th { background-color: #3498db; color: white; }\n');
            fprintf(fid, 'tr:nth-child(even) { background-color: #f2f2f2; }\n');
            fprintf(fid, '.stat { font-weight: bold; color: #2980b9; }\n');
            fprintf(fid, 'img { max-width: 100%%; height: auto; margin: 20px 0; border: 1px solid #ddd; }\n');
            fprintf(fid, '</style>\n');
            fprintf(fid, '</head>\n<body>\n');
            
            % Title
            fprintf(fid, '<h1>QuaDRiGa Massive MIMO Simulation Report</h1>\n');
            fprintf(fid, '<p><strong>Generated:</strong> %s</p>\n', datestr(now));
            fprintf(fid, '<p><strong>Output Directory:</strong> %s</p>\n', obj.output_dir);
            
            % Configuration
            fprintf(fid, '<h2>Configuration</h2>\n');
            fprintf(fid, '<table>\n');
            fprintf(fid, '<tr><th>Parameter</th><th>Value</th></tr>\n');
            fprintf(fid, '<tr><td>Number of UEs</td><td>%d</td></tr>\n', obj.stats.num_ues);
            fprintf(fid, '<tr><td>Number of BSs</td><td>%d</td></tr>\n', obj.config.bs.num);
            fprintf(fid, '<tr><td>Simulation Duration</td><td>%.0f seconds (%.1f min)</td></tr>\n', ...
                obj.stats.duration, obj.stats.duration/60);
            fprintf(fid, '<tr><td>Frequency</td><td>%.2f GHz</td></tr>\n', obj.config.frequency/1e9);
            fprintf(fid, '<tr><td>BS MIMO</td><td>%dx%d (%dx%d array)</td></tr>\n', ...
                obj.config.bs.num_tx, obj.config.bs.num_rx, ...
                obj.config.bs.array_rows, obj.config.bs.array_cols);
            fprintf(fid, '<tr><td>UE MIMO</td><td>%dx%d (%dx%d array)</td></tr>\n', ...
                obj.config.ue.num_tx, obj.config.ue.num_rx, ...
                obj.config.ue.array_rows, obj.config.ue.array_cols);
            fprintf(fid, '<tr><td>Total CSI Reports</td><td>%d</td></tr>\n', obj.stats.num_reports);
            fprintf(fid, '</table>\n');
            
            % Statistics
            fprintf(fid, '<h2>Statistics</h2>\n');
            fprintf(fid, '<table>\n');
            fprintf(fid, '<tr><th>Metric</th><th>Mean</th><th>Std Dev</th><th>Min</th><th>Max</th></tr>\n');
            fprintf(fid, '<tr><td>RSRP [dBm]</td><td class="stat">%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>\n', ...
                obj.stats.rsrp_mean, obj.stats.rsrp_std, obj.stats.rsrp_min, obj.stats.rsrp_max);
            fprintf(fid, '<tr><td>SINR [dB]</td><td class="stat">%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>\n', ...
                obj.stats.sinr_mean, obj.stats.sinr_std, obj.stats.sinr_min, obj.stats.sinr_max);
            fprintf(fid, '<tr><td>CQI</td><td class="stat">%.2f</td><td>-</td><td>-</td><td>-</td></tr>\n', ...
                obj.stats.cqi_mean);
            fprintf(fid, '</table>\n');
            
            % Figures
            fprintf(fid, '<h2>Visualizations</h2>\n');
            
            % List all figures
            fig_files = dir([obj.figures_dir, '*.png']);
            for i = 1:length(fig_files)
                fig_name = fig_files(i).name;
                fprintf(fid, '<h3>%s</h3>\n', strrep(fig_name(4:end-4), '_', ' '));
                fprintf(fid, '<img src="../figures/%s" alt="%s">\n', fig_name, fig_name);
            end
            
            % Files
            fprintf(fid, '<h2>Output Files</h2>\n');
            fprintf(fid, '<h3>CSV Files</h3>\n');
            fprintf(fid, '<ul>\n');
            fprintf(fid, '<li><strong>Combined:</strong> <code>csv/all_ues_combined.csv</code> - All UE data</li>\n');
            fprintf(fid, '<li><strong>Per-UE:</strong> <code>csv/ue_001.csv</code> to <code>csv/ue_%03d.csv</code> - Individual UE data</li>\n', ...
                obj.stats.num_ues);
            fprintf(fid, '</ul>\n');
            
            fprintf(fid, '<h3>Figures</h3>\n');
            fprintf(fid, '<ul>\n');
            for i = 1:length(fig_files)
                fprintf(fid, '<li><code>figures/%s</code></li>\n', fig_files(i).name);
            end
            fprintf(fid, '</ul>\n');
            
            % Footer
            fprintf(fid, '<hr>\n');
            fprintf(fid, '<p><em>Report generated by ResultsManager - QuaDRiGa Massive MIMO Simulation</em></p>\n');
            fprintf(fid, '</body>\n</html>\n');
            
            fclose(fid);
            
            fprintf('  HTML report: %s\n', html_file);
        end
        
    end
end