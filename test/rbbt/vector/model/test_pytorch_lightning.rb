require File.join(File.expand_path(File.dirname(__FILE__)), '../../..', 'test_helper.rb')
require 'rbbt/vector/model/pytorch_lightning'

class TestPytorchLightning < Test::Unit::TestCase
  def test_regresion
    points = 10
    a = 1
    b = 1

    x = (0..points - 1)
    y = points.times.collect{|p| p }
    
    python = <<~EOF
import pytorch_lightning as pl
import numpy as np
import torch
from torch.nn import MSELoss
from torch.optim import Adam
from torch.utils.data import DataLoader, Dataset
import torch.nn as nn


class SimpleDataset(Dataset):
    def __init__(self):
        X = np.arange(10000)
        y = X * 2
        X = [[_] for _ in X]
        y = [[_] for _ in y]
        self.X = torch.Tensor(X)
        self.y = torch.Tensor(y)

    def __len__(self):
        return len(self.y)

    def __getitem__(self, idx):
        return {"X": self.X[idx], "y": self.y[idx]}


class TestPytorchLightningModel(pl.LightningModule):
    def __init__(self):
        super().__init__()
        self.fc = nn.Linear(1, 1)
        self.criterion = MSELoss()

    def forward(self, inputs, labels=None):
        outputs = self.fc(inputs)
        loss = 0
        if labels is not None:
            loss = self.criterion(outputs, labels)
        return loss, outputs

    def train_dataloader(self):
        dataset = SimpleDataset()
        return DataLoader(dataset, batch_size=1000)

    def training_step(self, batch, batch_idx):
        input_ids = batch["X"]
        labels = batch["y"]
        loss, outputs = self(input_ids, labels)
        return {"loss": loss}

    def configure_optimizers(self):
        optimizer = Adam(self.parameters(), lr=0.1)
        return optimizer
    EOF

    TmpFile.with_dir do |dir|
      Open.write(File.join(dir, 'model.py'), python)
      model = PytorchLightningModel.new dir, "TestPytorchLightningModel"
      model.init

      model.trainer = RbbtPython.class_new_obj("pytorch_lightning", "Trainer", max_epochs: 10, precision: 16)
      model.init

      model.train

      w = model.get_weights('fc').to_ruby.first.first

      assert w > 1.8
      assert w < 2.2

      res = model.eval(10.0)
      assert_equal res, (10 * w)
      assert res > 1.8 * 10.0
      assert res < 2.2 * 10.0

      res = model.eval([10.0])
      res = model.eval_list([[10.0], [11.2], [14.3]])
      assert_equal 3, RbbtPython.numpy2ruby(res).length

      model = VectorModel.new dir
      model.init

    end
  end
end

