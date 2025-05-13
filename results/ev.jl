using CairoMakie
using ColorSchemes
using DelimitedFiles
using Dates
using TimeSeries
using Statistics
using StatsBase
include(joinpath(dirname(@__FILE__), "variables.jl"))
include(joinpath(dirname(@__FILE__), "results_fun.jl"))
CairoMakie.activate!(type = "svg")

### get the data
model = "ESN"
location = "IT-La2"
ground_truth, prediction = model_location_data(model, location)
ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth;
    time_full = Date(2000,01,01):Day(1):Date(2020,12,31),
    time_train = Date(2000,01,01):Day(1):Date(2013,12,31),
    time_pred = Date(2014,01,01):Day(1):Date(2020,12,31)
)

ta_gt_full = fix_leapyear(ta_gt_full)
ta_gt_train = fix_leapyear(ta_gt_train)
ta_gt_pred = fix_leapyear(ta_gt_pred)

ta_gt_mean, ta_gt_std = get_yearlymeanstd(ta_gt_full)
ta_train_anomalies = get_ta_anomalies(ta_gt_train,
    ta_gt_mean, ta_gt_std
)
ta_pred_anomalies = get_ta_anomalies(ta_gt_pred,
    ta_gt_mean, ta_gt_std
)
sigma_pos, sigma_neg = get_sigma(ta_train_anomalies, 90)


ta_train_extremes = build_ta_extremes(
    ta_gt_train, ta_train_anomalies, sigma_pos, sigma_neg
)

ta_pred_extremes = build_ta_extremes(
    ta_gt_pred, ta_pred_anomalies, sigma_pos, sigma_neg
)

ex_idx = findall(x-> x>sigma_pos || x<sigma_neg, ta_pred_anomalies)

tempo_full = string.(Dates.year.(timestamp(ta_gt_full)))
lentime_full = length(tempo_full)

tempo_train = string.(Dates.year.(timestamp(ta_gt_train)))
lentime_train = length(tempo_train)

tempo_pred = string.(Dates.year.(timestamp(ta_gt_pred)))
lentime_pred = length(tempo_pred)


function arrray2tuples(arr)
    tu = []
    nontu = []
    for (idx,val) in enumerate(arr)
        global st, fin
        if idx == 1
            if val+1 == arr[idx+1]
                st = val
            elseif val+1 != arr[idx+1]
                push!(nontu, val)
            end
        elseif idx == length(arr)
            if val-1 == arr[idx-1]
                fin = val
                push!(tu, (st, fin))
            elseif val-1 != arr[idx-1]
                push!(nontu, val)
            end
        elseif idx != 1
            if val-1 != arr[idx-1] && val+1 == arr[idx+1]
                st = val
            elseif val-1 == arr[idx-1] && val+1 != arr[idx+1]
                fin = val
                push!(tu, (st, fin))
            elseif val-1 != arr[idx-1] && val+1 != arr[idx+1]
                push!(nontu, val)
            end
        end
    end
    return tu, nontu
end

tu_idx = arrray2tuples(ex_idx)

fullpage_theme = Theme(
    colors = ColorSchemes.Dark2_3,
    Axis = (
        ticklabelsize=32,
        xticklabelsize = 38,
        yticklabelsize = 38,
        xlabelsize = 42,
        ylabelsize = 42,
        titlesize = 48,
        xgridcolor = :transparent,
        ygridcolor = :transparent,
        xtickalign = 1.0,
        ytickalign = 1.0,
        xticksmirrored = true,
        yticksmirrored = true,
        titlefont = :regular,
        xticksize = 14,
        yticksize = 14,
        xtickwidth = 3,
        ytickwidth = 3,
        spinewidth = 3,
    ),
    fontsize=34,
    backgroundcolor = RGBf(1.0, 1.0, 1.0),
    fonts = (; regular = "Arial"),
    resolution=(1920, 1080)
)

set_theme!(fullpage_theme)

### Define figure
fig = Figure()

### Split figure 
# Upper figure, full timeseries
upf = fig[1,1] = GridLayout()
# Lower figure, split train test
lowf = fig[2,1] = GridLayout()
# Lower lef figure, train
leftlowf = lowf[1,1] = GridLayout()
# Upper lower left figure, samples / mean avg
upleftlowf = leftlowf[1,1] = GridLayout()
# Lower lower left figure, normalized and distribution
lowleftlowf = leftlowf[2,1] = GridLayout()
# Lower right figure, normalized and normal data with extremes
rightlowf = lowf[1,2] = GridLayout()
uprightlowf = rightlowf[1,1] = GridLayout()
lowrightlowf = rightlowf[2,1] = GridLayout()

leftupleftlowf = upleftlowf[1,1] = GridLayout()
rightupleftlowf = upleftlowf[1,2] = GridLayout()

for (label, layout) in zip(["(a)", "(b)", "(c)", "(d)", "(e)"], [upf, upleftlowf, lowleftlowf, uprightlowf, lowrightlowf])
    Label(layout[1, 1, TopLeft()], label,
        fontsize = 42,
        font = :bold,
        padding = (0, 3, 3, 0),
        halign = :right)
end
colgap!(upleftlowf, 10)
rowgap!(rightlowf, 10)

colors = ColorSchemes.Dark2_3

