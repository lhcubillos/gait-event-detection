function [X, t_window, labels] = generate_features_hu(t, imu_accel, imu_gyro, sample_rate, euler, wl, stp)
    %GENERATE_FEATURES_HU Summary of this function goes here
    %   Detailed explanation goes here

    % Imu gyro comes in rads/s and imu_accel in g's

    arguments
        t
        imu_accel %has to come in m/s^2
        imu_gyro %rads/s
        sample_rate
        euler = []
        wl = 0.3 %window length in seconds
        stp = 0.01 %window step in seconds
    end

    %% Filter data
    fs = sample_rate; %Hz
    [b, a] = butter(6, 25 / (fs / 2));
    filt_accel = filter(b, a, imu_accel);
    filt_gyro = filter(b, a, imu_gyro);

    % Get orientation angle
    if isempty(euler)
        FUSE = imufilter('SampleRate', sample_rate);
        [orientation, ang_vel] = FUSE(imu_accel, imu_gyro);
        euler = quat2eul(orientation);
        or_angle = euler(:, 3);
    else
        or_angle = euler;
    end

    %% Separate data into windows
    window_length = round(wl * sample_rate);
    step = round(stp * sample_rate);
    num_windows = ceil((size(filt_accel, 1)-window_length+1) / step);
    data_accel = NaN(num_windows, window_length, 3);
    data_gyro = NaN(num_windows, window_length, 3);
    data_or_angle = NaN(num_windows, window_length);
    % Time at the end of each window
    t_window = t(1) + ((1:num_windows) - 1) .* stp + (wl - stp);

    curr_idx = 1;

    for i = 1:num_windows

        try
            data_accel(i, :, :) = filt_accel(curr_idx:curr_idx + window_length - 1, :);
            data_gyro(i, :, :) = filt_gyro(curr_idx:curr_idx + window_length - 1, :);
            data_or_angle(i, :) = or_angle(curr_idx:curr_idx + window_length - 1, :);
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
    X = all_features;
%     % Normalized features
%     X = (all_features - mean(all_features, 1)) ./ std(all_features, 0, 1);

end
