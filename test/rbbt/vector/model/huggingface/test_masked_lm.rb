require File.join(File.expand_path(File.dirname(__FILE__)),'../../../..', 'test_helper.rb')
require 'rbbt/vector/model/huggingface/masked_lm'

class TestMaskedLM < Test::Unit::TestCase
  def test_train_new_word
    TmpFile.with_file do |dir|

      checkpoint = "microsoft/BiomedNLP-PubMedBERT-base-uncased-abstract-fulltext"
      mlm = MaskedLMModel.new checkpoint, dir, tokenizer_args: {max_length: 16, model_max_length: 16}

      mod, tokenizer = mlm.init
      if tokenizer.vocab["[GENE]"].nil?
        tokenizer.add_tokens("[GENE]")
        mod.resize_token_embeddings(tokenizer.__len__)
      end

      100.times do
        mlm.add "This [GENE] is [MASK] on tumor cells.", %w(expressed)
        mlm.add "This [MASK] is expressed.", %w([GENE])
      end

      assert_equal "protein", mlm.eval(["This [MASK] is expressed."])

      mlm.train

      assert_equal "[GENE]", mlm.eval(["This [MASK] is expressed."])
      assert_equal "expressed", mlm.eval(["This [GENE] is [MASK] in tumor cells."])

      mlm = MaskedLMModel.new checkpoint, dir, :max_length => 16
      
      assert_equal "[GENE]", mlm.eval(["This [MASK] is expressed."])
      assert_equal "expressed", mlm.eval(["This [GENE] is [MASK] in tumor cells."])

      mlm = VectorModel.new dir
      
      assert_equal "[GENE]", mlm.eval(["This [MASK] is expressed."])
      assert_equal "expressed", mlm.eval(["This [GENE] is [MASK] in tumor cells."])

    end
  end
end
