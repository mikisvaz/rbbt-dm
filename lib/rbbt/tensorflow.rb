require 'rbbt/util/python'

module RbbtTensorflow

  def self.init
    RbbtPython.run do
      pyimport "tensorflow", as: "tf"
    end
  end

  def self.test

    mod = x_test = y_test = nil
    RbbtPython.run do

      mnist_db = tf.keras.datasets.mnist

      (x_train, y_train), (x_test, y_test) = mnist_db.load_data()
      x_train, x_test = x_train / 255.0, x_test / 255.0

      mod = tf.keras.models.Sequential.new([
        tf.keras.layers.Flatten.new(input_shape: [28, 28]),
        tf.keras.layers.Dense.new(128, activation:'relu'),
        tf.keras.layers.Dropout.new(0.2),
        tf.keras.layers.Dense.new(10, activation:'softmax')
      ])
      mod.compile(optimizer='adam',
                  loss='sparse_categorical_crossentropy',
                  metrics=['accuracy'])
      mod.fit(x_train, y_train, epochs:1)
      mod
    end

    RbbtPython.run do
      mod.evaluate(x_test,  y_test, verbose:2)
    end
  end
end

if __FILE__ == $0
  RbbtTensorflow.init
  RbbtTensorflow.test
end
