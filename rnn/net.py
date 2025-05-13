import skorch
import numpy as np
import torch

import torch.optim as optim


class Net(skorch.NeuralNetRegressor):

    def __init__(
        self,
        criterion=torch.nn.MSELoss,
        optimizer= optim.Adam,
        lr=0.001,
        *args,
        **kwargs
    ):
        super(Net, self).__init__(
            criterion=criterion,
            lr=lr,
            optimizer=optimizer,
            *args,
            **kwargs
        )

    def repackage_hidden(self, hidden):
        """
        Wraps hidden states in new Tensors, to detach them from their history (To be done at the beginning of each iteration/step).
        """
        if isinstance(hidden, torch.Tensor):
            return hidden.detach()
        else:
            return tuple(self.repackage_hidden(v) for v in hidden)

    def on_epoch_begin(self, *args, **kwargs):
        super().on_epoch_begin(*args, **kwargs)

        # As an optimization to save tensor allocation for each
        # batch we initialize the hidden state only once per epoch.
        # This optimization was taken from the original example.
        self.hidden = self.module_.init_hidden2(self.batch_size)

    def train_step(self, X, y):
        print("t")
        self.module_.train()


        # Repackage shared hidden state so that the previous batch
        # does not influence the current one.
        self.hidden = self.repackage_hidden(self.hidden)
        self.module_.zero_grad()

        output, self.hidden = self.module_(X, self.hidden)

        loss = self.get_loss(output, y)
        loss.backward()

        self.optimizer.step()
        for p in self.module_.parameters():
            p.data.add_(-self.lr, p.grad.data)
        return {'loss': loss, 'y_pred': output}

    def validation_step(self, X, y):
        self.module_.eval()

        hidden = self.module_.init_hidden2(self.batch_size)
        output, _ = self.module_(X, hidden)

        return {'loss': self.get_loss(output, y), 'y_pred': output}

    def evaluation_step(self, X, **kwargs):
        self.module_.eval()

        X = skorch.utils.to_tensor(X, device=self.device)
        hidden = self.module_.init_hidden2(self.batch_size)
        output, _ = self.module_(X, hidden)

        return output
