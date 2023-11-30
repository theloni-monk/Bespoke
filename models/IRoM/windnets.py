from torch import nn

class AngleNet(nn.Module):
    def __init__(self, geom=5, trigValue=1, biasLayer=True):
        super(AngleNet, self).__init__()

        k1 = int(geom*8)
        k2 = int(k1/2 + 5)
        self.linear_relu_stack = nn.Sequential(nn.Linear(geom, k1, bias=biasLayer),
                                               nn.ReLU(),
                                               nn.Linear(k1, k2, bias=biasLayer),
                                               nn.ReLU(),
                                               nn.Linear(k2, trigValue, bias=biasLayer),
                                               )

    def forward(self, x):
        return self.linear_relu_stack(x.flatten())

class MagNet(nn.Module):
    def __init__(self, biasLayer=False):
        super(MagNet, self).__init__()

        self.linear_relu_stack = nn.Sequential(nn.Linear(3, 6, bias=biasLayer),
                                               nn.Tanh(),
                                               nn.Linear(6, 1, bias=biasLayer),
                                               )

    def forward(self, x):
        return self.linear_relu_stack(x.flatten())
