% close all;
subject = "AB08";
activity = "treadmill";
trial_num = 1;

% Window length
wl = 0.3;
% Step
stp = 0.01;
%% Algorithm
SWING = 1;
STANCE = 2;
% Given a variable trial that contains a struct having everything
trial = all_data.(subject).(activity){trial_num};
t = trial.imu.Header;
gt_hs_r = table2array(trial.gcRight(:, {'HeelStrike'}));
gt_hs_l = table2array(trial.gcLeft(:, {'HeelStrike'}));
gt_to_r = table2array(trial.gcRight(:, {'ToeOff'}));
gt_to_l = table2array(trial.gcRight(:, {'ToeOff'}));
imu_accel = table2array(trial.imu(:, {'thigh_Accel_X', 'thigh_Accel_Y', 'thigh_Accel_Z'}));
imu_gyro = table2array(trial.imu(:, {'thigh_Gyro_X', 'thigh_Gyro_Y', 'thigh_Gyro_Z'}));

%% Clean data
% TODO: Remove the data until the first heel strike, and remove also the last
% heel strike
if activity == "levelground"
    [~, heel_strikes] = findpeaks(gt_hs_r);
end

%% Filter data
fs = 200; %Hz
[b, a] = butter(6, 25 / (fs / 2));
filt_accel = filter(b, a, imu_accel);
filt_gyro = filter(b, a, imu_gyro);

figure
plot(t, imu_accel);
hold on;
plot(t, filt_accel);
title("Acceleration");
legend(["Original X", "Original Y", "Original Z", "Filt X", "Filt Y", "Filt Z"])
yyaxis right;
plot(t, gt_hs_r);
figure
plot(t, imu_gyro);
hold on;
plot(t, filt_gyro);
title("Gyro");
legend(["Original X", "Original Y", "Original Z", "Filt X", "Filt Y", "Filt Z"])
yyaxis right;
plot(t, gt_hs_r);

% Get orientation angle
FUSE = imufilter('SampleRate', 200);
[orientation, ang_vel] = FUSE(imu_accel * 9.81, deg2rad(imu_gyro));
euler = quat2eul(orientation);
or_angle = euler(:, 3);

%% Get labels in proper format
[~, r_heel_strikes] = findpeaks(gt_hs_r);
[~, r_toe_off] = findpeaks(gt_to_r);
[~, l_heel_strikes] = findpeaks(gt_hs_l);
[~, l_toe_off] = findpeaks(gt_to_l);

figure
plot(t, gt_hs_r);
hold on;
title("Gait events");
scatter(t(r_heel_strikes), gt_hs_r(r_heel_strikes));
scatter(t(r_toe_off), gt_hs_r(r_toe_off));
legend(["Phase (from hs)", "Heel strikes", "Toe offs"])

l_phase_cat = get_phase_cat(l_heel_strikes, l_toe_off, length(gt_hs_l));
r_phase_cat = get_phase_cat(r_heel_strikes, r_toe_off, length(gt_hs_r));

figure
plot(t, l_phase_cat)
hold on;
plot(t, r_phase_cat);
legend(["Left", "Right"]);

figure
plot(r_phase_cat);
hold on;
plot(gt_hs_r / 50);
plot(gt_to_r / 100);
legend(["Labels HS", "Actual HS phase", "Actual TO phase"]);
yticks([1 2])
yticklabels(["SWING", "STANCE"])

%% Separate data into windows
sample_rate = 200;
window_length = round(wl * sample_rate);
step = round(stp * sample_rate);
num_windows = ceil(size(filt_accel, 1) / step);
data_accel = NaN(num_windows, window_length, 3);
data_gyro = NaN(num_windows, window_length, 3);
data_or_angle = NaN(num_windows, window_length);
data_labels_l = NaN(num_windows, window_length);
data_labels_r = NaN(num_windows, window_length);
% TODO: I need to calculate the orientation angle as well.
curr_idx = 1;

for i = 1:num_windows

    try
        data_accel(i, :, :) = filt_accel(curr_idx:curr_idx + window_length - 1, :);
        data_gyro(i, :, :) = filt_gyro(curr_idx:curr_idx + window_length - 1, :);
        data_or_angle(i, :) = or_angle(curr_idx:curr_idx + window_length - 1, :);
        data_labels_l(i, :) = l_phase_cat(curr_idx:curr_idx + window_length - 1);
        data_labels_r(i, :) = r_phase_cat(curr_idx:curr_idx + window_length - 1);
    catch ME

        if ME.identifier == 'MATLAB:badsubscript'
            break;
        end

        rethrow(ME);
    end

    curr_idx = curr_idx + step;
end

% Remove all rows that start with NaN (only at the end)
data_accel = data_accel(~isnan(data_accel(:, 1, 1)), :, :);
data_gyro = data_gyro(~isnan(data_gyro(:, 1, 1)), :, :);
data_or_angle = data_or_angle(~isnan(data_or_angle(:, 1, 1)), :, :);
data_labels_l = data_labels_l(~isnan(data_labels_l(:, 1, 1)), :);
data_labels_r = data_labels_r(~isnan(data_labels_r(:, 1, 1)), :);

