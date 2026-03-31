% TestAreaGenerator.m
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% Test script for validating the AreaGenerator, GeometryUtils, and
% ValidationUtils components. Verifies Voronoi area generation, 
% scenario matching, visualization, and boundary reflection logic.

clear; clc; close all;

% Add paths
addpath('config', 'utils', 'environment');

%% 1. Load Configuration
fprintf('Loading configuration...\n');
config = SimulationConfig();

%% 2. Generate Areas
fprintf('\nGenerating areas...\n');
areas = AreaGenerator.generate(config);

%% 3. Validate Area-Scenario Matching
ValidationUtils.validate_area_type_scenario_match(areas);

%% 4. Create Test UEs
fprintf('\nCreating test UEs...\n');
num_test_ues = 30;
ue_x = config.area_bounds(1) + (config.area_bounds(2) - config.area_bounds(1)) * rand(num_test_ues, 1);
ue_y = config.area_bounds(3) + (config.area_bounds(4) - config.area_bounds(3)) * rand(num_test_ues, 1);
ue_positions = [ue_x, ue_y];

%% 5. Visualization
fprintf('Generating combined visualization...\n');
fig = AreaGenerator.plot_areas_combined(areas, config, ue_positions);
saveas(fig, 'voronoi_combined_analysis.png');

%% 6. Test Boundary Reflection
fprintf('\n--- Testing Boundary Reflection ---\n');
test_positions = [
    205, 100;   % Outside right
    -5, 50;     % Outside left
    100, 205;   % Outside top
    100, -5     % Outside bottom
];
test_velocities = [
    2, 1;
    -2, 1;
    1, 2;
    1, -2
];

for i = 1:size(test_positions, 1)
    [new_pos, new_vel] = GeometryUtils.reflect_velocity_at_boundary(...
        test_positions(i,:), test_velocities(i,:), config.area_bounds);
    fprintf('Pos [%.1f, %.1f] + Vel [%.1f, %.1f] -> Pos [%.1f, %.1f], Vel [%.1f, %.1f]\n', ...
        test_positions(i,1), test_positions(i,2), ...
        test_velocities(i,1), test_velocities(i,2), ...
        new_pos(1), new_pos(2), new_vel(1), new_vel(2));
end

fprintf('\nAll tests completed successfully.\n');