require 'rbbt/util/R'
require 'rbbt/vector/model/util'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class VectorModel
  attr_accessor :directory, :model_path, :extract_features, :init_model, :train_model, :eval_model, :post_process, :balance
  attr_accessor :features, :names, :labels, :factor_levels
  attr_accessor :model, :model_options

  def extract_features(&block)
    @extract_features = block if block_given?
    @extract_features
  end

  def init_model(&block)
    @init_model = block if block_given?
    @init_model
  end

  def train_model(&block)
    @train_model = block if block_given?
    @train_model
  end

  def eval_model(&block)
    @eval_model = block if block_given?
    @eval_model
  end

  def init
    @model ||= self.instance_exec &@init_model
  end

  def post_process(&block)
    @post_process = block if block_given?
    @post_process
  end


  def self.R_run(model_path, features, labels, code, names = nil, factor_levels = nil)
    TmpFile.with_file do |feature_file|
      Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
      Open.write(feature_file + '.label', labels * "\n" + "\n")
      Open.write(feature_file + '.names', names * "\n" + "\n") if names


      what = case labels.first
             when Numeric, Integer, Float
               'numeric()'
             else
               'character()'
             end

      R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=TRUE);
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
#{ factor_levels.collect do |name,levels|
    "features[['#{name}']] = factor(features[['#{name}']], levels=#{R.ruby2R levels})"
  end * "\n" if factor_levels }
labels = scan("#{ feature_file }.label", what=#{what});
features = cbind(features, label = labels);
#{code}
      EOF
    end
  end

  def self.R_train(model_path, features, labels, code, names = nil, factor_levels = nil)
    TmpFile.with_file do |feature_file|
      Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
      Open.write(feature_file + '.label', labels * "\n" + "\n")
      Open.write(feature_file + '.names', names * "\n" + "\n") if names

      what = case labels.first
             when Numeric, Integer, Float
               'numeric()'
             else
               'character()'
             end

      R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=TRUE);
labels = scan("#{ feature_file }.label", what=#{what});
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
features = cbind(features, label = labels);
#{ factor_levels.collect do |name,levels|
    "features[['#{name}']] = factor(features[['#{name}']], levels=#{R.ruby2R levels})"
  end * "\n" if factor_levels }
#{code}
# Save used factor levels
factor_levels = c()
for (c in names(features)){
  if (is.factor(features[[c]]))
    factor_levels[c] = paste(levels(features[[c]]), collapse="\t")
}
rbbt.tsv.write("#{model_path}.factor_levels", factor_levels, names=c('Levels'), type='flat')
save(model, file='#{model_path}')
      EOF
    end
  end

  def self.R_eval(model_path, features, list, code, names = nil, factor_levels = nil)
    TmpFile.with_file do |feature_file|
      if list
        Open.write(feature_file, features.collect{|feat| feat * "\t"} * "\n" + "\n")
      else
        Open.write(feature_file, features * "\t" + "\n")
      end
      Open.write(feature_file + '.names', names * "\n" + "\n") if names

      TmpFile.with_file do |results|

        io = R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=TRUE);
#{"names(features) = make.names(readLines('#{feature_file + '.names'}'))" if names }
#{ factor_levels.collect do |name,levels|
    "features[['#{name}']] = factor(features[['#{name}']], levels=#{R.ruby2R levels})"
  end * "\n" if factor_levels }
