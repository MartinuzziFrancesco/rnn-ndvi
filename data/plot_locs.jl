using GeoMakie, CairoMakie, DelimitedFiles, ColorSchemes
CairoMakie.activate!(type = "svg")

halfpage_theme = Theme(
    colors = ColorSchemes.Dark2_3,
    Axis = (
        ticklabelsize=24,
        xticklabelsize = 40,
        yticklabelsize = 40,
        xlabelsize = 44,
        ylabelsize = 44,
        titlesize = 45,
        xgridcolor = :transparent,
        ygridcolor = :transparent,
        xtickalign = 1.0,
        ytickalign = 1.0,
        xticksmirrored = true,
        yticksmirrored = true,
        titlefont = :regular,
        xticksize = 10,
        yticksize = 10,
        xticksvisible = false,
        yticksvisible = false
    ),
    fontsize=28,
    backgroundcolor = RGBf(1.0, 1.0, 1.0),
    fonts = (; regular = "Arial"),
    resolution=(1080, 1500)
)

set_theme!(halfpage_theme)

locations = readdlm("./named_locations.txt", ',')
f_locations = readdlm("./final_locations.txt")

fig = Figure(resolution=(1080, 1280))
dest="+proj=merc"

cat = ["dbf", "enf", "mf", "dbf"]
f_cat = ["dbf", "enf", "mf"]

markers = [:circle, :diamond, :utriangle, :pentagon]
colors = ColorSchemes.seaborn_colorblind

mfig = fig[1,1] = GridLayout()
lfig = fig[2,1] = GridLayout()
llfig = lfig[1,1] = GridLayout()
rlfig = lfig[1,2] = GridLayout()


ga = GeoAxis(
    mfig[1, 1];
    dest = dest,
    lonlims=(-12, 32),
    latlims = (28, 70),
    coastlines = true,

)

xlims!(ga, -12, 32)
ylims!(ga, 30, 72)

for (idx, ft) in enumerate(cat)
    indices = findall(x->x==ft, locations[:,4])
    scatter!(Float32.(locations[indices,3]), Float32.(locations[indices,2]),
             marker=markers[idx],
             markersize = 28,
             color=:grey)
end

for (idx,ft) in enumerate(f_cat)
    f_indices = findall(x->x==ft, f_locations[:,4])
    scatter!(Float32.(f_locations[f_indices,3]), Float32.(f_locations[f_indices,2]),
             marker=markers[idx],
             markersize = 34,
             color=colors[idx])

end
hidedecorations!(ga)

labels = cat
elements = [
    MarkerElement(marker=ma,color=:grey,markersize=28) for (im,ma) in enumerate(markers)
]

Legend(llfig[1,1],
        labelsize = 40,
        titlesize = 44,
        elements,
        labels,
        "Available Forest Sites",
        titlefont = :bold,
        orientation = :horizontal
)

f_labels = f_cat
f_elements = [
    MarkerElement(marker=ma,color=colors[im],markersize=34) for (im,ma) in enumerate(markers[1:3])
]

Legend(rlfig[1,1],
        labelsize = 40,
        titlesize = 44,
        f_elements,
        f_labels,
        "Used Forest Sites",
        titlefont = :bold,
        orientation = :horizontal
)

save("locations.png", fig, dpi=300)
