class TorchModel
  def self.model_architecture(model_path)
    model_path + '.architecture'
  end

  def self.save_state(model, model_path)
    Log.debug "Saving model state into #{model_path}"
    RbbtPython.torch.save(model.state_dict(), model_path)
  end

  def self.load_state(model, model_path)
    Log.debug "Loading model state from #{model_path}"
    model.load_state_dict(RbbtPython.torch.load(model_path))
    model
  end

  def self.save_architecture(model, model_path)
    model_architecture = model_architecture(model_path)
    Log.debug "Saving model architecture into #{model_architecture}"
    RbbtPython.torch.save(model, model_architecture)
  end

  def self.load_architecture(model_path)
    model_architecture = model_architecture(model_path)
    return unless Open.exists?(model_architecture)
    Log.debug "Loading model architecture from #{model_architecture}"
    RbbtPython.torch.load(model_architecture)
  end
end
