classdef AreaGenerator
% AREAGENERATOR - Generate simulation areas using Voronoi tessellation
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static class is responsible for generating the physical topology of the
% simulation environment. It divides the map into Voronoi polygons, assigns
% specific geographical characteristics (e.g., shopping center, residential),
% and matches them with appropriate 3GPP channel models (scenarios).
%
% Static methods for:
%   - Generating random Voronoi seeds
%   - Assigning scenarios and area types with logical matching
%   - Visualizing areas

    methods (Static)
        
        function areas = generate(config)
            % GENERATE Create random areas using Voronoi tessellation
            %
            % Input:
            %   config - simulation configuration struct
            %
            % Output:
            %   areas - struct array with fields:
            %           - id: area identifier
            %           - seed: [x, y] Voronoi seed point
            %           - scenario: QuaDRiGa scenario string (matched to area_type)
            %           - area_type: traffic category string
            %           - transition_width: meters
            %
            % Example:
            %   config = SimulationConfig();
            %   areas = AreaGenerator.generate(config);
            
            % Set random seed for reproducibility
            if isfield(config, 'random_seed_areas')
                rng(config.random_seed_areas);
                fprintf('[AreaGenerator] Using area random seed: %d\n', config.random_seed_areas);
            end
            
            fprintf('[AreaGenerator] Generating %d areas...\n', config.num_areas);
            
            % Extract parameters
            num_areas = config.num_areas;
            bounds = config.area_bounds;
            area_types = config.area_types;
            transition_width = config.transition_width;
            
            % Generate random seeds
            seeds = AreaGenerator.generate_random_seeds(num_areas, bounds);
            
            % Initialize areas struct array
            areas = struct();
            
            % Create each area
            for i = 1:num_areas
                areas(i).id = i;
                areas(i).seed = seeds(i, :);
                
                % Randomly assign area type
                areas(i).area_type = AreaGenerator.assign_random_area_type(area_types);
                
                % Assign matching scenario based on area type
                areas(i).scenario = AreaGenerator.assign_matching_scenario(areas(i).area_type);
                
                % Set transition width
                areas(i).transition_width = transition_width;
            end
            
            % Validate all seeds are within bounds
            for i = 1:num_areas
                if ~GeometryUtils.check_if_in_bounds(areas(i).seed, bounds)
                    error('Area %d seed [%.1f, %.1f] is outside bounds', ...
                        i, areas(i).seed(1), areas(i).seed(2));
                end
            end
            
            fprintf('[AreaGenerator] Successfully created %d areas\n', num_areas);
            
            % Print summary
            AreaGenerator.print_area_summary(areas);
        end
        
        
        function seeds = generate_random_seeds(num_areas, bounds)
            % GENERATE_RANDOM_SEEDS Create random Voronoi seed points
            %
            % Input:
            %   num_areas - number of seeds to generate
            %   bounds    - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   seeds - [Nx2] matrix of [x, y] coordinates
            
            x_min = bounds(1);
            x_max = bounds(2);
            y_min = bounds(3);
            y_max = bounds(4);
            
            % Generate random x coordinates
            x_coords = x_min + (x_max - x_min) * rand(num_areas, 1);
            
            % Generate random y coordinates
            y_coords = y_min + (y_max - y_min) * rand(num_areas, 1);
            
            % Combine into [Nx2] matrix
            seeds = [x_coords, y_coords];
        end
        
        
        function scenario = assign_matching_scenario(area_type)
            % ASSIGN_MATCHING_SCENARIO Assign appropriate scenario based on area type
            %
            % Input:
            %   area_type - string ('shopping_center', 'residential', etc.)
            %
            % Output:
            %   scenario - QuaDRiGa scenario string
            %
            % Logic:
            %   shopping_center -> UMi_NLOS (indoor, enclosed)
            %   residential     -> UMi_LOS/NLOS (mixed, 50/50)
            %   office          -> UMi_NLOS (buildings)
            %   highway         -> RMa_LOS (open, fast)
            %   parking_lot     -> UMi_LOS (open)
            %   park            -> UMi_LOS (open spaces)
            
            switch area_type
                case 'shopping_center'
                    scenario = '3GPP_38.901_UMi_NLOS';  % Indoor/enclosed
                    
                case 'residential'
                    % 50/50 chance of LOS or NLOS
                    if rand() < 0.5
                        scenario = '3GPP_38.901_UMi_LOS';
                    else
                        scenario = '3GPP_38.901_UMi_NLOS';
                    end
                    
                case 'office'
                    scenario = '3GPP_38.901_UMi_NLOS';  % Buildings
                    
                case 'highway'
                    scenario = '3GPP_38.901_RMa_LOS';   % Open, rural macro
                    
                case 'parking_lot'
                    scenario = '3GPP_38.901_UMi_LOS';   % Open
                    
                case 'park'
                    scenario = '3GPP_38.901_UMi_LOS';   % Open spaces
                    
                otherwise
                    % Default fallback
                    warning('Unknown area type: %s. Using UMi as default.', area_type);
                    scenario = '3GPP_38.901_UMi';
            end
        end
        
        
        function area_type = assign_random_area_type(area_types_list)
            % ASSIGN_RANDOM_AREA_TYPE Randomly select an area type
            %
            % Input:
            %   area_types_list - cell array of area type strings
            %
            % Output:
            %   area_type - randomly selected area type string
            
            num_types = length(area_types_list);
            idx = randi(num_types);
            area_type = area_types_list{idx};
        end
        
        
        function print_area_summary(areas)
            % PRINT_AREA_SUMMARY Display summary of created areas
            %
            % Input:
            %   areas - struct array of areas
            
            fprintf('\n--- Area Summary ---\n');
            for i = 1:length(areas)
                fprintf('Area %d: seed=[%.1f, %.1f], type=%s, scenario=%s\n', ...
                    areas(i).id, areas(i).seed(1), areas(i).seed(2), ...
                    areas(i).area_type, areas(i).scenario);
            end
            fprintf('-------------------\n\n');
        end
        
        
        function fig = plot_areas_combined(areas, config, ue_positions)
            % PLOT_AREAS_COMBINED Visualize Voronoi areas in single figure with subplots
            %
            % Input:
            %   areas        - struct array of areas
            %   config       - simulation config
            %   ue_positions - (optional) [Nx2] matrix of UE positions to overlay
            %
            % Output:
            %   fig - figure handle
            %
            % Creates a single figure with 3 subplots:
            %   1. Voronoi tessellation with area types
            %   2. Same with UE positions (if provided)
            %   3. Traffic load heatmap
            
            if nargin < 3
                ue_positions = [];
            end
            
            % Create figure with subplots
            fig = figure('Name', 'Voronoi Area Analysis', 'Position', [50, 50, 1600, 500]);
            
            % Calculate traffic loads for heatmap
            timestamp = config.simulation_datetime;
            loads = zeros(length(areas), 1);
            for i = 1:length(areas)
                loads(i) = TrafficUtils.get_area_load(areas(i).area_type, timestamp, config);
            end
            
            % Subplot 1: Basic Voronoi tessellation
            subplot(1, 3, 1);
            AreaGenerator.plot_voronoi_diagram(areas, config, [], 'Area Types');
            
            % Subplot 2: Voronoi with UEs
            subplot(1, 3, 2);
            if ~isempty(ue_positions)
                AreaGenerator.plot_voronoi_diagram(areas, config, ue_positions, 'With UE Positions');
            else
                AreaGenerator.plot_voronoi_diagram(areas, config, [], 'Areas (No UEs)');
            end
            
            % Subplot 3: Traffic load heatmap
            subplot(1, 3, 3);
            AreaGenerator.plot_heatmap_only(areas, config, loads, 'Traffic Load');
            
            fprintf('[AreaGenerator] Combined area visualization created\n');
        end
        
        
        function plot_voronoi_diagram(areas, config, ue_positions, title_text)
            % PLOT_VORONOI_DIAGRAM Plot Voronoi tessellation (internal helper)
            
            hold on;
            grid on;
            
            % Extract bounds
            x_min = config.area_bounds(1);
            x_max = config.area_bounds(2);
            y_min = config.area_bounds(3);
            y_max = config.area_bounds(4);
            
            % Extract seeds
            num_areas = length(areas);
            seeds = zeros(num_areas, 2);
            for i = 1:num_areas
                seeds(i, :) = areas(i).seed;
            end
            
            % Create fine grid for Voronoi visualization
            grid_resolution = 200;
            x_grid = linspace(x_min, x_max, grid_resolution);
            y_grid = linspace(y_min, y_max, grid_resolution);
            [X, Y] = meshgrid(x_grid, y_grid);
            
            % Assign each grid point to nearest seed
            Z = zeros(size(X));
            for i = 1:numel(X)
                point = [X(i), Y(i)];
                area_idx = GeometryUtils.find_area(point, areas);
                Z(i) = area_idx;
            end
            
            % Plot Voronoi regions with colors
            imagesc(x_grid, y_grid, Z);
            colormap(gca, jet(num_areas));
            alpha(0.3);  % Make semi-transparent
            
            % Plot Voronoi boundaries using voronoi function
            if num_areas >= 3  % voronoi needs at least 3 points
                h = voronoi(seeds(:,1), seeds(:,2), 'k-');
                set(h, 'LineWidth', 1.5);
            end
            
            % Define marker styles for different area types
            type_markers = containers.Map(...
                {'shopping_center', 'residential', 'office', 'highway', 'parking_lot', 'park'}, ...
                {'s', 'o', '^', 'd', 'p', 'h'});  % square, circle, triangle, diamond, pentagon, hexagon
            
            type_colors = containers.Map(...
                {'shopping_center', 'residential', 'office', 'highway', 'parking_lot', 'park'}, ...
                {'r', 'b', 'c', 'k', 'y', 'g'});
            
            % Plot seeds with different markers based on area type
            for i = 1:num_areas
                area_type = areas(i).area_type;
                
                % Get marker and color for this type
                if isKey(type_markers, area_type)
                    marker = type_markers(area_type);
                    color = type_colors(area_type);
                else
                    marker = 'o';
                    color = 'k';
                end
                
                % Plot seed
                plot(areas(i).seed(1), areas(i).seed(2), ...
                    'Marker', marker, ...
                    'MarkerSize', 12, ...
                    'MarkerFaceColor', color, ...
                    'MarkerEdgeColor', 'k', ...
                    'LineWidth', 2);
                
                % Add area ID label
                text(areas(i).seed(1), areas(i).seed(2) + 5, ...
                    sprintf('A%d', i), ...
                    'FontSize', 9, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', 'white', ...
                    'EdgeColor', 'black');
            end
            
            % Plot UE positions if provided
            if ~isempty(ue_positions)
                scatter(ue_positions(:,1), ue_positions(:,2), ...
                    30, 'w', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            end
            
            % Plot BS positions if available in config
            if isfield(config, 'bs') && isfield(config.bs, 'positions')
                bs_pos = config.bs.positions;
                scatter(bs_pos(:,1), bs_pos(:,2), ...
                    200, 'r', '^', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 2);
            end
            
            % Set axis properties
            axis equal;
            xlim([x_min, x_max]);
            ylim([y_min, y_max]);
            xlabel('X Position [m]', 'FontSize', 10, 'FontWeight', 'bold');
            ylabel('Y Position [m]', 'FontSize', 10, 'FontWeight', 'bold');
            title(title_text, 'FontSize', 12, 'FontWeight', 'bold');
            
            % Create legend for area types with correct markers
            legend_entries = {};
            legend_handles = [];
            unique_types = unique({areas.area_type});
            
            for i = 1:length(unique_types)
                area_type = unique_types{i};
                if isKey(type_markers, area_type) && isKey(type_colors, area_type)
                    marker = type_markers(area_type);
                    color = type_colors(area_type);
                else
                    marker = 'o';
                    color = 'k';
                end
                
                h = plot(NaN, NaN, marker, 'MarkerSize', 8, ...
                    'MarkerFaceColor', color, 'MarkerEdgeColor', 'k', ...
                    'LineWidth', 1.5);
                legend_handles = [legend_handles, h];
                legend_entries{end+1} = strrep(area_type, '_', ' ');
            end
            
            % Add BS to legend if plotted
            if isfield(config, 'bs') && isfield(config.bs, 'positions')
                h = plot(NaN, NaN, '^', 'MarkerSize', 10, ...
                    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
                legend_handles = [legend_handles, h];
                legend_entries{end+1} = 'Base Stations';
            end
            
            % Add UEs to legend if plotted
            if ~isempty(ue_positions)
                h = plot(NaN, NaN, 'o', 'MarkerSize', 6, ...
                    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
                legend_handles = [legend_handles, h];
                legend_entries{end+1} = sprintf('UEs (%d)', size(ue_positions, 1));
            end
            
            legend(legend_handles, legend_entries, 'Location', 'best', 'FontSize', 8);
            
            hold off;
        end
        
        
        function plot_heatmap_only(areas, config, metric_values, metric_name)
            % PLOT_HEATMAP_ONLY Plot heatmap of a metric (internal helper)
            
            hold on;
            grid on;
            
            % Extract bounds
            x_min = config.area_bounds(1);
            x_max = config.area_bounds(2);
            y_min = config.area_bounds(3);
            y_max = config.area_bounds(4);
            
            % Extract seeds
            num_areas = length(areas);
            seeds = zeros(num_areas, 2);
            for i = 1:num_areas
                seeds(i, :) = areas(i).seed;
            end
            
            % Create grid
            grid_resolution = 200;
            x_grid = linspace(x_min, x_max, grid_resolution);
            y_grid = linspace(y_min, y_max, grid_resolution);
            [X, Y] = meshgrid(x_grid, y_grid);
            
            % Assign metric value to each grid point
            Z = zeros(size(X));
            for i = 1:numel(X)
                point = [X(i), Y(i)];
                area_idx = GeometryUtils.find_area(point, areas);
                Z(i) = metric_values(area_idx);
            end
            
            % Plot heatmap
            imagesc(x_grid, y_grid, Z);
            colormap(gca, hot);
            cb = colorbar('FontSize', 9, 'FontWeight', 'bold');
            ylabel(cb, metric_name, 'FontSize', 9, 'FontWeight', 'bold');
            
            % Plot Voronoi boundaries
            if num_areas >= 3
                h = voronoi(seeds(:,1), seeds(:,2), 'k-');
                set(h, 'LineWidth', 1.5);
            end
            
            % Plot seeds
            scatter(seeds(:,1), seeds(:,2), 100, 'b', 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 2);
            
            % Add labels showing metric values
            for i = 1:num_areas
                text(areas(i).seed(1), areas(i).seed(2) + 5, ...
                    sprintf('%.2f', metric_values(i)), ...
                    'FontSize', 9, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', 'white', ...
                    'EdgeColor', 'black');
            end
            
            % Set axis properties
            axis equal;
            xlim([x_min, x_max]);
            ylim([y_min, y_max]);
            xlabel('X Position [m]', 'FontSize', 10, 'FontWeight', 'bold');
            ylabel('Y Position [m]', 'FontSize', 10, 'FontWeight', 'bold');
            title(['Heatmap: ' metric_name], 'FontSize', 12, 'FontWeight', 'bold');
            
            % Add explanation text
            text(x_min + 5, y_max - 5, ...
                sprintf('Values represent %s by area.\nHigher values = darker red.', lower(metric_name)), ...
                'FontSize', 8, 'BackgroundColor', 'white', ...
                'EdgeColor', 'black', 'VerticalAlignment', 'top');
            
            hold off;
        end
        
    end
end