require 'rbbt/vector/model/torch'

class HuggingfaceModel < TorchModel

  def initialize(task, checkpoint, dir = nil, model_options = {})
    super(dir, nil, model_options)

    @model_options = Misc.add_defaults @model_options, :task => task, :checkpoint => checkpoint

    init_model do 
      checkpoint = @model_path && File.directory?(@model_path) ? @model_path : @model_options[:checkpoint]

      model = RbbtPython.call_method("rbbt_dm.huggingface", :load_model, 
                                     @model_options[:task], checkpoint, **(IndiferentHash.setup(model_options[:model_args]) || {}))

      tokenizer_checkpoint = @model_options[:tokenizer_checkpoint] || checkpoint

      tokenizer = RbbtPython.call_method("rbbt_dm.huggingface", :load_tokenizer, 
                                         @model_options[:task], tokenizer_checkpoint, **(IndiferentHash.setup(model_options[:tokenizer_args]) || {}))

      [model, tokenizer]
    end

    eval_model do |texts,is_list|
      model, tokenizer = self.init

      if is_list || @model_options[:task] == "MaskedLM"
        texts = [texts] if ! is_list

        if @model_options.include?(:locate_tokens)
          locate_tokens = @model_options[:locate_tokens]
        elsif @model_options[:task] == "MaskedLM"
          @model_options[:locate_tokens] = locate_tokens = tokenizer.special_tokens_map["mask_token"] 
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

        dataset_file = TorchModel.text_dataset(tsv_file, texts)
        training_args_obj = RbbtPython.call_method("rbbt_dm.huggingface", :training_args, checkpoint_dir, @model_options[:training_args])

        begin
          RbbtPython.call_method("rbbt_dm.huggingface", :predict_model, model, tokenizer, training_args_obj, dataset_file, locate_tokens)
        ensure
          Open.rm_rf tmpdir if tmpdir
        end
      else
        RbbtPython.call_method("rbbt_dm.huggingface", :eval_model, model, tokenizer, [texts], locate_tokens)
      end
    end

    train_model do |texts,labels|
      model, tokenizer = self.init

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
      dataset_file = HuggingfaceModel.text_dataset(tsv_file, texts, labels, @model_options[:class_labels])

      RbbtPython.call_method("rbbt_dm.huggingface", :train_model, model, tokenizer, training_args_obj, dataset_file, @model_options[:class_weights])

      Open.rm_rf tmpdir if tmpdir

      model.save_pretrained(@model_path) if @model_path
      tokenizer.save_pretrained(@model_path) if @model_path
    end

    post_process do |result,is_list|
      model, tokenizer = self.init

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

                     best.collect{|b| tokenizer.decode(b) } * "|"
                   end
                   Array === locate_tokens ? item_masks : item_masks.first
                 end
               else
                 predictions
               end

      (! is_list || single) && Array === result ? result.first : result
    end


    save_models if @model_path
  end

  def reset_model
    @model, @tokenizer = nil
    Open.rm_rf @model_path
    init
  end
end

