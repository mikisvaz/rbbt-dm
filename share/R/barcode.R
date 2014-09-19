rbbt.GE.barcode <- function(matrix_file, output_file, sd.factor = 2, key.field = "Ensembl Gene ID"){
  data = rbbt.tsv(matrix_file)
  data.mean = rowMeans(data, na.rm=T)
  data.sd = apply(data, 1, sd, na.rm=T)
  data.threshold = as.matrix(data.mean) + sd.factor * as.matrix(data.sd)
  names(data.threshold) = names(data.mean)
  rm(data.mean)
  rm(data.sd)

  file.barcode = file(output_file, 'w')

  cat("#", file = file.barcode)
  cat(key.field, file = file.barcode)
  cat("\t", file = file.barcode)
  cat(colnames(data), file = file.barcode, sep="\t")
  cat("\n", file = file.barcode)
     
  for (gene in rownames(data)){
    barcode = (data[gene,] - data.threshold[gene]) > 0

    cat(gene, file = file.barcode)
    cat("\t", file = file.barcode)
    cat(barcode, file = file.barcode, sep = "\t")
    cat("\n", file = file.barcode)
  }
  close(file.barcode)
}


rbbt.GE.activity_cluster <- function(matrix_file, output_file, key.field = "ID"){

    library(mclust)

    data = rbbt.tsv(matrix_file)
    classes = apply(data,2,function(row){Mclust(row)$classification})

    rownames(classes) <- rownames(data)
    names(classes) <- c("Cluster")

    rbbt.tsv.write(output_file, classes, key.field)
}
