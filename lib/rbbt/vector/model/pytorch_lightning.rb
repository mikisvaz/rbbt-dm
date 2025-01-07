require 'rbbt/vector/model/torch'

class PytorchLightningModel < TorchModel
  attr_accessor :loader, :val_loader, :trainer
  def initialize(...)
    super(...)

    train_model do |features,labels|
      model = init
      train_loader = self.loader
      val_loader = self.val_loader
      if train_loader.nil?
        batch_size ||= model_options[:training_args][:batch_size]
        batch_size ||= model_options[:batch_size]
        batch_size ||= 1

        shuffle = model_options[:training_args][:shuffle]
        shuffle = true if shuffle.nil?

        num_workers = Rbbt.config(:num_workers, :dataloader, :default => 2)
        train_loader = RbbtPython.run :torch do
          dataset = features.zip(labels).collect{|f,l| [torch.tensor(f), l] }
          torch.utils.data.DataLoader.call(dataset, batch_size: batch_size, shuffle: shuffle, num_workers: num_workers.to_i)
        end
      end
      trainer.fit(model, train_loader, val_loader)
      TorchModel.save_architecture(model, model_path) if @directory
      TorchModel.save_state(model, model_path) if @directory
    end

    eval_model do |features,list=false|
      model = init
      eval_loader = self.loader
      if list
        if eval_loader.nil?
          batch_size ||= model_options[:batch_size]
          batch_size ||= model_options[:training_args][:batch_size]
          batch_size ||= 1

          num_workers = Rbbt.config(:num_workers, :dataloader, :default => 2)
          eval_loader = RbbtPython.run :torch do
            dataset = torch.tensor(features)
            torch.utils.data.DataLoader.call(dataset, batch_size: batch_size, num_workers: num_workers.to_i)
          end
        end
        trainer.predict(model, eval_loader).inject([]){|acc,res| acc.concat RbbtPython.numpy2ruby(res[1])}
      else
        model.call(torch.tensor(features))
      end
    end
  end

  def trainer
    @trainer ||= begin
                   trainer_args = {default_root_dir: File.join(@directory, 'checkpoints')}.
                     merge(model_options[:training_args].except(:batch_size))
                   RbbtPython.class_new_obj("pytorch_lightning", "Trainer", trainer_args)
                 end
  end
end
