struct FullResults{L,M,AM,MR,MMS}
    location::L
    models::M
    metrics::AM
    metrics_results::MR
    metrics_meanstd::MMS
end

struct ExtremeResults{L,M,T,B,S}
    location::L
    models::M
    thresholds::T
    binaries_mean::B
    binaries_std::S
end

function ExtremeResults(
    location,
    models,
    thresholds = 90:1:99,
    samples=100;
    extremes_function = extremes4model,
    kwargs...
)

    bin4mod_mean = Dict()
    bin4mod_std = Dict()
    for model in models
        println(model)
        bin_mean = zeros(length(thresholds), length(models))
        bin_std = zeros(length(thresholds), length(models))
        for (tidx,t) in enumerate(thresholds)
            println(t)
            bq = extremes_function(
                location, model, t, samples; kwargs...
            )
            bin_mean[tidx,1], bin_std[tidx,1] = bq["hit_rate"][1], bq["hit_rate"][2]
            bin_mean[tidx,2], bin_std[tidx,2] = bq["falsealarm_rate"][1], bq["falsealarm_rate"][2]
            bin_mean[tidx,3], bin_std[tidx,3] = bq["falsealarm_ratio"][1], bq["falsealarm_ratio"][2]
            bin_mean[tidx,4], bin_std[tidx,4] = bq["proportion_correct"][1], bq["proportion_correct"][2]
        end
        bin4mod_mean["$model"] = bin_mean
        bin4mod_std["$model"] = bin_std
    end

    ExtremeResults(location, models, thresholds, bin4mod_mean, bin4mod_std)
end

function FullResults(
    location,
    models=[
        "lstm",
        "gru",
        "rnntanh",
        "esn"
    ],
    metrics= [wape,
        mse,
        mae,
        coef_variation,
        marre,
        ope,
        rmsle,
        r2_score,
        mape,
        smape,
        nrmse],
    samples=100;
    kwargs...
)
    
    model_meanstds = Dict()
    model_raws = Dict()
    for model in models
        metrics_meanstd = Dict()
        metrics_raw = Dict()
        for metric in metrics
            metrics_meanstd["$metric"] = results4model(
                location, model, metric, samples; mean_std = true, kwargs...
            )
            metrics_raw["$metric"] = results4model(
                location, model, metric, samples; mean_std = false, kwargs...
            )
        end
        model_meanstds[model] = metrics_meanstd
        model_raws[model] = metrics_raw
    end

    FullResults(
        location, models, metrics, model_raws, model_meanstds
    )
end

function save_results(location, fr; filename = "full_results.jld2")
    path = "./"*location*"/"*filename
    jldsave(path; fr)
end

function read_results(location; filename = "full_results.jld2")
    path = "./"*location*"/"*filename
    jldopen(path)["fr"]
end

function compute_all(
    locations,
    models,
    metrics,
    samples = 100;
    save = true,
    filename = "full_results.jld2",
    kwargs...
)
    full_results = Dict()
    for location in locations
        println(location)
        fr = FullResults(
            location, models, metrics, samples; kwargs...
        )
        full_results[location] = fr
        if save
            save_results(
                location, fr; filename=filename
            )
        end
    end
    full_results
end

function compute_all_extremes(
    locations,
    models,
    thresholds=90:1:99,
    samples=100;
    save = true,
    filename = "summer_extremes.jld2",
    kwargs...
)

    extremes = Dict()
    for location in locations
        println(location)
        fr = ExtremeResults(
            location,
            models,
            thresholds,
            samples;
            kwargs...
        )
        extremes[location] = fr
        if save
            save_results(
                location, fr; filename = filename
            )
        end
    end
    extremes
end

function read_all_extremes(locations; filename = "extremes.jld2")
    extremes = Dict()
    for location in locations
        println(location)
        fr = read_results(location; filename=filename)
        extremes[location] = fr
    end

    extremes
end

