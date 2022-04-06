clear;
close all;

load data/all_data.mat;
subjects = fieldnames(all_data);
activities = fieldnames(all_data.(subjects{1}));
diff_time = [];
diff_time_std = [];
test_condition = {};
for i=1:length(subjects)
   subject = subjects{i};
   for j=1:length(activities)
      activity = activities{j};
      for k = 1:length(all_data.(subject).(activity))
         trial_num = k;
         fprintf("Processing %s, in activity %s, trial number %d\n",subject, activity, trial_num);
         test_condition{end+1,1} = {subject, activity, trial_num};
         run("HuKrausz.m");
         diff_time = [diff_time; avg_diff_time];
         diff_time_std = [diff_time_std; std_diff_time];
         close all
      end
   end
end

%% Visualize results
% load results/diff_time
% load results/diff_time_std
% load results/test_condition
activities = ["treadmill","levelground","stair","ramp"];
avg_time = zeros(4,1);
std_time = zeros(4,1);
for i=1:length(activities)
    idxs = cell2mat(arrayfun(@(row) strcmp(test_condition{row,1}{2}, activities(i)), 1:size(test_condition,1), 'UniformOutput', false))';
    avg_time(i) = mean(diff_time(idxs));
    std_time(i) = mean(diff_time_std(idxs));
end

figure
X = categorical(activities);
X = reordercats(X,activities);
bar(X,avg_time*1000)
hold on;
errorbar(X, avg_time*1000, std_time*1000, 'r.')
title("Heel strike prediction error");
ylabel("Avg error (ms)");
