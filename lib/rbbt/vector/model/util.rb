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

  def balance_labels
    counts = Misc.counts(@labels)
    min = counts.values.min

    used = {}
    new_labels = []
    new_features = []
    @labels.zip(@features).shuffle.each do |label, features|
      used[label] ||= 0
      next if used[label] > min
      used[label] += 1
      new_labels << label
      new_features << features
    end
    @labels = new_labels
    @features = new_features
  end
end
