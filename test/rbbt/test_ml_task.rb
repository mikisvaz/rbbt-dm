require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper.rb')
require 'rbbt/ml_task'

class TestMLTask < Test::Unit::TestCase
  def test_MLTask

    triage = MLTask.new
    ml_task.pre_process do
    end
  end
end

