# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: rbbt-dm 1.1.53 ruby lib

Gem::Specification.new do |s|
  s.name = "rbbt-dm".freeze
  s.version = "1.1.53"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Miguel Vazquez".freeze]
  s.date = "2021-06-25"
  s.description = "Data-mining and statistics".freeze
  s.email = "miguel.vazquez@fdi.ucm.es".freeze
  s.extra_rdoc_files = [
    "LICENSE"
  ]
  s.files = [
    "LICENSE",
    "lib/rbbt/expression_old/expression.rb",
    "lib/rbbt/expression_old/matrix.rb",
    "lib/rbbt/expression_old/signature.rb",
    "lib/rbbt/matrix.rb",
    "lib/rbbt/matrix/barcode.rb",
    "lib/rbbt/matrix/differential.rb",
    "lib/rbbt/matrix/knowledge_base.rb",
    "lib/rbbt/ml_task.rb",
    "lib/rbbt/network/paths.rb",
    "lib/rbbt/plots/bar.rb",
    "lib/rbbt/plots/heatmap.rb",
    "lib/rbbt/stan.rb",
    "lib/rbbt/statistics/fdr.rb",
    "lib/rbbt/statistics/fisher.rb",
    "lib/rbbt/statistics/hypergeometric.rb",
    "lib/rbbt/statistics/random_walk.rb",
    "lib/rbbt/statistics/rank_product.rb",
    "lib/rbbt/tensorflow.rb",
    "lib/rbbt/vector/model.rb",
    "lib/rbbt/vector/model/spaCy.rb",
    "lib/rbbt/vector/model/svm.rb",
    "lib/rbbt/vector/model/tensorflow.rb",
    "share/R/MA.R",
    "share/R/barcode.R",
    "share/R/heatmap.3.R",
    "share/spaCy/cpu/textcat_accuracy.conf",
    "share/spaCy/cpu/textcat_efficiency.conf",
    "share/spaCy/gpu/textcat_accuracy.conf",
    "share/spaCy/gpu/textcat_efficiency.conf"
  ]
  s.homepage = "http://github.com/mikisvaz/rbbt-phgx".freeze
  s.rubygems_version = "3.1.4".freeze
  s.summary = "Data-mining and statistics".freeze
  s.test_files = ["test/rbbt/network/test_paths.rb".freeze, "test/rbbt/matrix/test_barcode.rb".freeze, "test/rbbt/statistics/test_random_walk.rb".freeze, "test/rbbt/statistics/test_fisher.rb".freeze, "test/rbbt/statistics/test_fdr.rb".freeze, "test/rbbt/statistics/test_hypergeometric.rb".freeze, "test/rbbt/test_ml_task.rb".freeze, "test/rbbt/vector/test_model.rb".freeze, "test/rbbt/vector/model/test_spaCy.rb".freeze, "test/rbbt/vector/model/test_tensorflow.rb".freeze, "test/rbbt/vector/model/test_svm.rb".freeze, "test/rbbt/test_stan.rb".freeze, "test/test_helper.rb".freeze]

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rbbt-util>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<RubyInline>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<priority_queue_cxx17>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<distribution>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<png>.freeze, [">= 0"])
  else
    s.add_dependency(%q<rbbt-util>.freeze, [">= 0"])
    s.add_dependency(%q<RubyInline>.freeze, [">= 0"])
    s.add_dependency(%q<priority_queue_cxx17>.freeze, [">= 0"])
    s.add_dependency(%q<distribution>.freeze, [">= 0"])
    s.add_dependency(%q<png>.freeze, [">= 0"])
  end
end

