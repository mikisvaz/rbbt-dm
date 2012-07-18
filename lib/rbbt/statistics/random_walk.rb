require 'png'
require 'inline'
require 'set'
require 'rbbt/util/misc'

module RandomWalk

  inline do |builder|

    builder.prefix  <<-EOC_CODE
#include <math.h>
//{{{ Make compatible with 1.9 and 1.8
#ifndef RUBY_19
#ifndef RFLOAT_VALUE
#define RFLOAT_VALUE(v) (RFLOAT(v)->value)
#endif
#ifndef RARRAY_PTR
#define RARRAY_PTR(v) (RARRAY(v)->ptr)
#endif
#ifndef RARRAY_LEN
#define RARRAY_LEN(v) (RARRAY(v)->len)
#endif
#endif
//}}} Make compatible with 1.9 and 1.8
    EOC_CODE


    builder.c_raw_singleton <<-'EOC'
    double weight(int position, int mean){
        double rel_pos = (double) abs(position - mean) / mean; 
        double weight =  0.3 *  0.5 * rel_pos +  0.7 * (exp(30*rel_pos)/exp(30));
        return(weight);
    }
    EOC

    builder.c_singleton <<-'EOC'
    double fast_score_scale(VALUE positions, int total, int missing){
      int idx;

      int mean = total / 2;
      int position;
      double penalty;
      double max_top, max_bottom;
      double total_weights = 0;

      VALUE rel_q = rb_ary_new();
      VALUE rel_l = rb_ary_new();

      rb_ary_push(rel_q,rb_float_new(0));

      // Rescale positions and accumulate weights

      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        position = FIX2INT(rb_ary_entry(positions, idx));

        rb_ary_push(rel_l, rb_float_new((double) position / total));

        total_weights += weight(position, mean);
        rb_ary_push(rel_q, rb_float_new(total_weights));
      }

      // Add penalty for missing genes
      penalty = missing * weight(mean * 0.8, mean);
      total_weights  = total_weights + penalty;

      // Traverse list and get extreme values
      max_top = max_bottom = 0;
      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        double top    = RFLOAT_VALUE(rb_ary_entry(rel_q, idx + 1)) / total_weights -
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));
        double bottom = - (penalty + RFLOAT_VALUE(rb_ary_entry(rel_q, idx))) / total_weights +
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));

        if (top > max_top)       max_top    = top;
        if (bottom > max_bottom) max_bottom = bottom;
      }

     if (max_top > max_bottom) return max_top;
     else                      return -max_bottom;
    }
    EOC

  end


  class << self
    alias score fast_score_scale
  end

  def self.combine(up, down)
    return down if up == 0
    return up if down == 0

    return up - down
    if (up > 0) == (down > 0)
      return 0
    else
      up - down
    end
  end

  def self.score_up_down(up, down, total, missing = 0)
    scores_up   = score(up, total, missing)
    scores_down = score(down, total, missing)

    combine(scores_up, scores_down)
  end

  # Two sided
  def self.permutations(size, total, missing = 0, times = 10000)
    if size == 0
      [0] * times
    else
      (1..times).collect do
        p = Misc.random_sample_in_range(total, size)
        score(p.sort, total, missing).abs
      end
    end
  end

  def self.permutations_up_down(size_up, size_down, total, missing = 0, times = 10000)
    (1..times).collect do
      score_up_down(Array.new(size_up){ (rand * total).to_i }.sort, Array.new(size_down){ (rand * total).to_i }.sort, total, missing).abs
    end
  end

  def self.pvalue(permutations, score)
    score = score.abs
    permutations.inject(0){|acc, per| 
      acc += 1 if per > score
      acc
    }.to_f / permutations.length
  end

  COLORS = {
    :red =>   PNG::Color::Red,
    :green => PNG::Color::Green,
    :white => PNG::Color::White,
    :black => PNG::Color::Black,
    :gray => PNG::Color::Gray,
  }

  def self.draw_hits(hits, total, filename = nil, options = {})
    update = options[:update]

    size = options[:size] || total
    bg_color = options[:bg_color] || :white
    width = options[:width] || 20
    sections = options[:sections] || []

    size = [size, total].min
    canvas = PNG::Canvas.new size, width, COLORS[bg_color] || PNG::Color.from(bg_color)

    hits = hits.collect{|h| h - 1}
    if size < total
      hits = hits.collect{|h| (h.to_f * size / total).to_i}
    end

    sections.each{|color, info|
      start = info[0]
      finish = info[1]
      (start..finish).each{|x|
        (0..width - 1).each{|y|
          canvas[x,y] = COLORS[color]
        }
      }
    }

    hits.each{|hit|
      canvas.line hit, 0, hit , width - 1, PNG::Color::Black
    }

    png = PNG.new canvas

    if filename
      png.save filename
    else
      png.to_blob
    end
  end
