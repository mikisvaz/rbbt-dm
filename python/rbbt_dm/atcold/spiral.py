import torch
import math
def spiral_data(N=1000, D=2, C=3):
    X = torch.zeros(N * C, D)
    y = torch.zeros(N * C, dtype=torch.long)
    for c in range(C):
        index = 0
        t = torch.linspace(0, 1, N)
        # When c = 0 and t = 0: start of linspace
        # When c = 0 and t = 1: end of linpace
        # This inner_var is for the formula inside sin() and cos() like sin(inner_var) and cos(inner_Var)
        inner_var = torch.linspace(
            # When t = 0
            (2 * math.pi / C) * (c),
            # When t = 1
            (2 * math.pi / C) * (2 + c),
            N
        ) + torch.randn(N) * 0.2

        for ix in range(N * c, N * (c + 1)):
            X[ix] = t[index] * torch.FloatTensor((
                math.sin(inner_var[index]), math.cos(inner_var[index])
            ))
            y[ix] = c
            index += 1

    return (X, y)
