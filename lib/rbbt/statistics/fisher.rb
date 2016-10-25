require 'rbbt/util/R'
require 'rbbt/util/R/eval'

module Fisher
  def self.test_classification(classes1, classes2, alternative='greater')
    matrix = [0,0,0,0]
    classes1.each_with_index do |c1,i|
      c2 = classes2[i]
      if c1 == 1 and c2 == 1
        matrix[0] += 1
      elsif c1 == 0 and c2 == 1
        matrix[1] += 1
      elsif c1 == 1 and c2 == 0
        matrix[2] += 1
      else
        matrix[3] += 1
      end
    end
    R.eval("fisher.test(matrix(#{R.ruby2R matrix}, nrow=2), alternative = #{R.ruby2R alternative})$p.value")
  end
end
