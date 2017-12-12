require 'inline'
require 'rbbt'
require 'rbbt/persist'
require 'rbbt/persist'
require 'rbbt/tsv'
require 'rbbt/statistics/fdr'
require 'rbbt/entity'
require 'distribution'
require 'distribution/hypergeometric'

require 'rbbt/util/R/eval'

module Hypergeometric
  inline do |builder|
    builder.prefix <<-EOC
#include <math.h>
    EOC

    builder.c_raw_singleton <<-EOC
/**
 * Compute log(k!)
 * @param k The value k.
 * @return The result.
 */
double lFactorial(double k)
{
  double r = 0;
  int i;
  for(i=2 ; i<=(int)k ; i++)
  {
    r = r + (double)(log((double)i));
  }
  return r;
}



/**
 * Compute the log(binom(n,k))
 * @param n The number of possible items.
 * @param k The number of selected items.
 * @return The result.
 */
double lBinom(double n, double k)
{
  long i;
  double r = 0;

  if(n > n-k){
    k = n-k;
  }

  for(i = (long)n ; i> (n-k) ; i--)
  {
    r = r + log((double)i);
  }

  r = r - lFactorial(k);

  return r;
}
    EOC

    builder.c_singleton <<-EOC
/**
*  * Compute the Hypergeometric accumulated value.
*  * @param total       => total size
*  * @param support     => total support
*  * @param list        => selected list size
*  * @param found       => support
*  * @return The result
*  */
        //pvalues[annotation] = Hypergeometric.hypergeometric(tsv_size, counts[annotation], total, count)
        //["200204", 2141, 15, 125, 3, 1.37320769558675e-188, ["Q05193", "P54762", "Q12923"]]
double hypergeometric_c(double total, double support, double list, double found)
{
  double other = total - support;

  double top = list;
  double log_n_choose_k = lBinom(total,list);

  double lfoo = lBinom(support,top) + lBinom(other, list-top);

  double sum = 0;
  int i;

  if(support < list){
    top = support;
  }


  for (i = (int)top; i >= found; i-- )
  {
    sum = sum + exp(lfoo - log_n_choose_k);
    if ( i > found)
    {
      lfoo = lfoo + log(i / (support - i+1)) +  log( (other - list + i) / (list-i+1)  );
    }
  }
  return sum;
}
    EOC
  end

  def self.hypergeometric(count, positive, negative, total)
    #RSRuby.instance.phyper(count - 1, positive, negative, total, false).to_f
    R.eval("phyper(#{ count } - 1, #{ positive }, #{ negative }, #{ total }, lower.tail=FALSE)").to_f
  end
end

