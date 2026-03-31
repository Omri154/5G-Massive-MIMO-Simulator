classdef UserEquipmentManager < handle
% USEREQUIPMENTMANAGER - Manage user equipment with mobility and QuaDRiGa antenna arrays
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class handles the initialization, configuration, and management of
% the User Equipment (UEs) within the simulation. It creates the physical
% antenna arrays (e.g., 2x2 MIMO) and manages UE positions and velocities
% utilizing the RandomWalkModel.
%
% Properties:
%   num_ues    - Number of user equipment
%   positions  - [Nx2] matrix of [x, y] in meters (height is constant)
%   velocities - [Nx2] matrix of [vx, vy] in m/s
%   rx_arrays  - Cell array of qd_arrayant objects (one per UE)
%   config     - Configuration struct

    properties
        num_ues         
        positions       
        velocities      
        rx_arrays       
        config          
    end
    
    methods
        
        function obj = UserEquipmentManager(config)
            % USEREQUIPMENTMANAGER Constructor
            %
            % Input:
            %   config - simulation configuration struct
            %
            % Example:
            %   config = SimulationConfig();
            %   ue_manager = UserEquipmentManager(config);
            
            obj.config = config;
            obj.num_ues = config.ue.num;
            
            fprintf('[UserEquipmentManager] Initializing %d UEs...\n', obj.num_ues);
            
            % Initialize positions and velocities
            obj.initialize_mobility();
            
            % Create QuaDRiGa antenna arrays
            obj.create_antenna_arrays();
            
            fprintf('[UserEquipmentManager] Initialization complete\n');
            obj.print_summary();
        end
        
        
        function initialize_mobility(obj)
            % INITIALIZE_MOBILITY Initialize UE positions and velocities
            %
            % Uses RandomWalkModel to generate random initial positions
            % and velocities within configured bounds and speed ranges.
            
            % Initialize positions (random within bounds)
            obj.positions = RandomWalkModel.initialize_positions(...
                obj.num_ues, obj.config.area_bounds);
            
            % Initialize velocities (random speed and direction)
            obj.velocities = RandomWalkModel.initialize_velocities(...
                obj.num_ues, obj.config);
            
            fprintf('[UserEquipmentManager] Mobility initialized\n');
        end
        
        
        function create_antenna_arrays(obj)
            % CREATE_ANTENNA_ARRAYS Create QuaDRiGa antenna arrays for all UEs
            %
            % Creates 2x2 MIMO antenna arrays for standard UE configuration with:
            %   - Omni-directional pattern
            %   - 0.5 wavelength spacing
            %   - 2x2 grid layout (4 elements total)
            
            obj.rx_arrays = cell(obj.num_ues, 1);
            
            % Calculate element spacing
            wavelength = obj.config.wavelength;
            spacing = obj.config.ue.array_spacing * wavelength;  % typically 0.5 lambda
            
            % Get array dimensions
            num_rows = obj.config.ue.array_rows;  
            num_cols = obj.config.ue.array_cols;  
            num_elements = num_rows * num_cols;   
            
            for ue_id = 1:obj.num_ues
                % Create omni-directional antenna array
                rx_array = qd_arrayant('omni');
                
                % Set element positions for array (grid layout)
                element_pos = zeros(3, num_elements);
                
                idx = 1;
                for row = 1:num_rows
                    for col = 1:num_cols
                        % Center the array around origin
                        x_pos = (col - (num_cols+1)/2) * spacing;
                        y_pos = 0;  % All in same plane
                        z_pos = (row - (num_rows+1)/2) * spacing;
                        
                        element_pos(:, idx) = [x_pos; y_pos; z_pos];
                        idx = idx + 1;
                    end
                end
                
                % Set element positions
                rx_array.element_position = element_pos;
                
                % Set coupling matrix (identity = no coupling)
                rx_array.coupling = eye(num_elements);
                
                % Store array
                obj.rx_arrays{ue_id} = rx_array;
            end
            
            fprintf('[UserEquipmentManager] Created %dx%d arrays for %d UEs\n', ...
                num_rows, num_cols, obj.num_ues);
        end
        
        
        function update_positions(obj, dt)
            % UPDATE_POSITIONS Update all UE positions based on velocities
            %
            % Input:
            %   dt - time step in seconds
            %
            % Moves UEs according to their velocities and handles
            % boundary collisions with elastic reflection.
            
            % Use RandomWalkModel.step for efficient batch update with boundary handling
            [obj.positions, obj.velocities] = RandomWalkModel.step(...
                obj.positions, obj.velocities, dt, obj.config.area_bounds);
        end
        
        
        function update_velocities(obj)
            % UPDATE_VELOCITIES Update all UE velocities
            %
            % Generates new random velocities for all UEs.
            % Typically called every config.mobility.update_interval seconds.
            
            obj.velocities = RandomWalkModel.update_velocities(...
                obj.velocities, obj.config);
        end
        
        
        function position = get_position(obj, ue_id)
            % GET_POSITION Get position of specific UE
            %
            % Input:
            %   ue_id - user equipment ID (1 to num_ues)
            %
            % Output:
            %   position - [x, y] in meters
            
            if ue_id < 1 || ue_id > obj.num_ues
                error('Invalid UE ID: %d (valid range: 1-%d)', ue_id, obj.num_ues);
            end
            
            position = obj.positions(ue_id, :);
        end
        
        
        function position_3d = get_position_3d(obj, ue_id)
            % GET_POSITION_3D Get 3D position of specific UE (includes height)
            %
            % Input:
            %   ue_id - user equipment ID (1 to num_ues)
            %
            % Output:
            %   position_3d - [x, y, height] in meters
            
            if ue_id < 1 || ue_id > obj.num_ues
                error('Invalid UE ID: %d (valid range: 1-%d)', ue_id, obj.num_ues);
            end
            
            position_2d = obj.positions(ue_id, :);
            height = obj.config.ue.height;
            position_3d = [position_2d, height];
        end
        
        
        function velocity = get_velocity(obj, ue_id)
            % GET_VELOCITY Get velocity of specific UE
            %
            % Input:
            %   ue_id - user equipment ID (1 to num_ues)
            %
            % Output:
            %   velocity - [vx, vy] in m/s
            
            if ue_id < 1 || ue_id > obj.num_ues
                error('Invalid UE ID: %d (valid range: 1-%d)', ue_id, obj.num_ues);
            end
            
            velocity = obj.velocities(ue_id, :);
        end
        
        
        function rx_array = get_rx_array(obj, ue_id)
            % GET_RX_ARRAY Get QuaDRiGa antenna array for specific UE
            %
            % Input:
            %   ue_id - user equipment ID (1 to num_ues)
            %
            % Output:
            %   rx_array - qd_arrayant object
            
            if ue_id < 1 || ue_id > obj.num_ues
                error('Invalid UE ID: %d (valid range: 1-%d)', ue_id, obj.num_ues);
            end
            
            rx_array = obj.rx_arrays{ue_id};
        end
        
        
        function all_positions = get_all_positions(obj)
            % GET_ALL_POSITIONS Get positions of all UEs
            %
            % Output:
            %   all_positions - [Nx2] matrix of [x, y]
            
            all_positions = obj.positions;
        end
        
        
        function all_positions_3d = get_all_positions_3d(obj)
            % GET_ALL_POSITIONS_3D Get 3D positions of all UEs
            %
            % Output:
            %   all_positions_3d - [Nx3] matrix of [x, y, height]
            
            height = obj.config.ue.height;
            all_positions_3d = [obj.positions, height * ones(obj.num_ues, 1)];
        end
        
        
        function all_velocities = get_all_velocities(obj)
            % GET_ALL_VELOCITIES Get velocities of all UEs
            %
            % Output:
            %   all_velocities - [Nx2] matrix of [vx, vy]
            
            all_velocities = obj.velocities;
        end
        
        
        function all_arrays = get_all_rx_arrays(obj)
            % GET_ALL_RX_ARRAYS Get all QuaDRiGa antenna arrays
            %
            % Output:
            %   all_arrays - cell array of qd_arrayant objects
            
            all_arrays = obj.rx_arrays;
        end
        
        
        function stats = get_mobility_statistics(obj)
            % GET_MOBILITY_STATISTICS Get current mobility statistics
            %
            % Output:
            %   stats - struct with mobility statistics
            
            stats = RandomWalkModel.get_mobility_statistics(...
                obj.positions, obj.velocities);
        end
        
        
        function print_summary(obj)
            % PRINT_SUMMARY Display summary of UE configuration
            
            fprintf('\n--- User Equipment Configuration ---\n');
            fprintf('Number of UEs: %d\n', obj.num_ues);
            fprintf('MIMO Configuration: %dx%d (Array: %dx%d)\n', ...
                obj.config.ue.num_tx, obj.config.ue.num_rx, ...
                obj.config.ue.array_rows, obj.config.ue.array_cols);
            fprintf('UE Height: %.1f m\n', obj.config.ue.height);
            fprintf('Tx Power: %.1f dBm\n', obj.config.ue.tx_power);
            fprintf('Noise Figure: %.1f dB\n', obj.config.ue.noise_figure);
            
            fprintf('\nMobility Configuration:\n');
            fprintf('  Speed range: %.1f - %.1f m/s\n', ...
                obj.config.mobility.speed_min, obj.config.mobility.speed_max);
            fprintf('  Velocity update interval: %.0f s\n', ...
                obj.config.mobility.update_interval);
            fprintf('  Position update timestep: %.1f s\n', ...
                obj.config.mobility.position_timestep);
            
            % Current statistics
            stats = obj.get_mobility_statistics();
            fprintf('\nCurrent Mobility Statistics:\n');
            fprintf('  Mean position: [%.1f, %.1f] m\n', stats.mean_position);
            fprintf('  Mean speed: %.2f m/s\n', stats.mean_speed);
            fprintf('  Max speed: %.2f m/s\n', stats.max_speed);
            fprintf('  Min speed: %.2f m/s\n', stats.min_speed);
            fprintf('-------------------------------------\n\n');
        end
        
        
        function validate(obj)
            % VALIDATE Check that all UEs are properly configured
            %
            % Throws error if configuration is invalid
            
            % Check positions within bounds
            for i = 1:obj.num_ues
                if ~GeometryUtils.check_if_in_bounds(obj.positions(i,:), ...
                        obj.config.area_bounds)
                    error('UE %d position [%.1f, %.1f] is out of bounds', ...
                        i, obj.positions(i,1), obj.positions(i,2));
                end
            end
            
            % Check antenna arrays
            for i = 1:obj.num_ues
                if isempty(obj.rx_arrays{i})
                    error('UE %d has no antenna array', i);
                end
                
                % Check number of elements
                num_elements = size(obj.rx_arrays{i}.element_position, 2);
                expected = obj.config.ue.num_rx;
                if num_elements ~= expected
                    error('UE %d has %d elements, expected %d', ...
                        i, num_elements, expected);
                end
            end
            
            fprintf('[UserEquipmentManager] Validation passed\n');
        end
        
    end
end