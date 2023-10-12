using CairoMakie
using DelimitedFiles
using Dates
using TimeSeries
using StatsBase
using PyCall
include(joinpath(dirname(@__FILE__), "variables.jl"))

skl = pyimport("sklearn.metrics")

CairoMakie.activate!(type = "svg")

#location = "CZ-Lnz"

idx = 1

measures = zeros(3, length(locations))

for (ids,location) in enumerate(locations)
    esn_results = Array(readdlm(path*"results/$location/20230308$location$idx.txt", ',', Float32)')
    ground_truth_full = readdlm(path*"data/$location/mean_ndvi_sg74$location.csv", Float32)
    ground_truth_train = ground_truth_full[1:5000]
    ground_truth_fullyear_train = ground_truth_full[1:5114]
    ground_truth_pred = ground_truth_full[5001:end]

    ta_gt_full = TimeArray(time_full, reduce(vcat, ground_truth_full))
    ta_mean_full, ta_std_full = get_yearlymeanstd(ta_gt_full)

    ta_gt_pred = TimeArray(time_pred, reduce(vcat, ground_truth_pred))
    ta_gt_fy_pred = TimeArray(start_date:Day(1):Date(2013,12,31), ground_truth_fullyear_train)
    ta_mean_pred, ta_std_pred = get_yearlymeanstd(
        ta_gt_fy_pred,
        years=2000:2013)

    ta_esn = TimeArray(time_pred, reduce(vcat, esn_results))

    measures[1,ids], measures[2,ids], measures[3,ids] = quantify_anomalies(ta_gt_pred, ta_esn, ta_mean_pred, ta_std_pred)
    
end
mean(measures, dims=2)