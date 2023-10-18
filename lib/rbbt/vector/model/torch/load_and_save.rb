class TorchModel
  def model_architecture
    File.join(@directory, 'model_architecture.pth')
  end

  def save_state
    Log.debug "Saving model state into #{model_path}"
    RbbtPython.torch.save(model.state_dict(), model_path)
  end

  def load_state
    Log.debug "Loading model state from #{model_path}"
    @model.load_state_dict(RbbtPython.torch.load(model_path))
  end

  def save_architecture
    Log.debug "Saving model architecture into #{model_architecture}"
    RbbtPython.torch.save(model, model_architecture)
  end

  def load_architecture
    return unless Open.exists?(model_architecture)
    Log.debug "Loading model architecture from #{model_architecture}"
    @model = RbbtPython.torch.load(model_architecture)
  end

  def save_torch_model
    save_state
    save_architecture
  end

  def load_torch_model
    load_architecture
    load_state
    @model
  end
end
