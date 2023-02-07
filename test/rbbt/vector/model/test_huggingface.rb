require File.join(File.expand_path(File.dirname(__FILE__)),'../../..', 'test_helper.rb')
require 'rbbt/vector/model/huggingface'

class TestHuggingface < Test::Unit::TestCase

  def test_pipeline
    require 'rbbt/util/python'
    model = VectorModel.new
    model.post_process do |elements|
      elements.collect{|e| e['label'] }
    end
    model.eval_model do |file, elements|
      RbbtPython.run :transformers do 
        classifier ||= transformers.pipeline("sentiment-analysis")
        classifier.call(elements)
      end
    end

    assert_equal ["POSITIVE"], model.eval("I've been waiting for a HuggingFace course my whole life.")
  end

  def test_sst_eval
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir

      model.class_labels = ["Bad", "Good"]

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])
    end
  end


  def test_sst_train
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir
      model.class_labels = ["Bad", "Good"]

      model.training_args.merge! :auto_find_batch_size => true

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

      100.times do
        model.add "Dog is good", 1
      end

      model.train

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])
    end
  end

  def test_sst_train_no_save
    checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

    model = HuggingfaceModel.new "SequenceClassification", checkpoint
    model.class_labels = ["Bad", "Good"]

    assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

    100.times do
      model.add "Dog is good", 1
    end

    model.train

    assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])
  end

  def test_sst_train_save_and_load
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir
      model.class_labels = ["Bad", "Good"]

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

      100.times do
        model.add "Dog is good", 1
      end

      model.train

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir
      model.class_labels = ["Bad", "Good"]

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

      model = HuggingfaceModel.new "SequenceClassification", model.model_file
      model.class_labels = ["Bad", "Good"]

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

    end
  end

  def test_sst_stress_test
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir

      100.times do
        model.add "Dog is good", 1
        model.add "Cat is bad", 0
      end

      Misc.benchmark(10) do
        model.train
      end

      Misc.benchmark 1000 do
        model.eval(["This is good", "This is terrible", "This is dog", "This is cat", "Very different stuff", "Dog is bad", "Cat is good"])
      end
    end
  end

  def test_mask_eval
    checkpoint = "bert-base-uncased"

    model = HuggingfaceModel.new "MaskedLM", checkpoint
    assert_equal 3, model.eval(["Paris is the [MASK] of the France.", "The [MASK] worked very hard all the time.", "The [MASK] arrested the dangerous [MASK]."]).
      reject{|v| v.empty?}.length
  end

end

