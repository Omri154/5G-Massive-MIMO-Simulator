% MainSimulation.m
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% Main entry point for the 5G Massive MIMO simulation.
% Initializes the environment, generates users and base stations, 
% runs the time-stepped simulation loop, and saves the generated dataset.

clear; clc; close all;

%% Add paths
fprintf('Adding paths...\n');
addpath('config', 'utils', 'environment', 'mobility', 'network', 'simulation', 'output');

%% Title and Copyright
fprintf('==================================================\n');
fprintf('  5G Massive MIMO Dynamic Simulation\n');
fprintf('  Developed by: Omri Israeli\n');
fprintf('  GitHub: github.com/Omri154/5G-Massive-MIMO-Simulator\n');
fprintf('==================================================\n\n');

%% Load configuration
fprintf('Loading configuration...\n');
config = SimulationConfig();

fprintf('\n========================================\n');
fprintf('  Simulation Parameters\n');
fprintf('========================================\n');
fprintf('Duration: %.0f seconds (%.1f minutes)\n', ...
    config.timing.total_duration, config.timing.total_duration/60);
fprintf('Expected CSI reports per UE: %.0f\n', ...
    config.timing.total_duration / config.timing.csi_report_interval);
fprintf('Total expected reports: %.0f\n', ...
    (config.timing.total_duration / config.timing.csi_report_interval) * config.ue.num);
fprintf('========================================\n\n');

%% Initialize components
fprintf('Initializing simulation components...\n');

% 1. Generate areas
fprintf('[1/5] Generating areas...\n');
%rng(config.random_seed_areas);
areas = AreaGenerator.generate(config);

% 2. Create base stations
fprintf('[2/5] Creating base stations...\n');
bs_manager = BaseStationManager(config);

% 3. Create user equipment
fprintf('[3/5] Creating user equipment...\n');
rng(config.random_seed_mobility);
ue_manager = UserEquipmentManager(config);

% 4. Create time manager
fprintf('[4/5] Creating time manager...\n');
time_manager = TimeManager(config);

% 5. Create CSI Reporter
fprintf('[5/5] Creating CSI Reporter...\n');
csi_reporter = CSIReporter(config, areas, bs_manager, ue_manager);

%% Pre-allocate storage for data
fprintf('\nAllocating storage for CSI data...\n');

num_ues = config.ue.num;
num_reports = config.timing.num_csi_reports;
total_reports = num_ues * num_reports;

fprintf('Storage size: %d UEs x %d reports = %d total\n', ...
    num_ues, num_reports, total_reports);

% Pre-allocate arrays
csi_data_all = struct();
csi_data_all.timestamp = zeros(total_reports, 1);
csi_data_all.ue_id = zeros(total_reports, 1);
csi_data_all.x = zeros(total_reports, 1);
csi_data_all.y = zeros(total_reports, 1);
csi_data_all.area_id = zeros(total_reports, 1);
csi_data_all.rsrp = zeros(total_reports, 1);
csi_data_all.rsrq = zeros(total_reports, 1);
csi_data_all.sinr = zeros(total_reports, 1);
csi_data_all.cqi = zeros(total_reports, 1);
csi_data_all.serving_bs = zeros(total_reports, 1);
csi_data_all.distance = zeros(total_reports, 1);

% Trajectory storage
trajectory_data = cell(num_ues, 1);
for i = 1:num_ues
    trajectory_data{i} = ue_manager.get_position(i);
end

% Transition log
transition_log = struct([]);

% Counters
report_index = 1;
total_position_updates = 0;
total_csi_reports_count = 0;
total_velocity_updates = 0;
total_transitions = 0;

fprintf('Storage allocated successfully.\n');

%% Run Simulation Loop
fprintf('\n========================================\n');
fprintf('  Starting Simulation\n');
fprintf('========================================\n\n');

dt = config.timing.position_update_dt;
next_progress_threshold = 0;               % Start printing at 0%
progress_step = config.update_precantage;  % Update terminal every 2%
bar_length = 30;                           % Visual length of the progress bar

tic;  % Start timer

