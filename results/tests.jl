using Distributed
using Pkg
Pkg.activate(".")
@everywhere Pkg.activate(".")
using CairoMakie, DelimitedFiles, Dates, TimeSeries, StatsBase, ColorSchemes, JLD2
#@everywhere using CairoMakie, DelimitedFiles, Dates, TimeSeries, StatsBase, ColorSchemes, JLD2, Makie.Colors

include(joinpath(dirname(@__FILE__), "results_fun.jl"))
include(joinpath(dirname(@__FILE__), "plots_fun.jl"))
include(joinpath(dirname(@__FILE__), "variables.jl"))
include(joinpath(dirname(@__FILE__), "metrics.jl"))
include(joinpath(dirname(@__FILE__), "binary_events.jl"))
models = ["LSTM", "GRU", "RNN_TANH", "ESN"]
CairoMakie.activate!(type = "svg")

@everywhere include(joinpath(dirname(@__FILE__), "results_fun.jl"))
@everywhere include(joinpath(dirname(@__FILE__), "plots_fun.jl"))
@everywhere include(joinpath(dirname(@__FILE__), "variables.jl"))
@everywhere include(joinpath(dirname(@__FILE__), "metrics.jl"))



extremes4model("DE-Hai", "LSTM", 90, cut_season=true,
               only_negatives = true,
               season=["June" "July" "August"])
#location = "CZ-Lnz"
#hist_loc(location, "nrmse")
#hist_full(locations, "smape")


measures = [nrmse, smape, r2_score]

full_results = compute_all(
    locations, models, metrics, 100;
    save = true
)
#=
full_results_extremes = compute_all(
    locations, models, metrics, 100;
    filename = "full_results_extremes.jld2", 
    only_extremes = true,
    save=false
)
=#
growing_season_results = compute_all(
    locations, models, metrics, 100;
    filename = "growing_season_results.jld2",
    cut_season = true,
    season = ["May" "June" "July" "August" "September"],
    save=true
)

### TODO save summer extremes//modify how you get them
thresholds = 90:1:99
for threshold in thresholds
    compute_all(
        locations, models, metrics, 100;
        filename = "summer_extremes$threshold.jld2",
        cut_season = true,
        season = ["June" "July" "August"],
        only_extremes = true,
        save=true,
        threshold=threshold
    )
    println("end of threshold: ", threshold)
end

### TODO save summer extremes

thresholds = 90:1:99
full_season_extremes = zeros(length(90:1:99), length(models))
full_season_extremes_std = zeros(length(90:1:99), length(models))

for (tidx,threshold) in enumerate(thresholds)
    model_extrems = zeros(length(locations), length(models))
    for (lidx,location) in enumerate(locations)
        for (midx,model) in enumerate(models)
            res = read_results(location; filename="full_season_extremes$threshold.jld2")
            model_extrems[lidx,midx] = res.metrics_meanstd[model]["nrmse"][1]
        end
    end
    full_season_extremes[tidx,:] = mean(model_extrems, dims=1)
    full_season_extremes_std[tidx,:] = std(model_extrems, dims=1)
end

open("./stdfullnrmse.csv", "w") do io
    writedlm(io, full_season_extremes_std, ',')
end
open("./meanfullnrmse.csv", "w") do io
    writedlm(io, full_season_extremes, ',')
end



full_accuracy = zeros(length(locations), length(models))
#extremes_accuracy = zeros(length(locations), length(models))
growingseason_accuracy = zeros(length(locations), length(models))
#growingextremes_accuracy = zeros(length(locations), length(models))

for (lidx,location) in enumerate(locations)
    for (midx,model) in enumerate(models)
        full_accuracy[lidx, midx] = full_results[location].metrics_meanstd[model]["nrmse"][1]
        #extremes_accuracy[lidx, midx] = full_results_extremes[location].metrics_meanstd[model]["smape"][1]
        growingseason_accuracy[lidx, midx] = growing_season_results[location].metrics_meanstd[model]["nrmse"][1]
        #growingextremes_accuracy[lidx, midx] = growing_season_extremes[location].metrics_meanstd[model]["smape"][1]
    end
end

mfr = mean(full_accuracy, dims=1)
std(full_accuracy, dims=1)
#mfre = mean(extremes_accuracy, dims=1)
mgs = mean(growingseason_accuracy, dims=1)
std(growingseason_accuracy, dims=1)

#mgse = mean(growingextremes_accuracy, dims=1)

