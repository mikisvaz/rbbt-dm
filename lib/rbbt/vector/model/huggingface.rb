require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.add_path Rbbt.python.find(:lib)
RbbtPython.init_rbbt

class HuggingfaceModel < VectorModel

  def self.tsv_dataset(tsv_dataset_file, elements, labels = nil, class_labels = nil)

    if labels
      labels = case class_labels
               when Array
                 labels.collect{|l| class_labels.index l}
               when Hash
                 inverse_class_labels = {}
                 class_labels.each{|c,l| inverse_class_labels[l] = c }
                 labels.collect{|l| inverse_class_labels[l]}
               else
                 labels
               end

      Open.write(tsv_dataset_file) do |ffile|
        ffile.puts ["label", "text"].flatten * "\t"
        elements.zip(labels).each do |element,label|
          ffile.puts [label, element].flatten * "\t"
        end
      end
    else
      Open.write(tsv_dataset_file) do |ffile|
        ffile.puts ["text"].flatten * "\t"
        elements.each{|element| ffile.puts element }
      end
    end

    tsv_dataset_file
  end

  def initialize(task, checkpoint, *args)
    options = args.pop if Hash === args.last
    options = Misc.add_defaults options, :task => task, :checkpoint => checkpoint
    super(*args)
    @model_options ||= {}
    @model_options.merge!(options)

    eval_model do |directory,texts|
      checkpoint = directory && File.directory?(directory) ? directory : @model_options[:checkpoint]

      if @model.nil?
        @model, @tokenizer = RbbtPython.call_method("rbbt_dm.huggingface", :load_model_and_tokenizer, @model_options[:task], checkpoint)
      end
      
      if Array === texts

        if @model_options.include?(:locate_tokens)
          locate_tokens = @model_options[:locate_tokens]
        elsif @model_options[:task] == "MaskedLM"
          @model_options[:locate_tokens] = locate_tokens = @tokenizer.special_tokens_map["mask_token"] 
        end

        if @directory
          tsv_file = File.join(@directory, 'dataset.tsv')
          checkpoint_dir = File.join(@directory, 'checkpoints')
        else
          tmpdir = TmpFile.tmp_file
          Open.mkdir tmpdir
          tsv_file = File.join(tmpdir, 'dataset.tsv')
          checkpoint_dir = File.join(tmpdir, 'checkpoints')
        end

        dataset_file = HuggingfaceModel.tsv_dataset(tsv_file, texts)
        training_args_obj = RbbtPython.call_method("rbbt_dm.huggingface", :training_args, checkpoint_dir, @model_options[:training_args])

        begin
          RbbtPython.call_method("rbbt_dm.huggingface", :predict_model, @model, @tokenizer, training_args_obj, dataset_file, locate_tokens)
        ensure
          Open.rm_rf tmpdir if tmpdir
        end
      else
        RbbtPython.call_method("rbbt_dm.huggingface", :eval_model, @model, @tokenizer, [texts], locate_tokens)
      end
    end

    train_model do |directory,texts,labels|
      checkpoint = directory && File.directory?(directory) ? directory : @model_options[:checkpoint]
      @model, @tokenizer = RbbtPython.call_method("rbbt_dm.huggingface", :load_model_and_tokenizer, @model_options[:task], checkpoint)

      if @directory
        tsv_file = File.join(@directory, 'dataset.tsv')
        checkpoint_dir = File.join(@directory, 'checkpoints')
      else
        tmpdir = TmpFile.tmp_file
        Open.mkdir tmpdir
        tsv_file = File.join(tmpdir, 'dataset.tsv')
        checkpoint_dir = File.join(tmpdir, 'checkpoints')
      end

      training_args_obj = RbbtPython.call_method("rbbt_dm.huggingface", :training_args, checkpoint_dir, @model_options[:training_args])
      dataset_file = HuggingfaceModel.tsv_dataset(tsv_file, texts, labels, @model_options[:class_labels])

      RbbtPython.call_method("rbbt_dm.huggingface", :train_model, @model, @tokenizer, training_args_obj, dataset_file, @model_options[:class_weights])

      Open.rm_rf tmpdir if tmpdir

      @model.save_pretrained(directory) if directory
      @tokenizer.save_pretrained(directory) if directory
    end

    post_process do |result|
      if result.respond_to?(:predictions)
        single = false
        predictions = result.predictions
      elsif result["token_positions"]
        predictions = result["result"].predictions
        token_positions = result["token_positions"]
      else
        single = true
        predictions = result["logits"]
      end

      task, class_labels, locate_tokens = @model_options.values_at :task, :class_labels, :locate_tokens
      result = case task
               when "SequenceClassification"
                 RbbtPython.collect(predictions) do |logits|
                   logits = RbbtPython.numpy2ruby logits
                   best_class = logits.index logits.max
                   best_class = class_labels[best_class] if class_labels
                   best_class
                 end
               when "MaskedLM"
                 all_token_positions = token_positions.to_a

                 i = 0
                 RbbtPython.collect(predictions) do |item_logits|
                   item_token_positions = all_token_positions[i]
                   i += 1

                   item_logits = RbbtPython.numpy2ruby(item_logits)
                   item_masks = item_token_positions.collect do |token_positions|

                     best = item_logits.values_at(*token_positions).collect do |logits|
                       best_token, best_score = nil
                       logits.each_with_index do |v,i|
                         if best_score.nil? || v > best_score
                           best_token, best_score = i, v
                         end
                       end
                       best_token
                     end

                     best.collect{|b| @tokenizer.decode(b) } * "|"
                   end
                   Array === locate_tokens ? item_masks : item_masks.first
                 end
               else
                 logits
               end

      single ? result.first : result
    end


    save_models if @directory
  end

  def reset_model
    @model, @tokenizer = nil
    Open.rm_rf @model_file
  end

end

