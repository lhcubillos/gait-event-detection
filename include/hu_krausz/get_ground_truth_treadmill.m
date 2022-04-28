function [gt_heel_strike_t, gt_toe_off_t] = get_ground_truth_treadmill(t, force_plate_data)
    %GET_GROUND_TRUTH_HU Summary of this function goes here
    %   Detailed explanation goes here
    arguments
        t % real time of the force plate data
        force_plate_data % XYZ forces, with shape (3,N)
    end

    % Heel strike happens when the Z force of the force plate goes above
    % 20N. Toe off when the Z force goes back below 20.

    thres = 18;

    % Filter data to avoid false positives
    [b, a] = butter(2, 20 / (2000/2));
    filt_force = filtfilt(b, a, force_plate_data')';

    %% Heel strike
    % Threshold crossings
    vals_greater = filt_force(3, :) >= thres;
    % Set the first to zero just in case it was originally over the threshold
    vals_greater(1) = 0;
    % Find the corresponding indices
    idxs_greater = find(vals_greater);
    % Only keep those values where the previous one was lower than thres
    prev_was_lower = filt_force(3, idxs_greater - 1) < thres;
    gt_heel_strike_t = t(idxs_greater(prev_was_lower));

    %% Toe off
    % Threshold crossings
    vals_lower = filt_force(3, :) <= thres;
    % Set the first to zero just in case it was originally below the threshold
    vals_lower(1) = 0;
    % Find the corresponding indices
    idxs_lower = find(vals_lower);
    % Only keep those values where the previous one was lower than thres
    prev_was_higher = filt_force(3, idxs_lower - 1) > thres;
    gt_toe_off_t = t(idxs_lower(prev_was_higher));

end
