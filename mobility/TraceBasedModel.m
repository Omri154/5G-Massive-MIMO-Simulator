classdef TraceBasedModel < handle
% TRACEBASEDMODEL - Trace-based mobility model for UEs
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class implements a stateful trace-based mobility model where UE
% movement is driven by a pre-defined CSV file containing waypoints.
% Each UE follows a sequence of (x, y) positions with specified departure
% times. Positions between waypoints are linearly interpolated.
%
% CSV Format (one row per waypoint):
%   ue_id, x, y, departure_time
%   1, 45.2, 88.1, 2024-01-15 08:30:00
%   1, 102.7, 134.5, 2024-01-15 08:32:10
%
% Columns:
%   ue_id          - UE identifier (integer, 1-indexed)
%   x              - X position in meters
%   y              - Y position in meters
%   departure_time - When the UE LEAVES this waypoint (datetime string)
%
% Notes:
%   - Speed is derived from distance / time (not a CSV column)
%   - Each UE can have a different number of waypoints
%   - To make a UE stay at a point: repeat the same (x,y) with two
%     different departure_times (see README for home/work example)
%   - UEs missing from CSV get a stationary fallback position
%   - Different UEs can have completely different numbers of waypoints

    properties
        traces               % Struct array holding waypoint data per UE
        current_segment_idx  % [Nx1] tracks active segment index per UE (stateful O(1) lookup)
        num_ues              % Total number of UEs
        config               % Reference to simulation configuration
    end

    methods

        function obj = TraceBasedModel(csv_path, config)
            % TRACEBASEDMODEL Constructor
            %
            % Input:
            %   csv_path - path to the waypoint CSV file
            %   config   - simulation configuration struct
            %
            % Example:
            %   model = TraceBasedModel('./data/ue_traces.csv', config);

            obj.config  = config;
            obj.num_ues = config.ue.num;

            % Initialize segment indices to 1 (all UEs start at first segment)
            obj.current_segment_idx = ones(obj.num_ues, 1);

            % Load CSV data
            obj.load_traces(csv_path);

            % Validate physics (separate from load so it can be skipped if needed)
            obj.validate_trace_physics();
        end


        function load_traces(obj, csv_path)
            % LOAD_TRACES Load and validate waypoint data from CSV
            %
            % Reads the CSV, validates required columns, parses datetimes,
            % sorts each UE's rows by departure time, clamps out-of-bounds
            % positions, and builds the internal traces struct array.

            fprintf('[TraceBasedModel] Loading traces from: %s\n', csv_path);

            % --- Check file exists ---
            if ~isfile(csv_path)
                error('[TraceBasedModel] CSV file not found: %s', csv_path);
            end

            % --- Read CSV ---
            try
                raw = readtable(csv_path, ...
                    'VariableNamingRule', 'preserve', ...
                    'TextType', 'string');
            catch ME
                error('[TraceBasedModel] Failed to read CSV: %s', ME.message);
            end

            fprintf('[TraceBasedModel] CSV loaded: %d rows\n', height(raw));

            % --- Validate required columns (no avg_speed - derived from physics) ---
            required_cols = {'ue_id', 'x', 'y', 'departure_time'};
            for c = 1:length(required_cols)
                if ~ismember(required_cols{c}, raw.Properties.VariableNames)
                    error('[TraceBasedModel] Missing required column: "%s"', required_cols{c});
                end
            end

            % --- Parse departure_time ---
            try
                raw.departure_time = datetime(raw.departure_time, ...
                    'InputFormat', 'yyyy-MM-dd HH:mm:ss');
            catch ME
                error('[TraceBasedModel] Could not parse departure_time. Expected format: "yyyy-MM-dd HH:mm:ss". Error: %s', ME.message);
            end

            % --- Build per-UE trace structs ---
            bounds    = obj.config.area_bounds;
            sim_start = obj.config.simulation_datetime;

            empty_trace = struct( ...
                'ue_id',           0,  ...
                'waypoints',       [], ...
                'departure_times', [], ...
                'num_waypoints',   0);
            obj.traces = repmat(empty_trace, 1, obj.num_ues);

            missing_ues = [];
            warned_oob  = [];

            for ue_id = 1:obj.num_ues
                ue_mask = raw.ue_id == ue_id;

                % --- Missing UE: create stationary fallback ---
                if sum(ue_mask) == 0
                    missing_ues(end+1) = ue_id; %#ok<AGROW>
                    obj.traces(ue_id)  = obj.make_fallback_trace(ue_id, bounds, sim_start);
                    continue;
                end

                % --- Extract rows and sort by departure time ---
                ue_rows  = raw(ue_mask, :);
                [~, si]  = sort(ue_rows.departure_time);
                ue_rows  = ue_rows(si, :);

                waypoints = [ue_rows.x, ue_rows.y];
                dep_times = ue_rows.departure_time;

                % --- Clamp out-of-bounds positions ---
                x_oob = waypoints(:,1) < bounds(1) | waypoints(:,1) > bounds(2);
                y_oob = waypoints(:,2) < bounds(3) | waypoints(:,2) > bounds(4);
                oob   = x_oob | y_oob;
                if any(oob) && ~ismember(ue_id, warned_oob)
                    warning('[TraceBasedModel] UE %d has %d waypoint(s) outside bounds. Clamping.', ...
                        ue_id, sum(oob));
                    waypoints(:,1) = max(bounds(1), min(bounds(2), waypoints(:,1)));
                    waypoints(:,2) = max(bounds(3), min(bounds(4), waypoints(:,2)));
                    warned_oob(end+1) = ue_id; %#ok<AGROW>
                end

                % --- Validate departure times are strictly increasing ---
                if any(seconds(diff(dep_times)) <= 0)
                    error('[TraceBasedModel] UE %d has non-increasing departure_times. Each row must be later than the previous.', ue_id);
                end

                % --- Store ---
                obj.traces(ue_id).ue_id           = ue_id;
                obj.traces(ue_id).waypoints        = waypoints;
                obj.traces(ue_id).departure_times  = dep_times;
                obj.traces(ue_id).num_waypoints    = size(waypoints, 1);
            end

            % --- Report missing UEs ---
            if ~isempty(missing_ues)
                warning('[TraceBasedModel] %d UE(s) not found in CSV (IDs: %s). Using stationary fallback.', ...
                    length(missing_ues), num2str(missing_ues));
            end

            fprintf('[TraceBasedModel] Traces loaded for %d UEs (%d missing/fallback)\n', ...
                obj.num_ues, length(missing_ues));
            obj.print_trace_summary();
        end


        function positions = initialize_positions(obj, sim_start_datetime)
            % INITIALIZE_POSITIONS Get starting positions of all UEs at t=0
            %
            % Also resets segment indices so the model is safe to reinitialize.
            %
            % Input:
            %   sim_start_datetime - datetime of simulation start
            %
            % Output:
            %   positions - [Nx2] matrix of [x, y]

            % Reset segment state so initialization is always correct
            % even if called after the simulation has already run partway
            obj.current_segment_idx = ones(obj.num_ues, 1);

            positions = obj.step(sim_start_datetime);
            fprintf('[TraceBasedModel] Initialized %d UE positions at simulation start.\n', obj.num_ues);
        end


        function positions = step(obj, current_datetime)
            % STEP High-performance stateful position update for all UEs
            %
            % Uses the saved current_segment_idx per UE for O(1) average
            % performance — only advances the index forward, never searches
            % from the beginning.
            %
            % IMPORTANT: This method modifies current_segment_idx as a side
            % effect. Only call it from the main simulation loop with the
            % true current simulation time. For statistics or one-off queries
            % use get_position_at_time() instead.
            %
            % Input:
            %   current_datetime - datetime object for current sim time
            %
            % Output:
            %   positions - [Nx2] matrix of [x, y]

            positions = zeros(obj.num_ues, 2);

            for ue_id = 1:obj.num_ues
                tr  = obj.traces(ue_id);
                idx = obj.current_segment_idx(ue_id);

                % Advance segment index forward if time has passed the next waypoint
                while idx < tr.num_waypoints && ...
                        current_datetime >= tr.departure_times(idx + 1)
                    idx = idx + 1;
                end
                obj.current_segment_idx(ue_id) = idx;  % Save updated state

                % Before trace begins: stay at first waypoint
                if current_datetime <= tr.departure_times(1)
                    positions(ue_id, :) = tr.waypoints(1, :);
                    continue;
                end

                % After trace ends: stay at last waypoint
                if idx == tr.num_waypoints
                    positions(ue_id, :) = tr.waypoints(end, :);
                    continue;
                end

                % Active segment: linear interpolation
                t_start  = tr.departure_times(idx);
                t_end    = tr.departure_times(idx + 1);
                seg_dur  = seconds(t_end - t_start);

                if seg_dur <= 0
                    positions(ue_id, :) = tr.waypoints(idx + 1, :);
                else
                    elapsed = seconds(current_datetime - t_start);
                    alpha   = min(1.0, max(0.0, elapsed / seg_dur));
                    p_start = tr.waypoints(idx, :);
                    p_end   = tr.waypoints(idx + 1, :);
                    positions(ue_id, :) = p_start + alpha * (p_end - p_start);
                end
            end
        end


        function position = get_position_at_time(obj, tr, current_datetime)
            % GET_POSITION_AT_TIME Stateless position query for a single UE
            %
            % Unlike step(), this method does NOT modify current_segment_idx.
            % Safe to call from get_mobility_statistics(), plot functions,
            % or any context that needs a position without advancing state.
            %
            % Input:
            %   tr               - single UE trace struct (obj.traces(ue_id))
            %   current_datetime - datetime object
            %
            % Output:
            %   position - [x, y] in meters

            % Before trace begins
            if current_datetime <= tr.departure_times(1)
                position = tr.waypoints(1, :);
                return;
            end

            % After trace ends
            if current_datetime >= tr.departure_times(end)
                position = tr.waypoints(end, :);
                return;
            end

            % Find segment using search (stateless - no saved index used)
            idx = find(tr.departure_times <= current_datetime, 1, 'last');

            if isempty(idx) || idx >= tr.num_waypoints
                position = tr.waypoints(end, :);
                return;
            end

            t_start = tr.departure_times(idx);
            t_end   = tr.departure_times(idx + 1);
            seg_dur = seconds(t_end - t_start);

            if seg_dur <= 0
                position = tr.waypoints(idx + 1, :);
                return;
            end

            alpha    = min(1.0, max(0.0, seconds(current_datetime - t_start) / seg_dur));
            position = tr.waypoints(idx, :) + alpha * (tr.waypoints(idx+1, :) - tr.waypoints(idx, :));
        end


        function speeds = get_current_speeds(obj, current_datetime)
            % GET_CURRENT_SPEEDS Calculate physical speed for each UE
            %
            % Speed is derived from distance / segment_duration.
            % Does NOT use current_segment_idx — fully stateless so it is
            % safe to call from any context including statistics and plots.
            %
            % Input:
            %   current_datetime - datetime object
            %
            % Output:
            %   speeds - [Nx1] vector of speeds in m/s

            speeds = zeros(obj.num_ues, 1);

            for ue_id = 1:obj.num_ues
                tr = obj.traces(ue_id);

                % Before or after trace: stationary
                if current_datetime <= tr.departure_times(1) || ...
                        current_datetime >= tr.departure_times(end)
                    speeds(ue_id) = 0;
                    continue;
                end

                % Find active segment via search (stateless)
                idx = find(tr.departure_times <= current_datetime, 1, 'last');

                if ~isempty(idx) && idx < tr.num_waypoints
                    dist = norm(tr.waypoints(idx+1, :) - tr.waypoints(idx, :));
                    dur  = seconds(tr.departure_times(idx+1) - tr.departure_times(idx));
                    if dur > 0
                        speeds(ue_id) = dist / dur;
                    end
                end
            end
        end


        function stats = get_mobility_statistics(obj, current_datetime)
            % GET_MOBILITY_STATISTICS Compute mobility statistics at a given time
            %
            % Uses stateless helpers (get_position_at_time, get_current_speeds)
            % so calling this never corrupts the simulation segment state.
            % Returns the same struct format as RandomWalkModel for compatibility.
            %
            % Input:
            %   current_datetime - datetime object
            %
            % Output:
            %   stats - struct with fields:
            %           num_ues, mean_position, std_position,
            %           mean_speed, max_speed, min_speed, num_stationary

            % Use stateless position query — NOT step()
            positions = zeros(obj.num_ues, 2);
            for ue_id = 1:obj.num_ues
                positions(ue_id, :) = obj.get_position_at_time( ...
                    obj.traces(ue_id), current_datetime);
            end

            % Use stateless speed query
            speeds = obj.get_current_speeds(current_datetime);

            stats.num_ues        = obj.num_ues;
            stats.mean_position  = mean(positions, 1);
            stats.std_position   = std(positions, 0, 1);
            stats.mean_speed     = mean(speeds);
            stats.max_speed      = max(speeds);
            stats.min_speed      = min(speeds);
            stats.num_stationary = sum(speeds < 0.01);
        end


        function validate_trace_physics(obj)
            % VALIDATE_TRACE_PHYSICS Warn if implied speeds exceed physical limits
            %
            % Compares distance/time per segment against config.mobility.speed_max.
            % Uses a 50% tolerance buffer to account for legitimate bursts
            % (e.g. a UE on a bus briefly exceeds walking speed_max).
            % Issues warnings, not errors, so simulation can still proceed.

            fprintf('[TraceBasedModel] Validating physical speed limits...\n');

            max_allowed = obj.config.mobility.speed_max * 1.5;
            num_warnings = 0;

            for ue_id = 1:obj.num_ues
                tr = obj.traces(ue_id);
                for i = 1:(tr.num_waypoints - 1)
                    dist = norm(tr.waypoints(i+1, :) - tr.waypoints(i, :));
                    dur  = seconds(tr.departure_times(i+1) - tr.departure_times(i));

                    if dur <= 0
                        continue;
                    end

                    implied_speed = dist / dur;

                    if implied_speed > max_allowed
                        warning('[TraceBasedModel] UE %d segment %d: implied speed = %.1f m/s (%.0f km/h) exceeds config max (%.1f m/s).', ...
                            ue_id, i, implied_speed, implied_speed * 3.6, obj.config.mobility.speed_max);
                        num_warnings = num_warnings + 1;
                    end
                end
            end

            if num_warnings == 0
                fprintf('[TraceBasedModel] All segments within physical speed limits.\n');
            else
                fprintf('[TraceBasedModel] %d speed warning(s). Check waypoint timing.\n', num_warnings);
            end
        end


        function generate_example_csv(obj, output_path)
            % GENERATE_EXAMPLE_CSV Write a sample CSV for testing
            %
            % Creates a valid CSV with realistic waypoints for all UEs in
            % config. Each UE gets a random route with a home/work/return
            % pattern to demonstrate the stay-at-point feature.
            %
            % Input:
            %   output_path - where to write the CSV (e.g. './data/ue_traces.csv')

            fprintf('[TraceBasedModel] Generating example CSV: %s\n', output_path);

            config      = obj.config;
            num_ues     = config.ue.num;
            sim_start   = config.simulation_datetime;
            bounds      = config.area_bounds;
            x_min = bounds(1); x_max = bounds(2);
            y_min = bounds(3); y_max = bounds(4);
            total_dur   = config.timing.total_duration;

            fid = fopen(output_path, 'w');
            if fid == -1
                error('[TraceBasedModel] Cannot open output file: %s', output_path);
            end

            fprintf(fid, 'ue_id,x,y,departure_time\n');

            rng(42);  % Fixed seed for reproducible example output

            for ue_id = 1:num_ues
                % Each UE: home -> (optional midpoint) -> work -> work stay -> home
                home = [x_min + (x_max-x_min)*rand(), y_min + (y_max-y_min)*rand()];
                work = [x_min + (x_max-x_min)*rand(), y_min + (y_max-y_min)*rand()];

                % t=0:          at home, about to leave
                % t=20% dur:    arrives at work
                % t=80% dur:    leaves work
                % t=100% dur:   arrives home
                t0   = sim_start;
                t1   = sim_start + seconds(total_dur * 0.20);
                t2   = sim_start + seconds(total_dur * 0.80);
                t3   = sim_start + seconds(total_dur * 1.00);

                waypoints = [home; work; work; home];
                dep_times = [t0; t1; t2; t3];

                for wp = 1:4
                    dep_str = datestr(dep_times(wp), 'yyyy-mm-dd HH:MM:SS');
                    fprintf(fid, '%d,%.2f,%.2f,%s\n', ...
                        ue_id, waypoints(wp,1), waypoints(wp,2), dep_str);
                end
            end

            fclose(fid);
            fprintf('[TraceBasedModel] Example CSV written: %d UEs, 4 waypoints each.\n', num_ues);
            fprintf('  Pattern: home -> work (stay) -> home\n');
        end


        function fig = plot_trajectories(obj, num_ues_to_plot)
            % PLOT_TRAJECTORIES Visualize waypoint paths for a subset of UEs
            %
            % Input:
            %   num_ues_to_plot - (optional) how many UEs to plot (default: 10)
            %
            % Output:
            %   fig - figure handle

            if nargin < 2
                num_ues_to_plot = min(10, obj.num_ues);
            end

            config = obj.config;
            fig = figure('Name', 'Trace-Based UE Trajectories', ...
                'Position', [100, 100, 800, 700]);
            hold on;
            grid on;

            x_min = config.area_bounds(1); x_max = config.area_bounds(2);
            y_min = config.area_bounds(3); y_max = config.area_bounds(4);

            rectangle('Position', [x_min, y_min, x_max-x_min, y_max-y_min], ...
                'EdgeColor', 'k', 'LineWidth', 2, 'LineStyle', '--');

            colors = lines(num_ues_to_plot);

            for i = 1:num_ues_to_plot
                tr = obj.traces(i);
                if tr.num_waypoints == 0
                    continue;
                end

                wp = tr.waypoints;

                % Path line
                plot(wp(:,1), wp(:,2), '-', 'Color', colors(i,:), 'LineWidth', 1.5);

                % All waypoints as dots
                scatter(wp(:,1), wp(:,2), 40, colors(i,:), 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 1);

                % Start marker (circle)
                plot(wp(1,1), wp(1,2), 'o', 'MarkerSize', 9, ...
                    'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

                % End marker (square)
                plot(wp(end,1), wp(end,2), 's', 'MarkerSize', 9, ...
                    'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

                % UE label
                text(wp(1,1)+3, wp(1,2)+3, sprintf('UE%d', i), ...
                    'FontSize', 8, 'Color', colors(i,:), 'FontWeight', 'bold');
            end

            % BS positions
            if isfield(config, 'bs') && isfield(config.bs, 'positions')
                bs_pos = config.bs.positions;
                scatter(bs_pos(:,1), bs_pos(:,2), 200, 'r', '^', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 2);
            end

            axis equal;
            xlim([x_min, x_max]);
            ylim([y_min, y_max]);
            xlabel('X Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Y Position [m]', 'FontSize', 12, 'FontWeight', 'bold');
            title(sprintf('Trace-Based Trajectories (%d UEs shown)', num_ues_to_plot), ...
                'FontSize', 14, 'FontWeight', 'bold');

            h1 = plot(NaN, NaN, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
            h2 = plot(NaN, NaN, 's', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
            h3 = plot(NaN, NaN, 'k.', 'MarkerSize', 10);
            legend([h1, h2, h3], {'Start', 'End', 'Waypoint'}, 'Location', 'best');

            hold off;
            fprintf('[TraceBasedModel] Trajectory plot created.\n');
        end

    end


    methods (Access = private)

        function trace = make_fallback_trace(~, ue_id, bounds, sim_start)
            % MAKE_FALLBACK_TRACE Stationary trace for a UE missing from CSV
            x = bounds(1) + (bounds(2) - bounds(1)) * rand();
            y = bounds(3) + (bounds(4) - bounds(3)) * rand();

            trace.ue_id           = ue_id;
            trace.waypoints        = [x, y; x, y];
            trace.departure_times  = [sim_start; sim_start + seconds(1)];
            trace.num_waypoints    = 2;
        end


        function print_trace_summary(obj)
            % PRINT_TRACE_SUMMARY Print a compact summary of loaded traces

            fprintf('\n--- Trace Summary ---\n');
            total_wp = 0;
            show_n   = min(obj.num_ues, 5);

            for ue_id = 1:show_n
                tr  = obj.traces(ue_id);
                total_wp = total_wp + tr.num_waypoints;
                if tr.num_waypoints >= 2
                    dur = seconds(tr.departure_times(end) - tr.departure_times(1));
                else
                    dur = 0;
                end
                fprintf('  UE %3d: %2d waypoints, trace duration = %.0f s\n', ...
                    ue_id, tr.num_waypoints, dur);
            end

            if obj.num_ues > show_n
                for ue_id = (show_n+1):obj.num_ues
                    total_wp = total_wp + obj.traces(ue_id).num_waypoints;
                end
                fprintf('  ... and %d more UEs\n', obj.num_ues - show_n);
            end

            fprintf('  Total waypoints: %d (avg %.1f per UE)\n', ...
                total_wp, total_wp / obj.num_ues);
            fprintf('---------------------\n\n');
        end

    end
end
