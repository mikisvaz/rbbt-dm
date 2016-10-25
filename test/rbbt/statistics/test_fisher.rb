require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/statistics/fisher'

class TestFisher < Test::Unit::TestCase
  def test_classification
    class1 = [0,0,0,0,1,1,1,1,1]
    class2 = [0,0,0,1,1,1,1,1,0]
    iii Fisher.test_classification(class1, class2)
  end
end

