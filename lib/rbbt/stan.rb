require 'rbbt/util/R'
require 'mkfifo'

module STAN

  def self.save_data(directory, data = {})
    directory = directory.find if Path === directory
    types = {}
    load_str = "input_data = list()\n"

    data.each do |name, value|
      file = File.join(directory, name.to_s)
      case value
      when Integer
        Open.write(file, value.to_json)
        types[name] = 'integer'
        load_str << "input_data[['" << name.to_s << "']] = " << "fromJSON(txt='#{file}')" << "\n"
      when Float
        Open.write(file, value.to_json)
        types[name] = 'real'
        load_str << "input_data[['" << name.to_s << "']] = " << "fromJSON(txt='#{file}')" << "\n"
      when Array
        Open.write(file, value.to_json)
        if value.select{|v| Float === v}.empty?
          types[name] = 'iarray'
        else
          types[name] = 'array'
        end
        load_str << "input_data[['" << name.to_s << "_l']] = " << value.length.to_s << "\n"
        load_str << "input_data[['" << name.to_s << "']] = " << "fromJSON(txt='#{file}')" << "\n"
      when TSV
        Open.write(file, value.to_s)
        types[name] = 'matrix'
        load_str << "input_data[['" << name.to_s << "_c']] = " << value.fields.length.to_s << "\n"
        load_str << "input_data[['" << name.to_s << "_r']] = " << value.size.to_s << "\n"
        load_str << "#{name}.tmp = " << "rbbt.impute(rbbt.tsv('#{file}'))" << "\n"
        load_str << "input_data[['" << name.to_s << "']] = " << "#{name}.tmp" << "\n"
      when Path
        value = TSV.open(value)
        Open.write(file, value.to_s)
        types[name] = 'matrix'
        load_str << "input_data[['" << name.to_s << "_c']] = " << value.fields.length.to_s << "\n"
        load_str << "input_data[['" << name.to_s << "_r']] = " << value.size.to_s << "\n"
        load_str << "#{name}.tmp = " << "rbbt.impute(rbbt.tsv('#{file}'))" << "\n"
        load_str << "input_data[['" << name.to_s << "']] = " << "#{name}.tmp" << "\n"
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
      when 'real'
        types_str << "  " << "real " << name << ";\n"
      when 'integer'
        types_str << "  " << "int " << name << ";\n"
      when 'array'
        types_str << "  " << "int<lower=0> " << name << "_l" << ";\n"
        #types_str << "  " << "real " << name << "[" << name << "_l]" << ";\n"
        types_str << "  " << "vector" << "[" << name << "_l] "<< name  << ";\n"
      when 'iarray'
        types_str << "  " << "int<lower=0> " << name << "_l" << ";\n"
        #types_str << "  " << "real " << name << "[" << name << "_l]" << ";\n"
        types_str << "  " << "int " << name << "[" << name << "_l]" << ";\n"
      when 'matrix'
        types_str << "  " << "int<lower=0> " << name << "_c" << ";\n"
        types_str << "  " << "int<lower=0> " << name << "_r" << ";\n"
        #types_str << "  " << "real " << name << "[" << name << "_r," << name << "_c]" << ";\n"
        types_str << "  " << "matrix" << "[" << name << "_r," << name << "_c] " << name << ";\n"
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

  def self.exec(data, model, input_directory, parameter_chains, sample_file, debug = FALSE, stan_options = {})
    stan_options = Misc.add_defaults stan_options, :iter => 1000, :warmup => 500, :chains => 1, :seed => 2887, :refresh => 1200

    data = {} if data.nil?

    types, load_str = save_data(input_directory, data)
    data_header = self.data_header(types)
    stan_model = data_header + "\n" + model

    stan_file = Rbbt.var.stan_models[Misc.digest(stan_model).to_s << ".stan"].find
    Open.write(stan_file, stan_model)

    Log.debug "STAN model:\n" + stan_model

    script = <<-EOF
rbbt.require('rstan')
rbbt.require('jsonlite')

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

#{load_str} 

fit <- stan(file='#{stan_file}', data=input_data, sample_file='#{sample_file}', verbose=#{debug ? 'TRUE' : 'FALSE'}, #{R.hash2Rargs(stan_options)})

params <- as.data.frame(fit)

print(fit)
#{parameter_chains.nil? ? "" : "rbbt.tsv.write('#{parameter_chains}', params)" }
    EOF

    R.run script, nil, :monitor => debug
  end

  def self.stream_chain(data, model, directory = nil, options = {})
    options, directory = directory, nil if Hash === directory
    debug = Misc.process_options options, :debug

    if directory.nil?
      directory = TmpFile.tmp_file 
      erase = true
    end

    FileUtils.mkdir_p directory unless File.exist? directory
    input_directory  = File.join(directory, 'inputs')
    parameter_chains = File.join(directory, 'chains') unless erase
    summary          = File.join(directory, 'summary') unless erase
    sample_file      = File.join(directory, 'samples')

    File.mkfifo(sample_file)

    io = Misc.open_pipe do |sin|
      iteration = 1
      sin << "#: :type=:list#:cast=:to_f" << "\n"
      begin
        reader = File.open(sample_file, 'r')
        while line = reader.gets
          if line =~ /^#/
            new_line = line
            next
          elsif line =~ /^lp__/
            parts = line.split(",")
            new_line = "#Iteration\t" << parts * "\t"
          else
            parts = line.split(",")
            new_line = iteration.to_s << "\t" << parts * "\t"
            iteration += 1
          end
          sin << new_line 
        end
      rescue 
        Log.exception $!
        raise $!
      end
    end

    exec_thread = Thread.new do
      res = self.exec(data, model, input_directory, parameter_chains, sample_file, debug, options)
      Open.write(summary, res.read.to_s) unless summary.nil?
      Log.debug "Result from STAN:\n" << res.read
    end

    ConcurrentStream.setup io, :threads => [exec_thread] do
      Log.debug "Done chains for STAN"
      if erase
        FileUtils.rm_rf directory
      end
    end
  end

  def self.run(data, model, directory, options = {})
    debug = Misc.process_options options, :debug

    input_directory = File.join(directory, 'inputs')

    parameter_chains = File.join(directory, 'chains')
    summary = File.join(directory, 'summary')
    sample_file = File.join(directory, 'sample')

    res = self.exec(data, model, input_directory, parameter_chains, sample_file, debug, options)
    Log.debug "Result from STAN:\n" << res.read
    Open.write(summary, res.read)
    
    Open.open(parameter_chains)
  end

  def self.fit(data, model, options = {})
    TmpFile.with_file do |directory|
      FileUtils.mkdir_p directory
      res = self.run(data, model, directory, options)
      TSV.open(res, :type => :list, :cast => :to_f)
    end
  end


end
