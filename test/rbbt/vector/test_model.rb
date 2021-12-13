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
rbbt.require('e1071')
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

  def test_model_list
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

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model = Proc.new{|model_file,features,labels|
        TmpFile.with_file do |feature_file|
          Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
          Open.write(feature_file + '.class', labels * "\n")
          R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
labels = scan("#{ feature_file }.class", what=numeric());
features = cbind(features, class = labels);
rbbt.require('e1071')
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

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        [features, label]
      end

      model.add_list(*Misc.zip_fields(pairs))

      model.train

      assert model.eval("1;1;1").to_f > 0.5
      assert model.eval("0;0;0").to_f < 0.5
    end
  end

  def test_model_list2
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
rbbt.require('e1071')
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

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        [features, label]
      end

      model.add_list(*Misc.zip_fields(pairs))

      model.train

      assert model.eval("1;1;1").to_f > 0.5
      assert model.eval("0;0;0").to_f < 0.5
    end
  end

  def test_model_save
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

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model = Proc.new{|model_file,features,labels|
        TmpFile.with_file do |feature_file|
          Open.write(feature_file, features.collect{|feats| feats * "\t"} * "\n")
          Open.write(feature_file + '.class', labels * "\n")
          R.run <<-EOF
features = read.table("#{ feature_file }", sep ="\\t", stringsAsFactors=FALSE);
labels = scan("#{ feature_file }.class", what=numeric());
features = cbind(features, label = labels);
rbbt.require('e1071')
model = svm(label ~ ., data = features) 
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

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      model.train

      model = VectorModel.new(dir)
      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      assert model.eval("1;1;1").to_f > 0.5
      assert model.eval("0;0;0").to_f < 0.5
    end
  end

  def test_model_name
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

      model.names = %w(Var1 Var2 Var3)

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model =<<-EOF
rbbt.require('e1071')
model = svm(as.factor(label) ~ Var1 + Var2, data = features) 
      EOF

      model.eval_model = <<-EOF
library(e1071)
label = predict(model, features);
      EOF

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      model.train

      assert model.eval("1;1;1").to_f > 0.5
      assert model.eval("0;0;0").to_f < 0.5
    end
  end

  def test_model_cv
    text =<<-EOF
0 0;1;0;0
0 1;0;0;0
0 0;1;0;0
0 1;0;0;0
1 0;1;1;0
1 1;0;1;0
1 1;1;1;0
1 0;1;1;0
1 1;1;1;0
    EOF

    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir
      model = VectorModel.new(dir)

      model.names = %w(Var1 Var2 Var3 Var4)

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model =<<-EOF
rbbt.require('randomForest')
model = randomForest(as.factor(label) ~ ., data = features) 
      EOF

      model.eval_model = <<-EOF
rbbt.require('randomForest')
label = predict(model, features);
      EOF

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      model.train
      
      assert_equal "0", model.eval("1;1;0;0")
      assert_equal "1", model.eval("1;1;1;0")

      Log.with_severity 1 do
        model.cross_validation(2)
      end

    end
  end

  def test_model_mclass
    text =<<-EOF
0 0;1;0;0
0 1;0;0;0
0 0;1;0;0
0 1;0;0;0
1 0;1;1;0
1 1;0;1;0
1 1;1;1;0
1 0;1;1;0
1 1;1;1;0
2 0;1;0;1
2 1;0;0;1
2 1;1;0;1
2 0;1;0;1
2 1;1;0;1
    EOF

    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir
      model = VectorModel.new(dir)

      model.names = %w(Var1 Var2 Var3 Var4)

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model =<<-EOF
rbbt.require('randomForest')
model = randomForest(as.factor(label) ~ ., data = features) 
      EOF

      model.eval_model = <<-EOF
rbbt.require('randomForest')
label = predict(model, features);
      EOF

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      model.train
      
      assert_equal "0", model.eval("1;1;0;0")
      assert_equal "1", model.eval("1;1;1;0")
      assert_equal "2", model.eval("1;1;0;1")

      Log.with_severity 1 do
        model.cross_validation(2)
      end

    end
  end

  def test_model_factor_levels
    text =<<-EOF
0 0;1;0;f1
0 1;0;0;f1
0 0;1;0;f1
0 1;0;0;f1
1 0;1;1;f2
1 1;0;1;f2
1 1;1;1;f2
1 0;1;1;f2
1 1;1;1;f2
    EOF

    TmpFile.with_file() do |dir|
      FileUtils.mkdir_p dir
      model = VectorModel.new(dir)

      model.names = %w(Var1 Var2 Var3 Factor)

      model.extract_features = Proc.new{|element,list|
        if element
          element.split(";")
        elsif list
          list.collect{|e| e.split(";") }
        end
      }

      model.train_model =<<-EOF
rbbt.require('randomForest')
model = randomForest(as.factor(label) ~ ., data = features) 
      EOF

      model.eval_model = <<-EOF
rbbt.require('randomForest')
label = predict(model, features);
      EOF

      pairs = text.split(/\n/).collect do |line|
        label, features = line.split(" ")
        model.add features, label
      end

      Log.with_severity 0 do
        model.train
        model.cross_validation(2)

        assert_raise do
          assert_equal "0", model.eval("1;1;0;f1")
        end

        model.factor_levels = {"Factor" => %w(f1 f2)}
        model.train
        model = VectorModel.new(dir)
        assert_equal "1", model.eval("1;1;1;f2")
      end

    end
  end


end
