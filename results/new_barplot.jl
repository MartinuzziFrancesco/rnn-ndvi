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
function rename_accuracy(
    measures;
    needles = ["r2_score", "nrmse", "mean_absolute_percentage_error"],
    needles2names = Dict("r2_score" => L"R^2",
                         "nrmse" => "NRMSE",
                         "mean_absolute_error" => "MAPE")
)
    new_names = []
    for (midx,mm) in enumerate(measures)
        for (nidx,nn) in enumerate(needles)
            if occursin(nn, "$mm")
                push!(new_names, needles2names[nn])
            end
        end
    end
    new_names
end
function get_singleresults(
    measure,
    locations,
    models,
    samples;
    cut_season=false,
    only_extremes=false,
    season = ["March" "April" "May" "June" "July" "August" "September" "October" "November"]
)
    results = zeros(length(locations)*length(models), 4)
    
    i = 1
    for (idx,location) in enumerate(locations)
        for (midx,model) in enumerate(models)
            res_avg, res_std = results4model(
                location, model, measure, samples;
                cut_season = cut_season, only_extremes=only_extremes, season=season, mean_std = true
            )
            results[i, 1] = idx
            results[i, 2] = midx
            results[i, 3] = res_avg
            results[i, 4] = res_std
            i+=1
        end
    end
    results
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
# Left left upper figure
llupf = lupf[1,2] = GridLayout()
# Right left upper figure
rlupf = lupf[1,1] = GridLayout()
# Right upper figure
rupf = upf[2,2] = GridLayout()
# Left right upper figure
lrupf = rupf[1,1] = GridLayout()
# Right right upper figure
rrupf = rupf[1,2] = GridLayout()

Label(upf[1, 1, Top()], "Full Season", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))
Label(upf[1, 2, Top()], "Growing Season", valign = :bottom,
    font = :bold,
    fontsize=46,
    padding = (0, 0, 5, 0))

rowsize!(upf, 1, Auto(0.02))
rowgap!(upf, 10)

measures = [nrmse, smape]
needles = ["nrmse", "smape"]
needles2names = Dict("nrmse" => "NRMSE",
                     "smape" => "SMAPE")
measure_names = rename_accuracy(
    measures; needles, needles2names
)

models2names = Dict("LSTM"=>"LSTM",
                     "GRU" => "GRU",
                     "RNN_TANH" => "RNN",
                     "ESN" => "ESN")


fs_results = []
gs_results = []
for measure in measures
    fsresults = get_singleresults(
        measure, locations, models, samples;
        cut_season=false
    )
    gsresults = get_singleresults(
        measure, locations, models, samples;
        cut_season=true, season=gs
    )
    push!(gs_results, gsresults)
    push!(fs_results, fsresults)
end

for (ridx,rr) in enumerate(fs_results)
    mm = measure_names[ridx]
    if ridx == 1
        lax = Axis(lupf[1,ridx],
            yticks = (1:length(locations), locations);
            title = "$mm")
    else
        lax = Axis(lupf[1,ridx],
            yticks = (1:length(locations), locations);
            yticklabelsvisible = false,
            title = "$mm")
    end
        
    #if plot_type == "barplot"
    barplot!(lax, rr[:,1], rr[:,3],
        dodge = Int.(rr[:,2]),
        color = colors[Int.(rr[:,2])],
        direction=:x)
    #elseif plot_type == "crossbar"
    #crossbar!(lax, rr[:,1], rr[:,3],
    #    rr[:,3].+rr[:,4],
    #    rr[:,3].-rr[:,4],
    #    dodge = Int.(rr[:,2]),
    #    color = colors[Int.(rr[:,2])],
    #    show_notch=true,
    #    orientation=:horizontal)
    #end
    if mm == "NRMSE"
        xlims!(lax, 0.0, 1.1)
        lax.xticks = ([0.0, 0.3, 0.6, 0.9], ["0.0", "0.3", "0.6", "0.9"])
    else
        xlims!(lax, 0, 22)
        lax.xticks = ([0, 5, 10, 15, 20], ["0", "5", "10", "15", "20"])
    end
end

for (ridx,rr) in enumerate(gs_results)
    mm = measure_names[ridx]
    rax = Axis(rupf[1,ridx],
        yticks = (1:length(locations), locations);
        yticklabelsvisible = false,
        title = "$mm")
    #if plot_type == "barplot"
    barplot!(rax, rr[:,1], rr[:,3],
        dodge = Int.(rr[:,2]),
        color = colors[Int.(rr[:,2])],
        direction=:x)
    #elseif plot_type == "crossbar"
    #crossbar!(rax, rr[:,1], rr[:,3],
    #    rr[:,3].+rr[:,4],
    #    rr[:,3].-rr[:,4],
    #    dodge = Int.(rr[:,2]),
    #    color = colors[Int.(rr[:,2])],
    #    show_notch=true,
    #    orientation=:horizontal)
    #end
    if mm == "NRMSE"
        xlims!(rax, 0.0, 1.1)
        rax.xticks = ([0.0, 0.3, 0.6, 0.9], ["0.0", "0.3", "0.6", "0.9"])
    else
        xlims!(rax, 0, 22)
        rax.xticks = ([0, 5, 10, 15, 20], ["0", "5", "10", "15", "20"])
    end
end

labels = [models2names[mm] for mm in models ]
elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
Legend(lowf[1,1],
    labelsize = 32,
    titlesize = 35,
    elements,
    labels,
    "Models",
    titlefont = :bold,
    orientation = :horizontal)

fig
save("./f08.eps", fig, dpi=300)

#Label(fig[0, :], text = plot_title, fontsize = 38)