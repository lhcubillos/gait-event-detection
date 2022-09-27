clear;
close all;

load data/all_data;

%%
subject = "AB08";
activity = "treadmill";
trial_num = 1;
trial = all_data.(subject).(activity){trial_num};
imu_accel = table2array(trial.imu(:,{'thigh_Accel_X','thigh_Accel_Y','thigh_Accel_Z'}));
imu_gyro = table2array(trial.imu(:,{'thigh_Gyro_X','thigh_Gyro_Y','thigh_Gyro_Z'}));

%% Figure
figure
plot(imu_gyro);