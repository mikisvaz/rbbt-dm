require 'rbbt-util'
require 'rbbt/sources/organism'

class Matrix

  class << self
    attr_accessor :matrix_dir
    def matrix_dir
      @matrix_dir ||= Rbbt.var.matrices
    end
  end

  attr_accessor :data_file, :labels, :value_type, :format, :organism
  def initialize(data_file, labels, value_type, format, organism=nil, identifiers=nil)
    @data_file = data_file
    @labels = labels
    @value_type = value_type
    @format = format
    @organism = organism 
    @organism ||=  begin
                     TSV.parse_header(@data_file).namespace || "Hsa"
                   end
    @identifiers = identifiers || Organism.identifiers(organism)
  end

  def samples
    @samples ||= TSV.parse_header(@data_file).fields
  end

  def subsets
    @subsets ||= begin
                   subsets = {}
                   case @labels
                   when TSV
                     factors = @labels.fields
                     @labels.through do |sample,values|
                       factors.zip(values).each do |factor,value|
                         subsets[factor] ||= {}
                         subsets[factor][value] ||= []
                         subsets[factor][value] << sample
                       end
                     end
                   when Hash
                     @labels.each do |factor,info|
                       subsets[factors] ||= []
                       info.each do |value, samples|
                         subsets[factors][value] = case samples
                                                   when Array 
                                                     samples
                                                   when String
                                                     samples.split ','
                                                   else
                                                     raise "Format of samples not understood: #{Misc.finguerprint samples}"
                                                   end

                       end
                     end
                   end
                   subsets
                 end
  end

  def comparison(main, contrast, subsets = nil)

    if main.index "="
      main_factor, main_value = main.split "=" 
      raise ParameterException, "Main selection not understood" if subsets[main_factor].nil? or subsets[main_factor][main_value].nil?
      main_samples = subsets[main_factor][main_value].split ','
    else
      main_samples = main.split(/[|,\n]/)
    end

    if contrast
      if contrast.index "="
        contrast_factor, contrast_value = contrast.split "=" 
        raise ParameterException, "Contrast selection not understood" if subsets[contrast_factor].nil? or subsets[contrast_factor][contrast_value].nil?
        contrast_samples = subsets[contrast_factor][contrast_value].split ','
      else
        contrast_samples = contrast.split(/[|,\n]/)
      end
    else
      if subsets and defined? main_factor
        contrast_samples = subsets[main_factor].values.collect{|s| s.split ',' }.flatten.uniq - main_samples
      else
        contrast_samples = samples - main_samples
      end
    end

    [main_samples, contrast_samples]
  end


  def to_gene(identifiers = nil)
    require 'rbbt/tsv/change_id'

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Gene", :dir => Matrix.matrix_dir.values, :no_load => true) do
      identifiers = [Organism.identifiers(organism), @identifiers, identifiers].compact.uniq

      data_file.tsv(:cast => :to_f).change_key("Ensembl Gene ID", :identifiers => identifiers) do |v|
        Misc.mean(v.compact)
      end
    end
    Matrix.new file, labels, value_type, format
  end
end
