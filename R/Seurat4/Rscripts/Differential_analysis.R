########################################################################
#
#  0 setup environment, install libraries if necessary, load libraries
# 
# ######################################################################
invisible(lapply(c("Seurat","dplyr","cowplot",
                   "magrittr","data.table","future","ggplot2","tidyr"), function(x) {
                           suppressPackageStartupMessages(library(x,character.only = T))
                   }))
source("https://raw.githubusercontent.com/nyuhuyang/SeuratExtra/master/R/Seurat4_differential_expression.R")
#conda activate r4.0.3
# SLURM_ARRAY_TASK_ID
slurm_arrayid <- Sys.getenv('SLURM_ARRAY_TASK_ID')
if (length(slurm_arrayid)!=1)  stop("Exact one argument must be supplied!")
# coerce the value to an integer
args <- as.integer(as.character(slurm_arrayid))
print(paste0("slurm_arrayid=",args))

path <- paste0("output/",gsub("-","",Sys.Date()),"/")
if(!dir.exists(path))dir.create(path, recursive = T)
# load files
#======1.2 load  Seurat =========================
object = readRDS("data/OSU_SCT_20210821.rds")
# Need 32GB
DefaultAssay(object) = "SCT"
Idents(object) = "Doublets"
object <- subset(object, idents = "Singlet")

step = c("SCT_snn_res.0.8","cell.types","combine",
         "clinical_response","Subcluster")[5]

if(step == "SCT_snn_res.0.8"){
    #opts = 0:75
    print(arg <- as.integer(args))
    Idents(object) = "SCT_snn_res.0.8"
    system.time(markers <- FindMarkers_UMI(object, 
                                           ident.1 = arg,
                                           group.by = "SCT_snn_res.0.8",
                                           logfc.threshold = 0.25, 
                                           only.pos = T,
                                           latent.vars = "nFeature_SCT",
                                           test.use = "MAST"))
    
    markers$cluster = arg
    if(args < 10) arg = paste0("0", args)
    write.csv(markers,paste0(path,arg,"_FC0.25_cluster_",args,".csv"))
    
}

if(step == "cell.types"){
    opts = sort(unique(object$cell.types)) #1:11
    print(opt <- opts[args])
    Idents(object) = "cell.types"
    system.time(markers <- FindMarkers_UMI(object, 
                                           ident.1 = opt,
                                           group.by = "cell.types",
                                           logfc.threshold = 0.25, 
                                           only.pos = T,
                                           latent.vars = "nFeature_SCT",
                                           test.use = "MAST"))
    
    markers$cluster = opt
    if(args < 10) arg = paste0("0", args)
    opt %<>% gsub(":|\\/","_",.)
    write.csv(markers,paste0(path,arg,"_FC0.25_cell.types_",opt,".csv"))
    
}

if(step == "combine"){
    opts = c("B-cells","MDSCs","Monocytes","NK cells",
             "T-cells:CD4+","T-cells:CD8+","T-cells:regs")
    
    print(opt <- opts[args])
    object %<>% subset(subset = cell.types %in% opt)
    Idents(object) = "treatment"
    system.time(markers <- FindMarkers_UMI(object, 
                                           ident.1 = "Ibrutinib",
                                           group.by = "treatment",
                                           logfc.threshold = 0.1, 
                                           only.pos = F,
                                           latent.vars = "nFeature_SCT",
                                           test.use = "MAST"))
    
    markers$cell.type = opt
    markers$cluster = "Ibrutinib vs Baseline"
    
    write.csv(markers,paste0(path,args,"_FC0.1_",opt,"_Ibrutinib vs Baseline.csv"))
    
}
    
if(step == "clinical_response"){
    opts = data.frame(cell.types = c(rep("B-cells",3),
                                     rep("MDSCs",3),
                                     rep("Monocytes",3),
                                     rep("NK cells",3),
                                     rep("T-cells:CD4+",3),
                                     rep("T-cells:CD8+",3),
                                     rep("T-cells:regs",3)),
                      response = c(rep(c("PD","PR","SD"),times = 7))
    )
    
    print(opt <- opts[args,])
    object %<>% subset(subset = cell.types %in% opt$cell.types
                       & response %in% opt$response)
    Idents(object) = "treatment"
    system.time(markers <- FindMarkers_UMI(object, 
                                           ident.1 = "Ibrutinib",
                                           group.by = "treatment",
                                           logfc.threshold = 0.1, 
                                           only.pos = F,
                                           latent.vars = "nFeature_SCT",
                                           test.use = "MAST"))
    
    markers$cell.type = opt$cell.types
    markers$response = opt$response
    markers$cluster = "Ibrutinib vs Baseline"
    
    arg = args
    if(args < 10) arg = paste0("0", args)
    write.csv(markers,paste0(path,arg,"_FC0.1_",opt$cell.types,"_",opt$response,".csv"))
}


if(step == "Subcluster"){
    # Need 64GB
    opts = c("B-cells","HSC/progenitors","MDSCs+Monocytes",
             "NK cells","T-cells:CD4+","T-cells:CD8+","T-cells:regs")
    object$cell.types %<>% gsub("MDSCs|Monocytes","MDSCs+Monocytes",.)
    print(opt <- opts[args])
    object %<>% subset(subset = cell.types %in% opt)
    Idents(object) = "FTH1_lvl"
    system.time(markers <- FindMarkers_UMI(object, 
                                           ident.1 = "FTH1 high",
                                           group.by = "FTH1_lvl",
                                           logfc.threshold = 0.1, 
                                           only.pos = F,
                                           latent.vars = "nFeature_SCT",
                                           test.use = "MAST"))
    
    markers$cell.type = opt
    markers$cluster = "Subcluster1 vs Subcluster2"
    
    write.csv(markers,paste0(path,args,"_FC0.1_",opt,"_Subcluster1 vs Subcluster2.csv"))
    
}
