require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')
require 'rbbt/vector/model/svm'
require 'rbbt/util/R'
require 'test/unit'

class TestSVMModel < Test::Unit::TestCase

  def test_model
    text =<<-EOF
1 0;1;1
1 1;0;1
1 1;1;1
1 0;1;1
1 1;1;1
0 0;1;0
0 1;0;0
0 0;1;0
0 1;0;0
    EOF

    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir
      model = SVMModel.new(dir)

      model.extract_features = Proc.new{|element|
        element.split(";")
      }

      text.split(/\n/).each do |line|
        label, features = line.split(" ")
        model.add(features, label)
      end

      model.train

      assert model.eval("1;1;1") > 0.5
      assert model.eval("0;0;0") < 0.5

      assert_equal [true, false], model.eval_list(%w(1;1;1 0;0;0)).collect{|v| v > 0.5}
    end
  end

end
