require 'rbbt-util'
require 'rbbt/sources/organism'

class RbbtMatrix

  class << self
    attr_accessor :matrix_dir
    def matrix_dir
      @matrix_dir ||= Rbbt.var.matrices
    end
  end

  attr_accessor :data_file, :labels, :value_type, :format, :organism, :identifiers
  def initialize(data_file, labels = nil, value_type = nil, format = nil, organism=nil, identifiers=nil)
    data_file = data_file.find if Path === data_file
    @data_file = data_file
    @labels = labels 
    @value_type = value_type || 'count'
    @format = format
    _header = nil
    @format ||=  begin
                   _header ||= TSV.parse_header(@data_file)
                   _header.key_field || "ID"
                 end
    @organism = organism 
    @organism ||=  begin
                     _header ||= TSV.parse_header(@data_file)
                     _header.namespace || Organism.default_code("Hsa")
                   end
    @identifiers = identifiers 
  end

  def all_fields
    @all_fields ||= TSV.parse_header(@data_file).all_fields
  end

  def fields
    all_fields[1..-1]
  end

  def key_field
    all_fields.first
  end

  def samples
    @samples ||= TSV.parse_header(@data_file)[:fields]
  end

  def subsets=(subsets)
    @subsets = subsets
  end

  def subsets
    @subsets ||= begin
                   subsets = {}
                   case @labels
                   when Path
                     if @labels.exists?
                      labels = @labels.tsv
                      factors = labels.fields
                      labels.through do |sample,values|
                        factors.zip(values).each do |factor,value|
                          subsets[factor] ||= {}
                          subsets[factor][value] ||= []
                          subsets[factor][value] << sample
                        end
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

  def transpose(id = nil)
    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Transpose", :check => [data_file], :other => {:id => id},  :dir => RbbtMatrix.matrix_dir.values, :no_load => true) do

      data = data_file.tsv(:cast => :to_f, :type => :double).transpose(id)

      data.to_list{|v| v.length > 1 ? Misc.mean(v) : v }
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, key_field, organism
    matrix.subsets = subsets
    matrix
  end

  def to_average(identifiers = nil)
    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Average", :check => [data_file],  :dir => RbbtMatrix.matrix_dir.values, :no_load => true) do

      data = data_file.tsv(:cast => :to_f, :type => :double)

      data.to_list{|v| v.length > 1 ? Misc.mean(v) : v }
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, key_field, organism
    matrix.subsets = subsets
    matrix
  end

  def to_gene(identifiers = nil)
    require 'rbbt/tsv/change_id'

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Gene", :check => [data_file], :dir => RbbtMatrix.matrix_dir.values, :no_load => true) do

      data = data_file.tsv(:cast => :to_f)

      identifiers = [identifiers, @identifiers, data.identifiers, Organism.identifiers(organism)].flatten.compact.uniq

      new_data = data.change_key("Ensembl Gene ID", :identifiers => identifiers.reverse) do |v|
        Misc.mean(v.compact)
      end

      new_data.delete ""
      new_data.delete nil

      new_data
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, "Ensembl Gene ID", organism
    matrix.subsets = subsets
    matrix
  end

  def to_name(identifiers = nil)
    require 'rbbt/tsv/change_id'

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Name", :check => [data_file], :dir => RbbtMatrix.matrix_dir.values, :no_load => true) do

      data = data_file.tsv(:cast => :to_f)

      identifiers = [identifiers, @identifiers, data.identifiers, Organism.identifiers(organism)].flatten.compact.uniq

      new_data = data.change_key("Associated Gene Name", :identifiers => identifiers.reverse) do |v|
        Misc.mean(v.compact)
      end

      new_data.delete ""
      new_data.delete nil

      new_data
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, "Associated Gene Name", organism
    matrix.subsets = subsets
    matrix
  end
  def to_barcode_ruby(factor = 2)
    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Barcode #{factor}", :check => [data_file],  :dir => RbbtMatrix.matrix_dir.barcode, :no_load => true) do |filename|
      barcode_ruby(filename, factor)
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, key_field, organism
    matrix.subsets = subsets
    matrix
  end

  def to_barcode(factor = 2)
    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Barcode R #{factor}", :check => [data_file],  :dir => RbbtMatrix.matrix_dir.barcode, :no_load => true) do |filename|
      barcode(filename, factor)
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, key_field, organism
    matrix.subsets = subsets
    matrix
  end

  def to_activity(clusters = 2)
    require 'rbbt/tsv/change_id'

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file

    file = Persist.persist(data_file, :tsv, :prefix => "Activity #{clusters.inspect}", :check => [data_file],  :dir => RbbtMatrix.matrix_dir.barcode, :no_load => true) do |filename|
      activity_cluster(filename, clusters)
    end
    subsets = self.subsets
    matrix = RbbtMatrix.new file, labels, value_type, key_field, organism
    matrix.subsets = subsets
    matrix
  end

  def tsv(to_gene=true, identifiers = nil)
    if to_gene and key_field != "Ensembl Gene ID"
      file =  self.to_gene(identifiers).data_file
      file.tsv :persist => true, :persist_dir => RbbtMatrix.matrix_dir.persist, :type => :double, :merge => true
    else
      self.data_file.tsv :persist => true, :persist_dir => RbbtMatrix.matrix_dir.persist, :merge => true
    end
  end

end
