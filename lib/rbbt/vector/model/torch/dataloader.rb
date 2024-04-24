class TorchModel
  def self.feature_tsv(elements, labels = nil, class_labels = nil)
    tsv = TSV.setup({}, :key_field => "ID", :fields => ["features"], :type => :flat)
    if labels
      tsv.fields = tsv.fields + ["label"]
      labels = case class_labels
               when Array
                 labels.collect{|l| class_labels.index l}
               when Hash
                 inverse_class_labels = {}
                 class_labels.each{|c,l| inverse_class_labels[l] = c }
                 labels.collect{|l| inverse_class_labels[l]}
               else
                 labels
               end
      elements.zip(labels).each_with_index do |p,i|
        features, label = p
        id = i
        if Array === features
          tsv[id] = features + [label]
        else
          tsv[id] = [features, label]
        end
      end
    else
      elements.each_with_index do |features,i|
        id = i
        if Array === features
          tsv[id] = features
        else
          tsv[id] = [features]
        end
      end
    end
    tsv
  end

  def self.feature_dataset(tsv_dataset_file, elements, labels = nil, class_labels = nil)
    tsv = feature_tsv(elements, labels, class_labels)
    Open.write(tsv_dataset_file, tsv.to_s)
    tsv_dataset_file
  end

  def self.text_dataset(tsv_dataset_file, elements, labels = nil, class_labels = nil)
    elements = elements.compact.collect{|e| e.gsub("\n", ' ') }
    tsv = feature_tsv(elements, labels, class_labels)
    tsv.fields[0] = "text"
    if labels.nil?
      tsv = tsv.to_single
    else
      tsv.type = :list
    end
    Open.write(tsv_dataset_file, tsv.to_s)
    tsv_dataset_file
  end

end
