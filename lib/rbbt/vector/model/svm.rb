require 'rbbt/vector/model'
class SVMModel < VectorModel
  def initialize(dir)
    super(dir)

    @extract_features = Proc.new{|element|
      element
    }

    @train_model =<<-EOF
library(e1071);
model = svm(class ~ ., data = features, scale=c(0));
    EOF
 
    @eval_model =<<-EOF
library(e1071);
label = predict(model, features);
    EOF
  end
end
