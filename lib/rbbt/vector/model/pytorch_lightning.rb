require 'rbbt/vector/model/torch'

class PytorchLightningModel < TorchModel
  attr_accessor :loader, :val_loader, :trainer
  def initialize(module_name, class_name, dir = nil, model_options = {})
    super(dir, model_options)
    @module_name = module_name
    @class_name = class_name

    init_model do 
      RbbtPython.pyimport :torch
      RbbtPython.pyimport @module_name
      @model = RbbtPython.class_new_obj(@module_name, @class_name, @model_options[:model_args] || {})
    end

    train_model do |features,labels|
      model = init
      loader = self.loader
      val_loader = self.val_loader
      if (features && features.any?) && loader.nil?
        TmpFile.with_file do |tsv_dataset_file|
          TorchModel.feature_dataset(tsv_dataset_file, features, labels)
          RbbtPython.pyimport :rbbt_dm
          loader = RbbtPython.rbbt_dm.tsv(tsv_dataset_file)
        end
      end
      trainer.fit(model, loader, val_loader)
    end
  end

  def trainer
    @trainer ||= begin
                   options = @model_options[:training_args] || @model_options[:trainer_args] 
                   RbbtPython.class_new_obj("pytorch_lightning", "Trainer", options || {})
                 end
  end
end
