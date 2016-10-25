# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: rbbt-dm 1.1.29 ruby lib

Gem::Specification.new do |s|
  s.name = "rbbt-dm".freeze
  s.version = "1.1.29"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Miguel Vazquez".freeze]
  s.date = "2016-10-25"
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
    "lib/rbbt/network/paths.rb",
    "lib/rbbt/plots/bar.rb",
    "lib/rbbt/plots/heatmap.rb",
    "lib/rbbt/statistics/fdr.rb",
    "lib/rbbt/statistics/fisher.rb",
    "lib/rbbt/statistics/hypergeometric.rb",
    "lib/rbbt/statistics/random_walk.rb",
    "lib/rbbt/statistics/rank_product.rb",
    "lib/rbbt/vector/model.rb",
    "lib/rbbt/vector/model/svm.rb",
    "share/R/MA.R",
    "share/R/barcode.R",
    "share/R/heatmap.3.R"
  ]
  s.homepage = "http://github.com/mikisvaz/rbbt-phgx".freeze
  s.rubygems_version = "2.6.6".freeze
  s.summary = "Data-mining and statistics".freeze
  s.test_files = ["test/test_helper.rb".freeze, "test/rbbt/vector/model/test_svm.rb".freeze, "test/rbbt/vector/test_model.rb".freeze, "test/rbbt/network/test_paths.rb".freeze, "test/rbbt/matrix/test_barcode.rb".freeze, "test/rbbt/statistics/test_random_walk.rb".freeze, "test/rbbt/statistics/test_fdr.rb".freeze, "test/rbbt/statistics/test_hypergeometric.rb".freeze, "test/rbbt/statistics/test_fisher.rb".freeze]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rbbt-util>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<RubyInline>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<priority_queue>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<distribution>.freeze, [">= 0"])
      s.add_runtime_dependency(%q<png>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rbbt-util>.freeze, [">= 0"])
      s.add_dependency(%q<RubyInline>.freeze, [">= 0"])
      s.add_dependency(%q<priority_queue>.freeze, [">= 0"])
      s.add_dependency(%q<distribution>.freeze, [">= 0"])
      s.add_dependency(%q<png>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rbbt-util>.freeze, [">= 0"])
    s.add_dependency(%q<RubyInline>.freeze, [">= 0"])
    s.add_dependency(%q<priority_queue>.freeze, [">= 0"])
    s.add_dependency(%q<distribution>.freeze, [">= 0"])
    s.add_dependency(%q<png>.freeze, [">= 0"])
  end
end

