library(limma)

#########################################################################
# Model processing 

# Ratio
rbbt.dm.matrix.differential.ratio.oneside <- function(expr){
    ratio = apply(expr, 1 ,function(x){mean(x, na.rm = TRUE)})
    names(ratio) <- rownames(expr);
    return(ratio);
}

rbbt.dm.matrix.differential.ratio.twoside <- function(expr, contrast){
    ratio = rbbt.dm.matrix.differential.ratio.oneside(expr) - rbbt.dm.matrix.differential.ratio.oneside(contrast)
    names(ratio) <- rownames(expr);
    return(ratio);
}

# Limma
rbbt.dm.matrix.differential.limma.oneside <- function(expr, subset = NULL){

    if (is.null(subset)){
        fit <- lmFit(expr);
    }else{
        design = rep(0, dim(expr)[2]);
        design[names(expr) %in% subset] = 1;
    }

    fit <- lmFit(expr, design);

    fit <- eBayes(fit);

    sign = fit$t < 0;
    sign[is.na(sign)] = FALSE;
    fit$p.value[sign] =  - fit$p.value[sign];

    return(list(t= fit$t, p.values= fit$p.value));
}

rbbt.dm.matrix.differential.limma.twoside <- function(expr, subset.main, subset.contrast){

    design = cbind(rep(1,dim(expr)[2]), rep(0,dim(expr)[2]));
    colnames(design) <-c('intercept', 'expr');
    design[names(expr) %in% subset.main,]     = 1;
    design[names(expr) %in% subset.contrast,'intercept']     = 1;
    
    fit <- lmFit(expr, design);

    fit <- eBayes(fit);
    sign = fit$t[,2] < 0;
    sign[is.na(sign)] = FALSE;
    fit$p.value[sign,2] = - fit$p.value[sign,2];

    return(list(t= fit$t[,2], p.values= fit$p.value[,2]));
}


rbbt.dm.matrix.guess.log2 <- function(m, two.channel){
    if (two.channel){
        return (sum(m < 0, na.rm = TRUE) == 0);
    }else{
        return (max(m, na.rm = TRUE) > 100);
    }
}

rbbt.dm.matrix.differential <- function(file, main, contrast = NULL, log2 = FALSE, outfile = NULL, key.field = NULL, two.channel = NULL){
    data = data.matrix(rbbt.tsv(file));
    ids = rownames(data);
    if (is.null(key.field)){ key.field = "ID" }

    if (is.null(log2)){
      log2 = rbbt.dm.matrix.guess.log2(data, two.channel)
    }

    if (log2){
       data = log2(data);
       min = min(data[data != -Inf])
       data[data == -Inf] = min
       return
    }

    if (is.null(contrast)){
      ratio = rbbt.dm.matrix.differential.ratio.oneside(subset(data, select=main)); 
    }else{
      ratio = rbbt.dm.matrix.differential.ratio.twoside(subset(data, select=main), subset(data, select=contrast) ); 
    }

    if (is.null(contrast)){
        limma = NULL;
        tryCatch({ 
            limma = rbbt.dm.matrix.differential.limma.oneside(data, main); 
        }, error=function(x){
            cat("Limma failed for complete dataset. Trying just subset.\n", file=stderr());
            print(x, file=stderr());
            tryCatch({ 
                limma = rbbt.dm.matrix.differential.limma.oneside(subset(data, select=main)); 
            }, error=function(x){
                cat("Limma failed for subset dataset.\n", file=stderr());
                print(x, file=stderr());
            });
         })
    }else{
        limma = NULL;
        tryCatch({ 
            limma = rbbt.dm.matrix.differential.limma.twoside(data, main, contrast); 
        }, error=function(x){
            cat("Limma failed for complete dataset. Trying just subset.\n", file=stderr());
            print(x, file=stderr());
            tryCatch({ 
                limma = rbbt.dm.matrix.differential.limma.twoside(subset(data, select=c(main, contrast)), main, contrast); 
            }, error=function(x){
                cat("Limma failed for subset dataset.\n", file=stderr());
                print(x, file=stderr());
            });
         })

    }

    if (! is.null(limma)){
       result = data.frame(ratio = ratio[ids], t.values = limma$t[ids], p.values = limma$p.values[ids])
       result["adjusted.p.values"] = p.adjust(result$p.values, "fdr")
    }else{
       result = data.frame(ratio = ratio)
    }

   if (is.null(outfile)){
       return(result);
   }else{
       rbbt.tsv.write(outfile, result, key.field, ":type=:list#:cast=:to_f");
       return(NULL);
   }
}



############################################################################
############################################################################
############################################################################
############################################################################
############################################################################
# OLD STUFF


