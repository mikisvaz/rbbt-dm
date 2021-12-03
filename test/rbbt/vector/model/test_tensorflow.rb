require File.join(File.expand_path(File.dirname(__FILE__)), '../../..', 'test_helper.rb')
require 'rbbt/vector/model/tensorflow'

class TestTensorflowModel < Test::Unit::TestCase

  def test_keras
    Log.severity = 0
    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir

      model = TensorFlowModel.new(
        dir, 
        optimizer: 'adam',
        loss: 'sparse_categorical_crossentropy',
        metrics: ['accuracy']
      )

      model.keras_graph do
        tf = tensorflow
        tf.keras.models.Sequential.new([
          tf.keras.layers.Flatten.new(input_shape: [28, 28]),
          tf.keras.layers.Dense.new(128, activation:'relu'),
          tf.keras.layers.Dropout.new(0.2),
          tf.keras.layers.Dense.new(10, activation:'softmax')
        ])
      end

      sum = predictions = nil
      model.tensorflow do
        tf = tensorflow
        mnist_db = tf.keras.datasets.mnist

        (x_train, y_train), (x_test, y_test) = mnist_db.load_data()
        x_train, x_test = x_train / 255.0, x_test / 255.0

        num = PyCall.len(x_train)

        num.times do |i|
          model.add x_train[i], y_train[i]
        end

        model.train

        predictions = model.eval_list x_test.tolist()
        sum = 0

        predictions.zip(y_test.tolist()).each do |pred,label|
          sum += 1 if label.to_i == pred
        end

      end

      assert sum.to_f / predictions.length > 0.7
    end
  end
end

