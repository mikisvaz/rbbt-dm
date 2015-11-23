require 'rbbt/util/R'

class Matrix
  def differential(main, contrast, path = nil)
    all_samples = self.samples
    if Array === main and Array === contrast
      main_samples, contrast_samples = main, contrast
    else
      main_samples, contrast_samples = comparison main, contrast
    end

    name = data_file =~ /:>/ ? File.basename(data_file) : data_file
    main_samples = main_samples & all_samples
    contrast_samples = contrast_samples & all_samples
    Persist.persist(name, :tsv, :persist => :update, :file => path,
                    :other => {:main => main_samples, :contrast => contrast_samples}, 
                    :prefix => "Diff", :dir => Matrix.matrix_dir.differential, :no_load => true) do |file|

      raise if file.nil?

      case value_type
      when 'two_channel'
        log2 = true
        trend = false
        two_channel = true
      when nil, 'count', 'counts'
        log2 = true
        trend = false
        two_channel = false
      when 'fpkm'
        log2 = true
        trend = true
        two_channel = false
      when 'log2 ratio', 'transformed count'
        log2 = false
        trend = false
        two_channel = false
      else
        Log.warn "Unkown value_type: #{value_type}"
        log2 = true
        trend = false
        two_channel = false
      end

      file = file.find if Path === file
      FileUtils.mkdir_p File.dirname(file) unless file.nil? or File.exists? File.dirname(file)

      cmd = <<-EOS

source('#{Rbbt.share.R["MA.R"].find}')

data = rbbt.dm.matrix.differential(#{ R.ruby2R data_file }, 
  main = #{R.ruby2R(main_samples)}, 
  contrast = #{R.ruby2R(contrast_samples)}, 
  log2=#{ R.ruby2R log2 }, 
  outfile = #{R.ruby2R file}, 
  key.field = #{R.ruby2R format}, 
  two.channel = #{R.ruby2R two_channel},
  namespace = #{R.ruby2R organism},
  eBayes.trend = #{R.ruby2R trend}
  )
        EOS

        R.run(cmd, :monitor => true)
    end
  end
end


#def self.analyze(datafile,  main, contrast = nil, log2 = false, outfile = nil, key_field = nil, two_channel = nil)
#  FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
#  GE.run_R("rbbt.GE.process(#{ R.ruby2R datafile }, main = #{R.ruby2R(main, :strings => true)}, contrast = #{R.ruby2R(contrast, :strings => true)}, log2=#{ R.ruby2R log2 }, outfile = #{R.ruby2R outfile}, key.field = #{R.ruby2R key_field}, two.channel = #{R.ruby2R two_channel})")
#end
#def self.barcode(datafile, outfile, factor = 2)
#  FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
#  GE.run_R("rbbt.GE.barcode(#{ R.ruby2R datafile }, #{ R.ruby2R outfile }, #{ R.ruby2R factor })")
#end
