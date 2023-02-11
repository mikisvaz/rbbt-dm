require File.join(File.expand_path(File.dirname(__FILE__)),'../../..', 'test_helper.rb')
require 'rbbt/vector/model/huggingface'

class TestHuggingface < Test::Unit::TestCase

  def test_options
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"
      task = "SequenceClassification"

      model = HuggingfaceModel.new task, checkpoint, dir, :class_labels => %w(bad good)
      iii model.eval "This is dog"
      iii model.eval "This is cat"
      iii model.eval(["This is dog", "This is cat"])

      model = VectorModel.new dir
      iii model.eval(["This is dog", "This is cat"])
    end
  end

  def test_pipeline
    require 'rbbt/util/python'
    model = VectorModel.new
    model.post_process do |elements|
      elements.collect{|e| e['label'] }
    end
    model.eval_model do |elements|
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

      model.model_options[:class_labels] = ["Bad", "Good"]

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])
    end
  end


  def test_sst_train
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir, max_length: 128

      model.model_options[:class_labels] = %w(Bad Good)

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

      100.times do
        model.add "Dog is good", "Good"
      end

      model.train

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

      model = VectorModel.new dir
      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])
    end
  end

  def test_sst_train_with_labels
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir

      model.model_options[:class_labels] = %w(Bad Good)

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

      100.times do
        model.add "Dog is good", "Good"
      end

      model.train

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

      model = VectorModel.new dir
      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])
    end
  end


  def test_sst_train_no_save
    checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

    model = HuggingfaceModel.new "SequenceClassification", checkpoint
    model.model_options[:class_labels] = ["Bad", "Good"]

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
      model.model_options[:class_labels] = ["Bad", "Good"]

      assert_equal ["Bad", "Good"], model.eval(["This is dog", "This is cat"])

      100.times do
        model.add "Dog is good", "Good"
      end

      model.train

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

      model_path = model.model_path

      model = HuggingfaceModel.new "SequenceClassification", model_path
      model.model_options[:class_labels] = ["Bad", "Good"]

      assert_equal ["Good", "Good"], model.eval(["This is dog", "This is cat"])

      model = VectorModel.new dir

      assert_equal "Good", model.eval("This is dog")

    end
  end

  def test_sst_stress_test
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir

      model.eval "This is dog"

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

  def test_mask_eval_tokenizer
    checkpoint = "bert-base-uncased"

    model = HuggingfaceModel.new "MaskedLM", checkpoint
    model.eval ["Hi [MASK]"]

    mod, tokenizer = model.init


    orig =  tokenizer.call("Hi [GENE]")["input_ids"]
    tokenizer.add_tokens(["[GENE]"])
    mod.resize_token_embeddings(tokenizer.__len__)
    new =  tokenizer.call("Hi [GENE]")["input_ids"]

    assert orig.length > new.length
  end


  def test_custom_class
    TmpFile.with_file do |dir|
      Open.write File.join(dir, "mypkg/__init__.py"), ""

      Open.write File.join(dir, "mypkg/mymodel.py"), <<~EOF

# Esta clase es igual que la de RobertaForTokenClassification
# Importamos los métodos necesarios
import torch.nn as nn
from transformers import RobertaConfig
from transformers.modeling_outputs import TokenClassifierOutput
from transformers.models.roberta.modeling_roberta import RobertaModel, RobertaPreTrainedModel

# Creamos una clase que herede de RobertaPreTrainedModel
class RobertaForTokenClassification_NER(RobertaPreTrainedModel):
  config_class = RobertaConfig

  def __init__(self, config):
    # Se usa para inicializar el modelo Roberta
    super().__init__(config)
    # Numero de etiquetas que se van a clasificar (sería el número de etiquetas del corpus*2)
    # Una correspondiente a la etiqueta I y otra a la B.
    self.num_labels = config.num_labels
    # No incorporamos pooling layer para devolver los hidden states de cada token (no sólo el CLS)
    self.roberta = RobertaModel(config, add_pooling_layer=False)
    self.dropout = nn.Dropout(config.hidden_dropout_prob)
    self.classifier = nn.Linear(config.hidden_size, config.num_labels)
    self.init_weights()

  def forward(self, input_ids = None, attention_mask = None, token_type_ids = None, labels = None, 
              **kwargs):
    # Obtenemos una codificación del input (los hidden states)
    outputs = self.roberta(input_ids, attention_mask = attention_mask,
                           token_type_ids = token_type_ids, **kwargs)
    
    # A la salida de los hidden states le aplicamos la capa de dropout
    sequence_output = self.dropout(outputs[0])
    # Y posteriormente la capa de clasificación.
    logits = self.classifier(sequence_output)
    # Si labels tiene algún valor (lo que se hará durante el proceso de entrenamiento), se calculan las Loss
    # para justar los pesos en el backprop.
    loss = None
    if labels is not None:
      loss_fct = nn.CrossEntropyLoss()
      loss = loss_fct(logits.view(-1, self.num_labels), labels.view(-1))

    return TokenClassifierOutput(loss=loss, logits=logits,
                                 hidden_states=outputs.hidden_states, 
                                 attentions=outputs.attentions)
      EOF

      RbbtPython.add_path dir

      biomedical_roberta = "PlanTL-GOB-ES/bsc-bio-ehr-es-cantemist"
      model = HuggingfaceModel.new "mypkg.mymodel:RobertaForTokenClassification_NER", biomedical_roberta

      model.post_process do |result|
        RbbtPython.numpy2ruby result.predictions
      end

      texto = "El paciente tiene un cáncer del pulmon"
      iii model.eval [texto]
    end
  end

  def test_sst_train_word_embeddings
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir
      model.model_options[:class_labels] = %w(Bad Good)

      mod, tokenizer = model.init

      orig = HuggingfaceModel.get_weights(mod, 'distilbert.embeddings.word_embeddings')
      orig = RbbtPython.numpy2ruby(orig.cpu.detach.numpy)

      100.times do
        model.add "Dog is good", "Good"
      end

      model.train

      new = HuggingfaceModel.get_weights(mod, 'distilbert.embeddings.word_embeddings')
      new = RbbtPython.numpy2ruby(new.cpu.detach.numpy)
      
      diff = []
      new.each_with_index do |row,i|
        diff << i if row != orig[i]
      end

      assert diff.length > 0
    end
  end

  def test_sst_freeze_word_embeddings
    TmpFile.with_file do |dir|
      checkpoint = "distilbert-base-uncased-finetuned-sst-2-english"

      model = HuggingfaceModel.new "SequenceClassification", checkpoint, dir
      model.model_options[:class_labels] = %w(Bad Good)

      mod, tokenizer = model.init

      layer = HuggingfaceModel.freeze_layer(mod, 'distilbert')

      orig = HuggingfaceModel.get_weights(mod, 'distilbert.embeddings.word_embeddings')
      orig = RbbtPython.numpy2ruby(orig.cpu.detach.numpy)

      100.times do
        model.add "Dog is good", "Good"
      end

      model.train

      new = HuggingfaceModel.get_weights(mod, 'distilbert.embeddings.word_embeddings')
      new = RbbtPython.numpy2ruby(new.cpu.detach.numpy)
      
      diff = []
      new.each_with_index do |row,i|
        diff << i if row != orig[i]
      end

      assert diff.length == 0
    end
  end

end

