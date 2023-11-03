require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class TorchModel < VectorModel

  attr_accessor :model, :criterion, :optimizer, :training_args

  def initialize(dir = nil, model_options = {})
    TorchModel.init_python
    super(dir, model_options)
    @training_args = model_options[:training_args] || {}

    init_model do
      model = TorchModel.load_architecture(model_path) if @directory
      TorchModel.load_state(model, model_path) if @directory
    end

    eval_model do |features,list=false|
      init
      @device ||= TorchModel.device(model_options)
      @dtype ||= TorchModel.dtype(model_options)
      model.to(@device)

      tensor = list ? TorchModel.tensor(features, @device, @dtype) : TorchModel.tensor([features], @device, @dtype)

      res = model.call(tensor)

      TorchModel::Tensor.setup(list ? res : res[0])
    end

    train_model do |features,labels|
      @device ||= TorchModel.device(model_options)
      @dtype ||= TorchModel.dtype(model_options)
      model.to(@device)
      @optimizer ||= TorchModel.optimizer(model, training_args)
      epochs = training_args[:epochs] || 3

      inputs = TorchModel.tensor(features, @device, @dtype)
      #target = TorchModel.tensor(labels.collect{|v| [v] }, @device, @dtype)
      target = TorchModel.tensor(labels, @device, @dtype)

      Log::ProgressBar.with_bar epochs, :desc => "Training" do |bar|
        epochs.times do |i|
          @optimizer.zero_grad()
          outputs = model.call(inputs)
          loss = criterion.call(outputs, target)
          loss.backward()
          @optimizer.step
          Log.debug "Epoch #{i}, loss #{loss}"
          bar.tick
        end
      end
      TorchModel.save_architecture(model, model_path) if @directory
      TorchModel.save_state(model, model_path) if @directory
    end
  end
end
require_relative 'torch/helpers'
require_relative 'torch/dataloader'
require_relative 'torch/introspection'
require_relative 'torch/load_and_save'
