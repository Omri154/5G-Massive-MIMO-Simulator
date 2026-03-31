classdef TrafficUtils
% TRAFFICUTILS - Traffic load calculations
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static utility class handles the dynamic calculation of network 
% traffic load based on the area type (e.g., residential, office), the day 
% of the week, and the time of day. It converts these load factors into 
% quantifiable RF interference (dB) to be applied to the CSI metrics.
%
% Note: The weekend definition aligns with the Israeli workweek (Friday 
% and Saturday are considered weekend days).
%
% Static methods for:
%   - Calculating network load by area type and time
%   - Converting load factors to interference levels
%   - Time period and day type classification

    methods (Static)
        
        function load_factor = get_area_load(area_type, timestamp, config)
            % GET_AREA_LOAD Calculate network load for a given area and time
            %
            % Input:
            %   area_type - string (e.g., 'shopping_center', 'residential')
            %   timestamp - datetime object representing the current simulation time
            %   config    - simulation configuration struct
            %
            % Output:
            %   load_factor - scalar representing network load (range 0 to 1)
            %
            % Example:
            %   load = TrafficUtils.get_area_load('shopping_center', ...
            %                                      datetime('2024-07-15 14:00'), config);
            
            % Check if traffic simulation is enabled in config
            if ~config.traffic.enabled
                load_factor = 0;
                return;
            end
            
            % Extract time information
            day_of_week = weekday(timestamp);  % 1=Sunday, 7=Saturday
            hour_of_sim = hour(timestamp);
            
            % Determine day type
            if TrafficUtils.is_weekend(day_of_week)
                day_type = 'weekend';
            else
                day_type = 'weekday';
            end
            
            % Determine time period
            time_period = TrafficUtils.get_time_period(hour_of_sim);
            
            % Retrieve load factor from config profiles
            try
                load_factor = config.traffic.profiles.(area_type).(day_type).(time_period);
            catch
                % If area_type is missing from profiles, fallback to a default low load
                warning('Area type "%s" not found in traffic profiles. Using default load 0.2', area_type);
                load_factor = 0.2;
            end
        end
        
        
        function time_period = get_time_period(hour)
            % GET_TIME_PERIOD Categorize an hour of the day into a discrete period
            %
            % Input:
            %   hour - integer representing the hour of day (0-23)
            %
            % Output:
            %   time_period - string label for the period
            %
            % Time periods mapping:
            %   night:   00:00 - 05:59
            %   morning: 06:00 - 09:59
            %   midday:  10:00 - 16:59
            %   evening: 17:00 - 21:59
            %   late:    22:00 - 23:59
            
            if hour >= 0 && hour < 6
                time_period = 'night';
            elseif hour >= 6 && hour < 10
                time_period = 'morning';
            elseif hour >= 10 && hour < 17
                time_period = 'midday';
            elseif hour >= 17 && hour < 22
                time_period = 'evening';
            else  % hour >= 22 && hour < 24
                time_period = 'late';
            end
        end
        
        
        function is_wknd = is_weekend(day_of_week)
            % IS_WEEKEND Determine if a given day index represents the weekend
            %
            % Note: In MATLAB's weekday() function, 1=Sunday, 7=Saturday.
            % This function considers Friday (6) and Saturday (7) as the weekend.
            %
            % Input:
            %   day_of_week - integer representing the day (1-7)
            %
            % Output:
            %   is_wknd - boolean
            
            is_wknd = (day_of_week == 6) || (day_of_week == 7);
        end
        
        
        function interference_db = calculate_interference_db(load_factor, max_interference_db)
            % CALCULATE_INTERFERENCE_DB Convert a load factor to interference in dB
            %
            % Calculates the interference linearly based on the load factor.
            % For example, if max_interference_db = 20:
            %   load=0   -> interference = 0 dB
            %   load=0.5 -> interference = 10 dB
            %   load=1   -> interference = 20 dB
            %
            % Input:
            %   load_factor         - network load (0 to 1)
            %   max_interference_db - maximum interference at 100% load [dB]
            %
            % Output:
            %   interference_db - calculated interference level [dB]
            
            interference_db = load_factor * max_interference_db;
        end
        
        
        function load_factors = get_load_for_all_areas(areas, timestamp, config)
            % GET_LOAD_FOR_ALL_AREAS Calculate load factors for all simulation areas
            %
            % Useful for batch processing or heatmap generation.
            %
            % Input:
            %   areas     - struct array containing the field 'area_type'
            %   timestamp - datetime object
            %   config    - simulation configuration struct
            %
            % Output:
            %   load_factors - [Nx1] column vector of load factors corresponding to areas
            
            num_areas = length(areas);
            load_factors = zeros(num_areas, 1);
            
            for i = 1:num_areas
                load_factors(i) = TrafficUtils.get_area_load(...
                    areas(i).area_type, timestamp, config);
            end
        end
        
        
        function day_type_str = get_day_type_string(timestamp)
            % GET_DAY_TYPE_STRING Get a human-readable string for the day type
            %
            % Input:
            %   timestamp - datetime object
            %
            % Output:
            %   day_type_str - string ('weekday' or 'weekend')
            
            day_of_week = weekday(timestamp);
            
            if TrafficUtils.is_weekend(day_of_week)
                day_type_str = 'weekend';
            else
                day_type_str = 'weekday';
            end
        end
        
    end
end