clear;
close all;

path_mat = "../../Data/GaitEventDetection/NewDevice/measurement_2022_04_22__09_18_09.mat";
path_csv = "../../Data/GaitEventDetection/NewDevice/2022_04_22__09_18_09.csv";

qtm_struct = load(path_mat);
fn = fieldnames(qtm_struct);
qtm_struct = qtm_struct.(fn{1});
csv_table = readtable(path_csv);

%% 
l_force = qtm_struct.Force(2).Force;
r_force = qtm_struct.Force(1).Force;
frequency = qtm_struct.Force.Frequency;
num_frames = qtm_struct.Force.NrOfSamples;
t = (0:(num_frames-1))/frequency;
t_csv
figure
plot(t, l_force(3,:));
hold on;
plot(t, r_force(3,:));
plot(csv_table.timestamp/1000000, csv_table.gyro_x);
legend(["L","R","Gyro X"])
