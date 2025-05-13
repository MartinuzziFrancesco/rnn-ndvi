### BinaryValues
struct BinaryValues
    hits::Int #true positives
    false_alarms::Int #false positives
    misses::Int #false negatives
    correct_rejections::Int
    tot::Int
end

function bvsum(bv1::BinaryValues, bv2::BinaryValues)
    return BinaryValues(
        bv1.hits+bv2.hits, bv1.false_alarms+bv2.false_alarms, bv1.misses+bv2.misses,
        bv1.tot-(bv1.hits+bv2.hits+bv1.misses+bv2.misses)-(bv1.false_alarms+bv2.false_alarms),
        bv1.tot
    )
end

pod(bv::BinaryValues) = _pod(bv.hits, bv.misses)
pofd(bv::BinaryValues) = _pofd(bv.false_alarms, bv.correct_rejections)
pofa(bv::BinaryValues) = _pofa(bv.false_alarms, bv.hits)
pc(bv::BinaryValues) = _pc(bv.hits, bv.correct_rejections, bv.tot)
fbias(bv::BinaryValues) = _fbias(bv.hits, bv.misses, bv.false_alarms)
fscore(bv::BinaryValues) = _fscore(bv.hits, bv.false_alarms, bv.misses)


function _base_rate(hits, misses, tot)
    return (hits+misses)/tot
end

function _pod(hits, misses) #hit_rate
    return hits/(hits+misses)
end

function _pofd(false_alarms, correct_rejections) #falsealarm_rate
    return false_alarms/(false_alarms+correct_rejections)
end

function _pofa(false_alarms, hits) #falsealarm_ratio
    return false_alarms/(false_alarms+hits)
end

function _pc(hits, correct_rejections, tot) #proportion_correct
    return (hits+correct_rejections)/tot
end

function _fbias(hits, misses, false_alarms)
    return (hits+false_alarms)/(hits+misses)
end

function _base_rate(hits, misses, tot)
    return (hits+misses)/tot
end

function auc(bv::BinaryValues)
    return (1+pod(bv)-pofd(bv))/(2)
end

function _fscore(tp, fp, fn)
    return (2*tp)/(2*tp+fp+fn)
end


### Binary events with ta
"""
checks if the extreme events in `ta_extremes_target`
are also in `ta_extremes_candidate` and returns the number
of values for which this does not occurr ("false negatives")
"""
function binary_elements(
    ta_gt,
    ta_extremes_gt,
    ta_extremes_pred
)
    hits = 0

    if ta_extremes_pred == []
        hits = 0
    else
        for idx in eachindex(ta_extremes_gt)
            if first(timestamp(ta_extremes_gt[idx])) in timestamp(ta_extremes_pred)
                hits+=1
            end
        end
    end

    misses = length(ta_extremes_gt) - hits
    false_alarms = length(ta_extremes_pred) - hits
    correct_rejections = length(ta_gt) - length(ta_extremes_gt) - false_alarms

    return BinaryValues(hits, false_alarms, misses, correct_rejections, length(ta_gt))
end

function extremes4model(
    location,
    model,
    threshold,
    samples=100;
    time_pred = Date(2013,09,09):Day(1):Date(2020,12,31),
    cut_season=false,
    only_negatives = false,
    season=["May" "June" "July" "August" "September"],
    binary_quantifier = pod
)

    ground_truth, prediction = model_location_data(model, location, samples)
    ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
        ground_truth; time_pred=time_pred
    )

    ta_gt_train = ta_gt_train[Date(2002,01,01):Day(1):Date(2013,09,08)]
    
    bqs = []

    for i in 1:samples

        ta_prediction = data2ta(prediction[:,i], time_pred)
        ta_gt_mean, ta_gt_std = get_yearlymeanstd(ta_gt_full)

        if cut_season
            ta_gt_train = get_season(ta_gt_train, season=season)
            ta_gt_mean = get_season(ta_gt_mean, season=season)
            ta_gt_std = get_season(ta_gt_std, season=season)
            ta_gt_pred = get_season(ta_gt_pred, season=season)
            ta_prediction = get_season(ta_prediction, season=season)
            ta_extremes_gt = double_conditional_ta_extremes(
                ta_gt_pred, ta_gt_pred, ta_gt_mean, ta_gt_std;
                threshold=threshold
            )
            ta_extremes_pred = double_conditional_ta_extremes(
                ta_prediction, ta_gt_pred, ta_gt_mean, ta_gt_std;
               threshold=threshold
            )
        else
            ta_extremes_gt = double_conditional_ta_extremes(
                ta_gt_pred, ta_gt_train, ta_gt_mean, ta_gt_std;
                threshold=threshold
            )
            ta_extremes_pred = double_conditional_ta_extremes(
                ta_prediction, ta_gt_train, ta_gt_mean, ta_gt_std;
                threshold=threshold
            )
        end

        be1 = binary_elements(
            ta_gt_pred, ta_extremes_gt[1], ta_extremes_pred[1]
        )
        be2 = binary_elements(
            ta_gt_pred, ta_extremes_gt[2], ta_extremes_pred[2]
        )

        if only_negatives
            be = be2
        else
            be = bvsum(be1, be2)
        end

        bq = binary_quantifier(be)

        if isnan(bq)
            continue
        else
            push!(bqs, bq)
        end
    end

    bqs_mean = mean(bqs)
    bqs_std = std(bqs)
    return bqs_mean, bqs_std
end

function range_extremes4model(
    location,
    model,
    thresholds=90:1:99,
    samples=100;
    kwargs...
)
    extremes_mean = zeros(length(thresholds))
    extremes_std = zeros(length(thresholds))
    for (tidx,threshold) in enumerate(thresholds)
        println(threshold)
        exs = extremes4model(
            location,
            model,
            threshold,
            samples;
            kwargs...
        )
        extremes_mean[tidx], extremes_std[tidx] = exs[1], exs[2]
    end

    return extremes_mean, extremes_std
end

function extremes4locations(
    locations,
    model,
    thresholds=90:1:99,
    samples=100;
    #save = true,
    kwargs...
)

    extremes_mean = zeros(length(thresholds), length(locations))
    extremes_std = zeros(length(thresholds), length(locations))

    for (lidx,location) in enumerate(locations)
        println(location)
        exs = range_extremes4model(
            location,
            model,
            thresholds,
            samples;
            kwargs...
        )

        extremes_mean[:,lidx], extremes_std[:,lidx] = exs[1], exs[2]
    end

    return mean(extremes_mean, dims=2), std(extremes_std, dims=2)
end

function extremes4modelslocations(
    locations,
    models,
    binary_quantifier,
    thresholds=90:1:99,
    samples=100;
    save_extremes = true,
    filename="full",
    kwargs...
)

    extremes_mean = zeros(length(thresholds), length(models))
    extremes_std = zeros(length(thresholds), length(models))

    for (midx,model) in enumerate(models)
        println(model)
        exs = extremes4locations(
            locations,
            model,
            thresholds,
            samples;
            binary_quantifier=binary_quantifier,
            kwargs...
        )

        extremes_mean[:,midx], extremes_std[:,midx] = exs[1], exs[2]
    end

    if save_extremes
         
        open("./mean$filename$binary_quantifier.csv", "w") do io
            writedlm(io, extremes_mean, ',')
        end
        open("./std$filename$binary_quantifier.csv", "w") do io
            writedlm(io, extremes_std, ',')
        end
    end

    return extremes_mean, extremes_std

end