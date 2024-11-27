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

             //RFLOAT_VALUE_SET(rb_ary_entry(ps, idx)) = p;
             rb_ary_unshift(ps, p);
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

           double p,op, last = 1;

           for (idx = total - 1; idx >= 0 ; idx-- ){
             op  = (double) RFLOAT_VALUE(rb_ary_entry(ps, idx));

             if (op < 0){
               p = -op;
             }else{
               p = op;
             }

             p = p * (double) total / (double) (idx + 1);
             if (p > last) p = last;
             last = p;

             if (op < 0){
               p = -p;
             }else{
               p = p;
             }
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

  def self.adjust_hash!(data, field = nil)
    begin
      if data.respond_to? :unnamed
        unnamed = data.unnamed 
        data.unnamed = true
      end

      values = []
      keys = []

      field_pos = (String === field ) ?  data.fields.index(field) : field

      field_pos = nil if data.respond_to?(:type) and data.type == :single

      data.collect{|k,vs|
        v = field_pos.nil? ? vs : vs[field_pos]
        v = v.first if Array === v
        v = 1.0 if v.nil?
        [k, v.to_f] 
      }.sort{|a,b| 
        a[1].abs <=> b[1].abs
      }.each{|p|
        keys << p[0]
        values << p[1]
      }

      iii RUBY_VERSION[0]
      if RUBY_VERSION[0] == "2" || RUBY_VERSION[0] == "3"
        new_values = FDR.adjust(values)
        keys.zip(new_values).each do |k,v|
          vs = data[k] 
          if field_pos
            vs[field_pos] = v
          else
            if Array === vs
              vs[0] = v
            else
              data[k] = v
            end
          end
        end
      else
        FDR.adjust!(values)
      end

      data
    ensure
      data.unnamed = unnamed if unnamed
    end
  end
end
