require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/statistics/random_walk'
require 'test/unit'

class TestRandomWalk < Test::Unit::TestCase
  def test_pvalue_inline
    list = (1..1000).to_a
    list.extend OrderedList

    puts list.pvalue((1..100).to_a)
    puts list.pvalue([100, 200, 300, 400, 500])
    puts list.pvalue_inline([100, 200, 300, 400, 500], 0.05)
    puts list.pvalue_inline((1..100).to_a, 0.05)
  end
end


