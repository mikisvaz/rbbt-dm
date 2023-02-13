require 'rbbt/vector/model/huggingface'
class MaskedLMModel < HuggingfaceModel

  def initialize(checkpoint, dir = nil, model_options = {})
    
    model_options = Misc.add_defaults model_options, :max_length => 128
    super("MaskedLM", checkpoint, dir, model_options)

    train_model do |texts,labels|
      model, tokenizer = self.init
      max_length = @model_options[:max_length]
      mask_id = tokenizer.mask_token_id

      dataset = []
      texts.zip(labels).each do |text,label_values|
        fixed_text = text.gsub("[MASK]", "[PENDINGMASK]")
        label_tokens = label_values.collect{|label| tokenizer.convert_tokens_to_ids(label) }
        label_tokens.each do |ids|
          ids = [ids] unless Array === ids
          fixed_text.sub!("[PENDINGMASK]", "[MASK]" * ids.length)
        end

        tokenized_text = tokenizer.call(fixed_text, truncation: true, padding: "max_length")
        input_ids = tokenized_text["input_ids"].to_a
        attention_mask = tokenized_text["attention_mask"].to_a

        all_label_tokens = label_tokens.flatten
        label_ids = input_ids.collect do |id|
          if id == mask_id
            all_label_tokens.shift
          else
            -100
          end
        end
        dataset << {input_ids: input_ids, labels: label_ids, attention_mask: attention_mask}
      end

      dataset_file = File.join(@directory, 'dataset.json')
      Open.write(dataset_file, dataset.collect{|e| e.to_json} * "\n")

      training_args_obj = RbbtPython.call_method("rbbt_dm.huggingface", :training_args, @model_path, @model_options[:training_args])
      data_collator = RbbtPython.class_new_obj("transformers", "DefaultDataCollator", {}) 
      RbbtPython.call_method("rbbt_dm.huggingface", :train_model, model, tokenizer, training_args_obj, dataset_file, @model_options[:class_weights], data_collator: data_collator)

      model.save_pretrained(@model_path) if @model_path
      tokenizer.save_pretrained(@model_path) if @model_path
    end

  end
end
