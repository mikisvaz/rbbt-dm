require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class PythonModel < VectorModel
  attr_accessor :python_class, :python_module
  def initialize(dir, python_class = nil, python_module = nil, model_options = nil)
    python_module = :model if python_module.nil?
    model_options, python_module = python_module, :model if model_options.nil? && Hash === python_module
    model_options = {} if model_options.nil?

    super(dir, model_options)

    @python_class = python_class
    @python_module = python_module

    init_model do
      RbbtPython.add_path @directory 
      RbbtPython.class_new_obj(@python_module, @python_class, **model_options)
    end if python_class

    eval_model do |features,list=false|
      init
      if list
        model.eval(features)
      else
        model.eval([features])[0]
      end
    end
  end
end
