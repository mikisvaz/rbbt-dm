require 'rbbt/vector/model'
class SVMModel < VectorModel
  def initialize(dir)
    super(dir)

    @extract_features ||= Proc.new{|element|
      element
    }

    @train_model ||=<<-EOF
rbbt.require('e1071');
model = svm(as.factor(label) ~ ., data = features);
    EOF
 
    @eval_model ||=<<-EOF
rbbt.require('e1071');
label = predict(model, features);
    EOF
  end
end