while ~time_manager.is_finished()
    
    % Always compute current datetime first — used by multiple subsystems
    current_datetime = config.simulation_datetime + seconds(time_manager.current_time);

    % 1. Update UE positions
    if time_manager.should_update_positions()
        ue_manager.update_positions(dt, current_datetime);
        total_position_updates = total_position_updates + 1;
        
        % Store trajectories
        for ue_id = 1:num_ues
            current_pos = ue_manager.get_position(ue_id);
            trajectory_data{ue_id} = [trajectory_data{ue_id}; current_pos];
        end
        
        % Check for transitions
        for ue_id = 1:num_ues
            position = ue_manager.get_position(ue_id);
            [in_transition, blend_factor, area_pair] = ...
                TransitionManager.check_transition(position, areas, config.transition_width);
            
            if in_transition
                trans_info = struct();
                trans_info.time = time_manager.current_time;
                trans_info.ue_id = ue_id;
                trans_info.position = position;
                trans_info.from_area = area_pair(1);
                trans_info.to_area = area_pair(2);
                trans_info.blend_factor = blend_factor;
                transition_log = [transition_log; trans_info];
                total_transitions = total_transitions + 1;
            end
        end
    end
    
    % 2. Report CSI
    if time_manager.check_and_advance_csi()
        total_csi_reports_count = total_csi_reports_count + 1;
        
        % Get CSI for all UEs
        csi_matrix = csi_reporter.generate_all_csi_reports(current_datetime);
        
        % Store CSI data for EVERY UE
        for ue_id = 1:num_ues
            ue_pos = ue_manager.get_position(ue_id);
            area_idx = GeometryUtils.find_area(ue_pos, areas);
            
            csi_data_all.timestamp(report_index) = time_manager.current_time;
            csi_data_all.ue_id(report_index) = ue_id;
            csi_data_all.x(report_index) = ue_pos(1);
            csi_data_all.y(report_index) = ue_pos(2);
            csi_data_all.area_id(report_index) = area_idx;
            csi_data_all.rsrp(report_index) = csi_matrix(ue_id, 1);
            csi_data_all.rsrq(report_index) = csi_matrix(ue_id, 2);
            csi_data_all.sinr(report_index) = csi_matrix(ue_id, 3);
            csi_data_all.cqi(report_index) = csi_matrix(ue_id, 4);
            csi_data_all.serving_bs(report_index) = csi_matrix(ue_id, 5);
            csi_data_all.distance(report_index) = csi_matrix(ue_id, 6);
            
            report_index = report_index + 1;
        end
    end
    
    % 3. Update velocities
    if time_manager.check_and_advance_velocities()
        ue_manager.update_velocities();
        total_velocity_updates = total_velocity_updates + 1;
    end
    
    % Static Progress Bar Update (Every 10%)
    percent_done = 100 * (time_manager.current_time / config.timing.total_duration);
    if percent_done >= next_progress_threshold
        filled_len = round((percent_done / 100) * bar_length);
        empty_len = bar_length - filled_len;
        bar_str = ['[', repmat('=', 1, filled_len), repmat('-', 1, empty_len), ']'];
        
        actual_reports = report_index - 1;
        fprintf('%s %5.1f%% | Time: %6.1f / %6.1f sec | Reports: %d \n', ...
            bar_str, percent_done, time_manager.current_time, config.timing.total_duration, actual_reports);
            
        next_progress_threshold = next_progress_threshold + progress_step;
    end
    
    % Advance time
    time_manager.advance_time(dt);
end

% Final 100% printout ensuring it reaches the end
bar_str = ['[', repmat('=', 1, bar_length), ']'];
fprintf('%s 100.0%% | Time: %6.1f / %6.1f sec | Reports: %d \n', ...
    bar_str, config.timing.total_duration, config.timing.total_duration, report_index - 1);

elapsed_time = toc;
fprintf('\nSimulation Loop Completed.\n');

%% Verify Storage
actual_reports_stored = report_index - 1;
expected_reports = num_ues * num_reports;

fprintf('\n========================================\n');
fprintf('  Simulation Complete\n');
fprintf('========================================\n\n');

fprintf('--- Timing ---\n');
fprintf('Simulation time: %.1f s (%.1f min)\n', ...
    config.timing.total_duration, config.timing.total_duration / 60);
