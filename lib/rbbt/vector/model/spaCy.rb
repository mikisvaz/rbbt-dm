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
    @lang = lang

    super(dir)

    @train_model = Proc.new do |file, features, labels|
      texts = features
      docs = []
      unique_labels = labels.uniq
      tmpconfig = File.join(file, 'config')
      tmptrain = File.join(file, 'train.spacy')
      SpaCy.config(@config, tmpconfig)
      SpaCyModel.spacy do
        nlp = SpaCy.nlp(lang)
        docs = []
        RbbtPython.iterate nlp.pipe(texts.zip(labels), as_tuples: true), :bar => "Training documents into spacy format" do |doc,label|
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
      CMD.cmd_log(:spacy, "train #{tmpconfig} --output #{file} --paths.train #{tmptrain} --paths.dev #{tmptrain}",  "--gpu-id" => gpu)
    end
 
    @eval_model = Proc.new do |file, features,list|
      texts = features
      texts = [texts] unless list

      docs = []
      SpaCyModel.spacy do
        nlp = spacy.load("#{file}/model-best")

        docs = nlp.pipe(texts)
        RbbtPython.collect docs do |d|
          d.cats.sort_by{|l,v| v.to_f }.last.first
        end
        #nlp.(docs).cats.collect{|cats| cats.sort_by{|l,v| v.to_f }.last.first }
        #Log::ProgressBar.with_bar texts.length, :desc => "Evaluating documents" do |bar|
        #  texts.collect do |text|
        #    cats = nlp.(text).cats
        #    bar.tick
        #    cats.sort_by{|l,v| v.to_f }.last.first
        #  end
        #end
      end
    end
  end

end
