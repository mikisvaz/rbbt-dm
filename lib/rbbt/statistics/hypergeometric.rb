require 'inline'
require 'rbbt/tsv'
require 'rbbt/persist'
require 'rbbt/statistics/fdr'
require 'rbbt/entity'

module Hypergeometric
  class << self
    inline do |builder|
      builder.c_raw <<-EOC
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
  
      builder.c <<-EOC
/**
*  * Compute the Hypergeometric accumulated value.
*  * @param total       => total size
*  * @param support     => total support
*  * @param list        => selected list size
*  * @param found       => support
*  * @return The result
*  */
double hypergeometric(double total, double support, double list, double found)
{
	double other = total - support;

	double top = list;
	if(support < list){
		top = support;
	}

	double log_n_choose_k = lBinom(total,list);

	double lfoo = lBinom(support,top) + lBinom(other, list-top);
	
	double sum = 0;
  int i;
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
  end
end

module TSV

  def annotation_counts(fields = nil, persistence = false)
    fields ||= self.fields
    fields = [fields] if String === fields or Symbol === fields

    Persist.persist(filename, :yaml, :fields => fields, :persist => persistence, :prefix => "Hyp.Geo.Counts") do 
      data ||= Hash.new(0)

      with_unnamed do

        case type
        when :single
          through :key, fields do |key, value|
            next if value.nil?
            data[value] += 1
          end
        when :double
          through :key, fields do |key, values|
            next if values.nil?
            values.flatten.compact.uniq.each{|value| data[value] += 1}
          end
        when :list
          through :key, fields do |key, values|
            next if values.nil?
            values.compact.uniq.each{|value| data[value] += 1}
          end
        when :flat
          through :key, fields do |key, values|
            next if values.nil?
            values.compact.uniq.each{|value| data[value] += 1}
          end
        end

      end

      data
    end
  end

  def enrichment(list, fields = nil, options = {})
    background = options.delete :background

    if background and not background.empty?
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

      add_keys = Misc.process_options options, :add_keys

      Log.debug "Enrichment analysis of field #{fields.inspect} for #{list.length} entities"

      selected = select :key => list

      tsv_size = keys.length
      total = selected.keys.length
      Log.debug "Found #{total} of #{list.length} entities"

      counts = annotation_counts fields, options[:persist]

      annotations = Hash.new 
      annotation_keys = Hash.new
      selected.with_unnamed do

        case type
        when :single
          selected.through :key, fields do |key, value|
            value = value.dup
            annotations[value] ||= 0
            annotations[value] += 1
            next unless add_keys
            annotation_keys[value] ||= []
            annotation_keys[value] << key
          end

        when :double
          selected.through :key, fields do |key, values|
            values.flatten.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotations[value] ||= 0
              annotations[value] += 1
              next unless add_keys
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end

        when :list
          selected.through :key, fields do |key, values|
            values.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotations[value] ||= 0
              annotations[value] += 1
              next unless add_keys
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end

        when :flat
          selected.through :key, fields do |key, values|
            values.compact.uniq.reject{|value| value.empty?}.each{|value| 
              value = value.dup
              annotations[value] ||= 0
              annotations[value] += 1
              next unless add_keys
              annotation_keys[value] ||= []
              annotation_keys[value] << key
            }
          end

        end

      end

      if background
        reset_filters
        pop_filter
      end

      pvalues = {}
      annotations.each do |annotation, count|
        next if count < options[:min_support] or not counts.include? annotation
        pvalues[annotation] = Hypergeometric.hypergeometric(tsv_size, counts[annotation], total, count)
      end

      FDR.adjust_hash! pvalues if options[:fdr]

      pvalues.delete_if{|k, pvalue| pvalue > options[:cutoff] } if options[:cutoff]

      TSV.setup(pvalues, :key_field => fields, :fields => ["p-value"], :cast => :to_f, :type => :single)

      if add_keys
        tsv = TSV.setup(pvalues.keys, :key_field => fields, :fields => [], :type => :double)

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
        pvalues
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


