require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class TorchModel < VectorModel

  attr_accessor :model

  def self.get_layer(model, layer)
    layer.split(".").inject(model){|acc,l| PyCall.getattr(acc, l.to_sym) }
  end

  def self.get_weights(model, layer)
    PyCall.getattr(get_layer(model, layer), :weight)
  end

  def self.freeze(layer)
    begin
      PyCall.getattr(layer, :weight).requires_grad = false
    rescue
    end
    RbbtPython.iterate(layer.children) do |layer|
      freeze(layer)
    end
  end

  def self.freeze_layer(model, layer)
    layer = get_layer(model, layer)
    freeze(layer)
  end

  def initialize(*args)
    options = args.pop if Hash === args.last
    super(*args, model_options: options)
  end
end
