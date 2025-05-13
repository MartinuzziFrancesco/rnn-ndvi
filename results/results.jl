using CairoMakie
using DelimitedFiles
using Dates
using TimeSeries
using PyCall
using StatsBase
include(joinpath(dirname(@__FILE__), "variables.jl"))
skl = pyimport("sklearn.metrics")
CairoMakie.activate!(type = "svg")

fig = Figure(resolution=(1200, 1080),
    fonts = (; regular = "Arial"),
    fontsize=32,
    backgroundcolor = RGBf(1.0, 1.00, 1.00))

ax = Axis(fig[1, 1],
    #title = "Results",
    xlabel = "Actual NDVI",
    ylabel = "Predicted NDVI",
    xticklabelsize = 42,
    yticklabelsize = 42,
    xlabelsize = 48,
    ylabelsize = 48,
    #titlesize = 46
)

limits!(ax, 0.35, 0.9, 0.35, 0.9)
idx = 1
growing_season = ["March" "April" "May" "June" "July" "August" "September" "October"]

r2_tot = zeros(length(locations))
mae_tot = zeros(length(locations))

for (i,location) in enumerate(locations)
    esn_results = Array(readdlm(path*"results/$location/20230308$location$idx.txt", ',', Float32)')
    ground_truth = readdlm(path*"data/$location/mean_ndvi_sg74$location.csv", Float32)[5001:end]

    ta_total = TimeArray(time_pred, [ground_truth reduce(vcat, esn_results)])
    ta_plot = []
    for month in growing_season
        push!(ta_plot, when(ta_total, monthname, month))
    end
    ta_plot = reduce(vcat, ta_plot)
    mae_tot[i] = round(skl.mean_absolute_error(values(ta_plot)[:,1]', values(ta_plot)[:,2]'), digits=4)
    r2_tot[i] = round(skl.r2_score(values(ta_plot)[:,1]', values(ta_plot)[:,2]'), digits=4)

    scatter!(ax, values(ta_plot)[:,1], values(ta_plot)[:,2], label="$location")
end

# Diagonal
x = 0.0:0.1:1.0
lines!(ax, x, x,
        color=:grey,
        linewidth=5.0)

Legend(fig[1,2], ax, "Locations")
save("./full_results.png", fig, px_per_unit = 2)

println(mean(r2_tot), mean(mae_tot))