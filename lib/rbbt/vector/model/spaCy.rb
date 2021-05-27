require 'rbbt/vector/model'
require 'rbbt/nlp/spaCy'

class SpaCyModel < VectorModel
  attr_accessor :config

  def spacy(&block)
    RbbtPython.run "spacy" do 
      RbbtPython.module_eval(&block)
    end
  end
  
  def initialize(dir, config, lang = 'en_core_web_sm')
    @config = config
    @lang = lang

    super(dir)

    @train_model = Proc.new do |file, features, labels|
      texts = features
      docs = []
      tmpconfig = File.join(file, 'config')
      tmptrain = File.join(file, 'train.spacy')
      SpaCy.config(@config, tmpconfig)
      spacy do
        nlp= spacy.load(lang)
        docs = []
        RbbtPython.iterate nlp.pipe(texts.zip(labels), as_tuples: true), :bar => "Training documents into spacy format" do |doc,label|
          doc.cats["positive"] = %w(1 true).include? label.to_s.downcase
          docs << doc
        end
        doc_bin = spacy.tokens.DocBin.new(docs: docs)
        doc_bin.to_disk(tmptrain)
      end

      CMD.cmd_log(:spacy, "train #{tmpconfig} --output #{file} --paths.train #{tmptrain} --paths.dev #{tmptrain}")
    end
 
    @eval_model = Proc.new do |file, features|
      texts = features

      docs = []
      spacy do
        nlp = spacy.load("#{file}/model-best")

        texts.collect do |text|
          nlp.(text).cats['positive'] > 0.5 ? 1 : 0
        end
      end
    end
  end

end
