include(joinpath(dirname(@__FILE__), "variables.jl"))


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

function fullres_barplot(
    #full_results,
    locations,
    measures,
    models=["LSTM", "GRU", "RNN_TANH", "ESN"],
    samples=100;
    cut_season = false,
    colors = Makie.wong_colors(),
    needles = ["nrmse", "smape"],
    needles2names = Dict("nrmse" => "NRMSE",
                         "smape" => "SMAPE"),
    models2names = Dict("LSTM"=>"LSTM",
                        "GRU" => "GRU",
                        "RNN_TANH" => "RNN",
                        "ESN" => "ESN"),
    file_name = "results_barplot_tt",
    file_ext = ".png",
    plot_type = "barplot",
    plot_title = "General",
    only_extremes = false,
    season = ["March" "April" "May" "June" "July" "August" "September" "October" "November"],
    kwargs...
)

    save_path = joinpath(dirname(@__FILE__))*"/"*file_name*plot_type

    println("Renaming accuracy measures...")
    measure_names = rename_accuracy(
        measures; needles, needles2names
    )
    @assert length(measures) == length(measure_names)

    println("Computing results...")
    full_results = []
    for measure in measures
        results = get_singleresults(
            measure, locations, models, samples;
            cut_season=cut_season, only_extremes=only_extremes, season=season
        )
        push!(full_results, results)
    end

    fig = Figure(resolution=(1380, 1080))

    println("Plotting results...")
    for (ridx,rr) in enumerate(full_results)
        mm = measure_names[ridx]
        ax = Axis(fig[1,ridx],
            yticks = (1:length(locations), locations);
            title = "$mm",
            kwargs...)
        if plot_type == "barplot"
            barplot!(ax, rr[:,1], rr[:,3],
                dodge = Int.(rr[:,2]),
                color = colors[Int.(rr[:,2])],
                direction=:x)
        elseif plot_type == "crossbar"
            crossbar!(ax, rr[:,1], rr[:,3],
                      rr[:,3].+rr[:,4],
                      rr[:,3].-rr[:,4],
                dodge = Int.(rr[:,2]),
                color = colors[Int.(rr[:,2])],
                show_notch=true,
                orientation=:horizontal)
        end
    end

    labels = [models2names[mm] for mm in models ]
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
    Legend(fig[1,length(full_results)+1],
        labelsize = 26,
        titlesize = 32,
        elements,
        labels,
        "Models")
    Label(fig[0, :], text = plot_title, fontsize = 38)
    println("Saving plot...")
    save(save_path*file_ext, fig, px_per_unit = 2)
    println("Plots saved at $save_path$file_ext")
end

function perlocation_densities(
    models,
    locations,
    acc_measure,
    samples=50,
    colors = ColorSchemes.seaborn_colorblind
)

    fig = Figure(resolution=(1080, 1620),
        fonts = (; regular = "Arial"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00))

    for (midx,model) in enumerate(models)
        for (lidx,location) in enumerate(locations)
            gt_full, prediction = model_location_data(
                model, location
            )

            ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
                gt_full
            )

            ax = Axis(fig[lidx, midx],
                #title = "$model",
                #xlabel = "Actual NDVI",
                #ylabel = "Predicted NDVI",
                #xticklabelsize = 42,
                #yticklabelsize = 42,
                #xlabelsize = 48,
                #ylabelsize = 48,
                #titlesize = 46
            )
        end
    end
    save("./densities.eps", fig, dpi = 300)
end

function perlocation_scatter(
    models,
    locations,
    samples=100,
    colors = Makie.wong_colors()
)
    fig = Figure(resolution=(1080, 5400),
        fonts = (; regular = "Arial"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00))

    for (midx,model) in enumerate(models)
        for (lidx,location) in enumerate(locations)
            gt_full, prediction = model_location_data(
                model, location
            )

            ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(
                gt_full
            )

    
            ax = Axis(fig[lidx, midx],
                title = "$model",
                #xlabel = "Actual NDVI",
                #ylabel = "Predicted NDVI",
                #xticklabelsize = 42,
                #yticklabelsize = 42,
                #xlabelsize = 48,
                #ylabelsize = 48,
                #titlesize = 46
            )
            limits!(ax, 0.35, 0.9, 0.35, 0.9)
            for i in 1:samples
                scatter!(ax, values(ta_gt_pred), prediction[:,i],
                    color = colors[midx])
            end
            x = 0.0:0.1:1.0
            lines!(ax, x, x,
                color=:grey,
                linewidth=5.0)
        end
    end
    
    save("./results.png", fig, px_per_unit = 2)
