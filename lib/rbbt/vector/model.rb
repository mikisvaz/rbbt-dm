require 'rbbt/util/R'

class VectorModel
  attr_accessor :directory, :model_file, :extract_features, :train_model, :eval_model
  attr_accessor :features, :labels

  def self.R_train(model_file, features, labels, code)
    TmpFile.with_file do |feature_file|
      Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
      Open.write(feature_file + '.class', labels * "\n")

      R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
labels = scan("#{ feature_file }.class");
features = cbind(features, class = labels);
#{code}
save(model, file='#{model_file}')
      EOF
    end
  end

  def self.R_eval(model_file, features, list, code)
    TmpFile.with_file do |feature_file|
      TmpFile.with_file do |results|
        if list
          Open.write(feature_file, features.collect{|feat| feat * "\t"} * "\n" + "\n")
        else
          Open.write(feature_file, features * "\t" + "\n")
        end

        io = R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
load(file="#{model_file}");
#{code}
cat(paste(label, sep="\\n"));
        EOF

        res = io.read.sub(/WARNING: .*?\n/s,'').split(/\s+/).collect{|l| l.to_f}

        if list
          res
        else
          res.first
        end
      end
    end
  end

  def initialize(directory, extract_features = nil, train_model = nil, eval_model = nil)
    @directory = directory
    FileUtils.mkdir_p @directory unless File.exists? @directory
    @model_file = File.join(@directory, "model")
    extract_features = @extract_features 
    train_model = @train_model 
    eval_model = @eval_model
    @features = []
    @labels = []
  end

  def add(element, label = nil)
    @features << extract_features.call(element)
    @labels << label unless label.nil?
  end

  def train
    case 
    when Proc === train_model
      train_model.call(@model_file, @features, @labels)
    when String === train_model
      SVMModel.R_train(@model_file,  @features, @labels, train_model)
    end
  end

  def eval(element)
    case 
    when Proc === eval_model
      eval_model.call(@model_file, extract_features.call(element), false)
    when String === eval_model
      SVMModel.R_eval(@model_file,  extract_features.call(element), false, eval_model)
    end
  end

  def eval_list(elements, extract = true)
    case 
    when Proc === eval_model
      eval_model.call(@model_file, extract ? elements.collect{|element| extract_features.call(element)} : elements, true)
    when String === eval_model
      SVMModel.R_eval(@model_file, extract ? elements.collect{|element| extract_features.call(element)} : elements, true, eval_model)
    end
  end

  def cross_validation(folds = 10)
    saved_features = @features
    saved_labels = @labels
    seq = (0..features.length - 1).to_a

    chunk_size = features.length / folds

    acc = []
    folds.times do
      seq = seq.shuffle
      eval_chunk = seq[0..chunk_size]
      train_chunk = seq[chunk_size.. -1]

      eval_features = @features.values_at *eval_chunk
      eval_labels = @labels.values_at *eval_chunk

      @features = @features.values_at *train_chunk
      @labels = @labels.values_at *train_chunk

      train
      predictions = eval_list eval_features, false

      acc << predictions.zip(eval_labels).collect{|pred,lab| pred - lab < 0.5 ? 1 : 0}.inject(0){|acc,e| acc +=e} / chunk_size

      @features = saved_features
      @labels = saved_labels
    end

    acc
  end
end
