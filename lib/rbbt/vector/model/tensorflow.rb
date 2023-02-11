require 'rbbt/vector/model'
require 'rbbt/tensorflow'

class TensorFlowModel < VectorModel
  attr_accessor :graph, :epochs, :compile_options

  def tensorflow(&block)
    RbbtPython.run "tensorflow" do 
      RbbtPython.module_eval(&block)
    end
  end

  def keras(&block)
    RbbtPython.run "tensorflow.keras", as: 'keras' do 
      RbbtPython.run "tensorflow" do 
        RbbtPython.module_eval(&block)
      end
    end
  end
  
  def initialize(dir, graph = nil, epochs = 3, **compile_options)
    @graph = graph
    @epochs = epochs
    @compile_options = compile_options

    super(dir)

    @train_model = Proc.new do |features, labels|
      tensorflow do 
        features = tensorflow.convert_to_tensor(features)
        labels = tensorflow.convert_to_tensor(labels)
      end
      @graph ||= keras_graph
      @graph.compile(**@compile_options)
      @graph.fit(features, labels, :epochs => @epochs, :verbose => true)
      @graph.save(@model_path)
    end
 
    @eval_model = Proc.new do |features|
      tensorflow do 
        features = tensorflow.convert_to_tensor(features)
      end
      model_path = @model_path
      graph = @graph ||= keras.models.load_model(model_path)
      keras do
        indices = graph.predict(features, :verbose => false).tolist()
        labels = indices.collect{|p| p.length > 1 ? p.index(p.max): p.first }
        labels
      end
    end
  end

  def keras_graph(&block)
    @graph = keras(&block)
  end
end
