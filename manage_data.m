%% Data extraction
clear;
close all;

file_pattern = sprintf('%s/**/*_trials.mat', "../../Data/GeorgiaTechDataset/scripts/STRIDES");
allFileInfo = dir(file_pattern);
all_data = {};
for file_num = 1:numel(allFileInfo)
    file = allFileInfo(file_num);
    split_folder = split(char(file.folder), '\');
    subject = split_folder{end};
    split_name = split(file.name, "_");
    activity = char(split_name(1));
    trials = load(strcat(file.folder,"\\",file.name)).trials;
    all_data.(subject).(activity) = trials;
end
save('data/all_data.mat', 'all_data');
