require 'rbbt/vector/model/torch'

class PytorchLightningModel < TorchModel
  attr_accessor :loader, :val_loader, :trainer
  def initialize(module_name, class_name, dir = nil, model_options = {})
    super(dir, model_options)
    @module_name = module_name
    @class_name = class_name

    init_model do 
      RbbtPython.pyimport @module_name
      RbbtPython.class_new_obj(@module_name, @class_name, @model_options[:model_args] || {})
    end

    train_model do |features,labels|
      model = init
      raise "Use the loader" if @loader.nil?
      raise "Use the trainer" if @trainer.nil?
      
      trainer.fit(model, @loader, @val_loader)
    end

    eval_model do |features,list|
      if list
        model.call(RbbtPython.call_method(:torch, :tensor, features))
      else
        model.call(RbbtPython.call_method(:torch, :tensor, [features]))
      end
    end

  end
end

if __FILE__ == $0
end
