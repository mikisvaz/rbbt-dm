require 'rbbt-util'
require 'rbbt/sources/organism'

class Matrix

  class << self
    attr_accessor :matrix_dir
    def matrix_dir
      @matrix_dir ||= Rbbt.var.matrices
    end
  end

  attr_accessor :data_file, :labels, :value_type, :format, :organism, :identifiers
  def initialize(data_file, labels, value_type, format, organism=nil, identifiers=nil)
    @data_file = data_file
    @labels = labels
    @value_type = value_type
    @format = format
    @format ||=  begin
                   _header ||= TSV.parse_header(@data_file)
                   _header.key_field || "ID"
                 end
    @organism = organism 
    _header = nil
    @organism ||=  begin
                     _header ||= TSV.parse_header(@data_file)
                     _header.namespace || Organism.default_code("Hsa")
                   end
    @identifiers = identifiers 
  end

  def samples
    @samples ||= TSV.parse_header(@data_file).fields
  end

  def subsets=(subsets)
    @subsets = subsets
  end

  def subsets
    @subsets ||= begin
                   subsets = {}
                   case @labels
                   when Path
                     labels = @labels.tsv
                     factors = labels.fields
                     labels.through do |sample,values|
                       factors.zip(values).each do |factor,value|
                         subsets[factor] ||= {}
                         subsets[factor][value] ||= []
                         subsets[factor][value] << sample
                       end
                     end

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
                       subsets[factors] ||= {}
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

                   clean_subsets = {}
                   subsets.each do |factor,values|
                     next if values.nil? or values.size < 2
                     values.each do |level,samples|
                       next if samples.nil? or samples.length < 2
                       clean_subsets[factor] ||= {}
                       clean_subsets[factor][level] = samples
                     end
                   end

                   clean_subsets
                 end
  end

  def comparison(main, contrast, subsets = nil)
    subsets ||= self.subsets

    if main.index "="
      main_factor, main_value = main.split "=" 
      raise ParameterException, "Main selection not understood" if subsets[main_factor].nil? or subsets[main_factor][main_value].nil?
      value = subsets[main_factor][main_value]
      main_samples = String === value ? value.split(',') : value
    else
      main_samples = main.split(/[|,\n]/)
    end

    if contrast
      if contrast.index "="
        contrast_factor, contrast_value = contrast.split "=" 
        raise ParameterException, "Contrast selection not understood" if subsets[contrast_factor].nil? or subsets[contrast_factor][contrast_value].nil?
        value = subsets[contrast_factor][contrast_value]
        contrast_samples = String === value ? value.split(',') : value
      else
        contrast_samples = contrast.split(/[|,\n]/)
      end
    else
      if subsets and main_factor
        contrast_samples = subsets[main_factor].values.flatten.collect{|s| s.split ',' }.flatten.uniq - main_samples
      else
        contrast_samples = samples - main_samples
      end
    end
    main_samples = main_samples.compact.reject{|m| m.empty? }.collect{|m| m.strip }
    contrast_samples = contrast_samples.compact.reject{|m| m.empty? }.collect{|m| m.strip }

    [main_samples, contrast_samples]
  end


  def to_gene(identifiers = nil)
    require 'rbbt/tsv/change_id'

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Gene", :dir => Matrix.matrix_dir.values, :no_load => true) do

      data = data_file.tsv(:cast => :to_f)

      identifiers = [identifiers, @identifiers, data.identifiers, Organism.identifiers(organism)].flatten.compact.uniq

      data.change_key("Ensembl Gene ID", :identifiers => identifiers.reverse) do |v|
        Misc.mean(v.compact)
      end
    end
    subsets = self.subsets
    matrix = Matrix.new file, labels, value_type, "Ensembl Gene ID", organism
    matrix.subsets = subsets
    matrix
  end

  def tsv(to_gene=true, identifiers = nil)
    if to_gene
      file =  self.to_gene(identifiers).data_file
      file.tsv :persist => true, :persist_dir => Matrix.matrix_dir.persist, :type => :double, :merge => true, :cast => nil
    else
      self.data_file.tsv :persist => true, :persist_dir => Matrix.matrix_dir.persist, :type => :double, :merge => true, :cast => nil
    end
  end

end
