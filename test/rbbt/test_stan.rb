require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper.rb')
require 'rbbt/stan'

class TestClass < Test::Unit::TestCase
  def test_save_array

    data = {}
    data[:y] = [1,2,3,4]

    TmpFile.with_file do |directory|
      STAN.save_data(directory, data)
      assert File.exists?(File.join(directory, 'y'))
      assert_equal '[1,2,3,4]', Open.read(File.join(directory, 'y'))
    end

  end

  def test_data_header
    types = {:y => 'array'}

    header = STAN.data_header(types)
    assert header.include? 'real y[y_l]'
  end

  def test_fit
    Log.severity = 0
    data = {}
    data[:y] = [1,1,1,1,1,0,0,2,2]

    res = STAN.fit(data, <<-EOF, :iter => 10_000, :chains => 10)
parameters{
  real mu;
}

model{
  mu ~ normal(0,3);
  y ~ normal(mu, 1);
}
    EOF

    Log.tsv res

  end
end

