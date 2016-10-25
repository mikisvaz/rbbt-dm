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
end
