require 'rbbt/util/R'

class Matrix
  def barcode(outfile, factor = 2)

    FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
    cmd =<<-EOF
source('#{Rbbt.share.R['barcode.R'].find}')
rbbt.GE.barcode.mode(#{ R.ruby2R self.data_file }, #{ R.ruby2R outfile }, #{ R.ruby2R factor })
    EOF

    R.run(cmd)
  end

  def barcode_ruby(outfile, factor = 2)
    parser = TSV::Parser.new self.data_file
    dumper = TSV::Dumper.new parser.options.merge(:type => :list, :cast => :to_i)
    dumper.init

    TSV.traverse parser, :into => dumper, :bar => "Barcoding #{self.data_file}" do |key,values|
      clean_values = values.flatten.compact.collect{|v| v.to_f}
      modes = R.eval("rbbt.get.modes(#{R.ruby2R clean_values})$modes")
      mode = Array === modes ? modes.first : modes
      mode_values = clean_values.select{|v| v.to_f <= mode}
      mode_values.concat mode_values.collect{|v| v+mode}
      sd = Misc.sd mode_values 
      if sd.nil?
        [key, [nil] * values.length]
      else
        threshold = mode + sd
        bars = if Array === values.compact.first 
          values.collect do |v|
            Misc.mean(v.compact.collect{|v| v.to_f}) > threshold ? 1 : 0
          end
        else
          values.collect do |v|
            v.to_f > threshold ? 1 : 0
          end
        end
        key = key.first if Array === key
      [key, bars]
      end
    end

    Misc.sensiblewrite(outfile, dumper.stream)
  end

  def activity_cluster(outfile, factor = 2)

    FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
    cmd =<<-EOF
source('#{Rbbt.share.R['barcode.R'].find}')
rbbt.GE.activity_cluster(#{ R.ruby2R self.data_file }, #{ R.ruby2R outfile }, #{R.ruby2R value_type})
    EOF

    R.run(cmd)
  end


end
