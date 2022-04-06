using MAT
using FileIO

function process_mat(file_path)
    file = matread(file_path)
    trials = []
    for trial in file["trials"]
        trial_dict = Dict{String,Union{Matrix{Float64},Float64,String}}()
        for key in ["gcRight", "imu", "gcLeft"]
            trial_dict[key] = trial[key]
        end
        trial_dict["startTime"] = trial["conditions"]["trialStarts"]
        trial_dict["endTime"] = trial["conditions"]["trialEnds"]
        push!(trials, trial_dict)
    end


    return trials
end

data_dir = "G:\\My Drive\\UMich\\Data\\GeorgiaTechDataset\\scripts\\STRIDES"
data_dict = Dict{String,Dict{String,Array{Dict{String,Union{Matrix{Float64},Float64,String}}}}}()
for (root, subjects, files) in walkdir(data_dir)
    if !startswith(split(root, "\\")[end], "AB")
        continue
    end
    subject = split(root, "\\")[end]
    println("Processing $subject...")
    subject_dict = Dict{String,Array{Dict{String,Union{Matrix{Float64},Float64,String}}}}()
    for mat_file in files
        # Only get matlab files and the ones that end with trials
        if split(mat_file, ".")[end] != "mat" || !startswith(split(mat_file, "_")[end], "trials")
            continue
        end
        activity = split(mat_file, "_")[1]
        println("\t$activity")
        file_path = join([root, mat_file], "\\")
        subject_dict[activity] = process_mat(file_path)
    end
    data_dict[subject] = subject_dict
end
println(typeof(data_dict))
save("data/gt_data.jld2", "data", data_dict)
