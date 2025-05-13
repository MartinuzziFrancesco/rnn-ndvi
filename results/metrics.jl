"""
Weighted Absolute Percentage Error
"""
function wape(gt, pred)
    return 100 * sum(abs.(gt - pred)) / sum(abs.(gt))
end

"""
Mean Squared Error
"""
function mse(gt, pred)
    mean((gt - pred).^2)
end

"""
Mean Absolute Error
"""
function mae(gt, pred)
    mean(abs.(gt - pred))
end

"""
Coefficient of Variation
"""
function coef_variation(gt, pred)
    100 * std(gt - pred) / mean(gt)
end

"""
Mean Absolute Ranged Relative Error
"""
function marre(gt, pred)
    100 * mean(abs.(gt - pred) / (maximum(gt) - minimum(gt)))
end

"""
Optimality Percentage Error
"""
function ope(gt, pred)
    sum(abs.(gt - pred)) / sum(abs.(gt .- mean(gt)))
end

"""
Root Mean Squared Log Error
"""
function rmsle(gt, pred)
    gt = gt .- minimum(gt) .+ 1e-8
    pred = pred .- minimum(pred) .+ 1e-8
    sqrt(mean(((log.(pred .+ 1) - log.(gt .+ 1)).^2)))
end


"""
R2 score
"""
function r2_score(gt, pred)
    1 - sum((gt - pred).^2) / sum((gt .- mean(gt)).^2)
end

"""
Mean Absolute Percentage Error
"""
function mape(gt, pred)
    100 * mean(abs.(gt - pred) ./ gt)
end

"""
Symmetric mean absolute percentage error
"""
function smape(gt, pred)
    100 * mean(abs.(gt - pred) ./ (abs.(gt) + abs.(pred))) * 2
end

"""
Normalized Root Mean Squared Error
"""
function nrmse(gt, pred)
    rmsd(gt, pred, normalize=true)
end

metrics = [wape,
           mse,
           mae,
           coef_variation,
           marre,
           ope,
           rmsle,
           r2_score,
           mape,
           smape,
           nrmse]