season = ["May" "June" "July" "August" "September"]
samples=50
plotname = "full_season"
cut_season = false
only_extremes = false
fullres_barplot(
    locations,
    measures;
    needles = ["nrmse", "smape", "r2_score"],
    needles2names = Dict(
        "r2_score" => L"R^2",
        "nrmse" => "NRMSE",
        "smape" => "SMAPE"),
    plot_type = "barplot",
    season = season,
    plot_title = plotname,
    file_name = plotname,
    cut_season=cut_season,
    only_extremes=only_extremes,
    yticklabelsize = 26,
    xticklabelsize = 26,
    xlabelsize = 32,
    ylabelsize = 32,
    titlesize = 38)


for location in locations, model in models
    for measure in measures
        println(location, " ", model, " ", model_mean_std(location, model, measure, samples))
    end
end
=#
model="LSTM"    
location = "DE-Hai"

gt_full, results = model_location_data(model, location)
gt_train, gt_pred = split_traintest(gt_full, length(time_train))

#for i in 1:samples

ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
    gt_full
)
ta_pred = data2ta(results[:,3], time_pred)

ta_mean_train, ta_std_train = get_yearlymeanstd(
    ta_gt_full, years=2002:2013
)
season=["June" "July" "August"]

ta_gt_train = get_season(ta_gt_train, season=season)
ta_mean_train = get_season(ta_mean_train, season=season)
ta_std_train = get_season(ta_std_train, season=season)
ta_gt_pred = get_season(ta_gt_pred, season=season)
ta_pred = get_season(ta_pred, season=season)

ta_anomalies = get_ta_anomalies(
    ta_gt_train, ta_mean_train, ta_std_train #ta_gt_train
)

sigma_pos, sigma_neg = get_sigma(
    ta_anomalies, 92
)

ta_anomalies_gt = get_ta_anomalies(
    ta_gt_pred, ta_mean_train, ta_std_train
)
ta_anomalies_esn = get_ta_anomalies(
    ta_pred, ta_mean_train, ta_std_train
)

Plots.scatter(ta_anomalies_esn, label = "anomalies esn")
Plots.scatter!(ta_anomalies_gt, label = "anomalies gt")
Plots.hline!([sigma_pos, sigma_neg], label="sigma")

Plots.scatter(ta_anomalies, label = "anomalies gt, training")
Plots.hline!([sigma_pos, sigma_neg], label="sigma")


ta_extremes_gt = get_ta_extremes(
    ta_gt_pred, ta_mean_train, ta_std_train; threshold=99
)

ta_extremes_esn = get_conditional_ta_extremes(
    ta_pred, ta_gt_pred, ta_mean_train, ta_std_train; threshold=99
)

be = binary_elements(ta_gt_pred, ta_extremes_gt, ta_extremes_esn)
bq = binary_quantifiers(
           be[1],
           be[2],
           be[3],
           be[4],
           length(ta_gt_pred)
)
 
compute_all_extremes(
    locations,
    models;
    filename = "extremes_growingseason.jld2",
    cut_season = true,
    season = ["May" "June" "July" "August" "September"]
)

ex1 = read_all_extremes(locations; filename = "extremes.jld2")
ex2 = read_all_extremes(locations; filename = "summer_extremes.jld2")

binary_quantifiers = [pod, pofd, pofa, pc, fscore]
for bq in binary_quantifiers
    extremes4modelslocations(
        locations,
        models,
        bq,
        90:1:99;
        cut_season=true,
        only_negatives = true,
        season=["June" "July" "August"],
        filename="summer"
    )

    extremes4modelslocations(
        locations,
        models,
        bq,
        90:1:99
    )
end





binary_quantifier = fscore
thresholds=90:1:99
samples=100
filename="summer"


for (midx,model) in enumerate(models)
    println(model)

    extremes_mean = zeros(length(thresholds), length(locations))
    extremes_std = zeros(length(thresholds), length(locations))

    for (lidx,location) in enumerate(locations)
        println(location)
        exs = range_extremes4model(
            location,
            model,
            thresholds,
            samples;
            binary_quantifier = binary_quantifier,
            cut_season=true,
            only_negatives = true,
        )

        extremes_mean[:,lidx], extremes_std[:,lidx] = exs[1], exs[2]
    end

    open("./mean$filename$binary_quantifier$model.csv", "w") do io
        writedlm(io, extremes_mean, ',')
    end
    open("./std$filename$binary_quantifier$model.csv", "w") do io
        writedlm(io, extremes_std, ',')
    end
    
end
