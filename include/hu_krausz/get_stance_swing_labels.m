function [labels] = get_stance_swing_labels(t_window, gt_hs_t, gt_to_t)
    %get_stance_swing_labels Summary of this function goes here
    %   Detailed explanation goes here
    SWING = 1;
    STANCE = 2;
    UNKNOWN = 3;

    num_windows = length(t_window);
    labels = ones(num_windows, 1) * UNKNOWN;

    % if there is more than X seconds between toe off and heel strike, call that UNKNOWN
    max_interval_to_hs = 1.5; %seconds

    iteration_label = STANCE;
    other_label = SWING;
    array_to_iterate = gt_hs_t;
    other_array = gt_to_t;

    if gt_hs_t(1) > gt_to_t(1)
        % Then we started with the swing phase
        iteration_label = SWING;
        other_label = STANCE;
        array_to_iterate = gt_to_t;
        other_array = gt_hs_t;
    end

    for i = 1:length(array_to_iterate)
        timing = array_to_iterate(i);
        % Find window idx closest to this timing
        [val, window_timing] = min(abs(t_window - timing));
        % Previous events
        previous_events = other_array(other_array < timing);
        % Future events
        future_events = other_array(other_array > timing);

        if val < 0.01
            labels(window_timing) = iteration_label;
        end

        if ~isempty(previous_events)
            last_timing = previous_events(end);
            % Find idx closest to this timing
            [val, window_last_timing] = min(abs(t_window - last_timing));
            fprintf('Closest distance in timing previous: %f\n', val);

            if val < 0.01
                labels(window_last_timing:window_timing - 1) = other_label;
            end

            % If this condition is met, there was a double belt problem
            if iteration_label == SWING && abs(last_timing - timing) >= max_interval_to_hs
                labels(window_last_timing:window_timing - 1) = UNKNOWN;
            end

        end

        % Future timing
        if ~isempty(future_events)
            next_timing = future_events(1);
            % Find idx closest to this timing
            [val, window_next_timing] = min(abs(t_window - next_timing));
            fprintf('Closest distance in timing future: %f\n', val);

            if val < 0.01
                labels(window_timing + 1:window_next_timing) = iteration_label;
            end

            % If this condition is met, there was a double belt problem
            if iteration_label == STANCE && abs(next_timing - timing) >= max_interval_to_hs
                labels(window_timing + 1:window_next_timing) = UNKNOWN;
            end

        end

    end

end
