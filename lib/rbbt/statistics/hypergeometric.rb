require 'inline'
require 'rbbt/util/tsv'

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
*  * @param total => total size
*  * @param support => total support
*  * @param list => selected list size,
*  * @param found => support
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

    annotation_count_cache_file = TSV.get_persistence_file(File.basename(filename) + "_" + fields.inspect, File.expand_path(File.dirname(filename)))

    if File.exists?(annotation_count_cache_file)
      Log.low "Loading annotation counts from #{ annotation_count_cache_file }"
      TCHash.get(annotation_count_cache_file)
    else
      Log.low "Saving annotation counts to #{ annotation_count_cache_file }"
      hash = TCHash.get(annotation_count_cache_file)

      counts = Hash.new(0)
      total = 0
      through :main, fields do |key, values|
        values.flatten.uniq.each{|value| counts[value] += 1; total += 1}
      end
      counts["_total"] = total
      hash.merge! counts
    end
  end

  def enrichment(list, fields)
    selected = select list
    counts = annotation_counts fields

    annotations = Hash.new 0
    total = 0
    selected.through :main, fields do |key, values|
      values.flatten.uniq.each{|value| annotations[value] += 1; total += 1}
    end

    pvalues = {}
    annotations.each do |annotation, count|
      pvalues[annotation] = Hypergeometric.hypergeometric(counts["_total"], counts[annotation], count, total)
    end

    pvalues
  end
end



