import torch

from torch import nn

class RNNModel(nn.Module):
    def __init__(self, rnn_type, input_dim, hidden_dim, num_layers, output_dim, dropout, device='cuda'):
        super(RNNModel, self).__init__()
        # Assign attributes
        self.drop = nn.Dropout(dropout)
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        self.rnn_type = rnn_type
        self.device = device
        self.hidden = self.init_hidden()

        # Define RNN
        if rnn_type in ['LSTM', 'GRU']:
            self.rnn = getattr(nn, rnn_type)(input_dim, hidden_dim, num_layers, dropout=dropout)
        else:
            try:
                nonlinearity = {'RNN_TANH': 'tanh', 'RNN_RELU': 'relu'}[rnn_type]
            except KeyError:
                raise ValueError( """An invalid option for `--model` was supplied,
                                 options are ['LSTM', 'GRU', 'RNN_TANH' or 'RNN_RELU']""")
            self.rnn = nn.RNN(input_dim, hidden_dim, num_layers, nonlinearity=nonlinearity, dropout=dropout)
        
        # Fully connected layer for final readout
        self.fc = nn.Linear(hidden_dim, output_dim)
        self.init_rnn_weights(self.rnn, self.num_layers)
        self.init_linear_weights(self.fc)

    def forward(self, x):
        self.hidden = self.repackage_hidden(self.hidden)
        x, self.hidden = self.rnn(x, self.hidden)
        x = self.fc(x)
        return x
    
    def init_hidden(self):
        if self.rnn_type == 'LSTM':
            return (torch.zeros(self.num_layers, self.hidden_dim).to(self.device),
                    torch.zeros(self.num_layers, self.hidden_dim).to(self.device))
        else:
            return torch.zeros(self.num_layers, self.hidden_dim).to(self.device)
            
    def init_rnn_weights(self, layer, num_layers):
        for nl in range(num_layers):
            for weight in layer._all_weights[nl]:
                if "weight" in weight:
                    nn.init.xavier_uniform_(getattr(layer,weight)).to(self.device)
                if "bias" in weight:
                    nn.init.uniform_(getattr(layer,weight)).to(self.device)

    def init_linear_weights(self, layer):
        nn.init.xavier_uniform_(layer.weight).to(self.device)

  
    def repackage_hidden(self, hidden):
        """
        Wraps hidden states in new Tensors, to detach them from their history (To be done at the beginning of each iteration/step).
        """
        if isinstance(hidden, torch.Tensor):
            return hidden.detach()
        else:
            return tuple(self.repackage_hidden(v) for v in hidden)
