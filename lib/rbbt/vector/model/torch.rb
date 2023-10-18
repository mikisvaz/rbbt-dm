require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class TorchModel < VectorModel

  attr_accessor :model, :criterion, :optimizer, :training_args

  module Tensor
    def to_ruby
      RbbtPython.numpy2ruby(self)
    end
    def self.setup(obj)
      obj.extend Tensor
    end
  end

  def self.init_python
    RbbtPython.pyimport :torch
    RbbtPython.pyimport :rbbt
    RbbtPython.pyimport :rbbt_dm
    RbbtPython.pyfrom :rbbt_dm, import: :util
    RbbtPython.pyfrom :torch, import: :nn
  end

  def optimizer 
    @optimizer ||= begin
                     learning_rate = training_args[:learning_rate] || 0.01
                     RbbtPython.torch.optim.SGD.new(model.parameters(), lr: learning_rate)
                   end
  end

  def device
    @device ||= begin
      case @model_options[:device]
      when String, Symbol
        RbbtPython.torch.device(@model_options[:device].to_s)
      when nil
        RbbtPython.rbbt_dm.util.device()
      else
        @model_options[:device]
      end
    end
  end

  def dtype
    @dtype ||= begin
      case @model_options[:dtype]
      when String, Symbol
        RbbtPython.torch.call(@model_options[:dtype])
      when nil
        RbbtPython.torch.float
      else
        @model_options[:dtype]
      end
    end
  end

  def self.tensor(obj, device, dtype)
    RbbtPython.torch.tensor(obj, dtype: dtype, device: device)
  end

  def tensor(obj)
    TorchModel.tensor(obj, device, dtype)
  end

  def initialize(dir, model_options = {})
    TorchModel.init_python
    super(dir, model_options)
    @training_args = model_options[:training_args] || {}

    eval_model do |features,list=false|
      model.to(device)

      tensor = list ? self.tensor(features) : self.tensor([features])

      res = model.call(tensor)

      Tensor.setup(list ? res : res[0])
    end

    train_model do |features,labels|
      model.to(device)
      epochs = training_args[:epochs] || 3

      inputs = self.tensor(features)
      target = self.tensor(labels)

      Log::ProgressBar.with_bar epochs, :desc => "Training" do |bar|
        epochs.times do |i|
          optimizer.zero_grad()
          outputs = model.call(inputs)
          loss = criterion.call(outputs, target)
          loss.backward()
          optimizer.step
          Log.debug "Epoch #{i}, loss #{loss}"
          bar.tick
        end
      end
    end
  end
end
require_relative 'torch/dataloader'
require_relative 'torch/introspection'
