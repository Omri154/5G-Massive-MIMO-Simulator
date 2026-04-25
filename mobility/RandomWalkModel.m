classdef RandomWalkModel
% RANDOMWALKMODEL - Random walk mobility model for UEs
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static class provides the physics engine for simulating User Equipment (UE) 
% movement within the simulation area. It implements a random walk mobility pattern
% where UEs move in straight lines and change speed/direction at specified intervals,
% bouncing off the boundaries of the defined area.
%
% Static methods for:
%   - Initializing random velocities and positions
%   - Updating velocities (direction and speed changes)
%   - Updating positions based on velocity and time step
%   - Batch processing for efficient handling of multiple UEs
%   - Calculating mobility statistics and generating trajectory plots

    methods (Static)
        
        function velocities = initialize_velocities(num_ues, config)
            % INITIALIZE_VELOCITIES Generate random initial velocities for all UEs
            %
            % Input:
            %   num_ues - number of UEs
            %   config  - simulation config with mobility parameters
            %
            % Output:
            %   velocities - [Nx2] matrix where each row is [vx, vy] in m/s
            %
            % Example:
            %   velocities = RandomWalkModel.initialize_velocities(100, config);
            
            % Set random seed for reproducibility
            if isfield(config, 'random_seed_mobility')
                rng(config.random_seed_mobility);
            end
            
            velocities = zeros(num_ues, 2);
            
            for i = 1:num_ues
                velocities(i, :) = RandomWalkModel.generate_random_velocity(config);
            end
            
            fprintf('[RandomWalkModel] Initialized %d random velocities\n', num_ues);
        end
        
        
        function velocity = generate_random_velocity(config)
            % GENERATE_RANDOM_VELOCITY Generate a single random velocity vector
            %
            % Input:
            %   config - simulation config with mobility parameters
            %
            % Output:
            %   velocity - [vx, vy] in m/s
            %
            % Process:
            %   1. Draw random speed from [speed_min, speed_max]
            %   2. Draw random direction from [0, 360] degrees
            %   3. Convert to velocity vector [vx, vy]
            
            % Draw random speed
            speed_min = config.mobility.speed_min;
            speed_max = config.mobility.speed_max;
            speed = speed_min + (speed_max - speed_min) * rand();
            
            % Draw random direction (0-360 degrees)
            direction_deg = config.mobility.direction_min + ...
                (config.mobility.direction_max - config.mobility.direction_min) * rand();
            
            % Convert to velocity components
            vx = speed * cosd(direction_deg);
            vy = speed * sind(direction_deg);
            
            velocity = [vx, vy];
        end
        
        
        function velocities = update_velocities(velocities, config)
            % UPDATE_VELOCITIES Update all UE velocities
            %
            % Input:
            %   velocities - [Nx2] current velocities
            %   config     - simulation config
            %
            % Output:
            %   velocities - [Nx2] new random velocities
            %
            % Called every config.mobility.update_interval seconds (typically 10s)
            % Note: Does NOT reset random seed - allows different velocities each update
            
            num_ues = size(velocities, 1);
            
            for i = 1:num_ues
                velocities(i, :) = RandomWalkModel.generate_random_velocity(config);
            end
        end
        
        
        function new_position = update_position(position, velocity, dt)
            % UPDATE_POSITION Update single UE position based on velocity
            %
            % Input:
            %   position - [x, y] current position in meters
            %   velocity - [vx, vy] current velocity in m/s
            %   dt       - time step in seconds
            %
            % Output:
            %   new_position - [x, y] new position in meters
            %
            % Physics:
            %   new_position = position + velocity * dt
            
            new_position = position + velocity * dt;
        end
        
        
        function positions = update_positions_batch(positions, velocities, dt)
            % UPDATE_POSITIONS_BATCH Update all UE positions at once
            %
            % Input:
            %   positions  - [Nx2] current positions
            %   velocities - [Nx2] current velocities
            %   dt         - time step in seconds
            %
            % Output:
            %   positions - [Nx2] new positions
            %
            % More efficient than calling update_position in a loop
            
            positions = positions + velocities * dt;
        end
        
        
        function [positions, velocities] = step(positions, velocities, dt, bounds)
            % STEP Complete mobility step: update positions and handle boundaries
            %
            % Input:
            %   positions  - [Nx2] current positions
            %   velocities - [Nx2] current velocities
            %   dt         - time step in seconds
            %   bounds     - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   positions  - [Nx2] new positions (after boundary handling)
            %   velocities - [Nx2] new velocities (reflected if hit boundary)
            %
            % This is the main function to call in the simulation loop.
            
            % Update all positions
            positions = RandomWalkModel.update_positions_batch(positions, velocities, dt);
            
            % Handle boundary collisions for all UEs
            num_ues = size(positions, 1);
            for i = 1:num_ues
                [positions(i,:), velocities(i,:)] = ...
                    GeometryUtils.reflect_velocity_at_boundary(...
                        positions(i,:), velocities(i,:), bounds);
            end
        end
        
        
        function positions = initialize_positions(num_ues, bounds)
            % INITIALIZE_POSITIONS Generate random initial positions within bounds
            %
            % Input:
            %   num_ues - number of UEs
            %   bounds  - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   positions - [Nx2] matrix of [x, y] positions
            %
            % Note: Random seed should be set by caller (e.g., AreaGenerator or SimulationEngine)
            
            x_min = bounds(1);
            x_max = bounds(2);
            y_min = bounds(3);
            y_max = bounds(4);
            
            % Random x coordinates
            x_coords = x_min + (x_max - x_min) * rand(num_ues, 1);
            
            % Random y coordinates
            y_coords = y_min + (y_max - y_min) * rand(num_ues, 1);
            
            positions = [x_coords, y_coords];
            
            fprintf('[RandomWalkModel] Initialized %d random positions\n', num_ues);
        end
        
        
        function [speed, direction] = get_velocity_polar(velocity)
            % GET_VELOCITY_POLAR Convert velocity vector to polar form
            %
            % Input:
            %   velocity - [vx, vy] in m/s
            %
            % Output:
            %   speed     - magnitude in m/s
            %   direction - angle in degrees (0 = East, 90 = North)
            %
            % Useful for analysis and debugging
            
            speed = sqrt(velocity(1)^2 + velocity(2)^2);
            direction = atan2d(velocity(2), velocity(1));
            
            % Convert to 0-360 range
            if direction < 0
                direction = direction + 360;
            end
        end
        
        
        function stats = get_mobility_statistics(positions, velocities)
            % GET_MOBILITY_STATISTICS Calculate statistics about UE mobility
            %
            % Input:
            %   positions  - [Nx2] current positions
            %   velocities - [Nx2] current velocities
            %
            % Output:
            %   stats - struct with fields:
            %           - num_ues: number of UEs
            %           - mean_position: [x, y] mean position
            %           - std_position: [x, y] position std deviation
            %           - mean_speed: average speed
            %           - max_speed: maximum speed
            %           - min_speed: minimum speed
            %           - num_stationary: number of UEs with speed close to 0
            
            num_ues = size(positions, 1);
            
            % Position statistics
            stats.num_ues = num_ues;
            stats.mean_position = mean(positions, 1);
            stats.std_position = std(positions, 0, 1);
            
            % Speed statistics
            speeds = sqrt(velocities(:,1).^2 + velocities(:,2).^2);
            stats.mean_speed = mean(speeds);
            stats.max_speed = max(speeds);
            stats.min_speed = min(speeds);
            stats.num_stationary = sum(speeds < 0.01);  % Almost zero
            
            % Direction distribution (for analysis)
            directions = atan2d(velocities(:,2), velocities(:,1));
            directions(directions < 0) = directions(directions < 0) + 360;
            stats.mean_direction = mean(directions);
            stats.std_direction = std(directions);
        end
        
        
        function fig = plot_trajectories(trajectory_data, config, num_ues_to_plot)
            % PLOT_TRAJECTORIES Visualize UE movement trajectories
            %
            % Input:
            %   trajectory_data   - cell array where each cell contains [Tx2] positions over time
            %   config            - simulation config
            %   num_ues_to_plot   - (optional) how many UEs to plot (default: 10)
            %
            % Output:
            %   fig - figure handle
            
            if nargin < 3
                num_ues_to_plot = min(10, length(trajectory_data));
            end
            
            fig = figure('Name', 'UE Trajectories', 'Position', [100, 100, 800, 700]);
            hold on;
            grid on;
            
            % Extract bounds
            x_min = config.area_bounds(1);
            x_max = config.area_bounds(2);
            y_min = config.area_bounds(3);
            y_max = config.area_bounds(4);
            
            % Plot boundaries
            rectangle('Position', [x_min, y_min, x_max-x_min, y_max-y_min], ...
                'EdgeColor', 'k', 'LineWidth', 2, 'LineStyle', '--');
            
            % Plot trajectories for subset of UEs
            colors = lines(num_ues_to_plot);
            
            for i = 1:num_ues_to_plot
                if i <= length(trajectory_data) && ~isempty(trajectory_data{i})
                    traj = trajectory_data{i};
                    
                    % Plot trajectory line
                    plot(traj(:,1), traj(:,2), '-', ...
                        'Color', colors(i,:), 'LineWidth', 1.5);
                    
                    % Mark start position
                    plot(traj(1,1), traj(1,2), 'o', ...
                        'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), ...
                        'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
                    
                    % Mark end position
                    plot(traj(end,1), traj(end,2), 's', ...
                        'MarkerSize', 8, 'MarkerFaceColor', colors(i,:), ...
                        'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
                end
            end
            
            % Plot BS positions if available
            if isfield(config, 'bs') && isfield(config.bs, 'positions')
                bs_pos = config.bs.positions;
                scatter(bs_pos(:,1), bs_pos(:,2), ...
                    200, 'r', '^', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 2);
            end
            
            axis equal;
            xlim([x_min, x_max]);
            ylim([y_min, y_max]);
            xlabel('X Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Y Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
            title(sprintf('UE Trajectories (%d UEs shown)', num_ues_to_plot), ...
                'FontSize', 14, 'FontWeight', 'bold');
            
            % Create legend
            h1 = plot(NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'k', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            h2 = plot(NaN, NaN, 's', 'MarkerSize', 8, 'MarkerFaceColor', 'k', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
            legend([h1, h2], {'Start', 'End'}, 'Location', 'best');
            
            hold off;
            
            fprintf('[RandomWalkModel] Trajectory plot created\n');
        end
        
    end
end