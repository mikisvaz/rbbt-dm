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
          #TmpFile.with_file do |tsv_dataset_file|
          #  TorchModel.feature_dataset(tsv_dataset_file, features, labels)
          #  dataset = RbbtPython.rbbt_dm.tsv(tsv_dataset_file)
          #  loader = RbbtPython.run :torch do
          #    torch.utils.data.DataLoader.call(dataset, batch_size: 2, shuffle: true)
          #  end
          #end
          dataset = features.zip(labels)
          loader = RbbtPython.run :torch do
            torch.utils.data.DataLoader.call(dataset, batch_size: 2, shuffle: true)
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
                   options = @model_options[:training_args] || @model_options[:trainer_args] 
                   RbbtPython.class_new_obj("pytorch_lightning", "Trainer", options || {})
                 end
  end
end
