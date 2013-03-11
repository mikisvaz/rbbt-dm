require 'rbbt/util/misc'

module Signature
  extend ChainMethods
  self.chain_prefix = :signature


  def self.setup(hash, options = {})
    hash.extend Signature
    hash
  end

  def self.open(file, field = nil, options = {})
    options = Misc.add_defaults options, :fields => nil, :cast => :to_f, :type => :single

    options[:fields] ||= [field] if field

    tsv = TSV.open(file, options)
    tsv.extend Signature
    tsv
  end

  def self.tsv_field(tsv, field, cast = nil)
    tsv = TSV.open(tsv) unless TSV === tsv
    Signature.setup(tsv.column(field, cast))
  end

  #{{{ Basic manipulation

  def signature_select(*args, &block)
    Signature.setup(signature_clean_select(*args, &block))
  end

  def transform(&block)
    case
    when (block_given? and block.arity == 2)
      self.each do |key, value|
        self[key] = yield key, value
      end
    when (block_given? and block.arity == 1)
      self.each do |key, value|
        self[key] = yield value
      end
    else
      raise "Block not given, or arity not 1 or 2"
    end
    self
  end

  def abs
    transform{|value| value.abs}
  end

  def log
    transform{|value| Math.log(value)}
  end

  def values_over(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    Misc.prepare_entity(self.select{|k,v| v >= threshold}.collect{|k,v| k}, self.key_field, entity_options)
  end

  def values_under(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    Misc.prepare_entity(self.select{|k,v| v <= threshold}.collect{|k,v| k}, self.key_field, entity_options)
  end

  #{{{ Rank stuff

  def clean_empty
    Signature.setup(select{|k,v| v.nil? ? false : (v.respond_to?(:empty) ? !v.empty? : true)}.tap{|s| s.unnamed = true})
  end

  def sorted
    OrderedList.setup(clean_empty.sort_by{|elem,v| v}.collect{|elem,v| elem})
  end

  def ranks
    ranks = TSV.setup({}, :key_field => self.key_field, :fields => ["Rank"], :cast => :to_i, :type => :single)
    sorted.each_with_index do |elem, i|
      ranks[elem] = i
    end
    ranks
  end

  #{{{ Pvalue stuff
  
  def significant_pvalues(threshold)
    entity_options = self.entity_options
    entity_options[:organism] ||= self.namespace
    if threshold > 0
      Misc.prepare_entity(self.select{|k,v| v > 0 and v <= threshold}.collect{|k,v| k}, self.key_field, entity_options)
    else
      Misc.prepare_entity(self.select{|k,v| v < 0 and v >= threshold}.collect{|k,v| k}, self.key_field, entity_options)
    end
  end
  def pvalue_fdr_adjust!
    FDR.adjust_hash! self
    self
  end

  def pvalue_score
    transform{|value| value > 0 ? -Math.log(value + 0.00000001) : Math.log(-value + 0.00000001)}
  end

  def pvalue_sorted
    OrderedList.setup(clean_empty.transform{|v| v.to_f}.sort{|a,b| 
      a = a[1]
      b = b[1]
      case
      when a == b
        0
      when (a <= 0 and b >= 0)
        1
      when (a >= 0 and b <= 0)
        -2
      when a > 0
        a.abs <=> b.abs
      else
        b.abs <=> a.abs
      end
    
    }.collect{|elem,v| elem})
  end

  def pvalue_sorted_weights
    sorted = clean_empty.transform{|v| v.to_f}.sort{|a,b| 
      a = a[1]
      b = b[1]
      case
      when a == b
        0
      when (a <= 0 and b >= 0)
        1
      when (a >= 0 and b <= 0)
        -2
      when a > 0
        a.abs <=> b.abs
      else
        b.abs <=> a.abs
      end
    }

    keys = []
    weights = []
    sorted.each{|k,v| keys << k; weights << - Math.log(v.abs)}

    OrderedList.setup(keys, weights)
  end


end