load(file="#{model_path}");
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
    code.sub!(/.*(\sdo\b|{)/, 'Proc.new\1')
    instance_eval code, file
  end

  def initialize(directory = nil, model_options = {})
    @directory = directory
    @model_options = IndiferentHash.setup(model_options)

    if @directory
      FileUtils.mkdir_p @directory unless File.exist?(@directory)

      @model_path            = File.join(@directory, "model")

      @extract_features_file = File.join(@directory, "features")
      @init_model_path       = File.join(@directory, "init_model")

      @train_model_path      = File.join(@directory, "train_model")
      @train_model_path_R    = File.join(@directory, "train_model.R")

      @eval_model_path       = File.join(@directory, "eval_model")
      @eval_model_path_R     = File.join(@directory, "eval_model.R")

      @post_process_file     = File.join(@directory, "post_process")
      @post_process_file_R   = File.join(@directory, "post_process.R")

      @names_file            = File.join(@directory, "feature_names")
      @levels_file           = File.join(@directory, "levels")
      @options_file          = File.join(@directory, "options.json")

      if File.exist?(@options_file)
        @model_options = JSON.parse(Open.read(@options_file)).merge(@model_options || {})
        IndiferentHash.setup(@model_options)
      end
    end
    
    if extract_features.nil?
      if @extract_features_file && File.exist?(@extract_features_file)
        @extract_features = __load_method @extract_features_file
      end
    else
      @extract_features = extract_features 
    end

    if init_model.nil?
      if @init_model_path && File.exist?(@init_model_path)
        @init_model = __load_method @init_model_path
      end
    else
      @init_model = init_model 
    end

    if train_model.nil?
      if @train_model_path && File.exist?(@train_model_path)
        @train_model = __load_method @train_model_path
      elsif @train_model_path_R && File.exist?(@train_model_path_R)
        @train_model = Open.read(@train_model_path_R)
      end
    else
      @train_model = train_model 
    end

    if eval_model.nil?
      if @eval_model_path && File.exist?(@eval_model_path)
        @eval_model = __load_method @eval_model_path
      elsif @eval_model_path_R && File.exist?(@eval_model_path_R)
        @eval_model = Open.read(@eval_model_path_R)
      end
    else
      @eval_model = eval_model
    end

    if post_process.nil?
      if @post_process_file && File.exist?(@post_process_file)
        @post_process = __load_method @post_process_file
      elsif @post_process_file_R && File.exist?(@post_process_file_R)
        @post_process = Open.read(@post_process_file_R)
      end
    else
      @post_process = post_process
    end


    if names.nil?
      if @names_file && File.exist?(@names_file)
        @names = Open.read(@names_file).split("\n")
      end
    else
      @extract_features = names 
    end

    if factor_levels.nil?
      if @levels_file && File.exist?(@levels_file)
        @factor_levels = YAML.load(Open.read(@levels_file))
      end
      if @model_path && File.exist?(@model_path + '.factor_levels')
        @factor_levels = TSV.open(@model_path + '.factor_levels')
      end
    else
      @factor_levels = factor_levels 
    end

    @features = []
    @labels = []
  end

  def clear
    @features = []
    @labels = []
  end

  def add(element, label = nil)
    features = @extract_features ? self.instance_exec(element, &@extract_features) : element
    @features << features
    @labels << label 
  end

  def add_list(elements, labels = nil)
    if @extract_features.nil? || @extract_features.arity == 1
      case labels
      when nil
        elements.each do |elem|
          add(elem)
        end
      when Array
        elements.zip(labels).each do |elem,label|
          add(elem, label)
        end
      when Hash
        elements.each do |elem|
          label = labels[elem]
          add(elem, label)
        end
      else
        elements.each do |elem|
          add(elem, labels)
        end
      end
    else
      features = self.instance_exec(nil, elements, &@extract_features)
      @features.concat  features
      @labels.concat labels if labels
    end
  end

  def save_models
    require 'method_source'

    case 
    when Proc === train_model
      begin
        Open.write(@train_model_path, train_model.source)
      rescue
      end
    when String === train_model
      Open.write(@train_model_path_R, @train_model)
    end

    Open.write(@extract_features_file, @extract_features.source) if @extract_features
    Open.write(@init_model_path, @init_model.source) if @init_model

    case 
    when Proc === eval_model
      begin
        Open.write(@eval_model_path, eval_model.source)
      rescue
      end
    when String === eval_model
      Open.write(@eval_model_path_R, eval_model)
    end

    case 
    when Proc === post_process
      begin
        Open.write(@post_process_file, post_process.source)
      rescue
      end
    when String === post_process
      Open.write(@post_process_file_R, post_process)
    end

    Open.write(@levels_file, @factor_levels.to_yaml) if @factor_levels
    Open.write(@names_file, @names * "\n" + "\n") if @names
    Open.write(@options_file, @model_options.to_json) if @model_options
  end

  def train
    begin
      if @balance
        @original_features = @features
        @original_labels = @labels
        self.balance_labels
      end

      case 
      when Proc === @train_model
        self.instance_exec(@features, @labels, @names, @factor_levels, &@train_model)
      when String === @train_model
        VectorModel.R_train(@model_path, @features, @labels, train_model, @names, @factor_levels)
      end
    ensure
      if @balance
        @features =  @original_features
        @labels = @original_labels
      end
    end

    save_models if @directory
  end

  def run(code)
    VectorModel.R_run(@model_path,  @features, @labels, code, @names, @factor_levels)
  end

  def eval(element)
    features = @extract_features.nil? ? element : self.instance_exec(element, &@extract_features)

    result = case 
             when Proc === @eval_model
               self.instance_exec(features, false, nil, @names, @factor_levels, &@eval_model)
             when String === @eval_model
               VectorModel.R_eval(@model_path, features, false, eval_model, @names, @factor_levels)
             else
               raise "No @eval_model function or R script"
             end

    result = self.instance_exec(result, false, &@post_process) if Proc === @post_process 

    result
  end

  def eval_list(elements, extract = true)

    if extract && ! @extract_features.nil? 
      features = if @extract_features.arity == 1
                   elements.collect{|element| self.instance_exec(element, &@extract_features) }
                 else
                   self.instance_exec(nil, elements, &@extract_features)
                 end
    else
      features = elements
    end

    result = case 
             when Proc === eval_model
               self.instance_exec(features, true, nil, @names, @factor_levels, &@eval_model)
             when String === eval_model
               VectorModel.R_eval(@model_path, features, true, eval_model, @names, @factor_levels)
             end

    result = self.instance_exec(result, true, &@post_process) if Proc === @post_process 

    result
  end

  def self.f1_metrics(test, predicted, good_label = nil)
    tp, tn, fp, fn, pr, re, f1 = [0, 0, 0, 0, nil, nil, nil]

    labels = (test + predicted).uniq

    if labels.length == 2 || good_label
      good_label = labels.uniq.select{|l| l.to_s == "true"}.first if good_label.nil?
      good_label = labels.uniq.select{|l| l.to_s == "1"}.first if good_label.nil?
      good_label = labels.uniq.sort.first if good_label.nil?
      good_label = good_label.to_s

      test.zip(predicted).each do |gs,pred|
        gs = gs.to_s
        pred = pred.to_s

        tp += 1 if pred == good_label && gs == good_label
        fp += 1 if pred == good_label && gs != good_label
        tn += 1 if pred != good_label && gs != good_label 
        fn += 1 if pred != good_label && gs == good_label
      end

      p = tp + fn
      pp = tp + fp

      pr = tp.to_f / pp
      re = tp.to_f / p

      f1 = (2.0 * tp) / (2.0 * tp + fp + fn) 

      [tp, tn, fp, fn, pr, re, f1]
    else 
      num = labels.length
      acc = []
      labels.each do |good_label|
        values = VectorModel.f1_metrics(test, predicted, good_label)
        tp, tn, fp, fn, pr, re, f1 = values
        Log.debug "Partial CV #{good_label} - P:#{"%.3f" % pr} R:#{"%.3f" % re} F1:#{"%.3f" % f1} - #{[tp.to_s, tn.to_s, fp.to_s, fn.to_s] * " "}"
        acc << values
      end
      Misc.zip_fields(acc).collect{|s| Misc.mean(s)}
    end
  end

  def cross_validation(folds = 10, good_label = nil)

    orig_features = @features
    orig_labels = @labels

    multiclass = @labels.uniq.length > 2

    if multiclass
      res = TSV.setup({}, "Fold~P,R,F1#:type=:list")
    else
      res = TSV.setup({}, "Fold~TP,TN,FP,FN,P,R,F1#:type=:list")
    end

    begin
      if folds == 1
        feature_folds = [@features]
        labels_folds = [@labels]
      else
        feature_folds = Misc.divide(@features, folds)
        labels_folds = Misc.divide(@labels, folds)
      end

      folds.times do |fix|

        if folds == 1
          rest = [fix]
        else
          rest = (0..(folds-1)).to_a - [fix]
        end

        test_set = feature_folds[fix]
        train_set = feature_folds.values_at(*rest).flatten(1)

        test_labels = labels_folds[fix]
        train_labels = labels_folds.values_at(*rest).flatten(1)

        @features = train_set
        @labels = train_labels

        self.reset_model if self.respond_to? :reset_model
        self.train
        predictions = self.eval_list test_set, false

        raise "Number of predictions (#{predictions.length}) and test labels (#{test_labels.length}) do not match" if predictions.length != test_labels.length

        different_labels = test_labels.uniq

        Log.debug do "Accuracy Fold #{fix}: #{(100 * test_labels.zip(predictions).select{|t,p| t == p }.length.to_f / test_labels.length).round(2)}%"  end

        tp, tn, fp, fn, pr, re, f1 = VectorModel.f1_metrics(test_labels, predictions, good_label)

        if multiclass 
          Log.low "Multi-class CV Fold #{fix} - Average P:#{"%.3f" % pr} R:#{"%.3f" % re} F1:#{"%.3f" % f1}"
          res[fix] = [pr,re,f1]
        else
          Log.low "CV Fold #{fix} P:#{"%.3f" % pr} R:#{"%.3f" % re} F1:#{"%.3f" % f1} - #{[tp.to_s, tn.to_s, fp.to_s, fn.to_s] * " "}"
          res[fix] = [tp,tn,fp,fn,pr,re,f1]
        end

      end
    ensure
      @features = orig_features
      @labels = orig_labels
    end unless folds == -1

    if folds != 1
      self.reset_model if self.respond_to? :reset_model
      self.train 
    end

    res
  end
end
