classdef TransitionManager
% TRANSITIONMANAGER - Detect and manage transitions between areas
% Copyright (c) 2026 Omri Israeli. All rights reserved.
% Licensed under the MIT License.
%
% This static class is responsible for detecting when User Equipment (UEs) 
% enter transition zones (boundaries) between different Voronoi regions.
% It calculates a blend factor to enable smooth channel transitions rather 
% than abrupt jumps when a UE moves from one environmental scenario to another.
%
% Methods:
%   check_transition               - Detect if UE is in a transition zone
%   get_primary_area               - Get the closest area for a position
%   analyze_trajectory_transitions - Analyze transitions along a complete trajectory
%   validate_transition_zones      - Validate transition zone configuration

    methods (Static)
        
        function [in_transition, blend_factor, area_pair] = ...
                check_transition(position, areas, transition_width)
            % CHECK_TRANSITION Detect if UE is in transition zone between areas
            %
            % Input:
            %   position         - [x, y] UE position
            %   areas            - struct array of areas with 'seed' field
            %   transition_width - width of transition zone [meters]
            %
            % Output:
            %   in_transition - boolean, true if UE is in transition zone
            %   blend_factor  - blend factor (0-1), 0=area1, 1=area2
            %   area_pair     - [area1_idx, area2_idx] or [area_idx] if not transitioning
            %
            % Transition detection logic:
            %   - Find the two closest area seeds
            %   - If distance difference < transition_width, UE is in transition
            %   - Blend factor is calculated based on relative distances
            %
            % Example:
            %   [in_trans, blend, pair] = TransitionManager.check_transition(...
            %       [100, 50], areas, 10);
            
            % Find distances to all area seeds
            num_areas = length(areas);
            distances = zeros(num_areas, 1);
            
            for i = 1:num_areas
                distances(i) = GeometryUtils.distance_to_seed(position, areas(i).seed);
            end
            
            % Sort to get two closest areas
            [sorted_dist, sorted_idx] = sort(distances);
            
            closest_dist = sorted_dist(1);
            second_closest_dist = sorted_dist(2);
            
            % Check if in transition zone
            % UE is in transition if the difference between the two closest
            % distances is less than the transition width
            distance_diff = second_closest_dist - closest_dist;
            
            if distance_diff < transition_width
                % In transition zone
                in_transition = true;
                
                % Get the two areas involved in transition
                area_pair = sorted_idx(1:2);
                
                % Calculate blend factor (0 = fully in area1, 1 = fully in area2)
                % Linear interpolation based on relative distances
                total_dist = closest_dist + second_closest_dist;
                blend_factor = closest_dist / total_dist;
                
                % Clamp to [0, 1]
                blend_factor = max(0, min(1, blend_factor));
                
            else
                % Not in transition - firmly in one area
                in_transition = false;
                blend_factor = 0;  % Not used
                area_pair = sorted_idx(1);  % Only the closest area
            end
        end
        
        
        function area_idx = get_primary_area(position, areas)
            % GET_PRIMARY_AREA Get the primary (closest) area for a position
            %
            % Input:
            %   position - [x, y] UE position
            %   areas    - struct array of areas
            %
            % Output:
            %   area_idx - index of closest area
            %
            % This is a convenience function that returns the closest area
            % without transition detection.
            %
            % Example:
            %   area_idx = TransitionManager.get_primary_area([100, 50], areas);
            
            area_idx = GeometryUtils.find_area(position, areas);
        end
        
        
        function [transition_points, transition_info] = ...
                analyze_trajectory_transitions(trajectory, areas, transition_width)
            % ANALYZE_TRAJECTORY_TRANSITIONS Analyze transitions along a trajectory
            %
            % Input:
            %   trajectory       - [Nx2] matrix of positions along trajectory
            %   areas            - struct array of areas
            %   transition_width - transition zone width [meters]
            %
            % Output:
            %   transition_points - [Mx1] indices where transitions occur
            %   transition_info   - struct array with transition details
            %
            % Useful for post-processing analysis of UE movement behavior.
            %
            % Example:
            %   [trans_pts, info] = TransitionManager.analyze_trajectory_transitions(...
            %       ue_trajectory, areas, 10);
            
            num_points = size(trajectory, 1);
            transition_points = [];
            transition_info = struct([]);
            
            current_area = GeometryUtils.find_area(trajectory(1, :), areas);
            
            for i = 2:num_points
                [in_trans, blend, area_pair] = ...
                    TransitionManager.check_transition(...
                        trajectory(i, :), areas, transition_width);
                
                if in_trans
                    new_area = area_pair(2);  % Transitioning to this area
                    
                    if new_area ~= current_area
                        % Transition detected
                        transition_points = [transition_points; i];
                        
                        trans_info = struct();
                        trans_info.index = i;
                        trans_info.position = trajectory(i, :);
                        trans_info.from_area = current_area;
                        trans_info.to_area = new_area;
                        trans_info.blend_factor = blend;
                        
                        transition_info = [transition_info; trans_info];
                        
                        current_area = new_area;
                    end
                end
            end
        end
        
        
        function validate_transition_zones(areas, transition_width, bounds)
            % VALIDATE_TRANSITION_ZONES Validate transition zone configuration
            %
            % Input:
            %   areas            - struct array of areas
            %   transition_width - transition zone width [meters]
            %   bounds           - [x_min, x_max, y_min, y_max]
            %
            % Checks:
            %   - Transition width is reasonable relative to area sizes
            %   - No excessive overlap
            %
            % Example:
            %   TransitionManager.validate_transition_zones(areas, 10, [0,200,0,200]);
            
            num_areas = length(areas);
            
            % Calculate minimum distance between any two seeds
            min_seed_distance = inf;
            for i = 1:num_areas
                for j = i+1:num_areas
                    dist = GeometryUtils.distance_to_seed(...
                        areas(i).seed, areas(j).seed);
                    min_seed_distance = min(min_seed_distance, dist);
                end
            end
            
            fprintf('[TransitionManager] Validation:\n');
            fprintf('  Number of areas: %d\n', num_areas);
            fprintf('  Transition width: %.1f m\n', transition_width);
            fprintf('  Min seed distance: %.1f m\n', min_seed_distance);
            
            % Check if transition width is too large
            if transition_width > min_seed_distance / 2
                warning('Transition width (%.1f m) is large relative to minimum seed distance (%.1f m)', ...
                    transition_width, min_seed_distance);
            end
            
            % Check if transition width is reasonable
            area_size = (bounds(2) - bounds(1)) * (bounds(4) - bounds(3));
            avg_area_size = area_size / num_areas;
            avg_area_radius = sqrt(avg_area_size / pi);
            
            if transition_width > avg_area_radius / 2
                warning('Transition width (%.1f m) is large relative to average area size', ...
                    transition_width);
            end
            
            fprintf('  Validation passed\n');
        end
        
    end
end