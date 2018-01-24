require 'rbbt/util/R'
module STAN

  def self.save_data(directory, data = {})
    directory = directory.find if Path === directory
    types = {}
    load_str = "input_data = list()\n"

    data.each do |name, value|
      file = File.join(directory, name.to_s)
      case value
      when Array
        Open.write(file, value.to_json)
        types[name] = 'array'
        load_str << "input_data[['" << name.to_s << "_l']] = " << value.length.to_s << "\n"
        load_str << "input_data[['" << name.to_s << "']] = " << "fromJSON(txt='#{file}')" << "\n"
      else
        raise "Unknown type of data #{ name }: #{Misc.fingerprint value}"
      end
    end

    [types, load_str]
  end

  def self.data_header(types)

    types_str = ""
    types.each do |name,type|
      name = name.to_s
      case type
      when 'array'
        types_str << "  " << "int<lower=0> " << name << "_l" << ";\n"
        types_str << "  " << "real " << name << "[" << name << "_l]" << ";\n"
      else
        raise "Unknown type for #{ name }: #{type}"
      end

    end
    <<-EOF
data{

#{types_str}
}
    EOF
  end

  def self.fit(data, model, options = {})
    options = Misc.add_defaults options, :iter => 1000, :warmup => 500, :chains => 1, :seed => 2887, :refresh => 1200
    iter, warmup, chains, seed, refresh = options.values_at :iter, :warmup, :chains, :seed, :refresh
    TmpFile.with_file do |directory|
      types, load_str = save_data(directory, data)
      data_header = self.data_header(types)

      stan_model = data_header + "\n" + model

      stan_file = Rbbt.var.stan_models[Misc.digest(stan_model).to_s << ".stan"].find
      Open.write(stan_file, stan_model)
      TmpFile.with_file do |output|
        script = <<-EOF
rbbt.require('rstan')
rbbt.require('jsonlite')

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

        #{load_str} 

fit <- stan(file='#{stan_file}', data=input_data, verbose=TRUE,
            iter=#{iter}, warmup=#{warmup}, chains=#{chains}, seed=#{seed}, refresh=#{refresh})

params <- as.data.frame(extract(fit, permuted=FALSE))

rbbt.tsv.write('#{output}', params)
        EOF

        R.run script, nil, :monitor => true
        TSV.open(output, :type => :list, :cast => :to_f)
      end
    end
  end


end
