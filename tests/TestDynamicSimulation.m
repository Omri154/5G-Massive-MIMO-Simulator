% TestDynamicSimulation.m
%
% A dynamic simulation test where UEs move and report CSI over time.
% Generates visual analyses of trajectories and individual UE metrics.

clear; clc; close all;

% Add necessary paths
addpath('config', 'utils', 'environment', 'mobility', 'network', 'simulation');

%% 1. Configuration & Initialization
fprintf('=== Starting Dynamic Simulation Test ===\n');

config = SimulationConfig();

% Adjust settings for a meaningful test
config.timing.total_duration = 60;       % Run for 60 seconds
config.timing.csi_report_interval = 0.5; % Report every 0.5 seconds
config.timing.position_update_dt = 0.1;  % Move every 0.1 seconds
config.ue.num = 20;                      % Fewer UEs to make plots clearer

% Initialize Modules
areas = AreaGenerator.generate(config);
bs_manager = BaseStationManager(config);
ue_manager = UserEquipmentManager(config);
csi_reporter = CSIReporter(config, areas, bs_manager, ue_manager);

fprintf('\nConfiguration:\n');
fprintf('  Duration: %d sec\n', config.timing.total_duration);
fprintf('  UEs: %d\n', config.ue.num);
fprintf('  Mobility Model: Random Walk (Bounce at borders)\n');

%% 2. The Main Simulation Loop
fprintf('\n=== Running Simulation Loop ===\n');

% Prepare data storage
num_steps_csi = floor(config.timing.total_duration / config.timing.csi_report_interval);
history.time = zeros(num_steps_csi, 1);
history.ue_1_data = zeros(num_steps_csi, 6); % Store full data for UE #1
history.all_positions = cell(num_steps_csi, 1); % Store positions for plots
history.all_sinr = cell(num_steps_csi, 1);      % Store SINR for plots

% Timers
current_time = 0;
step_idx = 0;
report_idx = 0;

% Progress bar
h_wait = waitbar(0, 'Running Dynamic Simulation...');

while current_time < config.timing.total_duration
    step_idx = step_idx + 1;
    
    % --- A. Mobility Step ---
    % Move all UEs (Position Update)
    ue_manager.update_positions(config.timing.position_update_dt);
    
    % Update Velocities (every mobility update interval)
    if mod(step_idx * config.timing.position_update_dt, config.mobility.update_interval) < 1e-5
        fprintf('  [t=%.1f] Updating UE velocities...\n', current_time);
        ue_manager.update_velocities();
    end
    
    % --- B. CSI Reporting Step ---
    % Generate reports
    if mod(current_time, config.timing.csi_report_interval) < config.timing.position_update_dt/2
        report_idx = report_idx + 1;
        
        % Generate CSI for all UEs
        all_csi = csi_reporter.generate_all_csi_reports(current_time);
        
        % Store Data
        history.time(report_idx) = current_time;
        history.all_positions{report_idx} = ue_manager.get_all_positions();
        history.all_sinr{report_idx} = all_csi(:, 3); % Column 3 is SINR
        
        % Track UE #1 specifically for detailed time-series analysis
        history.ue_1_data(report_idx, :) = all_csi(1, :);
        
        % Update waitbar
        if ishandle(h_wait)
            waitbar(current_time / config.timing.total_duration, h_wait, ...
                sprintf('Simulation Time: %.1fs / %ds', current_time, config.timing.total_duration));
        end
    end
    
    % Advance time
    current_time = current_time + config.timing.position_update_dt;
end

if ishandle(h_wait)
    close(h_wait);
end
fprintf('Simulation complete. Generated %d reports.\n', report_idx);

%% 3. Visualization: Trajectories Colored by SINR
fprintf('\n=== Generating Trajectory Visualization ===\n');

fig_traj = figure('Name', 'UE Dynamic Trajectories', 'Position', [100, 100, 1000, 800]);

% Draw Background (Voronoi Areas)
AreaGenerator.plot_voronoi_diagram(areas, config, [], 'Dynamic Trajectories (Colored by SINR)');

% Restore hold on (plot_voronoi_diagram may have disabled it)
hold on;
grid on;

% Define range for colormap
sinr_min = -5; sinr_max = 25; 
colormap(jet);

fprintf('Plotting trajectories for %d UEs...\n', config.ue.num);

for ue_id = 1:config.ue.num
    % Extract path for this UE
    path_x = zeros(report_idx, 1);
    path_y = zeros(report_idx, 1);
    path_sinr = zeros(report_idx, 1);
    
    for t = 1:report_idx
        pos = history.all_positions{t};
        sinr = history.all_sinr{t};
        path_x(t) = pos(ue_id, 1);
        path_y(t) = pos(ue_id, 2);
        path_sinr(t) = sinr(ue_id);
    end
    
    % Clean approach: Draw the path as a faint line, then scatter points over it
    plot(path_x, path_y, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    scatter(path_x, path_y, 25, path_sinr, 'filled', 'MarkerEdgeColor', 'none');
end

% Add Colorbar
c = colorbar;
c.Label.String = 'SINR [dB]';
caxis([sinr_min, sinr_max]);

% Plot BSs securely on top
bs_pos = bs_manager.get_all_positions();
plot(bs_pos(:,1), bs_pos(:,2), '^r', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');

title('UE Movement Paths (Color = Signal Quality)');
xlabel('X [m]'); ylabel('Y [m]');
xlim([config.area_bounds(1) config.area_bounds(2)]); 
ylim([config.area_bounds(3) config.area_bounds(4)]);
hold off;

%% 4. Visualization: Single UE Time Series Analysis
fprintf('\n=== Generating Single UE Analysis ===\n');

ue1_rsrp = history.ue_1_data(:, 1);
ue1_sinr = history.ue_1_data(:, 3);
ue1_dist = history.ue_1_data(:, 6);
time_axis = history.time;

fig_ts = figure('Name', 'Single UE Analysis', 'Position', [150, 150, 1000, 600]);

% Subplot 1: Distance vs Time
subplot(2, 2, 1);
plot(time_axis, ue1_dist, 'b-', 'LineWidth', 2);
grid on;
xlabel('Time [s]'); ylabel('Distance to Serving BS [m]');
title('UE #1: Movement relative to BS');

% Subplot 2: RSRP vs Time
subplot(2, 2, 2);
plot(time_axis, ue1_rsrp, 'r-', 'LineWidth', 2);
grid on;
xlabel('Time [s]'); ylabel('RSRP [dBm]');
title('UE #1: Received Power over Time');

% Subplot 3: Correlation (Distance vs RSRP)
subplot(2, 2, 3);
scatter(ue1_dist, ue1_rsrp, 20, time_axis, 'filled');
colormap(gca, parula);
cb = colorbar; cb.Label.String = 'Time [s]';
grid on;
xlabel('Distance [m]'); ylabel('RSRP [dBm]');
title('Physics Check: Path Loss Correlation');

% Add trendline
p = polyfit(ue1_dist, ue1_rsrp, 1);
hold on;
plot(ue1_dist, polyval(p, ue1_dist), 'k--', 'LineWidth', 1.5);
legend('Measurements', sprintf('Trend: %.2f dB/m', p(1)));

% Subplot 4: SINR vs Time
subplot(2, 2, 4);
plot(time_axis, ue1_sinr, 'g-', 'LineWidth', 2);
grid on;
xlabel('Time [s]'); ylabel('SINR [dB]');
title('UE #1: Signal Quality (SINR)');

fprintf('\nDynamic simulation test completed successfully.\n');