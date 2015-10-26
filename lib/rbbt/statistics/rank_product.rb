require 'rbbt/tsv'

module RankProduct
  def self.score(gene_ranks, signature_sizes)
    scores = {}
    log_sizes = signature_sizes.collect{|size| Math::log(size)}
    gene_ranks.each{|gene, positions|
      scores[gene] = positions.collect{|p| p.nil? or (p.respond_to?(:empty?) and p.empty?) ? signature_sizes.max  : p }.zip(log_sizes).
        collect{|p| Math::log(p[0]) - p[1]}.   
        inject(0){|acc, v| acc += v  }
    }
    scores
  end

  def self.permutations(num_signatures, num = 1000)
    scores = []
    num.times{
       value = 0
       num_signatures.times{|size_and_log| 
         value += Math::log(rand)
       } 
       scores << value
    }
    scores
  end

  def self.permutations_full(signature_sizes)
    gene_ranks = {}
    signature_sizes.each{|size|
      (1..size).to_a.shuffle.each_with_index{|gene, pos|
        gene_ranks[gene] ||= []
        gene_ranks[gene] << pos + 1
      }
    }
    gene_ranks.delete_if{|code, positions| positions.length != signature_sizes.length}

    scores = score(gene_ranks, signature_sizes)
    scores.values
  end
end

module TSV
  def rank_product(fields, reverse = false, &block)
    tsv = self.slice(fields)

    if block_given?
      scores = fields.collect{|field| tsv.sort_by(field, true, &block)}
    else
      scores = fields.collect{|field| tsv.sort_by(field, true){|gene,values| tsv.type == :single ? values.to_f : values.flatten.first.to_f}}
    end
    positions = {}
    
    if reverse
      size = self.size
      tsv.keys.each do |entity|
        positions[entity] = scores.collect{|list| size - list.index(entity)}
      end
    else
      tsv.keys.each do |entity|
        positions[entity] = scores.collect{|list| list.index(entity) + 1}
      end
    end

    signature_sizes = fields.collect{|field| slice(field).values.select{|v| v and not (v.respond_to?(:empty?) and v.empty?)}.length} 

    score = RankProduct.score(positions, signature_sizes)

    score
  end
end