%% Generate features
% Accel
mean_accel = squeeze(mean(data_accel, 2));
std_accel = squeeze(std(data_accel, 0, 2));
max_accel = squeeze(max(data_accel, [], 2));
min_accel = squeeze(min(data_accel, [], 2));
first_accel = squeeze(data_accel(:, 1, :));
last_accel = squeeze(data_accel(:, end, :));
% accel: mean XYZ, std XYZ, maximum XYZ, minimum XYZ, first XYZ, last XYZ
accel_features = [mean_accel std_accel max_accel min_accel first_accel last_accel];

% Gyro
mean_gyro = squeeze(mean(data_gyro, 2));
std_gyro = squeeze(std(data_gyro, 0, 2));
max_gyro = squeeze(max(data_gyro, [], 2));
min_gyro = squeeze(min(data_gyro, [], 2));
first_gyro = squeeze(data_gyro(:, 1, :));
last_gyro = squeeze(data_gyro(:, end, :));
% gyro: mean XYZ, std XYZ, maximum XYZ, minimum XYZ, first XYZ, last XYZ
gyro_features = [mean_gyro std_gyro max_gyro min_gyro first_gyro last_gyro];

% Orientation angle
mean_or_angle = squeeze(mean(data_or_angle, 2));
std_or_angle = squeeze(std(data_or_angle, 0, 2));
max_or_angle = squeeze(max(data_or_angle, [], 2));
min_or_angle = squeeze(min(data_or_angle, [], 2));
first_or_angle = squeeze(data_or_angle(:, 1, :));
last_or_angle = squeeze(data_or_angle(:, end, :));
or_angle_features = [mean_or_angle std_or_angle max_or_angle min_or_angle first_or_angle last_or_angle];

all_features = [accel_features gyro_features or_angle_features];
% Normalized features
X = (all_features - mean(all_features, 1)) ./ std(all_features, 0, 1);
% Labels: we use the label at the end
% labels = mode(data_labels_r,2);
labels = data_labels_r(:, end);
% Remove all windows for which the label is 0
windows_unknown = labels == 0;
idxs_not_cut = find(windows_unknown == false);
num_cut_windows = idxs_not_cut(1) - 1;
X = X(labels ~= 0, :);
labels = labels(labels ~= 0);
num_windows = length(labels);

% Save data
% save("data/to_train/"+lower(subject) + "_" + activity + "_" + num2str(trial_num) + ".mat", "X");
% save("data/to_train/labels_"+lower(subject) + "_" + activity + "_" + num2str(trial_num) + ".mat", "labels");
% close all;

%% PCA
% [~,X_pca,~,~,explained,~] = pca(X);
% num_components = 25;
% X_pca = X_pca(:,1:num_components);
% sum_explained = cumsum(explained);
% var_explained = sum_explained(num_components)

%% Classifier
load models / trainedLogReg3subjects.mat
% No PCA
% Ground truth heel strikes
gt_heel_strike_window_idx = [];

for i = 2:length(labels)

    if labels(i - 1) == SWING && labels(i) == STANCE
        gt_heel_strike_window_idx = [gt_heel_strike_window_idx; i];
    end

end

num_moving_avg = 3;
t_window = t(1) + num_cut_windows * stp + ((1:num_windows) - 1) .* stp + (wl - stp);
min_time_betw_hs = 0.3;
% Simulate actual data streaming in
predictions = [];
heel_strike_pred_idxs = [];
heel_strike_pred_t = [];

for i = 1:length(X)
    t_now = t_window(i);
    % In the real environment, I would have to wait for the full window to
    % come in, and then compute the necessary features
    data_point = X(i, :);
    tic
    pred = trainedModel.predictFcn(data_point);
    toc
    % If I don't have enough predictions, I won't be able to find heel
    % strike.
    % If I have enough predictions to do a moving average
    if length(predictions) >= num_moving_avg
        pred = mean([predictions(end - (num_moving_avg - 2):end); pred]);
    end

    predictions = [predictions; pred];

    if length(predictions) < 2
        continue;
    end

    last_pred = round(predictions(end - 1));
    pred = round(pred);

    if last_pred == SWING && pred == STANCE
        % Check that the last heel strike happened more than 300ms ago
        if length(heel_strike_pred_t) >= 1
            last_t_hs = heel_strike_pred_t(end);

            if t_now - last_t_hs >= min_time_betw_hs
                heel_strike_pred_idxs = [heel_strike_pred_idxs; i];
                heel_strike_pred_t = [heel_strike_pred_t; t_now];
            end

        else
            heel_strike_pred_idxs = [heel_strike_pred_idxs; i];
            heel_strike_pred_t = [heel_strike_pred_t; t_now];
        end

    end

end

