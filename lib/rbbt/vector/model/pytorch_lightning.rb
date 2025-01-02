require 'rbbt/vector/model/torch'

class PytorchLightningModel < TorchModel
  attr_accessor :loader, :val_loader, :trainer, :batch_size, :shuffle
  def initialize(...)
    super(...)

    @batch_size = training_args.delete(:batch_size) || 2
    @shuffle = training_args.delete(:shuffle)
    @shuffle = true if @shuffle.nil?

    train_model do |features,labels|
      model = init
      loader = self.loader
      val_loader = self.val_loader
      if (features && features.any?) 
        if loader.nil?
          batch_size = @batch_size
          shuffle = @shuffle
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
                   RbbtPython.class_new_obj("pytorch_lightning", "Trainer", training_args || {})
                 end
  end
end
