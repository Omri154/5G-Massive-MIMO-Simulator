function config = SimulationConfig()
% SIMULATIONCONFIG - Complete configuration for the simulation
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This function returns a comprehensive configuration struct required for 
% running the Massive MIMO simulation. It centralizes all parameters 
% related to environment, network, mobility, timing, and dynamic effects 
% (weather, traffic).
%
% Usage:
%   config = SimulationConfig();
%
% Note: Values can be safely modified here and the simulation can be rerun 
% without altering the core logic. Modifying seeds allows for reproducibility 
% or generation of entirely new datasets.

    config = struct();
    
    %% ======================================================================
    %  General Settings
    %% ======================================================================
    
    config.simulation_name = 'QuaDRiGa_Super_Sim';
    config.version = '1.0';
    config.description = 'Massive MIMO simulation with weather, traffic, and transitions';
    
    % Simulation timestamp
    config.simulation_datetime = datetime('2024-01-15 08:30:00'); % timestamp in the format 'YYYY-MM-DD HOUR:MINUTE:SECONDS'

    % Separate seeds for reproducibility and flexibility
    % Master seed (used for general randomness)
    config.random_seed = 54321;
    
    % Seed for Voronoi area generation (areas, scenarios, positions)
    config.random_seed_areas = 12345;
    
    % Seed for UE mobility (initial positions, velocities, trajectories)
    config.random_seed_mobility = 98765;
    
    % HOW TO USE SEEDS:
    % - To run the same simulation again: keep all seeds unchanged.
    % - To keep the same area layout but different UE movement: change only random_seed_mobility.
    % - To get a completely new simulation: change random_seed (or both area & mobility seeds).
    
    %% ======================================================================
    %  Environment
    %% ======================================================================
    
    % Area dimensions
    config.area_width = 200;           % [meters]
    config.area_height = 200;          % [meters]
    config.area_bounds = [0, config.area_width, 0, config.area_height];  % [x_min, x_max, y_min, y_max]
    
    % Areas (Voronoi regions)
    config.num_areas = 8;              % Number of areas (seeds)
    config.transition_width = 10;      % [meters] Transition zone width between areas
    
    % Available area types
    config.area_types = {'shopping_center', 'residential', 'office', ...
                         'highway', 'parking_lot', 'park'};
    
    % Available QuaDRiGa scenarios
    config.scenarios = {'3GPP_38.901_RMa', ...         % Rural Macro
                        '3GPP_38.901_RMa_LOS', ...     % Rural Macro LOS
                        '3GPP_38.901_RMa_NLOS', ...    % Rural Macro NLOS
                        '3GPP_38.901_UMi', ...         % Urban Micro
                        '3GPP_38.901_UMi_LOS', ...     % Urban Micro LOS
                        '3GPP_38.901_UMi_NLOS'};       % Urban Micro NLOS
    
    %% ======================================================================
    %  Network
    %% ======================================================================
    
    % Frequency
    config.frequency = 3.5e9;          % [Hz] 3.5 GHz (5G band)
    config.bandwidth = 100e6;          % [Hz] 100 MHz
    
    % --- Base Stations (Massive MIMO) ---
    config.bs.num = 2;                 % Number of base stations
    
    % BS positions: [x, y, height] in rows
    config.bs.positions = [50,  50,  25;    % BS1: north-west
                           150, 150, 25];   % BS2: south-east
    
    % MASSIVE MIMO Configuration
    % 64x64 MIMO: 64 Tx antennas x 64 Rx antennas
    % Physical array: 8 rows x 8 columns = 64 elements
    config.bs.num_tx = 64;             % 64 Tx antennas (8x8 array)
    config.bs.num_rx = 64;             % 64 Rx antennas (8x8 array)
    config.bs.array_rows = 8;          % 8 rows in antenna array
    config.bs.array_cols = 8;          % 8 columns in antenna array
    config.bs.array_config = [config.bs.array_rows, config.bs.array_cols, 1, 1, 1];
    
    % Antenna properties
    config.bs.antenna_pattern = '3gpp-3d';      % Radiation pattern
    config.bs.antenna_polarization = 'cross';   % Cross-polarization
    config.bs.downtilt = -8;                    % [degrees] Downtilt angle (vertical)
    
    % Azimuth angles (horizontal orientation)
    config.bs.azimuth = [45, 225];              % [degrees] BS1=45 deg, BS2=225 deg
    
    config.bs.tx_power = 46;                    % [dBm] Transmit power (typical macro)
    
    % --- User Equipment ---
    config.ue.num = 100;               % Number of users
    
    % UE MIMO configuration (standard mobile)
    % 2x2 MIMO array = 4 physical antenna elements
    % Physical array: 2 rows x 2 columns = 4 elements
    config.ue.num_tx = 4;              % 4 Tx antennas (2x2 array)
    config.ue.num_rx = 4;              % 4 Rx antennas (2x2 array)
    config.ue.array_rows = 2;          % 2 rows in antenna array
    config.ue.array_cols = 2;          % 2 columns in antenna array
    config.ue.array_spacing = 0.5;     % [wavelengths] Spacing between antennas
    
    % Antenna properties
    config.ue.antenna_pattern = 'omni';         % Omni-directional
    config.ue.height = 1.5;                     % [meters] Typical height (phone in hand)
    config.ue.tx_power = 23;                    % [dBm] Typical transmit power
    config.ue.noise_figure = 9;                 % [dB] Receiver noise figure
    
    %% ======================================================================
    %  Mobility
    %% ======================================================================
    
    config.mobility.model = 'random_walk';      % Mobility model
    config.mobility.speed_min = 0;              % [m/s] Minimum speed
    config.mobility.speed_max = 3;              % [m/s] Maximum speed (walking)
    config.mobility.direction_min = 0;          % [degrees] Minimum direction
    config.mobility.direction_max = 360;        % [degrees] Maximum direction
    
    % Timing
    config.mobility.update_interval = 10;       % [seconds] Change speed/direction every 10s
    config.mobility.position_timestep = 0.1;    % [seconds] Update position every 0.1s
    
    % Collisions
    config.mobility.boundary_behavior = 'reflect';  % reflect/wrap/stop
    config.mobility.collision_elasticity = 1.0;     % 1.0 = perfectly elastic
    
    %% ======================================================================
    %  Simulation Timing
    %% ======================================================================
    
    config.timing.total_duration = 300;         % [seconds] 5 minutes
    config.timing.csi_report_interval = 0.5;    % [seconds] CSI report every 0.5s
    config.timing.position_update_dt = 0.1;     % [seconds] Position update every 0.1s
    config.timing.mobility_update_dt = 10;      % [seconds] Velocity update every 10s
    
    % Derived calculations
    config.timing.num_csi_reports = config.timing.total_duration / config.timing.csi_report_interval;
    config.timing.num_position_updates = config.timing.total_duration / config.timing.position_update_dt;
    config.timing.num_mobility_updates = config.timing.total_duration / config.timing.mobility_update_dt;
    
    %% ======================================================================
    %  Weather
    %% ======================================================================
    
    config.weather.enabled = true;              % Enable weather effects
    
    % Climate conditions by month (1=January, 12=December)
    % Each month: [prob_clear, prob_light_rain, prob_heavy_rain]
    config.weather.monthly_probabilities = [
        0.6, 0.3, 0.1;  % January - winter
        0.6, 0.3, 0.1;  % February
        0.7, 0.25, 0.05; % March
        0.8, 0.15, 0.05; % April
        0.9, 0.1, 0.0;  % May - summer begins
        0.95, 0.05, 0.0; % June
        1.0, 0.0, 0.0;  % July - dry summer
        1.0, 0.0, 0.0;  % August
        0.9, 0.1, 0.0;  % September
        0.8, 0.15, 0.05; % October
        0.7, 0.2, 0.1;  % November
        0.6, 0.3, 0.1   % December - winter
    ];
    
    % Rain effect on path loss [dB] at 3.5 GHz
    config.weather.rain_attenuation = struct();
    config.weather.rain_attenuation.clear = 0;          % [dB] Clear/sunny
    config.weather.rain_attenuation.light_rain = 0.5;   % [dB] Light rain
    config.weather.rain_attenuation.heavy_rain = 2.0;   % [dB] Heavy rain
    
    %% ======================================================================
    %  Traffic Load
    %% ======================================================================
    
    config.traffic.enabled = true;              % Enable traffic load effects
    
    % Load profile by area type, day, and time
    % Structure: config.traffic.profiles.(area_type).(day_type).(time_period) = load_factor
    
    % --- Shopping Center ---
    config.traffic.profiles.shopping_center.weekday.night = 0.1;      % 00:00-06:00
    config.traffic.profiles.shopping_center.weekday.morning = 0.3;    % 06:00-10:00
    config.traffic.profiles.shopping_center.weekday.midday = 0.5;     % 10:00-17:00
    config.traffic.profiles.shopping_center.weekday.evening = 0.7;    % 17:00-22:00
    config.traffic.profiles.shopping_center.weekday.late = 0.2;       % 22:00-24:00
    
    config.traffic.profiles.shopping_center.weekend.night = 0.1;
    config.traffic.profiles.shopping_center.weekend.morning = 0.6;
    config.traffic.profiles.shopping_center.weekend.midday = 0.9;
    config.traffic.profiles.shopping_center.weekend.evening = 0.9;
    config.traffic.profiles.shopping_center.weekend.late = 0.4;
    
    % --- Residential ---
    config.traffic.profiles.residential.weekday.night = 0.6;          % At home at night
    config.traffic.profiles.residential.weekday.morning = 0.7;        % Waking up
    config.traffic.profiles.residential.weekday.midday = 0.3;         % At work
    config.traffic.profiles.residential.weekday.evening = 0.8;        % Back home
    config.traffic.profiles.residential.weekday.late = 0.7;
    
    config.traffic.profiles.residential.weekend.night = 0.6;
    config.traffic.profiles.residential.weekend.morning = 0.8;
    config.traffic.profiles.residential.weekend.midday = 0.7;
    config.traffic.profiles.residential.weekend.evening = 0.8;
    config.traffic.profiles.residential.weekend.late = 0.7;
    
    % --- Office ---
    config.traffic.profiles.office.weekday.night = 0.05;
    config.traffic.profiles.office.weekday.morning = 0.7;
    config.traffic.profiles.office.weekday.midday = 0.9;
    config.traffic.profiles.office.weekday.evening = 0.5;
    config.traffic.profiles.office.weekday.late = 0.05;
    
    config.traffic.profiles.office.weekend.night = 0.02;
    config.traffic.profiles.office.weekend.morning = 0.05;
    config.traffic.profiles.office.weekend.midday = 0.05;
    config.traffic.profiles.office.weekend.evening = 0.05;
    config.traffic.profiles.office.weekend.late = 0.02;
    
    % --- Highway ---
    config.traffic.profiles.highway.weekday.night = 0.2;
    config.traffic.profiles.highway.weekday.morning = 0.95;           % Rush hour!
    config.traffic.profiles.highway.weekday.midday = 0.6;
    config.traffic.profiles.highway.weekday.evening = 0.95;           % Rush hour!
    config.traffic.profiles.highway.weekday.late = 0.3;
    
    config.traffic.profiles.highway.weekend.night = 0.2;
    config.traffic.profiles.highway.weekend.morning = 0.5;
    config.traffic.profiles.highway.weekend.midday = 0.6;
    config.traffic.profiles.highway.weekend.evening = 0.7;
    config.traffic.profiles.highway.weekend.late = 0.4;
    
    % --- Parking Lot ---
    config.traffic.profiles.parking_lot.weekday.night = 0.1;
    config.traffic.profiles.parking_lot.weekday.morning = 0.5;
    config.traffic.profiles.parking_lot.weekday.midday = 0.6;
    config.traffic.profiles.parking_lot.weekday.evening = 0.7;
    config.traffic.profiles.parking_lot.weekday.late = 0.3;
    
    config.traffic.profiles.parking_lot.weekend.night = 0.1;
    config.traffic.profiles.parking_lot.weekend.morning = 0.6;
    config.traffic.profiles.parking_lot.weekend.midday = 0.8;
    config.traffic.profiles.parking_lot.weekend.evening = 0.7;
    config.traffic.profiles.parking_lot.weekend.late = 0.4;
    
    % --- Park ---
    config.traffic.profiles.park.weekday.night = 0.05;
    config.traffic.profiles.park.weekday.morning = 0.3;
    config.traffic.profiles.park.weekday.midday = 0.4;
    config.traffic.profiles.park.weekday.evening = 0.5;
    config.traffic.profiles.park.weekday.late = 0.1;
    
    config.traffic.profiles.park.weekend.night = 0.05;
    config.traffic.profiles.park.weekend.morning = 0.6;
    config.traffic.profiles.park.weekend.midday = 0.8;
    config.traffic.profiles.park.weekend.evening = 0.7;
    config.traffic.profiles.park.weekend.late = 0.2;
    
    % Traffic effect on SINR
    config.traffic.max_interference_db = 20;    % [dB] Maximum interference at full load
    
    %% ======================================================================
    %  Output
    %% ======================================================================
    
    config.output.format = 'csv';               % 'csv', 'mat', or 'hdf5'
    config.output.directory = './results/';     % Output directory
    config.output.filename_prefix = 'simulation'; % Filename prefix
    config.output.include_timestamp = true;     % Add timestamp to filename
    
    % Columns to save in CSV
    config.output.columns = {'timestamp', 'ue_id', 'x', 'y', ...
                             'area_id', 'area_type', 'scenario', ...
                             'area_load', 'weather_condition', ...
                             'in_transition', 'blend_factor', ...
                             'rsrp', 'rsrq', 'sinr', 'cqi', ...
                             'serving_bs', 'distance_to_bs'};
    
    % Save options
    config.output.save_channel_matrices = true; % Don't save full matrices (heavy!)
    config.output.save_trajectory = true;        % Save movement trajectories
    config.output.verbose = true;                % Print progress
    config.output.progress_interval = 30;        % [seconds] Print every 30s
    config.update_precantage = 2;                % printing update every 2%

    config.output.show_figures = false; % Opening plots at the end of the run
    
    %% ======================================================================
    %  QuaDRiGa Specific
    %% ======================================================================
    
    config.quadriga.use_absolute_delays = false; % Use relative delays
    config.quadriga.show_progress_bars = false;  % Don't show progress bars
    config.quadriga.use_3GPP_baseline = true;    % Use 3GPP baseline
    
    %% ======================================================================
    %  Debug & Validation
    %% ======================================================================
    
    config.debug.enabled = false;               % Debug mode
    config.debug.plot_areas = true;             % Plot areas
    config.debug.plot_trajectories = true;      % Plot trajectories
    config.debug.plot_csi = false;              % Plot CSI (slow!)
    config.debug.save_plots = true;             % Save plots
    
    config.validation.check_bounds = true;      % Check UEs stay within bounds
    config.validation.check_reports = true;     % Check number of reports
    config.validation.check_csi_range = true;   % Check CSI is in reasonable range
    
    %% ======================================================================
    %  Derived Calculations & Validation
    %% ======================================================================
    
    % Calculate wavelength
    config.wavelength = 3e8 / config.frequency; % [meters]
    
    % Validation checks
    assert(config.bs.num == size(config.bs.positions, 1), ...
        'Number of BSs does not match number of rows in positions');
    
    assert(config.bs.num_tx == config.bs.array_rows * config.bs.array_cols, ...
        'Number of Tx antennas does not match array configuration');
    
    assert(config.timing.total_duration > config.timing.csi_report_interval, ...
        'Simulation duration must be longer than CSI report interval');
    
    % Print summary
    if config.output.verbose
        fprintf('========================================\n');
        fprintf('  QuaDRiGa Massive MIMO Simulation\n');
        fprintf('========================================\n');
        fprintf('Random Seeds (for reproducibility):\n');
        fprintf('  Master seed: %d\n', config.random_seed);
        fprintf('  Areas seed: %d\n', config.random_seed_areas);
        fprintf('  Mobility seed: %d\n', config.random_seed_mobility);
        fprintf('Simulation datetime: %s\n', datestr(config.simulation_datetime));
        fprintf('Area: %.0f x %.0f meters\n', config.area_width, config.area_height);
        fprintf('Areas: %d\n', config.num_areas);
        fprintf('\nMassive MIMO Configuration:\n');
        fprintf('Base Stations: %d\n', config.bs.num);
        fprintf('  Antennas: %dx%d = %d elements (Array: %dx%d)\n', ...
            config.bs.num_tx, config.bs.num_rx, config.bs.num_tx, ...
            config.bs.array_rows, config.bs.array_cols);
        fprintf('  Azimuths: [%.0f deg, %.0f deg]\n', config.bs.azimuth);
        fprintf('User Equipment: %d\n', config.ue.num);
        fprintf('  Antennas: %dx%d = 4 elements (Array: %dx%d)\n', ...
            config.ue.num_tx, config.ue.num_rx, ...
            config.ue.array_rows, config.ue.array_cols);
        fprintf('Frequency: %.2f GHz (Lambda=%.4f m)\n', config.frequency/1e9, config.wavelength);
        fprintf('Duration: %.0f sec (%.1f min)\n', config.timing.total_duration, config.timing.total_duration/60);
        fprintf('CSI reports: %.0f per UE (total %.0f)\n', ...
            config.timing.num_csi_reports, config.timing.num_csi_reports * config.ue.num);
        fprintf('Weather Enabled: %s | Traffic Enabled: %s\n', string(config.weather.enabled), string(config.traffic.enabled));
        fprintf('========================================\n');
    end

end