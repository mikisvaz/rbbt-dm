require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/network/paths'
require 'test/unit'
require 'rbbt/sources/string'
require 'set'


class TestNetwork < Test::Unit::TestCase
  def test_dijsktra
    string = STRING.protein_protein.tsv :persist => false, :fields => ["Interactor Ensembl Protein ID"], :type => :flat 
    string.unnamed = true

    start_node = "ENSP00000256078"
    end_node = "ENSP00000306245"

    path = Paths.dijkstra(string, start_node, [end_node])

    assert path != nil
    assert path.include? start_node
    assert path.include? end_node
  end

  def test_weighted_dijsktra
    string = STRING.protein_protein.tsv 

    string.process "Score" do |scores|
      scores.collect{|score| 1000 - score.to_i}
    end
    string.unnamed = true

    start_node = "ENSP00000256078"
    end_node = "ENSP00000306245"

    path = Paths.weighted_dijkstra(string, start_node, end_node)

    assert path != nil
    assert path.include? start_node
    assert path.include? end_node
    
    path = Paths.weighted_dijkstra(string, start_node, Set.new([end_node]))

    assert path != nil
    assert path.include? start_node
    assert path.include? end_node
 
  end

  def test_random_weighted_dijsktra
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


