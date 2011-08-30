require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/vector/model'
require 'rbbt/util/R'
require 'test/unit'

class TestVectorModel < Test::Unit::TestCase

  def test_model
    text =<<-EOF
1 0;1;1
1 1;0;1
1 1;1;1
1 0;1;1
1 1;1;1
0 0;1;0
0 1;0;0
0 0;1;0
0 1;0;0
    EOF

    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir
      model = VectorModel.new(dir)

      model.extract_features = Proc.new{|element|
        element.split(";")
      }

      model.train_model = Proc.new{|model_file,features,labels|
        TmpFile.with_file do |feature_file|
          Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
          Open.write(feature_file + '.class', labels * "\n")
          R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
labels = scan("#{ feature_file }.class", what=numeric());
features = cbind(features, class = labels);
library(e1071)
model = svm(class ~ ., data = features) 
save(model, file="#{ model_file }");
          EOF
        end
      }

      model.eval_model = Proc.new{|model_file,features|
        TmpFile.with_file do |feature_file|
          TmpFile.with_file do |results|
            Open.write(feature_file, features * "\t")
            puts R.run(<<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
library(e1071)
load(file="#{ model_file }")
label = predict(model, features);
cat(label, file="#{results}");
            EOF
            ).read
            Open.read(results)
          end
        end

      }

      text.split(/\n/).each do |line|
        label, features = line.split(" ")
        model.add(features, label)
      end

      model.train

      assert model.eval("1;1;1").to_f > 0.5
      assert model.eval("0;0;0").to_f < 0.5
    end
  end

end
