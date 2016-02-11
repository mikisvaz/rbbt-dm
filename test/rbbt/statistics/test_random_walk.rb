require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/statistics/random_walk'
require 'test/unit'

class TestRandomWalk < Test::Unit::TestCase
  def test_score_weight
    list = (1..1000).to_a
    list.extend OrderedList

    weights = list.collect{|v| (Misc.mean(list) - v)**2}
    weights_total = Misc.sum(weights)

    assert RandomWalk.score_custom_weights((1..100).to_a, weights, weights_total, list.length, 0) >
    RandomWalk.score_custom_weights([100, 200, 300, 400, 500], weights, weights_total, list.length, 0)
  end

  def test_pvalue
    list = (1..1000).to_a
    list.extend OrderedList

    assert list.pvalue((1..100).to_a, 0.05).abs < 0.05
    assert list.pvalue((1..100).to_a, 0.05) > 0
    
    assert list.pvalue((900..1000).to_a, 0.05).abs < 0.05
    assert list.pvalue((900..1000).to_a, 0.05) < 0

    assert list.pvalue([100, 200, 300, 400, 500], 0.05) > 0.05

    assert list.pvalue((1..100).to_a, 0.05, :persisted_permutations => true).abs < 0.05
    assert list.pvalue((1..100).to_a, 0.05, :persisted_permutations => true) > 0
    
    assert list.pvalue((900..1000).to_a, 0.05, :persisted_permutations => true).abs < 0.05
    assert list.pvalue((900..1000).to_a, 0.05, :persisted_permutations => true) < 0

    assert list.pvalue([100, 200, 300, 400, 500], 0.05, :persisted_permutations => true) > 0.05
  end

  def test_pvalue_up_down
    Log.severity = 0
    list = (1..1000).to_a
    list.extend OrderedList

    assert list.pvalue_up_down((1..100).to_a, (900..1000).to_a, 0.05, :persist_permutations => false).abs < 0.05
    assert list.pvalue_up_down((1..100).to_a, (900..1000).to_a, 0.05, :persist_permutations => false) > 0

    assert list.pvalue_up_down((900..1000).to_a, (1..100).to_a, 0.05, :persist_permutations => false).abs < 0.05
    assert list.pvalue_up_down((900..1000).to_a, (1..100).to_a, 0.05, :persist_permutations => false) < 0

    rand_top = (1..100).to_a.collect{ rand(1000) }
    rand_bottom = (1..100).to_a.collect{ rand(1000) }
    assert list.pvalue_up_down(rand_top, rand_bottom, 0.05, :persisted_permutations => false).abs > 0.05

    assert list.pvalue_up_down((1..100).to_a, (900..1000).to_a, 0.05, :persist_permutations => true).abs < 0.05
    assert list.pvalue_up_down((1..100).to_a, (900..1000).to_a, 0.05, :persist_permutations => true) > 0

    assert list.pvalue_up_down((900..1000).to_a, (1..100).to_a, 0.05, :persist_permutations => true).abs < 0.05
    assert list.pvalue_up_down((900..1000).to_a, (1..100).to_a, 0.05, :persist_permutations => true) < 0

    rand_top = (1..100).to_a.collect{ rand(1000) }
    rand_bottom = (1..100).to_a.collect{ rand(1000) }
    assert list.pvalue_up_down(rand_top, rand_bottom, 0.05, :persisted_permutations => true).abs > 0.05
  end

  def __test_pvalue_weights
    list = (1..1000).to_a

    weights = list.collect{|v| (Misc.mean(list) - v)**2}
    weights_total = Misc.sum(weights)
    
    OrderedList.setup(list, weights, weights_total)

    assert list.pvalue_weights((1..100).to_a, 0.05) < 0.05
    assert list.pvalue_weights([100, 200, 300, 400, 500], 0.05) > 0.05

  end
end


