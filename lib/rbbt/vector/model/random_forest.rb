require 'rbbt/vector/model'
class RFModel < VectorModel
  def initialize(dir)
    super(dir)

    @extract_features = Proc.new{|element|
      element
    }

    @train_model =<<-EOF
rbbt.require("randomForest");
model = randomForest(as.factor(label) ~ ., data = features);
    EOF
 
    @eval_model =<<-EOF
rbbt.require("randomForest");
pred = names(model$forest$xlevels)
for (p in pred) { 
  if (is.factor(features[[p]])) { 
      features[[p]] = factor(features[[p]], levels=model$forest$xlevels[[p]])
    } 
}
label = predict(model, features);
    EOF
  end

  def importance
    TmpFile.with_file do |tmp|
      tsv = R.run <<-EOF
load(file="#{model_file}");
rbbt.tsv.write('#{tmp}', model$importance)
      EOF
      TSV.open(tmp)
    end
  end
end
