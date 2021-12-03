require 'rbbt/util/R'

class VectorModel
  attr_accessor :directory, :model_file, :extract_features, :train_model, :eval_model
  attr_accessor :features, :names, :labels

  def self.R_run(model_file, features, labels, code, names = nil)
    TmpFile.with_file do |feature_file|
      Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
      Open.write(feature_file + '.label', labels * "\n")
      Open.write(feature_file + '.names', names * "\n") if names


      what = case labels.first
             when Numeric, Integer, Float
               'numeric()'
             else
               'character()'
             end

      R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
labels = scan("#{ feature_file }.label", what=#{what});
features = cbind(features, label = labels);
#{code}
      EOF
    end
  end

  def self.R_train(model_file, features, labels, code, names = nil)
    TmpFile.with_file do |feature_file|
      Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
      Open.write(feature_file + '.label', labels * "\n")
      Open.write(feature_file + '.names', names * "\n") if names

      what = case labels.first
             when Numeric, Integer, Float
               'numeric()'
             else
               'character()'
             end

      R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
labels = scan("#{ feature_file }.label", what=#{what});
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
features = cbind(features, label = labels);
#{code}
save(model, file='#{model_file}')
      EOF
    end
  end

  def self.R_eval(model_file, features, list, code, names = nil)
    TmpFile.with_file do |feature_file|
      if list
        Open.write(feature_file, features.collect{|feat| feat * "\t"} * "\n" + "\n")
      else
        Open.write(feature_file, features * "\t" + "\n")
      end
      Open.write(feature_file + '.names', names * "\n") if names

      TmpFile.with_file do |results|

        io = R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
load(file="#{model_file}");
#{code}
cat(paste(label, sep="\\n", collapse="\\n"));
        EOF
        txt = io.read
        res = txt.sub(/WARNING: .*?\n/s,'').split(/\s+/)

        if list
          res
        else
          res.first
        end
      end
    end
  end

  def __load_method(file)
    code = Open.read(file)
    code.sub!(/.*Proc\.new/, "Proc.new")
    instance_eval code, file
  end

  def initialize(directory, extract_features = nil, train_model = nil, eval_model = nil)
    @directory = directory
    FileUtils.mkdir_p @directory unless File.exists? @directory

    @model_file = File.join(@directory, "model")
    @extract_features_file = File.join(@directory, "features")
    @train_model_file = File.join(@directory, "train_model")
    @eval_model_file = File.join(@directory, "eval_model")
    @train_model_file_R = File.join(@directory, "train_model.R")
    @eval_model_file_R = File.join(@directory, "eval_model.R")

    if extract_features.nil?
      if File.exists?(@extract_features_file)
        @extract_features = __load_method @extract_features_file
      end
    else
      @extract_features = extract_features 
    end

    if train_model.nil?
      if File.exists?(@train_model_file)
        @train_model = __load_method @train_model_file
      elsif File.exists?(@train_model_file_R)
        @train_model = Open.read(@train_model_file_R)
      end
    else
      @train_model = train_model 
    end

    if eval_model.nil?
      if File.exists?(@eval_model_file)
        @eval_model = __load_method @eval_model_file
      elsif File.exists?(@eval_model_file_R)
        @eval_model = Open.read(@eval_model_file_R)
      end
    else
      @eval_model = eval_model
    end

    @features = []
    @labels = []
  end

  def clear
    @features = []
    @labels = []
  end

  def add(element, label = nil)
    features = @extract_features ? extract_features.call(element) : element
    @features << features
    @labels << label 
  end

  def add_list(elements, labels = nil)
    if @extract_features.nil? || @extract_features.arity == 1
      elements.zip(labels || [nil]).each do |elem,label|
        add(elem, label)
      end
    else
      features = @extract_features.call(nil, elements)
      @features.concat  features
      @labels.concat labels if labels
    end
  end

  def save_models
    require 'method_source'

    case 
    when Proc === train_model
      begin
        Open.write(@train_model_file, train_model.source)
      rescue
      end
    when String === train_model
      Open.write(@train_model_file_R, @train_model)
    end

    Open.write(@extract_features_file, @extract_features.source) if @extract_features

    case 
    when Proc === eval_model
      begin
        Open.write(@eval_model_file, eval_model.source)
      rescue
      end
    when String === eval_model
      Open.write(@eval_model_file_R, eval_model)
    end
  end

  def train
    case 
    when Proc === train_model
      train_model.call(@model_file, @features, @labels, @names)
    when String === train_model
      VectorModel.R_train(@model_file,  @features, @labels, train_model, @names)
    end
    save_models
  end

  def run(code)
    VectorModel.R_run(@model_file,  @features, @labels, code, @names)
  end

  def eval(element)
    case 
    when Proc === @eval_model
      @eval_model.call(@model_file, @extract_features.call(element), false, nil, @names)
    when String === @eval_model
      VectorModel.R_eval(@model_file,  @extract_features.call(element), false, eval_model, @names)
    end
  end

  def eval_list(elements, extract = true)

    if extract && ! @extract_features.nil? 
      features = if @extract_features.arity == 1
                   elements.collect{|element| @extract_features.call(element) }
                 else
                   @extract_features.call(nil, elements)
                 end
    else
      features = elements
    end

    case 
    when Proc === eval_model
      eval_model.call(@model_file, features, true, nil, @names)
    when String === eval_model
      VectorModel.R_eval(@model_file, features, true, eval_model, @names)
    end
  end

  #def cross_validation(folds = 10)
  #  saved_features = @features
  #  saved_labels = @labels
  #  seq = (0..features.length - 1).to_a

  #  chunk_size = features.length / folds

  #  acc = []
  #  folds.times do
  #    seq = seq.shuffle
  #    eval_chunk = seq[0..chunk_size]
  #    train_chunk = seq[chunk_size.. -1]

  #    eval_features = @features.values_at *eval_chunk
  #    eval_labels = @labels.values_at *eval_chunk

  #    @features = @features.values_at *train_chunk
  #    @labels = @labels.values_at *train_chunk

  #    train
  #    predictions = eval_list eval_features, false

  #    acc << predictions.zip(eval_labels).collect{|pred,lab| pred - lab < 0.5 ? 1 : 0}.inject(0){|acc,e| acc +=e} / chunk_size

  #    @features = saved_features
  #    @labels = saved_labels
  #  end

  #  acc
  #end

  def cross_validation(folds = 10)

    res = TSV.setup({}, "Fold~TP,TN,FP,FN,P,R,F1#:type=:list")

    orig_features = @features
    orig_labels = @labels

    begin
      feature_folds = Misc.divide(@features, folds)
      labels_folds = Misc.divide(@labels, folds)

      folds.times do |fix|

        rest = (0..(folds-1)).to_a - [fix]

        test_set = feature_folds[fix]
        train_set = feature_folds.values_at(*rest).inject([]){|acc,e| acc += e; acc}

        test_labels = labels_folds[fix]
        train_labels = labels_folds.values_at(*rest).flatten

        tp, fp, tn, fn, pr, re, f1 = [0, 0, 0, 0, nil, nil, nil]

        @features = train_set
        @labels = train_labels
        self.train
        predictions = self.eval_list test_set, false

        raise "Number of predictions (#{predictions.length}) and test labels (#{test_labels.length}) do not match" if predictions.length != test_labels.length

        test_labels.zip(predictions).each do |gs,pred|
          gs = gs.to_s
          pred = pred.to_s

          gs = "1" if gs == "true"
          gs = "0" if gs == "false"
          pred = "1" if pred == "true"
          pred = "0" if pred == "false"

          tp += 1 if gs == pred && gs == "1"
          tn += 1 if gs == pred && gs == "0"
          fp += 1 if gs == "0" && pred == "1"
          fn += 1 if gs == "1" && pred == "0"
        end

        p = tp + fn
        pp = tp + fp

        pr = tp.to_f / pp
        re = tp.to_f / p

        f1 = (2.0 * tp) / (2.0 * tp + fp + fn) 

        Log.debug "CV Fold #{fix} P:#{"%.3f" % pr} R:#{"%.3f" % re} F1:#{"%.3f" % f1} - #{[tp.to_s, tn.to_s, fp.to_s, fn.to_s] * " "}"

        res[fix] = [tp,tn,fp,fn,pr,re,f1]
      end
    ensure
      @features = orig_features
      @labels = orig_labels
    end
    self.train
    res
  end
end
