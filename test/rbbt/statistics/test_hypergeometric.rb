require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/statistics/hypergeometric'
require 'test/unit'

class TestCmd < Test::Unit::TestCase

  def test_hypergeometric
    assert Hypergeometric.hypergeometric(100, 20, 15,13) < 0.05
  end

  def test_annotation_counts
     content =<<-EOF
#Id    ValueA    ValueB    OtherID
row1    a|aa|aaa    b    Id1|Id2
row2    A    B    Id3
row3    a    C    Id4
    EOF
    
    TmpFile.with_file(content) do |filename|
      tsv = TSV.new(filename + '#:sep=/\s+/')
      counts = tsv.annotation_counts
      assert_equal 2, counts['a']
    end
  end

  def test_enrichment
     content =<<-EOF
#Id    ValueA    ValueB    OtherID
row1    a|aa|aaa    b    Id1|Id2
row2    A    B    Id3
row3    a    C    Id4
row4    A    B    Id3
row5    A    B    Id3
row6    A    B    Id3
row7    A    B    Id3
    EOF
    
    TmpFile.with_file(content) do |filename|
      tsv = TSV.new(filename + '#:sep=/\s+/')
      assert tsv.enrichment(%w(a), "ValueA").collect{|annot,pvalue| pvalue < 0.01 ? annot : nil}.compact
    end
  end
end
