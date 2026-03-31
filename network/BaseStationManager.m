classdef BaseStationManager < handle
% BASESTATIONMANAGER - Manage base stations with QuaDRiGa antenna arrays
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This class handles the initialization, configuration, and management of
% the base stations (BS) within the simulation. It creates the physical 
% antenna arrays (including Massive MIMO configurations) and manages their 
% positions and orientations (Azimuth and Downtilt).
%
% Properties:
%   num_bs     - Number of base stations
%   positions  - [Nx3] matrix of [x, y, height] in meters
%   tx_arrays  - Cell array of qd_arrayant objects (one per BS)
%   config     - Configuration struct

    properties
        num_bs          
        positions       
        tx_arrays       
        config          
    end
    
    methods
        
        function obj = BaseStationManager(config)
            % BASESTATIONMANAGER Constructor
            %
            % Input:
            %   config - simulation configuration struct
            %
            % Example:
            %   bs_manager = BaseStationManager(config);
            
            obj.config = config;
            obj.num_bs = config.bs.num;
            obj.positions = config.bs.positions;
            
            % Validate positions
            if size(obj.positions, 1) ~= obj.num_bs
                error('Number of BS positions (%d) does not match num_bs (%d)', ...
                    size(obj.positions, 1), obj.num_bs);
            end
            
            fprintf('[BaseStationManager] Initializing %d base stations...\n', obj.num_bs);
            
            % Create QuaDRiGa antenna arrays
            obj.create_antenna_arrays();
            
            fprintf('[BaseStationManager] Initialization complete\n');
            obj.print_summary();
        end
        
        
        function create_antenna_arrays(obj)
            % CREATE_ANTENNA_ARRAYS Create QuaDRiGa antenna arrays for all BSs
            %
            % Generates the physical antenna arrays based on the configuration.
            % Specifically designed to support Massive MIMO (e.g., 64 elements in an 
            % 8x8 grid) with:
            %   - 3GPP 3D radiation pattern
            %   - Cross-polarization
            %   - Configurable grid layout (rows x columns)
            %   - Appropriate element spacing (typically 0.5 lambda)
            %   - Mechanical tilt around y-axis (Downtilt)
            %   - Horizontal rotation around z-axis (Azimuth)
            
            obj.tx_arrays = cell(obj.num_bs, 1);
            
            for bs_id = 1:obj.num_bs
                % Create base antenna element with 3GPP 3D pattern
                tx_array = qd_arrayant('3gpp-3d');
                
                % Retrieve array dimensions from config
                num_rows = obj.config.bs.array_rows;      
                num_cols = obj.config.bs.array_cols;      
                num_elements = num_rows * num_cols;       
                
                % Calculate element positions
                % Standard spacing: 0.5 wavelength
                wavelength = obj.config.wavelength;
                spacing = 0.5 * wavelength;  % meters
                
                % Create 2D grid of antenna positions
                % Element positions are [3xN] matrix: [x; y; z] in meters
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
                tx_array.element_position = element_pos;
                
                % Set coupling matrix (identity = no coupling)
                tx_array.coupling = eye(num_elements);
                
                % Apply downtilt (mechanical tilt around y-axis)
                % Negative tilt points downward
                downtilt_deg = obj.config.bs.downtilt;  
                tx_array.rotate_pattern(downtilt_deg, 'y');  
                
                % Apply azimuth rotation (horizontal orientation)
                azimuth_deg = obj.config.bs.azimuth(bs_id);
                tx_array.rotate_pattern(azimuth_deg, 'z');  
                
                % Store array
                obj.tx_arrays{bs_id} = tx_array;
                
                fprintf('[BaseStationManager] Created %dx%d Massive MIMO array for BS %d (%d elements)\n', ...
                    num_rows, num_cols, bs_id, num_elements);
                fprintf('  Azimuth: %.0f deg, Downtilt: %.1f deg\n', azimuth_deg, downtilt_deg);
            end
        end
        
        
        function position = get_position(obj, bs_id)
            % GET_POSITION Get position of specific BS
            %
            % Input:
            %   bs_id - base station ID (1 to num_bs)
            %
            % Output:
            %   position - [x, y, height] in meters
            
            if bs_id < 1 || bs_id > obj.num_bs
                error('Invalid BS ID: %d (valid range: 1-%d)', bs_id, obj.num_bs);
            end
            
            position = obj.positions(bs_id, :);
        end
        
        
        function tx_array = get_tx_array(obj, bs_id)
            % GET_TX_ARRAY Get QuaDRiGa antenna array for specific BS
            %
            % Input:
            %   bs_id - base station ID (1 to num_bs)
            %
            % Output:
            %   tx_array - qd_arrayant object
            
            if bs_id < 1 || bs_id > obj.num_bs
                error('Invalid BS ID: %d (valid range: 1-%d)', bs_id, obj.num_bs);
            end
            
            tx_array = obj.tx_arrays{bs_id};
        end
        
        
        function all_positions = get_all_positions(obj)
            % GET_ALL_POSITIONS Get positions of all BSs
            %
            % Output:
            %   all_positions - [Nx3] matrix of [x, y, height]
            
            all_positions = obj.positions;
        end
        
        
        function all_arrays = get_all_tx_arrays(obj)
            % GET_ALL_TX_ARRAYS Get all QuaDRiGa antenna arrays
            %
            % Output:
            %   all_arrays - cell array of qd_arrayant objects
            
            all_arrays = obj.tx_arrays;
        end
        
        
        function print_summary(obj)
            % PRINT_SUMMARY Display summary of BS configuration
            
            fprintf('\n--- Base Station Configuration ---\n');
            fprintf('Number of BSs: %d\n', obj.num_bs);
            fprintf('MIMO Configuration: %dx%d (Array: %dx%d)\n', ...
                obj.config.bs.num_tx, obj.config.bs.num_rx, ...
                obj.config.bs.array_rows, obj.config.bs.array_cols);
            fprintf('Frequency: %.2f GHz\n', obj.config.frequency / 1e9);
            fprintf('Wavelength: %.4f m\n', obj.config.wavelength);
            fprintf('Tx Power: %.1f dBm\n', obj.config.bs.tx_power);
            fprintf('Downtilt: %.1f degrees\n', obj.config.bs.downtilt);
            
            fprintf('\nBS Positions & Orientations:\n');
            for i = 1:obj.num_bs
                fprintf('  BS %d: Position=[%.1f, %.1f, %.1f]m, Azimuth=%.0f deg\n', ...
                    i, obj.positions(i,1), obj.positions(i,2), obj.positions(i,3), ...
                    obj.config.bs.azimuth(i));
            end
            fprintf('----------------------------------\n\n');
        end
        
        
        function validate(obj)
            % VALIDATE Check that all BSs are properly configured
            %
            % Throws an error if the configuration is invalid (e.g., negative
            % height or missing elements).
            
            % Check positions
            if any(obj.positions(:,3) <= 0)
                error('BS height must be positive');
            end
            
            % Check antenna arrays
            for i = 1:obj.num_bs
                if isempty(obj.tx_arrays{i})
                    error('BS %d has no antenna array', i);
                end
                
                % Check number of elements
                num_elements = size(obj.tx_arrays{i}.element_position, 2);
                expected = obj.config.bs.num_tx;
                if num_elements ~= expected
                    error('BS %d has %d elements, expected %d', ...
                        i, num_elements, expected);
                end
            end
            
            fprintf('[BaseStationManager] Validation passed\n');
        end
        
    end
end