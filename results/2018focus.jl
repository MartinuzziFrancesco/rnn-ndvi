using CairoMakie
using DelimitedFiles
using Dates
using TimeSeries
using StatsBase
using ComplexityMeasures
using Distances

CairoMakie.activate!(type = "svg")

function get_growingseason(ta;
    growing_season=["March" "April" "May" "June" "July" "August" "September" "October"])

    ta_gs = []
    for month in growing_season
        push!(ta_gs, when(ta, monthname, month))
    end
    ta_gs = reduce(vcat, ta_gs)
    return ta_gs
end

function get_yearlymeanstd(
    ta;
    years = 2000:2020,
    year_range = Date(2001,01,01):Dates.Day(1):Date(2001, 12,31)
)

    ta_matrix_full = zeros(365, length(years))
    
    for (idx,yy) in enumerate(years)
        year_tmp = when(ta, year, yy)
        if size(year_tmp, 1) == 366
            year_tmp = year_tmp[1:end-1]
        end
        ta_matrix_full[:,idx] = values(year_tmp)
    end
    
    mean_ndvi = reduce(vcat, mean(ta_matrix_full, dims = 2))
    std_ndvi = reduce(vcat, std(ta_matrix_full, dims = 2))
    
    ta_mean_ndvi = TimeArray(year_range, mean_ndvi)
    ta_std_ndvi = TimeArray(year_range, std_ndvi)

    return ta_mean_ndvi, ta_std_ndvi
end

function get_stddiff(
    ta,
    ta_mean,
    ta_std
)

    std_ndvi = zeros(size(ta,1))

    for (id,(dd,vv)) in enumerate(ta)
        fix_y = Date(2001, Dates.month(dd), Dates.day(dd))
        std = (values(ta[dd])-values(ta_mean[fix_y]))/(values(ta_std[fix_y]))
        std_ndvi[id] = first(std)
    end

    return TimeArray(timestamp(ta), std_ndvi)
end

start_preddate = Date(2013,09,09)
start_date = Date(2000,01,01)
stop_date = Date(2020,12,31)
time_full = start_date:Day(1):stop_date
time_pred = start_preddate:Day(1):stop_date


path = "/home/francesco/Documents/rnn-ndvi/"
location = "DE-Obe"
idx = 1

esn_results = Array(readdlm(path*"results/$location/20230308$location$idx.txt", ',', Float32)')
ground_truth_full = readdlm(path*"data/$location/mean_ndvi_sg74$location.csv", Float32)
ground_truth_pred = ground_truth_full[5001:end]

ta_gt_full = TimeArray(time_full, reduce(vcat, ground_truth_full))
ta_gt_pred = TimeArray(time_pred, reduce(vcat, ground_truth_pred))
ta_esn = TimeArray(time_pred, reduce(vcat, esn_results))

years = 2005:1:2013




fig = Figure(resolution=(1920, 1080),
    fonts = (; regular = "Arial"),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0))
ax = Axis(fig[1, 1],
    title = "$location",
    #xlabel = "Months",
    #xticksvisible = false,
    ylabel = "NDVI",
    #xticklabelsize = 42,
    yticklabelsize = 42,
    #xlabelsize = 48,
    ylabelsize = 48,
    titlesize = 52
)

for year in years

    ta_plot = ta_gt_full[Date(year,03,01):Date(year,12,31)]
    lentime = length(ta_plot)
    if year == 2005
        lines!(ax, 1:lentime, values(ta_plot),
            label="Years in Training Set",
            color=:grey,
            linewidth=2.0)
    else
        lines!(ax, 1:lentime, values(ta_plot),
            #label="Training Years",
            color=:grey,
            linewidth=2.0)
    end
end

ta_plot = ta_gt_full[Date(2018,3,01):Date(2018,12,31)]
lentime = length(ta_plot)
lines!(ax, 1:lentime, values(ta_plot),
    label="2018 Ground Truth",
    color=:black,
    linewidth=4.0)

