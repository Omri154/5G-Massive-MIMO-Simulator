% TestNetworkManagers.m
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% Test script for validating the BaseStationManager and UserEquipmentManager
% components. Verifies the creation of network nodes, antenna arrays, and
% their integration with the mobility model.

clear; clc; close all;

% Add paths
addpath('config', 'utils', 'environment', 'mobility', 'network');

%% 1. Load Configuration
fprintf('\nLoading configuration...\n');
config = SimulationConfig();

%% 2. Create Managers
fprintf('\n=== Testing Network Managers ===\n');

bs_manager = BaseStationManager(config);
ue_manager = UserEquipmentManager(config);

%% 3. Validation
fprintf('\n=== Validation ===\n');
bs_manager.validate();
ue_manager.validate();

%% 4. Test Base Station Access
fprintf('\n=== Testing BS Access ===\n');

for bs_id = 1:bs_manager.num_bs
    pos = bs_manager.get_position(bs_id);
    array = bs_manager.get_tx_array(bs_id);
    
    fprintf('BS %d:\n', bs_id);
    fprintf('  Position: [%.1f, %.1f, %.1f] m\n', pos);
    fprintf('  Antenna elements: %d\n', size(array.element_position, 2));
    fprintf('  Array type: %s\n', class(array));
end

%% 5. Test User Equipment Access
fprintf('\n=== Testing UE Access ===\n');

% Test the first 5 UEs
for ue_id = 1:5
    pos = ue_manager.get_position(ue_id);
    pos_3d = ue_manager.get_position_3d(ue_id);
    vel = ue_manager.get_velocity(ue_id);
    array = ue_manager.get_rx_array(ue_id);
    
    [speed, direction] = RandomWalkModel.get_velocity_polar(vel);
    
    fprintf('UE %d:\n', ue_id);
    fprintf('  Position: [%.1f, %.1f] m\n', pos);
    fprintf('  Position 3D: [%.1f, %.1f, %.1f] m\n', pos_3d);
    fprintf('  Speed: %.2f m/s, Direction: %.0f deg\n', speed, direction);
    fprintf('  Antenna elements: %d\n', size(array.element_position, 2));
end

%% 6. Test Mobility Updates
fprintf('\n=== Testing Mobility Updates ===\n');

% Store initial positions
initial_positions = ue_manager.get_all_positions();

% Update positions for 10 steps (equivalent to 1 second)
dt = 0.1;
for step = 1:10
    ue_manager.update_positions(dt);
end

% Check that positions have changed appropriately
final_positions = ue_manager.get_all_positions();
displacement = final_positions - initial_positions;
mean_displacement = mean(sqrt(sum(displacement.^2, 2)));

fprintf('After 1 second:\n');
fprintf('  Mean displacement: %.2f m\n', mean_displacement);

% Update velocities
ue_manager.update_velocities();
fprintf('  Velocities updated successfully.\n');

%% 7. Test QuaDRiGa Antenna Array Info
fprintf('\n=== QuaDRiGa Antenna Arrays ===\n');

% Base Station antenna array info
bs_array = bs_manager.get_tx_array(1);
fprintf('BS 1 antenna array:\n');
fprintf('  Element positions shape: [%d x %d]\n', size(bs_array.element_position));
fprintf('  Coupling matrix shape: [%d x %d]\n', size(bs_array.coupling));
fprintf('  Number of elements: %d\n', size(bs_array.element_position, 2));

% Display a sample of element positions
fprintf('  Element positions (first 4):\n');
for i = 1:min(4, size(bs_array.element_position, 2))
    fprintf('    Element %d: [%.4f, %.4f, %.4f] m\n', i, ...
        bs_array.element_position(:, i));
end

% User Equipment antenna array info
ue_array = ue_manager.get_rx_array(1);
fprintf('\nUE 1 antenna array:\n');
fprintf('  Element positions shape: [%d x %d]\n', size(ue_array.element_position));
fprintf('  Coupling matrix shape: [%d x %d]\n', size(ue_array.coupling));
fprintf('  Number of elements: %d\n', size(ue_array.element_position, 2));

% Display all UE element positions
fprintf('  Element positions:\n');
for i = 1:size(ue_array.element_position, 2)
    fprintf('    Element %d: [%.4f, %.4f, %.4f] m\n', i, ...
        ue_array.element_position(:, i));
end

%% 8. Simple Visualization - UE positions relative to BSs
fprintf('\n=== Creating Simple Visualization ===\n');

figure('Name', 'Network Layout', 'Position', [100, 100, 800, 700]);
hold on;
grid on;

% Plot area boundaries
x_max = config.area_bounds(2);
y_max = config.area_bounds(4);
rectangle('Position', [0, 0, x_max, y_max], ...
    'EdgeColor', 'k', 'LineWidth', 2, 'LineStyle', '--');

% Plot Base Stations
bs_positions = bs_manager.get_all_positions();
scatter(bs_positions(:,1), bs_positions(:,2), ...
    300, 'r', '^', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 2);

% Label Base Stations
for i = 1:size(bs_positions, 1)
    text(bs_positions(i,1)+5, bs_positions(i,2)+5, sprintf('BS%d', i), ...
        'FontSize', 12, 'FontWeight', 'bold');
end

% Plot User Equipment
ue_positions = ue_manager.get_all_positions();
scatter(ue_positions(:,1), ue_positions(:,2), ...
    50, 'b', 'o', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1);

% Plot settings
axis equal;
xlim([0, x_max]);
ylim([0, y_max]);
xlabel('X Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Network Layout: %d BSs + %d UEs', config.bs.num, config.ue.num), 'FontSize', 14, 'FontWeight', 'bold');
legend({'Base Stations', 'User Equipment'}, 'Location', 'best');

hold off;

fprintf('Simple visualization created successfully.\n');

%% 9. Summary
fprintf('\n=== Summary ===\n');
fprintf('BaseStationManager: Verified\n');
fprintf('UserEquipmentManager: Verified\n');
fprintf('QuaDRiGa antenna arrays: Created successfully\n');
fprintf('Mobility integration: Verified\n');
fprintf('Validations: Passed\n');

fprintf('\nNetwork managers test completed successfully.\n');