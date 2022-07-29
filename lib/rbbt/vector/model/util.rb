class VectorModel
  attr_accessor :bar

  def bar(max = nil, desc = nil)
    desc, max = max, nil if desc.nil?
    @bar ||= Log::ProgressBar.new max
    @bar.desc = desc
    @bar.max = max
    @bar.init
    @bar
  end
end
