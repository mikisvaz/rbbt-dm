require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/network/paths'
require 'test/unit'
require 'rbbt/sources/string'
require 'set'


class TestNetwork < Test::Unit::TestCase
  def _test_dijsktra
    network_txt=<<-EOF
#: :sep=/\s/#:type=:flat
#Start End
N1 N2
N2 N3 N4
N4 N5
    EOF
    network = TSV.open(StringIO.new(network_txt))

    start_node = "N1"
    end_node = "N5"

    path = Paths.dijkstra(network, start_node, [end_node])
    assert_equal %w(N1 N2 N4), path.reverse
  end

  def test_weighted_dijsktra
    network_txt=<<-EOF
#: :sep=/\s/#:type=:double
#Start End Score
N1 N2|N5 1|10
N2 N3|N4 1|1
N4 N5 1
    EOF
    network = TSV.open(StringIO.new(network_txt))

    start_node = "N1"
    end_node = "N5"

    path = Paths.weighted_dijkstra(network, start_node, [end_node])
    assert_equal %w(N1 N2 N4 N5), path.reverse

  end


  def __test_random_weighted_dijsktra
    string = STRING.protein_protein.tsv 

    string.process "Score" do |scores|
      scores.collect{|score| 1000 - score.to_i}
    end
    string.unnamed = true

    start_node = "ENSP00000256078"
    end_node = "ENSP00000306245"

    path = Paths.random_weighted_dijkstra(string, 0.8, start_node, end_node)

    assert path != nil
    assert path.include? start_node
    assert path.include? end_node
  end

end


