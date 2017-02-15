require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/statistics/fdr'
require 'test/unit'
require 'rbbt/util/R'

class TestFDR < Test::Unit::TestCase
  def clean(values)
    if Array === values
      values.collect{|v| (v * 10000).to_i.to_f / 10000}
    else
      (values * 10000).to_i.to_f / 10000
    end
  end

  def copy(values)
    values.collect{|v| v + 0.0}
  end

  def setup
    @values = [0.001, 0.002, 0.003, 0.003, 0.003, 0.004, 0.006, 0.07, 0.09]
    @threshold = 0.01
    @r_adj = R.eval_a "p.adjust(#{R.ruby2R(@values)},'BH')"
  end

  def test_step_up
    assert_equal(0.006, clean(FDR.step_up(@values, @threshold)))
    assert_equal(clean(FDR.step_up_native(@values, @threshold)), clean(FDR.step_up_fast(@values,@threshold)))
    assert_equal(@r_adj.select{|v| v <= @threshold}.length, @values.select{|v| v <= FDR.step_up(@values, @threshold)}.length)
  end

  def test_adjust
    assert_equal(clean(@r_adj), clean(FDR.adjust_native(@values)))
    assert_equal(clean(FDR.adjust_fast(@values)), clean(FDR.adjust_native(@values)))

    assert_equal(clean(@r_adj), clean(FDR.adjust_fast_self(copy(@values)))) if RUBY_VERSION[0] != "2"
  end
end


