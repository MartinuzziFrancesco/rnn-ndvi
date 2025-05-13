using CairoMakie
using DelimitedFiles
using Dates
using TimeSeries
using PyCall
skl = pyimport("sklearn.metrics")

function plot_traj(location; kwargs...)
end

function scatter_prec(location; kwargs...)
end

function plot_extremes(location; kwargs...)
end

CairoMakie.activate!(type = "svg")

start_date = Date(2013,09,09)
stop_date = Date(2020,12,31)
time = start_date:Day(1):stop_date

path = "/home/francesco/Documents/rnn-ndvi/"
locations = ["IT-Lav",
                     "SE-Nor",
                     "DE-Wet",
                     "CZ-BK1",
                     "NL-Loo",
                     "SE-Htm",
                     "DE-Obe",
                     "CZ-Stn",
                     "SE-Sk2",
                     "DE-Bay",
                     "FI-Hyy",
                     "BE-Vie",
                     "DE-Hzd",
                     "DE-RuW",
                     "SE-Ros",
                     #"FR-Pue",
                     "DE-Lkb",
                     "FI-Let",
                     "IT-La2",
                     "IT-Ren",
                     "SE-Svb",
                     "DE-Hai",
                     "CZ-Lnz"
]


idx = 1
for location in locations
isdir(path*"data/$location") ? nothing : mkdir(path*"data/$location")

#lstm_results = readdlm(path*"data/$location/ndvi_lstm.csv", Float32)[15:end]
esn_results = Array(readdlm(path*"results/$location/20230308$location$idx.txt", ',', Float32)')
ground_truth = readdlm(path*"data/$location/mean_ndvi_sg74$location.csv", Float32)[5001:end]

#rmse_lstm = round(skl.mean_squared_error(ground_truth', lstm_results'), digits=4)
rmse_esn = round(skl.mean_squared_error(ground_truth', reduce(vcat,esn_results)'), digits=4)

#mae_lstm = round(skl.mean_absolute_error(ground_truth', lstm_results'), digits=4)
mae_esn = round(skl.mean_absolute_error(ground_truth', reduce(vcat,esn_results)'), digits=4)

#r2_lstm = round(skl.r2_score(ground_truth', lstm_results'), digits=4)
r2_esn = round(skl.r2_score(ground_truth', reduce(vcat,esn_results)'), digits=4)

ta_gt = TimeArray(time, ground_truth)
ta_esn = TimeArray(time, reduce(vcat, esn_results))
#ta_lstm = TimeArray(time, reduce(vcat, lstm_results))

tempo = string.(timestamp(ta_gt))
lentime = length(tempo)
slice_dates = range(1, lentime, step=lentime ÷ 5)

fig = Figure(resolution=(1920, 500),
    fonts = (; regular = "Arial"),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0))
ax = Axis(fig[1, 1],
    title = "$location",
    xlabel = "Years",
    ylabel = "NDVI",
    xticklabelsize = 32,
    yticklabelsize = 32,
    xlabelsize = 40,
    ylabelsize = 40,
    titlesize = 46
)


lines!(ax, 1:lentime, values(ta_gt),
    label="Ground Truth",
    color=:black,
    linewidth=2.0)
lines!(ax, 1:lentime, values(ta_esn),
    label="ESN Prediction",
    color=:red,
    linewidth=2.0)
#lines!(ax, 1:lentime, values(ta_lstm), label="LSTM Prediction")
axislegend("Legend", position = :lb)
ax.xticks = (slice_dates, tempo[slice_dates])
ax.xticklabelrotation = π / 4
ax.xticklabelalign = (:right, :center)
fig
save(path*"results/$location/test.png", fig, px_per_unit = 2)

fig2 = Figure(resolution=(1080, 1080),
    backgroundcolor = RGBf(0.98, 0.98, 0.98))
ax2 = Axis(fig2[1, 1],
    title = "ESN",
    xlabel = "Actual",
    ylabel = "Predicted"
)
limits!(ax2, 0.0, 1.0, 0.0, 1.0)

scatter!(ax2, values(ta_gt), values(ta_esn))
text!(ax2, 0.45, 0.85, text="rmse=$rmse_esn\n mae=$mae_esn\n r2=$r2_esn",
    fontsize = 30,
    align=(:left, :top),
    color=:black,
    position=(0,0),
    space = :data)
#rmse=$rmse_lstm\n mae=$mae_lstm\n r2=$r2_lstm"
fig2
save(path*"results/$location/test2.png", fig2, px_per_unit = 2)

#=
fig3 = Figure(resolution=(1080, 1080),
    backgroundcolor = RGBf(0.98, 0.98, 0.98))
ax3 = Axis(fig3[1, 1],
    title = "LSTM",
    xlabel = "Actual",
    ylabel = "Predicted"
)
limits!(ax3, 0.0, 1.0, 0.0, 1.0)

scatter!(ax3, values(ta_gt), values(ta_lstm))
text!(ax3, 0.45, 0.85, text="rmse=$rmse_lstm\n mae=$mae_lstm\n r2=$r2_lstm",
    fontsize = 30,
    align=(:left, :top),
    color=:black,
    position=(0,0),
    space = :data)
#rmse=$rmse_lstm\n mae=$mae_lstm\n r2=$r2_lstm"
fig3
save(path*"results/$location/test3.png", fig3, px_per_unit = 2)
=#

end