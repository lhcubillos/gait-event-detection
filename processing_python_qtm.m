clear;
close all;

% path_mat = "../../Data/GaitEventDetection/NewDevice/LC042022/measurement_2022_04_22__09_26_48";
% path_csv = "../../Data/GaitEventDetection/NewDevice/LC042022/2022_04_22__09_26_48.csv";
% offset = 0;
path_mat = "../../Data/GaitEventDetection/NewDevice/SC042722/measurement_2022_04_27__15_02_12.mat";
path_csv = "../../Data/GaitEventDetection/NewDevice/SC042722/2022_04_27__15_02_12.csv";
offset = 33;

qtm_struct = load(path_mat);
fn = fieldnames(qtm_struct);
qtm_struct = qtm_struct.(fn{1});
csv_table = readtable(path_csv);

%%
l_force = qtm_struct.Force(2).Force;
r_force = qtm_struct.Force(1).Force;
% Remove offset if necessary
l_force = l_force - offset;
r_force = r_force - offset;
l_force = rmmissing(l_force')';
r_force = rmmissing(r_force')';
frequency = qtm_struct.Force.Frequency;
num_samples = qtm_struct.Force.NrOfSamples;
t_force = (0:(length(r_force) - 1)) / frequency;
figure
plot(t_force, l_force(3, :));
hold on;
plot(t_force, r_force(3, :));
yyaxis right;
plot(csv_table.timestamp / 1000, csv_table.gyro_x);
legend(["L", "R", "Gyro X"])

figure
plot(csv_table.timestamp / 1000, [csv_table.accel_x csv_table.accel_y csv_table.accel_z])

%% Run algorithm
% In m/s^2
imu_accel = 9.8067 * [csv_table.accel_x csv_table.accel_y csv_table.accel_z];
% In radians
imu_gyro = deg2rad([csv_table.gyro_x csv_table.gyro_y csv_table.gyro_z]);
euler = deg2rad(csv_table.euler_x);
t_imu = csv_table.timestamp / 1000;
imu_sample_rate = 100;
[gt_hs_t, gt_to_t] = get_ground_truth_treadmill(t_force, r_force);
[X, t_window] = generate_features_hu(t_imu, imu_accel, imu_gyro, imu_sample_rate, euler);
gt_labels = get_stance_swing_labels(t_window, gt_hs_t, gt_to_t);

%%
[heel_strike_idxs, predictions] = detect_gait_events_hu(t_window, X);

%% Evaluate algorithm
figure
confusionchart(confusionmat(gt_labels, predictions));
figure;
plot(t_force, r_force(3, :));
hold on;

for i = 1:length(heel_strike_idxs)
    xline(t_window(heel_strike_idxs(i)))
end

yyaxis right;
plot(t_window, gt_labels);

figure
plot(t_window, gt_labels);
hold on;
plot(t_window, predictions);
legend(["Original","Predicted"]);
yticks([1 2 3])
yticklabels(["SWING", "STANCE", "UNKNOWN"])
