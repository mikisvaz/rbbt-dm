from torch.utils.data import Dataset, DataLoader

class TSVDataset(Dataset):
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
    import rbbt
    return TSVDataset(rbbt.tsv(filename, *args, **kwargs))

def tsv(*args, **kwargs):
    return tsv_dataset(*args, **kwargs)

def data_dir():
    import rbbt
    return rbbt.path('var/rbbt_dm/data')

if __name__ == "__main__":
    import rbbt

    filename = "/home/miki/test/numeric.tsv"
    ds = tsv(filename)

    dl = DataLoader(ds, batch_size=1)

    for f, l in iter(dl):
        print(".")
        print(f[0,:])
        print(l[0])




