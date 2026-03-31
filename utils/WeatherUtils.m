classdef WeatherUtils
% WEATHERUTILS - Weather condition and rain attenuation calculations
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static utility class manages the simulation of environmental weather
% effects on the RF signal. It determines the weather state based on the
% simulation timestamp (using monthly probabilities) and calculates the 
% corresponding signal attenuation.
%
% Static methods for:
%   - Determining weather conditions based on a timestamp
%   - Calculating rain attenuation for signal propagation (ITU-R based)
%   - Validating weather logic (e.g., dry summers in the Mediterranean)

    methods (Static)
        
        function weather_condition = get_weather_condition(timestamp, config)
            % GET_WEATHER_CONDITION Determine weather condition for a given timestamp
            %
            % Uses a probabilistic model based on the month of the year.
            %
            % Input:
            %   timestamp - datetime object representing the simulation time
            %   config    - simulation configuration struct
            %
            % Output:
            %   weather_condition - string: 'clear', 'light_rain', 'heavy_rain'
            %
            % Example:
            %   weather = WeatherUtils.get_weather_condition(...
            %                datetime('2024-07-15 14:00'), config);
            
            % Check if weather effects are enabled
            if ~config.weather.enabled
                weather_condition = 'clear';
                return;
            end
            
            % Extract month (1-12)
            month_of_sim = month(timestamp);
            
            % Retrieve probabilities for this specific month
            % Format: [prob_clear, prob_light_rain, prob_heavy_rain]
            probs = config.weather.monthly_probabilities(month_of_sim, :);
            
            % Validate that probabilities sum to 1
            prob_sum = sum(probs);
            if abs(prob_sum - 1.0) > 0.01
                warning('Weather probabilities for month %d do not sum to 1 (sum=%.2f). Normalizing...', ...
                    month_of_sim, prob_sum);
                probs = probs / prob_sum;  
            end
            
            % Draw random condition
            rand_val = rand();
            
            if rand_val < probs(1)
                weather_condition = 'clear';
            elseif rand_val < (probs(1) + probs(2))
                weather_condition = 'light_rain';
            else
                weather_condition = 'heavy_rain';
            end
            
            % Logical validation: Ensure no rain in July/August (months 7-8)
            % typical for a Mediterranean climate
            if (month_of_sim == 7 || month_of_sim == 8) && ~strcmp(weather_condition, 'clear')
                weather_condition = 'clear';  
            end
        end
        
        
        function attenuation_db = get_rain_attenuation_db(weather_condition, config)
            % GET_RAIN_ATTENUATION_DB Get path loss attenuation due to rain
            %
            % Retrieves the predefined attenuation value for the given weather state.
            %
            % Input:
            %   weather_condition - string: 'clear', 'light_rain', 'heavy_rain'
            %   config            - simulation configuration struct
            %
            % Output:
            %   attenuation_db - additional path loss in dB
            
            switch weather_condition
                case 'clear'
                    attenuation_db = config.weather.rain_attenuation.clear;
                case 'light_rain'
                    attenuation_db = config.weather.rain_attenuation.light_rain;
                case 'heavy_rain'
                    attenuation_db = config.weather.rain_attenuation.heavy_rain;
                otherwise
                    warning('Unknown weather condition: %s. Using clear (0 dB).', weather_condition);
                    attenuation_db = 0;
            end
        end
        
        
        function is_possible = is_rain_possible_in_month(month)
            % IS_RAIN_POSSIBLE_IN_MONTH Check if rain is climatologically possible
            %
            % Tailored for a Mediterranean climate (e.g., Israel), where rain
            % is highly unlikely during the peak summer months.
            %
            % Input:
            %   month - integer (1-12)
            %
            % Output:
            %   is_possible - boolean (false for July and August, true otherwise)
            
            is_possible = ~(month == 7 || month == 8);
        end
        
        
        function attenuation_db = calculate_rain_attenuation_custom(rain_rate_mm_per_hr, ...
                                                                     frequency_ghz, ...
                                                                     path_length_km)
            % CALCULATE_RAIN_ATTENUATION_CUSTOM Calculate rain attenuation using ITU-R formula
            %
            % Computes attenuation based on the ITU-R P.838-3 recommendation.
            % This is a simplified version tailored for the 3-4 GHz range 
            % with horizontal polarization.
            %
            % Input:
            %   rain_rate_mm_per_hr - rain rate [mm/hr]
            %   frequency_ghz       - signal frequency [GHz]
            %   path_length_km      - propagation path length [km]
            %
            % Output:
            %   attenuation_db - calculated rain attenuation [dB]
            
            % ITU-R P.838 coefficients (approximations for ~3.5 GHz)
            k = 0.00045;
            alpha = 1.03;
            
            % Specific attenuation [dB/km]
            gamma = k * (rain_rate_mm_per_hr ^ alpha);
            
            % Total path attenuation
            attenuation_db = gamma * path_length_km;
        end
        
        
        function weather_str = get_weather_description(weather_condition)
            % GET_WEATHER_DESCRIPTION Get human-readable weather description
            %
            % Input:
            %   weather_condition - string: 'clear', 'light_rain', 'heavy_rain'
            %
            % Output:
            %   weather_str - descriptive string representing the condition
            
            switch weather_condition
                case 'clear'
                    weather_str = 'Clear/Sunny';
                case 'light_rain'
                    weather_str = 'Light Rain (2-10 mm/hr)';
                case 'heavy_rain'
                    weather_str = 'Heavy Rain (>20 mm/hr)';
                otherwise
                    weather_str = 'Unknown';
            end
        end
        
        
        function season = get_season(month)
            % GET_SEASON Get the season corresponding to a given month
            %
            % Categorizes months into standard Northern Hemisphere seasons.
            %
            % Input:
            %   month - integer (1-12)
            %
            % Output:
            %   season - string: 'winter', 'spring', 'summer', 'fall'
            
            if month >= 3 && month <= 5
                season = 'spring';
            elseif month >= 6 && month <= 8
                season = 'summer';
            elseif month >= 9 && month <= 11
                season = 'fall';
            else  % month == 12 || month == 1 || month == 2
                season = 'winter';
            end
        end
        
        
        function [weather_condition, attenuation_db] = get_weather_and_attenuation(timestamp, config)
            % GET_WEATHER_AND_ATTENUATION Retrieve both weather condition and attenuation
            %
            % Convenience function to get the current state and its RF impact in one call.
            %
            % Input:
            %   timestamp - datetime object
            %   config    - simulation configuration struct
            %
            % Output:
            %   weather_condition - string describing the weather
            %   attenuation_db    - calculated rain attenuation [dB]
            
            weather_condition = WeatherUtils.get_weather_condition(timestamp, config);
            attenuation_db = WeatherUtils.get_rain_attenuation_db(weather_condition, config);
        end
        
    end
end