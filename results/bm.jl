using CairoMakie, DelimitedFiles, Dates, TimeSeries, StatsBase, ColorSchemes, JLD2

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


models = [
    "LSTM",
    "GRU",
    "RNN_TANH",
    "ESN"
]
binary_metrics = [
    "pod",
    "pofd",
    "pofa",
    "pc"
]
colors = ColorSchemes.seaborn_colorblind
colormap=:Accent_4
markers = [:circle, :hexagon, :diamond, :rect]
titlesize=32
markersize=32
ticklabelsize=24

fig = Figure(resolution=(1080, 1280),
    fonts = (; regular = "Arial", bold="Arial bold"),
    #fontsize=32,
    backgroundcolor = RGBf(1.0, 1.00, 1.00))

results = []
errors = []

spec = "full"

for (bidx,metric) in enumerate(binary_metrics)
    #push!(results, readdlm("meanfull$metric.csv", ','))
    push!(results, readdlm("mean$spec$metric.csv", ','))
    push!(errors, readdlm("std$spec$metric.csv", ','))
end

percentiles = 90:1:99

ufig = fig[1,1] = GridLayout()
lfig = fig[2,1] = GridLayout()
legendfig = fig[3,1] = GridLayout()

afig = ufig[1,1] = GridLayout()
bfig = ufig[1,2] = GridLayout()
cfig = lfig[1,1] = GridLayout()
dfig = lfig[1,2] = GridLayout()

figs = [afig[1,1], bfig[1,1], cfig[1,1], dfig[1,1]]
titles = ["POD ↑", "POFD ↓", "POFA ↓", "PC ↑"]
#=
for (label, layout) in zip(["(a)", "(b)", "(c)", "(d)"], [afig, bfig, cfig, dfig])
    Label(layout[1, 1, TopLeft()], label,
        fontsize = 42,
        font = :bold,
        padding = (0, 5, 5, 0),
        halign = :right)
end
=#
for (aidx,metric) in enumerate(titles)
    max = Axis(figs[aidx],
            title=titles[aidx],
            xlabel = "Quantiles",
            xlabelsize = 40,
            titlesize = 46,
            xticklabelsize = 38,
            yticklabelsize = 38,
            titlefont = :bold,
            xlabelfont = :regular,
            ylabelfont = :regular,
            xgridcolor = :transparent,
            ygridcolor = :transparent,
            xtickalign = 1.0,
            ytickalign = 1.0,
            xticksize = 10,
            yticksize = 10
            #xticksmirrored = true,
            #yticksmirrored = true
        )
    for (midx,model) in enumerate(models)
        scatterlines!(max, percentiles, results[aidx][:,midx],
            color=colors[midx],
            markersize = markersize,
            marker=markers[midx]
        )

        errorbars!(max, percentiles, results[aidx][:,midx], errors[aidx][:,midx],
            color=colors[midx],
            linewidth = 2,
            whiskerwidth = 12
        )
    end
    max.xticks = ([90, 92, 94, 96, 98], ["0.90", "0.92", "0.94", "0.96", "0.98"])
    #xlims!(0.9, 1.0)
end

models2names = Dict("LSTM"=>"LSTM",
                    "GRU" => "GRU",
                    "RNN_TANH" => "RNN",
                    "ESN" => "ESN")

labels = [models2names[mm] for mm in models]
elements = [
    [LineElement(color=colors[im], linestyle = nothing), MarkerElement(marker=ma,color=colors[im],markersize=markersize)] for (im,ma) in enumerate(markers)
]

Legend(legendfig[1,1],
    labelsize = 40,
    titlesize = 44,
    elements,
    labels,
    "Models",
    titlefont = :bold,
    orientation = :horizontal
)

fig

save("./newbm$spec.eps", fig, dpi = 300)