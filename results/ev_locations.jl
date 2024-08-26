using CairoMakie, DelimitedFiles, Dates, TimeSeries, StatsBase, ColorSchemes, JLD2

include(joinpath(dirname(@__FILE__), "results_fun.jl"))
include(joinpath(dirname(@__FILE__), "variables.jl"))
include(joinpath(dirname(@__FILE__), "metrics.jl"))
include(joinpath(dirname(@__FILE__), "binary_events.jl"))
models = ["LSTM", "GRU", "RNN_TANH", "ESN"]

fs = ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
gs = ["May" "June" "July" "August" "September"]
seasons = [gs, fs]
samples = 100

function get_singleresults(
    locations,
    models,
    name = "full",
    perc = 1
)
    results = zeros(length(locations)*length(models), 4)
    metric = fscore
    
    
    i = 1
    for (idx,location) in enumerate(locations)
        for (midx,model) in enumerate(models)
            mean_fscore = readdlm("./mean$name$metric$model.csv", ',')
            std_fscore = readdlm("./std$name$metric$model.csv", ',')
            res_avg, res_std = mean_fscore[perc, idx], std_fscore[perc, idx]
            results[i, 1] = idx
            results[i, 2] = midx
            results[i, 3] = res_avg
            results[i, 4] = res_std
            i+=1
        end
    end
    results
end

function colorscheme_alpha(cscheme::ColorScheme, alpha::T = 0.5; 
    ncolors=12) where T<:Real
return ColorScheme([ColorSchemes.RGBA(get(cscheme, k), alpha) for k in range(0, 1, length=ncolors)])
end

fullpage_theme = Theme(
    colors = ColorSchemes.Dark2_3,
    Axis = (
        ticklabelsize=32,
        xticklabelsize = 38,
        yticklabelsize = 35,
        xlabelsize = 42,
        ylabelsize = 42,
        titlesize = 42,
        xgridcolor = :transparent,
        ygridcolor = :transparent,
        xtickalign = 1.0,
        ytickalign = 1.0,
        xticksmirrored = true,
        #yticksmirrored = true,
        titlefont = :regular,
        xticksize = 14,
        yticksize = 14,
        yticksvisible=false,
        xtickwidth = 3,
        ytickwidth = 3,
        spinewidth = 3,
    ),
    fontsize=34,
    backgroundcolor = RGBf(1.0, 1.0, 1.0),
    fonts = (; regular = "Arial"),
    resolution=(1200, 1700)
)
colors = ColorSchemes.seaborn_colorblind
set_theme!(fullpage_theme)

fig = Figure()
### Split figure
#tf = fig[1,1] = GridLayout()
# Upper figure
upf = fig[1,1] = GridLayout()
# Lower figure
lowf = fig[2,1] = GridLayout()
# Left upper figure
lupf = upf[2,1] = GridLayout()
# Right upper figure
rupf = upf[2,2] = GridLayout()


Label(upf[1, 1, Top()], "Full Season", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))
Label(upf[1, 2, Top()], "Summer", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))

rowsize!(upf, 1, Auto(0.02))
rowgap!(upf, 10)

fig

models2names = Dict("LSTM"=>"LSTM",
                     "GRU" => "GRU",
                     "RNN_TANH" => "RNN",
                     "ESN" => "ESN")


lax = Axis(lupf[1,1],
    yticks = (1:length(locations), locations);
    title = "F1 score")
rax = Axis(rupf[1,1],
    yticks = (1:length(locations), locations);
    yticklabelsvisible = false,
    title = "F1 score")
for i in 1:10
    fsresults = get_singleresults(locations, models, "full", i)
    gsresults = get_singleresults(locations, models, "summer", i)

    rr = fsresults
    gr = gsresults

    #if plot_type == "barplot"
    barplot!(lax, rr[:,1], rr[:,3],
        dodge = Int.(rr[:,2]),
        color = colorscheme_alpha(ColorSchemes.seaborn_colorblind, 1/i, ncolors=10)[Int.(rr[:,2])],#colors[Int.(rr[:,2])],
        direction=:x,
        fillto=rr[:,3].-0.01)

    xlims!(lax, 0.0, 0.45)
    lax.xticks = ([0.0, 0.1, 0.2, 0.3, 0.4], ["0.0", "0.1", "0.2", "0.3", "0.4"])

    barplot!(rax, gr[:,1], gr[:,3],
        dodge = Int.(gr[:,2]),
        color = colorscheme_alpha(ColorSchemes.seaborn_colorblind, 1/i, ncolors=10)[Int.(rr[:,2])],#colors[Int.(gr[:,2])],
        direction=:x,
        fillto=gr[:,3].-0.01)
    xlims!(rax, 0.0, 0.45)
    rax.xticks = ([0.0, 0.1, 0.2, 0.3, 0.4], ["0.0", "0.1", "0.2", "0.3", "0.4"])

end

fig

labels = [models2names[mm] for mm in models ]
elements = [PolyElement(polycolor = ColorSchemes.seaborn_colorblind[i]) for i in 1:length(labels)]
labels_q = ["90", "91", "92", "93", "94", "95", "96", "97", "98", "99"]
elements_q = [PolyElement(polycolor = colorscheme_alpha(ColorSchemes.grays, 1/i, ncolors=10)[0.1]) for i in 1:10]

Legend(lowf[1,1],
    labelsize = 32,
    titlesize = 35,
    [elements, elements_q],
    [labels, labels_q],
    ["Models", "Quantiles"],
    titlefont = :bold,
    orientation = :horizontal,
    nbanks=2,
    titleposition=:left)

fig
save("./fA2.eps", fig, dpi=300)

#Label(fig[0, :], text = plot_title, fontsize = 38)