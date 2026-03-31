classdef GeometryUtils
% GEOMETRYUTILS - Geometric calculations for simulation
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static utility class provides essential geometric and spatial 
% operations required for the simulation environment.
%
% Features:
%   - Determining which Voronoi area a point belongs to
%   - Calculating Euclidean distances between objects (e.g., UE to BS)
%   - Enforcing spatial boundaries and boundary collision physics
%   - Providing data for transition zone detection

    methods (Static)
        
        function area_idx = find_area(point, areas)
            % FIND_AREA Find which area a point belongs to
            %
            % Determines the closest area seed to the given point,
            % effectively placing the point within that Voronoi region.
            %
            % Input:
            %   point - [x, y] coordinates
            %   areas - struct array with field 'seed'
            %
            % Output:
            %   area_idx - index of the closest area
            %
            % Example:
            %   area_idx = GeometryUtils.find_area([100, 50], areas);
            
            num_areas = length(areas);
            distances = zeros(num_areas, 1);
            
            % Calculate distance to each seed
            for i = 1:num_areas
                distances(i) = GeometryUtils.distance_to_seed(point, areas(i).seed);
            end
            
            % Return index of the closest seed
            [~, area_idx] = min(distances);
        end
        
        
        function dist = distance_to_seed(point, seed)
            % DISTANCE_TO_SEED Calculate Euclidean distance between point and seed
            %
            % Input:
            %   point - [x, y] coordinates
            %   seed  - [x, y] coordinates
            %
            % Output:
            %   dist - Euclidean distance
            
            dx = point(1) - seed(1);
            dy = point(2) - seed(2);
            dist = sqrt(dx^2 + dy^2);
        end
        
        
        function [area_indices, distances] = get_two_closest_areas(point, areas)
            % GET_TWO_CLOSEST_AREAS Find the two closest areas to a point
            %
            % Used primarily for transition zone detection to determine
            % if a user is nearing a boundary between two regions.
            %
            % Input:
            %   point - [x, y] coordinates
            %   areas - struct array with field 'seed'
            %
            % Output:
            %   area_indices - [idx1, idx2] indices of the two closest areas
            %   distances    - [dist1, dist2] distances to those areas
            
            num_areas = length(areas);
            distances_all = zeros(num_areas, 1);
            
            % Calculate all distances
            for i = 1:num_areas
                distances_all(i) = GeometryUtils.distance_to_seed(point, areas(i).seed);
            end
            
            % Sort and extract the two closest
            [sorted_dist, sorted_idx] = sort(distances_all);
            
            area_indices = sorted_idx(1:2);
            distances = sorted_dist(1:2);
        end
        
        
        function is_inside = check_if_in_bounds(point, bounds)
            % CHECK_IF_IN_BOUNDS Check if a point is within rectangular bounds
            %
            % Input:
            %   point  - [x, y] coordinates
            %   bounds - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   is_inside - boolean indicating if the point is strictly inside
            
            x = point(1);
            y = point(2);
            
            is_inside = (x >= bounds(1)) && (x <= bounds(2)) && ...
                        (y >= bounds(3)) && (y <= bounds(4));
        end
        
        
        function [positions_out, any_out_of_bounds] = enforce_bounds(positions, bounds)
            % ENFORCE_BOUNDS Clip positions to strictly stay within bounds
            %
            % Input:
            %   positions - [Nx2] matrix of [x, y] positions
            %   bounds    - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   positions_out     - [Nx2] matrix of clipped positions
            %   any_out_of_bounds - boolean, true if any position was altered
            
            positions_out = positions;
            
            % Clip x coordinates
            positions_out(:,1) = max(bounds(1), min(bounds(2), positions(:,1)));
            
            % Clip y coordinates
            positions_out(:,2) = max(bounds(3), min(bounds(4), positions(:,2)));
            
            % Check if any values were modified
            any_out_of_bounds = any(positions_out(:) ~= positions(:));
        end
        
        
        function distance = point_to_point_distance(point1, point2)
            % POINT_TO_POINT_DISTANCE Calculate distance between two points
            %
            % Input:
            %   point1 - [x, y] coordinates
            %   point2 - [x, y] coordinates
            %
            % Output:
            %   distance - Euclidean distance
            
            dx = point1(1) - point2(1);
            dy = point1(2) - point2(2);
            distance = sqrt(dx^2 + dy^2);
        end
        
        
        function distances = calculate_distances_matrix(positions1, positions2)
            % CALCULATE_DISTANCES_MATRIX Calculate pairwise distances
            %
            % Useful for calculating UE-to-BS distances in batch.
            %
            % Input:
            %   positions1 - [Nx2] matrix of coordinates
            %   positions2 - [Mx2] matrix of coordinates
            %
            % Output:
            %   distances - [NxM] matrix where distances(i,j) is the distance
            %               from positions1(i,:) to positions2(j,:)
            
            N = size(positions1, 1);
            M = size(positions2, 1);
            distances = zeros(N, M);
            
            for i = 1:N
                for j = 1:M
                    distances(i,j) = GeometryUtils.point_to_point_distance(...
                        positions1(i,:), positions2(j,:));
                end
            end
        end
        
        
        function angle = calculate_angle_between_points(point1, point2)
            % CALCULATE_ANGLE_BETWEEN_POINTS Calculate angle from point1 to point2
            %
            % Input:
            %   point1 - [x, y] starting coordinates
            %   point2 - [x, y] ending coordinates
            %
            % Output:
            %   angle - angle in degrees (0-360), where 0 = East, 90 = North
            
            dx = point2(1) - point1(1);
            dy = point2(2) - point1(2);
            
            angle = atan2d(dy, dx);
            
            % Convert to 0-360 range
            if angle < 0
                angle = angle + 360;
            end
        end
        
        
        function new_point = move_point(point, angle_deg, distance)
            % MOVE_POINT Translate a point by a distance in a given direction
            %
            % Input:
            %   point     - [x, y] starting coordinates
            %   angle_deg - direction in degrees (0 = East, 90 = North)
            %   distance  - translation magnitude
            %
            % Output:
            %   new_point - [x, y] resulting coordinates
            
            dx = distance * cosd(angle_deg);
            dy = distance * sind(angle_deg);
            
            new_point = point + [dx, dy];
        end
        
        
        function [new_position, new_velocity] = reflect_velocity_at_boundary(position, velocity, bounds)
            % REFLECT_VELOCITY_AT_BOUNDARY Reflect velocity vector at physical boundaries
            %
            % Implements perfect elastic collision physics with map boundaries.
            % Preserves kinetic energy (speed) while reversing the relevant 
            % directional component.
            %
            % Input:
            %   position - [x, y] current coordinates
            %   velocity - [vx, vy] current velocity vector [m/s]
            %   bounds   - [x_min, x_max, y_min, y_max]
            %
            % Output:
            %   new_position - [x, y] corrected coordinates (clipped to bounds)
            %   new_velocity - [vx, vy] reflected velocity vector
            %
            % Example:
            %   [pos, vel] = GeometryUtils.reflect_velocity_at_boundary(...
            %       [205, 100], [2, 1], [0, 200, 0, 200]);
            %   % Output: pos = [200, 100], vel = [-2, 1] (reflected from right wall)
            
            new_position = position;
            new_velocity = velocity;
            
            x_min = bounds(1);
            x_max = bounds(2);
            y_min = bounds(3);
            y_max = bounds(4);
            
            % Check X boundaries (Left/Right walls)
            if position(1) < x_min
                new_position(1) = x_min;
                new_velocity(1) = -velocity(1);  
            elseif position(1) > x_max
                new_position(1) = x_max;
                new_velocity(1) = -velocity(1);  
            end
            
            % Check Y boundaries (Top/Bottom walls)
            if position(2) < y_min
                new_position(2) = y_min;
                new_velocity(2) = -velocity(2);  
            elseif position(2) > y_max
                new_position(2) = y_max;
                new_velocity(2) = -velocity(2);  
            end
        end
        
    end
end