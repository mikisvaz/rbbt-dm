require 'rbbt/vector/model'
require 'rbbt/nlp/spaCy'

class SpaCyModel < VectorModel
  attr_accessor :config

  def self.spacy(&block)
    RbbtPython.run "spacy" do 
      RbbtPython.module_eval(&block)
    end
  end
  
  def initialize(dir, config, categories = %w(positive negative), lang = 'en_core_web_md')
    @config = case
              when Path === config
                config.read
              when Misc.is_filename?(config)
                Open.read(config)
              when (Misc.is_filename?(config, false) && Rbbt.share.spaCy.cpu[config].exists?)
                Rbbt.share.spaCy.cpu[config].read
              when (Misc.is_filename?(config, false) && Rbbt.share.spaCy[config].exists?)
                Rbbt.share.spaCy[config].read
              else
                config
              end
    Log.debug "SpaCy model loading config from: #{@config}"
    @lang = lang

    super(dir)

    @train_model = Proc.new do |features, labels|
      texts = features
      docs = []
      unique_labels = labels.uniq
      tmpconfig = File.join(@model_path, 'config')
      tmptrain = File.join(@model_path, 'train.spacy')
      SpaCy.config(@config, tmpconfig)

      bar = bar(features.length, "Training documents into spacy format")
      SpaCyModel.spacy do
        nlp = SpaCy.nlp(lang)
        docs = []
        RbbtPython.iterate nlp.pipe(texts.zip(labels), as_tuples: true), :bar => bar do |doc,label|
          unique_labels.each do |other_label|
            next if other_label == label
            doc.cats[other_label] = false
          end
          doc.cats[label] = true
          docs << doc
        end

        doc_bin = spacy.tokens.DocBin.new(docs: docs)
        doc_bin.to_disk(tmptrain)
      end

      gpu = Rbbt::Config.get('gpu_id', :spacy, :spacy_train, :default => 0)
      CMD.cmd_log(:spacy, "train #{tmpconfig} --output #{@model_path} --paths.train #{tmptrain} --paths.dev #{tmptrain}",  "--gpu-id" => gpu)
    end
 
    @eval_model = Proc.new do |features,list|
      texts = features
      texts = [texts] unless list

      model_path = @model_path

      docs = []
      bar = bar(features.length, "Evaluating model")
      SpaCyModel.spacy do
        gpu = Rbbt::Config.get('gpu_id', :spacy, :spacy_train, :default => 0)
        gpu = gpu.to_i if gpu && gpu != ""
        spacy.require_gpu(gpu) if gpu
        nlp = spacy.load("#{model_path}/model-best")

        docs = nlp.pipe(texts)
        RbbtPython.collect docs, :bar => bar do |d|
          Misc.timeout_insist(20) do
            d.cats.sort_by{|l,v| v.to_f || 0 }.last.first
          end
        end
      end
    end
  end

end
