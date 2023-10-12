using Distributed
@everywhere using Pkg
Pkg.activate(".")
using DelimitedFiles, StatsBase, Dates, LinearAlgebra, ReservoirComputing
@everywhere Pkg.activate(".")
@everywhere using DelimitedFiles, StatsBase, Dates, LinearAlgebra, ReservoirComputing

@everywhere function do_esn(res_size,
    res_radius,
    leaky_coeff,
    ridge_coeff,
    res_sparsity,
    features_train,
    labels_train,
    features_test,
    labels_test;
    washout = 1000
)
    input_scaling = 1.0f-1
    input_builder = DenseLayer(input_scaling)
    res_sparsity = res_sparsity
    res_builder = RandSparseReservoir(res_size, res_radius, res_sparsity)
    b = zeros(Float32, res_size)

    driver = ReservoirComputing.RNN(leaky_coefficient=leaky_coeff,
             activation_function=tanh)#tanh
    
    esn = ESN(features_train;
        reservoir = res_builder,
        input_layer = input_builder,
        bias = b,
        reservoir_driver = driver,
        washout = washout,
        states_type = PaddedExtendedStates(),
        nla_type = NLADefault())

    training_method = StandardRidge(ridge_coeff)
    output_layer = train(esn, labels_train, training_method)
    output = esn(Predictive(features_test), output_layer)
    error = round(rmsd(output, labels_test); digits=6)
    #error = round(mean([rmsd(output[i,:], labels_test[i,:]) for i in 1:2]); digits=6)
    output, error
end

locations = ["IT-Lav",
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



#for location in locations

@everywhere function mainf(location;
    data_path = "/net/home/fmartinuzzi/rnn-ndvi/",
    sizes = 600:300:1200,
    radiuss = collect(0.9:0.05:1.5),
    leaky_coeffs = collect(0.5:0.05:1.0),
    ridge_coeffs = [1.0f-2, 1.0f-3, 1.0f-4, 1.0f-5],
    res_sparsitys = 0.01:0.01:0.1,

    start_date = Date(2000,01,01),
    stop_date = Date(2020,12,30),
    time = collect(start_date:Day(1):stop_date),
    train_len = 5000,

    samples=100,
    washout=1000
)
    println(location)
    features = Matrix(readdlm(data_path*"data/$location/norm_sg92$location.csv", ',', Float32)')
    labels = Matrix(readdlm(data_path*"data/$location/mean_ndvi_sg74$location.csv", ',', Float32)')

    features_train = features[:,1:train_len]
    labels_train = reduce(hcat, labels[washout+1:train_len])
    #labels_train = labels[:,1:train_len]
    features_test = features[:,train_len+1:end]
    labels_test = reduce(hcat, labels[train_len+1:end])
    #labels_test = labels[:,train_len+1:end]

    for i in sizes
        println(location, i)
        for j in radiuss
            for k in leaky_coeffs
                for l in ridge_coeffs
                    for c in res_sparsitys
                        o, e = do_esn(i, j, k, l, c,
                            features_train, labels_train, features_test, labels_test
                        )
                        println(location, e)
                        isdir(data_path*"results/$location") ? nothing : mkdir(data_path*"results/$location")
                        #isfile(data_path*"results/$location/esn_hyperparams$location.txt") ? rm(data_path*"results/$location/esn_hyperparams$location.txt") : nothing
                        open(data_path*"results/$location/params_ESN$location.csv", "a") do io
                            writedlm(io, [i j k l c e], ',')
                        end
                        GC.gc()
                    end
                end
            end
        end
    end

end

@everywhere function othermainf(location;
    data_path = "/net/home/fmartinuzzi/rnn-ndvi/",
    sizes = 600:300:1200,
    radiuss = collect(0.9:0.05:1.5),
    leaky_coeffs = collect(0.5:0.05:1.0),
    ridge_coeffs = [1.0f-2, 1.0f-3, 1.0f-4, 1.0f-5],
    res_sparsitys = 0.01:0.01:0.1,

    start_date = Date(2000,01,01),
    stop_date = Date(2020,12,30),
    time = collect(start_date:Day(1):stop_date),
    train_len = 5000,

    samples=100,
    washout=1000
)

    println(location)
    features = Matrix(readdlm(data_path*"data/$location/norm_sg92$location.csv", ',', Float32)')
    labels = Matrix(readdlm(data_path*"data/$location/mean_ndvi_sg74$location.csv", ',', Float32)')

    features_train = features[:,1:train_len]
    labels_train = reduce(hcat, labels[washout+1:train_len])
    #labels_train = labels[:,1:train_len]
    features_test = features[:,train_len+1:end]
    labels_test = reduce(hcat, labels[train_len+1:end])
    #labels_test = labels[:,train_len+1:end]

    hyper_results = readdlm(data_path*"results/$location/params_ESN$location.csv", ',',Float32)
    ordered_accuracy = sort(hyper_results[:,5])

    results = zeros(size(labels_test, 2), samples)
    println("start loop")
    for i in 1:samples
        print(i)
        #global output, labels_test
        idx = findall(x->x==ordered_accuracy[1], hyper_results)[1][1]
        rsize, rradius, leaky, regr, spar  = hyper_results[idx,1:5]
        output, error = do_esn(Int64(rsize), rradius, leaky, regr, spar,
            features_train, labels_train, features_test, labels_test)
        results[:,i] = output
    end
    println("end loop")

    println("save results")
    open(data_path*"results/$location/ESN$samples$location.csv", "w") do io
        writedlm(io, results, ',')
    end

    GC.gc()
end

#pmap(x -> mainf(x), locations)
pmap(x -> othermainf(x), locations)