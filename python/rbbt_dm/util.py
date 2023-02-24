import random
import torch
import numpy

def set_seed(seed):
    """
    Set seed in several backends
    """
    random.seed(seed)
    numpy.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)

def deterministic():
    """
    Ensure that all operations are deterministic on GPU (if used) for
    reproducibility
    """
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

def device():
    return torch.device("cuda:0") if torch.cuda.is_available() else torch.device("cpu")

def data_directory():
    from pathlib import Path
    print(Path.home())

