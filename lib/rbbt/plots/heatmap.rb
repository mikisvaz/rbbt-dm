require 'rbbt/util/R'
require 'rbbt/util/colorize'

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

    width = 1200 + (values.fields.length * 100)
    height = 1000 + (values.length * 50)
    size = [width, height].max
    size = [size, 20000].min
    width = [size, width].min
    height = [size, height].min

    take_log = take_log ? "TRUE" : "FALSE"
    heatmap_script = <<-EOF 
library(ggplot2);
rbbt.heatmap('#{filename}', #{ width }, #{ height }, data, take_log=#{take_log});
    EOF

    values.R heatmap_script
    
    filename
  end

  def self.heatmap3(values, filename, options = {})
    scale, take_log, add_to_height, colors = Misc.process_options options, 
      :scale, :take_log, :add_to_height, :colors

    width = 1200 + (values.fields.length * 100)
    height = 1000 + (values.length * 50)
    size = [width, height].max
    size = [size, 2000].min
    width = [size, width].min
    height = [size, height].min

    take_log = take_log ? "TRUE" : "FALSE"

    map = options.delete :map

    if map
      values = values.slice(map.keys)
      clab = TSV.setup(map.keys, :type => :list, :fields => [], :key_field => map.key_field)

      options[:keys] = []
      options[:colors] = []
      map.fields.each do |field|
        color = Colorize.tsv map.slice(field)
        clab.add_field field do |k, values|
          color[k].to_rgb
        end
        options[:keys] << "" unless options[:keys].empty?
        options[:keys].concat map.values.uniq
        options[:colors] << "#000" unless options[:colors].empty?
        options[:colors].concat color.values_at(*map.keys).collect{|c| c.to_rgb}.uniq
      end

      if options[:keys].length > 20 
        options.delete :keys
        options.delete :colors
      end

      options[:ColSideColors] = clab
    end

    other_params = ", " << options.collect{|k,v| [R.ruby2R(k), R.ruby2R(v)] * "="} * ", " if options.any?

    heatmap_script = <<-EOF 
library(ggplot2, quietly = TRUE, warn.conflicts = TRUE);
source('#{Rbbt.share.R["heatmap.3.R"].find}');

rbbt.heatmap.3('#{filename}', #{ width }, #{ height }, data, take_log=#{take_log}#{other_params});
    EOF

    values.R heatmap_script
    
    filename
  end


end
