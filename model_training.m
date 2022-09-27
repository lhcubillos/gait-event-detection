clear;
close all;

subjects = ["LC042022", "SC042722", "TA050422", "YC050422", "YL050422"];
path_data = "../../Data/GaitEventDetection/NewDevice/";
offsets = [0 33 0 0 0];
max_num_trials = 2;
X = cell(length(subjects), max_num_trials);
% For future deep learning models
X_raw = cell(length(subjects), max_num_trials);
gt_labels = cell(length(subjects), max_num_trials);
gt_labels_raw = cell(length(subjects), max_num_trials);

for j = 1:length(subjects)
    subject = subjects(j);
    path_subj = path_data + subject;
    csv_files = dir(path_subj + "/*.csv");
    mat_files = dir(path_subj + "/*.mat");
    % Sort by filename
    [~, ind_csv] = sort({csv_files.name});
    csv_files = csv_files(ind_csv);
    [~, ind_mat] = sort({mat_files.name});
    mat_files = mat_files(ind_mat);

    num_trials = length(csv_files);
    subj_data = cell(num_trials, 1);

    for i = 1:num_trials
        % Features
        csv_table = readtable(csv_files(i).folder + "\" + csv_files(i).name);
        imu_accel = 9.8067 * [csv_table.accel_x csv_table.accel_y csv_table.accel_z];
        imu_gyro = deg2rad([csv_table.gyro_x csv_table.gyro_y csv_table.gyro_z]);
        euler = deg2rad(csv_table.euler_x);
        imu_sample_rate = 100;
        t_imu = csv_table.timestamp / 1000;
        [features, t_window] = generate_features_hu(t_imu, imu_accel, imu_gyro, imu_sample_rate, euler);
        X{j, i} = features;
        raw_features = [imu_accel imu_gyro euler];
        % Add history
        history = 9;
        % We remove some data points that don't have enough history
        num_features = size(raw_features, 2);
        new_size = num_features * (history + 1);
        raw_features_new = zeros(size(raw_features, 1) - history, new_size);

        for time_point = history + 1:size(raw_features, 1)
            hist_data = raw_features((time_point - history):time_point, :)';
            raw_features_new(time_point - history, :) = reshape(hist_data, [1, new_size]);
        end

        X_raw{j, i} = raw_features_new;

        % Labels
        qtm_struct = load(mat_files(i).folder + "\" + mat_files(i).name);
        fn = fieldnames(qtm_struct);
        qtm_struct = qtm_struct.(fn{1});
        r_force = qtm_struct.Force(1).Force;
        r_force = r_force - offsets(j);
        r_force = rmmissing(r_force')';
        frequency = qtm_struct.Force.Frequency;
        num_samples = qtm_struct.Force.NrOfSamples;
        t_force = (0:(length(r_force) - 1)) / frequency;

        [gt_hs_t, gt_to_t] = get_ground_truth_treadmill(t_force, r_force);
        labels = get_stance_swing_labels(t_window, gt_hs_t, gt_to_t);
        labels_raw = get_stance_swing_labels(t_imu, gt_hs_t, gt_to_t);
        gt_labels{j, i} = labels;
        gt_labels_raw{j, i} = labels_raw(history + 1:end);
        figure
        plot(t_force, r_force(3, :));
        hold on;
        yyaxis right;
        plot(t_window, labels);
        yticks([1 2 3])
        yticklabels(["SWING", "STANCE", "UNKNOWN"])
    end

end

%% Separate training and testing
% Use all subjects but one for training and then test on the other one
test_subject = randi([1 length(subjects)]);
X_test = X{test_subject, 1};
X_train = X;
X_train(test_subject, :) = [];
X_train = vertcat(X_train{:, 1});
labels_test = gt_labels{test_subject, 1};
labels_train = gt_labels;
labels_train(test_subject, :) = [];
labels_train = vertcat(labels_train{:, 1});

%% Evaluate model on testing data
predicted = trainedModel1.predictFcn(X_test);
figure
plotconfusion(categorical(labels_test), categorical(predicted));

%% Raw
test_subject = 3;
X_raw_test = X_raw{test_subject, 1};
X_raw_train = X_raw;
X_raw_train(test_subject, :) = [];
X_raw_train = vertcat(X_raw_train{:, 1});
labels_raw_test = gt_labels_raw{test_subject, 1};
labels_raw_train = gt_labels_raw;
labels_raw_train(test_subject, :) = [];
labels_raw_train = vertcat(labels_raw_train{:, 1});
%% Evaluate model on testing data
predicted = sub3_model.predictFcn(X_raw_test);
figure
plotconfusion(categorical(labels_raw_test), categorical(predicted));
