% TestUtils.m
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% Test script for validating utility classes: GeometryUtils, 
% TrafficUtils, WeatherUtils, and ValidationUtils.

clear; clc; close all;

% Add paths
addpath('config', 'utils');

% Load configuration
fprintf('Loading configuration...\n');
config = SimulationConfig();

%% Test GeometryUtils
fprintf('\nTesting GeometryUtils...\n');

% Create dummy areas
areas(1).seed = [50, 50];
areas(2).seed = [150, 150];

point = [100, 100];
area_idx = GeometryUtils.find_area(point, areas);
fprintf('  Point [100,100] belongs to area %d\n', area_idx);

dist = GeometryUtils.distance_to_seed(point, areas(1).seed);
fprintf('  Distance to seed 1: %.2f meters\n', dist);

in_bounds = GeometryUtils.check_if_in_bounds(point, config.area_bounds);
fprintf('  Point in bounds: %d\n', in_bounds);

%% Test TrafficUtils
fprintf('\nTesting TrafficUtils...\n');

timestamp = datetime('2024-07-15 14:30:00');
load = TrafficUtils.get_area_load('shopping_center', timestamp, config);
fprintf('  Shopping center load at 14:30 weekday: %.2f\n', load);

time_period = TrafficUtils.get_time_period(14);
fprintf('  Hour 14 is: %s\n', time_period);

interference = TrafficUtils.calculate_interference_db(0.8, 20);
fprintf('  Interference at 80%% load: %.1f dB\n', interference);

%% Test WeatherUtils
fprintf('\nTesting WeatherUtils...\n');

weather = WeatherUtils.get_weather_condition(timestamp, config);
fprintf('  Weather in July: %s\n', weather);

attenuation = WeatherUtils.get_rain_attenuation_db(weather, config);
fprintf('  Rain attenuation: %.2f dB\n', attenuation);

season = WeatherUtils.get_season(7);
fprintf('  Month 7 is: %s\n', season);

%% Test ValidationUtils
fprintf('\nTesting ValidationUtils...\n');

ValidationUtils.validate_config(config);

positions = [100, 100; 150, 150];
try
    ValidationUtils.validate_positions(positions, config.area_bounds);
    fprintf('  Position validation passed\n');
catch
    fprintf('  Position validation failed\n');
end

fprintf('\nAll utils tests completed successfully.\n');