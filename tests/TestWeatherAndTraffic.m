% TestWeatherAndTraffic.m
%
% Test script to validate the dynamic effects of weather and traffic
% load on the simulation over different scenarios (e.g., Winter vs. Summer,
% Rush Hour vs. Night).

clear; clc; close all;

addpath('config', 'utils', 'environment', 'mobility', 'network', 'simulation');

fprintf('\n========================================\n');
fprintf('  Weather & Traffic Scenario Test\n');
fprintf('========================================\n\n');

%% Define scenarios to test
scenarios = {
    struct('name', 'July Afternoon (No Rain, Moderate Traffic)', ...
           'datetime', datetime('2024-07-15 14:30:00'), ...
           'expected_rain', 0, ...
           'expected_traffic_office', 0.9);
    
    struct('name', 'January Afternoon (Rain Likely, Moderate Traffic)', ...
           'datetime', datetime('2024-01-15 14:30:00'), ...
           'expected_rain', 0.4, ...  
           'expected_traffic_office', 0.9);
    
    struct('name', 'July Morning Rush (No Rain, High Highway Traffic)', ...
           'datetime', datetime('2024-07-15 08:30:00'), ...
           'expected_rain', 0, ...
           'expected_traffic_highway', 0.95);
    
    struct('name', 'January Night (Rain Possible, Low Traffic)', ...
           'datetime', datetime('2024-01-15 02:00:00'), ...
           'expected_rain', 0.4, ...
           'expected_traffic_office', 0.05);
};

%% Run test for each scenario
results = cell(length(scenarios), 1);

for s = 1:length(scenarios)
    fprintf('\n========================================\n');
    fprintf('=== Scenario %d: %s ===\n', s, scenarios{s}.name);
    fprintf('========================================\n');
    fprintf('Date/Time: %s\n', datestr(scenarios{s}.datetime));
    
    % Create config and set datetime before initialization
    config = SimulationConfig();
    config.simulation_datetime = scenarios{s}.datetime;
    config.timing.total_duration = 15000;  % Sufficiently long to bypass weather cache
    config.ue.num = 15;
    config.output.verbose = false;
    
    % Ensure different UE positions for each scenario
    config.random_seed_mobility = 12345 + s * 1000;
    
    % Initialize components
    fprintf('\nInitializing simulation components...\n');
    areas = AreaGenerator.generate(config);
    bs_manager = BaseStationManager(config);
    ue_manager = UserEquipmentManager(config);
    
    % Create CSI Reporter
    csi_reporter = CSIReporter(config, areas, bs_manager, ue_manager);
    
    fprintf('\nGenerating CSI reports...\n');
    all_sinr = [];
    all_rsrp = [];
    
    % Pass time values spanning several hours to bypass the 60s cache
    time_points = [0, 3600, 7200, 10800, 14400];  % Hourly jumps
    for i = 1:length(time_points)
        t = time_points(i);
        
        csi_data = csi_reporter.generate_all_csi_reports(t);
        
        all_sinr = [all_sinr; csi_data(:, 3)];
        all_rsrp = [all_rsrp; csi_data(:, 1)];
        
        fprintf('  t=%.0fs (+%d hr): Mean RSRP=%.2f dBm, Mean SINR=%.2f dB\n', ...
            t, t/3600, mean(csi_data(:, 1)), mean(csi_data(:, 3)));
    end
    
    % Get statistics
    fprintf('\n');
    csi_reporter.print_statistics();
    
    % Calculate expected traffic loads
    traffic_loads = struct();
    traffic_loads.office = TrafficUtils.get_area_load('office', scenarios{s}.datetime, config);
    traffic_loads.highway = TrafficUtils.get_area_load('highway', scenarios{s}.datetime, config);
    traffic_loads.residential = TrafficUtils.get_area_load('residential', scenarios{s}.datetime, config);
    traffic_loads.shopping = TrafficUtils.get_area_load('shopping_center', scenarios{s}.datetime, config);
    
    fprintf('Traffic Loads (at %s):\n', datestr(scenarios{s}.datetime));
    fprintf('  Office: %.2f\n', traffic_loads.office);
    fprintf('  Highway: %.2f\n', traffic_loads.highway);
    fprintf('  Residential: %.2f\n', traffic_loads.residential);
    fprintf('  Shopping: %.2f\n', traffic_loads.shopping);
    
    % Store results
    results{s} = struct();
    results{s}.scenario = scenarios{s}.name;
    results{s}.datetime = scenarios{s}.datetime;
    results{s}.mean_sinr = mean(all_sinr);
    results{s}.mean_rsrp = mean(all_rsrp);
    results{s}.std_sinr = std(all_sinr);
    results{s}.std_rsrp = std(all_rsrp);
    results{s}.weather_stats = csi_reporter.weather_stats;
    results{s}.traffic_loads = traffic_loads;
    
    fprintf('\nCSI Summary:\n');
    fprintf('  Mean RSRP: %.2f +/- %.2f dBm\n', results{s}.mean_rsrp, results{s}.std_rsrp);
    fprintf('  Mean SINR: %.2f +/- %.2f dB\n', results{s}.mean_sinr, results{s}.std_sinr);
    
    fprintf('\n========================================\n');
end

%% Compare Results
fprintf('\n========================================\n');
fprintf('  Comparison Summary\n');
fprintf('========================================\n\n');

fprintf('%-50s | SINR (dB) | RSRP (dBm) | Rain%% | Hwy Load\n', 'Scenario');
fprintf('%s\n', repmat('-', 100, 1));

