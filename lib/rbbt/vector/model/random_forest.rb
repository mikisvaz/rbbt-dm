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
  if (class(features[[p]]) == "factor") { 
      features[[p]] = factor(features[[p]], levels=model$forest$xlevels[[p]])
    } 
}
label = predict(model, features);
    EOF
  end
end
