using EarthDataLab
using PyCall
using StatsBase
using DelimitedFiles
sc = pyimport("scipy")

# Locations 
cover80_locations = ["IT-Lav",
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
                     "FR-Pue",
                     "DE-Lkb",
                     "FI-Let",
                     "IT-La2",
                     "IT-Ren",
                     "SE-Svb",
                     "DE-Hai",
                     "CZ-Lnz"
]

# Data directory
modis_dir = "/net/data/FluxnetEO/MODIS/"

# savgol params
window = 7
poly_deg = 4

for location in cover80_locations
      filename_modis = modis_dir * location * ".modis.subpixel.nc"
      full_modis = Cube(filename_modis)
      modis_ndvi = subsetcube(full_modis, variable="NDVI")
      mean_modis = mapslices(mean, modis_ndvi, dims=("Lon","Lat"))[:,1]
      filtered_modis = sc.signal.savgol_filter(mean_modis, window, poly_deg)
      isdir("./data/$location") ? nothing : mkdir("./data/$location")
      open("./data//$location/mean_ndvi_sg$window$poly_deg$location.csv", "w") do io
        writedlm(io, filtered_modis, ',')
      end
end