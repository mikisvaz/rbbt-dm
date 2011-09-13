require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt-util'
require 'rbbt/statistics/random_walk'
require 'test/unit'
require 'rsruby'

class TestRandomWalk < Test::Unit::TestCase

  def test_score
    positions1 = [1,2,3,4]
    positions2 = [1,2,3,4,50,51,52]
    positions3 = [50,51,52]
    positions4 = [98,99,100]
    total = 100

    assert RandomWalk.score(positions1, total, 0) > RandomWalk.score(positions2, total, 0)
    assert RandomWalk.score(positions1, total, 0) > RandomWalk.score(positions3, total, 0)
    assert RandomWalk.score(positions2, total, 0) > RandomWalk.score(positions3, total, 0)

    assert RandomWalk.score(positions4, total, 0) < 0
    assert RandomWalk.score(positions4, total, 0).abs > RandomWalk.score(positions2, total, 0).abs
  end

  def test_score_up_down
    positions1 = [1,2,3,4]
    positions2 = [1,2,3,4,50,51,52]
    positions3 = [50,51,52]
    positions4 = [98,99,100]
    total = 100

    assert RandomWalk.score_up_down(positions1, positions4, total, 0) > RandomWalk.score_up_down(positions1, positions3, total, 0)
    assert RandomWalk.score_up_down(positions4, positions1, total, 0) < 0
    assert_in_delta 0.0001, RandomWalk.score_up_down(positions4, positions1, total, 0).abs, RandomWalk.score_up_down(positions1, positions4, total, 0).abs
  end

  def test_pvalue
    positions1 = [1,2,3,4]
    positions2 = [1,2,3,4,50,51,52]
    positions3 = [50,51,52]
    positions4 = [98,99,100]
    total = 100

    score1 = RandomWalk.score_up_down(positions1, positions4, total, 0)
    score2 = RandomWalk.score_up_down(positions2, positions3, total, 0)

    assert score1 > score2

    permutations1 = RandomWalk.permutations_up_down(positions1.length, positions4.length, total)
    permutations2 = RandomWalk.permutations_up_down(positions2.length, positions3.length, total)

    assert RandomWalk.pvalue(permutations1, score1) < RandomWalk.pvalue(permutations2, score2)
  end

  def test_draw
    positions1 = [1,2,3,4]
    positions2 = [1,2,3,4,50,51,52]
    positions3 = [50,51,52]
    positions4 = [98,99,100]
    total = 100

    assert RandomWalk.draw_hits(positions2, total) =~ /PNG/

    TmpFile.with_file do |png|
      RandomWalk.draw_hits(positions2, total, png)
      assert File.exists? png
    end
  end
end



