using Peaks, Statistics, DSP, StatsBase

function getPhaseGreene(t::Array{Float64,1}, imu_shank::Array{Float64,1}, ground_truth_hs::Array{Float64,1}, fs::Int64)

    # Filter imu data
    responsetype = Lowpass(5; fs = fs)
    designmethod = Butterworth(4)
    # Get shank gyro
    filtered_imu = filtfilt(digitalfilter(responsetype, designmethod), imu_shank)

    # Find peaks
    maxima_idx, maxima_vals = findmaxima(filtered_imu)
    minima_idx, minima_vals = findminima(filtered_imu)

    # Get mid-swing point
    mid_swing_idxs = Array{Int64,1}()
    mid_swing_vals = Array{Float64,1}()
    th1 = 0.6 * maximum(filtered_imu)
    th2 = 0.8 * mean(filtered_imu[filtered_imu.>mean(filtered_imu)])
    for (max_idx, max_value) in zip(maxima_idx, maxima_vals)
        minimums = filter(x -> x[1] < max_idx, collect(zip(minima_idx, minima_vals)))
        if length(minimums) == 0
            continue
        end
        last_min = minimums[end][2]
        # Check 1: last minimum should be at least th1 less than this maximum
        if max_value - th1 <= last_min
            continue
        end
        # Check 2: 
        if max_value < th2
            continue
        end
        push!(mid_swing_idxs, max_idx)
        push!(mid_swing_vals, max_value)
    end

    # IC points
    ic_idxs = Array{Int64,1}()
    ic_vals = Array{Float64,1}()
    # NOTE: this is using info from the future, wouldn't be possible online
    th3 = 0.8 * abs(mean(filtered_imu[filtered_imu.<mean(filtered_imu)]))
    th5 = mean(filtered_imu)
    for (min_idx, min_value) in zip(minima_idx, minima_vals)
        maximums = filter(x -> x[1] < min_idx, collect(zip(maxima_idx, maxima_vals)))
        if length(maximums) == 0
            continue
        end
        last_max = maximums[end][2]
        last_max_idx = maximums[end][1]
        # Check 1 and 2: last maximum was at least th3 greater than this minimum
        if min_value + th3 > last_max || min_value > th5
            continue
        end
        # New check: last point must be the midswing point
        if last_max_idx ∉ mid_swing_idxs
            continue
        end
        push!(ic_idxs, min_idx)
        push!(ic_vals, min_value)
    end

    # TC points
    tc_idxs = Array{Int64,1}()
    tc_vals = Array{Float64,1}()
    th4 = 0.8 * mean(filtered_imu[filtered_imu.<mean(filtered_imu)])
    th6 = 2 * th3
    for (min_idx, min_value) in zip(minima_idx, minima_vals)
        maximums = filter(x -> x[1] < min_idx, collect(zip(maxima_idx, maxima_vals)))
        if length(maximums) == 0
            continue
        end
        last_max = maximums[end][2]
        last_max_idx = maximums[end][1]
        # Check 1: last maximum was at least th3 greater than this minimum
        if min_value > th4
            continue
        end
        # Check2
        # if min_value + th6 > last_max
        # 	continue
        # end
        # New check: previous maxima can't be a mid-swing point
        if last_max_idx in mid_swing_idxs
            continue
        end
        push!(tc_idxs, min_idx)
        push!(tc_vals, min_value)
    end

    # Order ic (1) and tc (2) found points
    gait_events = cat(ones(Int8, length(ic_idxs)), 2 * ones(Int8, length(tc_idxs)), dims = 1)
    all_idxs = cat(ic_idxs, tc_idxs, dims = 1)
    unzip(a) = map(x -> getfield.(a, x), fieldnames(eltype(a)))
    all_idx, gait_events = unzip(sort(collect(zip(all_idxs, gait_events)), by = first))

    heel_strike_phase = zeros(length(ground_truth_hs))

    # Find mistakes
    mistakes = sum(diff(gait_events) .== 0)
    # println("Mistakes: $mistakes")
    # Remove all initial entries until we find an IC point
    initial_idx = findfirst(gait_events .== 1)
    if isnothing(initial_idx)
        printstyled("No heel contact was found\n", color = :red)
        return heel_strike_phase
    end
    gait_events = gait_events[initial_idx:end]
    all_idxs = all_idxs[initial_idx:end]

    # Get Phase
    for (i, ic_idx) in enumerate(ic_idxs)
        if i == 1
            continue
        end
        last_idx = ic_idxs[i-1]
        linspace_percent = collect(LinRange(0, 100, ic_idx - last_idx + 1))
        heel_strike_phase[last_idx:ic_idx] = linspace_percent
    end

    # Evaluation: how far from actual heel strike
    baseline = 50 * ones(length(ground_truth_hs))
    rmse = rmsd(ground_truth_hs, heel_strike_phase)
    rmse_baseline = rmsd(ground_truth_hs, baseline)
    # println("RMSE: $rmse, baseline: $rmse_baseline")
    # Average time between heel strike detections
    gt_hs_idxs, _ = findminima(ground_truth_hs)
    distances = zeros(length(ic_idxs))
    for ic_idx in ic_idxs
        # closest distance
        dist = abs(ic_idx - sort(gt_hs_idxs, by = x -> abs(ic_idx - x))[1])
        push!(distances, dist / fs)
    end
    avg_time_dist = mean(distances)
    # println("Average time distance: $avg_time_dist")


    return heel_strike_phase, mistakes, rmse, rmse_baseline, avg_time_dist
end

function getPhaseHuKrausz(t::Array{Float64,1}, imu_shank::Array{Float64,1}, ground_truth_hs::Array{Float64,1}, fs::Int64)
    # Uses all the data from IMU placed in thigh, separated in to small bins

end