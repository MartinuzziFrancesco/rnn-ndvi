# Learning Extreme Vegetation Response to Climate Forcing: A Comparison of Recurrent Neural Network Architectures

> [!WARNING]
> This is a research repository, the code contained in here is provided as is.

> [!IMPORTANT]
> The paper is available on [EGUSphere](https://egusphere.copernicus.org/preprints/2023/egusphere-2023-2368/)

This repository contains the scripts to reproduce the results of the paper: Learning Extreme Vegetation Response to Climate Forcing: A Comparison of Recurrent Neural Network Architectures. This readme provides a brief overview of the contents of the repository. If you need more detailed instructions please contact me at martinuzzi@informatik.uni-leipzig.de.

Folder Structure:

  - data: Contains scripts related to data processing.
  - results: Contains scripts associated with results analysis and plotting.
  - esn: Houses the scripts for Echo State Network (ESN) results.
  - rnn: Consists of the scripts for Recurrent Neural Network (RNN) results.
  - preprocessing: Scripts dedicated to preprocessing the meteorological and NDVI data.

## How to Use:

1. Preprocessing:

    Meteo Data: Refer to the meteo_preproc.jl script.
    NDVI Data: Refer to the ndvi_preproc.jl script.

2. Model Training & Testing:

    For RNNs: Run rnn.py. Before running, make sure to manually set the desired model (Options: RNNTANH, GRU, LSTM) within the script.

    For ESNs: Execute the general_script.jl script.

3. Result Analysis:

Navigate to the results folder.

  - For generating plots that appera in the paper: Use ec.jl, ev.jl, and ts.jl.
  - For data exploration and data analysis: Check results_fun.jl and plots_fun.jl which contain various useful functions.
  - Variable Definitions: Refer to variables.jl.
  - Location Information: Available in locations.jl.

## Dependencies:

Each folder has a Project.toml file listing the Julia packages required for the scripts in that specific folder. For the Python RNNs, they are dependent on Skorch, which is built on top of Pytorch.
Additional Notes:

   - The data folder does not contain actual data but has scripts like plot_locs.jl that might be useful for data exploration.
   - The results folder has a variety of scripts, including those dedicated to plotting figures used in the paper and scripts for exploratory analysis.
   - Make sure you have all dependencies installed before running the scripts. Always follow the instructions in each script or module for any specific details or settings.

## Contributions:

Feel free to fork this repository, raise issues, or submit pull requests if you find any discrepancies or have suggestions for improvement.

Thank you for your interest in our research! If you have questions or need further clarification on any aspect, please contact us (martinuzzi@informatik.uni-leipzig.de) or raise an issue in the repository.
