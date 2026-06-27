classdef TimeManager < handle
% TIMEMANAGER - Manage simulation time and event scheduling
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class handles the progression of simulation time and controls
% the precise scheduling of events such as position updates, velocity
% changes, and CSI reporting. It explicitly tracks next event times to
% avoid floating-point precision issues.
%
% Properties:
%   current_time            - Current simulation time [s]
%   total_duration          - Total simulation duration [s]
%   csi_report_interval     - CSI report interval [s]
%   position_update_dt      - Position update timestep [s]
%   mobility_update_dt      - Mobility update interval [s]

    properties
        current_time            
        total_duration          
        csi_report_interval     
        position_update_dt      
        mobility_update_dt      
        
        % Internal counters
        position_update_counter
        csi_report_counter
        mobility_update_counter
        
        % Event tracking
        next_csi_report_time
        next_velocity_update_time
        
        % Tolerances for floating point comparison
        time_tolerance = 1e-6;
    end
    
    methods
        
        function obj = TimeManager(config)
            % TIMEMANAGER Constructor
            %
            % Input:
            %   config - Simulation configuration struct
            
            % Initialize from config
            obj.total_duration = config.timing.total_duration;
            obj.csi_report_interval = config.timing.csi_report_interval;
            obj.position_update_dt = config.timing.position_update_dt;
            obj.mobility_update_dt = config.timing.mobility_update_dt;
            
            % Initialize time and counters
            obj.current_time = 0;
            obj.position_update_counter = 0;
            obj.csi_report_counter = 0;
            obj.mobility_update_counter = 0;
            
            % Initialize next event times
            obj.next_csi_report_time = 0;  % First report at t=0
            obj.next_velocity_update_time = obj.mobility_update_dt;  % First update at mobility interval
            
            fprintf('[TimeManager] Initialized\n');
            fprintf('  Total duration: %.0f s (%.1f min)\n', ...
                obj.total_duration, obj.total_duration/60);
            fprintf('  CSI interval: %.2f s\n', obj.csi_report_interval);
            fprintf('  Position update: %.2f s\n', obj.position_update_dt);
            fprintf('  Mobility update: %.0f s\n', obj.mobility_update_dt);
        end
        
        
        function should = should_update_positions(obj)
            % SHOULD_UPDATE_POSITIONS Check if it's time to update UE positions
            
            % Always update positions (this is the main timestep)
            should = true;
        end
        
        function should = check_and_advance_csi(obj)
            % WARNING: This method advances the schedule when it returns true.
            % Call it ONCE per loop iteration only. For read-only checks use
            % is_csi_due() instead.
            should = (obj.current_time >= obj.next_csi_report_time - obj.time_tolerance);
            if should
                obj.next_csi_report_time = obj.next_csi_report_time + obj.csi_report_interval;
                obj.csi_report_counter = obj.csi_report_counter + 1;
            end
        end

        function result = is_csi_due(obj)
            % Read-only check — does NOT advance the schedule. Safe to call anywhere.
            result = (obj.current_time >= obj.next_csi_report_time - obj.time_tolerance);
        end

        function should = check_and_advance_velocities(obj)
            % WARNING: Same note as check_and_advance_csi — call once per loop only.
            if obj.current_time < obj.time_tolerance
                should = false;
                return;
            end
            should = (obj.current_time >= obj.next_velocity_update_time - obj.time_tolerance);
            if should
                obj.next_velocity_update_time = obj.next_velocity_update_time + obj.mobility_update_dt;
                obj.mobility_update_counter = obj.mobility_update_counter + 1;
            end
        end
        
        function should = should_report_csi(obj)
            % SHOULD_REPORT_CSI Check if it's time to report CSI
            %
            % Uses explicit time tracking to ensure precise reporting intervals.
            
            % Check if we've reached or passed the next CSI report time
            should = (obj.current_time >= obj.next_csi_report_time - obj.time_tolerance);
            
            % If we're reporting, schedule next report
            if should
                obj.next_csi_report_time = obj.next_csi_report_time + obj.csi_report_interval;
            end
        end
        
        
        function should = should_update_velocities(obj)
            % SHOULD_UPDATE_VELOCITIES Check if it's time to update UE velocities
            %
            % Uses explicit time tracking to determine velocity updates.
            
            % Skip first timestep (t=0)
            if obj.current_time < obj.time_tolerance
                should = false;
                return;
            end
            
            % Check if we've reached or passed the next velocity update time
            should = (obj.current_time >= obj.next_velocity_update_time - obj.time_tolerance);
            
            % If we're updating, schedule next update
            if should
                obj.next_velocity_update_time = obj.next_velocity_update_time + obj.mobility_update_dt;
            end
        end
        
        
        function advance_time(obj, dt)
            % ADVANCE_TIME Advance simulation time by dt seconds
            %
            % Input:
            %   dt - Time step in seconds
            
            obj.current_time = obj.current_time + dt;
            
            % Update counters (these happen AFTER should_* checks)
            obj.position_update_counter = obj.position_update_counter + 1;
        end
        
        
        function finished = is_finished(obj)
            % IS_FINISHED Check if simulation has completed
            
            finished = (obj.current_time >= obj.total_duration);
        end
        
        
        function percentage = get_progress_percentage(obj)
            % GET_PROGRESS_PERCENTAGE Get simulation completion percentage
            
            percentage = (obj.current_time / obj.total_duration) * 100;
            percentage = min(100, max(0, percentage));  % Clamp to [0, 100]
        end
        
        
        function reset(obj)
            % RESET Reset time manager to initial state
            
            obj.current_time = 0;
            obj.position_update_counter = 0;
            obj.csi_report_counter = 0;
            obj.mobility_update_counter = 0;
            
            % Reset next event times
            obj.next_csi_report_time = 0;
            obj.next_velocity_update_time = obj.mobility_update_dt;
            
            fprintf('[TimeManager] Reset to t=0\n');
        end
        
        
        function print_status(obj)
            % PRINT_STATUS Display current time manager status
            
            fprintf('\n--- TimeManager Status ---\n');
            fprintf('Current time: %.2f s (%.1f%%)\n', ...
                obj.current_time, obj.get_progress_percentage());
            fprintf('Position updates: %d\n', obj.position_update_counter);
            fprintf('CSI reports: %d\n', obj.csi_report_counter);
            fprintf('Mobility updates: %d\n', obj.mobility_update_counter);
            fprintf('Next CSI report: %.2f s\n', obj.next_csi_report_time);
            fprintf('Finished: %s\n', string(obj.is_finished()));
            fprintf('-------------------------\n\n');
        end
        
        
        function stats = get_statistics(obj)
            % GET_STATISTICS Get timing statistics
            %
            % Output:
            %   stats - Struct containing timing and execution counts
            
            stats = struct();
            stats.current_time = obj.current_time;
            stats.total_duration = obj.total_duration;
            stats.progress_percentage = obj.get_progress_percentage();
            stats.position_updates = obj.position_update_counter;
            stats.csi_reports = obj.csi_report_counter;
            stats.mobility_updates = obj.mobility_update_counter;
            stats.is_finished = obj.is_finished();
            
            % Calculate expected vs actual
            expected_csi = floor(obj.current_time / obj.csi_report_interval);
            expected_mobility = floor(obj.current_time / obj.mobility_update_dt);
            
            stats.expected_csi_reports = expected_csi;
            stats.expected_mobility_updates = expected_mobility;
        end
        
    end
end