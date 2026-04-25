clear; clc;
addpath('config', 'mobility');
config = SimulationConfig();
mkdir('./data');

% Create a temporary model just to call generate_example_csv
% We need a dummy CSV first so the constructor doesn't crash
dummy_csv = './data/dummy.csv';
fid = fopen(dummy_csv, 'w');
fprintf(fid, 'ue_id,x,y,departure_time\n');
fprintf(fid, '1,50,50,2024-01-15 08:30:00\n');
fclose(fid);

m = TraceBasedModel(dummy_csv, config);
m.generate_example_csv('./data/ue_traces.csv');
delete(dummy_csv);
fprintf('Done — ready to run MainSimulation.\n');