end

function hist_loc(
    location,
    metric,
    models = [
        "lstm",
        "gru",
        "rnntanh",
        "esn"
    ];
    filename = "full_results.jld2",
    colors = Makie.wong_colors(),
    kwargs...)

    fig = Figure(resolution=(720, 720),
        fonts = (; regular = "Arial"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00))
        ax = Axis(fig[1, 1],
            title = "$location $metric"
            #xlabel = "Actual NDVI",
            #ylabel = "Predicted NDVI",
            #xticklabelsize = 42,
            #yticklabelsize = 42,
            #xlabelsize = 48,
            #ylabelsize = 48,
            #titlesize = 46
        )
    fr = read_results(location; filename=filename)
    for (midx,model) in enumerate(models)
        println(model)
        rr = fr.metrics_results[model][metric]
        density!(ax, rr,
            bins=12,
            color=(colors[midx],0.4))
    end
    models2names = Dict("lstm"=>"LSTM",
        "gru" => "GRU",
        "rnntanh" => "RNN",
        "esn" => "ESN")
    labels = [models2names[mm] for mm in models ]
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
    Legend(fig[1,2],
        labelsize = 26,
        titlesize = 32,
        elements,
        labels,
        "Models")

    fig
end

function hist_full(
    locations,
    metric,
    models = [
        "LSTM",
        "GRU",
        "RNN_TANH",
        "ESN"
    ];
    filename = "full_season_extremes92.jld2",#"full_results.jld2",
    colors = ColorSchemes.seaborn_colorblind,
    kwargs...)

    fig = Figure(resolution=(720, 720),
        fonts = (; regular = "Arial"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00))
    ax = Axis(fig[1, 1],
            title = "$metric"
            #xlabel = "Actual NDVI",
            #ylabel = "Predicted NDVI",
            #xticklabelsize = 42,
            #yticklabelsize = 42,
            #xlabelsize = 48,
            #ylabelsize = 48,
            #titlesize = 46
        )
    #=
    fr = []
    for location in locations
        for model in models
            fr_tmp = read_results(location; filename=filename)
            dt_tmp = fr_tmp.metrics_results[model][metric]
            push!(fr, dt_tmp)
        end
    end
    rr = reduce(vcat, fr)
=#
    for (midx,model) in enumerate(models)
        fr = []
        for location in locations
            fr_tmp = read_results(location; filename=filename)
            dt_tmp = fr_tmp.metrics_results[model][metric]
            push!(fr, dt_tmp)
        end
        rr = reduce(vcat, fr)
        density!(ax, rr,
            bins=12,
            color=(colors[midx],0.4))
    end
    models2names = Dict("LSTM"=>"LSTM",
        "GRU" => "GRU",
        "RNN_TANH" => "RNN",
        "ESN" => "ESN")
    labels = [models2names[mm] for mm in models ]
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
    Legend(fig[1,2],
        labelsize = 26,
        titlesize = 32,
        elements,
        labels,
        "Models")

    save("./test.png", fig, dpi = 300)
end

function plot_binary_extremes(
    locations;
    models = [
        "LSTM",
        "GRU",
        "RNN_TANH",
        "ESN"
    ],
    binary_metrics = [
        "pod",
        "pofd",
        "pofa",
        "pc"
    ],
    colors = ColorSchemes.seaborn_colorblind,
    colormap=:Accent_4,
    markers = [:circle, :hexagon, :diamond, :rect],
    titlesize=32,
    markersize=32,
    ticklabelsize=24
)

    fig = Figure(resolution=(1080, 1280),
        fonts = (; regular = "Arial", bold="Arial bold"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00))
    
    results = []
    errors = []

    spec = "summer"

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
            if (model == "ESN") && (metric == "POFD ↓")
                @show errors[aidx][:,midx]
                errors[aidx][:,midx] *= 3
            elseif (model == "ESN") && (metric == "PC ↑")
                errors[aidx][:,midx] *= 3
            end

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

    

    save("./newbm$spec.eps", fig, dpi = 300)
end

scatter_theme = Theme(
    colors = ColorSchemes.seaborn_colorblind,
    colormap=:Accent_4,
    markers = [:circle, :hexagon, :diamond, :rect],
    titlesize=32,
    markersize=24,
    ticklabelsize=24,
    xlabel = "Percentiles",
    xlabelsize = 28,
    resolution=(1080, 500),
    fonts = (; regular = "Arial", bold="Arial bold"),
    #fontsize=32,
    backgroundcolor = RGBf(1.0, 1.00, 1.00),
    titlefont = :bold,
    xlabelfont = :regular,
    ylabelfont = :regular
)

