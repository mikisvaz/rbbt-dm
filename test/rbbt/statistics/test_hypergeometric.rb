require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/statistics/hypergeometric'
require 'test/unit'

class TestHypergeometric < Test::Unit::TestCase

  def test_hypergeometric_c
    assert_equal Hypergeometric.hypergeometric_c(2, 1, 1, 1).round(2), 0.5
    assert_equal Hypergeometric.hypergeometric_c(10, 1, 1, 1).round(2), 0.1
  end

  def test_hypergeometric
    assert Hypergeometric.hypergeometric(100, 20, 15, 13) < 0.0005
  end

  def test_annotation_counts
     content =<<-EOF
#Id    ValueA    ValueB    OtherID
row1    a|aa|aaa    b    Id1|Id2
row2    A    B    Id3
row3    a    C    Id4
    EOF
    
    TmpFile.with_file(content) do |filename|
      tsv = TSV.open(filename, :sep => /\s+/)
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
row4    a    B    Id3
row5    a    B    Id3
row6    A    B    Id3
row7    A    B    Id3
    EOF
    
    TmpFile.with_file(content) do |filename|
      tsv = TSV.open(filename, :sep => /\s+/)

      assert_equal %w(a), tsv.enrichment(%w(row1 row3 row4 row5), "ValueA", :fdr => false).collect{|annot, values| pvalue = values.first.first.to_f; pvalue < 0.05 ? annot : nil}.compact
    end
  end

  def test_enrichement_with_background
     content =<<-EOF
#Id    ValueA    ValueB    OtherID
row1    a|aa|aaa    b    Id1|Id2
row2    A    B    Id3
row3    a    C    Id4
row4    a    B    Id3
row5    a    B    Id3
row6    A    B    Id3
row7    A    B    Id3
    EOF
    
    TmpFile.with_file(content) do |filename|
      tsv = TSV.open(filename, :sep => /\s+/)

      assert_equal %w(a), tsv.enrichment(%w(row1 row3 row4 row5), "ValueA", :fdr => false, :background => %w(row1 row2 row3 row4 row5 row6 row7)).collect{|annot, values| pvalue = values.first.first.to_f; pvalue < 0.05 ? annot : nil}.compact
      assert_equal %w(), tsv.enrichment(%w(row1 row3 row4 row5), "ValueA", :fdr => false, :background => %w(row1 row2 row3 row4 row5)).collect{|annot, values| pvalue = values.first.first.to_f; pvalue < 0.05 ? annot : nil}.compact
    end
 
  end
end
