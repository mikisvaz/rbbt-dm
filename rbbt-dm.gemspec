# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: rbbt-dm 1.1.6 ruby lib

Gem::Specification.new do |s|
  s.name = "rbbt-dm"
  s.version = "1.1.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Miguel Vazquez"]
  s.date = "2014-06-02"
  s.description = "Data-mining and statistics"
  s.email = "miguel.vazquez@fdi.ucm.es"
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
    "lib/rbbt/network/paths.rb",
    "lib/rbbt/plots/bar.rb",
    "lib/rbbt/plots/heatmap.rb",
    "lib/rbbt/statistics/fdr.rb",
    "lib/rbbt/statistics/hypergeometric.rb",
    "lib/rbbt/statistics/random_walk.rb",
    "lib/rbbt/statistics/rank_product.rb",
    "lib/rbbt/vector/model.rb",
    "lib/rbbt/vector/model/svm.rb"
  ]
  s.homepage = "http://github.com/mikisvaz/rbbt-phgx"
  s.rubygems_version = "2.2.2"
  s.summary = "Data-mining and statistics"
  s.test_files = ["test/rbbt/network/test_paths.rb", "test/rbbt/statistics/test_fdr.rb", "test/rbbt/statistics/test_random_walk.rb", "test/rbbt/statistics/test_hypergeometric.rb", "test/rbbt/vector/model/test_svm.rb", "test/rbbt/vector/test_model.rb", "test/test_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rbbt-util>, [">= 0"])
      s.add_runtime_dependency(%q<RubyInline>, [">= 0"])
      s.add_runtime_dependency(%q<priority_queue>, [">= 0"])
      s.add_runtime_dependency(%q<distribution>, [">= 0"])
      s.add_runtime_dependency(%q<png>, [">= 0"])
    else
      s.add_dependency(%q<rbbt-util>, [">= 0"])
      s.add_dependency(%q<RubyInline>, [">= 0"])
      s.add_dependency(%q<priority_queue>, [">= 0"])
      s.add_dependency(%q<distribution>, [">= 0"])
      s.add_dependency(%q<png>, [">= 0"])
    end
  else
    s.add_dependency(%q<rbbt-util>, [">= 0"])
    s.add_dependency(%q<RubyInline>, [">= 0"])
    s.add_dependency(%q<priority_queue>, [">= 0"])
    s.add_dependency(%q<distribution>, [">= 0"])
    s.add_dependency(%q<png>, [">= 0"])
  end
end