#MA.get_order <- function(values){
#    orders = values;
#    orders[,] = NA;
#
#    for (i in 1:dim(values)[2]){
#        positions = names(sort(values[,i],decreasing=T,na.last=NA));
#        orders[,i] = NA;
#        orders[positions,i] = 1:length(positions)
#    }
#    orders 
#}
#
#MA.guess.do.log2 <- function(m, two.channel){
#    if (two.channel){
#        return (sum(m < 0, na.rm = TRUE) == 0);
#    }else{
#        return (max(m, na.rm = TRUE) > 100);
#    }
#}
#
#MA.translate <- function(m, trans){
#    trans[trans==""] = NA;
#    trans[trans=="NO MATCH"] = NA;
#
#    missing = length(trans) - dim(m)[1];
#
## If extra genes
#    if (missing < 0){
#        trans = c(trans,rep(NA, - missing));
#        missing = 0;
#    }
#    n = apply(m,2,function(x){ 
## Complete data with missing genes
#         x.complete = c(x,rep(NA, missing));
#         tapply(x.complete, factor(trans), median)
#         });
#    n[sort(rownames(n),index.return=T)$ix,]
#}
#
## Conditions
#
#MA.conditions.has_control <- function(x){
#    keywords = c('none', 'control', 'normal', 'wild', 'baseline', 'untreat', 'uninfected', 'universal', 'reference', 'vehicle', 'w.t.','wt');
#    for(keyword in keywords){
#        control = grep(keyword, x, ignore.case = TRUE);
#        if (any(control)){
#            return(x[control[1]]);
#        }
#    }
#    return(NULL)
#}
#
#MA.condition.values <- function(values){
#    control = MA.conditions.has_control(values);
#
#    values.factor = factor(values);
#    values.levels = levels(values.factor);
#
## If there is a control state remove it from sorting
#    if (!is.null(control))
#        values.levels = values.levels[values.levels != control];    
#
#
## Use numeric sort if they all have numbers
#    if (length(grep('^ *[0-9]+',values.levels,perl=TRUE)) == length(values.levels)){
#        ix = sort(as.numeric(sub('^ *([0-9]+).*',"\\1",values.levels)), decreasing = T, index.return = TRUE)$ix
#    }else{
#        ix = sort(values.levels, decreasing = T, index.return = TRUE)$ix
#    }
#
#    return(list(values = values.levels[ix], control = control));
#}
#
#
##########################################################################
## Model processing 
#
## Ratio
#MA.ratio.two_channel <- function(m, conditions, main){
#    main = m[,conditions==main];
#    if (!is.null(dim(main))){
#        main = apply(main, 1 ,function(x){mean(x, na.rm = TRUE)});
#    }
#    return(main);
#}
#
#MA.ratio.contrast <- function(m, conditions, main, contrast){
#    main = m[,conditions==main];
#    if (!is.null(dim(main))){
#        main = apply(main, 1 ,function(x){mean(x, na.rm = TRUE)});
#    }
#
#    contrast = m[,conditions==contrast];
#    if (!is.null(dim(contrast))){
#        contrast = apply(contrast, 1 ,function(x){mean(x, na.rm = TRUE)});
#    }
#
#    return (main - contrast);
#}
#
#
## Limma
#
#MA.limma.two_channel <- function(m, conditions, main){
#    if (sum(conditions == main) < 3){
#        return(NULL);
#    }
#
#    design = rep(0,dim(m)[2]);
#    design[conditions == main] = 1;
#
## We need to subset the columns because of a problem with NA values. This
## might affect eBayes variance estimations, thats my guess anyway...
#
#    fit <- lmFit(m[,design == 1],rep(1, sum(design)));
#
#    tryCatch({
#             fit <- eBayes(fit);
#             sign = fit$t < 0;
#             sign[is.na(sign)] = FALSE;
#             fit$p.value[sign] =  - fit$p.value[sign];
#             return(list(t= fit$t, p.values= fit$p.value));
#     }, error=function(x){
#             print("Exception caught in eBayes", file=stderr);
#             print(x, file=stderr);
#     })
#
#    return(NULL);
#}
#
#MA.limma.contrast <- function(m, conditions, main, contrast){
#    if (sum(conditions == main) + sum(conditions == contrast) < 3){
#        return(NULL);
#    }
#    m = cbind(m[,conditions == main],m[,conditions == contrast]);
#
#    design = cbind(rep(1,dim(m)[2]), rep(0,dim(m)[2]));
#    colnames(design) <-c('intercept', 'main');
#    design[1:sum(conditions==main),2] = 1;
#
#
#    fit <- lmFit(m,design);
#    tryCatch({
#             fit <- eBayes(fit);
#             sign = fit$t[,2] < 0;
#             sign[is.na(sign)] = FALSE;
#             fit$p.value[sign,2] = - fit$p.value[sign,2] 
#             return(list(t= fit$t[,2], p.values= fit$p.value[,2] ));
#    }, error=function(x){
#             print("Exception caught in eBayes", file=stderr);
#             print(x, file=stderr);
#    })
#
#    return(NULL);
#}
#
#
##########################################################################
## Process conditions
#
#MA.strip_blanks <- function(text){
#    text = sub(' *$', '' ,text);
#    text = sub('^ *', '' ,text);
#
#    return(text);
#}
#
#MA.orders <- function(ratios, t){
#    best  = vector();
#    names = vector();
#    for (name in colnames(ratios)){
#        if (sum(colnames(t) == name) > 0){
#            best = cbind(best, t[,name]);
#            names = c(names, name);
#        }else{
#            best = cbind(best, ratios[,name]);
#            names = c(names, paste(name,'[ratio]', sep=" "));
#        }
#    }
#    rownames(best)   <- rownames(ratios);
#    orders           <- as.data.frame(MA.get_order(best));
#    colnames(orders) <- names;
#
#    return(orders);
#}
#
#MA.process_conditions.contrasts <- function(m, conditions, two.channel){
#    max_levels             = 10;
#    max_levels_control     = 1;
#
#
#    values = MA.condition.values(conditions);
#
#
#    ratios   = vector();
#    t       = vector();
#    p.values = vector();
#
#    ratio_names = vector();
#    t_names     = vector();
#
#    if (!is.null(values$control)){
#        contrast = values$control;
#        for (main in values$values){
#            name =  paste(main, contrast, sep = " <=> ")
#
#                ratio       = MA.ratio.contrast(m, conditions, main, contrast);
#            ratio_names = c(ratio_names, name);
#            ratios      = cbind(ratios, ratio);
#
#            res      = MA.limma.contrast(m, conditions, main, contrast);        
#            if (!is.null(res)){
#                t_names = c(t_names, name);
#                t           = cbind(t, res$t);
#                p.values     = cbind(p.values, res$p.values);
#            } 
#        }
#    }
#
#
#    if (length(values$values) <= max_levels_control || (is.null(values$control) && !two.channel && length(values$values) <= max_levels )){
#
#        remaining = values$values;
#        for (main in values$values){
#            remaining = remaining[remaining != main];
#            for (contrast in remaining){
#                name =  paste(main, contrast, sep = " <=> ");
#
#                ratio       = MA.ratio.contrast(m, conditions, main, contrast);
#                ratio_names = c(ratio_names, name);
#                ratios      = cbind(ratios, ratio);
#
#                res      = MA.limma.contrast(m, conditions, main, contrast);        
#                if (!is.null(res)){
#                    t_names  = c(t_names, name);
#                    t        = cbind(t, res$t);
#                    p.values = cbind(p.values, res$p.values);
#                } 
#            }
#        }
#    }
#
#
#    if (length(ratio_names) != 0){
#        ratio_names = as.vector(sapply(ratio_names, MA.strip_blanks));
#        colnames(ratios) <- ratio_names
#    }
#
#    if (length(t_names) != 0){
#        t_names = as.vector(sapply(t_names, MA.strip_blanks));
#        colnames(t) <- t_names;
#        colnames(p.values) <- t_names;
#    }
#
#
#    return(list(ratios = ratios, t=t, p.values = p.values));
#}
#
#MA.process_conditions.two_channel <- function(m, conditions){
#    values = MA.condition.values(conditions);
#
#    all_values = values$values;
#    if (!is.null(values$control)){
#        all_values = c(all_values, values$control);
#    }
#
#
#    ratios   = vector();
#    t        = vector();
#    p.values = vector();
#
#    ratio_names = vector();
#    t_names     = vector();
#
#
#    for (main in all_values){
#        name =  main;
#
#        ratio       = MA.ratio.two_channel(m, conditions, main);
#        ratio_names = c(ratio_names, name);
#        ratios      = cbind(ratios, ratio);
#
#        res      = MA.limma.two_channel(m, conditions, main);        
#        if (!is.null(res)){
#            t_names  = c(t_names, name);
#            t        = cbind(t, res$t);
#            p.values = cbind(p.values, res$p.values);
#        }
#    }
#
#    if (length(ratio_names) != 0){
#        ratio_names = as.vector(sapply(ratio_names, MA.strip_blanks));
#        colnames(ratios) <- ratio_names
#    }
#
#    if (length(t_names) != 0){
#        t_names = as.vector(sapply(t_names, MA.strip_blanks));
#        colnames(t) <- t_names;
#        colnames(p.values) <- t_names;
#    }
#
#    return(list(ratios = ratios, t=t, p.values = p.values));
#}
#
#
#
## Process microarray matrix
#
#MA.process <- function(m, conditions_list, two.channel = FALSE){
#
#    ratios   = vector();
#    t        = vector();
#    p.values = vector();
#
#    for(type in colnames(conditions_list)){
#        conditions = conditions_list[,type]
#
#            if (two.channel){
#                res = MA.process_conditions.two_channel(m, conditions);
#                if (length(res$ratios) != 0){    colnames(res$ratios) <- sapply(colnames(res$ratios),function(x){paste(type,x,sep=": ")});     ratios   = cbind(ratios,res$ratios);}
#                if (length(res$t) != 0){         colnames(res$t) <- sapply(colnames(res$t),function(x){paste(type,x,sep=": ")});               t        = cbind(t,res$t);}
#                if (length(res$p.values) != 0){  colnames(res$p.values) <- sapply(colnames(res$p.values),function(x){paste(type,x,sep=": ")}); p.values = cbind(p.values,res$p.values);}
#            }
#
#        res = MA.process_conditions.contrasts(m, conditions, two.channel);
#        if (length(res$ratios) != 0){    colnames(res$ratios) <- sapply(colnames(res$ratios),function(x){paste(type,x,sep=": ")});     ratios   = cbind(ratios,res$ratios);}
#        if (length(res$t) != 0){         colnames(res$t) <- sapply(colnames(res$t),function(x){paste(type,x,sep=": ")});               t        = cbind(t,res$t);}
#        if (length(res$p.values) != 0){  colnames(res$p.values) <- sapply(colnames(res$p.values),function(x){paste(type,x,sep=": ")}); p.values = cbind(p.values,res$p.values);}
#    }
#
#    orders <- MA.orders(ratios,t);
#    return(list(ratios = ratios, t=t, p.values = p.values, orders=orders));
#}
#
#
#MA.save <- function(prefix, orders, ratios, t , p.values, experiments, description = NULL) {
#    if (is.null(orders)){
#        cat("No suitable samples for analysis\n")
#            write(file=paste(prefix,'skip',sep="."), "No suitable samples for analysis" );
#    } else {
#        write.table(file=paste(prefix,'orders',sep="."), orders, sep="\t",  row.names=F, col.names=F, quote=F);
#        write.table(file=paste(prefix,'codes',sep="."), rownames(orders), sep="\t",  row.names=F, col.names=F, quote=F);
#        write.table(file=paste(prefix,'logratios',sep="."), ratios, sep="\t",  row.names=F, col.names=F, quote=F);
#        write.table(file=paste(prefix,'t',sep="."), t, sep="\t",  row.names=F, col.names=F, quote=F);
#        write.table(file=paste(prefix,'pvalues',sep="."), p.values, sep="\t",  row.names=F, col.names=F, quote=F);
#        write.table(file=paste(prefix,'experiments',sep="."), experiments, sep="\t",  row.names=F, col.names=F, quote=F);
#
#        write(file=paste(prefix,'description',sep="."),  description)
#    }
#}
#
#MA.load <- function(prefix, orders = TRUE, logratios = TRUE, t = TRUE, p.values = TRUE){
#    data = list();
#    genes <- scan(file=paste(prefix,'codes',sep="."),sep="\n",quiet=T,what=character());
#    experiments <- scan(file=paste(prefix,'experiments',sep="."),sep="\n",quiet=T,what=character());
#
#    experiments.no.ratio = experiments[- grep('ratio', experiments)];
#
#    if (orders){
#        orders <- read.table(file=paste(prefix,'orders',sep="."),sep="\t");
#        rownames(orders) <- genes;
#        colnames(orders) <- experiments;
#        data$orders=orders;
#    }
#    if (logratios){
#        logratios <- read.table(file=paste(prefix,'logratios',sep="."),sep="\t");
#        rownames(logratios) <- genes;
#        colnames(logratios) <- experiments;
#        data$logratios=logratios;
#    }
#    if (t){
#        t <- read.table(file=paste(prefix,'t',sep="."),sep="\t");
#        rownames(t) <- genes;
#        colnames(t) <- experiments.no.ratio;
#        data$t=t;
#    }
#    if (p.values){
#        p.values <- read.table(file=paste(prefix,'pvalues',sep="."),sep="\t");
#        rownames(p.values) <- genes;
#        colnames(p.values) <- experiments.no.ratio;
#        data$p.values=p.values;
#    }
#
#
#    return(data);
#}
