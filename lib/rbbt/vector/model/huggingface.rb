require 'rbbt/vector/model'
require 'rbbt/util/python'

RbbtPython.init_rbbt

class HuggingfaceModel < VectorModel

  attr_accessor :checkpoint, :task, :locate_tokens, :class_labels

  def tsv_dataset(tsv_dataset_file, elements, labels = nil)

    if labels
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

  def call_method(name, *args)
    RbbtPython.import_method("rbbt_dm.huggingface", name).call(*args)
  end

  def input_tsv_file
    File.join(@directory, 'dataset.tsv') if @directory
  end

  def checkpoint_dir
    File.join(@directory, 'checkpoints') if @directory
  end

  def run_model(elements, labels = nil)
    TmpFile.with_file do |tmpfile|
      tsv_file = input_tsv_file || File.join(tmpfile, 'dataset.tsv')
      output_dir = checkpoint_dir || File.join(tmpfile, 'checkpoints')

      Open.mkdir File.dirname(output_dir)
      Open.mkdir File.dirname(tsv_file)

      if labels
        training_args = call_method(:training_args, output_dir)
        call_method(:train_model, @model, @tokenizer, training_args, tsv_dataset(tsv_file, elements, labels))
      else
        if Array === elements
          training_args = call_method(:training_args, output_dir)
          call_method(:predict_model, @model, @tokenizer, training_args, tsv_dataset(tsv_file, elements), @locate_tokens)
        else
          call_method(:eval_model, @model, @tokenizer, [elements], @locate_tokens)
        end
      end
    end
  end

  def initialize(task, initial_checkpoint = nil, *args)
    super(*args)
    @task = task

    @checkpoint = model_file && File.exists?(model_file)? model_file : initial_checkpoint

    @model, @tokenizer = call_method(:load_model_and_tokenizer, @task, @checkpoint)

    @locate_tokens = @tokenizer.special_tokens_map["mask_token"]  if @task == "MaskedLM"

    train_model do |file,elements,labels|
      run_model(elements, labels)

      @model.save_pretrained(file) if file
      @tokenizer.save_pretrained(file) if file
    end

    eval_model do |file,elements|
      run_model(elements)
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

      result = case @task
               when "SequenceClassification"
                 RbbtPython.collect(predictions) do |logits|
                   logits = RbbtPython.numpy2ruby logits
                   best_class = logits.index logits.max
                   best_class = @class_labels[best_class] if @class_labels
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
                   Array === @locate_tokens ? item_masks : item_masks.first
                 end
               else
                 logits
               end

      single ? result.first : result
    end
  end
end

if __FILE__ == $0

end
