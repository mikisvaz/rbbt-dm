require 'png'
require 'rbbt/util/misc'

module BarPlot

  COLORS = {
    :red =>   PNG::Color::Red,
    :green => PNG::Color::Green,
    :blue => PNG::Color::Blue,
    :white => PNG::Color::White,
    :black => PNG::Color::Black,
    :gray => PNG::Color::Gray,
    :yellow => PNG::Color::Yellow,
  }

  def self.get_color(color)
    return color if PNG::Color === color
    return COLORS[color] if COLORS.include? color
    PNG::Color.from(color)
  end

  def self.gradient_color(values, options = {})
    options = Misc.add_defaults options, :start_color => :green, :end_color => :red, :missing_color => :blue
    start_color, end_color, missing_color = Misc.process_options options, :start_color, :end_color, :missing_color

    start_color = get_color start_color 
    end_color = get_color end_color
    
    max = values.reject{|v| v.nan? || v.infinite?}.max
    min = values.reject{|v| v.nan? || v.infinite?}.min

    case
    when (max.nil? or min.nil?)
      return [missing_color] * values.length 
    when max == min
      return [end_color] * values.length 
    else
      diff = max - min

      r_start = start_color.r
      g_start = start_color.g
      b_start = start_color.b

      r_end = end_color.r
      g_end = end_color.g
      b_end = end_color.b

      values.collect{|v|
        if v.infinite? or v.nan?
          missing_color
        else
          ratio = (255 * (v - min)) / diff
          r = (r_start.to_f * (1-ratio) + (r_end.to_f * ratio)).to_i
          b = (b_start.to_f * (1-ratio) + (b_end.to_f * ratio)).to_i
          g = (g_start.to_f * (1-ratio) + (g_end.to_f * ratio)).to_i
          PNG::Color.new(r, g, b)
        end
      }
    end
  end

  def self.draw_hits_on_canvas(hits, total, canvas, color = PNG::Color::Black)
    width = canvas.width
    height = canvas.height

    # fix hits
    hits = hits.collect{|h| h - 1} # make it start at 0

    if width < total
      hits = hits.collect{|h| (h.to_f * width / total).floor}
    end

    if Array === color
      hits.zip(color).each{|hit, color|
        canvas.line hit, 0, hit , height - 1, get_color(color)
      }
    else
      color = get_color color
      hits.each{|hit|
        canvas.line hit, 0, hit , height - 1, color
      }
    end

    canvas
  end

  def self.draw_sections_on_canvas(ranges, total, canvas, color = PNG::Color::Black)
    width = canvas.width
    height = canvas.height

    # fix hits
    ranges = ranges.collect{|r| (r.begin-1..r.end)} # make it start at 0

    if width < total
      ratio = width.to_f / total
      ranges = ranges.collect{|range| ((range.begin.to_f*ratio).floor..(range.end.to_f*ratio).floor)} # make it start at 0
    end

    if Array === color
      ranges.zip(color).each{|range, color|
        range.each do |hit|
          canvas.line hit, 0, hit , height - 1, get_color(color)
        end
      }
    else
      color = get_color color
      ranges.each{|range|
        range.each do |hit|
          canvas.line hit, 0, hit , height - 1, color
        end
      }
    end

    canvas
  end

  MAX_WIDTH = 2000
  def self.get_canvas(options = {})
    options = Misc.add_defaults options, :width => [options[:total], MAX_WIDTH].min, :height => 20, :background => PNG::Color::White
    width, height, background, canvas = Misc.process_options options, :width, :height, :background, :canvas

    canvas ||= if options[:update] and options[:filename] and File.exists? options[:filename]
                 PNG.load_file options[:filename]
               else
                 PNG::Canvas.new width, height, get_color(background) 
               end
  end

  def self.draw(items, total, options = {})
    options = options.merge :total => total
    canvas = get_canvas(options)
    items = [items] if Range === items
    return canvas if items.empty? and options[:filename].nil?

    color = options.delete(:color) || PNG::Color::Black
    if Range === items.first
      draw_sections_on_canvas(items, total, canvas, color)
    else
      draw_hits_on_canvas(items, total, canvas, color)
    end

    case options[:filename]
    when :string
      PNG.new(canvas).to_blob
    when nil
      canvas
    else
      PNG.new(canvas).save options[:filename]
    end
  end
end