"""
    model_mean_std(location,
        model,
        acc_measure,
        samples=50;
    )::Tuple

to test run:
```julia
test = model_mean_std("IT-Lav", "lstm", skl.mean_absolute_error)
```
"""
function results4model(location,
    model,
    acc_measure,
    samples=100;
    mean_std = true,
    cut_season = false,
    only_extremes = false,
    season = ["March" "April" "May" "June" "July" "August" "September" "October" "November"],
    time_pred = Date(2013,09,09):Day(1):Date(2020,12,31),
    threshold=90,
    binary_quantifier=fscore,
    negative_extremes = false, ######### TODO
    kwargs...
)

    ground_truth, prediction = model_location_data(model, location, samples)
    ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
        ground_truth; time_pred=time_pred, kwargs...
    )
    ta_prediction = data2ta(prediction, time_pred)

    if only_extremes
        ta_gt_mean, ta_gt_std = get_yearlymeanstd(ta_gt_full)
        ta_gt_pred = get_conditional_ta_extremes(
            ta_gt_pred,
            ta_gt_train,
            ta_gt_mean,
            ta_gt_std;
            threshold=threshold)
        ta_prediction = ta_prediction[timestamp(ta_gt_pred)]
    end

    if cut_season
        ta_gt_pred = get_season(ta_gt_pred, season=season)
        ta_prediction = get_season(ta_prediction, season=season)
    end
    
    if mean_std
        return mean_std_pred(
            values(ta_prediction), values(ta_gt_pred), acc_measure, samples
        )
    elseif mean_std==false
        return fullacc_pred(
            values(ta_prediction), values(ta_gt_pred), acc_measure, samples
        )
    end
end


function mean_std_pred(prediction,
    ground_truth,
    acc_measure,
    samples=100
)

    acc_array = fullacc_pred(prediction,
        ground_truth,
        acc_measure,
        samples
    )

    # get mean and std of prediciton accuracy
    return mean(acc_array), std(acc_array)
end

function fullacc_pred(prediction,
    ground_truth,
    acc_measure,
    samples=100
)

    # calc accuracy per run
    acc_array = zeros(samples)
    for i in eachindex(acc_array)
        acc_array[i] = acc_measure(ground_truth', prediction[:,i]')
    end

    return acc_array
end

"""
removes the last day of february for leap years
"""
function fix_leapyear(ta)
    new_ta = []

    for (idx,(dd, vv)) in enumerate(ta)
        if isleapyear(dd) && dd == Date(Dates.year(dd), 02, 29)
            nothing
        else
            push!(new_ta, ta[idx])
        end
    end

    return reduce(vcat, new_ta)
end

"""
cuts the time array for the chosen months
"""
function get_season(ta;
    season=["March" "April" "May" "June" "July" "August" "September" "October" "November"]
)

    ta_gs = []
    for month in season
        push!(ta_gs, when(ta, monthname, month))
    end

    return reduce(vcat, ta_gs)
end

"""
Gets the yearly mean and std of the time array based on the years chosen
"""
function get_yearlymeanstd(
    ta;
    years = 2000:2014,
    year_range = Date(2001,01,01):Dates.Day(1):Date(2001, 12,31)
)

    ta_matrix_full = zeros(365, length(years))
    
    for (idx,yy) in enumerate(years)
        year_tmp = when(ta, year, yy)
        year_tmp = fix_leapyear(year_tmp)
        ta_matrix_full[:,idx] = values(year_tmp)
    end
    
    yearly_mean = reduce(vcat, mean(ta_matrix_full, dims = 2))
    yearly_std = reduce(vcat, std(ta_matrix_full, dims = 2))

    ta_mean = TimeArray(year_range, yearly_mean)
    ta_std = TimeArray(year_range, yearly_std)

    return ta_mean, ta_std
end

"""
    function get_ta_anomalies(
        ta,
        ta_mean,
        ta_std
    )
Standardization for yearly data, given mean and std
"""
function get_ta_anomalies(
    ta,
    ta_mean,
    ta_std
)

    fixed_ta = fix_leapyear(ta)
    anomalies = zeros(size(fixed_ta,1))

    for (id,(dd,vv)) in enumerate(fixed_ta)
        fix_y = Date(2001, Dates.month(dd), Dates.day(dd))
        std = (values(fixed_ta[dd])-values(ta_mean[fix_y]))/(values(ta_std[fix_y]))
        anomalies[id] = first(std)
    end

    return TimeArray(timestamp(fixed_ta), anomalies) # =ta_anomalies