### Upper figure, full timeseries
uax = Axis(upf[1,1],
        #title = "Full dataset $location",
        xlabel = "Years",
        ylabel = "NDVI",
)
lines!(uax, 1:lentime_full, reduce(vcat,mean(values(ta_gt_full), dims=2)),
    label="$location",
    linewidth=4.0,
    color=colors[1]
)
uax.xticks = (1:730:7665, string.(2000:2:2020))
rowsize!(fig.layout, 1, Relative(1/3))
Label(upf[1, 1, Top()], "Full Dataset $location", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))
vlines!(uax, [5110],
    linewidth=3.0,
    linestyle = :dash,
    color=:grey)

Label(upf[1, 1, Top()], "T",
        fontsize = 32,
        padding = (542, 3, 3, 0),
        halign = :center,
        color=:grey)
fig

Label(rightlowf[1, 1, Top()], "Testing data", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))
fig

urlax = Axis(uprightlowf[1,1],
        xticklabelsvisible = false,
        ylabel = "Normalized NDVI"
)
lines!(urlax, 1:lentime_pred, reduce(vcat,mean(values(ta_pred_anomalies), dims=2)),
    label="$location",
    linewidth=3.0,
    color=colors[3])
hlines!(urlax, [sigma_neg, sigma_pos], xmax = [1, 1],
    linestyle = :dash,
    linewidth=3.0,
    color=:firebrick3)
urlax.yticks = ([sigma_neg, sigma_pos], [L"\kappa_-", L"\kappa_+"])
urlax.xticks = (1:365:2555, string.(2014:1:2020))
fig

lrlax = Axis(
    lowrightlowf[1,1],
    xlabel = "Years",
    ylabel = "NDVI",
)
lines!(lrlax, 1:lentime_pred, reduce(vcat,mean(values(ta_gt_pred), dims=2)),
    label="$location",
    linewidth=3.0,
    color=colors[3])
vspan!(lrlax, [x[1] for x in tu_idx[1]], [x[2] for x in tu_idx[1]],
    color=(:firebrick3, 0.2))
vlines!(lrlax, [x[1] for x in tu_idx[2]],
    color=(:firebrick3, 0.2))
lrlax.xticks = (1:365:2555, string.(2014:1:2020))
fig

Label(leftlowf[1, 1:1, Top()], "Training data", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))

llax = Axis(leftupleftlowf[1,1],
        xlabel = "Months",
        ylabel = "NDVI"
)

for (yidx,yys) in enumerate(2000:2014)
    ta = when(ta_gt_full, year, yys)
    lines!(llax, reduce(vcat,values(ta)),
        color = (colors[2], 0.6),
        linewidth=3.0)
end
llax.xticks = ([1, 91, 182, 274], ["Jan", "Apr", "Jul", "Oct"])
ylims!(llax, 0.5, 0.88)
fig

rllax = Axis(rightupleftlowf[1,1],
    xlabel = "Months",
    yticklabelsvisible = false
)

lines!(rllax, reduce(vcat, values(ta_gt_mean)),
    color=colors[2],
    linewidth=3.0)
band!(rllax,
    1:length(reduce(vcat, values(ta_gt_mean))),
    reduce(vcat, values(ta_gt_mean)).+reduce(vcat, values(ta_gt_std)),
    reduce(vcat, values(ta_gt_mean)).-reduce(vcat, values(ta_gt_std)),
    color=(colors[2], 0.3))
rllax.xticks = ([1, 91, 182, 274], ["Jan", "Apr", "Jul", "Oct"])
ylims!(rllax, 0.5, 0.88)
fig

ulax = Axis(lowleftlowf[1,1],
        xlabel = "Years",
        ylabel = "Normalized NDVI",
        yticksmirrored = false
)
lines!(ulax, 1:lentime_train, reduce(vcat,mean(values(ta_train_anomalies), dims=2)),
    label="$location",
    linewidth=3.0,
    color=colors[2])
hlines!(ulax, [sigma_neg, sigma_pos], xmax = [1, 1],
    linewidth=3.0,
    linestyle = :dash,
    color=:firebrick3)
ulax.xticks = (1:1460:5110, string.(2000:4:2012))
ulax.yticks = ([-2.0, sigma_neg, 0.0, sigma_pos, 2.0], ["-2", L"\kappa_-", "0", L"\kappa_+", "2"])
fig

rlax = Axis(lowleftlowf[1,2],
    backgroundcolor = :transparent,
    leftspinevisible = false,
    rightspinevisible = false,
    bottomspinevisible = false,
    topspinevisible = false,
    xticklabelsvisible = false, 
    yticklabelsvisible = false,
    xgridcolor = :transparent,
    ygridcolor = :transparent,
    xminorticksvisible = false,
    yminorticksvisible = false,
    xticksvisible = false,
    yticksvisible = false,
    xautolimitmargin = (0.0,0.0),
    yautolimitmargin = (0.0,0.0),
    xticksmirrored = false,
    yticksmirrored = false
)

hist!(rlax, reduce(vcat,mean(values(ta_train_anomalies), dims=2)),
    direction=:x,
    color=colors[2])
hidedecorations!(rlax, grid = false)

colsize!(lowleftlowf, 1, Relative(4/5))
colgap!(lowleftlowf, 5)
fig

save("./extremes.eps", fig, dpi=300)

