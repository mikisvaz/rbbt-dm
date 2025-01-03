require_relative 'python'

class TorchModel < PythonModel

  attr_accessor :criterion, :optimizer

  def initialize(...)
    TorchModel.init_python
    super(...)

    @model_options[:training_options] = @model_options.delete(:training_args) if @model_options.include?(:training_args)
    training_args = IndiferentHash.pull_keys(@model_options, :training) || {}
    @model_options[:training_args] = training_args
    init_model do
      model = TorchModel.load_architecture(model_path) 
      if model.nil?
        RbbtPython.add_path @directory 
        RbbtPython.process_paths
        RbbtPython.class_new_obj(@python_module, @python_class, **model_options.except(:training_args, :batch_size))
      else
        TorchModel.load_state(model, model_path)
      end
    end

    train_model do |features,labels|
      init
      @device ||= TorchModel.device(model_options)
      @dtype ||= TorchModel.dtype(model_options)
      model.to(@device)
      @optimizer ||= TorchModel.optimizer(model, model_options[:training_args] || {})

      epochs = model_options[:training_args][:epochs] || 3
      batch_size = model_options[:batch_size]
      batch_size ||= model_options[:training_args][:batch_size]
      batch_size ||= 1

      inputs = TorchModel.tensor(features, @device, @dtype)
      #target = TorchModel.tensor(labels.collect{|v| [v] }, @device, @dtype)
      target = TorchModel.tensor(labels, @device, @dtype)

      Log::ProgressBar.with_bar epochs, :desc => "Training" do |bar|
        epochs.times do |i|
          @optimizer.zero_grad()
          outputs = model.call(inputs)
          outputs = outputs.squeeze() if target.dim() == 1
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

    eval_model do |features,list=false|
      init
      @device ||= TorchModel.device(model_options)
      @dtype ||= TorchModel.dtype(model_options)
      model.to(@device)
      model.eval

      features = [features] unless list

      batch_size = model_options[:batch_size]
      batch_size ||= model_options[:training_args][:batch_size]
      batch_size ||= 1

      res = Misc.chunk(features, batch_size).inject(nil) do |acc,batch|

        tensor = TorchModel.tensor(batch, @device, @dtype)

        loss, chunk_res = model.call(tensor)

        chunk_res = loss if chunk_res.nil?

        acc = acc.nil? ? chunk_res : RbbtPython.torch.cat([acc, chunk_res])
      end

      res = TorchModel::Tensor.setup(list ? res : res[0])

      res
    end

  end
end
require_relative 'torch/helpers'
require_relative 'torch/dataloader'
require_relative 'torch/introspection'
require_relative 'torch/load_and_save'
