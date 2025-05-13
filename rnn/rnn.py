#packages imports
import torch
import datetime
import os
import sys
import torch.optim as optim
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

#from sklearn.model_selection import train_test_split
#from sklearn.preprocessing import StandardScaler
#from scipy.signal import savgol_filter
#from torch.utils.data import TensorDataset, DataLoader
from torch import nn
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GridSearchCV
from sklearn.model_selection import TimeSeriesSplit
from skorch import NeuralNetRegressor
from skorch.callbacks import EarlyStopping
from skorch.dataset import ValidSplit

#imports from files
from _data import get_dataloader, get_data, _split_data
from model import RNNModel


# torch.cuda.is_available() checks and returns a Boolean True if a GPU is available, else it'll return False
is_cuda = torch.cuda.is_available()

# If we have a GPU available, we'll set our device to GPU. We'll use this device variable later in our code.
if is_cuda:
    device = torch.device("cuda")
    print("GPU is available")
else:
    device = torch.device("cpu")
    print("GPU not available, CPU used")

rnn_model = 'GRU' #'GRU', 'RNN_TANH'
cv = ValidSplit(TimeSeriesSplit(n_splits=5, test_size=900))

#device = torch.device("cpu")

batch_size = 128
net = NeuralNetRegressor(
    module=RNNModel,
    criterion = nn.MSELoss,
    optimizer= optim.Adam,
    max_epochs=500,
    batch_size=batch_size,
    device=device,
    module__device=device,
    module__rnn_type=rnn_model,
    module__input_dim=6,
    module__hidden_dim=32,
    module__num_layers=2,
    module__output_dim=1,
    module__dropout=0.1,
    lr = 0.01,
    train_split=None,
    verbose=0
    #callbacks=[EarlyStopping(patience=50)]
)

#data_path = "/net/home/fmartinuzzi/projects/data_exploration/data/"

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

params = {
    'lr': [1e-3, 1e-4, 1e-5],
    'module__hidden_dim': [32, 64, 128],
    'module__num_layers': [2, 3, 4],
    'module__dropout': [0.1, 0.2, 0.3, 0.4],
    'max_epochs': [150, 200, 250]
}


lstm_gs = GridSearchCV(
    net,
    params,
    refit=False,
    cv=TimeSeriesSplit(n_splits=5, test_size=900),
    scoring='neg_mean_squared_error',
    verbose=1,
    n_jobs=2
)
original_stdout = sys.stdout
data_path="/home/francesco/Documents/rnn-ndvi/data/"
results_path = "/home/francesco/Documents/rnn-ndvi/results/"

samples = 100

for location in cover80_locations:
    print(location)
    # get data
    features, labels = get_data(location)
    features_train, features_test, labels_train, labels_test = _split_data(features, labels)
    # grid search
    lstm_gs.fit(features_train, labels_train)
    if not os.path.exists(results_path+location):
        os.makedirs(results_path+location)

    with open(results_path+location+"/params_"+rnn_model+".txt", 'w') as f:
        sys.stdout = f
        print("best params: {}".format(lstm_gs.best_params_))
        f.close()
        sys.stdout = original_stdout
    
    # run best params
    print("end grid search")
    net = NeuralNetRegressor(
        module=RNNModel,
        criterion = nn.MSELoss,
        optimizer= optim.Adam,
        max_epochs=500,
        batch_size=batch_size,
        device=device,
        module__device=device,
        module__rnn_type=rnn_model,
        module__input_dim=features_train.shape[1],
        module__hidden_dim=lstm_gs.best_params_['module__hidden_dim'],
        module__num_layers=lstm_gs.best_params_['module__num_layers'],
        module__output_dim=1,
        module__dropout=lstm_gs.best_params_['module__dropout'],
        lr = lstm_gs.best_params_['lr'],
        train_split=cv,
        verbose=0,
        callbacks=[EarlyStopping(patience=50)]
    )
    #{'lr': 0.01, 'max_epochs': 75, 'module__dropout': 0.1, 'module__hidden_dim': 32, 'module__num_layers': 2}
    # save data
    

    print("running results")
    results = np.zeros((features_test.shape[0], samples))
    for i in range(samples):
        net.initialize()
        net.fit(features_train, labels_train)
        output = net.predict(features_test)
        results[:,i] = np.squeeze(output)
    np.savetxt(results_path+location+"/"+rnn_model+str(samples)+str(location)+".csv", results, delimiter=",")
