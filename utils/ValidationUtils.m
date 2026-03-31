classdef ValidationUtils
% VALIDATIONUTILS - Validation and sanity checks
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static utility class acts as the "gatekeeper" for the simulation.
% It performs critical pre-run configuration checks to ensure physical and
% logical validity, as well as post-run integrity checks to guarantee the
% quality of the generated CSI dataset.
%
% Static methods for:
%   - Configuration validation (Pre-run)
%   - Position and boundary validation
%   - CSI metrics range validation (Post-run)
%   - Simulation data integrity checks
%   - Logical matching between area types and RF scenarios

    methods (Static)
        
        function validate_config(config)
            % VALIDATE_CONFIG Validate simulation configuration
            %
            % Performs sanity checks on the configuration parameters before
            % the simulation starts.
            %
            % Input:
            %   config - simulation config struct
            %
            % Throws an error if the configuration is logically or physically invalid.
            
            % Check area dimensions
            assert(config.area_width > 0, 'Area width must be positive');
            assert(config.area_height > 0, 'Area height must be positive');
            
            % Check number of areas
            assert(config.num_areas >= 2, 'Must have at least 2 areas');
            assert(config.num_areas <= 20, 'Too many areas (max 20)');
            
            % Check BS configuration
            assert(config.bs.num >= 1, 'Must have at least 1 base station');
            assert(config.bs.num_tx > 0, 'BS must have at least 1 Tx antenna');
            assert(config.bs.num_rx > 0, 'BS must have at least 1 Rx antenna');
            
            % Check UE configuration
            assert(config.ue.num >= 1, 'Must have at least 1 UE');
            assert(config.ue.num_tx > 0, 'UE must have at least 1 Tx antenna');
            assert(config.ue.num_rx > 0, 'UE must have at least 1 Rx antenna');
            
            % Check frequency
            assert(config.frequency > 0, 'Frequency must be positive');
            assert(config.frequency >= 1e9 && config.frequency <= 100e9, ...
                'Frequency should be between 1-100 GHz for typical wireless');
            
            % Check timing
            assert(config.timing.total_duration > 0, 'Duration must be positive');
            assert(config.timing.csi_report_interval > 0, 'CSI interval must be positive');
            assert(config.timing.position_update_dt > 0, 'Position update dt must be positive');
            
            % Check that intervals make sense
            assert(config.timing.total_duration >= config.timing.csi_report_interval, ...
                'Duration must be at least one CSI interval');
            assert(config.timing.csi_report_interval >= config.timing.position_update_dt, ...
                'CSI interval should be >= position update interval');
            
            % Check mobility parameters
            assert(config.mobility.speed_min >= 0, 'Minimum speed cannot be negative');
            assert(config.mobility.speed_max > config.mobility.speed_min, ...
                'Maximum speed must be greater than minimum speed');
            
            fprintf('[ValidationUtils] Configuration validation passed\n');
        end
        
        
        function validate_positions(positions, bounds)
            % VALIDATE_POSITIONS Check if positions are strictly within bounds
            %
            % Input:
            %   positions - [Nx2] matrix of [x, y] positions
            %   bounds    - [x_min, x_max, y_min, y_max]
            %
            % Throws an error if any position violates the simulation boundaries.
            
            x_coords = positions(:, 1);
            y_coords = positions(:, 2);
            
            x_valid = (x_coords >= bounds(1)) & (x_coords <= bounds(2));
            y_valid = (y_coords >= bounds(3)) & (y_coords <= bounds(4));
            
            all_valid = all(x_valid & y_valid);
            
            if ~all_valid
                num_invalid = sum(~(x_valid & y_valid));
                error('ValidationUtils:OutOfBounds', ...
                    '%d position(s) are out of bounds', num_invalid);
            end
        end
        
        
        function is_valid = validate_csi_metrics(rsrp, rsrq, sinr, cqi)
            % VALIDATE_CSI_METRICS Check if CSI metrics fall within reasonable ranges
            %
            % Validates scalar values against typical physical ranges for LTE/5G.
            %
            % Input:
            %   rsrp - Reference Signal Received Power [dBm]
            %   rsrq - Reference Signal Received Quality [dB]
            %   sinr - Signal to Interference plus Noise Ratio [dB]
            %   cqi  - Channel Quality Indicator (0-15)
            %
            % Output:
            %   is_valid - boolean, true if all metrics are within typical bounds
            %
            % Typical ranges for LTE/5G:
            %   RSRP: -140 to -40 dBm
            %   RSRQ: -20 to -3 dB
            %   SINR: -10 to 30 dB
            %   CQI:  0 to 15
            
            is_valid = true;
            
            % Check RSRP
            if rsrp < -140 || rsrp > -40
                warning('ValidationUtils:InvalidRSRP', ...
                    'RSRP %.1f dBm is outside typical range [-140, -40]', rsrp);
                is_valid = false;
            end
            
            % Check RSRQ
            if rsrq < -20 || rsrq > -3
                warning('ValidationUtils:InvalidRSRQ', ...
                    'RSRQ %.1f dB is outside typical range [-20, -3]', rsrq);
                is_valid = false;
            end
            
            % Check SINR
            if sinr < -10 || sinr > 30
                warning('ValidationUtils:InvalidSINR', ...
                    'SINR %.1f dB is outside typical range [-10, 30]', sinr);
                is_valid = false;
            end
            
            % Check CQI
            if cqi < 0 || cqi > 15
                warning('ValidationUtils:InvalidCQI', ...
                    'CQI %d is outside valid range [0, 15]', cqi);
                is_valid = false;
            end
        end
        
        
        function validate_simulation_data(data, config)
            % VALIDATE_SIMULATION_DATA Check overall simulation output integrity
            %
            % Input:
            %   data   - simulation output data structure
            %   config - simulation configuration struct
            %
            % Checks:
            %   - Correct number of expected reports per UE
            %   - Presence of all configured UEs in the output
            %   - Monotonically increasing timestamps
            
            expected_reports_per_ue = config.timing.num_csi_reports;
            num_ues = config.ue.num;
            
            fprintf('[ValidationUtils] Validating simulation data...\n');
            
            % Check if we have data for all UEs
            if length(data.ue_data) ~= num_ues
                error('Expected data for %d UEs, got %d', num_ues, length(data.ue_data));
            end
            
            % Check each UE data stream
            for ue_id = 1:num_ues
                ue_reports = data.ue_data{ue_id};
                
                % Check number of generated reports
                num_reports = size(ue_reports.csi_reports, 1);
                if num_reports ~= expected_reports_per_ue
                    warning('UE %d has %d reports, expected %d', ...
                        ue_id, num_reports, expected_reports_per_ue);
                end
                
                % Check that timestamps are monotonically increasing
                if ~issorted(ue_reports.timestamps)
                    warning('UE %d timestamps are not monotonically increasing', ue_id);
                end
            end
            
            fprintf('[ValidationUtils] Validation complete\n');
        end
        
        
        function check_area_coverage(areas, bounds)
            % CHECK_AREA_COVERAGE Verify that all area seeds are strictly within bounds
            %
            % Input:
            %   areas  - struct array with field 'seed'
            %   bounds - [x_min, x_max, y_min, y_max]
            
            num_areas = length(areas);
            
            for i = 1:num_areas
                seed = areas(i).seed;
                
                if seed(1) < bounds(1) || seed(1) > bounds(2) || ...
                   seed(2) < bounds(3) || seed(2) > bounds(4)
                    error('Area %d seed [%.1f, %.1f] is outside bounds', ...
                        i, seed(1), seed(2));
                end
            end
        end
        
        
        function validate_area_type_scenario_match(areas)
            % VALIDATE_AREA_TYPE_SCENARIO_MATCH Check logical matching of area types and scenarios
            %
            % Validates that the assigned 3GPP scenarios make physical sense 
            % for the designated area types. For example:
            %   - shopping_center should not be LOS (enclosed structure)
            %   - park should generally not be NLOS (open space)
            %   - highway should utilize RMa (rural macro)
            %
            % Input:
            %   areas - struct array with fields 'area_type' and 'scenario'
            %
            % Throws warnings (not errors) if logical mismatches are detected.
            
            num_areas = length(areas);
            num_warnings = 0;
            
            for i = 1:num_areas
                area_type = areas(i).area_type;
                scenario = areas(i).scenario;
                
                % Check logical consistency based on area type
                switch area_type
                    case 'shopping_center'
                        if contains(scenario, 'LOS') && ~contains(scenario, 'NLOS')
                            warning('Area %d: shopping_center typically should be NLOS (enclosed), but got %s', ...
                                i, scenario);
                            num_warnings = num_warnings + 1;
                        end
                        
                    case 'park'
                        if contains(scenario, 'NLOS') && ~contains(scenario, 'LOS')
                            warning('Area %d: park typically should be LOS (open), but got %s', ...
                                i, scenario);
                            num_warnings = num_warnings + 1;
                        end
                        
                    case 'parking_lot'
                        if contains(scenario, 'NLOS') && ~contains(scenario, 'LOS')
                            warning('Area %d: parking_lot typically should be LOS (open), but got %s', ...
                                i, scenario);
                            num_warnings = num_warnings + 1;
                        end
                        
                    case 'highway'
                        if ~contains(scenario, 'RMa')
                            warning('Area %d: highway typically should be RMa (rural macro), but got %s', ...
                                i, scenario);
                            num_warnings = num_warnings + 1;
                        end
                        
                    case 'office'
                        if contains(scenario, 'LOS') && ~contains(scenario, 'NLOS')
                            warning('Area %d: office typically should be NLOS (buildings), but got %s', ...
                                i, scenario);
                            num_warnings = num_warnings + 1;
                        end
                end
            end
            
            if num_warnings == 0
                fprintf('[ValidationUtils] Area type-scenario matching validated\n');
            else
                fprintf('[ValidationUtils] Found %d area type-scenario mismatches (warnings above)\n', num_warnings);
            end
        end
        
        
        function report_statistics(data)
            % REPORT_STATISTICS Print high-level summary statistics of simulation data
            %
            % Input:
            %   data - simulation output data structure
            
            fprintf('\n========================================\n');
            fprintf('  Simulation Statistics\n');
            fprintf('========================================\n');
            
            num_ues = length(data.ue_data);
            fprintf('Number of UEs: %d\n', num_ues);
            
            % Calculate total reports across all UEs
            total_reports = 0;
            for ue_id = 1:num_ues
                total_reports = total_reports + size(data.ue_data{ue_id}.csi_reports, 1);
            end
            fprintf('Total CSI reports: %d\n', total_reports);
            fprintf('Average reports per UE: %.1f\n', total_reports / num_ues);
            
            % If CSI metrics are available, aggregate and display ranges
            if isfield(data.ue_data{1}, 'csi_reports')
                all_rsrp = [];
                all_sinr = [];
                
                for ue_id = 1:num_ues
                    csi = data.ue_data{ue_id}.csi_reports;
                    if size(csi, 2) >= 2
                        all_rsrp = [all_rsrp; csi(:, 1)];
                        all_sinr = [all_sinr; csi(:, 2)];
                    end
                end
                
                if ~isempty(all_rsrp)
                    fprintf('\nRSRP range: [%.1f, %.1f] dBm\n', min(all_rsrp), max(all_rsrp));
                    fprintf('RSRP mean: %.1f dBm\n', mean(all_rsrp));
                end
                
                if ~isempty(all_sinr)
                    fprintf('SINR range: [%.1f, %.1f] dB\n', min(all_sinr), max(all_sinr));
                    fprintf('SINR mean: %.1f dB\n', mean(all_sinr));
                end
            end
            
            fprintf('========================================\n\n');
        end
        
    end
end