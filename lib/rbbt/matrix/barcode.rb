require 'rbbt/util/R'

class Matrix
  def barcode(outfile, factor = 2)

    FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
    cmd =<<-EOF
source('#{Rbbt.share.R['barcode.R'].find}')
rbbt.GE.barcode(#{ R.ruby2R self.data_file }, #{ R.ruby2R outfile }, #{ R.ruby2R factor })
    EOF

    R.run(cmd)
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
