require 'png'
require 'inline'
require 'set'
require 'rbbt/util/misc'

module RandomWalk

  inline do |builder|

    builder.prefix  <<-EOC_CODE
#include <math.h>
#include <time.h>
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

    builder.c_singleton <<-'EOC'
    void sample_without_replacement ( int populationSize,    int sampleSize,       VALUE positions) {
        // Use Knuth's variable names
        int n = sampleSize;
        int N = populationSize;

        int t = 0; // total input records dealt with
        int m = 0; // number of items selected so far
        double u;

        //srand ( (unsigned)time ( NULL ) );
        while (m < n)
        {
            u = (double) rand() / ((double) RAND_MAX + 1.0); 

            if ( (N - t)*u >= n - m )
            {
                t++;
            }
            else
            {
                rb_ary_push(positions, rb_int_new(t));
                t++; m++;
            }
        }
    }
    EOC

    builder.c_singleton <<-'EOC'
    double score_plain_weight(VALUE positions, int total, int missing){
      int idx;

      int position;
      double penalty;
      double max_top, max_bottom;
      double hit_weights = 0;

      VALUE rel_l = rb_ary_new();
      VALUE rel_q = rb_ary_new();

      rb_ary_push(rel_q,rb_float_new(0));

      // Rescale positions and accumulate weights

      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        position = FIX2INT(rb_ary_entry(positions, idx));

        rb_ary_push(rel_l, rb_float_new((double) position / total));

        hit_weights += 1;
        rb_ary_push(rel_q, rb_float_new(hit_weights));
      }

      // Add penalty for missing genes
      penalty = missing * 1;
      hit_weights  = hit_weights + penalty;

      // Traverse list and get extreme values of:
      // Proportion of weight covered - Proportion of hits covered

      max_top = max_bottom = 0;
      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        double top    = RFLOAT_VALUE(rb_ary_entry(rel_q, idx + 1)) / hit_weights -
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));
        double bottom = - (penalty + RFLOAT_VALUE(rb_ary_entry(rel_q, idx))) / hit_weights +
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));

        if (top > max_top)       max_top    = top;
        if (bottom > max_bottom) max_bottom = bottom;
      }

     if (max_top > max_bottom) return max_top;
     else                      return -max_bottom;
    }
    EOC

    builder.c_raw_singleton <<-'EOC'
    double fitted_weight(int position, int medium){
        double rel_pos = (double) abs(position - medium) / medium; 
        double weight =  0.3 *  0.5 * rel_pos +  0.7 * (exp(30*rel_pos)/exp(30));
        return(weight);
    }
    EOC

    builder.c_singleton <<-'EOC'
    double score_fitted_weight(VALUE positions, int total, int missing){
      int idx;

      int medium = total / 2;
      int position;
      double penalty;
      double max_top, max_bottom;
      double hit_weights = 0;

      VALUE rel_l = rb_ary_new();
      VALUE rel_q = rb_ary_new();

      rb_ary_push(rel_q,rb_float_new(0));

      // Rescale positions and accumulate weights

      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        position = FIX2INT(rb_ary_entry(positions, idx));

        rb_ary_push(rel_l, rb_float_new((double) position / total));

        hit_weights += fitted_weight(position, medium);
        rb_ary_push(rel_q, rb_float_new(hit_weights));
      }

      // Add penalty for missing genes
      penalty = missing * fitted_weight(medium * 0.8, medium);
      hit_weights  = hit_weights + penalty;

      // Traverse list and get extreme values of:
      // Proportion of weight covered - Proportion of hits covered

      max_top = max_bottom = 0;
      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        double top    = RFLOAT_VALUE(rb_ary_entry(rel_q, idx + 1)) / hit_weights -
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));
        double bottom = - (penalty + RFLOAT_VALUE(rb_ary_entry(rel_q, idx))) / hit_weights +
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));

        if (top > max_top)       max_top    = top;
        if (bottom > max_bottom) max_bottom = bottom;
      }

     if (max_top > max_bottom) return max_top;
     else                      return -max_bottom;
    }
    EOC


    builder.c_singleton <<-'EOC'
    double score_custom_weights(VALUE positions, VALUE weights, int total_weights, int total, int missing){
      int idx;

      int medium = total / 2;
      int position;
      double penalty;
      double max_top, max_bottom;
      double hit_weights = 0;

      VALUE rel_l = rb_ary_new();
      VALUE rel_q = rb_ary_new();

      rb_ary_push(rel_q,rb_float_new(0));

      // Rescale positions and accumulate weights

      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        position = FIX2INT(rb_ary_entry(positions, idx));

        rb_ary_push(rel_l, rb_float_new((double) position / total));

        hit_weights += rb_ary_entry(weights, position);
        rb_ary_push(rel_q, rb_float_new(hit_weights / total_weights));
      }

      // Add penalty for missing genes
      penalty = missing * rb_ary_entry(weights, (int) medium * 0.8);
      hit_weights  = hit_weights + penalty;
      hit_weights = hit_weights / total_weights;

      // Traverse list and get extreme values of:
      // Proportion of weight covered - Proportion of hits covered

      max_top = max_bottom = 0;
      for (idx = 0; idx < RARRAY_LEN(positions); idx++){
        double top    = RFLOAT_VALUE(rb_ary_entry(rel_q, idx + 1)) / hit_weights -
                        RFLOAT_VALUE(rb_ary_entry(rel_l, idx));
        double bottom = - (penalty + RFLOAT_VALUE(rb_ary_entry(rel_q, idx))) / hit_weights +
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
    attr_accessor :scoring_method

    def set_scoring(method)
      scoring_method = method
      class << self; self end.send(:alias_method, :score, method.to_sym)
    end
  end

  set_scoring :score_fitted_weight


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

  # Two sided
  def self.score_up_down(up, down, total, missing = 0)
    scores_up   = score(up, total, missing)
    scores_down = score(down, total, missing)

    combine(scores_up, scores_down)
  end

  def self.permutations(size, total, missing = 0, times = 10_000)
    if size == 0
      [0] * times
    else
      (1..times).collect do
        p = []
        sample_without_replacement(total, size, p)

        score(p, total, missing).abs
      end
    end
  end

  def self.persisted_permutations(size, total, missing = 0, times = 10_000)
    repo_file = "/tmp/rw_repo7"
    repo = Persist.open_tokyocabinet(repo_file, false, :float_array)
    key = Misc.digest([size, total, missing, times, scoring_method].inspect)
    repo.read
    if repo[key]
      repo[key]
    else
      p = permutations(size, total, missing, times)
      repo.write_and_close do
        repo[key] = p
      end
      p
    end
  end

  def self.permutations_up_down(size_up, size_down, total, missing = 0, times = 10000)
    (1..times).collect do
      score_up_down(Array.new(size_up){ (rand * total).to_i }.sort, Array.new(size_down){ (rand * total).to_i }.sort, total, missing).abs
    end
  end

  def self.pvalue(permutations, score)
    score = score.abs
    permutations.inject(1){|acc, per| 

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
  attr_accessor :weights, :total_weights

  def self.setup(list, weights = nil, total_weights = nil)
    list.extend OrderedList
    list.weights = weights
    if weights and total_weights.nil?
      list.total_weights = Misc.sum(weights)
    else
      list.total_weights = total_weights
    end
    list
  end

  def self.hits(list, set)
    set = Set.new(set) unless Set === set
    hits = []
    list.each_with_index do |e,i|
      hits << i + 1 if set.include? e # count from 1
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

  def score(set)
    hits = hits(set)
    RandomWalk.score(hits.sort, self.length, 0)
  end

  def score_weights(set)
    raise "No weight defined" if @weights.nil?
    @total_weights ||= Misc.sum(@weights)
    hits = hits(set)
    RandomWalk.score_weights(hits.sort, @weights, @total_weights, self.length, 0)
  end


  def draw_hits(set, filename = nil, options = {})
    OrderedList.draw_hits(self, set, filename, options)
  end

  #def pvalue(set, options = {})
  #  set = Set.new(set.compact) unless Set === set
  #  options = Misc.add_defaults options, :permutations => 10000, :missing => 0
  #  hits = hits(set)
  #  score = RandomWalk.score(hits.sort, self.length, 0)
  #  permutations = RandomWalk.permutations(set.length, self.length, options[:missing], options[:permutations])
  #  RandomWalk.pvalue(permutations, score)
  #end

  def pvalue(set, cutoff = 0.1, options = {})
    set = Set.new(set.compact) unless Set === set
    options = Misc.add_defaults options, :permutations => 10000, :missing => 0
    permutations, missing, persist_permutations = Misc.process_options options, :permutations, :missing, :persist_permutations

    hits = hits(set)
   
    return 1.0 if hits.empty?

    target_score = RandomWalk.score(hits.sort, self.length, missing)

    if persist_permutations
      permutations = RandomWalk.persisted_permutations(set.length, self.length, missing, permutations)
      RandomWalk.pvalue(permutations, target_score)
    else
      # P-value computation
      target_score_abs = target_score.abs

      max = (permutations.to_f * cutoff).ceil

      size = set.length
      total = self.length
      better_permutation_score_count = 1
      if size == 0
        1.0
      else
        (1..permutations).each do
          p= []
          RandomWalk.sample_without_replacement(total, size, p)

          permutation_score = RandomWalk.score(p.sort, total, missing).abs
          if permutation_score.abs > target_score_abs
            better_permutation_score_count += 1
          end

          return 1.0 if better_permutation_score_count > max
        end
        p = (better_permutation_score_count.to_f + 1) / permutations
        p = -p if target_score < 0
        p
      end
    end
  end

  def pvalue_weights(set, cutoff = 0.1, options = {})
    raise "No weight defined" if @weights.nil?
    @total_weights ||= Misc.sum(@weights)

    set = Set.new(set.compact) unless Set === set
    options = Misc.add_defaults options, :permutations => 10000, :missing => 0
    permutations, missing = Misc.process_options options, :permutations, :missing

    hits = hits(set)

    return 1.0 if hits.empty?

    target_score = RandomWalk.score_weights(hits.sort, @weights, @total_weights, self.length, 0)
    target_score_abs = target_score.abs

    max = (permutations.to_f * cutoff).ceil

    size = set.length
    total = self.length
    better_permutation_score_count = 1
    if size == 0
      1.0
    else
      (1..permutations).each do
        p= []
        RandomWalk.sample_without_replacement(total, size, p)

        permutation_score = RandomWalk.score_weights(p.sort, @weights, @total_weights, total, missing).abs
        if permutation_score.abs > target_score_abs
          better_permutation_score_count += 1
        end

        return 1.0 if better_permutation_score_count > max
      end
      p = (better_permutation_score_count.to_f + 1) / permutations
      p = -p if target_score < 0
      p
    end
  end
end

module TSV

  def self.rank_enrichment_for_list(list, hits, options = {})
    cutoff = options[:cutoff]
    list.extend OrderedList
    if cutoff
      list.pvalue(hits, cutoff, options)
    else
      list.pvalue(hits, nil, options)
    end
  end

  def self.rank_enrichment(tsv, list, options = {})
    masked = options[:masked]
    if tsv.fields
      res = TSV.setup({}, :cast => :to_f, :type => :double, :key_field => tsv.key_field, :fields => ["p-value", tsv.fields.first]) 
    else
      res = TSV.setup({}, :cast => :to_f, :type => :double) 
    end

    list = list.clean_annotations if list.respond_to? :clean_annotations
    tsv.with_monitor :desc => "Rank enrichment" do
      tsv.with_unnamed do
        tsv.through do |key, values|
          next if masked and masked.include? key
          pvalue = rank_enrichment_for_list(list, values.flatten, options)
          res[key] = [pvalue, (values.respond_to?(:subset) ? values.subset(list) :  values & list)]
        end
      end
    end

    FDR.adjust_hash! res, 0 if options[:fdr]

    res
  end

  def rank_enrichment(list, options = {})
    TSV.rank_enrichment(self, list, options)
  end

  def ranks_for(field)
    ranks = TSV.setup({}, :key_field => self.key_field, :fields => ["Rank"], :type => :single, :cast => :to_i)
    sort_by(field, true).each_with_index do |k, i|
      ranks[k] = i
    end

    ranks.entity_options = entity_options
    ranks.entity_templates = entity_templates
    ranks.namespace = namespace

    ranks
  end
end
