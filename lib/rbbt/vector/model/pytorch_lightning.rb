require 'rbbt/vector/model/torch'

class PytorchLightningModel < TorchModel
  attr_accessor :loader, :val_loader, :trainer
  def initialize(...)
    super(...)

    train_model do |features,labels|
      model = init
      loader = self.loader
      val_loader = self.val_loader
      if (features && features.any?) 
        if loader.nil?
          batch_size ||= model_options[:training_args][:batch_size]
          batch_size ||= model_options[:batch_size]
          batch_size ||= 1

          shuffle = model_options[:training_args][:shuffle]
          shuffle = true if shuffle.nil?

          loader = RbbtPython.run :torch do
            dataset = features.zip(labels).collect{|f,l| [torch.tensor(f), l] }
            torch.utils.data.DataLoader.call(dataset, batch_size: batch_size, shuffle: shuffle)
          end
        end
      end
      trainer.fit(model, loader, val_loader)
      TorchModel.save_architecture(model, model_path) if @directory
      TorchModel.save_state(model, model_path) if @directory
    end
  end

  def trainer
    @trainer ||= begin
                   RbbtPython.class_new_obj("pytorch_lightning", "Trainer", model_options[:training_args] || {})
                 end
  end
end
