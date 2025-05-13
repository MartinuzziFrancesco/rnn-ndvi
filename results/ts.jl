using TimeSeries
using CairoMakie
using ColorSchemes
using DelimitedFiles
using Dates
using Statistics
using StatsBase
include(joinpath(dirname(@__FILE__), "variables.jl"))
include(joinpath(dirname(@__FILE__), "results_fun.jl"))
CairoMakie.activate!(type = "svg")

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

colors = ColorSchemes.seaborn_colorblind
time_pred = Date(2013,09,09):Day(1):Date(2020,12,31)
models = ["ESN"]
models2names = Dict("LSTM"=>"LSTM",
                        "GRU" => "GRU",
                        "RNN_TANH" => "RNN",
                        "ESN" => "ESN")

chosen_locations = [
    "CZ-Stn",
    "IT-La2",
    "DE-Hai"
]

fig = Figure()
upfig = fig[1,1] = GridLayout()
fig_legend = fig[2,1] = GridLayout()
figleft = upfig[1,1] = GridLayout()
figright = upfig[1,2] = GridLayout()

figlocs = []
for idx in 1:length(chosen_locations)
    figloc = figleft[idx,1] = GridLayout()
    push!(figlocs, figloc)
end

#figleft[length(chosen_locations)+1,1] = GridLayout()

for (idx,location) in enumerate(chosen_locations)

    if idx != length(chosen_locations)
    
        ax = Axis(figlocs[idx][1, 1],
            #title = "$location",
            #xlabel = "Years",
            ylabel = "NDVI",
            xticklabelsvisible = false
        )
    else
        ax = Axis(figlocs[idx][1, 1],
            #title = "$location",
            xlabel = "Years",
            ylabel = "NDVI",
            #xticklabelsvisible = false
        )
    end
           

    for (midx,model) in enumerate(models)
        ground_truth, prediction = model_location_data(model, location)
        ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth)
        ta_prediction = data2ta(prediction, time_pred)
        tempo = string.(timestamp(ta_gt_pred))
        lentime = length(tempo)
        
        if midx == 1
            lines!(ax, 1:lentime, values(ta_gt_pred),
                label="Ground Truth",
                color=:black,
                linewidth=3.0)
        end

        mm = models2names[model]

        lines!(ax, 1:lentime, values(ta_prediction)[:,2],
            label="$mm",
            color = colors[midx],
            linewidth=1.5)

        ax.xticks = (116:365:2670, string.(2014:1:2020))
        ax.yticks = (0.4:0.2:0.8, string.(0.4:0.2:0.8))
        ylims!(ax, 0.3, 1.0)

    end
    Box(figlocs[idx][1,2], color = :gray90)
    Label(figlocs[idx][1,2], location, rotation = pi/2, tellheight = false, fontsize=44)
    colgap!(figlocs[idx], 1, 0)
end

for (midx,model) in enumerate(models)
    location = "CZ-Stn"
    ax = Axis(figright[1, 1],
            title = "$location Focus 2018",
            xlabel = "Months",
            ylabel = "NDVI",
            #xticklabelsvisible = false
    )

    
    ground_truth, prediction = model_location_data(model, location)
    ta_gt_full, ta_gt_train, ta_gt_pred = get_ta_arrays(ground_truth)
    ta_prediction = data2ta(prediction, time_pred)
    ta_gt_pred = ta_gt_pred[Date(2018,01,01):Date(2018,12,31)]
    ta_prediction = ta_prediction[Date(2018,01,01):Date(2018,12,31)]

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

    ta_gt_pred = ta_gt_pred[Date(2018,01,01):Date(2018,12,31)]
    ta_prediction = ta_prediction[Date(2018,01,01):Date(2018,12,31)]
    
    tempo = string.(timestamp(ta_gt_pred))
    lentime = length(tempo)
    
    if midx == 1
        lines!(ax, 1:lentime, values(ta_gt_pred),
            label="Ground Truth",
            color=:black,
            linewidth=7.0)
    end

    mm = models2names[model]

    lines!(ax, 1:lentime, values(ta_prediction)[:,2],
        label="$mm",
        color = colors[midx],
        linewidth=5.0)

    ax.xticks = ([1, 91, 182, 274], ["Jan", "Apr", "Jul", "Oct"])
    ax.yticks = (0.4:0.2:0.8, string.(0.4:0.2:0.8))
    ylims!(ax, 0.3, 1.0)

    vspan!(ax, [x[1] for x in tu_idx[1]], [x[2] for x in tu_idx[1]],
        color=(:grey, 0.1))
    vlines!(ax, [x[1] for x in tu_idx[2]],
        color=(:grey, 0.1))

end




labels = [models2names[mm] for mm in models]
elements = [LineElement(
        color=colors[im], 
        linewidth=8.0
    ) for (im,ma) in enumerate(labels)]
push!(labels, "Target signal")
push!(elements, LineElement(
    color=:black, 
    linewidth=8.0
    )
)
push!(labels, "Extremes")
push!(elements, LineElement(
    color=(:grey, 0.3),
    linewidth=12.0
    )
)

Legend(fig_legend[1,1],
        labelsize = 40,
        titlesize = 44,
        elements,
        labels,
        "Legend",
        titlefont = :bold,
        orientation = :horizontal,
        nbanks = 2
)

for (label, layout) in zip(["(a)", "(b)"], [figleft, figright])
    Label(layout[1, 1, TopLeft()], label,
        fontsize = 42,
        font = :bold,
        padding = (0, 3, 3, 0),
        halign = :right)
end

fig

save("./ts.png", fig, dpi=300)