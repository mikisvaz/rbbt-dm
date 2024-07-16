class TorchModel
  def self.get_layer(model, layer = nil)
    if layer.nil?
      model
    else
      layer.split(".").inject(model){|acc,l| PyCall.getattr(acc, l.to_sym) }
    end
  end
  def get_layer(...); TorchModel.get_layer(model, ...); end

  def self.get_weights(model, layer = nil)
    Tensor.setup PyCall.getattr(get_layer(model, layer), :weight)
  end
  def get_weights(...); TorchModel.get_weights(model, ...); end

  def self.freeze(layer, requires_grad=false)
    begin
      PyCall.getattr(layer, :weight).requires_grad = requires_grad
    rescue
    end
    RbbtPython.iterate(layer.children) do |layer|
      freeze(layer, requires_grad)
    end
  end

  def self.freeze_layer(model, layer, requires_grad = false)
    layer = get_layer(model, layer)
    freeze(layer, requires_grad)
  end

  def freeze_layer(...); TorchModel.freeze_layer(model, ...); end
end
