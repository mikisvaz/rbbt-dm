require 'rbbt/util/R'

module Heatmap
  def self.heatmap(values, filename, options = {})
    scale, take_log, add_to_height, colors = Misc.process_options options, 
      :scale, :take_log, :add_to_height, :colors

    width = 200 + (values.fields.length * 16)
    height = 200 + (values.length * 16)
    size = [width, height].max
    size = [size, 10000].min

    heatmap_script = <<-EOF 
    #{ take_log ? "data <- log(data)" : ""}
        my.hclust <- function(d){ hclust(d, method="ward") }; 
        my.hclust <- function(d){ hclust(d) }; 
        rbbt.png_plot(
          '#{filename}', 
    #{ size }, 
    #{ (defined?(add_to_height) and not add_to_height.nil?) ? (size + (add_to_height * 16 * [1, (height.to_f / width)].max).to_i) : size }, 
          'heatmap(as.matrix(data),
    #{
    case scale.to_s
    when "true", 'row'
      'scale="row",' 
    when 'column' 
      'scale="column",' 
    when "none", ""
      'scale="none",'
    end
    }
    #{colors.nil? ? "" : "ColSideColors=#{colors},"} 
          hclustfun=my.hclust, 
          )',
          pointsize=12, type='cairo', res=150)
        data = NULL;
    EOF

    values.R heatmap_script
    
    filename
  end

  def self.heatmap2(values, filename, options = {})
    scale, take_log, add_to_height, colors = Misc.process_options options, 
      :scale, :take_log, :add_to_height, :colors

    width = 200 + (values.fields.length * 16)
    height = 200 + (values.length * 16)
    size = [width, height].max
    size = [size, 20000].min

    heatmap_script = <<-EOF 
    library(ggplot2);

    EOF

    values.R heatmap_script
    
    filename
  end

end
