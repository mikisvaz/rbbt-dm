require File.join(File.expand_path(File.dirname(__FILE__)), '../../..', 'test_helper.rb')
require 'rbbt/vector/model/spaCy'
require 'rbbt/vector/model/svm'

class TestSpaCyModel < Test::Unit::TestCase

  def test_spyCy
    TmpFile.with_file() do |dir|
      Log.severity = 0
      FileUtils.mkdir_p dir

      model = SpaCyModel.new(
        dir, 
        "cpu/textcat_efficiency.conf"
      )


      require 'rbbt/tsv/csv'
      url = "https://raw.githubusercontent.com/hanzhang0420/Women-Clothing-E-commerce/master/Womens%20Clothing%20E-Commerce%20Reviews.csv"
      tsv = TSV.csv(Open.open(url))
      tsv = tsv.reorder("Review Text", ["Recommended IND"]).to_single

      good = tsv.select("Recommended IND" => '1')
      bad = tsv.select("Recommended IND" => '0')

      gsize = 200
      bsize = 50
      good.keys[0..gsize-1].each do |text|
        next if text.nil? || text.empty?
        model.add text, 'good'
      end

      bad.keys[0..bsize-1].each do |text|
        model.add text, 'bad'
      end

      model.cross_validation 1

      model = VectorModel.new dir

      assert Misc.counts(model.eval_list(good.keys[0..50]))['good'] > 40
      assert Misc.counts(model.eval_list(bad.keys[0..50]))['bad'] > 40
    end

    def test_svm_spacy

      require 'rbbt/tsv/csv'
      url = "https://raw.githubusercontent.com/hanzhang0420/Women-Clothing-E-commerce/master/Womens%20Clothing%20E-Commerce%20Reviews.csv"
      tsv = TSV.csv(Open.open(url))
      tsv = tsv.reorder("Review Text", ["Recommended IND"]).to_single

      good = tsv.select("Recommended IND" => '1')
      bad = tsv.select("Recommended IND" => '0')

      gsize = 2000
      bsize = 500
      model = SVMModel.new(
        dir
      )

      nlp = RbbtPython.run "spacy" do
        spacy.load('en_core_web_md')
      end

      model.extract_features = Proc.new do |text|
        vs = RbbtPython.run do
          RbbtPython.collect nlp.(text).__iter__ do |token|
            token.vector.tolist()
          end
        end
        length = vs.length

        v = vs.inject(nil){|acc,ev| acc = acc.nil? ? ev : acc.zip(ev).collect{|a,b| a + b } }

        v.collect{|e| e / length }
      end

      TSV.traverse good.keys[0..gsize-1], :type => :array, :bar => true do |text|
        next if text.nil? || text.empty?
        model.add text, '1'
      end

      TSV.traverse bad.keys[0..bsize-1], :type => :array, :bar => true do |text|
        model.add text, '0'
      end

      model.cross_validation

    end
  end

  def test_spyCy_trf
    TmpFile.with_file() do |dir|
      Log.severity = 0
      FileUtils.mkdir_p dir

      model = SpaCyModel.new(
        dir, 
        "gpu/textcat_accuracy.conf"
      )


      require 'rbbt/tsv/csv'
      url = "https://raw.githubusercontent.com/hanzhang0420/Women-Clothing-E-commerce/master/Womens%20Clothing%20E-Commerce%20Reviews.csv"
      tsv = TSV.csv(Open.open(url))
      tsv = tsv.reorder("Review Text", ["Recommended IND"]).to_single

      good = tsv.select("Recommended IND" => '1')
      bad = tsv.select("Recommended IND" => '0')

      gsize = 2000
      bsize = 500
      good.keys[0..gsize-1].each do |text|
        next if text.nil? || text.empty?
        model.add text, '1'
      end

      bad.keys[0..bsize-1].each do |text|
        model.add text, '0'
      end

      model.cross_validation
    end
  end
end