predictions = round(predictions);
conf_mat = confusionmat(labels, predictions)

figure
plot(t_window, labels);
ylim([0.5 2.5])
yticks([1 2])
yticklabels(["SWING", "STANCE"])
yyaxis right;
plot(t, gt_hs_r);
ylim([-50 150])
legend(["Labels", "Ground truth"])

figure
plot(labels);
hold on;
plot(predictions);
ylim([0.5 2.5])
yticks([1 2])
yticklabels(["SWING", "STANCE"])
legend(["Original", "Predicted"])

figure
plot(t, gt_hs_r);
hold on;
arrayfun(@(a)xline(a), t_window(heel_strike_pred_idxs));
legend(["Ground truth", "Predicted"])
title("Heel strike predictions");

%% Evaluation
% Measure number of ground truth heel strikes, and the ones found by the
% algorithm
fprintf("GT heel strikes: %d, Found heel strikes: %d\n", length(gt_heel_strike_window_idx), length(heel_strike_pred_idxs));
% For each ground truth heel strike, find the closest found heel strike
% TODO: this does not recognize whether the prediction comes before or
% after.
[~, dist] = dsearchn(heel_strike_pred_idxs, gt_heel_strike_window_idx);
% Each dist value represents one step difference.
dist_t = dist * stp;
% If distance at one point is greater than 300ms, then that one was not
% recognized correctly.
num_not_recognized = sum(dist_t > 0.3);
fprintf("GT heel strikes not recognized: %d\n", num_not_recognized);
dist_t(dist_t > 0.3) = NaN;
avg_dist = mean(dist_t, 'omitnan')
std_dist = std(dist_t, 'omitnan')
% PCA
% predicted = classify(X_pca, X_pca, labels);
% figure
% plot(labels);
% hold on;
% plot(predicted);
% ylim([0.5 2.5])
% % TODO: maybe do some filtering on the prediction, something I could do
% % online
%
% %% Actual heel strike prediction
% heel_strike_window_idx = [];
% for i=2:length(predicted)
%     if predicted(i-1) == SWING && predicted(i) == STANCE
%         heel_strike_window_idx = [heel_strike_window_idx;i];
%     end
% end
% gt_heel_strike_window_idx = [];
% for i=2:length(labels)
%     if labels(i-1) == SWING && labels(i) == STANCE
%         gt_heel_strike_window_idx = [gt_heel_strike_window_idx;i];
%     end
% end
% figure
% plot(t, gt_hs_r);
% hold on;
% arrayfun(@(a)xline(a),t_window(gt_heel_strike_window_idx));
%
% figure
% plot(labels);
% hold on;
% plot(predicted);
% ylim([0.5 2.5])
% legend(["Original","Predicted"])
% scatter(heel_strike_window_idx, ones(length(heel_strike_window_idx),1))
%
% figure
% plot(windows_unknown)
% title("Windows unknown");
%
% % % Transform from window idx to actual time
% % % Will assume heel strike happened at the end of the window
% % heel_strike_pred = (num_cut_windows + heel_strike_window_idx - 1) .* step + window_length;
% % gt_heel_strike_pred = (num_cut_windows + gt_heel_strike_window_idx - 1) .* step + window_length;
% % Filter those heel strike that happen before 300ms have passed
% min_distance_betw_hs = 0.3 * fs;
% heel_strike_pred = heel_strike_pred([true; diff(heel_strike_pred) > min_distance_betw_hs]);
%
% figure
% plot(t, gt_hs_r);
% hold on;
% arrayfun(@(a)xline(a),t(heel_strike_pred));
% legend(["Ground truth", "Predicted"])
%
% %% Evaluation
% % Will calculate average distance to closest heel strike
% [~,dist] = dsearchn(r_heel_strikes, heel_strike_pred);
% [~,gt_dist] = dsearchn(r_heel_strikes, gt_heel_strike_pred);
% avg_diff_time = mean(dist) / 200
% std_diff_time = std(dist) / 200
% gt_avg_diff_time = mean(gt_dist) / 200
% gt_std_diff_time = std(gt_dist) / 200
% % Confusion matrix on the prediction as well
% conf_mat = confusionmat(labels, predicted)
%% Functions
function phase_cat = get_phase_cat(heel_strike, toe_off, num_elements)
    SWING = 1;
    STANCE = 2;
    phase_cat = zeros(num_elements, 1);

    for i = 1:length(heel_strike)
        hs_idx = heel_strike(i);
        % Get the previous toe off
        previous_toe_offs = toe_off(toe_off < hs_idx);

        if isempty(previous_toe_offs)
            continue
        end

        last_toe_off = previous_toe_offs(end);
        phase_cat(last_toe_off:hs_idx) = SWING;

        % Get future toe off
        future_toe_offs = toe_off(toe_off > hs_idx);

        if isempty(future_toe_offs)
            continue
        end

        next_toe_off = future_toe_offs(1);
        phase_cat(hs_idx:next_toe_off) = STANCE;
    end

end
