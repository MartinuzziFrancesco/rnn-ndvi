using Dates
using EarthDataLab
using Measures
using NetCDF
using Plots
using PyCall
using StatsBase
using ReservoirComputing
#include(joinpath(dirname(@__DIR__), "preprocessing", "dist.jl"))
sc = pyimport("scipy")
skl = pyimport("sklearn.metrics")
pr = pyimport("sklearn.preprocessing")


function do_esn(res_size, res_radius, leaky_coeff, ridge_coeff)
    input_scaling = 1.0f-1
    input_builder = WeightedLayer(input_scaling)
    res_sparsity = 0.05
    res_builder = RandSparseReservoir(res_size, res_radius, res_sparsity)
    b = zeros(Float32, res_size)

    driver = ReservoirComputing.RNN(leaky_coefficient=leaky_coeff,
             activation_function=sigmoid)#tanh
    
    esn = ESN(features_train;
        washout = washout,
        reservoir = res_builder,
        input_layer = input_builder,
        bias = b,
        reservoir_driver = driver,
        states_type = PaddedExtendedStates(),
        nla_type = NLAT2())

    training_method = StandardRidge(ridge_coeff)
    output_layer = train(esn, labels_train, training_method)
    x, output = esn(Predictive(features_test), output_layer)

    #error = skl.mean_squared_error(labels_test, output)#round(rmsd(labels_test, output); digits=4)
    #rsquare = round(skl.r2_score(labels_test', output'); digits=4)
    #println(error, rsquare)
    error = round(rmsd(output, labels_test); digits=6)
    println(error)
    esn, output
end


# Read data
modis_dir = "/net/data/FluxnetEO/MODIS/"
location = "CZ-Stn"
#location = "DE-Lnf"

# temp
tg = Cube("/net/scratch/fmartinuzzi/E-OBS/tg_ens_mean_0.1deg_reg_v26.0e.nc")
# precipitation #not enough
#rr = Cube("/net/scratch/fmartinuzzi/E-OBS/rr_ens_mean_0.1deg_reg_v26.0e.nc")
#sea level pressure #not enough
pp = Cube("/net/scratch/fmartinuzzi/E-OBS/pp_ens_mean_0.1deg_reg_v26.0e.nc")
# mean global radiation
qq = Cube("/net/scratch/fmartinuzzi/E-OBS/qq_ens_mean_0.1deg_reg_v26.0e.nc")



filename_modis = modis_dir * location * ".modis.subpixel.nc"
cut_modis, mean_modis = average_modisdata(filename_modis, 5000)
labels = sc.signal.savgol_filter(mean_modis[:,1], 7, 4)
labels = Float32.(reduce(hcat, labels))[1:end-1]
#scaled_ndvi = standardize(ZScoreTransform, reduce(vcat, labels))

lat, lon = get_latlong(filename_modis)
start_date = Date(2000,01,01) #start_date = Date(2015,01,01)
stop_date = Date(2021,01,01)
times = (start_date, stop_date)

tg_cut = subsetcube(tg, lon=lon, lat=lat, time=times)[:,1]
scaled_tg = standardize(ZScoreTransform, reduce(vcat, tg_cut))
final_tg = sc.signal.savgol_filter(scaled_tg, 9, 2)

pp_cut = subsetcube(pp, lon=lon, lat=lat, time=times)[:,1]
scaled_pp = standardize(ZScoreTransform, reduce(vcat, pp_cut))
final_pp = sc.signal.savgol_filter(scaled_pp, 9, 2)

qq_cut = subsetcube(qq, lon=lon, lat=lat, time=times)[:,1]
scaled_qq = standardize(ZScoreTransform, reduce(vcat, Float32.(qq_cut)))
final_qq = sc.signal.savgol_filter(scaled_qq, 9, 2)

rr_cut = subsetcube(rr, lon=lon, lat=lat, time=times)[:,1]
scaled_rr = standardize(ZScoreTransform, reduce(vcat, Float32.(rr_cut)))
final_rr = sc.signal.savgol_filter(scaled_rr, 9, 2)

spi_tt = readdlm("./spi_DE-Har.csv", ',', Float32)[:,2:end]

features = vcat(spi_tt', final_qq[1:end-1]', final_pp[1:end-1]', final_tg[1:end-1]')[:,729:end]
#features = vcat(final_qq', final_pp', final_tg')
train_len = 5000
washout = 900

features_train = features[:,1:train_len]
features_test = features[:,train_len+1:end]

labels_train = reduce(hcat, labels[1+washout:train_len])
labels_test = reduce(hcat, labels[train_len+1:end])
esn, output = do_esn(600, 1.0, 1.0, 1.0f-2)
#plot(esn.states', legend=false, margin=14mm);savefig("test.png")

#output = do_esn(1192, 1.1, 1.0, 1.0f-6)
plot([output' labels_test']); savefig("test.png")

meanx = plot(size=(1920, 1080),
             legend=false,
             plot_title="$location",
             margin = 14mm,
             plot_titlefontsize=32,
             tickfontsize=21,
             yrange=(0.3,0.95),
             xaxis=false);
years = 2005:1:2013

for _year in years
    start_date = Date(_year,01,01)
    stop_date = Date(_year+1,01,01)
    times = (start_date, stop_date)
    ndvi_mean = subsetcube(mean_modis, time=times)
    plot!(meanx, sc.signal.savgol_filter(ndvi_mean[:,1], 7, 4),
              label="mean smoothed",
              color = :grey,
              linewidth=2);
end

plot!(meanx, output[end-730-365:end-730],
                     label="pred",
                     color = :red,
                     linewidth=4);

plot!(meanx, subsetcube(mean_modis, time=(Date(2018,01,01), Date(2019,01,01)))[:,1,1],
      color=:black,
      linewidth=4);

savefig(meanx, "res.png")


#plot(scaled_ndvi[1:end-30], scaled_ndvi[31:end], linewidth=0.1, color=:black, legend=false, figsize=(1920, 1920), margin = 14mm)
#plot!(scaled_ndvi[end-730-365:end-730], scaled_ndvi[end-700-365:end-700], linewidth=0.7, color=:red)
#savefig("test.png")

files = readdir()
nc_files = filter(endswith(".nc"),files)
for (i,file) in enumerate(nc_files)
    name = loc[1,i]
    mv(file,"$name.nc")
end

for i in 1:size(loc, 2)
    locations[i,:] = Array{Float32}(loc[2:3,i])
end