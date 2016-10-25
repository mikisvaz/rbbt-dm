require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/matrix'
require 'rbbt/matrix/barcode'

class TestBarcode < Test::Unit::TestCase
  def test_R_barcode
    data = TSV.setup({}, :key_field => "Gene", :fields => %w(S1 S2 S3 S4 S5 S6) , :type => :list)
    data["G1"] = [1,1,1,4,5,6]
    data["G2"] = [1,6,1,6,1,6]
    data["G3"] = [1,1,1,1,6,6]
    data["G4"] = [6,6,1,1,1,1]

    TmpFile.with_file(data.to_s) do |file|
      m = Matrix.new file
      m.barcode(file+'.barcode')
      tsv =  TSV.open(file+'.barcode')
      assert tsv["G2"] = [0,1,0,1,0,1]

      m.barcode_ruby(file+'.barcode_ruby')
      tsv =  TSV.open(file+'.barcode_ruby')
      assert tsv["G2"] = [0,1,0,1,0,1]
    end
  end
end

