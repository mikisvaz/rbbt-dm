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
    assert header.include? 'vector[y_l] y;'
  end

  def test_simple_fit
    Log.severity = 0
    res = STAN.fit({}, <<-EOF)
parameters{
real y;
}

model {
target += -0.5 * y * y;
}
    EOF
    ppp res
    Log.tsv res
  end

  def test_fit_vector
    Log.severity = 0
    data = {}
    real_mean = 4
    data[:y] = R.eval_a "rnorm(100, #{real_mean}, 1)"

    res = STAN.fit(data, <<-EOF, :iter => 10_000, :chains => 2)
parameters{
  real mu;
}
model{
  mu ~ normal(0,10);
  y ~ normal(mu, 1);
}
    EOF

    x = []
    m = Misc.mean(res.column("mu").values)

    assert (m - real_mean).abs < 0.5
  end

  def test_fit_matrix
    Log.severity = 0

    samples = 1000
    real_mean = 5
    y = TmpFile.with_file do |tsv|
      R.run <<-EOF
s = c(1,5,10)

samples = #{samples}
m = list()
for (i in seq(1,samples)){
  sample.name = paste("S",i, sep="")
  sample.values = rnorm(3,#{real_mean},1) * s
  m[[sample.name]] = sample.values
}

data = as.data.frame(m)
rbbt.tsv.write('#{tsv}', data)
      EOF

      TSV.open(tsv, :type => :list, :cast => :to_f)
    end

    y = y.transpose("Sample")

    res = STAN.fit({:y => y}, <<-EOF, :iter => 100, :warmup => 20, :chains => 1)
parameters{
  vector<lower=0>[y_c] s;
  real<lower=0> w_m;
}

model{
  s ~ cauchy(0,100);
  w_m ~ uniform(0,10);

  for (j in 1:y_c){
      y[,j] ~ normal(w_m*s[j], 1/s[j]);
  }
}
    EOF

    m = Misc.mean(res.column("w_m").values) 
    assert (m - real_mean).abs < (real_mean.to_f / 10)
  end

  def test_stream
    Log.severity = 0

    samples = 1000
    real_mean = 5
    y = TmpFile.with_file do |tsv|
      R.run <<-EOF
s = c(1,5,10)

samples = #{samples}
m = list()
for (i in seq(1,samples)){
  sample.name = paste("S",i, sep="")
  sample.values = rnorm(3,#{real_mean},1) * s
  m[[sample.name]] = sample.values
}

data = as.data.frame(m)
rbbt.tsv.write('#{tsv}', data)
      EOF

      TSV.open(tsv, :type => :list, :cast => :to_f)
    end

    y = y.transpose("Sample")

    io = STAN.stream_chain({:y => y}, <<-EOF, :iter => 100, :warmup => 20)
parameters{
  vector<lower=0>[y_c] s;
  real<lower=0> w_m;
}

model{
  s ~ cauchy(0,100);
  w_m ~ uniform(0,10);

  for (j in 1:y_c){
      y[,j] ~ normal(w_m*s[j], 1/s[j]);
  }
}
    EOF

    lines = 0
    while line = io.gets
      lines += 1
    end
    io.close
    io.join if io.respond_to? :join
    assert_equal 102, lines
  end
end

