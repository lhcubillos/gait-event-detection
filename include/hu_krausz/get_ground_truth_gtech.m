function [gt_heel_strike_t, gt_toe_off_t, t] = get_ground_truth_gtech(trial)
    %GET_GROUND_TRUTH_GTECH Summary of this function goes here
    %   Detailed explanation goes here
    t = trial.imu.Header;
    gt_hs_r = table2array(trial.gcRight(:, {'HeelStrike'}));
    gt_to_r = table2array(trial.gcRight(:, {'ToeOff'}));

    [~, r_heel_strikes] = findpeaks(gt_hs_r);
    [~, r_toe_off] = findpeaks(gt_to_r);
    gt_heel_strike_t = t(r_heel_strikes);
    gt_toe_off_t = t(r_toe_off);
end