function plot_allbinary_extremes(
    locations,
    ex1,
    ex2;
    models = [
        "LSTM",
        "GRU",
        "RNN_TANH",
        "ESN"
    ],
    binary_metrics = [
        "H",
        "F",
        "FAR",
        "PC"
    ],
    scatter_theme = Theme(
        colors = ColorSchemes.seaborn_colorblind,
        colormap=:Accent_4,
        markers = [:circle, :hexagon, :diamond, :rect],
        titlesize=32,
        markersize=24,
        ticklabelsize=24,
        xlabel = "Percentiles",
        xlabelsize = 28,
        resolution=(1080, 500),
        fonts = (; regular = "Arial", bold="Arial bold"),
        #fontsize=32,
        backgroundcolor = RGBf(1.0, 1.00, 1.00),
        titlefont = :bold,
        xlabelfont = :regular,
        ylabelfont = :regular
    )
)

    set_theme!(scatter_theme)

    fig = Figure()
    
    results1 = zeros(10, 4, 4)
    results2 = zeros(10, 4, 4)
    for location in locations
        for (midx,model) in enumerate(models)
            results1[:,:,midx] .+= ex1[location].binaries_mean[model]
            results2[:,:,midx] .+= ex2[location].binaries_mean[model]
        end
    end
    results1 = results1./length(locations)
    results2 = results2./length(locations)

    percentiles = 90:1:99

    lfig = fig[1,1] = GridLayout()
    rfig = fig[2,1] = GridLayout()
    ll = fig[1,2] = GridLayout()

    titles = ["H ↑", "F ↓","FAR ↓", "PC ↑"]

    for i in 1:4
        for (midx,model) in enumerate(models)
            ax = Axis(lfig[1,i], title = titles[i])
            scatterlines!(ax, percentiles, results1[:,i,midx],
                color=scatter_theme.colors[][midx],
                markersize = scatter_theme.markersize[],
                marker=scatter_theme.markers[][midx]
            )
        end
    end

    for i in 1:4
        for (midx,model) in enumerate(models)
            ax = Axis(rfig[1,i], title = titles[i])
            scatterlines!(ax, percentiles, results2[:,i,midx],
                color=scatter_theme.colors[][midx],
                markersize = scatter_theme.markersize[],
                marker=scatter_theme.markers[][midx]
            )
        end
    end

    models2names = Dict("LSTM"=>"LSTM",
                        "GRU" => "GRU",
                        "RNN_TANH" => "RNN",
                        "ESN" => "ESN")

    labels = [models2names[mm] for mm in models]
    elements = [
        [LineElement(color=scatter_theme.colors[][im], linestyle = nothing), 
        MarkerElement(marker=ma,color=scatter_theme.colors[][im],markersize=scatter_theme.markersize[])] 
        for (im,ma) in enumerate(scatter_theme.markers[])
    ]

    Legend(ll[1,1],
        labelsize = 26,
        titlesize = scatter_theme.titlesize[],
        elements,
        labels,
        "Models",
        titlefont = :bold
        )

    save("./bmfull.eps", fig, dpi = 300)
end



function plot_fullmetric_extremes(
    locations;
    models = [
        "LSTM",
        "GRU",
        "RNN_TANH",
        "ESN"
    ],
    binary_metrics = [
        "pod",
        "pofd",
        "pofa",
        "pc"
    ],
    colors = ColorSchemes.seaborn_colorblind,
    colormap=:Accent_4,
    markers = [:circle, :hexagon, :diamond, :rect],
    titlesize=32,
    markersize=32,
    ticklabelsize=24
)

    fig = Figure(resolution=(1500, 1500),
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
    lfig = fig[1,2] = GridLayout()
    legendfig = fig[1,3] = GridLayout()

    afig = ufig[1,1] = GridLayout()
    bfig = ufig[2,1] = GridLayout()
    cfig = lfig[1,1] = GridLayout()
    dfig = lfig[2,1] = GridLayout()

    figs = [afig, bfig, cfig, dfig]
    titles = ["POD ↑", "POFD ↓", "POFA ↓", "PC ↑"]

    for (aidx,metric) in enumerate(titles)
        max = Axis(figs[aidx][1,1],
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
            @show metric
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
        orientation = :vertical
    )

    for (label, layout) in zip(["A", "B", "C", "D"], figs)
        Label(layout[1, 1, TopLeft()], label,
            fontsize = 38,
            font = :bold,
            padding = (0, 5, 5, 0),
            halign = :right)
    end

    save("./newbm$spec.eps", fig, dpi = 300)
end