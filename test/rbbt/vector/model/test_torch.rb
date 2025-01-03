require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestTorch < Test::Unit::TestCase
  def test_linear
    model = nil

    TmpFile.with_dir do |dir|

      # Create model
      
      model = TorchModel.new dir
      model.model = RbbtPython.torch.nn.Linear.new(1, 1)
      model.criterion = RbbtPython.torch.nn.MSELoss.new()

      model.extract_features do |f|
        [f]
      end

      model.post_process do |v,list|
        list ? v.to_ruby.collect{|vv| vv.first } :  v.to_ruby.first
      end

      # Train model
      
      model.add 5.0, [10.0]
      model.add 10.0, [20.0]

      model.model_options[:training_args][:epochs] = 1000
      model.train

      w = model.get_weights.to_ruby.first.first

      assert w > 1.8
      assert w < 2.2

      # Load the model again

      model = VectorModel.new dir

      # Test model

      y = model.eval(100.0)

      assert(y > 150.0)
      assert(y < 250.0)

      test = [1.0, 5.0, 10.0, 20.0]
      input_sum = Misc.sum(test)
      sum = Misc.sum(model.eval_list(test))
      assert sum > 0.8 * input_sum * 2
      assert sum < 1.2 * input_sum * 2

      w = TorchModel.get_weights(model.model).to_ruby.first.first

      assert w > 1.8
      assert w < 2.2
    end
  end
end

