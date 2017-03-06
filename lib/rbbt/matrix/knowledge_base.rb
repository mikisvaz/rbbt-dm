require 'rbbt/matrix'
require 'rbbt/knowledge_base'
require 'rbbt/matrix/barcode'

class KnowledgeBase
  attr_accessor :matrix_registry
  def matrix_registry=(new)
    @matrix_registry = IndiferentHash.setup(new)
  end

  def matrix(name)
    matrix, options = @matrix_registry[name]

    return matrix if RbbtMatrix === matrix

    Path.setup(matrix) if not Path === matrix and File.exists? matrix

    raise "Registered matrix is strange: #{Misc.fingerprint matrix}" unless Path === matrix

    path = matrix

    raise "Registered path not found: #{path.find}" unless path.exists?
    
    if path.find.directory?
      data, labels, value_type, format, organism, identifiers = Misc.process_options options, :data, :labels, :value_type, :format, :organism, :identifiers 

      data ||= path.data if path.data.exists?
      data ||= path.values if path.values.exists?

      labels ||= path.labels if path.labels.exists?
      labels ||= path.samples if path.samples.exists?

      identifiers ||= path.identifiers if path.identifiers.exists?

      value_type = TSV.parse_header(data.find).key_field if data
      value_type ||= "Unknown ID"

      RbbtMatrix.new data, labels, value_type, format, organism, identifiers
    else
    end
  end

  def register_matrix(name, matrix, options = {})
    options = Misc.add_defaults options, :sample_format => "Sample"
    sample_format = Misc.process_options options, :sample_format

    @matrix_registry ||= IndiferentHash.setup({})
    @matrix_registry[name] = [matrix, options]


    register name do
      matrix = matrix(name)
      TSV.read_matrix matrix.data_file, sample_format
    end

    register name.to_s + '_activity' do
      matrix = matrix(name)
      TmpFile.with_file do |tmpfile|
        matrix.activity_cluster(tmpfile)
        tsv = TSV.open(TSV.read_matrix(tmpfile, sample_format))
        tsv.identifiers ||= matrix.data_file.identifier_files.first
        tsv.identifiers = tsv.identifiers.find if tsv.identifiers.respond_to? :find
        
        tsv = tsv.add_field "Activity" do |k,p|
          samples, values = p
          values = values.collect{|v| v.to_i }
          new_values = case Misc.max(values) 
                       when 1
                         [''] * samples.length
                       when 2
                         values.collect{|v| v == 2 ? "active" : '' }
                       else
                         values.collect{|v|
                           case v
                           when 1
                             "inactive"
                           when 2
                             ''
                           else
                             "active"
                           end
                         }
          end
        end

        tsv
      end
    end
  end

end
  