module TSV

  def annotation_counts(fields = nil, persistence = false, options = {})
    fields ||= self.fields
    fields = [fields] if String === fields or Symbol === fields
    rename = options.delete :rename
    background = options.delete :background

    field_pos = fields.collect{|f| self.fields.index f}.compact
    persistence_path = self.respond_to?(:persistence_path)? self.persistence_path : nil
    Persist.persist(filename, :yaml, :fields => fields, :persist => persistence, :prefix => "Hyp.Geo.Counts", :other => {:background => background, :rename => rename, :persistence_path => persistence_path}) do 
      data ||= {}

      with_unnamed do

        case type
        when :single
          through :key, field_pos do |key, value|
            next if background and not background.include?(key)
            next if value.nil? 
            data[value] ||= []
            data[value] << key
          end
        when :double
          through :key, field_pos do |key, values|
            next if background and not background.include?(key)
            values.flatten.compact.uniq.each{|value| data[value] ||= []; data[value] << key}
          end
        when :list
          through :key, field_pos do |key, values|
            next if values.nil?
            next if background and not background.include?(key)
            values.compact.uniq.each{|value| data[value] ||= []; data[value] << key}
          end
        when :flat
          through :key, field_pos do |key, values|
            next if values.nil?
            next if background and not background.include?(key)
            values.compact.uniq.each{|value| data[value] ||= []; data[value] << key}
          end
        end

      end

      if rename
        Log.debug("Using renames during annotation counts")
        Hash[*data.keys.zip(data.values.collect{|l| l.collect{|e| rename.include?(e)? rename[e] : e }.uniq.length }).flatten]
      else
        Hash[*data.keys.zip(data.values.collect{|l| l.uniq.length}).flatten]
      end
    end
  end

  def enrichment(list, fields = nil, options = {})
    options = Misc.add_defaults options, :skip_missing => true, :background => nil
    background, skip_missing = Misc.process_options options, :background, :skip_missing

    list = list.compact.uniq

    if Array === background and not background.empty?
      filter
      add_filter(:key, background)
      if defined? AnnotatedArray and AnnotatedArray === list
        list = list.subset background
      else
        list = list & background
      end
    end

    with_unnamed do
      fields ||= self.fields.first
      options = Misc.add_defaults options, :min_support => 3, :fdr => true, :cutoff => false, :add_keys => true

      add_keys, rename, masked = Misc.process_options options, :add_keys, :rename, :masked

      Log.debug "Enrichment analysis of field #{fields.inspect} for #{list.length} entities"

      selected = select :key => list.uniq

      found = selected.keys.length
      Log.debug "Found #{found} of #{list.length} entities"

      if skip_missing
        total = found
        Log.debug "Using #{ found } as sample size; skipping missing"
      else
        total = list.length
        Log.debug "Using #{ list.length } as sample size"
      end

      if background
        tsv_size = background.length
        counts = annotation_counts fields, options[:persist], :rename => rename, :masked => masked, :background => background
      else
        tsv_size = keys.length
        counts = annotation_counts fields, options[:persist], :rename => rename, :masked => masked
      end


      annotation_keys = Hash.new
      selected.with_unnamed do

        case type
        when :single
          selected.through :key, fields do |key, value|
            value = value.dup
            annotation_keys[value] ||= []
            annotation_keys[value] << key
          end

        when :double
          selected.through :key, fields do |key, values|
            values.flatten.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end

        when :list
          selected.through :key, fields do |key, values|
            values.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end

        when :flat
          selected.through do |key, values|
            next if values.nil?
            values.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end
        end
      end

      if Array === background and not background.empty?
        reset_filters
        pop_filter
      end

      pvalues = {}
      annotation_keys.each do |annotation, elems|
        next if masked and masked.include? annotation
        elems = elems.collect{|elem| rename.include?(elem)? rename[elem] : elem }.compact.uniq if rename
        count = elems.length
        next if count < options[:min_support] or not counts.include? annotation
        pvalues[annotation] = Hypergeometric.hypergeometric(count, counts[annotation], tsv_size - counts[annotation], total)
        iii [annotation, elems, total, counts[annotation], tsv_size, pvalues[annotation]]
      end

      pvalues = FDR.adjust_hash! pvalues if options[:fdr]

      pvalues.delete_if{|k, pvalue| pvalue > options[:cutoff] } if options[:cutoff]

      if add_keys
        tsv = TSV.setup(pvalues.keys.collect{|k| k.dup}, :key_field => fields, :fields => [], :type => :double)

        tsv.add_field 'p-value' do |annot, values|
          [pvalues[annot]]
        end

        tsv.add_field self.key_field do |annot, values|
          if list.respond_to? :annotate
            list.annotate annotation_keys[annot]
          else
            annotation_keys[annot]
          end
        end

        tsv
      else
        TSV.setup(pvalues, :key_field => fields, :fields => ["p-value"], :cast => :to_f, :type => :single)
      end

    end
  end

  def enrichment_for(tsv, field, options = {} )
    tsv = tsv.tsv if Path === tsv
    index = TSV.find_traversal(self, tsv, :in_namespace => false, :persist_input => true)

    raise "Cannot traverse identifiers" if index.nil?

    source_keys = index.values_at(*self.keys).flatten.compact.uniq

    tsv.enrichment source_keys, field, options
  end
end

module Entity
  module Enriched
    def enrichment(file, fields = nil, options = {})
      file = file.tsv if Path === file
      file.enrichment self, fields, options
    end
  end
end

