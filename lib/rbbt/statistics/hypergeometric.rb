require 'inline'
require 'rbbt/util/tsv'
require 'rbbt/util/persistence'
require 'rbbt/statistics/fdr'

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

class TSV

  def annotation_counts(fields = nil)
    fields ||= self.fields
    fields = [fields] if String === fields or Symbol === fields

    Persistence.persist(filename, "Annotation_counts[#{fields.inspect}]", :tsv, :fields => fields) do |file, options|
      counts = Hash.new(0)
      through :key, fields do |key, values|
        values.flatten.compact.uniq.each{|value| counts[value] += 1}
      end

      counts
    end
  end

  def enrichment(list, fields, options = {})
    options = Misc.add_defaults options, :min_support => 3, :fdr => true, :cutoff => false
    Log.debug "Enrichment analysis of field #{fields.inspect} for #{list.length} entities"
    selected = select :key => list
    
    tsv_size = keys.length
    total = selected.keys.length
    Log.debug "Found #{total} of #{list.length} entities"

    counts = annotation_counts fields

    annotations = Hash.new 0
    selected.through :key, fields do |key, values|
      values.flatten.compact.uniq.each{|value| annotations[value] += 1}
    end

    pvalues = {}
    annotations.each do |annotation, count|
      Log.debug "Hypergeometric: #{ annotation } - #{[tsv_size, counts[annotation], total, count].inspect}"
      next if count < options[:min_support]
      pvalue = Hypergeometric.hypergeometric(tsv_size, counts[annotation], total, count)
      pvalues[annotation] = pvalue
    end

    FDR.adjust_hash! pvalues if options[:fdr]
    pvalues.delete_if{|k, pvalue| pvalue > options[:cutoff] } if options[:cutoff]

    pvalues
  end

  def enrichment_for(tsv, field, options = {} )
    tsv = tsv.tsv if Path === tsv
    index = TSV.find_traversal(self, tsv, :in_namespace => false, :persist_input => true)

    raise "Cannot traverse identifiers" if index.nil?

    source_keys = index.values_at(*self.keys).flatten.compact.uniq

    tsv.enrichment source_keys, field, options
  end
end