for s = 1:length(results)
    total_weather = results{s}.weather_stats.clear + ...
                    results{s}.weather_stats.light_rain + ...
                    results{s}.weather_stats.heavy_rain;
    
    if total_weather > 0
        rain_pct = 100 * (results{s}.weather_stats.light_rain + ...
                          results{s}.weather_stats.heavy_rain) / total_weather;
    else
        rain_pct = 0;
    end
    
    fprintf('%-50s | %9.2f | %10.2f | %5.0f%% | %8.2f\n', ...
        results{s}.scenario(1:min(50, length(results{s}.scenario))), ...
        results{s}.mean_sinr, ...
        results{s}.mean_rsrp, ...
        rain_pct, ...
        results{s}.traffic_loads.highway);
end

fprintf('\n========================================\n');

%% Automated Analysis
fprintf('\nAnalysis:\n');
fprintf('----------------------------------------\n');

% 1. Check July Weather (Should be dry)
july_clear = true;
for s = 1:length(results)
    if contains(results{s}.scenario, 'July')
        total = results{s}.weather_stats.clear + ...
                results{s}.weather_stats.light_rain + ...
                results{s}.weather_stats.heavy_rain;
        if total > 0 && results{s}.weather_stats.clear < total
            july_clear = false;
        end
    end
end
if july_clear
    fprintf('PASS: July shows no rain (100%% clear)\n');
else
    fprintf('FAIL: July should have no rain.\n');
end

% 2. Check January Weather (Probabilistic Rain)
january_has_rain = false;
for s = 1:length(results)
    if contains(results{s}.scenario, 'January')
        if results{s}.weather_stats.light_rain > 0 || results{s}.weather_stats.heavy_rain > 0
            january_has_rain = true;
        end
    end
end
if january_has_rain
    fprintf('PASS: January correctly simulates rain events.\n');
else
    fprintf('WARNING: January should probabilistically have some rain.\n');
end

% 3. Check SINR Variation
sinr_values = cellfun(@(x) x.mean_sinr, results);
sinr_range = max(sinr_values) - min(sinr_values);
if sinr_range > 0.5
    fprintf('PASS: SINR values logically vary between scenarios (range: %.2f dB)\n', sinr_range);
else
    fprintf('FAIL: SINR variation is too low (range: %.2f dB).\n', sinr_range);
end

% 4. Check Traffic Loads (Rush Hour vs Night)
rush_hour_idx = find(contains(cellfun(@(x) x.scenario, results, 'UniformOutput', false), 'Rush'));
night_idx = find(contains(cellfun(@(x) x.scenario, results, 'UniformOutput', false), 'Night'));

if ~isempty(rush_hour_idx) && ~isempty(night_idx)
    rush_load = results{rush_hour_idx(1)}.traffic_loads.highway;
    night_load = results{night_idx(1)}.traffic_loads.highway;
    
    if rush_load > 0.9 && night_load < 0.3
        fprintf('PASS: Highway traffic accurately reflects time of day (Rush=%.2f, Night=%.2f)\n', rush_load, night_load);
    else
        fprintf('WARNING: Traffic logic failed. Rush=%.2f, Night=%.2f\n', rush_load, night_load);
    end
end
fprintf('----------------------------------------\n');

%% Visualization
figure('Name', 'Scenario Comparison', 'Position', [100, 100, 1400, 500]);

labels = {'Jul PM', 'Jan PM', 'Jul Rush', 'Jan Night'};

% Subplot 1: SINR Comparison
subplot(1, 3, 1);
bar(sinr_values);
set(gca, 'XTickLabel', labels);
ylabel('Mean SINR [dB]', 'FontWeight', 'bold');
title('Average Signal Quality (SINR)', 'FontWeight', 'bold');
grid on;

% Subplot 2: Weather Distribution
subplot(1, 3, 2);
weather_data = zeros(length(results), 3);
for s = 1:length(results)
    total = results{s}.weather_stats.clear + ...
            results{s}.weather_stats.light_rain + ...
            results{s}.weather_stats.heavy_rain;
    if total > 0
        weather_data(s, 1) = 100 * results{s}.weather_stats.clear / total;
        weather_data(s, 2) = 100 * results{s}.weather_stats.light_rain / total;
        weather_data(s, 3) = 100 * results{s}.weather_stats.heavy_rain / total;
    end
end
bar(weather_data, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('Percentage [%]', 'FontWeight', 'bold');
title('Weather Distribution', 'FontWeight', 'bold');
legend({'Clear', 'Light Rain', 'Heavy Rain'}, 'Location', 'best');
grid on;

% Subplot 3: Traffic Loads
subplot(1, 3, 3);
traffic_data = zeros(length(results), 4);
for s = 1:length(results)
    traffic_data(s, 1) = results{s}.traffic_loads.office;
    traffic_data(s, 2) = results{s}.traffic_loads.highway;
    traffic_data(s, 3) = results{s}.traffic_loads.residential;
    traffic_data(s, 4) = results{s}.traffic_loads.shopping;
end
bar(traffic_data);
set(gca, 'XTickLabel', labels);
ylabel('Load Factor (0-1)', 'FontWeight', 'bold');
title('Traffic Loads by Area Type', 'FontWeight', 'bold');
legend({'Office', 'Highway', 'Residential', 'Shopping'}, 'Location', 'best');
grid on;
ylim([0, 1.1]);

fprintf('\nTest completed successfully. Visual comparisons generated.\n\n');