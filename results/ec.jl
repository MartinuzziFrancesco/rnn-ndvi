using CairoMakie
using DelimitedFiles
using Dates
using TimeSeries
using StatsBase
using ComplexityMeasures
using Distances
using ColorSchemes
CairoMakie.activate!(type = "svg")

include(joinpath(dirname(@__FILE__), "variables.jl"))
include(joinpath(dirname(@__FILE__), "results_fun.jl"))
models = ["LSTM", "GRU", "RNN_TANH", "ESN"]
season = ["May" "June" "July" "August" "September"]


time_pred = Date(2013,09,09):Day(1):Date(2020,12,31)
models2names = Dict("LSTM"=>"LSTM",
                        "GRU" => "GRU",
                        "RNN_TANH" => "RNN",
                        "ESN" => "ESN")

m, τ = 6, 1
c = StatisticalComplexity(
    dist=JSDivergence(),
    est=SymbolicPermutation(; m, τ),
    entr=Renyi()
)
cc = entropy_complexity_curves(c,num_max=100)

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

cut_season = false
colors = ColorSchemes.seaborn_colorblind

fig = Figure(resolution=(1920, 1080),
    fonts = (; regular = "Arial", bold="Arial bold"),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0))

ug = fig[1,1] = GridLayout()
ff = fig[2,1] = GridLayout()

#fff = ff[1,1] = GridLayout()
#sff = ff[1,2] = GridLayout()

fug = ug[1,1] = GridLayout()
sug = ug[1,2] = GridLayout()

ax = Axis(fug[1, 1],
    title = "Full Season",
    titlefont = :bold,
    xlabel = "Entropy", #L"\mathcal{H}[P]",
    ylabel = "Complexity" #L"\mathcal{C}[P]",
)

markers = [:circle, :hexagon, :diamond, :rect]

full_e = zeros(length(locations), length(models))
full_c = zeros(length(locations), length(models))
for (lidx,location) in enumerate(locations)
    ec_mod = []
    for (midx,model) in enumerate(models)
        ground_truth, prediction = model_location_data(model, location)
        ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth)
        ta_prediction = data2ta(prediction, time_pred)
        residuals = reduce(
            vcat, values(ta_gt_pred) .- values(ta_prediction)
        )
        ec = entropy_complexity(c, residuals)
        full_e[lidx,midx], full_c[lidx,midx] = ec[1], ec[2]
        scatter!(ax, ec[1], ec[2],
            marker=markers[midx],
            color = colors[midx],
            markersize=24)
    end
    println("Done: ", location)
end

avg_e = mean(full_e, dims=1)
avg_c = mean(full_c, dims=1)

for (midx,model) in enumerate(models)
    scatter!(ax, avg_e[1,midx], avg_c[1,midx],
        marker=markers[midx],
        markersize=32.0,
        color=:black)
end

newcc2 = [cc[2][i] for i in 1:70:length(cc[2])]
lines!(ax,
    reduce(hcat,cc[1])[1,:],
    reduce(hcat,cc[1])[2,:],
    color=:grey
)
lines!(ax,
    reduce(hcat,newcc2)[1,:],
    reduce(hcat,newcc2)[2,:],
    color=:grey)

#save("ec_test.png", fig, px_per_unit = 2)

cut_season = true
ax2 = Axis(sug[1, 1],
    title = "Growing Season",
    titlefont = :bold,
    xlabel = "Entropy", #L"\mathcal{H}[P]",
    yticklabelsvisible = false
    #ylabel = "Complexity" #L"\mathcal{C}[P]",
)

full_e = zeros(length(locations), length(models))
full_c = zeros(length(locations), length(models))
for (lidx,location) in enumerate(locations)
    ec_mod = []
    for (midx,model) in enumerate(models)
        ground_truth, prediction = model_location_data(model, location)
        ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth)
        ta_prediction = data2ta(prediction, time_pred)
        if cut_season
            ta_gt_pred = get_season(ta_gt_pred, season=season)
            ta_prediction = get_season(ta_prediction, season=season)
        end
        residuals = reduce(
            vcat, values(ta_gt_pred) .- values(ta_prediction)
        )
        ec = entropy_complexity(c, residuals)
        full_e[lidx,midx], full_c[lidx,midx] = ec[1], ec[2]
        scatter!(ax2, ec[1], ec[2],
            marker=markers[midx],
            color = colors[midx],
            markersize=24)
    end
    println("Done: ", location)
end

avg_e = mean(full_e, dims=1)
avg_c = mean(full_c, dims=1)

for (midx,model) in enumerate(models)
    scatter!(ax2, avg_e[1,midx], avg_c[1,midx],
        marker=markers[midx],
        markersize=32.0,
        color=:black)
end

labels = [models2names[mm] for mm in models]
elements = [
    MarkerElement(marker=ma,color=colors[im],markersize=24) for (im,ma) in enumerate(markers)
]

elemts_b = [
    MarkerElement(marker=ma,color=:black,markersize=32) for (im,ma) in enumerate(markers)
]

legends = [Legend(
    ff[1,1],
    [elements, elemts_b],
    [labels, labels],
    ["Models", "Average"],
    labelsize = 32,
    titlesize = 35,
    titlefont = :bold,
    orientation = :horizontal,
    titleposition = :left,
    nbanks=2
)]

lines!(ax2,
    reduce(hcat,cc[1])[1,:],
    reduce(hcat,cc[1])[2,:],
    color=:grey
)
lines!(ax2,
    reduce(hcat,newcc2)[1,:],
    reduce(hcat,newcc2)[2,:],
    color=:grey)
fig
save("f05.eps", fig,dpi=300)