ta_plot = ta_esn[Date(2018,3,01):Date(2018,12,31)]
lentime = length(ta_plot)

tempo = timestamp(ta_plot)
lentime2 = length(tempo)
slice_dates = range(1, lentime2, step=lentime2 ÷ 6)

ax.xticks = (slice_dates, Dates.monthname.(tempo[slice_dates]))
#ax.xticklabelrotation = π / 4
#ax.xticklabelalign = (:right, :center)

lines!(ax, 1:lentime, values(ta_plot),
    label="2018 ESN Prediction",
    color=:red,
    linewidth=4.0)

Legend(fig[1,2], ax, "Locations")



ground_truth_full = readdlm(
    path*"data/$location/mean_ndvi_sg74$location.csv", Float32
)
ta_gt_full = TimeArray(time_full, reduce(vcat, ground_truth_full))
ta_mean_full, ta_std_full = get_yearlymeanstd(ta_gt_full)



ta_gt_std_diff = get_stddiff(ta_gt_full[Date(2018,3,01):Date(2018,12,31)],
    ta_mean_full, ta_std_full
)

ta_esn_std_diff = get_stddiff(ta_esn[Date(2018,3,01):Date(2018,12,31)],
    ta_mean_full, ta_std_full
)

ax21 = Axis(fig[2, 1],
    #title = "$location",
    xlabel = "Months",
    ylabel = "Anomalies",
    xticklabelsize = 42,
    yticklabelsize = 42,
    xlabelsize = 48,
    ylabelsize = 48,
    titlesize = 52
)

lines!(ax21, 1:lentime, values(ta_gt_std_diff),
    color=:black,
    linewidth=4.0)

lines!(ax21, 1:lentime, values(ta_esn_std_diff),
    color=:red,
    linewidth=4.0)

ax21.xticks = (slice_dates, Dates.monthname.(tempo[slice_dates]))
ax21.xticklabelrotation = π / 4
ax21.xticklabelalign = (:right, :center)
#hideydecorations!(ax, grid = false)
rowsize!(fig.layout, 1, Relative(3/4))
#trim!(fig.layout)
rowgap!(fig.layout, 1, Relative(0.01))
save("test.png", fig, px_per_unit = 2)


#### NEW ONE ####
location = "BE-Vie"

model = "esn"
ground_truth, prediction_esn = model_location_data(model, location)
prediction_esn = mean(prediction_esn, dims=2)
model = "rnntanh"
_, prediction_rnn = model_location_data(model, location)
prediction_rnn = mean(prediction_rnn, dims=2)
model="gru"
_, prediction_gru = model_location_data(model, location)
prediction_gru = mean(prediction_gru, dims=2)
model="lstm"
_, prediction_lstm = model_location_data(model, location)
prediction_lstm = mean(prediction_lstm, dims=2)

ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth;
    time_full = Date(2000,01,01):Day(1):Date(2020,12,31),
    time_train = Date(2000,01,01):Day(1):Date(2013,12,31),
    time_pred = Date(2014,01,01):Day(1):Date(2020,12,31)
)

time_pred = Date(2013,09,09):Day(1):Date(2020,12,31)
ta_gt_full = fix_leapyear(ta_gt_full)
ta_gt_train = fix_leapyear(ta_gt_train)
ta_gt_pred = fix_leapyear(ta_gt_pred)

ta_gt_mean, ta_gt_std = get_yearlymeanstd(ta_gt_full)