end

# to test
"""
    function get_sigma(
        ta_anomalies,
        threshold=90
    )
Given a standardized timeseries and a given threshold it returns the sigmas for the lower
and upper limit to define the extremes
"""
function get_sigma(
    ta_anomalies,
    threshold=90
)
    sigma_pos = percentile(values(ta_anomalies), threshold)
    sigma_neg = percentile(-values(ta_anomalies), threshold)
    return sigma_pos, -sigma_neg
end

# to test
"""
    get_extremes(
        ta_target,
        ta_mean,
        ta_std;
        threshold=90
    )
Given a timeseries, the yearly mean and std it returns the values over a given threshold
"""
function get_ta_extremes(
    ta_target,
    ta_mean,
    ta_std;
    threshold=90
)
    ta_anomalies = get_ta_anomalies(ta_target,
        ta_mean, ta_std
    )
    sigma_pos, sigma_neg = get_sigma(ta_anomalies, threshold)
    return build_ta_extremes(ta_target, ta_anomalies, sigma_pos, sigma_neg)
end

# fix this - conditiona_ta_extremes
# look at quantify_anomalies, I'm doing something wrong
function get_conditional_ta_extremes(
    ta_target,
    ta_condition,
    ta_mean,
    ta_std;
    threshold=90
)
    ta_condition_anomalies = get_ta_anomalies(ta_condition,
        ta_mean, ta_std
    )
    ta_anomalies = get_ta_anomalies(ta_target,
        ta_mean, ta_std
    )
    sigma_pos, sigma_neg = get_sigma(ta_condition_anomalies, threshold)
    return build_ta_extremes(ta_target, ta_anomalies, sigma_pos, sigma_neg)
end

function double_conditional_ta_extremes(
    ta_target,
    ta_condition,
    ta_mean,
    ta_std;
    threshold=90
)
    ta_condition_anomalies = get_ta_anomalies(ta_condition,
        ta_mean, ta_std
    )
    ta_anomalies = get_ta_anomalies(ta_target,
        ta_mean, ta_std
    )
    sigma_pos, sigma_neg = get_sigma(ta_condition_anomalies, threshold)
    return double_ta_extremes(ta_target, ta_anomalies, sigma_pos, sigma_neg)
end

function build_ta_extremes(
    ta_target,
    ta_anomalies,
    sigma_pos,
    sigma_neg
)
    ex_idx = findall(x-> x>sigma_pos || x<sigma_neg, ta_anomalies)
    ta_extremes = [ta_target[ex_ids] for ex_ids in ex_idx]
    
    if ta_extremes == []
        return ta_extremes
    else
        return reduce(vcat,ta_extremes)
    end

end

function double_ta_extremes(
    ta_target,
    ta_anomalies,
    sigma_pos,
    sigma_neg
)
    pos_idx = findall(x-> x>sigma_pos, ta_anomalies)
    neg_idx = findall(x-> x<sigma_neg, ta_anomalies)

    ta_pos_extremes = _build_ta_extremes(ta_target, pos_idx)
    ta_neg_extremes = _build_ta_extremes(ta_target, neg_idx)

    ta_pos_extremes, ta_neg_extremes
end

function _build_ta_extremes(ta_target, idx)

    ta_extremes = [ta_target[ids] for ids in idx]
    if ta_extremes == []
        return ta_extremes
    else
        return reduce(vcat,ta_extremes)
    end
end



# modify this
"""
given the groun truth timearray of the extremes and the timearray
of the prediction it returns the accuracy of the prediction for the
values in the extreme regime, according to a given accuracy measure
"""
function quantify_extremes(
    ta_extremes_gt,
    ta_prediction,
    acc_measure=smape
)

    gt = values(ta_extremes_gt)
    pred = values(ta_prediction[timestamp(ta_extremes_gt)])
    return acc_measure(gt, pred)
end

# TODO: fix
function extremes_mean_std(
    location,
    model,
    acc_measure,
    samples=100
)
    ground_truth, prediction = model_location_data(model, location)


end

