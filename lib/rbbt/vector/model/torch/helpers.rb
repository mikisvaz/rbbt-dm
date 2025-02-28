class TorchModel
  module Tensor
    def to_ruby
      RbbtPython.numpy2ruby(self)
    end

    def to_ruby!
      r = self.to_ruby
      self.del
      r
    end

    def length
      PyCall.len(self)
    end

    def self.setup(obj)
      obj.extend Tensor
    end

    def del
      self.detach
      self.grad = nil
      self.storage.resize_ 0
      self.to("cpu")
    end
  end

  def self.init_python
    RbbtPython.init_rbbt
    RbbtPython.pyimport :torch
    RbbtPython.pyimport :rbbt
    RbbtPython.pyimport :rbbt_dm
    RbbtPython.pyfrom :rbbt_dm, import: :util
    RbbtPython.pyfrom :torch, import: :nn
  end

  def self.optimizer(model, training_args)
    begin
      learning_rate = training_args[:learning_rate] || 0.01
      RbbtPython.torch.optim.SGD.new(model.parameters(), lr: learning_rate)
    end
  end

  def self.device(model_options)
    case model_options[:device]
    when String, Symbol
      RbbtPython.torch.device(model_options[:device].to_s)
    when nil
      RbbtPython.rbbt_dm.util.device()
    else
        model_options[:device]
    end
  end

  def self.dtype(model_options)
    case model_options[:dtype]
    when String, Symbol
      RbbtPython.torch.call(model_options[:dtype])
    when nil
      nil
    else
      model_options[:dtype]
    end
  end

  def self.tensor(obj, device, dtype)
    TorchModel::Tensor.setup(RbbtPython.torch.tensor(obj, dtype: dtype, device: device))
  end

end
