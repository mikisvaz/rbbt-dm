gem "test-unit", "~> 3.0"
gem "minitest", "~> 5.5"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'test/unit'
require 'fileutils'

require 'rbbt'
require 'rbbt/resource/path'


class Test::Unit::TestCase
  def self.datafile_test(file)
    Path.setup(File.join(File.dirname(__FILE__), 'data', file.to_s))
  end

  def datafile_test(file)
    Test::Unit::TestCase.datafile_test(file)
  end

  def with_python(code, &block)
    TmpFile.with_file do |dir|
      pkg = "pkg#{rand(100)}"
      Open.write File.join(dir, "#{pkg}/__init__.py"), code

      RbbtPython.add_path dir

      Misc.in_dir dir do
        yield pkg
      end
    end
  end
end
