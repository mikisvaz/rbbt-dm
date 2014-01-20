require 'inline'

module FDR

  # values should be sorted
  def self.step_up_native(values, rate)
    total = values.length

    last = 0
    values.each_with_index  do |value, i|
      if value > rate * (i + 1).to_f / total
        return last
      end
      last = value
    end
    return last
  end

  # values should be sorted
  def self.adjust_native(values)
    total = values.length.to_f

    adjusted = []
    last = 1
    values.reverse.each_with_index do |value, i|
      adj = [last, value * total / (total - i )].min
      last = adj
      adjusted << adj
    end

    adjusted.reverse
  end

  inline do |builder|

    builder.prefix  <<-EOC_CODE

//{{{ Make compatible with 1.9 and 1.8
#ifndef RUBY_19
# define RFLOAT_VALUE_SET(v) (((struct RFloat *)v)->float_value)
# ifndef RFLOAT_VALUE
#  define RFLOAT_VALUE(v) (RFLOAT(v)->value)
# endif
# ifndef RARRAY_LEN
#  define RARRAY_LEN(v) (RARRAY(v)->len)
# endif
#else
# define RFLOAT_VALUE_SET(v) RFLOAT_VALUE
#endif
    EOC_CODE

    c_code = <<-EOC_CODE
        double step_up_fast(VALUE ps, double rate){
           long idx;
           int total = (int) RARRAY_LEN(ps);

           double last_value = 0;
           double p;

           for (idx = 0; idx < total; idx++){
             p  = (double) RFLOAT_VALUE(rb_ary_entry(ps, idx));

             if (p > rate * (double) (idx + 1) / (double) total){
                return last_value;
             }
             last_value = p;
           }

           return last_value;
        }

    EOC_CODE
    builder.c_singleton c_code

    c_code = <<-EOC_CODE
         VALUE adjust_fast_self(VALUE ps){
           long idx;

           int total = (int) RARRAY_LEN(ps);

           double last = 1;
           VALUE current_value;
           for (idx = total - 1; idx >= 0 ; idx-- ){
             current_value = rb_ary_entry(ps, idx);
             
             double p  = (double) RFLOAT_VALUE(current_value);

             p = p * (double) total / (double) (idx + 1);
             if (p > last) p = last;
             last = p;

             RFLOAT_VALUE_SET(rb_ary_entry(ps, idx)) = p;
           }

          return ps;
         }
    EOC_CODE
    builder.c_singleton c_code

    c_code = <<-EOC_CODE
         VALUE adjust_fast(VALUE ps){
           long idx;

           int total = (int) RARRAY_LEN(ps);

           VALUE new_ary = rb_ary_new();
           VALUE f;

           double p, last = 1;

           for (idx = total - 1; idx >= 0 ; idx-- ){
             p  = (double) RFLOAT_VALUE(rb_ary_entry(ps, idx));


             p = p * (double) total / (double) (idx + 1);
             if (p > last) p = last;
             last = p;

             f = rb_float_new(p);
             rb_ary_unshift(new_ary, f);
           }

           return new_ary;
         }
    EOC_CODE
    builder.c_singleton c_code

    builder
  end


  class << self
    alias :adjust :adjust_fast
    alias :adjust! :adjust_fast_self
    alias :step_up :step_up_fast
  end

  # This will change the values of the floats in-situ
  def self.adjust_hash!(data, field = nil)
    keys = []
    values = []

    if data.respond_to? :unnamed
      unnamed = data.unnamed 
      data.unnamed = true
    end

    data.collect{|key, value| [key, Array === ( v = field.nil? ? value : value[field] ) ? v.first : v] }.sort{|a,b| 
      a[1] <=> b[1]
    }.each{|p|
      keys << p[0]
      values << p[1]
    }

    if data.respond_to? :unnamed
      data.unnamed = unnamed
    end

    if RUBY_VERSION[0] == "2"
      # I don't know why the RFLOAT_VALUE_SET for Ruby 2.1.0 does not work
      values = FDR.adjust(values)
      data   = Hash[*keys.zip(values).flatten]
    else
      FDR.adjust!(values)
    end

    data 
  end

end



