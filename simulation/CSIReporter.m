classdef CSIReporter < handle
% CSIREPORTER - Optimized CSI Reporter with batch QuaDRiGa processing
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class handles the generation of Channel State Information (CSI)
% reports. It utilizes batch processing for all UEs simultaneously to
% significantly improve runtime efficiency. It performs vectorized 
% calculations and applies environmental constraints such as weather 
% attenuation and traffic interference.
%
% Properties:
%   config      - Simulation configuration struct
%   areas       - Area definitions
%   bs_manager  - Base station manager
%   ue_manager  - User equipment manager

    properties
        config          
        areas           
        bs_manager      
        ue_manager      
        
        % Statistics
        total_reports_generated
        total_quadriga_calls
        total_quadriga_failures
        weather_stats
        
        % Cache
        last_weather_check_time
        cached_weather_condition
    end
    
    methods
        
        function obj = CSIReporter(config, areas, bs_manager, ue_manager)
            % CSIREPORTER Constructor
            %
            % Input:
            %   config     - simulation configuration
            %   areas      - struct array of Voronoi areas
            %   bs_manager - BaseStationManager instance
            %   ue_manager - UserEquipmentManager instance
            
            obj.config = config;
            obj.areas = areas;
            obj.bs_manager = bs_manager;
            obj.ue_manager = ue_manager;
            
            obj.total_reports_generated = 0;
            obj.total_quadriga_calls = 0;
            obj.total_quadriga_failures = 0;
            
            % Initialize weather stats
            obj.weather_stats = struct();
            obj.weather_stats.clear = 0;
            obj.weather_stats.light_rain = 0;
            obj.weather_stats.heavy_rain = 0;
            
            obj.last_weather_check_time = -inf;
            obj.cached_weather_condition = 'clear';
            
            fprintf('[CSIReporter] Initialized with batch processing mode.\n');
            fprintf('  Weather effects: %s\n', string(config.weather.enabled));
            fprintf('  Traffic interference: %s\n', string(config.traffic.enabled));
        end
        
        
        function all_csi_data = generate_all_csi_reports(obj, timestamp)
            % GENERATE_ALL_CSI_REPORTS Batch process all UEs to generate CSI
            %
            % Input:
            %   timestamp - current simulation time (datetime or seconds)
            %
            % Output:
            %   all_csi_data - [num_ues x 6] matrix containing:
            %                  [rsrp, rsrq, sinr, cqi, bs_id, distance]
            
            num_ues = obj.ue_manager.num_ues;
            
            % Pre-allocate output
            all_csi_data = zeros(num_ues, 6);
            
            % Get current weather (cached)
            weather_condition = obj.get_weather_condition(timestamp);
            
            % Group UEs by area and BS to optimize QuaDRiGa calls
            [ue_groups, group_info] = obj.group_ues_by_area_and_bs();
            
            % Process each group with batch QuaDRiGa
            for g = 1:length(ue_groups)
                ue_ids = ue_groups{g};
                area_idx = group_info(g).area_idx;
                bs_id = group_info(g).bs_id;
                scenario = obj.areas(area_idx).scenario;
                
                % Run QuaDRiGa once for all UEs in this group
                batch_results = obj.run_quadriga_batch(ue_ids, bs_id, scenario);
                
                % Retrieve environmental load for the area
                area_load = TrafficUtils.get_area_load(...
                    obj.areas(area_idx).area_type, timestamp, obj.config);
                
                for i = 1:length(ue_ids)
                    ue_id = ue_ids(i);
                    
                    % Get channel data
                    channel_data = batch_results{i};
                    
                    % Apply environmental effects
                    channel_data = obj.apply_weather_effects(channel_data, weather_condition);
                    channel_data = obj.apply_traffic_effects(channel_data, area_load);
                    
                    % Calculate distance to base station
                    ue_pos = obj.ue_manager.get_position_3d(ue_id);
                    bs_pos = obj.bs_manager.get_position(bs_id);
                    distance = norm(ue_pos - bs_pos);
                    
                    % Store results
                    all_csi_data(ue_id, :) = [channel_data.rsrp, channel_data.rsrq, ...
                                               channel_data.sinr, channel_data.cqi, ...
                                               bs_id, distance];
                end
            end
            
            obj.total_reports_generated = obj.total_reports_generated + num_ues;
        end
        
        
        function [ue_groups, group_info] = group_ues_by_area_and_bs(obj)
            % GROUP_UES_BY_AREA_AND_BS Organize UEs for batch processing
            %
            % Returns groups of UEs that share the same area and serving BS.
            
            num_ues = obj.ue_manager.num_ues;
            
            % Find area and BS for each UE
            ue_areas = zeros(num_ues, 1);
            ue_bs = zeros(num_ues, 1);
            
            for ue_id = 1:num_ues
                ue_pos = obj.ue_manager.get_position(ue_id);
                ue_areas(ue_id) = GeometryUtils.find_area(ue_pos, obj.areas);
                ue_bs(ue_id) = obj.find_serving_bs(...
                    obj.ue_manager.get_position_3d(ue_id));
            end
            
            % Create unique groups based on area and BS combination
            [unique_combos, ~, group_ids] = unique([ue_areas, ue_bs], 'rows');
            
            num_groups = size(unique_combos, 1);
            ue_groups = cell(num_groups, 1);
            group_info = struct('area_idx', {}, 'bs_id', {});
            
            for g = 1:num_groups
                ue_groups{g} = find(group_ids == g);
                group_info(g).area_idx = unique_combos(g, 1);
                group_info(g).bs_id = unique_combos(g, 2);
            end
        end
        
        
        function batch_results = run_quadriga_batch(obj, ue_ids, bs_id, scenario)
            % RUN_QUADRIGA_BATCH Process multiple UEs in a single QuaDRiGa layout
            %
            % Creates a single layout with one transmitter and multiple receivers
            % to significantly reduce setup overhead.
            
            num_ues = length(ue_ids);
            batch_results = cell(num_ues, 1);
            
            obj.total_quadriga_calls = obj.total_quadriga_calls + 1;
            
            try
                % Get BS info
                bs_position = obj.bs_manager.get_position(bs_id);
                tx_array = obj.bs_manager.get_tx_array(bs_id);
                
                % Get all UE positions
                ue_positions = zeros(3, num_ues);
                rx_arrays = cell(num_ues, 1);
                
                for i = 1:num_ues
                    ue_positions(:, i) = obj.ue_manager.get_position_3d(ue_ids(i))';
                    rx_arrays{i} = obj.ue_manager.get_rx_array(ue_ids(i));
                end
                
                % Create single layout with all UEs
                layout = qd_layout;
                layout.set_scenario(scenario);
                
                % Setup transmitter
                layout.tx_position = bs_position';
                layout.tx_array = tx_array;
                
                % Setup multiple receivers
                layout.no_rx = num_ues;
                layout.rx_position = ue_positions;
                
                % Assign the same array config for all UEs
                layout.rx_array = rx_arrays{1};
                
                % Set frequency
                layout.simpar.center_frequency = obj.config.frequency;
                
                % Generate all channels sequentially in batch
                [~] = evalc('channels = layout.get_channels();');
                
                % Extract CSI for each UE
                for i = 1:num_ues
                    batch_results{i} = obj.extract_csi_from_channel(...
                        channels(i), bs_position, ue_positions(:, i)');
                end
                
            catch ME
                % If batch generation fails, fall back to individual approximation
                obj.total_quadriga_failures = obj.total_quadriga_failures + 1;
                
                if obj.total_quadriga_failures < 3
                    warning('QuaDRiGa:BatchFailed', '%s', ME.message);
                end
                
                % Fallback: compute default free-space CSI individually
                for i = 1:num_ues
                    ue_pos = obj.ue_manager.get_position_3d(ue_ids(i));
                    distance = norm(ue_pos - bs_position);
                    batch_results{i} = obj.get_default_csi(distance);
                end
            end
        end
        
        
        function serving_bs = find_serving_bs(obj, ue_position)
            num_bs = obj.bs_manager.num_bs;
            rsrp_estimates = zeros(num_bs, 1);
            freq_ghz = obj.config.frequency / 1e9;
    
            % Get UE area and scenario
            ue_pos_2d = ue_position(1:2);
            ue_area_idx = GeometryUtils.find_area(ue_pos_2d, obj.areas);
            ue_scenario = obj.areas(ue_area_idx).scenario;
    
            for bs_id = 1:num_bs
                bs_pos = obj.bs_manager.get_position(bs_id);
        
                % Calculate distance, avoiding log(0)
                distance = norm(ue_position - bs_pos);
                distance = max(distance, 1);
        
                % Free Space Path Loss (FSPL)
                fspl_db = 20*log10(distance) + 20*log10(freq_ghz) + 32.45;
        
                % Get BS area and scenario
                bs_pos_2d = bs_pos(1:2);
                bs_area_idx = GeometryUtils.find_area(bs_pos_2d, obj.areas);
                bs_scenario = obj.areas(bs_area_idx).scenario;
        
                % Determine propagation penalty based on endpoint scenarios
                if ue_area_idx == bs_area_idx
                % Same area: penalty is strictly based on the shared scenario
                    if contains(ue_scenario, 'NLOS')
                        path_penalty = 10;
                    else
                        path_penalty = 0;
                    end
                else
                    % Cross-area propagation: evaluate both endpoints
                    ue_is_nlos = contains(ue_scenario, 'NLOS');
                    bs_is_nlos = contains(bs_scenario, 'NLOS');
            
                    if ue_is_nlos && bs_is_nlos
                        path_penalty = 15;  % Both endpoints in NLOS (Worst case)
                    elseif ue_is_nlos || bs_is_nlos
                        path_penalty = 10;  % One endpoint in NLOS (Moderate case)
                    else
                        path_penalty = 5;   % Both LOS, but crossing boundary (Light penalty)
                    end
                end
        
                % Calculate final RSRP estimate
                rsrp_estimates(bs_id) = obj.config.bs.tx_power - fspl_db - path_penalty;
            end
    
            % Select the Base Station with the highest estimated RSRP
            [~, serving_bs] = max(rsrp_estimates);
        end
        
        
        function weather_condition = get_weather_condition(obj, timestamp)
            % GET_WEATHER_CONDITION Retrieve current weather state
            % Results are cached for 60 simulation seconds to reduce overhead.
            
            if isnumeric(timestamp)
                current_datetime = obj.config.simulation_datetime + seconds(timestamp);
                current_time = timestamp;
            else
                current_datetime = timestamp;
                current_time = seconds(timestamp - obj.config.simulation_datetime);
            end
            
            % Check cache (update every 60 seconds)
            if current_time - obj.last_weather_check_time > 60
                obj.cached_weather_condition = ...
                    WeatherUtils.get_weather_condition(current_datetime, obj.config);
                obj.last_weather_check_time = current_time;
                
                % Update statistics
                switch obj.cached_weather_condition
                    case 'clear'
                        obj.weather_stats.clear = obj.weather_stats.clear + 1;
                    case 'light_rain'
                        obj.weather_stats.light_rain = obj.weather_stats.light_rain + 1;
                    case 'heavy_rain'
                        obj.weather_stats.heavy_rain = obj.weather_stats.heavy_rain + 1;
                end
            end
            
            weather_condition = obj.cached_weather_condition;
        end
        
        
        function csi_metrics = extract_csi_from_channel(obj, channel, bs_position, ue_position)
            % EXTRACT_CSI_FROM_CHANNEL Process channel object into CSI metrics
            
            csi_metrics = struct();
            
            if length(channel) > 1
                channel = channel(1);
            end
            
            coeff = channel.coeff;
            
            % RSRP calculation
            if isfield(channel, 'par') && isfield(channel.par, 'pg_eff')
                path_gain_db = 10*log10(channel.par.pg_eff);
            else
                H_power = mean(abs(coeff(:)).^2);
                path_gain_db = 10*log10(H_power + 1e-20);
            end
            
            rsrp_dbm = obj.config.bs.tx_power + path_gain_db;
            rsrp_dbm = max(-120, min(-40, rsrp_dbm));
            
            % RSRQ calculation
            power_per_rx = squeeze(sum(abs(coeff).^2, [2, 3, 4]));
            
            if numel(power_per_rx) > 1 && any(power_per_rx > 0)
                power_std = std(power_per_rx);
                power_mean = mean(power_per_rx) + 1e-20;
                cv = power_std / power_mean;
                rsrq_db = -3 - 15 * cv;
            else
                rsrq_db = -10;
            end
            rsrq_db = max(-20, min(-3, rsrq_db));
            
            % SINR calculation
            thermal_noise_dbm = -174 + 10*log10(obj.config.bandwidth);
            noise_power_dbm = thermal_noise_dbm + obj.config.ue.noise_figure;
            
            sinr_db = rsrp_dbm - noise_power_dbm;
            
            num_taps = size(coeff, 3);
            if num_taps > 1
                sinr_db = sinr_db - (num_taps - 1) * 0.2;
            end
            
            sinr_db = max(-5, min(30, sinr_db));
            
            % CQI mapping
            cqi = obj.sinr_to_cqi(sinr_db);
            
            csi_metrics.rsrp = double(rsrp_dbm);
            csi_metrics.rsrq = double(rsrq_db);
            csi_metrics.sinr = double(sinr_db);
            csi_metrics.cqi = double(cqi);
        end
        
        
        function channel_data = apply_weather_effects(obj, channel_data, weather_condition)
            % APPLY_WEATHER_EFFECTS Apply attenuation based on weather
            
            if ~obj.config.weather.enabled
                return;
            end
            
            rain_atten_db = WeatherUtils.get_rain_attenuation_db(...
                weather_condition, obj.config);
            
            if rain_atten_db > 0
                channel_data.rsrp = channel_data.rsrp - rain_atten_db;
                channel_data.rsrq = channel_data.rsrq - rain_atten_db * 0.3;
                channel_data.sinr = channel_data.sinr - rain_atten_db;
                channel_data.cqi = obj.sinr_to_cqi(channel_data.sinr);
            end
        end
        
        
        function channel_data = apply_traffic_effects(obj, channel_data, area_load)
            % APPLY_TRAFFIC_EFFECTS Apply interference based on area load
            
            if ~obj.config.traffic.enabled
                return;
            end
            
            interference_db = TrafficUtils.calculate_interference_db(...
                area_load, obj.config.traffic.max_interference_db);
            
            if interference_db > 0
                sinr_linear = 10^(channel_data.sinr/10);
                interference_linear = 10^(interference_db/10);
                sinr_with_interference = sinr_linear / (1 + interference_linear);
                
                channel_data.sinr = 10*log10(sinr_with_interference);
                channel_data.rsrq = channel_data.rsrq - interference_db * 0.2;
                channel_data.cqi = obj.sinr_to_cqi(channel_data.sinr);
            end
        end
        
        
        function cqi = sinr_to_cqi(obj, sinr_db)
            % SINR_TO_CQI Maps SINR values to 3GPP standard CQI indices
            
            if sinr_db < -6.7
                cqi = 0;
            elseif sinr_db < -4.7
                cqi = 1;
            elseif sinr_db < -2.3
                cqi = 2;
            elseif sinr_db < 0.2
                cqi = 3;
            elseif sinr_db < 2.4
                cqi = 4;
            elseif sinr_db < 4.3
                cqi = 5;
            elseif sinr_db < 5.9
                cqi = 6;
            elseif sinr_db < 8.1
                cqi = 7;
            elseif sinr_db < 10.3
                cqi = 8;
            elseif sinr_db < 12.3
                cqi = 9;
            elseif sinr_db < 14.1
                cqi = 10;
            elseif sinr_db < 15.7
                cqi = 11;
            elseif sinr_db < 17.6
                cqi = 12;
            elseif sinr_db < 19.6
                cqi = 13;
            elseif sinr_db < 21.6
                cqi = 14;
            else
                cqi = 15;
            end
        end
        
        
        function csi_data = get_default_csi(obj, distance)
            % GET_DEFAULT_CSI Fallback calculation for free-space path loss
            
            freq_ghz = obj.config.frequency / 1e9;
            fspl_db = 20*log10(distance) + 20*log10(freq_ghz) + 32.45;
            
            rsrp = obj.config.bs.tx_power - fspl_db;
            rsrp = max(-120, min(-60, rsrp));
            
            rsrq = -10;
            
            thermal_noise = -174 + 10*log10(obj.config.bandwidth);
            noise_power = thermal_noise + obj.config.ue.noise_figure;
            sinr = rsrp - noise_power;
            sinr = max(-5, min(25, sinr));
            
            cqi = obj.sinr_to_cqi(sinr);
            
            csi_data = struct();
            csi_data.rsrp = double(rsrp);
            csi_data.rsrq = double(rsrq);
            csi_data.sinr = double(sinr);
            csi_data.cqi = double(cqi);
        end
        
        
        function print_statistics(obj)
            % PRINT_STATISTICS Display reporter performance summary
            
            fprintf('\n--- CSIReporter Statistics ---\n');
            fprintf('Total reports: %d\n', obj.total_reports_generated);
            fprintf('Reports per UE: %.1f\n', obj.total_reports_generated / obj.ue_manager.num_ues);
            fprintf('QuaDRiGa batch calls: %d\n', obj.total_quadriga_calls);
            fprintf('QuaDRiGa failures: %d (%.1f%%)\n', ...
                obj.total_quadriga_failures, ...
                100 * obj.total_quadriga_failures / max(1, obj.total_quadriga_calls));
            
            fprintf('\nWeather Statistics:\n');
            total_checks = obj.weather_stats.clear + obj.weather_stats.light_rain + obj.weather_stats.heavy_rain;
            if total_checks > 0
                fprintf('  Clear: %d (%.1f%%)\n', obj.weather_stats.clear, 100*obj.weather_stats.clear/total_checks);
                fprintf('  Light rain: %d (%.1f%%)\n', obj.weather_stats.light_rain, 100*obj.weather_stats.light_rain/total_checks);
                fprintf('  Heavy rain: %d (%.1f%%)\n', obj.weather_stats.heavy_rain, 100*obj.weather_stats.heavy_rain/total_checks);
            end
            fprintf('-------------------------------\n\n');
        end
        
    end
end