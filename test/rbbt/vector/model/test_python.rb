require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestPythonModel < Test::Unit::TestCase
  def test_linear
    model = nil

    TmpFile.with_dir do |dir|

      Misc.in_dir dir do
        Open.write 'model.py', <<-EOF
class TestModel:
  def __init__(self, delta):
    self.delta = delta
    
  def eval(self, x):
    return [e + self.delta for e in x]
        EOF
        model = PythonModel.new dir, 'TestModel', :model, delta: 1
        
        assert_equal 2, model.eval(1)
        assert_equal [4, 6], model.eval_list([3, 5])

        model = PythonModel.new dir, 'TestModel', :model, delta: 2
        
        assert_equal 3, model.eval(1)
      end
    end
  end
end