function model_location_data(
    model, location, samples=100
)
    println(model)
    # ground truth data path
    baseline_filename = string("mean_ndvi_sg74$location", ".csv")
    baseline_path = joinpath(
        dirname(@__FILE__), "..", "data/$location", baseline_filename
    )
    # prediction data path
    prediction_filename = string(model, "$samples$location.csv")
    prediction_path = joinpath(
        dirname(@__FILE__), "..", "results/$location", prediction_filename
    )

    prediction = readdlm(prediction_path, ',')
    gt_full = readdlm(baseline_path,',')

    return gt_full, prediction
end

function data2ta(target_array, chosen_time)
    return TimeArray(chosen_time, target_array)
end

function split_traintest(target_array, idx)
    return target_array[1:idx], target_array[idx+1:end]
end

function get_ta_arrays(
    gt_full;
    time_full = Date(2000,01,01):Day(1):Date(2020,12,31),
    time_train = Date(2000,01,01):Day(1):Date(2013,09,08),
    time_pred = Date(2013,09,09):Day(1):Date(2020,12,31),
    actual_start = Date(2000,01,01)
)
    gt_train, gt_pred = split_traintest(gt_full, length(time_train))
    ta_gt_full = TimeArray(time_full, reduce(vcat, gt_full))[actual_start:Day(1):time_full[end]]
    ta_gt_train = TimeArray(time_train, reduce(vcat, gt_train))[actual_start:Day(1):time_train[end]]
    ta_gt_pred = TimeArray(time_pred, reduce(vcat, gt_pred))

    ta_gt_full, ta_gt_train, ta_gt_pred
end

function metric4extremes(location,
    model,
    acc_measure,
    samples=100;
    time_train=Date(2000,01,01):Day(1):Date(2013,09,08),
    time_pred = Date(2013,09,09):Day(1):Date(2020,12,31),
    threshold=90,
    kwargs...
)

    # get full data
    gt_full, prediction = model_location_data(
        model, location, samples
    )
    # get time arrays
    ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
        gt_full
    )
    ta_pred = data2ta(results[:,1], time_pred)
    # get yearly mean and std
    ta_mean_train, ta_std_train = get_yearlymeanstd(
        ta_gt_full, years=2000:2013
    )
    # get anomalies
    ta_anomalies = get_ta_anomalies(
        ta_gt_train, ta_mean_train, ta_std_train
    )

    ta_extremes_gt = get_conditional_ta_extremes(
        ta_gt_pred, ta_gt_train, ta_mean_train, ta_std_train;
        threshold=threshold
    )

    ex_er = quantify_extremes(
        ta_extremes_gt, ta_pred; acc_measure=acc_measure
    )

    ex_er

end

function ta2ta_extremes(ta,
    ta_mean,
    ta_std,
    sigma_pos,
    sigma_neg
)
    ta_anomalies = get_ta_anomalies(ta, ta_mean, ta_std)
    ta_extremes = build_ta_extremes(
        ta, ta_anomalies, sigma_pos, sigma_neg
    )
    return ta_extremes
end

function save_best(
    model,
    location;
    best = 50,
    samples=100,
    save_best = true)

    ground_truth, prediction = model_location_data(model, location, samples)
    ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
        ground_truth; time_pred=time_pred
    )
    gt_pred = values(ta_gt_pred)

    arr_pred = [prediction[:,i] for i in 1:samples]
    sort_pred = sort(arr_pred, lt=(x,y)->isless(nrmse(x,gt_pred), nrmse(y,gt_pred)))
    best_pred = reduce(hcat, sort_pred[1:best])

    if save_best
        open("./$location/$model$best$location.csv", "w") do io
            writedlm(io, best_pred, ',')
        end
    end

    return best_pred

end

function save_all_best(
    models,
    locations;
    kwargs...
)
    for location in locations
        println(location)
        for model in models
            bb = save_best(model, location; kwargs...)
        end
    end
end

function extremes4locations(
    locations,
    models,
    metrics = [nmrse, smape],
    samples=50;
    only_extremes = true,
    kwargs...
)


    for location in locations
        for model in models
            for metric in metrics
                rr = results4model(
                    location, model, metric, samples;
                    only_extremes=only_extremes, kwargs...
                )
                
            end
        end
    end
end