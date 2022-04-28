function [heel_strike_idxs, t_window] = detect_gait_events_hu(t, imu_accel, imu_gyro, sample_rate)
    %DETECT_GAIT_EVENTS Summary of this function goes here
    %   Detailed explanation goes here
    SWING = 1;
    STANCE = 2;

    [X, t_window] = generate_features_hu(t, imu_accel, imu_gyro, sample_rate);
    %% Classifier
    load models / trainedLogReg3subjects.mat trainedModel

    num_moving_avg = 3;
    min_time_betw_hs = 0.3;
    % Simulate actual data streaming in
    predictions = [];
    heel_strike_idxs = [];
    heel_strike_t = [];

    for i = 1:length(X)
        t_now = t_window(i);
        % In the real environment, I would have to wait for the full window to
        % come in, and then compute the necessary features
        data_point = X(i, :);
        pred = trainedModel.predictFcn(data_point);
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
            if length(heel_strike_t) >= 1
                last_t_hs = heel_strike_t(end);

                if t_now - last_t_hs >= min_time_betw_hs
                    heel_strike_idxs = [heel_strike_idxs; i];
                    heel_strike_t = [heel_strike_t; t_now];
                end

            else
                heel_strike_idxs = [heel_strike_idxs; i];
                heel_strike_t = [heel_strike_t; t_now];
            end

        end

    end

    predictions = round(predictions);
    % conf_mat = confusionmat(labels, predictions)

end
