import rbbt
import torch

class TSVDataset(torch.utils.data.Dataset):
    def __init__(self, tsv):
        self.tsv = tsv

    def __getitem__(self, key):
        if (type(key) == int):
            row = self.tsv.iloc[key]
        else:
            row = self.tsv.loc[key]

        row = row.to_numpy()
        features = row[:-1]
        label = row[-1]

        return features, label

    def __len__(self):
        return len(self.tsv)

def tsv_dataset(filename, *args, **kwargs):
    return TSVDataset(rbbt.tsv(filename, *args, **kwargs))

def tsv(*args, **kwargs):
    return tsv_dataset(*args, **kwargs)

def data_dir():
    return rbbt.path('var/rbbt_dm/data')
