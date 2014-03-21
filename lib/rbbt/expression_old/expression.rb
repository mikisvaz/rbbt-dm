require 'rbbt'
require 'rbbt/tsv'
require 'rbbt/GE'

module Expression
  extend Workflow

  def self.load_matrix(data_file, identifier_file, identifier_format, organism)
    log :open_data, "Opening data file"
    data = TSV.open(data_file, :type => :double, :unnamed => true)

    organism ||= data.namespace
   
    if not (identifier_file.nil? or identifier_format.nil? or data.key_field == identifier_format)

      case
      when (fields = (TSV.parse_header(Open.open(identifier_file)).fields) and fields.include?(identifier_format))
        log :attach, "Adding #{ identifier_format } from #{ identifier_file }"
        data = data.attach identifier_file, :fields => [identifier_format]
        log :reorder, "Reordering data fields"
        data = data.reorder identifier_format, data.fields.dup.delete_if{|field| field == identifier_format}
      else
        raise "No organism defined and identifier_format did not match available formats" if organism.nil?
        require 'rbbt/sources/organism'
        organism_identifiers = Organism.identifiers(organism)
        data.identifiers = identifier_file
        log :attach, "Adding #{ identifier_format } from #{ organism_identifiers }"
        data = data.attach organism_identifiers, :fields => [identifier_format]
        log :reorder, "Reordering data fields"
        data = data.reorder identifier_format, data.fields.dup.delete_if{|field| field == identifier_format}
        data
      end

      new_data = TSV.setup({}, :key_field => data.key_field, :fields => data.fields, :type => :list, :cast => :to_f, :namespace => organism, :unnamed => true)
      log :averaging, "Averaging multiple values"
      data.with_unnamed do
        data.through do |key, values|
          new_data[key] = values.collect{|list| Misc.mean(list.collect{|v| v.to_f})}
        end
      end

      data = new_data
    else
      log :ready, "Matrix ready"
    end

    data
  end

  def self.average_samples(matrix_file, samples)
    matrix = TSV.open(matrix_file)
    new = TSV.setup({}, :key_field => matrix.key_field, :fields => matrix.fields, :cast => matrix.cast, :namespace => matrix.namespace)
    positions = samples.collect{|sample| matrix.identify_field sample}.compact
    matrix.with_unnamed do
      matrix.through do |key,values|
        new[key] = Misc.mean(values.values_at(*positions).compact)
      end
    end

    new
  end

  def self.differential(matrix_file, main, contrast, log2, two_channel)
    header = TSV.parse_header(Open.open(matrix_file))
    key_field, *fields = header.all_fields
    namespace = header.namespace

    main = main & fields
    contrast = contrast & fields

    if Step === self
      GE.analyze(matrix_file, main, contrast, log2, path, key_field, two_channel)
      TSV.open(path, :type => :list, :cast => :to_f, :namespace => namespace)
    else
      TmpFile.with_file do |path|
        GE.analyze(matrix_file, main, contrast, log2, path, key_field, two_channel)
        TSV.open(path, :type => :list, :cast => :to_f, :namespace => namespace)
      end
    end
  end

  def self.barcode(matrix_file, output_file, factor = 3)
    GE.barcode(matrix_file, output_file, factor)
  end

  def self.top_up(diff_file, cutoff = 0.05)
    TSV.open(diff_file, :cast => :to_f).select("adjusted.p.values"){|p| p > 0 and p < cutoff}
  end

  def self.top_down(diff_file, cutoff = 0.05)
    cutoff = -cutoff
    tsv = TSV.open(diff_file, :cast => :to_f).select("adjusted.p.values"){|p| p < 0 and p > cutoff}
    tsv.each do |key,values|
      tsv[key] = values.collect{|v| v.abs}
    end
    tsv
  end
end

