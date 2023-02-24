require File.join(File.expand_path(File.dirname(__FILE__)), '../../..', 'test_helper.rb')
require 'rbbt/vector/model/pytorch_lightning'

class TestPytorchLightning < Test::Unit::TestCase
  def test_clustering
    nsamples = 10
    ngenes = 10000
    samples = nsamples.times.collect{|i| "Sample-#{i}" }
    data = TSV.setup({}, :key_field => "Gene", :fields => samples + ["cluster"], :type => :list, :cast => :to_f)

    profiles = []
    p0 = 3
    p1 = 7
    profiles[0] = nsamples.times.collect{ rand() + p0 }
    profiles[1] = nsamples.times.collect{ rand() + p1 }

    ngenes.times do |genen|
      gene = "Gene-#{genen}"
      cluster = genen % 2 
      values = profiles[cluster].collect do |m|
        rand() + m
      end
      data[gene] = values + [cluster]
    end

    python = <<~EOF
import torch
from torch import nn
from torch.nn import functional as F
from torch.utils.data import DataLoader
from torch.utils.data import random_split
from torchvision.datasets import MNIST
from torchvision import transforms
import pytorch_lightning as pl

class TestPytorchLightningModel(pl.LightningModule):
  def __init__(self, input_size=10, internal_dim=1):
    super().__init__()
    self.model = nn.Tanh()

  def configure_optimizers(self):
    optimizer = torch.optim.Adam(self.parameters(), lr=1e-3)
    return optimizer

  @torch.cuda.amp.autocast(True)
  def forward(self, x):
    x = x.to(self.dtype)
    return self.model(x).squeeze()

  @torch.cuda.amp.autocast(True)
  def training_step(self, train_batch, batch_idx):
    x, y = train_batch
    x = x.to(self.dtype)
    y = y.to(self.dtype)
    y_hat = self.model(x).squeeze()
    loss = F.mse_loss(y, y_hat) 
    self.log('train_loss', loss)
    return loss

  @torch.cuda.amp.custom_fwd(cast_inputs=torch.float64)
  def validation_step(self, val_batch, batch_idx):
    x, y = train_batch
    y_hat = self.model(x)    
    loss = F.mse_loss(y, y_hat) 
    self.log('val_loss', loss)

    EOF

    with_python(python) do |pkg|
      model = PytorchLightningModel.new pkg , "TestPytorchLightningModel", nil, model_args: {internal_dim: 1}
      TmpFile.with_file(data.to_s) do |data_file|
        ds = RbbtPython.call_method "rbbt_dm", :tsv, filename: data_file
        model.loader = RbbtPython.class_new_obj("torch.utils.data", :DataLoader, dataset: ds, batch_size: 64)
        model.trainer = RbbtPython.class_new_obj("pytorch_lightning", "Trainer", gpus: 1, max_epochs: 5, precision: 16)
      end
      model.train
      encoding = model.eval_list(data.values.collect{|v| v[0..-2] }).detach().cpu().numpy()
      iii encoding[0..10]
    end
  end

end

