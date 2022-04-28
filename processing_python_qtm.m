% clear;
% close all;

path_mat = "../../Data/GaitEventDetection/NewDevice/measurement_2022_04_22__09_26_48.mat";
path_csv = "../../Data/GaitEventDetection/NewDevice/2022_04_22__09_26_48.csv";

qtm_struct = load(path_mat);
fn = fieldnames(qtm_struct);
qtm_struct = qtm_struct.(fn{1});
csv_table = readtable(path_csv);

%% 
l_force = qtm_struct.Force(2).Force;
r_force = qtm_struct.Force(1).Force;
l_force = rmmissing(l_force')';
r_force = rmmissing(r_force')';
frequency = qtm_struct.Force.Frequency;
num_samples = qtm_struct.Force.NrOfSamples;
t = (0:(length(r_force)-1))/frequency;
figure
plot(t, l_force(3,:));
hold on;
plot(t, r_force(3,:));
yyaxis right;
plot(csv_table.timestamp/1000, csv_table.gyro_x);
legend(["L","R","Gyro X"])

figure
plot(csv_table.timestamp/1000, [csv_table.accel_x csv_table.accel_y csv_table.accel_z])

%% Run algorithm