end

module OrderedList
  def self.hits(list, set)
    set = Set.new(set) unless Set === set
    hits = []
    list.each_with_index do |e,i|
      hits << i + 1 if set.include? e
    end
    hits
  end

  def self.draw_hits(list, set, filename = nil, options = {})
    hits = OrderedList.hits(list, set)
    RandomWalk.draw_hits(hits, list.length, filename, options)
  end

  def hits(set)
    OrderedList.hits(self, set)
  end

  def draw_hits(set, filename = nil, options = {})
    OrderedList.draw_hits(self, set, filename, options)
  end

  def pvalue(set, options = {})
    set = Set.new(set.compact) unless Set === set
    options = Misc.add_defaults options, :permutations => 10000, :missing => 0
    hits = hits(set)
    score = RandomWalk.score(hits.sort, self.length, 0)
    permutations = RandomWalk.permutations(set.length, self.length, options[:missing], options[:permutations])
    RandomWalk.pvalue(permutations, score)
  end

  def pvalue_inline(set, cutoff, options = {})
    set = Set.new(set.compact) unless Set === set
    options = Misc.add_defaults options, :permutations => 10000, :missing => 0
    permutations, missing = Misc.process_options options, :permutations, :missing

    hits = hits(set)

    return 1.0 if hits.empty?

    target_score = RandomWalk.score(hits.sort, self.length, 0)

    max = (permutations.to_f * cutoff).ceil

    size = set.length
    total = self.length
    better_permutation_score_count = 0
    if size == 0
      1.0
    else
      (1..permutations).each do
        p = Set.new

        if size > total / 10
          template = (0..total - 1).to_a
          size.times do |i|
            pos = (rand * total - i).floor
            v, template[pos] = template[pos], template[-1]
          end
        else
          size.times do 
            pos = nil
            while pos.nil? 
              pos = (rand * total).floor
              if p.include? pos
                pos = nil
              end
            end
            p << pos
          end
        end

        permutation_score = RandomWalk.score(p.sort, total, missing).abs
        if permutation_score > target_score
          better_permutation_score_count += 1
        end

        return 1.0 if better_permutation_score_count > max
      end
      better_permutation_score_count.to_f / permutations
    end
  end
end

module TSV

  def self.rank_enrichment_for_list(list, hits, options = {})
    cutoff = Misc.process_options options, :cutoff
    list.extend OrderedList
    if cutoff
      list.pvalue_inline(hits, cutoff, options)
    else
      list.pvalue(hits, options)
    end
  end

  def self.rank_enrichment(tsv, list, options = {})
    if tsv.fields
      res = TSV.setup({}, :cast => :to_f, :type => :double, :key_field => tsv.key_field, :fields => ["p-value", tsv.fields.first]) 
    else
      res = TSV.setup({}, :cast => :to_f, :type => :double) 
    end

    tsv.with_monitor do
      tsv.with_unnamed do
        tsv.through do |key, values|
          pvalue = rank_enrichment_for_list(list, values, options)
          res[key] = [pvalue, (values.respond_to?(:subset) ? values.subset(list) :  values - list)]
        end
      end
    end

    FDR.adjust_hash! res, 0 if options[:fdr]

    res
  end

  def rank_enrichment(list, options = {})
    TSV.rank_enrichment(self, list, options)
  end
end
