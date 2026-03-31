% TestRandomWalkModel.m
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% Test script for validating the RandomWalkModel mobility module.
% Verifies initialization of positions and velocities, updates over time,
% boundary reflections, and generates trajectory plots.

clear; clc; close all;

% Add paths
addpath('config', 'utils', 'mobility');

%% 1. Load Configuration
fprintf('\nLoading configuration...\n');
config = SimulationConfig();

%% 2. Initialize UEs
fprintf('\n=== Testing RandomWalkModel ===\n');

num_ues = 35;  % Small number for testing
positions = RandomWalkModel.initialize_positions(num_ues, config.area_bounds);
velocities = RandomWalkModel.initialize_velocities(num_ues, config);

fprintf('Initial positions: %d UEs\n', size(positions, 1));
fprintf('Initial velocities: %d UEs\n', size(velocities, 1));

%% 3. Check Initial Statistics
stats = RandomWalkModel.get_mobility_statistics(positions, velocities);
fprintf('\nInitial Statistics:\n');
fprintf('  Mean position: [%.1f, %.1f]\n', stats.mean_position);
fprintf('  Mean speed: %.2f m/s\n', stats.mean_speed);
fprintf('  Max speed: %.2f m/s\n', stats.max_speed);
fprintf('  Min speed: %.2f m/s\n', stats.min_speed);

%% 4. Simulate for 90 seconds
fprintf('\n=== Running 90s simulation ===\n');

dt = 0.1;  % 0.1s timestep
total_time = 90;  % 90 seconds
num_steps = total_time / dt;

% Store trajectories
trajectory_data = cell(num_ues, 1);
for i = 1:num_ues
    trajectory_data{i} = positions(i,:);  % Store initial position
end

% Simulation loop
t = 0;
step_count = 0;
velocity_changes = 0;

tic;
for step = 1:num_steps
    % Update positions and handle boundaries
    [positions, velocities] = RandomWalkModel.step(...
        positions, velocities, dt, config.area_bounds);
    
    % Store trajectories
    for i = 1:num_ues
        trajectory_data{i} = [trajectory_data{i}; positions(i,:)];
    end
    
    % Every 10s: Change velocities
    if mod(t, 10) < 0.01
        velocities = RandomWalkModel.update_velocities(velocities, config);
        velocity_changes = velocity_changes + 1;
    end
    
    t = t + dt;
    step_count = step_count + 1;
end
elapsed = toc;

fprintf('Simulation completed:\n');
fprintf('  Steps: %d\n', step_count);
fprintf('  Velocity changes: %d\n', velocity_changes);
fprintf('  Elapsed time: %.2f seconds\n', elapsed);
fprintf('  Time per step: %.4f ms\n', elapsed/step_count * 1000);

%% 5. Final Statistics
stats_final = RandomWalkModel.get_mobility_statistics(positions, velocities);
fprintf('\nFinal Statistics:\n');
fprintf('  Mean position: [%.1f, %.1f]\n', stats_final.mean_position);
fprintf('  Mean speed: %.2f m/s\n', stats_final.mean_speed);

%% 6. Validate Boundary Enforcement
all_in_bounds = true;
for i = 1:num_ues
    if ~GeometryUtils.check_if_in_bounds(positions(i,:), config.area_bounds)
        fprintf('ERROR: UE %d out of bounds!\n', i);
        all_in_bounds = false;
    end
end

if all_in_bounds
    fprintf('\nAll UEs stayed within bounds.\n');
else
    fprintf('\nWARNING: Some UEs went out of bounds.\n');
end

%% 7. Plot Trajectories
fprintf('\nGenerating trajectory plot...\n');
fig = RandomWalkModel.plot_trajectories(trajectory_data, config, num_ues);
saveas(fig, 'ue_trajectories_test.png');

fprintf('\nRandomWalkModel test completed successfully.\n');