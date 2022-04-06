clear;
close all;

load data/all_data.mat;

%% Load data
subject = "AB08";
activity = "treadmill";
trial_num = 4;

% Given a variable trial that contains a struct having everything
trial = all_data.(subject).(activity){trial_num};
t = trial.imu.Header;
gt_hs_r = table2array(trial.gcRight(:,{'HeelStrike'}));
gt_to_r = table2array(trial.gcRight(:,{'ToeOff'}));
imu_accel = table2array(trial.imu(:,{'thigh_Accel_X','thigh_Accel_Y','thigh_Accel_Z'}));
imu_gyro = table2array(trial.imu(:,{'thigh_Gyro_X','thigh_Gyro_Y','thigh_Gyro_Z'}));

%% Filter data
fs = 200; %Hz
[b,a] = butter(6, 25 / (fs/2));
filt_accel = filter(b,a, imu_accel);
filt_gyro = filter(b,a, imu_gyro);

figure
plot(t, imu_accel);
hold on;
plot(t, filt_accel);
title("Acceleration");
legend(["Original X","Original Y","Original Z","Filt X","Filt Y","Filt Z"])
yyaxis right;
plot(t, gt_hs_r);
figure
plot(t, imu_gyro);
hold on;
plot(t, filt_gyro);
title("Gyro");
legend(["Original X","Original Y","Original Z","Filt X","Filt Y","Filt Z"])
yyaxis right;
plot(t, gt_hs_r);

% Get orientation angle
FUSE = imufilter('SampleRate',200);
[orientation, ang_vel] = FUSE(imu_accel*9.81, deg2rad(imu_gyro));
euler = quat2eul(orientation);
or_angle = euler(:,3);

figure
plot(t, imu_gyro);
hold on;
plot(t, filt_gyro);
title("Gyro");
legend(["Original X","Original Y","Original Z","Filt X","Filt Y","Filt Z"])
yyaxis right;
plot(t, gt_hs_r);

