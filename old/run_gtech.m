clear;
close all;
load data/all_data

%%
subject = "AB08";
activity = "treadmill";
trial_num = 1;
trial = all_data.(subject).(activity){trial_num};

imu_accel = 9.8067 * table2array(trial.imu(:, {'thigh_Accel_X', 'thigh_Accel_Y', 'thigh_Accel_Z'}));
imu_gyro = table2array(trial.imu(:, {'thigh_Gyro_X', 'thigh_Gyro_Y', 'thigh_Gyro_Z'}));

t = trial.imu.Header;
[gt_hs_t, gt_to_t] = get_ground_truth_gtech(trial);
[X, t_window] = generate_features_hu(t, imu_accel, imu_gyro, 200);
heel_strike_idxs = detect_gait_events_hu(t_window, X);

%% Evaluate algorithm
figure;
plot(t, table2array(trial.gcRight(:, {'HeelStrike'})));
hold on;

for i = 1:length(heel_strike_idxs)
    xline(t_window(heel_strike_idxs(i)))
end
