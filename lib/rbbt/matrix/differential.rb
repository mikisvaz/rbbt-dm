class Matrix
  def differential(main, contrast, path = nil)
    if Array === main and Array === contrast
      main_samples, contrast_samples = main, contrast
    else
      main_samples, contrast_samples = comparison main, contrast
    end

    Persist.persist(data_file, :tsv, :other => {:main => main_samples, :contrast => contrast_samples}, :prefix => "GENE", :dir => Matrix.matrix_dir, :no_load => true, :path => path) do |file|
      log2 = value_type == "count"
      GE.analyze(data_file, main_samples, contrast_samples, log2, path, format)
    end
  end
end