fprintf('Wall-clock time: %.2f s (%.1f min)\n', elapsed_time, elapsed_time/60);
fprintf('Speed factor: %.1fx realtime\n', config.timing.total_duration / elapsed_time);

fprintf('\n--- Storage Check ---\n');
fprintf('Expected reports: %d\n', expected_reports);
fprintf('Actually stored: %d\n', actual_reports_stored);
if actual_reports_stored == expected_reports
    fprintf('SUCCESS: All reports stored correctly.\n');
else
    fprintf('WARNING: Missing %d reports.\n', expected_reports - actual_reports_stored);
end

fprintf('\n--- Statistics ---\n');
fprintf('Position updates: %d\n', total_position_updates);
fprintf('CSI report events: %d\n', total_csi_reports_count);
fprintf('Reports per UE: %.0f\n', actual_reports_stored / num_ues);
fprintf('Velocity updates: %d\n', total_velocity_updates);
fprintf('Area transitions: %d\n', total_transitions);

% Mobility statistics
stats = ue_manager.get_mobility_statistics();
fprintf('\n--- Final Mobility ---\n');
fprintf('Mean position: [%.1f, %.1f] m\n', stats.mean_position);
fprintf('Mean speed: %.2f m/s\n', stats.mean_speed);

% Trim arrays to actual size (in case of early termination)
valid_indices = 1:actual_reports_stored;
csi_data_all.timestamp = csi_data_all.timestamp(valid_indices);
csi_data_all.ue_id = csi_data_all.ue_id(valid_indices);
csi_data_all.x = csi_data_all.x(valid_indices);
csi_data_all.y = csi_data_all.y(valid_indices);
csi_data_all.area_id = csi_data_all.area_id(valid_indices);
csi_data_all.rsrp = csi_data_all.rsrp(valid_indices);
csi_data_all.rsrq = csi_data_all.rsrq(valid_indices);
csi_data_all.sinr = csi_data_all.sinr(valid_indices);
csi_data_all.cqi = csi_data_all.cqi(valid_indices);
csi_data_all.serving_bs = csi_data_all.serving_bs(valid_indices);
csi_data_all.distance = csi_data_all.distance(valid_indices);

% CSI statistics
fprintf('\n--- CSI Statistics ---\n');
fprintf('Mean RSRP: %.2f dBm\n', mean(csi_data_all.rsrp));
fprintf('Mean RSRQ: %.2f dB\n', mean(csi_data_all.rsrq));
fprintf('Mean SINR: %.2f dB\n', mean(csi_data_all.sinr));
fprintf('Mean CQI: %.1f\n', mean(csi_data_all.cqi));

% CSI Reporter statistics
fprintf('\n');
csi_reporter.print_statistics();

fprintf('========================================\n\n');

%% Create engine-like struct for ResultsManager
engine = struct();
engine.config = config;
engine.areas = areas;
engine.bs_manager = bs_manager;
engine.ue_manager = ue_manager;
engine.time_manager = time_manager;
engine.trajectory_data = trajectory_data;
engine.transition_log = transition_log;
engine.total_position_updates = total_position_updates;
engine.total_csi_reports = total_csi_reports_count;
engine.total_velocity_updates = total_velocity_updates;
engine.total_transitions = total_transitions;

%% Save results using ResultsManager
fprintf('\n========================================\n');
fprintf('  Saving Results\n');
fprintf('========================================\n\n');

fprintf('Initializing ResultsManager...\n');
results_mgr = ResultsManager(config, engine, csi_data_all);

% Save everything
results_mgr.save_all_results();

fprintf('\n========================================\n');
fprintf('  Process Complete\n');
fprintf('========================================\n\n');
fprintf('Summary:\n');
fprintf('  - %d UEs simulated for %.1f seconds\n', num_ues, config.timing.total_duration);
fprintf('  - %d CSI reports generated (%.0f per UE)\n', actual_reports_stored, actual_reports_stored/num_ues);
fprintf('  - %d area transitions detected\n', total_transitions);
fprintf('  - Results saved to: %s\n', results_mgr.output_dir);
fprintf('  - CSV files: combined + %d per-UE files\n', num_ues);
fprintf('  - Visualizations: 8 detailed figures\n');
fprintf('  - HTML report generated\n');
fprintf('\n');