ta_range = Date(2018,01,01):Day(1):Date(2018,12,31)
ta_mean_range = Date(2001,01,01):Day(1):Date(2001,12,31)
ta_gt_mean, ta_gt_std = ta_gt_mean[ta_mean_range], ta_gt_std[ta_mean_range]
ta_prediction_esn = fix_leapyear(data2ta(prediction_esn, time_pred))[ta_range]
ta_prediction_rnn = fix_leapyear(data2ta(prediction_rnn, time_pred))[ta_range]
ta_prediction_gru = fix_leapyear(data2ta(prediction_gru, time_pred))[ta_range]
ta_prediction_lstm = fix_leapyear(data2ta(prediction_lstm, time_pred))[ta_range]
ta_gt_pred = ta_gt_pred[ta_range]


fig = Figure(resolution=(1920, 1080),
    fonts = (; regular = "Arial"),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0))
ax = Axis(fig[1, 1],
    title = "$location",
    #xlabel = "Months",
    #xticksvisible = false,
    ylabel = "NDVI",
    #xticklabelsize = 42,
    yticklabelsize = 42,
    #xlabelsize = 48,
    ylabelsize = 48,
    titlesize = 52
)

lines!(ax, 1:length(ta_gt_mean), reduce(vcat, values(ta_gt_mean)),
    label="Mean 2000-2014",
    color=:black,
    linewidth=3.0)
band!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_gt_mean)) .- reduce(vcat, values(ta_gt_std)),
    reduce(vcat, values(ta_gt_mean)) .+ reduce(vcat, values(ta_gt_std)),
    color=(:black, 0.2))
lines!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_gt_pred)),
    label="2018 Actual",
    color=:blue,
    linewidth=3.0)
lines!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_prediction_esn)),
    label="esn",
    color=:green,
    linewidth=3.0)

lines!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_prediction_rnn)),
    label="rnn",
    color=:yellow,
    linewidth=3.0)
lines!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_prediction_gru)),
    label="gru",
    color=:cyan,
    linewidth=3.0)
lines!(ax, 1:length(ta_gt_mean),
    reduce(vcat, values(ta_prediction_lstm)),
    label="lstm",
    color=:red,
    linewidth=3.0)
Legend(fig[1,2], ax, "Legend")

save("test.png", fig, px_per_unit = 2)

m, τ = 6, 1
c = StatisticalComplexity(
    dist=JSDivergence(),
    est=SymbolicPermutation(; m, τ),
    entr=Renyi()
)
res_esn = reduce(vcat, values(ta_gt_pred) .- values(ta_prediction_esn))
res_rnn = reduce(vcat, values(ta_gt_pred) .- values(ta_prediction_rnn))
res_gru = reduce(vcat, values(ta_gt_pred) .- values(ta_prediction_gru))
res_lstm = reduce(vcat, values(ta_gt_pred) .- values(ta_prediction_lstm))
ec_esn = entropy_complexity(c, res_esn)
ec_rnn = entropy_complexity(c, res_rnn)
ec_gru = entropy_complexity(c, res_gru)
ec_lstm = entropy_complexity(c, res_lstm)

cc = entropy_complexity_curves(c,num_max=1000)

fig = Figure(resolution=(1920, 1080),
    fonts = (; regular = "Arial"),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0))
ax = Axis(fig[1, 1],
    #title = "$location",
    #xlabel = "Months",
    #xticksvisible = false,
    #ylabel = "NDVI",
    #xticklabelsize = 42,
    yticklabelsize = 42,
    #xlabelsize = 48,
    ylabelsize = 48,
    titlesize = 52
)

scatter!(ax, ec_esn[1], ec_esn[2],
    label="esn")
scatter!(ax, ec_rnn[1], ec_rnn[2],
    label="rnn")
scatter!(ax, ec_gru[1], ec_gru[2],
    label="gru")
scatter!(ax, ec_lstm[1], ec_lstm[2],
    label="lstm")
lines!(ax, reduce(hcat,cc[1])[1,:], reduce(hcat,cc[1])[2,:])
lines!(ax, reduce(hcat,cc[2])[1,:], reduce(hcat,cc[2])[2,:])

Legend(fig[1,2], ax, "Legend")

save("ec.png", fig, px_per_unit = 2)
