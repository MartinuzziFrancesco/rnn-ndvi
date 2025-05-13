using Dates
using EarthDataLab
using NetCDF
using PyCall
using StatsBase
using DelimitedFiles
sc = pyimport("scipy")

function check_location(
    location;
    dir = "/net/data/Fluxnet/FLUXNET2020-ICOS-WarmWinter/",
    fileend = "_FLUXNET2015_ERAI_DD_1989-2020_beta-3.csv"
)

    filename = dir*"FLX_"*location*fileend
    isfile(filename) ? println(location, " Exists") : println(location, " Does not exists")
end

for location in cover80_locations
    check_location(location)
end


# Get lat lon from modis file for specific location
function get_latlon(filename)
    latlon_string = ncgetatt(filename, "Global", "site_coordinates")
    latlon_vec = split(latlon_string)
    lat = parse(Float64, chop(latlon_vec[1]))
    lon = parse(Float64, latlon_vec[2])
    lat, lon
end

function get_eobs_variable(
    var,
    location;
    modis_dir = "/net/data/FluxnetEO/MODIS/",
    eobs_dir = "/net/scratch/fmartinuzzi/E-OBS/",
    times = (Date(2000,01,01), Date(2021,01,01)),
    window = 9,
    poly_deg = 2
)

    # Specific MODIS file for the location
    filename_modis = modis_dir * location * ".modis.subpixel.nc"
    # Lat and lon of the location from MODIS file 
    lat, lon = get_latlon(filename_modis)
    # Read full eobs data for chosen variable
    cc = Cube(eobs_dir*var*"_ens_mean_0.1deg_reg_v26.0e.nc")
    # Cut data to get location and time consistency
    cc_data = Float32.(subsetcube(cc, lon=lon, lat=lat, time=times)[:,1])
    # Normalize data
    scaled_data = standardize(ZScoreTransform, reduce(vcat, cc_data))
    # Filter data, not for precipitation
    if var != "rr"
        return sc.signal.savgol_filter(scaled_data, window, poly_deg)
    else
        return scaled_data
    end

end

function find_missing(
    var,
    location;
    modis_dir = "/net/data/FluxnetEO/MODIS/",
    eobs_dir = "/net/scratch/fmartinuzzi/E-OBS/",
    times = (Date(2000,01,01), Date(2021,01,01))
)

    filename_modis = modis_dir * location * ".modis.subpixel.nc"
    lat, lon = get_latlon(filename_modis)
    var = Cube(eobs_dir*var*"_ens_mean_0.1deg_reg_v26.0e.nc")
    var_data = subsetcube(var, lon=lon, lat=lat, time=times)[:,1]
    mm = length(findall(x->x==1, ismissing.(var_data)))
    mm
end

function resample_era5(
    var,
    location;
    modis_dir = "/net/data/FluxnetEO/MODIS/",
    era5_dir = "/net/projects/deep_esdl/data/ERA5/",
    times = (Date(2000,01,01), Date(2021,01,01)),
    hours = 0:1:23,
    year = "2020",
    month = "02"
)

    filename_era5 = era5_dir*"ERA5-$year-$month-XAIDA.nc"
    filename_modis = modis_dir * location * ".modis.subpixel.nc"
    lat, lon = get_latlon(filename_modis)
    c = Cube(filename_era5)
    n_year = parse(Int64, year)
    n_month = parse(Int64, month)
    date = Date(n_year, n_month)

    for dd in Dates.daysinmonth(date)
        tts = (DateTime(n_year, n_month, dd), DateTime(n_year, n_month, dd+1))
        cube_data = subsetcube(c, lon=lon, lat=lat, time=tts, var="d2m")
    end
    
end

# Locations 
cover80_locations = ["IT-Lav",
                     "SE-Nor",
                     "DE-Wet",
                     "CZ-BK1",
                     #"NL-Loo",
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
                     #"SE-Svb",
                     "DE-Hai",
                     "CZ-Lnz"
]

# Variables 
meteo_vars = ["tg", "tn", "tx", "pp", "qq", "rr"]

# Data directories
modis_dir = "/net/data/FluxnetEO/MODIS/"
eobs_dir = "/net/scratch/fmartinuzzi/E-OBS/"
era5_dir = "/net/projects/deep_esdl/data/ERA5/"
icosww_dir = "/net/data/Fluxnet/FLUXNET2020-ICOS-WarmWinter"
data_dir = joinpath(dirname(@__FILE__), "..", "data/")

filename_era5 = era5_dir*"ERA5-2020-02-XAIDA.nc"

# Timeframe
start_date = Date(2000,01,01)
stop_date = Date(2021,01,01)
times = (start_date, stop_date)

# savgol params
window = 9
poly_deg = 2

# Cycle through locations and variables
for location in cover80_locations
    println(location)
    # Create matrix container fo meteo data
    meteo_data = zeros(Float32, length(start_date:Day(1):stop_date)-1, length(meteo_vars))
    for (idx,var) in enumerate(meteo_vars)
        var_data = get_eobs_variable(
            var, location;
            modis_dir=modis_dir,
            eobs_dir=eobs_dir,
            times=times,
            window=window,
            poly_deg=poly_deg
            )
        meteo_data[:,idx] = var_data
    end
    isdir(data_dir*"$location") ? nothing : mkdir(data_dir*"$location")
    open(data_dir*"/$location/norm_sg$window$poly_deg$location.csv", "w") do io
        writedlm(io, meteo_data, ',')
    end
end