#' @importFrom grDevices cm.colors colorRampPalette dev.list
#' @importFrom grDevices dev.new dev.off heat.colors jpeg palette
#' @importFrom grDevices pdf png rainbow tiff
#' @importFrom graphics abline axis barplot box boxplot curve
#' @importFrom graphics dotchart hist layout legend lines mtext
#' @importFrom graphics par pie plot points polygon segments text
#' @importFrom methods is
#' @importFrom stats as.dendrogram cor cutree dist ecdf
#' @importFrom stats formula hatvalues hclust lm lsfit median
#' @importFrom stats na.omit pchisq pf pnorm prcomp pt qbeta
#' @importFrom stats qqplot qt quantile reformulate residuals
#' @importFrom stats rnorm runif uniroot var
#' @importFrom utils head install.packages installed.packages
#' @importFrom utils memory.limit memory.size object.size read.csv
#' @importFrom utils read.delim read.table write.csv write.table
#' @importFrom compiler cmpfun
#' @importFrom ape as.phylo
#' @importFrom lme4 lmer lmerControl
#' @importFrom MASS ginv
#' @importFrom plotly plot_ly add_lines add_trace
#' @importFrom grid grid.edit gPath gpar
#' @importFrom EMMREML emmreml
#' @importFrom scatterplot3d scatterplot3d
#' @importFrom bigmemory deepcopy is.big.matrix
#' @importFrom LDheatmap LDheatmap

`GAPIT.0000` <-
function(){
##############################################################################################
#GAPIT: Genome Association and Prediction Integrated Tool
#Objective 1: State of art methods for high  power, accuracy and speed;
#Objective 2: User friendly by design, help documents, and web forum;
#Objective 3: Comprehensive output to interpret data and results;
#Objective 4: Informative tables and high quality figures for reports and publication;

#Methods implimented: 
# 1. GLM (Structure or Q method for GWAS, Pritchard et. al. Genetics, 2000)
# 2. MLM (Q+K, Yu et. al. Nature Genetics, 2006)
# 3. gBLUP (Marker based kinship, Zhang et. al. Journal of Animal Science, 2007)
# 4. PCA (Zhao et. al. Plos Genetics, 2007)
# 5. EMMA (Kang et. al. Genetics, 2008)
# 6. CMLM (Zhang et. al. Nature Genetics, 2010)
# 7. EMMAx (Kang et. al. Nature Genetics, 2010)
# 8. P3D (Zhang et. al. Nature Genetics, 2010)
# 9. FaST-LMM (Lippert et. al. Nature Methods, 2011)
# 10. ECMLM (Li et. al. BMC Bioogy, 2014)
# 11. SUPER (Wang et. al. PLoS One, 2014)

#Designed by Zhiwu Zhang
#Authors of paper on Bioinformatics (2012, 28:2397-2399): Alex Lipka, Feng Tian, Qishan Wang, Xiaolei Liu, Meng Li,You Tang and Zhiwu Zhang
#Authors of paper on Plant Genome (2016, Vol 9, No. 2): You Tang, Xiaolei Liu, Jiabo Wang, Meng Li, Qishan Wang, Feng Tian, Zhongbin Su, Yuchun Pan, Di Liu, Alexander E. Lipka, Edward S. Buckler, and Zhiwu Zhang
if(!require(multtest)) 
{
	if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
    BiocManager::install("multtest")
	#source("http://www.bioconductor.org/biocLite.R")
    #biocLite("multtest")
}
if(!require(gplots)) install.packages("gplots")
if(!require(LDheatmap)) install.packages("LDheatmap")
if(!require(genetics)) install.packages("genetics")
if(!require(ape)) install.packages("ape")
if(!require(EMMREML)) install.packages("EMMREML")
if(!require(scatterplot3d)) install.packages("scatterplot3d")
#if(!require(scatterplot3d)) install.packages("scatterplot3d")

# required_pkg = c("MASS", "data.table","biganalytics","ape", "magrittr","bigmemory", "gplots", "compiler", "scatterplot3d", "R.utils", "rrBLUP", "BGLR")
# missing_pkg = required_pkg[!(required_pkg %in% installed.packages()[,"Package"])]
# if(length(missing_pkg)) install.packages(missing_pkg, repos="http://cran.rstudio.com/")
if(!'multtest'%in% installed.packages()[,"Package"]){
	if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
    BiocManager::install("snpStats")
	#source("http://www.bioconductor.org/biocLite.R")
	#biocLite("multtest")
	#biocLite("snpStats")
}




GAPIT.Version="2018.08.18, GAPIT 3.0"
print(paste("All packages are loaded already !  ","GAPIT.Version is ",GAPIT.Version,sep=""))
return(GAPIT.Version)
}
#=============================================================================================

 #Object: To calculate Area Under (ROC) Curve (AUC)
 #Straitegy: NA
 #Output: P value
 #intput: beta-power and alpha-fdr or type I error
 #Authors: Zhiwu Zhang
 #Last update: December 18, 2015
##############################################################################################
GAPIT.AUC=function(beta=NULL,alpha=NULL){
	n=length(beta)
	#plot(alpha,beta,type="b")
	db=beta[-1]-beta[-n]
	da=1-.5*(alpha[-1]+alpha[-n])
	ab=da*db
	AUC=sum(ab)
	return(AUC)
}
#=============================================================================================
#Object: To generate binary phenotype
 #Straitegy: NA
 #Output: binary phenotype (0 and 1's)
 #intput: genetic effect (x), hertiability (h2) and ratio of 1's (r)
 #Authors: Zhiwu Zhang
 #Last update: March 18, 2016
##############################################################################################
`GAPIT.BIPH` <-
function(x=0,h2=.5,r=.25){
    #To assign probability for given standard normal variable x and h2
    #Author: Zhiwu Zhang
    #Last update: Febuary 27, 2016
    p=pnorm(x)
    srp=1-p-r
    sh=1/(1-sqrt(h2))
    adj=(r-.5)*(1-sqrt(h2))
    f=1/(1+exp(sh*srp))+adj
    return(f)
  }
#=============================================================================================


`GAPIT.Block` <-
function(Z,GA,KG){
#Object: To split a group kinship into two blocks containing individuals with and without phenotype
#Output: GAU,KW,KO,KWO
#Authors: Zhiwu Zhang and Alex Lipka 
# Last update: April 14, 2011 
##############################################################################################
# To separate group kiship into two blocks: with and without phenotype.
# A group goes to with phenotype as loog as it has one phenotyped individual.

#find position in group assignment (GA) for the individual associate with phenotype (specified by Z)
#taxa=unique(intersect(as.matrix(Z[1,-1]),GA[,1]))

taxa.Z=as.matrix(Z[1,-1])
taxa.GA=as.matrix(GA[,1])
position=taxa.GA%in%taxa.Z

#Initial block as 2
GAU=cbind(GA,2)

#Assign block as 1 if the individual has phenotype
GAU[position,3]=1

#Modify the non-phenotyped individuals if they in a group with phenotyped individuals
#To find the groups with phenotyped individuals
#update block assignment for all these groups
#get list of group that should be block 1

#grp.12=as.matrix(unique(GAU[,2]))
#grp.1=as.matrix(unique(GAU[which(GAU[,3]==1),2]))
#grp.2= as.matrix(setdiff(grp.12,grp.1))

grp.12=as.matrix(as.vector(unique(GAU[,2])) ) #unique group
grp.1=as.matrix(as.vector(unique(GAU[which(GAU[,3]==1),2])) ) #unique phenotyped group
grp.2= as.matrix(as.vector(setdiff(grp.12,grp.1))) #unique unphenotyped group

numWithout=length(grp.2)

order.1=1:length(grp.1)
order.2=1:length(grp.2)
if(numWithout >0) grpblock=as.matrix(rbind(cbind(grp.1,1,order.1), cbind(grp.2,   2,    order.2)))
if(numWithout==0) grpblock=as.matrix(      cbind(grp.1,1,order.1),                       )

order.block=order(as.matrix(GAU[,3]))
colnames(grpblock)=c("grp","block","ID")

#Indicators: 1-Phenotype, 1.5- unphenotyped but in a group with other phenotyped, 2-rest  (Zhiwu, Dec 7,2012)
#GAU0 <- merge(GAU[order.block,-3], grpblock, by.x = "X2", by.y = "grp")
#GAU=GAU0[,c(2,1,3,4)]
#print(head(GAU))
GAU1 <- merge(GAU[order.block,], grpblock, by.x = "X2", by.y = "grp")
#print(GAU1)
GAU1[,4]=(as.numeric(GAU1[,3])+as.numeric(GAU1[,4]))/2
#print(GAU1)

GAU=GAU1[,c(2,1,4,5)]
KW=KG[grp.1,grp.1]
KO=KG[grp.2,grp.2]
KWO=KG[grp.1,grp.2]

#write.table(GAU, "GAU.txt", quote = FALSE, sep = "\t", row.names = TRUE,col.names = TRUE)

#print("GAPIT.Block accomplished successfully!")

return(list(GAU=GAU,KW=KW,KO=KO,KWO=KWO))
}#The function GAPIT.Block ends here
#=============================================================================================

`GAPIT.Bread` <-
function(Y=NULL,CV=NULL,Z=NULL,KI=NULL,GK=NULL,GD=NULL,GM=NULL,
              method=NULL,delta=NULL,vg=NULL,ve=NULL,LD=0.01,GTindex=NULL,
              file.output=TRUE,opt="extBIC"){
#Object: To calculate p-values of SNPs by using method of GLM, MLM, CMLM, FaST, SUPER and DC  
#Straitegy: NA
#Output: GWAS, GPS,REMLs,vg,ve,delta
#intput: 
#Y: phenotype with columns of taxa,Y1,Y2...
#CV: covariate variables with columns of taxa, v1,v2...
#GD: same as GK. This is the genotype to screen, the columns are taxa,SNP1,SNP2,...
#GK: Genotype data in numerical format, taxa goes to row and snp go ti columns. the first column is taxa
#GM: Genotype map with columns of snpID,chromosome and position
#method: Options are GLM, MLM, CMLM, FaST, SUPER ,FARM-CPU and DC 
#Authors: Zhiwu Zhang
#Last update: November 2, 2011
##############################################################################################
#print("GAPIT.SUPER in progress...")

#Performing first screening with GLM
if(method=="GLM"){
#print("---------------screening by GLM----------------------------------")
  #print(GTindex)
  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  model=("GLM"),
  QC=FALSE,
  GTindex=GTindex,
  file.output=file.output				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with MLM
if(method=="MLM"){
#print("---------------screening by MLM----------------------------------")

  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  group.from=nrow(Y),			
  group.to=nrow(Y),
  QC=FALSE,
  GTindex=GTindex,
  file.output=file.output				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with Compressed MLM
if(method=="CMLM"){
#print("---------------screening by CMLM----------------------------------")
  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  group.from=1,			
  group.to=nrow(Y),
  QC=FALSE,
  GTindex=GTindex,
  file.output=file.output				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with FaST-LMM
if(method=="FaST" | method=="SUPER"| method=="DC")
{
  GWAS=NULL
  GPS=NULL
  if(!is.null(vg) & !is.null(vg) & is.null(delta)) delta=ve/vg
  if(is.null(vg) & is.null(ve))
  {

    myFaSTREML=GAPIT.get.LL(pheno=matrix(Y[,-1],nrow(Y),1),geno=NULL,snp.pool=as.matrix(GK[,-1]),X0=as.matrix(cbind(matrix(1,nrow(CV),1),CV[,-1])))
    
#print("Transfer data...")    
    REMLs=-2*myFaSTREML$LL  
    delta=myFaSTREML$delta
    vg=myFaSTREML$vg
    ve=myFaSTREML$ve
    #GPS=myFaSTREML$GPS
  }

mySUPERFaST=GAPIT.SUPER.FastMLM(ys=matrix(Y[,-1],nrow(Y),1),X0=as.matrix(cbind(matrix(1,nrow(CV),1),CV[,-1])),snp.pool=as.matrix(GK[-1]), xs=as.matrix(GD[GTindex,-1]),vg=vg,delta=delta,LD=LD,method=method)

GWAS=cbind(GM,mySUPERFaST$ps,mySUPERFaST$stats,mySUPERFaST$dfs,mySUPERFaST$effect)
}#End of if(method=="FaST" | method=="SUPER")





#FarmCPU
if(method=="FarmCPU")
{
  if(!require(bigmemory)) install.packages("bigmemory")
  if(!require(biganalytics)) install.packages("biganalytics")
library(bigmemory)  #for FARM-CPU
library(biganalytics) #for FARM-CPU
if(!exists('FarmCPU', mode='function'))source("http://www.zzlab.net/FarmCPU/FarmCPU_functions.txt")#web source code
colnames(GM)[1]="SNP"

myFarmCPU=FarmCPU(
Y=Y,#Phenotype
GD=GD,#Genotype
GM=GM,#Map information
CV=CV[,2:ncol(CV)],
file.output=T
)


xs=t(GD[,-1])
#print(dim(xs))
gene_taxa=colnames(GD)[-1]
ss=apply(xs,1,sum)
ns=nrow(GD)
storage=cbind(.5*ss/ns,1-.5*ss/ns)
maf=as.data.frame(cbind(gene_taxa,apply(cbind(.5*ss/ns,1-.5*ss/ns),1,min)))
colnames(maf)=c("SNP","maf")
nobs=ns
#print(dim(myFarmCPU$GWAS))
#print(length(maf))
myFarmCPU$GWAS=merge(myFarmCPU$GWAS[,-5],maf, by.x = "SNP", by.y = "SNP")
GWAS=cbind(myFarmCPU$GWAS,nobs)
GWAS=GWAS[order(GWAS$P.value),]
#colnames(GWAS)=c("SNP","Chromosome","Position","mp","mc","maf","nobs")

GPS=myFarmCPU$Pred

h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL
#colnames(GPS)[3]=c("Prediction")
}
#MLMM
if(method=="MLMM")
{
print(" GWAS by MLMM method !!")
Y=Y[!is.na(Y[,2]),]
taxa_Y=as.character(Y[,1])
taxa_GD=as.character(GD[,1])
taxa_CV=as.character(CV[,1])
GD=GD[taxa_GD%in%taxa_Y,]
CV=CV[taxa_CV%in%taxa_Y,]

#print(dim(Y))
#print(dim(GD))
#print(dim(CV))


KI= GAPIT.kinship.VanRaden(snps=as.matrix(GD[,-1]))
colnames(KI)=as.character(GD[,1])
 
if(is.null(CV))
{
mymlmm=mlmm(
Y=Y[,2],#Phenotype
X=as.matrix(GD[,-1]),#Genotype
K=as.matrix(KI),
#cofs=CV[,2:ncol(CV)],
nbchunks = 2, maxsteps = 10, thresh = 1.2 * 10^-5)

}else{
mymlmm=mlmm_cof(
Y=Y[,2],#Phenotype
X=as.matrix(GD[,-1]),#Genotype
K=as.matrix(KI),
cofs=as.matrix(CV[,2:ncol(CV)]),
nbchunks = 2, maxsteps = 10, thresh = 1.2 * 10^-5)
}
if(opt=='extBIC'){
GWAS_result=mymlmm$opt_extBIC$out
}
if(opt=='mbonf'){
GWAS_result=mymlmm$opt_mbonf$out
}
if(opt=='thresh'){
GWAS_result=mymlmm$opt_thresh$out
}
colnames(GWAS_result)=c("SNP","P.value")
xs=t(GD[,-1])
#print(dim(xs))
gene_taxa=colnames(GD)[-1]
colnames(GM)=c("SNP","Chromosome","position")
ss=apply(xs,1,sum)
ns=nrow(GD)
storage=cbind(.5*ss/ns,1-.5*ss/ns)
maf=as.data.frame(cbind(gene_taxa,apply(cbind(.5*ss/ns,1-.5*ss/ns),1,min)))
colnames(maf)=c("SNP","maf")
nobs=ns
GWAS_GM=merge(GM,GWAS_result, by.x = "SNP", by.y = "SNP")
mc=matrix(NA,nrow(GWAS_GM),1)
GWAS_GM=cbind(GWAS_GM,mc)
GWAS_GM_maf=merge(GWAS_GM,maf, by.x = "SNP", by.y = "SNP")

GWAS=cbind(GWAS_GM_maf,nobs)
#print(head(GWAS))
GWAS=GWAS[order(GWAS$P.value),]
GPS=NULL
#h2=mymlmm$step_table$h2[length(mymlmm$step_table$h2)]
h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL
colnames(GWAS)=c("SNP","Chromosome","Position","P.value","effec","maf","nobs")

}
#print("GAPIT.Bread succeed!")  
return (list(GWAS=GWAS, GPS=GPS,REMLs=REMLs,vg=vg,ve=ve,delta=delta))
} #end of GAPIT.Bread
#=============================================================================================

`GAPIT.Burger` <-
function(Y=NULL,CV=NULL,GK=NULL){
    #Object: To calculate likelihood, variances and ratio
    #Straitegy: NA
    #Output: P value
    #intput:
    #Y: phenotype with columns of taxa,Y1,Y2...
    #CV: covariate variables with columns of taxa,v1,v2...
    #GK: Genotype data in numerical format, taxa goes to row and snp go to columns. the first column is taxa (same as GAPIT.bread)
    #Authors: Xiaolei Liu ,Jiabo Wang and Zhiwu Zhang
    #Last update: November 2, 2015
##############################################################################################
    #print("GAPIT.Burger in progress...")
    
    if(!is.null(CV)){
        #CV=as.matrix(CV)#change CV to a matrix when it is a vector xiaolei changed here
		#theCV=as.matrix(cbind(matrix(1,nrow(CV),1),CV)) ###########for FarmCPU
		  theCV=as.matrix(cbind(matrix(1,nrow(CV),1),CV[,-1])) #reseted by Jiabo ,CV frame is wrong,and not rm taxa
                                                         #############for GAPIT other method GWAS
    }else{
        theCV=matrix(1,nrow(Y),1)
    }
    
#handler of single column GK
n=nrow(GK)
m=ncol(GK)
if(m>2){
theGK=as.matrix(GK[,-1])
}else{
theGK=matrix(GK[,-1],n,1)
}

myFaSTREML=GAPIT.get.LL(pheno=matrix(Y[,-1],nrow(Y),1),geno=NULL,snp.pool=theGK,X0=theCV   )
    REMLs=-2*myFaSTREML$LL
    delta=myFaSTREML$delta
    vg=myFaSTREML$vg
    ve=myFaSTREML$ve
    
    #print("GAPIT.Burger succeed!")
    return (list(REMLs=REMLs,vg=vg,ve=ve,delta=delta))
} #end of GAPIT.Burger.Bus
#=============================================================================================

`GAPIT.Bus`<-
function(Y=NULL,CV=NULL,Z=NULL,GT=NULL,KI=NULL,GK=NULL,GD=NULL,GM=NULL,
         WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),
         method=NULL,delta=NULL,vg=NULL,ve=NULL,LD=0.01,GTindex=NULL,
         cutOff=0.01,Multi_iter=FASLE,num_regwas=10,Random.model=FALSE,
         p.threshold=NA,QTN.threshold=0.01,maf.threshold=0.03,
         method.GLM="FarmCPU.LM",method.sub="reward",method.sub.final="reward",method.bin="static",
         DPP=1000000,bin.size=c(5e5,5e6,5e7),bin.selection=seq(10,100,10),
		 file.output=TRUE,opt="extBIC"){
#Object: To license data by method
#Output: Coresponding numerical value
# This function is used to run multiple method, Thanks MLMM FarmCPU Blink to share program and code.
#Authors: Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
GR=NULL
#print(head(CV))
if(method=="GLM"){
#print("---------------screening by GLM----------------------------------")

  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  group.from=0,			
  group.to=0,
  QC=FALSE,
  GTindex=GTindex,
  file.output=F				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with MLM
if(method=="MLM"){
#print("---------------screening by MLM----------------------------------")

  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  group.from=nrow(Y),			
  group.to=nrow(Y),
  QC=FALSE,
  GTindex=GTindex,
  file.output=F				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with Compressed MLM
if(method=="CMLM"){
#print("---------------screening by CMLM----------------------------------")
  myGAPIT <- GAPIT(
  Y=Y,			
  CV=CV,
  Z=Z,
  KI=KI,
  GD=GD,
  GM=GM,
  group.from=1,			
  group.to=nrow(Y),
  QC=FALSE,
  GTindex=GTindex,
  file.output=F				
  )
  GWAS=myGAPIT$GWAS 
  GPS=myGAPIT$GPS 
  REMLs=myGAPIT$REMLs  
  delta=myGAPIT$ve/myGAPIT$va
  vg=myGAPIT$vg
  ve=myGAPIT$ve
}

#Performing first screening with FaST-LMM
if(method=="FaST" | method=="SUPER"| method=="DC")
{
  GWAS=NULL
  GPS=NULL
  if(!is.null(vg) & !is.null(vg) & is.null(delta)) delta=ve/vg
  if(is.null(vg) & is.null(ve))
  {
    #print("!!!!!!!!!!!!!!!!")
    myFaSTREML=GAPIT.get.LL(pheno=matrix(Y[,-1],nrow(Y),1),geno=NULL,snp.pool=as.matrix(GK[,-1]),X0=as.matrix(cbind(matrix(1,nrow(CV),1),CV[,-1])))
    #print(myFaSTREML)
#print("Transfer data...")    
    REMLs=-2*myFaSTREML$LL  
    delta=myFaSTREML$delta
    vg=myFaSTREML$vg
    ve=myFaSTREML$ve
    #GPS=myFaSTREML$GPS
  }

mySUPERFaST=GAPIT.SUPER.FastMLM(ys=matrix(Y[,-1],nrow(Y),1),X0=as.matrix(cbind(matrix(1,nrow(CV),1),CV[,-1])),snp.pool=as.matrix(GK[-1]), xs=as.matrix(GD[GTindex,-1]),vg=vg,delta=delta,LD=LD,method=method)
GWAS=cbind(GM,mySUPERFaST$ps,mySUPERFaST$stats,mySUPERFaST$dfs,mySUPERFaST$effect)
}#End of if(method=="FaST" | method=="SUPER")


if(method=="FarmCPU")
{
  if(!require(bigmemory)) install.packages("bigmemory")
  if(!require(biganalytics)) install.packages("biganalytics")
library(bigmemory)  #for FARM-CPU
library(biganalytics) #for FARM-CPU
#if(!exists('FarmCPU', mode='function'))source("http://www.zzlab.net/FarmCPU/FarmCPU_functions.txt")#web source code

colnames(GM)[1]="SNP"

#print(GTindex)
if(!is.null(CV))
{       farmcpuCV=CV[,2:ncol(CV)]
  }else{
        farmcpuCV=NULL
}
#print(head(farmcpuCV))
# print(dim(GD))
# print(dim(farmcpuCV))
#print(Y)
myFarmCPU=FarmCPU(
        Y=Y,#Phenotype
        GD=GD,#Genotype
        GM=GM,#Map information
        CV=farmcpuCV,
        cutOff=cutOff,p.threshold=p.threshold,QTN.threshold=QTN.threshold,
        maf.threshold=maf.threshold,method.GLM=method.GLM,method.sub=method.sub,
        method.sub.final=method.sub.final,method.bin=method.bin,bin.size=c(5e5,5e6,5e7),bin.selection=seq(10,100,10),
        file.output=FALSE
        )
seq_farm=myFarmCPU$seqQTN
taxa=names(Y)[2]
#print(taxa)
GWAS=myFarmCPU$GWAS
#print(head(GWAS))
 X=GD[,-1]
 ss=apply(X,2,sum)
 ns=nrow(GD)
 nobs=ns
 GWAS=cbind(GWAS,nobs)

maf=apply(cbind(.5*ss/ns,1-.5*ss/ns),1,min)
GWAS$maf=maf
#print(head(GWAS))
GWAS[is.na(GWAS[,4]),4]=1

sig=GWAS[GWAS[,4]<(cutOff/(nrow(GWAS))),1:5]
sig_pass=TRUE
if(nrow(sig)==0)sig_pass=FALSE

if(Multi_iter&sig_pass)
{

sig=GWAS[GWAS[,4]<(cutOff/(nrow(GWAS))),1:5]
sig=sig[!is.na(sig[,4]),]
sig_position=as.numeric(as.matrix(sig[,1:3])[,2])*10^10+as.numeric(as.matrix(sig[,1:3])[,3])
sig=sig[order(sig_position),]
sig_order=as.numeric(rownames(sig))
#if(setequal(sig_order,numeric(0))) break

n=nrow(sig)
if(length(sig_order)!=1){
  diff_order=abs(sig_order[-length(sig_order)]-sig_order[-1])

  diff_index=diff_order<num_regwas

  count=0
  diff_index2=count
  for(i in 1:length(diff_index))
  {
    if(!diff_index[i]) count=count+1
    diff_index2=append(diff_index2,count)
  }
}else{
  diff_order=0
  diff_index2=0
}

sig_bins=rle(diff_index2)$lengths
num_bins=length(sig_bins)

# sig_diff_index=sig_diff<windowsize
#GWAS0=GWAS
#####################
print("The number of significant markers is")
print(n)
if(n!=num_bins)
{
  print("The  number of significant bins is")
  print(num_bins)
}
# print(windowsize)
 if(num_bins>0)
 {
  for(i in 1:num_bins)
  { 
    n_sig=sig_bins[i]
    if(i==1)
    {  j=1:n_sig
      }else{
       j=(sum(sig_bins[1:(i-1)])+1):sum(sig_bins[1:i])
      }
    aim_marker=sig[j,]
    #print(aim_marker)
    aim_order=as.numeric(rownames(aim_marker))
    aim_area=rep(FALSE,(nrow(GWAS)))
    # print(head(sig))
    # print(aim_order)

    #aim_area[c((aim_order-num_regwas):(aim_order-1),(aim_order+1):(aim_order+num_regwas))]=TRUE
    if(min(aim_order)<num_regwas)
    {
      aim_area[c(1:(max(aim_order)+num_regwas))]=TRUE

    }else{
      aim_area[c((min(aim_order)-num_regwas):(max(aim_order)+num_regwas))]=TRUE
    }
    # Next code can control with or without core marker in seconde model
    aim_area[aim_order]=FALSE  # without
    if(!is.null(farmcpuCV))
    {
      secondCV=cbind(farmcpuCV,X[seq_farm[!seq_farm%in%aim_order]])
    }else{
      secondCV=cbind(GD[,1],X[seq_farm[!seq_farm%in%aim_order]])

    }
    aim_area=aim_area[1:(nrow(GWAS))]
    #if(setequal(aim_area,logical(0))) next
        # this is used to set with sig marker in second model
        # aim_area[GM[,1]==aim_marker[,1]]=FALSE 
        
        secondGD=GD[,c(TRUE,aim_area)]
        secondGM=GM[aim_area,]
        print("Now that is multiple iteration for new farmcpu !!!")
        myGAPIT_Second <- FarmCPU(
                        Y=Y,
                        GD=secondGD,
                        GM=secondGM,
                        CV=secondCV,
                        file.output=F
                        )
        Second_GWAS= myGAPIT_Second$GWAS [,1:4]
        Second_GWAS[is.na(Second_GWAS[,4]),4]=1
        orignal_GWAS=GWAS[aim_area,]
        GWAS_index=match(Second_GWAS[,1],GWAS[,1])
        #test_GWAS=GWAS
        GWAS[GWAS_index,4]=Second_GWAS[,4]
   }
 }
}

GWAS[,2]=as.numeric(as.character(GWAS[,2]))
GWAS[,3]=as.numeric(as.character(GWAS[,3]))
#rint(head(GWAS))
nobs=ns

#print(head(GWAS))
GWAS=GWAS[,c(1:5,7,6)]
#print(head(GWAS))
if(Random.model)GR=GAPIT.RandomModel(Y=Y,X=GD[,-1],GWAS=GWAS,CV=cbind(Y[,1],farmcpuCV),cutOff=cutOff,GT=GT)

GPS=myFarmCPU$Pred
#colnames(GPS)[3]=c("Prediction")

h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL
#print(dim(GWAS))
#print(head(GWAS))
system(paste("rm -f FarmCPU.",taxa,".GWAS.Results.csv",sep=""))
system(paste("rm -f FarmCPU.",taxa,".Manhattan.Plot.Genomewise.pdf",sep=""))
system(paste("rm -f FarmCPU.",taxa,".QQ-Plot.pdf",sep=""))

print("FarmCPU has been done succeedly!!")
}
if(method=="BlinkC")
{
blink_GD=t(GD[,-1])
blink_GM=GM
blink_Y=Y
blink_Y[is.na(blink_Y)]="NaN"
colnames(blink_Y)=c("taxa","trait1")
blink_CV=CV
write.table(blink_GD,"myData.dat",quote=F,col.names=F,row.names=F)
write.table(blink_GM,"myData.map",quote=F,col.names=T,row.names=F)
write.table(blink_Y,"myData.txt",quote=F,col.names=T,row.names=F)
if(!is.null(CV))
{
  write.table(blink_CV,"myData.cov",quote=F,col.names=T,row.names=F)
}else{
  system("rm myData.cov")
}
system("./blink --gwas --file myData --numeric")
result=read.table("trait1_GWAS_result.txt",head=T)
result=result[,c(1,2,3,5,4)]
xs=t(GD[,-1])
#print(dim(xs))
gene_taxa=colnames(GD)[-1]
ss=apply(xs,1,sum)
ns=nrow(GD)
storage=cbind(.5*ss/ns,1-.5*ss/ns)
maf=result[,5]
#colnames(maf)=c("SNP","maf")
nobs=ns
effect=rep(NA,length(nobs))
#myFarmCPU$GWAS=merge(myFarmCPU$GWAS[,-5],maf, by.x = "SNP", by.y = "SNP")
GWAS=cbind(result[,1:4],effect)
GWAS=cbind(GWAS,maf)
GWAS=cbind(GWAS,nobs)
GWAS[,2]=as.numeric(as.character(GWAS[,2]))
GWAS[,3]=as.numeric(as.character(GWAS[,3]))
#print(dim(GWAS))
#GWAS=GWAS[order(GWAS$P.value),]
colnames(GWAS)=c("SNP","Chromosome","Position","P.value","effec","maf","nobs")

GPS=NULL
#colnames(GPS)[3]=c("Prediction")

h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL
}
if(method=="Blink")
{
  if(!require(devtools))  install.packages("devtools")
  if(!require(BLINK)) devtools::install_github("YaoZhou89/BLINK")
  #source("http://zzlab.net/GAPIT/gapit_functions.txt")
  source("http://zzlab.net/FarmCPU/FarmCPU_functions.txt")
  blink_GD=t(GD[,-1])
  blink_GM=GM
  blink_Y=Y
  blink_CV=NULL
  if(!is.null(CV))blink_CV=CV[,-1]

  #print(head(blink_CV))
  library(BLINK)

  myBlink=Blink(Y=blink_Y,GD=blink_GD,GM=blink_GM,CV=blink_CV,maxLoop=10,time.cal=T)
  #print(head(myBlink$GWAS))
  taxa=names(blink_Y)[2]
  GWAS=myBlink$GWAS[,1:4]
  #print(str(myBlink))
  ns=nrow(GD)
  nobs=ns
  effect=rep(NA,length(nobs))
  xs=t(GD[,-1])
  ss=apply(xs,1,sum)
  #storage=cbind(.5*ss/ns,1-.5*ss/ns)
  maf=apply(cbind(.5*ss/ns,1-.5*ss/ns),1,min)

  GWAS=cbind(GWAS,maf)#, by.x = "SNP", by.y = "SNP")  #Jiabo modified at 2019.3.25
  GWAS=cbind(GWAS,effect)
  GWAS=cbind(GWAS,nobs)

sig=GWAS[GWAS[,4]<(cutOff/(nrow(GWAS))),1:5]
sig_pass=TRUE
if(nrow(sig)==0)sig_pass=FALSE

#  

if(Multi_iter&sig_pass)
{

sig=GWAS[GWAS[,4]<(cutOff/(nrow(GWAS))),1:5]
sig=sig[!is.na(sig[,4]),]
sig_position=as.numeric(as.matrix(sig[,1:3])[,2])*10^10+as.numeric(as.matrix(sig[,1:3])[,3])
sig=sig[order(sig_position),]
sig_order=as.numeric(rownames(sig))
#if(setequal(sig_order,numeric(0))) break

n=nrow(sig)
if(length(sig_order)!=1){
  diff_order=abs(sig_order[-length(sig_order)]-sig_order[-1])

  diff_index=diff_order<num_regwas

  count=0
  diff_index2=count
  for(i in 1:length(diff_index))
  {
    if(!diff_index[i]) count=count+1
    diff_index2=append(diff_index2,count)
  }
  }else{
  diff_order=0
  diff_index2=0
  }

sig_bins=rle(diff_index2)$lengths
num_bins=length(sig_bins)

# sig_diff_index=sig_diff<windowsize
#GWAS0=GWAS
#####################
print("The number of significant markers is")
print(n)
if(n!=num_bins)
{
  print("The  number of significant bins is")
  print(num_bins)

}
# print(windowsize)
 if(num_bins>0)
 {
  for(i in 1:num_bins)
  { 
    n_sig=sig_bins[i]
    if(i==1)
    {  j=1:n_sig
      }else{
       j=(sum(sig_bins[1:(i-1)])+1):sum(sig_bins[1:i])
      }
    aim_marker=sig[j,]
    #print(aim_marker)
    aim_order=as.numeric(rownames(aim_marker))
    aim_area=rep(FALSE,(nrow(GWAS)))
    #aim_area[c((aim_order-num_regwas):(aim_order-1),(aim_order+1):(aim_order+num_regwas))]=TRUE
    aim_area[c((min(aim_order)-num_regwas):(max(aim_order)+num_regwas))]=TRUE
    aim_area[aim_order]=FALSE
    aim_area=aim_area[1:(nrow(GWAS))]
    if(setequal(aim_area,logical(0))) next

    # if(aim_matrix[rownames(aim_matrix)=="TRUE",1]<10) next
        # aim_area[GM[,1]==aim_marker[,1]]=FALSE      
        secondGD=GD[,c(TRUE,aim_area)]
        secondGM=GM[aim_area,]
        myGAPIT_Second =Blink(Y=Y,GD=secondGD,GM=secondGM,CV=blink_CV,maxLoop=10,time.cal=T)
        #print(head(myBlink$GWAS))
        #GWAS=myBlink$GWAS[,1:4]
        Second_GWAS= myGAPIT_Second$GWAS [,1:4]
        Second_GWAS[is.na(Second_GWAS[,4]),4]=1
        orignal_GWAS=GWAS[aim_area,]
        GWAS_index=match(Second_GWAS[,1],GWAS[,1])
        #test_GWAS=GWAS
        GWAS[GWAS_index,4]=Second_GWAS[,4]
  }
}

}

GWAS[,2]=as.numeric(as.character(GWAS[,2]))
GWAS[,3]=as.numeric(as.character(GWAS[,3]))
#rint(head(GWAS))

GPS=myBlink$Pred
#print(head(GWAS))
GWAS=GWAS[,c(1:5,7,6)]
if(Random.model)GR=GAPIT.RandomModel(Y=blink_Y,X=GD[,-1],GWAS=GWAS,CV=CV,cutOff=cutOff,GT=GT)


h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL

system(paste("rm -f FarmCPU.",taxa,".GWAS.Results.csv",sep=""))
system(paste("rm -f FarmCPU.",taxa,".Manhattan.Plot.Genomewise.pdf",sep=""))
system(paste("rm -f FarmCPU.",taxa,".QQ-Plot.pdf",sep=""))
  #print(head(GWAS))
  print("Bink R is done !!!!!")
}
if(method=="MLMM")
{
print("GWAS by MLMM method !!")
Y=Y[!is.na(Y[,2]),]
taxa_Y=as.character(Y[,1])
taxa_GD=as.character(GD[,1])
taxa_CV=as.character(CV[,1])
GD=GD[taxa_GD%in%taxa_Y,]
CV=CV[taxa_CV%in%taxa_Y,]

#print(dim(Y))
#print(dim(GD))
if(is.null(KI))
{
KI= GAPIT.kinship.VanRaden(snps=as.matrix(GD[,-1]))
colnames(KI)=as.character(GD[,1])
}else{
print("The Kinship is provided by user !!")
colnames(KI)[-1]=as.character(KI[,1])
rownames(KI)=as.character(KI[,1])

taxa_KI=as.character(KI[,1])
KI=KI[,-1] 
 # print(dim(KI))
if(!is.null(CV)){
  taxa_com=intersect(taxa_KI,intersect(taxa_GD,intersect(taxa_Y,taxa_CV)))
  }else{
  taxa_com=intersect(taxa_KI,intersect(taxa_GD,taxa_Y))    
  }
# print(head(taxa_com))
KI=KI[taxa_KI%in%taxa_com,taxa_KI%in%taxa_com]
GD=GD[taxa_GD%in%taxa_com,]
Y=Y[taxa_Y%in%taxa_com,]
CV=CV[taxa_CV%in%taxa_com,]
}

if(ncol(KI)!=nrow(GD)) print("Please make sure dim of K equal number of GD !!")

# print(dim(KI))
# print(dim(GD))
# print(dim(Y))
# print(dim(CV))
 # print(KI[1:5,1:5])

if(is.null(CV))
{
mymlmm=mlmm(
Y=Y[,2],#Phenotype
X=as.matrix(GD[,-1]),#Genotype
K=as.matrix(KI),
#cofs=CV[,2:ncol(CV)],
nbchunks = 2, maxsteps = 10, thresh = 1.2 * 10^-5)

}else{
mymlmm=mlmm_cof(
Y=Y[,2],#Phenotype
X=as.matrix(GD[,-1]),#Genotype
K=as.matrix(KI),
cofs=as.matrix(CV[,2:ncol(CV)]),
nbchunks = 2, maxsteps = 10, thresh = 1.2 * 10^-5)
}

#print(str(mymlmm))
if(opt=='extBIC'){
GWAS_result=mymlmm$opt_extBIC$out
}
if(opt=='mbonf'){
GWAS_result=mymlmm$opt_mbonf$out
}
if(opt=='thresh'){
GWAS_result=mymlmm$opt_thresh$out
}
colnames(GWAS_result)=c("SNP","P.value")
xs=t(GD[,-1])
#print(dim(xs))
gene_taxa=colnames(GD)[-1]
colnames(GM)=c("SNP","Chromosome","position")
ss=apply(xs,1,sum)
ns=nrow(GD)
storage=cbind(.5*ss/ns,1-.5*ss/ns)
maf=as.data.frame(cbind(gene_taxa,apply(cbind(.5*ss/ns,1-.5*ss/ns),1,min)))
colnames(maf)=c("SNP","maf")
nobs=ns
GWAS_GM=merge(GM,GWAS_result, by.x = "SNP", by.y = "SNP")
mc=matrix(NA,nrow(GWAS_GM),1)
GWAS_GM=cbind(GWAS_GM,mc)
#print(head(GWAS_GM))
#print(head(maf))
#maf=NULL
GWAS_GM_maf=merge(GWAS_GM,maf, by.x = "SNP", by.y = "SNP")

GWAS=cbind(GWAS_GM_maf,nobs)
#print(head(GWAS))
GWAS=GWAS[order(GWAS$P.value),]
GWAS[,2]=as.numeric(as.character(GWAS[,2]))
GWAS[,3]=as.numeric(as.character(GWAS[,3]))
GPS=NULL
#h2=mymlmm$step_table$h2[length(mymlmm$step_table$h2)]
h2=NULL
vg=NULL
ve=NULL
delta=NULL
REMLs=NULL
GWAS=GWAS[,c(1:4,6,7,5)]
colnames(GWAS)=c("SNP","Chromosome","Position","P.value","maf","nobs","effect")

}
# print(head(GWAS))
#print("GAPIT.Bus succeed!")  
return (list(GWAS=GWAS, GPS=GPS,REMLs=REMLs,vg=vg,ve=ve,delta=delta,GVs=GR$GVs))
} #end of GAPIT.Bus
#=============================================================================================









`GAPIT.CVMergePC` <-
function(X,Y){
#Object: To convert character SNP genotpe to numerical
#Output: Coresponding numerical value
#Authors: Feng Tian and Zhiwu Zhang
# Last update: May 30, 2011 
##############################################################################################
#Z=X+Y

Z <- merge(X, Y, by.x = colnames(X)[1], by.y = colnames(Y)[1])

return(Z)
}#end of GAPIT.CVMergePCfunction
#=============================================================================================

########## These three functions come from MVP package, Jiabo did some modifications
########## Following Apache License, we thank MVP developper to build these functions.
    ########## 1 creat P value scale in addtitional chromsome
    ########## 2 set col is same as GAPIT
    ########## 3 
circle.plot <- function(myr,type="l",x=NULL,lty=1,lwd=1,col="black",add=TRUE,n.point=1000)
	{
		curve(sqrt(myr^2-x^2),xlim=c(-myr,myr),n=n.point,ylim=c(-myr,myr),type=type,lty=lty,col=col,lwd=lwd,add=add)
		curve(-sqrt(myr^2-x^2),xlim=c(-myr,myr),n=n.point,ylim=c(-myr,myr),type=type,lty=lty,col=col,lwd=lwd,add=TRUE)
	}
Densitplot <- function(
		map,
		col=c("darkblue", "white", "red"),
		main="SNP Density",
		bin=1e6,
		band=3,
		width=5,
		legend.len=10,
		legend.max=NULL,
		legend.pt.cex=3,
		legend.cex=1,
		legend.y.intersp=1,
		legend.x.intersp=1,
		plot=TRUE
	)
	{   #print(head(map))
		map <- as.matrix(map)
		map <- map[!is.na(map[, 2]), ]
		map <- map[!is.na(map[, 3]), ]
		map <- map[map[, 2] != 0, ]
		#map <- map[map[, 3] != 0, ]
		options(warn = -1)
		max.chr <- max(as.numeric(map[, 2]), na.rm=TRUE)
		if(is.infinite(max.chr))	max.chr <- 0
		map.xy.index <- which(!as.numeric(map[, 2]) %in% c(0 : max.chr))
		if(length(map.xy.index) != 0){
			chr.xy <- unique(map[map.xy.index, 2])
			for(i in 1:length(chr.xy)){
				map[map[, 2] == chr.xy[i], 2] <- max.chr + i
			}
		}
		map <- map[order(as.numeric(map[, 2]), as.numeric(map[, 3])), ]
		chr <- as.numeric(map[, 2])
		pos <- as.numeric(map[, 3])
		chr.num <- unique(chr)
		#print(chr.num)
		chorm.maxlen <- max(pos)
		if(plot)	plot(NULL, xlim=c(0, chorm.maxlen + chorm.maxlen/10), ylim=c(0, length(chr.num) * band + band), main=main,axes=FALSE, xlab="", ylab="", xaxs="i", yaxs="i")
		pos.x <- list()
		col.index <- list()
		maxbin.num <- NULL
		#print(chr.num)
		for(i in 1 : length(chr.num)){
			pos.x[[i]] <- pos[which(chr == chr.num[i])]
			cut.len <- ceiling((max(pos.x[[i]]) - min(pos.x[[i]])) / bin)
			if(cut.len <= 1){
				col.index[[i]] = 1
			}else{
				cut.r <- cut(pos.x[[i]], cut.len, labels=FALSE)
				eachbin.num <- table(cut.r)
		        #print(eachbin.num)

				maxbin.num <- c(maxbin.num, max(eachbin.num))
				col.index[[i]] <- rep(eachbin.num, eachbin.num)
			}
		}

		Maxbin.num <- max(maxbin.num)
		maxbin.num <- Maxbin.num
		if(!is.null(legend.max)){
			maxbin.num <- legend.max
		}
		#print(col)
		#print(maxbin.num)
		col=colorRampPalette(col)(maxbin.num)
		col.seg=NULL
		for(i in 1 : length(chr.num)){
			if(plot)	polygon(c(0, 0, max(pos.x[[i]]), max(pos.x[[i]])), 
				c(-width/5 - band * (i - length(chr.num) - 1), width/5 - band * (i - length(chr.num) - 1), 
				width/5 - band * (i - length(chr.num) - 1), -width/5 - band * (i - length(chr.num) - 1)), col="grey", border="grey")
			if(!is.null(legend.max)){
				if(legend.max < Maxbin.num){
					col.index[[i]][col.index[[i]] > legend.max] <- legend.max
				}
			}
			col.seg <- c(col.seg, col[round(col.index[[i]] * length(col) / maxbin.num)])
			if(plot)	segments(pos.x[[i]], -width/5 - band * (i - length(chr.num) - 1), pos.x[[i]], width/5 - band * (i - length(chr.num) - 1), 
			col=col[round(col.index[[i]] * length(col) / maxbin.num)], lwd=1)
		}
		if(length(map.xy.index) != 0){
			for(i in 1:length(chr.xy)){
				chr.num[chr.num == max.chr + i] <- chr.xy[i]
			}
		}
		chr.num <- rev(chr.num)
		if(plot)	mtext(at=seq(band, length(chr.num) * band, band),text=paste("Chr", chr.num, sep=""), side=2, las=2, font=1, cex=0.6, line=0.2)
		if(plot)	axis(3, at=seq(0, chorm.maxlen, length=10), labels=c(NA, paste(round((seq(0, chorm.maxlen, length=10))[-1] / 1e6, 0), "Mb", sep="")),
			font=1, cex.axis=0.8, tck=0.01, lwd=2, padj=1.2)
		# image(c(chorm.maxlen-chorm.maxlen * legend.width / 20 , chorm.maxlen), 
		# round(seq(band - width/5, (length(chr.num) * band + band) * legend.height / 2 , length=maxbin.num+1), 2), 
		# t(matrix(0 : maxbin.num)), col=c("white", rev(heat.colors(maxbin.num))), add=TRUE)
		legend.y <- round(seq(0, maxbin.num, length=legend.len))
		len <- legend.y[2]
		legend.y <- seq(0, maxbin.num, len)
		if(!is.null(legend.max)){
			if(legend.max < Maxbin.num){
				if(!maxbin.num %in% legend.y){
					legend.y <- c(legend.y, paste(">=", maxbin.num, sep=""))
					legend.y.col <- c(legend.y[c(-1, -length(legend.y))], maxbin.num)
				}else{
					legend.y[length(legend.y)] <- paste(">=", maxbin.num, sep="")
					legend.y.col <- c(legend.y[c(-1, -length(legend.y))], maxbin.num)
				}
			}else{
				if(!maxbin.num %in% legend.y){
					legend.y <- c(legend.y, maxbin.num)
				}
				legend.y.col <- c(legend.y[-1])
			}
		}else{
			if(!maxbin.num %in% legend.y){
				legend.y <- c(legend.y, paste(">", max(legend.y), sep=""))
				legend.y.col <- c(legend.y[c(-1, -length(legend.y))], maxbin.num)
			}else{
				legend.y.col <- c(legend.y[-1])
			}
		}
		legend.y.col <- as.numeric(legend.y.col)
		legend.col <- c("grey", col[round(legend.y.col * length(col) / maxbin.num)])
		if(plot)	legend(x=(chorm.maxlen + chorm.maxlen/100), y=( -width/2.5 - band * (length(chr.num) - length(chr.num) - 1)), title="", legend=legend.y, pch=15, pt.cex = legend.pt.cex, col=legend.col,
			cex=legend.cex, bty="n", y.intersp=legend.y.intersp, x.intersp=legend.x.intersp, yjust=0, xjust=0, xpd=TRUE)
		if(!plot)	return(list(den.col=col.seg, legend.col=legend.col, legend.y=legend.y))
	}

GAPIT.Circle.Manhatton.Plot <- function(
	Pmap,
	col=c("#377EB8", "#4DAF4A", "#984EA3", "#FF7F00"),
	#col=c("darkgreen", "darkblue", "darkyellow", "darkred"),
	
	bin.size=1e6,
	bin.max=NULL,
	pch=19,
	band=1,
	cir.band=0.5,
	H=1.5,
	ylim=NULL,
	cex.axis=1,
	plot.type="c",
	multracks=TRUE,
	cex=c(0.5,0.8,1),
	r=0.3,
	xlab="Chromosome",
	ylab=expression(-log[10](italic(p))),
	xaxs="i",
	yaxs="r",
	outward=TRUE,
	threshold = 0.01, 
	threshold.col="red",
	threshold.lwd=1,
	threshold.lty=2,
	amplify= TRUE,     # is that available for remark signal pch col
	chr.labels=NULL,
	signal.cex = 2,
	signal.pch = 8,
	signal.col="red",
	signal.line=NULL,
	cir.chr=TRUE,
	cir.chr.h=1.3,
	chr.den.col=c("darkgreen", "yellow", "red"),
	#chr.den.col=c(126,177,153),
	cir.legend=TRUE,
	cir.legend.cex=0.8,
	cir.legend.col="grey45",
	LOG10=TRUE,
	box=FALSE,
	conf.int.col="grey",
	file.output=TRUE,
	file="pdf",
	dpi=300,
	xz=NULL,
	memo=""
)
{		#print("Starting Circular-Manhattan plot!",quote=F)
	taxa=colnames(Pmap)[-c(1:3)]
	if(!is.null(memo) && memo != "")	memo <- paste("_", memo, sep="")
	if(length(taxa) == 0)	taxa <- "Index"
	taxa <- paste(taxa, memo, sep="")
    col=rep(c( '#FF6A6A',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5'),ceiling(length(taxa)/5))
    legend.bit=round(nrow(Pmap)/30)

    numeric.chr <- as.numeric(Pmap[, 1])
	options(warn = 0)
	max.chr <- max(numeric.chr, na.rm=TRUE)
    aa=Pmap[1:legend.bit,]
    aa[,2]=max.chr+1
    #print(aa[,3])
    aa[,3]=sample(1:10^7.5,legend.bit)
    aa[,-c(1:3)]=0
    Pmap=rbind(Pmap,aa)
    #print(unique(Pmap[,2]))
	#SNP-Density plot
	if("d" %in% plot.type){
		print("SNP_Density Plotting...")
		if(file.output){
			if(file=="jpg")	jpeg(paste("SNP_Density.",paste(taxa,collapse="."),".jpg",sep=""), width = 9*dpi,height=7*dpi,res=dpi,quality = 100)
			if(file=="pdf")	pdf(paste("GAPIT.", taxa,".SNP_Density.Plot.pdf" ,sep=""), width = 9,height=7)
			if(file=="tiff")	tiff(paste("SNP_Density.",paste(taxa,collapse="."),".tiff",sep=""), width = 9*dpi,height=7*dpi,res=dpi)
			par(xpd=TRUE)
		}else{
			if(is.null(dev.list()))	dev.new(width = 9,height=7)
			par(xpd=TRUE)
		}

		Densitplot(map=Pmap[,c(1:3)], col=col, bin=bin.size, legend.max=bin.max, main=paste("The number of SNPs within ", bin.size/1e6, "Mb window size", sep=""))
		if(file.output)	dev.off()
	}

	if(length(plot.type) !=1 | (!"d" %in% plot.type)){
	
		#order Pmap by the name of SNP
		#Pmap=Pmap[order(Pmap[,1]),]
		Pmap <- as.matrix(Pmap)

		#delete the column of SNPs names
		Pmap <- Pmap[,-1]
		Pmap[is.na(Pmap)]=1
		#print(dim(Pmap))

		#scale and adjust the parameters
		cir.chr.h <- cir.chr.h/5
		cir.band <- cir.band/5
		threshold=threshold/nrow(Pmap)
		if(!is.null(threshold)){
			threshold.col <- rep(threshold.col,length(threshold))
			threshold.lwd <- rep(threshold.lwd,length(threshold))
			threshold.lty <- rep(threshold.lty,length(threshold))
			signal.col <- rep(signal.col,length(threshold))
			signal.pch <- rep(signal.pch,length(threshold))
			signal.cex <- rep(signal.cex,length(threshold))
		}
		if(length(cex)!=3) cex <- rep(cex,3)
		if(!is.null(ylim)){
			if(length(ylim)==1) ylim <- c(0,ylim)
		}
		
		if(is.null(conf.int.col))	conf.int.col <- NA
		if(is.na(conf.int.col)){
			conf.int=FALSE
		}else{
			conf.int=TRUE
		}

		#get the number of traits
		R=ncol(Pmap)-2

		#replace the non-euchromosome
		options(warn = -1)
		numeric.chr <- as.numeric(Pmap[, 1])
		options(warn = 0)
		max.chr <- max(numeric.chr, na.rm=TRUE)
		if(is.infinite(max.chr))	max.chr <- 0
		map.xy.index <- which(!numeric.chr %in% c(0:max.chr))
		if(length(map.xy.index) != 0){
			chr.xy <- unique(Pmap[map.xy.index, 1])
			for(i in 1:length(chr.xy)){
				Pmap[Pmap[, 1] == chr.xy[i], 1] <- max.chr + i
			}
		}

		Pmap <- matrix(as.numeric(Pmap), nrow(Pmap))

		#order the GWAS results by chromosome and position
		Pmap <- Pmap[order(Pmap[, 1], Pmap[,2]), ]

		#get the index of chromosome
		chr <- unique(Pmap[,1])
		chr.ori <- chr
		if(length(map.xy.index) != 0){
			for(i in 1:length(chr.xy)){
				chr.ori[chr.ori == max.chr + i] <- chr.xy[i]
			}
		}

		pvalueT <- as.matrix(Pmap[,-c(1:2)])
		#print(dim(pvalueT))
		pvalue.pos <- Pmap[, 2]
		p0.index <- Pmap[, 1] == 0
		if(sum(p0.index) != 0){
			pvalue.pos[p0.index] <- 1:sum(p0.index)
		}
		pvalue.pos.list <- tapply(pvalue.pos, Pmap[, 1], list)
		
		#scale the space parameter between chromosomes
		if(!missing(band)){
			band <- floor(band*(sum(sapply(pvalue.pos.list, max))/100))
		}else{
			band <- floor((sum(sapply(pvalue.pos.list, max))/100))
		}
		if(band==0)	band=1
		
		if(LOG10){
			pvalueT[pvalueT <= 0] <- 1
			pvalueT[pvalueT > 1] <- 1
		}

		#set the colors for the plot
		#palette(heat.colors(1024)) #(heatmap)
		#T=floor(1024/max(pvalue))
		#plot(pvalue,pch=19,cex=0.6,col=(1024-floor(pvalue*T)))
		
		#print(col)
		if(is.vector(col)){
			col <- matrix(col,R,length(col),byrow=TRUE)
		}
		if(is.matrix(col)){
			#try to transform the colors into matrix for all traits
			col <- matrix(as.vector(t(col)),R,dim(col)[2],byrow=TRUE)
		}

		Num <- as.numeric(table(Pmap[,1]))
		Nchr <- length(Num)
		N <- NULL
		#print(Nchr)
		#set the colors for each traits
		for(i in 1:R){
			colx <- col[i,]
			colx <- colx[!is.na(colx)]
			N[i] <- ceiling(Nchr/length(colx))
		}
		
		#insert the space into chromosomes and return the midpoint of each chromosome
		ticks <- NULL
		pvalue.posN <- NULL
		#pvalue <- pvalueT[,j]
		for(i in 0:(Nchr-1)){
			if (i==0){
				#pvalue <- append(pvalue,rep(Inf,band),after=0)
				pvalue.posN <- pvalue.pos.list[[i+1]] + band
				ticks[i+1] <- max(pvalue.posN)-floor(max(pvalue.pos.list[[i+1]])/2)
			}else{
				#pvalue <- append(pvalue,rep(Inf,band),after=sum(Num[1:i])+i*band)
				pvalue.posN <- c(pvalue.posN, max(pvalue.posN) + band + pvalue.pos.list[[i+1]])
				ticks[i+1] <- max(pvalue.posN)-floor(max(pvalue.pos.list[[i+1]])/2)
			}
		}
		pvalue.posN.list <- tapply(pvalue.posN, Pmap[, 1], list)
		#NewP[[j]] <- pvalue
		
		#merge the pvalues of traits by column
		if(LOG10){
			logpvalueT <- -log10(pvalueT)
		}else{
			pvalueT <- abs(pvalueT)
			logpvalueT <- pvalueT
		}

		add <- list()
		for(i in 1:R){
			colx <- col[i,]
			colx <- colx[!is.na(colx)]
			add[[i]] <- c(Num,rep(0,N[i]*length(colx)-Nchr))
		}

		TotalN <- max(pvalue.posN)

		if(length(chr.den.col) > 1){
			cir.density=TRUE
			den.fold <- 20
			density.list <- Densitplot(map=Pmap[,c(1,1,2)], col=chr.den.col, plot=FALSE, bin=bin.size, legend.max=bin.max)
			#list(den.col=col.seg, legend.col=legend.col, legend.y=legend.y)
		}else{
			cir.density=FALSE
		}


        #print(dim(pvalueT))

		if(is.null(xz)){
		signal.line.index <- NULL
		if(!is.null(threshold)){
			if(!is.null(signal.line)){
				for(l in 1:R){
					if(LOG10){
						signal.line.index <- c(signal.line.index,which(pvalueT[,l] < min(threshold)))
					}else{
						signal.line.index <- c(signal.line.index,which(pvalueT[,l] > max(threshold)))
					}
				}
				signal.line.index <- unique(signal.line.index)
			}
		}
		signal.lty=rep(2,length(signal.line.index))
	    }else{
        signal.line.index=as.numeric(as.vector(xz[,1]))
        signal.lty=as.numeric(as.vector(xz[,2]))
	    }#end is.null(xz)
        
		signal.line.index <- pvalue.posN[signal.line.index]
	}
	    


    if("c" %in% plot.type)
    {
		if(file.output){
			if(file=="jpg")	jpeg(paste("Circular-Manhattan.",paste(taxa,collapse="."),".jpg",sep=""), width = 8*dpi,height=8*dpi,res=dpi,quality = 100)
			if(file=="pdf")	pdf(paste("GAPIT.", taxa,".Circular.Manhattan.Plot.pdf" ,sep=""), width = 10,height=10)
			if(file=="tiff")	tiff(paste("Circular-Manhattan.",paste(taxa,collapse="."),".tiff",sep=""), width = 8*dpi,height=8*dpi,res=dpi)
		}
		if(!file.output){
			if(!is.null(dev.list()))	dev.new(width=8, height=8)
			par(pty="s", xpd=TRUE, mar=c(1,1,1,1))
		}
		par(pty="s", xpd=TRUE, mar=c(1,1,1,1))
		RR <- r+H*R+cir.band*R
		if(cir.density){
			plot(NULL,xlim=c(1.05*(-RR-4*cir.chr.h),1.1*(RR+4*cir.chr.h)),ylim=c(1.05*(-RR-4*cir.chr.h),1.1*(RR+4*cir.chr.h)),axes=FALSE,xlab="",ylab="")
		}else{
			plot(NULL,xlim=c(1.05*(-RR-4*cir.chr.h),1.05*(RR+4*cir.chr.h)),ylim=c(1.05*(-RR-4*cir.chr.h),1.05*(RR+4*cir.chr.h)),axes=FALSE,xlab="",ylab="")
		}
		if(!is.null(signal.line)){
			if(!is.null(signal.line.index)){
				X1chr <- (RR)*sin(2*pi*(signal.line.index-round(band/2))/TotalN)
				Y1chr <- (RR)*cos(2*pi*(signal.line.index-round(band/2))/TotalN)
				X2chr <- (r)*sin(2*pi*(signal.line.index-round(band/2))/TotalN)
				Y2chr <- (r)*cos(2*pi*(signal.line.index-round(band/2))/TotalN)
				#print(signal.line)

				#print(dim(pvalueT))
				#print(head(pvalueT))
				#print(dim(xz))
				#print(xz)
				#print(head(pvalue.posN))
				segments(X1chr,Y1chr,X2chr,Y2chr,lty=signal.lty,lwd=signal.line,col="grey")
			}
		}
		for(i in 1:R){
		
			#get the colors for each trait
			colx <- col[i,]
			colx <- colx[!is.na(colx)]
			
			#debug
			#print(colx)
			
			#print(paste("Circular_Manhattan Plotting ",taxa[i],"...",sep=""))
			pvalue <- pvalueT[,i]
			logpvalue <- logpvalueT[,i]
			if(is.null(ylim)){
				if(LOG10){
					Max <- ceiling(-log10(min(pvalue[pvalue!=0])))
				}else{
					Max <- ceiling(max(pvalue[pvalue!=Inf]))
					if(Max<=1)
					Max <- max(pvalue[pvalue!=Inf])
				}
			}else{
				Max <- ylim[2]
			}
			Cpvalue <- (H*logpvalue/Max)

			if(outward==TRUE){
				if(cir.chr==TRUE){
					
					#plot the boundary which represents the chromosomes
					polygon.num <- 1000
					#print(length(chr))
					for(k in 1:length(chr)){
						if(k==1){
							polygon.index <- seq(round(band/2)+1,-round(band/2)+max(pvalue.posN.list[[1]]), length=polygon.num)
							#change the axis from right angle into circle format
							X1chr=(RR)*sin(2*pi*(polygon.index)/TotalN)
							Y1chr=(RR)*cos(2*pi*(polygon.index)/TotalN)
							X2chr=(RR+cir.chr.h)*sin(2*pi*(polygon.index)/TotalN)
							Y2chr=(RR+cir.chr.h)*cos(2*pi*(polygon.index)/TotalN)

							#print(length(X1chr))
							if(is.null(chr.den.col)){
								polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=rep(colx,ceiling(length(chr)/length(colx)))[k],border=rep(colx,ceiling(length(chr)/length(colx)))[k])	
							}else{
								if(cir.density){
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col="grey",border="grey")
								}else{
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=chr.den.col,border=chr.den.col)
								}
							}
						}else{
							polygon.index <- seq(1+round(band/2)+max(pvalue.posN.list[[k-1]]),-round(band/2)+max(pvalue.posN.list[[k]]), length=polygon.num)
							X1chr=(RR)*sin(2*pi*(polygon.index)/TotalN)
							Y1chr=(RR)*cos(2*pi*(polygon.index)/TotalN)
							X2chr=(RR+cir.chr.h)*sin(2*pi*(polygon.index)/TotalN)
							Y2chr=(RR+cir.chr.h)*cos(2*pi*(polygon.index)/TotalN)
							if(is.null(chr.den.col)){
								polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=rep(colx,ceiling(length(chr)/length(colx)))[k],border=rep(colx,ceiling(length(chr)/length(colx)))[k])
							}else{
								if(cir.density){
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col="grey",border="grey")
								}else{
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=chr.den.col,border=chr.den.col)
								}
							}		
						}
					}
					
					if(cir.density){

						segments(
							(RR)*sin(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(RR)*cos(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(RR+cir.chr.h)*sin(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(RR+cir.chr.h)*cos(2*pi*(pvalue.posN-round(band/2))/TotalN),
							col=density.list$den.col, lwd=0.1
						)
						legend(
							x=RR+4*cir.chr.h,
							y=(RR+4*cir.chr.h)/2,
							horiz=F,
							title="Density", legend=density.list$legend.y, pch=15, pt.cex = 3, col=density.list$legend.col,
							cex=1, bty="n",
							y.intersp=1,
							x.intersp=1,
							yjust=0.5, xjust=0, xpd=TRUE
						)
						
					}
					
					# XLine=(RR+cir.chr.h)*sin(2*pi*(1:TotalN)/TotalN)
					# YLine=(RR+cir.chr.h)*cos(2*pi*(1:TotalN)/TotalN)
					# lines(XLine,YLine,lwd=1.5)
					if(cir.density){
						circle.plot(myr=RR+cir.chr.h,lwd=1.5,add=TRUE,col='grey')
						circle.plot(myr=RR,lwd=1.5,add=TRUE,col='grey')
					}else{
						circle.plot(myr=RR+cir.chr.h,lwd=1.5,add=TRUE)
						circle.plot(myr=RR,lwd=1.5,add=TRUE)
					}

				}
				
				#plot the y axis of legend for each trait
				if(cir.legend==TRUE){
					#try to get the number after radix point
					if(Max<=1) {
						round.n=nchar(as.character(10^(-ceiling(-log10(Max)))))-1
					}else{
						round.n=1
					}
					segments(0,r+H*(i-1)+cir.band*(i-1),0,r+H*i+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					segments(0,r+H*(i-1)+cir.band*(i-1),H/20,r+H*(i-1)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-1)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.75)+cir.band*(i-1),H/20,r+H*(i-0.75)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.75)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.5)+cir.band*(i-1),H/20,r+H*(i-0.5)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.5)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.25)+cir.band*(i-1),H/20,r+H*(i-0.25)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.25)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0)+cir.band*(i-1),H/20,r+H*(i-0)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					#text(-r/15,r+H*(i-0.75)+cir.band*(i-1),round(Max*0.25,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					text(-r/15,r+H*(i-0.5)+cir.band*(i-1),round(Max*0.5,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					text(-r/15,r+H*(i-0.25)+cir.band*(i-1),round(Max*0.75,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					#text(-r/15,r+H*(i-0)+cir.band*(i-1),round(Max*1,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					#text(r/5,0.4*(i-1),taxa[i],adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
				    
				}
				X=(Cpvalue+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(pvalue.posN-round(band/2))/TotalN)
				Y=(Cpvalue+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(pvalue.posN-round(band/2))/TotalN)
				# plot point in figure
				points(X[1:(length(X)-legend.bit)],Y[1:(length(Y)-legend.bit)],pch=19,cex=cex[1],col=rep(rep(colx,N[i]),add[[i]]))
				
				# plot significant line
				if(!is.null(threshold)){
					if(sum(threshold!=0)==length(threshold)){
						for(thr in 1:length(threshold)){
							significantline1=ifelse(LOG10, H*(-log10(threshold[thr]))/Max, H*(threshold[thr])/Max)
							#s1X=(significantline1+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(0:TotalN)/TotalN)
							#s1Y=(significantline1+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(0:TotalN)/TotalN)
							# plot significant line
							if(significantline1<H){
								#lines(s1X,s1Y,type="l",col=threshold.col,lwd=threshold.col,lty=threshold.lty)
								#if(thr==length(threshold))circle.plot(myr=(significantline1+r+H*(i-1)+cir.band*(i-1)),col="black",lwd=threshold.lwd[thr],lty=threshold.lty[thr])
								#print("!!!!!")
								circle.plot(myr=(significantline1+r+H*(i-1)+cir.band*(i-1)),col=threshold.col[thr],lwd=threshold.lwd[thr],lty=threshold.lty[thr])
								#circle.plot(myr=(significantline1+r+H*(i-1)+cir.band*(i-1)),col="black",lwd=threshold.lwd[thr],lty=threshold.lty[thr])
							}else{
								warning(paste("No significant points for ",taxa[i]," pass the threshold level using threshold=",threshold[thr],"!",sep=""))
							}
						}
					}
				}
				
				if(!is.null(threshold)){
					if(sum(threshold!=0)==length(threshold)){
						if(amplify==TRUE){
							if(LOG10){
								threshold <- sort(threshold)
								significantline1=H*(-log10(max(threshold)))/Max
							}else{
								threshold <- sort(threshold, decreasing=TRUE)
								significantline1=H*(min(threshold))/Max
							}
							
							p_amp.index <- which(Cpvalue>=significantline1)
							HX1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
							HY1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
							
							#cover the points that exceed the threshold with the color "white"
							points(HX1,HY1,pch=19,cex=cex[1],col="white")
							
								for(ll in 1:length(threshold)){
									if(ll == 1){
										if(LOG10){
											significantline1=H*(-log10(threshold[ll]))/Max
										}else{
											significantline1=H*(threshold[ll])/Max
										}
										p_amp.index <- which(Cpvalue>=significantline1)
										HX1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
										HY1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
									}else{
										if(LOG10){
											significantline0=H*(-log10(threshold[ll-1]))/Max
											significantline1=H*(-log10(threshold[ll]))/Max
										}else{
											significantline0=H*(threshold[ll-1])/Max
											significantline1=H*(threshold[ll])/Max
										}
										p_amp.index <- which(Cpvalue>=significantline1 & Cpvalue < significantline0)
										HX1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
										HY1=(Cpvalue[p_amp.index]+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
									}
								
									if(is.null(signal.col)){
										# print(signal.pch)
										points(HX1,HY1,pch=signal.pch,cex=signal.cex[ll]*cex[1],col=rep(rep(colx,N[i]),add[[i]])[p_amp.index])
									}else{
										# print(signal.pch)
										points(HX1,HY1,pch=signal.pch,cex=signal.cex[ll]*cex[1],col=signal.col[ll])
									}
								}
						}
					}
				}
				if(cir.chr==TRUE){
					ticks1=1.07*(RR+cir.chr.h)*sin(2*pi*(ticks-round(band/2))/TotalN)
					ticks2=1.07*(RR+cir.chr.h)*cos(2*pi*(ticks-round(band/2))/TotalN)
					if(is.null(chr.labels)){
						#print(length(ticks))
						for(i in 1:(length(ticks)-1)){
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.ori[i],srt=angle,font=2,cex=cex.axis)
						}
					}else{
						for(i in 1:length(ticks)){
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.labels[i],srt=angle,font=2,cex=cex.axis)
						}
					}
				}else{
					ticks1=(0.9*r)*sin(2*pi*(ticks-round(band/2))/TotalN)
					ticks2=(0.9*r)*cos(2*pi*(ticks-round(band/2))/TotalN)
					if(is.null(chr.labels)){
						for(i in 1:length(ticks)){
						angle=360*(1-(ticks-round(band/2))[i]/TotalN)
						text(ticks1[i],ticks2[i],chr.ori[i],srt=angle,font=2,cex=cex.axis)
						}
					}else{
						for(i in 1:length(ticks)){
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.labels[i],srt=angle,font=2,cex=cex.axis)
						}
					}
				}
			}
			if(outward==FALSE){
				if(cir.chr==TRUE){
					# XLine=(2*cir.band+RR+cir.chr.h)*sin(2*pi*(1:TotalN)/TotalN)
					# YLine=(2*cir.band+RR+cir.chr.h)*cos(2*pi*(1:TotalN)/TotalN)
					# lines(XLine,YLine,lwd=1.5)

					polygon.num <- 1000
					for(k in 1:length(chr)){
						if(k==1){
							polygon.index <- seq(round(band/2)+1,-round(band/2)+max(pvalue.posN.list[[1]]), length=polygon.num)
							X1chr=(2*cir.band+RR)*sin(2*pi*(polygon.index)/TotalN)
							Y1chr=(2*cir.band+RR)*cos(2*pi*(polygon.index)/TotalN)
							X2chr=(2*cir.band+RR+cir.chr.h)*sin(2*pi*(polygon.index)/TotalN)
							Y2chr=(2*cir.band+RR+cir.chr.h)*cos(2*pi*(polygon.index)/TotalN)
								if(is.null(chr.den.col)){
									polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=rep(colx,ceiling(length(chr)/length(colx)))[k],border=rep(colx,ceiling(length(chr)/length(colx)))[k])	
								}else{
									if(cir.density){
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col="grey",border="grey")
									}else{
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=chr.den.col,border=chr.den.col)
									}
								}
						}else{
							polygon.index <- seq(1+round(band/2)+max(pvalue.posN.list[[k-1]]),-round(band/2)+max(pvalue.posN.list[[k]]), length=polygon.num)
							X1chr=(2*cir.band+RR)*sin(2*pi*(polygon.index)/TotalN)
							Y1chr=(2*cir.band+RR)*cos(2*pi*(polygon.index)/TotalN)
							X2chr=(2*cir.band+RR+cir.chr.h)*sin(2*pi*(polygon.index)/TotalN)
							Y2chr=(2*cir.band+RR+cir.chr.h)*cos(2*pi*(polygon.index)/TotalN)
							if(is.null(chr.den.col)){
								polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=rep(colx,ceiling(length(chr)/length(colx)))[k],border=rep(colx,ceiling(length(chr)/length(colx)))[k])	
							}else{
									if(cir.density){
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col="grey",border="grey")
									}else{
										polygon(c(rev(X1chr),X2chr),c(rev(Y1chr),Y2chr),col=chr.den.col,border=chr.den.col)
									}
							}	
						}
					}
					if(cir.density){

						segments(
							(2*cir.band+RR)*sin(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(2*cir.band+RR)*cos(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(2*cir.band+RR+cir.chr.h)*sin(2*pi*(pvalue.posN-round(band/2))/TotalN),
							(2*cir.band+RR+cir.chr.h)*cos(2*pi*(pvalue.posN-round(band/2))/TotalN),
							col=density.list$den.col, lwd=0.1
						)
						legend(
							x=RR+4*cir.chr.h,
							y=(RR+4*cir.chr.h)/2,
							title="Density", legend=density.list$legend.y, pch=15, pt.cex = 3, col=density.list$legend.col,
							cex=1, bty="n",
							y.intersp=1,
							x.intersp=1,
							yjust=0.5, xjust=0, xpd=TRUE
						)
						
					}
					
					if(cir.density){
						circle.plot(myr=2*cir.band+RR+cir.chr.h,lwd=1.5,add=TRUE,col='grey')
						circle.plot(myr=2*cir.band+RR,lwd=1.5,add=TRUE,col='grey')
					}else{
						circle.plot(myr=2*cir.band+RR+cir.chr.h,lwd=1.5,add=TRUE)
						circle.plot(myr=2*cir.band+RR,lwd=1.5,add=TRUE)
					}

				}


				if(cir.legend==TRUE){
					
					#try to get the number after radix point
					if(Max<=1) {
						round.n=nchar(as.character(10^(-ceiling(-log10(Max)))))-1
					}else{
						round.n=2
					}
					segments(0,r+H*(i-1)+cir.band*(i-1),0,r+H*i+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					segments(0,r+H*(i-1)+cir.band*(i-1),H/20,r+H*(i-1)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-1)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.75)+cir.band*(i-1),H/20,r+H*(i-0.75)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.75)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.5)+cir.band*(i-1),H/20,r+H*(i-0.5)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.5)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0.25)+cir.band*(i-1),H/20,r+H*(i-0.25)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0.25)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					segments(0,r+H*(i-0)+cir.band*(i-1),H/20,r+H*(i-0)+cir.band*(i-1),col=cir.legend.col,lwd=1.5)
					circle.plot(myr=r+H*(i-0)+cir.band*(i-1),lwd=0.5,add=TRUE,col='grey')
					text(-r/15,r+H*(i-0.25)+cir.band*(i-1),round(Max*0.25,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					#text(-r/15,r+H*(i-0.5)+cir.band*(i-1),round(Max*0.5,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					text(-r/15,r+H*(i-0.75)+cir.band*(i-1),round(Max*0.75,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
					#text(-r/15,r+H*(i-1)+cir.band*(i-1),round(Max*1,round.n),adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)
				    #text(r,0.4*(i-1),taxa[i],adj=1,col=cir.legend.col,cex=cir.legend.cex,font=2)

				}
				
				X=(-Cpvalue+r+H*i+cir.band*(i-1))*sin(2*pi*(pvalue.posN-round(band/2))/TotalN)
				Y=(-Cpvalue+r+H*i+cir.band*(i-1))*cos(2*pi*(pvalue.posN-round(band/2))/TotalN)
				#points(X,Y,pch=19,cex=cex[1],col=rep(rep(colx,N[i]),add[[i]]))
				points(X[1:(length(X)-legend.bit)],Y[1:(length(Y)-legend.bit)],pch=19,cex=cex[1],col=rep(rep(colx,N[i]),add[[i]]))
				
				if(!is.null(threshold)){
					if(sum(threshold!=0)==length(threshold)){
					
						for(thr in 1:length(threshold)){
							significantline1=ifelse(LOG10, H*(-log10(threshold[thr]))/Max, H*(threshold[thr])/Max)
							#s1X=(significantline1+r+H*(i-1)+cir.band*(i-1))*sin(2*pi*(0:TotalN)/TotalN)
							#s1Y=(significantline1+r+H*(i-1)+cir.band*(i-1))*cos(2*pi*(0:TotalN)/TotalN)
							if(significantline1<H){
								#lines(s1X,s1Y,type="l",col=threshold.col,lwd=threshold.col,lty=threshold.lty)
								circle.plot(myr=(-significantline1+r+H*i+cir.band*(i-1)),col=threshold.col[thr],lwd=threshold.lwd[thr],lty=threshold.lty[thr])
							}else{
								warning(paste("No significant points for ",taxa[i]," pass the threshold level using threshold=",threshold[thr],"!",sep=""))
							}
						}
						if(amplify==TRUE){
							if(LOG10){
								threshold <- sort(threshold)
								significantline1=H*(-log10(max(threshold)))/Max
							}else{
								threshold <- sort(threshold, decreasing=TRUE)
								significantline1=H*(min(threshold))/Max
							}
							p_amp.index <- which(Cpvalue>=significantline1)
							HX1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
							HY1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
							
							#cover the points that exceed the threshold with the color "white"
							points(HX1,HY1,pch=19,cex=cex[1],col="white")
							
								for(ll in 1:length(threshold)){
									if(ll == 1){
										if(LOG10){
											significantline1=H*(-log10(threshold[ll]))/Max
										}else{
											significantline1=H*(threshold[ll])/Max
										}
										p_amp.index <- which(Cpvalue>=significantline1)
										HX1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
										HY1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
									}else{
										if(LOG10){
											significantline0=H*(-log10(threshold[ll-1]))/Max
											significantline1=H*(-log10(threshold[ll]))/Max
										}else{
											significantline0=H*(threshold[ll-1])/Max
											significantline1=H*(threshold[ll])/Max
										}
										p_amp.index <- which(Cpvalue>=significantline1 & Cpvalue < significantline0)
										HX1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*sin(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
										HY1=(-Cpvalue[p_amp.index]+r+H*i+cir.band*(i-1))*cos(2*pi*(pvalue.posN[p_amp.index]-round(band/2))/TotalN)
									
									}
								
									if(is.null(signal.col)){
										points(HX1,HY1,pch=signal.pch,cex=signal.cex[ll]*cex[1],col=rep(rep(colx,N[i]),add[[i]])[p_amp.index])
									}else{
										points(HX1,HY1,pch=signal.pch,cex=signal.cex[ll]*cex[1],col=signal.col[ll])
									}
								}
						}
					}
				}
				
				if(cir.chr==TRUE){
					ticks1=1.1*(2*cir.band+RR)*sin(2*pi*(ticks-round(band/2))/TotalN)
					ticks2=1.1*(2*cir.band+RR)*cos(2*pi*(ticks-round(band/2))/TotalN)
					if(is.null(chr.labels)){
						for(i in 1:(length(ticks)-1)){
						  angle=360*(1-(ticks-round(band/2))[i]/TotalN)
						  text(ticks1[i],ticks2[i],chr.ori[i],srt=angle,font=2,cex=cex.axis)
						}
					}else{
						for(i in 1:length(ticks)){
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.labels[i],srt=angle,font=2,cex=cex.axis)
						}
					}
				}else{
					ticks1=1.0*(RR+cir.band)*sin(2*pi*(ticks-round(band/2))/TotalN)
					ticks2=1.0*(RR+cir.band)*cos(2*pi*(ticks-round(band/2))/TotalN)
					if(is.null(chr.labels)){
						for(i in 1:length(ticks)){
						
							#adjust the angle of labels of circle plot
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.ori[i],srt=angle,font=2,cex=cex.axis)
						}
					}else{
						for(i in 1:length(ticks)){
							angle=360*(1-(ticks-round(band/2))[i]/TotalN)
							text(ticks1[i],ticks2[i],chr.labels[i],srt=angle,font=2,cex=cex.axis)
						}
					}	
				}
			}
		}
		taxa=append("Centre",taxa,)
		taxa_col=rep("black",R)
		taxa_col=append("red",taxa_col)
		for(j in 1:(R+1)){
            text(r/5,0.4*(j-1),taxa[j],adj=1,col=taxa_col[j],cex=cir.legend.cex,font=2)
				    
		}
		taxa=taxa[-1]
		if(file.output) dev.off()
	}

	if("q" %in% plot.type){
		#print("Starting QQ-plot!",quote=F)
		amplify=FALSE
		if(multracks){
			if(file.output){
				if(file=="jpg")	jpeg(paste("Multracks.QQ_plot.",paste(taxa,collapse="."),".jpg",sep=""), width = R*2.5*dpi,height=5.5*dpi,res=dpi,quality = 100)
				if(file=="pdf")	pdf(paste("Multracks.QQ_plot.",paste(taxa,collapse="."),".pdf",sep=""), width = R*2.5,height=5.5)
				if(file=="tiff")	tiff(paste("Multracks.QQ_plot.",paste(taxa,collapse="."),".tiff",sep=""), width = R*2.5*dpi,height=5.5*dpi,res=dpi)
				par(mfcol=c(1,R),mar = c(0,1,4,1.5),oma=c(3,5,0,0),xpd=TRUE)
			}else{
				if(is.null(dev.list()))	dev.new(width = 2.5*R, height = 5.5)
				par(xpd=TRUE)
			}
			for(i in 1:R){
				print(paste("Multracks_QQ Plotting ",taxa[i],"...",sep=""))		
				P.values=as.numeric(Pmap[,i+2])
				P.values=P.values[!is.na(P.values)]
				if(LOG10){
					P.values=P.values[P.values>0]
					P.values=P.values[P.values<=1]
					N=length(P.values)
					P.values=P.values[order(P.values)]
				}else{
					N=length(P.values)
					P.values=P.values[order(P.values,decreasing=TRUE)]
				}
				p_value_quantiles=(1:length(P.values))/(length(P.values)+1)
				log.Quantiles <- -log10(p_value_quantiles)
				if(LOG10){
					log.P.values <- -log10(P.values)
				}else{
					log.P.values <- P.values
				}
				
				#calculate the confidence interval of QQ-plot
				if(conf.int){
					N1=length(log.Quantiles)
					c95 <- rep(NA,N1)
					c05 <- rep(NA,N1)
					for(j in 1:N1){
						xi=ceiling((10^-log.Quantiles[j])*N)
						if(xi==0)xi=1
						c95[j] <- qbeta(0.95,xi,N-xi+1)
						c05[j] <- qbeta(0.05,xi,N-xi+1)
					}
					index=length(c95):1
				}else{
					c05 <- 1
					c95 <- 1
				}
				
				YlimMax <- max(floor(max(max(-log10(c05)), max(-log10(c95)))+1), floor(max(log.P.values)+1))
				plot(NULL, xlim = c(0,floor(max(log.Quantiles)+1)), axes=FALSE, cex.axis=cex.axis, cex.lab=1.2,ylim=c(0,YlimMax),xlab ="", ylab="", main = taxa[i])
				axis(1, at=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), labels=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), cex.axis=cex.axis)
				axis(2, at=seq(0,YlimMax,ceiling(YlimMax/10)), labels=seq(0,YlimMax,ceiling(YlimMax/10)), cex.axis=cex.axis)
				
				#plot the confidence interval of QQ-plot
				
				if(conf.int)	polygon(c(log.Quantiles[index],log.Quantiles),c(-log10(c05)[index],-log10(c95)),col=conf.int.col,border=conf.int.col)
				
				if(!is.null(threshold.col)){par(xpd=FALSE); abline(a = 0, b = 1, col = threshold.col[1],lwd=2); par(xpd=TRUE)}
				points(log.Quantiles, log.P.values, col = col[1],pch=1,cex=cex[3])
				#print(max(log.Quantiles))
				#	print(length(log.Quantiles))
				#	print(length(log.P.values))
				if(!is.null(threshold)){
					if(sum(threshold!=0)==length(threshold)){
						thre.line=-log10(min(threshold))
						if(amplify==TRUE){
							thre.index=which(log.P.values>=thre.line)
							if(length(thre.index)!=0){
							
								#cover the points that exceed the threshold with the color "white"
								points(log.Quantiles[thre.index],log.P.values[thre.index], col = "white",pch=19,cex=cex[3])
								if(is.null(signal.col)){
									points(log.Quantiles[thre.index],log.P.values[thre.index],col = col[1],pch=signal.pch[1],cex=signal.cex[1])
								}else{
									points(log.Quantiles[thre.index],log.P.values[thre.index],col = signal.col[1],pch=signal.pch[1],cex=signal.cex[1])
								}
							}
						}
					}
				}
			}
			if(box)	box()
			if(file.output) dev.off()
			if(R > 1){
				#qq_col=rainbow(R)
                qq_col=rep(c( '#FF6A6A',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5'),ceiling(R/5))

				signal.col <- NULL
				if(file.output){
					if(file=="jpg")	jpeg(paste("Multiple.QQ_plot.",paste(taxa,collapse="."),".jpg",sep=""), width = 5.5*dpi,height=5.5*dpi,res=dpi,quality = 100)
					if(file=="pdf")	pdf(paste("Multiple.QQ_plot.",paste(taxa,collapse="."),".pdf",sep=""), width = 5.5,height=5.5)
					if(file=="tiff")	tiff(paste("Multiple.QQ_plot.",paste(taxa,collapse="."),".tiff",sep=""), width = 5.5*dpi,height=5.5*dpi,res=dpi)
					par(mar = c(5,5,4,2),xpd=TRUE)
				}else{
					dev.new(width = 5.5, height = 5.5)
					par(xpd=TRUE)
				}
				P.values=as.numeric(Pmap[,i+2])
				P.values=P.values[!is.na(P.values)]
				if(LOG10){
					P.values=P.values[P.values>0]
					P.values=P.values[P.values<=1]
					N=length(P.values)
					P.values=P.values[order(P.values)]
				}else{
					N=length(P.values)
					P.values=P.values[order(P.values,decreasing=TRUE)]
				}
				p_value_quantiles=(1:length(P.values))/(length(P.values)+1)
				log.Quantiles <- -log10(p_value_quantiles)
											
				# calculate the confidence interval of QQ-plot
				if(conf.int){
					N1=length(log.Quantiles)
					c95 <- rep(NA,N1)
					c05 <- rep(NA,N1)
					for(j in 1:N1){
						xi=ceiling((10^-log.Quantiles[j])*N)
						if(xi==0)xi=1
						c95[j] <- qbeta(0.95,xi,N-xi+1)
						c05[j] <- qbeta(0.05,xi,N-xi+1)
					}
					index=length(c95):1
				}
				
				if(!conf.int){c05 <- 1; c95 <- 1}
				
				Pmap.min <- Pmap[,3:(R+2)]

				YlimMax <- max(floor(max(max(-log10(c05)), max(-log10(c95)))+1), -log10(min(Pmap.min[Pmap.min > 0])))
				plot(NULL, xlim = c(0,floor(max(log.Quantiles)+1)), axes=FALSE, cex.axis=cex.axis, cex.lab=1.2,ylim=c(0, floor(YlimMax+1)),xlab =expression(Expected~~-log[10](italic(p))), ylab = expression(Observed~~-log[10](italic(p))), main = "QQ plot")
				#legend("topleft",taxa,col=t(col)[1:R],pch=1,pt.lwd=2,text.font=6,box.col=NA)			
				legend("topleft",taxa,col=qq_col[1:R],pch=1,pt.lwd=3,text.font=6,box.col=NA)
				axis(1, at=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), labels=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), cex.axis=cex.axis)
				axis(2, at=seq(0,floor(YlimMax+1),ceiling((YlimMax+1)/10)), labels=seq(0,floor((YlimMax+1)),ceiling((YlimMax+1)/10)), cex.axis=cex.axis)
				#print(log.Quantiles[index])
				#print(index)
				#print(length(log.Quantiles))

				# plot the confidence interval of QQ-plot
				if(conf.int)	polygon(c(log.Quantiles[index],log.Quantiles),c(-log10(c05)[index],-log10(c95)),col=conf.int.col,border=conf.int.col)
				
				for(i in 1:R){
					#print(paste("Multraits_QQ Plotting ",taxa[i],"...",sep=""))
					P.values=as.numeric(Pmap[,i+2])
				    P.values=P.values[!is.na(P.values)]
				    if(LOG10){
					P.values=P.values[P.values>0]
					P.values=P.values[P.values<=1]
					N=length(P.values)
					P.values=P.values[order(P.values)]
				    }else{
					N=length(P.values)
					P.values=P.values[order(P.values,decreasing=TRUE)]
				    }
				    p_value_quantiles=(1:length(P.values))/(length(P.values)+1)
				    log.Quantiles <- -log10(p_value_quantiles)
				    if(LOG10){
					log.P.values <- -log10(P.values)
				    }else{
					log.P.values <- P.values
				    }
				
						
					if((i == 1) & !is.null(threshold.col)){par(xpd=FALSE); abline(a = 0, b = 1, col = threshold.col[1],lwd=2); par(xpd=TRUE)}
					#print(length(log.Quantiles))
				    #print("!!!!!") 
					#points(log.Quantiles, log.P.values, col = t(col)[i],pch=1,lwd=3,cex=cex[3])
					points(log.Quantiles, log.P.values, col = qq_col[i],pch=1,lwd=3,cex=cex[3])
					
					#print(max(log.Quantiles))
					#
	
					if(!is.null(threshold)){
						if(sum(threshold!=0)==length(threshold)){
							thre.line=-log10(min(threshold))
							if(amplify==TRUE){
								thre.index=which(log.P.values>=thre.line)
								if(length(thre.index)!=0){
								
									# cover the points that exceed the threshold with the color "white"
									points(log.Quantiles[thre.index],log.P.values[thre.index], col = "white",pch=19,lwd=3,cex=cex[3])
									if(is.null(signal.col)){
										points(log.Quantiles[thre.index],log.P.values[thre.index],col = t(col)[i],pch=signal.pch[1],cex=signal.cex[1])
									}else{
										points(log.Quantiles[thre.index],log.P.values[thre.index],col = signal.col[1],pch=signal.pch[1],cex=signal.cex[1])
									}
								}
							}
						}
					}
				}
					box()
				if(file.output) dev.off()
			}
		}else{
			for(i in 1:R){
				print(paste("Q_Q Plotting ",taxa[i],"...",sep=""))
				if(file.output){
					if(file=="jpg")	jpeg(paste("QQplot.",taxa[i],".jpg",sep=""), width = 5.5*dpi,height=5.5*dpi,res=dpi,quality = 100)
					if(file=="pdf")	pdf(paste("QQplot.",taxa[i],".pdf",sep=""), width = 5.5,height=5.5)
					if(file=="tiff")	tiff(paste("QQplot.",taxa[i],".tiff",sep=""), width = 5.5*dpi,height=5.5*dpi,res=dpi)
					par(mar = c(5,5,4,2),xpd=TRUE)
				}else{
					if(is.null(dev.list()))	dev.new(width = 5.5, height = 5.5)
					par(xpd=TRUE)
				}
				P.values=as.numeric(Pmap[,i+2])
				P.values=P.values[!is.na(P.values)]
				if(LOG10){
					P.values=P.values[P.values>0]
					P.values=P.values[P.values<=1]
					N=length(P.values)
					P.values=P.values[order(P.values)]
				}else{
					N=length(P.values)
					P.values=P.values[order(P.values,decreasing=TRUE)]
				}
				p_value_quantiles=(1:length(P.values))/(length(P.values)+1)
				log.Quantiles <- -log10(p_value_quantiles)
				if(LOG10){
					log.P.values <- -log10(P.values)
				}else{
					log.P.values <- P.values
				}
				
				#calculate the confidence interval of QQ-plot
				if(conf.int){
					N1=length(log.Quantiles)
					c95 <- rep(NA,N1)
					c05 <- rep(NA,N1)
					for(j in 1:N1){
						xi=ceiling((10^-log.Quantiles[j])*N)
						if(xi==0)xi=1
						c95[j] <- qbeta(0.95,xi,N-xi+1)
						c05[j] <- qbeta(0.05,xi,N-xi+1)
					}
					index=length(c95):1
				}else{
					c05 <- 1
					c95 <- 1
				}
				#print(max(log.Quantiles))
				#print("@@@@@")
				YlimMax <- max(floor(max(max(-log10(c05)), max(-log10(c95)))+1), floor(max(log.P.values)+1))
				plot(NULL, xlim = c(0,floor(max(log.Quantiles)+1)), axes=FALSE, cex.axis=cex.axis, cex.lab=1.2,ylim=c(0,YlimMax),xlab =expression(Expected~~-log[10](italic(p))), ylab = expression(Observed~~-log[10](italic(p))), main = paste("QQplot of",taxa[i]))
				axis(1, at=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), labels=seq(0,floor(max(log.Quantiles)+1),ceiling((max(log.Quantiles)+1)/10)), cex.axis=cex.axis)
				axis(2, at=seq(0,YlimMax,ceiling(YlimMax/10)), labels=seq(0,YlimMax,ceiling(YlimMax/10)), cex.axis=cex.axis)
				
				#plot the confidence interval of QQ-plot
				#print(log.Quantiles[index])
				qq_col=rainbow(R)
				#if(conf.int)	polygon(c(log.Quantiles[index],log.Quantiles),c(-log10(c05)[index],-log10(c95)),col=conf.int.col,border=conf.int.col)
				if(conf.int)	polygon(c(log.Quantiles[index],log.Quantiles),c(-log10(c05)[index],-log10(c95)),col=qq_col[i],border=conf.int.col)
				
				if(!is.null(threshold.col)){par(xpd=FALSE); abline(a = 0, b = 1, col = threshold.col[1],lwd=2); par(xpd=TRUE)}
				 
				points(log.Quantiles, log.P.values, col = col[1],pch=19,cex=2)
				
				if(!is.null(threshold)){
					if(sum(threshold!=0)==length(threshold)){
						thre.line=-log10(min(threshold))
						if(amplify==TRUE){
							thre.index=which(log.P.values>=thre.line)
							if(length(thre.index)!=0){
							    #print("!!!!")
								#cover the points that exceed the threshold with the color "white"
								points(log.Quantiles[thre.index],log.P.values[thre.index], col = "white",pch=19,lwd=3,cex=cex[3])
								if(is.null(signal.col)){
									points(log.Quantiles[thre.index],log.P.values[thre.index],col = col[1],pch=signal.pch[1],cex=signal.cex[1])
								}else{
									points(log.Quantiles[thre.index],log.P.values[thre.index],col = signal.col[1],pch=signal.pch[1],cex=signal.cex[1])
								}
							}
						}
					}
				}
				box()
				if(file.output) dev.off()
			}
		}
		print("Multiple QQ plot has been finished!",quote=F)
	}

		





	}#End of Whole function

#}
`GAPIT.Compress` <-
function(KI,kinship.cluster = "average",kinship.group = "Mean",GN=nrow(KI),Timmer,Memory){
#Object: To cluster individuals into groups based on kinship
#Output: GA, KG
#Authors: Alex Lipka and Zhiwu Zhang 
# Last update: April 14, 2011 
##############################################################################################
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP start") 
Memory=GAPIT.Memory(Memory=Memory,Infor="cp start")

# Extract the line names
line.names <- KI[,1]

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Does this change memory0") 
Memory=GAPIT.Memory(Memory=Memory,Infor="Does this change memory0")

# Remove the first column of the kinship matrix, which is the line names
KI <- KI[ ,-1]

# Convert kinship to distance
#distance.matrix <- 2 - KI 


#distance.matrix.as.dist <- as.dist(distance.matrix)
#distance.matrix.as.dist <- as.dist(2 - KI)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP distance") 
Memory=GAPIT.Memory(Memory=Memory,Infor="cp distance")

#print(paste("The value of kinship.cluster is ", kinship.cluster, sep = ""))



# hclust() will perform the hiearchical cluster analysis
#cluster.distance.matrix <- hclust(distance.matrix.as.dist, method = kinship.cluster)
#cluster.distance.matrix <- hclust(as.dist(2 - KI), method = kinship.cluster)
distance.matrix=dist(KI,upper=TRUE) #Jiabo Wang modified ,the dist is right function for cluster
cluster.distance.matrix=hclust(distance.matrix,method=kinship.cluster)
#cutree(out_hclust,k=3)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP cluster") 
Memory=GAPIT.Memory(Memory=Memory,Infor="cp cluster")

# Cutree will assign lines into k clusters
group.membership <- cutree(cluster.distance.matrix, k = GN)
compress_z=table(group.membership,paste(line.names))  #build compress z with group.membership

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP cutree") 
Memory=GAPIT.Memory(Memory=Memory,Infor="cp cutree")

#calculate group kinship
if(kinship.group == "Mean"){
#This matrix ooperation is much faster than tapply function for  "Mean"
x=as.factor(group.membership)
#b = model.matrix(~x-1) 
n=max(as.numeric(as.vector(x)))
b=diag(n)[x,]

KG=t(b)%*%as.matrix(KI)%*%b
CT=t(b)%*%(0*as.matrix(KI)+1)%*%b
KG=as.matrix(KG/CT)
rownames(KG)=c(1:nrow(KG))
colnames(KG)=c(1:ncol(KG))

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP calculation original")
Memory=GAPIT.Memory(Memory=Memory,Infor="cp calculation original")



}else{

gm=as.factor(group.membership)
kv=as.numeric(as.matrix(KI))
kvr=rep(gm,ncol(KI))
kvc=as.numeric(t(matrix(kvr,nrow(KI),ncol(KI))))

kInCol=t(rbind(kv,kvr,kvc))

rm(gm)
rm(kv)
rm(kvr)
rm(kvc)
rm(KI)
gc()



#This part does not work yet
#if(kinship.group == "Mean")
#    KG<- tapply(kInCol[,1], list(kInCol[,2], kInCol[,3]), mean)
if(kinship.group == "Max")    
    KG <- tapply(kInCol[,1], list(kInCol[,2], kInCol[,3]), max)
if(kinship.group == "Min")   
    KG <- tapply(kInCol[,1], list(kInCol[,2], kInCol[,3]), min)    
if(kinship.group == "Median")  
    KG <- tapply(kInCol[,1], list(kInCol[,2], kInCol[,3]), median)  
} #this is end of brancing "Mean" and the rest
    
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP calculation") 
Memory=GAPIT.Memory(Memory=Memory,Infor="cp calculation")

# add line names 
#GA <- data.frame(group.membership)
GA <- data.frame(cbind(as.character(line.names),as.numeric(group.membership) ))

#Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="CP Final") 
#Memory=GAPIT.Memory(Memory=Memory,Infor="CP Final")

#write.table(KG, paste("KG_from_", kinship.group, "_Method.txt"), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)

#print("GAPIT.Compress accomplished successfully!")
return(list(GA=GA, KG=KG,Timmer=Timmer,Memory=Memory))
}#The function GAPIT.Compress ends here
#=============================================================================================

`GAPIT.Compression.Visualization` <-
function(Compression = Compression, name.of.trait = name.of.trait){
#Object: Conduct the Benjamini-Hochberg FDR-Controlling Procedure
#Output: Three pdfs: One of the log likelihood function, one of the genetic and error variance component,
#                    and one of the heritabilities
#Authors: Alex Lipka and Zhiwu Zhang 
# Last update: May 10, 2011 
##############################################################################################
#Graph the optimum compression 

print("GAPIT.Compression.Visualization")
#print(Compression)

if(length(Compression)<=6) Compression=t(as.matrix(Compression[which(Compression[,4]!="NULL" | Compression[,4]!="NaN"),]))
if(length(Compression)==6) Compression=matrix(Compression,1,6) 
#print("Compression matrix")
#print(Compression)
#print(length(Compression) )

if(length(Compression)>6) Compression=Compression[which(Compression[,4]!="NULL" | Compression[,4]!="NaN"),]
if(length(Compression)<1) return() #no result

#Pie chart for the optimum setting
#-------------------------------------------------------------------------------
print("Pie chart")
LL=as.numeric(Compression[,4])
Compression.best=Compression[1,] 
variance=as.numeric(Compression.best[5:6])
#colors <- c("grey50","grey70")
colors <- c("#990000","dimgray")
varp=variance/sum(variance)
h2.opt= varp[1]

labels0 <- round(varp * 100, 1)
labels <- paste(labels0, "%", sep="")

legend0=c("Genetic: ","Residual: ")
legend <- paste(legend0, round(variance*100)/100, sep="")

LL.best0=as.numeric(Compression.best[4]  )
LL.best=paste("-2LL: ",floor(LL.best0*100)/100,sep="")
label.comp=paste(c("Cluster method: ","Group method: ","Group number: "), Compression.best[c(1:3)], sep="")
theOptimum=c(label.comp,LL.best) 
#print(variance)
pdf(paste("GAPIT.", name.of.trait,".Optimum.pdf", sep = ""), width = 14)
par(mfrow = c(1,1), mar = c(1,1,5,5), lab = c(5,5,7))
pie(variance,  col=colors, labels=labels,angle=45,border=NA)
legend(1.0, 0.5, legend, cex=1.5, bty="n",
   fill=colors)

#Display the optimum compression
text(1.5,.0, "The optimum compression", col= "gray10")
for(i in 1:4){
text(1.5,-.1*i, theOptimum[i], col= "gray10")
}
dev.off() 

#sort Compression by group number for plot order
Compression=Compression[order(as.numeric(Compression[,3])),]

#Graph compression with multiple groups
#print("Graph compression with multiple groups")


if(length(Compression)==6) return() #For to exit if only one row


#print("It should not go here")

if(length(unique(Compression[,3]))>1)
{
#Create a vector of colors
#print("Setting colors")
color.vector.basic <- c("red","blue","black", "blueviolet","indianred","cadetblue","orange")
color.vector.addition <- setdiff(c(colors()[grep("red",colors())], colors()[grep("blue",colors())]),color.vector.basic )
color.vector.addition.mixed <- sample(color.vector.addition,max(0,((length(unique(Compression[,1])) * length(unique(Compression[,2])))-length(color.vector.basic))))  
color.vector <- c(color.vector.basic,color.vector.addition.mixed )


#Create a vector of numbers for the line dot types
line.vector <-  rep(1:(length(unique(Compression[,1])) * length(unique(Compression[,2]))))

#We want to have a total of three plots, one displaying the likelihood function, one displaying the variance components, and one displaying the
# heritability 

pdf(paste("GAPIT.", name.of.trait,".Compression.multiple.group", ".pdf", sep = ""), width = 14)
par(mfrow = c(2,3), mar = c(5,5,1,1), lab = c(5,5,7))

# Make the likelihood function plot
#print("Likelihood")
k <- 1
for(i in 1:length(unique(Compression[,1]))){
  for(j in 1:length(unique(Compression[,2]))){

     if((i == 1)&(j == 1)) {
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,4])  
      plot(y~x,type="l", pch = 30, lty = line.vector[i], ylim=c(min(as.numeric(Compression[,4])),max(as.numeric(Compression[,4]))), xlim = c(min(as.numeric(Compression[,3])),max(as.numeric(Compression[,3]))),
      col = color.vector[j], xlab = "Number of Groups", ylab = "-2Log Likelihoood",lwd=1 )
      label = paste(c(as.character(unique(Compression[,1]))[k]," ",as.character(unique(Compression[,2]))[j]), collapse = "")
      }
  
    if((i != 1)|(j != 1)) {
      k <- k+1   
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,4])  
      lines(y~x,type="l", pch = 30, lty = line.vector[i], col = color.vector[j])
      label = c(label, paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = ""))
      }  
   }
 }
#Make a legend
  #legend("topright",  label, fill = color.vector)
  legend.col= 1+floor(length(unique(Compression[,1])) * length(unique(Compression[,2]))/20)
line.style=rep(1:length(unique(Compression[,1])), each = length(unique(Compression[,2])))      
line.color=rep(1:length(unique(Compression[,2])), length(unique(Compression[,1])))


legend("topright",  label, col = color.vector[line.color], lty = line.style, ncol=legend.col,horiz=FALSE,bty="n") 
 
 
# Make the genetic variance component plots
#print("genetic variance")
k <- 1
for(i in 1:length(unique(Compression[,1]))){
  for(j in 1:length(unique(Compression[,2]))){

     if((i == 1)&(j == 1)) {
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,5])  
      plot(y~x,type="l", pch = 17,  lty = line.vector[i], ylim=c(min(as.numeric(Compression[,5])),max(as.numeric(Compression[,5]))), xlim = c(min(as.numeric(Compression[,3])),max(as.numeric(Compression[,3]))),
      col = color.vector[j], xlab = "Number of Groups", ylab = "Genetic Variance", )
      #label = paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = "")
      }
  
    if((i != 1)|(j != 1)) {
      k <- k+1   
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,5])  
      lines(y~x,type="l", pch = 17, lty = line.vector[i], col = color.vector[j])
      #label = c(label, paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = ""))
      }  
   }
 }
 #Make a legend
  #legend("topleft",  label, fill = color.vector) 


# Make the residual variance component plots
k <- 1
for(i in 1:length(unique(Compression[,1]))){
  for(j in 1:length(unique(Compression[,2]))){

     if((i == 1)&(j == 1)) {
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,6])  
      plot(y~x,type="l", pch = 17,  ylim=c(min(as.numeric(Compression[,6])),max(as.numeric(Compression[,6]))), xlim = c(min(as.numeric(Compression[,3])),max(as.numeric(Compression[,3]))),
      col = color.vector[j], xlab = "Number of Groups", ylab = "Residual Variance", )
      #label = paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = "")
      }
  
    if((i != 1)|(j != 1)) {
      k <- k+1   
      Compression.subset <- Compression[which( (Compression[,1] == as.character(unique(Compression[,1])[i])) & (Compression[,2] == as.character(unique(Compression[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,6])  
      lines(y~x,type="l", pch = 17, lty = line.vector[i], col = color.vector[j])
      #label = c(label, paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = ""))
      }  
   }
 }
 #Make a legend
  #legend("topright",  label, fill = color.vector) 


#calculate total variance and h2
#print("h2")
heritablilty.vector <- as.numeric(Compression[,5])/(as.numeric(Compression[,5]) + as.numeric(Compression[,6]))
totalVariance.vector <- as.numeric(as.numeric(Compression[,5]) + as.numeric(Compression[,6]))
Compression.h2 <- cbind(Compression, heritablilty.vector,totalVariance.vector)

# Make the total variance component plots
#print("Total variance")
k <- 1
for(i in 1:length(unique(Compression.h2[,1]))){
  for(j in 1:length(unique(Compression.h2[,2]))){

     if((i == 1)&(j == 1)) {
      Compression.subset <- Compression.h2[which( (Compression.h2[,1] == as.character(unique(Compression.h2[,1])[i])) & (Compression.h2[,2] == as.character(unique(Compression.h2[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,8])  
      plot(y~x,type="l", pch = 17,  lty = line.vector[k], ylim=c(min(as.numeric(Compression.h2[,8])),max(as.numeric(Compression.h2[,8]))), xlim = c(min(as.numeric(Compression.h2[,3])),max(as.numeric(Compression.h2[,3]))),
      col = color.vector[1], xlab = "Number of Groups", ylab = "Total Variance", )
      #label = paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = "")
      }
  
    if((i != 1)|(j != 1)) {
      k <- k+1   
      Compression.subset <- Compression.h2[which( (Compression.h2[,1] == as.character(unique(Compression.h2[,1])[i])) & (Compression.h2[,2] == as.character(unique(Compression.h2[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,8]) 
      lines(y~x,type="l", pch = 17, lty = line.vector[i], col = color.vector[j])
      #label = c(label, paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = ""))
      }  
   }
 }
 #Make a legend
  #legend("topright",  label, fill = color.vector) 
  

# Make the heritability plots 
#print("h2 plot")
k <- 1
for(i in 1:length(unique(Compression[,1]))){
  for(j in 1:length(unique(Compression[,2]))){

     if((i == 1)&(j == 1)) {
      Compression.subset <- Compression.h2[which( (Compression.h2[,1] == as.character(unique(Compression.h2[,1])[i])) & (Compression.h2[,2] == as.character(unique(Compression.h2[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,7]) 

      plot(y~x,type="l", pch = 17,  lty = line.vector[k], ylim=c(min(as.numeric(Compression.h2[,7])),max(as.numeric(Compression.h2[,7]))), xlim = c(min(as.numeric(Compression.h2[,3])),max(as.numeric(Compression.h2[,3]))),
      col = color.vector[1], xlab = "Number of Groups", ylab = "Heritability", )
      #label = paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = "")
      }
  
    if((i != 1)|(j != 1)) {
      k <- k+1   
      Compression.subset <- Compression.h2[which( (Compression.h2[,1] == as.character(unique(Compression.h2[,1])[i])) & (Compression.h2[,2] == as.character(unique(Compression.h2[,2])[j]))  ),              ]
      x <- as.numeric(Compression.subset[,3])
      y <- as.numeric(Compression.subset[,7])  
      lines(y~x,type="l", lty = line.vector[i], pch = 17, col = color.vector[j])
      #label = c(label, paste(c(as.character(unique(Compression[,1]))[i]," ",as.character(unique(Compression[,2]))[j]), collapse = ""))
      }       
   }
 }
 
 #Make a legend
  #legend("topleft",  label, fill = color.vector) 
  
legend.col= 1+floor(length(unique(Compression[,1])) * length(unique(Compression[,2]))/20)
line.style=rep(1:length(unique(Compression[,1])), each = length(unique(Compression[,2])))      
line.color=rep(1:length(unique(Compression[,2])), length(unique(Compression[,1])))



# Make labels
      plot(0~0,axes=FALSE,type="l",ylab = "",xlab = "",frame.plot=FALSE)
      legend("topleft",  label, col = color.vector[line.color], lty = line.style, ncol=legend.col,horiz=FALSE) 
   
 
dev.off()
}#end of Graph compression with multiple groups

#Graph compression with single groups
#print("Graph compression with single groups")
if(length(unique(Compression[,3]))==1& length(unique(Compression[,1]))*length(unique(Compression[,2]))>1)
{

#Graph the compression with only one group
pdf(paste("GAPIT.Compression.single.group.", name.of.trait, ".pdf", sep = ""), width = 14)
par(mfrow = c(2,2), mar = c(5,5,1,1), lab = c(5,5,7))

nkt=length(unique(Compression[,1]))
nca=length(unique(Compression[,2]))
kvr=rep(c(1:nkt),nca)
kvc0=rep(c(1:nca),nkt)
kvc=as.numeric(t(matrix(kvc0,nca,nkt)))
kt.name=Compression[1:nkt,1]

ca.index=((1:nca)-1)*nkt+1
ca.name=Compression[ca.index,2]

KG<- t(tapply(as.numeric(Compression[,4]), list(kvr, kvc), mean))
colnames(KG)=kt.name
barplot(as.matrix(KG),  ylab= "-2 Log Likelihood",beside=TRUE, col=rainbow(length(unique(Compression[,2]))))


KG<- t(tapply(as.numeric(Compression[,5]), list(kvr, kvc), mean))
colnames(KG)=kt.name
barplot(as.matrix(KG),  ylab= "Genetic varaince", beside=TRUE, col=rainbow(length(unique(Compression[,2]))))

KG<- t(tapply(as.numeric(Compression[,6]), list(kvr, kvc), mean))
colnames(KG)=kt.name
barplot(as.matrix(KG),  ylab= "Residual varaince", beside=TRUE, col=rainbow(length(unique(Compression[,2]))))

KG<- t(tapply(as.numeric(Compression[,5])/(as.numeric(Compression[,5])+as.numeric(Compression[,6])), list(kvr, kvc), mean))
colnames(KG)=kt.name
barplot(as.matrix(KG),  ylab= "Heritability", beside=TRUE, col=rainbow(length(unique(Compression[,2]))),ylim=c(0,1))

legend("topleft", paste(t(ca.name)), cex=0.8,bty="n", fill=rainbow(length(unique(Compression[,2]))),horiz=TRUE)
dev.off() 
} #end of Graph compression with single groups

print("GAPIT.Compression.Visualization accomplished successfully!")

#return(list(compression=Compression.h2,h2=h2.opt))
return

}#GAPIT.Compression.Plots ends here
#=============================================================================================

`GAPIT.Create.Indicator` <-
function(xs, SNP.impute = "Major" ){
#Object: To esimate variance component by using EMMA algorithm and perform GWAS with P3D/EMMAx
#Output: ps, REMLs, stats, dfs, vgs, ves, BLUP,  BLUP_Plus_Mean, PEV
#Authors: Alex Lipka and Zhiwu Zhang
# Last update: April 30, 2012
##############################################################################################
#Determine the number of bits of the genotype

bit=nchar(as.character(xs[1]))


#Identify the SNPs classified as missing

if(bit==1)  {
xss[xss=="xs"]="N"
xs[xs=="-"]="N"
xs[xs=="+"]="N"
xs[xs=="/"]="N"
xs[xs=="K"]="Z" #K (for GT genotype)is is replaced by Z to ensure heterozygose has the largest value
}

if(bit==2)  {
xs[xs=="xsxs"]="N"
xs[xs=="--"]="N"
xs[xs=="++"]="N"
xs[xs=="//"]="N"
xs[xs=="NN"]="N"
}

#Create the indicators

#Sort the SNPs by genotype frequency
xs.temp <- xs[-which(xs == "N")]

frequ<- NULL
for(i in 1:length(unique(xs.temp))) frequ <- c(frequ, length(which(xs == unique(xs)[i])))

unique.sorted <- cbind(unique(xs.temp), frequ)

print("unique.sorted is")
print(unique.sorted)

unique.sorted <- unique.sorted[order(unique.sorted[,2]),]
unique.sorted <- unique.sorted[,-2]


#Impute based on the major and minor allele frequencies
if(SNP.impute == "Major") xs[which(is.na(xs))] = unique.sorted[1]
if(SNP.impute == "Minor") xs[which(is.na(xs))] = unique.sorted[length(unique.sorted)]
if(SNP.impute == "Middle") xs[which(is.na(xs))] = unique.sorted[2]
x.ind <- NULL
for(i in unique.sorted){
 x.col <- rep(NA, length(xs))
 x.col[which(xs==i)] <- 1
 x.col[which(xs!=i)] <- 0
 x.ind <- cbind(x.ind,x.col)                         
}



return(x.ind)

print("GAPIT.Create.Indicator accomplished successfully!")
}#end of GAPIT.Create.Indicator function
#=============================================================================================

`GAPIT.DP` <-
function(G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,CV.Inheritance=NULL,GP=NULL,GK=NULL,
                group.from=30 ,group.to=1000000,group.by=10,DPP=100000, 
                kinship.cluster="average", kinship.group='Mean',kinship.algorithm="VanRaden",                                                    
                bin.from=10000,bin.to=10000,bin.by=10000,inclosure.from=10,inclosure.to=10,inclosure.by=10,
                SNP.P3D=TRUE,SNP.effect="Add",SNP.impute="Middle",PCA.total=0, SNP.fraction = 1, seed = 123, BINS = 20,SNP.test=TRUE, 
                    SNP.MAF=0,FDR.Rate = 1, SNP.FDR=1,SNP.permutation=FALSE,SNP.CV=NULL,SNP.robust="GLM", NJtree.group=NULL,NJtree.type=c("fan","unrooted"),plot.bin=10^6,PCA.col=NULL,PCA.3d=FALSE,
                file.from=1, file.to=1, file.total=NULL, file.fragment = 99999,file.path=NULL,Inter.Plot=FALSE,Inter.type=c("m","q"),
                file.G=NULL, file.Ext.G=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL, 
                ngrid = 100, llim = -10, ulim = 10, esp = 1e-10, Multi_iter=FALSE,num_regwas=10,
                LD.chromosome=NULL,LD.location=NULL,LD.range=NULL, p.threshold=NA,QTN.threshold=0.01,maf.threshold=0.03,
                sangwich.top=NULL,sangwich.bottom=NULL,QC=TRUE,GTindex=NULL,LD=0.1,opt="extBIC",
                file.output=TRUE,cutOff=0.01, Model.selection = FALSE,output.numerical = FALSE,Random.model=FALSE,
                output.hapmap = FALSE, Create.indicator = FALSE,QTN=NULL, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = FALSE,
        method.GLM="fast.lm",method.sub="reward",method.sub.final="reward",method.bin="static",bin.size=c(1000000),bin.selection=c(10,20,50,100,200,500,1000),
        memo="",Prior=NULL,ncpus=1,maxLoop=3,threshold.output=.01, WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),maxOut=100,QTN.position=NULL,
        converge=1,iteration.output=FALSE,acceleration=0,iteration.method="accum",PCA.View.output=TRUE,Geno.View.output=TRUE,plot.style="Oceanic",SUPER_GD=NULL,SUPER_GS=FALSE,CG=NULL,model="MLM"){
#Object: To Data and Parameters  
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("GAPIT.DP in process...")
#Judge phenotype  genotype and GAPIT logical
#print(file.from)
#print(kinship.algorithm)
#print(NJtree.group)
myGenotype<-GAPIT.Genotype(G=G,GD=GD,GM=GM,KI=KI,PCA.total=PCA.total,kinship.algorithm=kinship.algorithm,SNP.fraction=SNP.fraction,SNP.test=FALSE,
                file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,NJtree.group=NJtree.group,NJtree.type=NJtree.type,
                LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,
                GP=GP,GK=GK,bin.size=NULL,inclosure.size=NULL, 
                sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,GTindex=NULL,file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero,Geno.View.output=Geno.View.output,PCA.col=PCA.col,PCA.3d=PCA.3d)

# }

KI=myGenotype$KI
PC=myGenotype$PC
print(dim(PC))

genoFormat=myGenotype$genoFormat
hasGenotype=myGenotype$hasGenotype
byFile=myGenotype$byFile
fullGD=myGenotype$fullGD
GD=myGenotype$GD
GI=myGenotype$GI

GT=myGenotype$GT
G=myGenotype$G
chor_taxa=myGenotype$chor_taxa

#if G exist turn to GD and GM

if(output.numerical) write.table(GD,  "GAPIT.Genotype.Numerical.txt", quote = FALSE, sep = "\t", row.names = TRUE,col.names = NA)
if(output.hapmap) write.table(myGenotype$G,  "GAPIT.Genotype.hmp.txt", quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)


rownames(GD)=GT
colnames(GD)=GI[,1]
GD=cbind(as.data.frame(GT),GD)

  print("GAPIT.DP accomplished successfully for multiple traits. Results are saved")
  return (list(Y=NULL,G=G,GD=GD,GM=GI,KI=KI,Z=Z,CV=CV,CV.Inheritance= CV.Inheritance,GP=GP,GK=GK,PC=PC,GI=GI,
                group.from= group.from ,group.to= group.to,group.by= group.by,DPP= DPP, name.of.trait=NULL,
                kinship.cluster= kinship.cluster, kinship.group= kinship.group,kinship.algorithm= kinship.algorithm,NJtree.group=NJtree.group,NJtree.type=NJtree.type,PCA.col=PCA.col,PCA.3d=PCA.3d,                                              
                bin.from= bin.from,bin.to= bin.to,bin.by= bin.by,inclosure.from= inclosure.from,inclosure.to= inclosure.to,inclosure.by= inclosure.by,opt=opt,
                SNP.P3D= SNP.P3D,SNP.effect= SNP.effect,SNP.impute= SNP.impute,PCA.total= PCA.total, SNP.fraction = SNP.fraction, seed = seed, 
                BINS = BINS,SNP.test=SNP.test, SNP.MAF= SNP.MAF,FDR.Rate = FDR.Rate, SNP.FDR= SNP.FDR,SNP.permutation= SNP.permutation,
                SNP.CV= SNP.CV,SNP.robust= SNP.robust, file.from= file.from, file.to=file.to, file.total= file.total, file.fragment = file.fragment,file.path= file.path, 
                file.G= file.G, file.Ext.G= file.Ext.G,file.GD= file.GD, file.GM= file.GM, file.Ext.GD= file.Ext.GD,file.Ext.GM= file.Ext.GM, 
                ngrid = ngrid, llim = llim, ulim = ulim, esp = esp,Inter.Plot=Inter.Plot,Inter.type=Inter.type,
                LD.chromosome= LD.chromosome,LD.location= LD.location,LD.range= LD.range,Multi_iter=Multi_iter,
                sangwich.top= sangwich.top,sangwich.bottom= sangwich.bottom,QC= QC,GTindex= GTindex,LD= LD,GT=GT,
                file.output= file.output,cutOff=cutOff, Model.selection = Model.selection,output.numerical = output.numerical,
                output.hapmap = output.hapmap, Create.indicator = Create.indicator,Random.model=Random.model,
				 QTN= QTN, QTN.round= QTN.round,QTN.limit= QTN.limit, QTN.update= QTN.update, QTN.method= QTN.method, Major.allele.zero = Major.allele.zero,
               method.GLM= method.GLM,method.sub= method.sub,method.sub.final= method.sub.final,
               method.bin= method.bin,bin.size= bin.size,bin.selection= bin.selection,
        		memo= memo,Prior= Prior,ncpus=1,maxLoop= maxLoop,threshold.output= threshold.output,
        		WS= WS,alpha= alpha,maxOut= maxOut,QTN.position= QTN.position, converge=1,iteration.output= iteration.output,acceleration=0,
        		iteration.method= iteration.method,PCA.View.output= PCA.View.output, 
                p.threshold=p.threshold,QTN.threshold=QTN.threshold,
                maf.threshold=maf.threshold,chor_taxa=chor_taxa,num_regwas=num_regwas,
        		Geno.View.output= Geno.View.output,plot.style= plot.style,SUPER_GD= SUPER_GD,SUPER_GS= SUPER_GS,CG=CG,plot.bin=plot.bin))
}  #end of GAPIT DP function
#=============================================================================================

`GAPIT.EMMAxP3D` <-
function(ys,xs,K=NULL,Z=NULL,X0=NULL,CVI=NULL,CV.Inheritance=NULL,GI=NULL,GP=NULL,
		file.path=NULL,file.from=NULL,file.to=NULL,file.total=1, genoFormat="Hapmap", file.fragment=NULL,byFile=FALSE,fullGD=TRUE,SNP.fraction=1,
    file.G=NULL,file.Ext.G=NULL,GTindex=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL,
    SNP.P3D=TRUE,Timmer,Memory,optOnly=TRUE,SNP.effect="Add",SNP.impute="Middle", SNP.permutation=FALSE,
    ngrids=100,llim=-10,ulim=10,esp=1e-10,name.of.trait=NULL, Create.indicator = FALSE, Major.allele.zero = FALSE){
#Object: To esimate variance component by using EMMA algorithm and perform GWAS with P3D/EMMAx
#Output: ps, REMLs, stats, dfs, vgs, ves, BLUP,  BLUP_Plus_Mean, PEV
#Authors: Feng Tian, Alex Lipka and Zhiwu Zhang
# Last update: April 6, 2016
# Library used: EMMA (Kang et al, Genetics, Vol. 178, 1709-1723, March 2008)
# Note: This function was modified from the function of emma.REML.t from the library
##############################################################################################
#print("EMMAxP3D started...")
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="P3D Start")
Memory=GAPIT.Memory(Memory=Memory,Infor="P3D Start")


#When numeric genotypes are selected, impute the missing SNPs with the allele indicated by the "SNP.impute" value
if(!optOnly){
 if(SNP.impute == "Major") xs[which(is.na(xs))] = 2
 if(SNP.impute == "Minor") xs[which(is.na(xs))] = 0
 if(SNP.impute == "Middle") xs[which(is.na(xs))] = 1
}


#--------------------------------------------------------------------------------------------------------------------<
#Change data to matrix format if they are not
if(is.null(dim(ys)) || ncol(ys) == 1)  ys <- matrix(ys, 1, length(ys))
if(is.null(X0)) X0 <- matrix(1, ncol(ys), 1)

#handler of special Z and K
if(!is.null(Z)){ if(ncol(Z) == nrow(Z)) Z = NULL }
if(!is.null(K)) {if(length(K)<= 1) K = NULL}

#Extract dimension information
g <- nrow(ys) #number of traits
n <- ncol(ys) #number of observation

q0 <- ncol(X0)#number of fixed effects
q1 <- q0 + 1  #Nuber of fixed effect including SNP

nr=n
if(!is.null(K)) tv=ncol(K)

#decomposation without fixed effect
#print("Caling emma.eigen.L...")
if(!is.null(K)) eig.L <- emma.eigen.L(Z, K) #this function handle both NULL Z and non-NULL Z matrix

#eig.L$values[eig.L$values<0]=0
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="eig.L")
Memory=GAPIT.Memory(Memory=Memory,Infor="eig.L")

#decomposation with fixed effect (SNP not included)
#print("Calling emma.eigen.R.w.Z...")
X <-  X0 #covariate variables such as population structure
if(!is.null(Z) & !is.null(K)) eig.R <- try(emma.eigen.R.w.Z(Z, K, X),silent=TRUE) #This will be used to get REstricted ML (REML)
if(is.null(Z)  & !is.null(K)) eig.R <- try(emma.eigen.R.wo.Z(   K, X),silent=TRUE) #This will be used to get REstricted ML (REML)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="eig.R")
Memory=GAPIT.Memory(Memory=Memory,Infor="eig.R")

#eig.R$values[eig.R$values<0]=0
#print(labels(eig.R))
#print(length(eig.R$values))
#print(dim(eig.R$vectors))
#print("emma.eigen.R.w.Z called!!!")
#Handler of error in emma
#print("!!!!!!")
if(!is.null(K)){
if(inherits(eig.R, "try-error"))
       return(list(ps = NULL, REMLs = NA, stats = NULL, effect.est = NULL, dfs = NULL,maf=NULL,nobs = NULL,Timmer=Timmer,Memory=Memory,
        vgs = NA, ves = NA, BLUP = NULL, BLUP_Plus_Mean = NULL,
        PEV = NULL, BLUE=NULL))

#print("@@@@@")
 }
#-------------------------------------------------------------------------------------------------------------------->
#print("Looping through traits...")
#Loop on Traits
for (j in 1:g)
{

if(optOnly){

  #REMLE <- GAPIT.emma.REMLE(ys[j,], X, K, Z, ngrids, llim, ulim, esp, eig.R)
  #vgs <- REMLE$vg
  #ves <- REMLE$ve
  #REMLs <- REMLE$REML
  #REMLE_delta=REMLE$delta

 if(!is.null(K)){
  REMLE <- GAPIT.emma.REMLE(ys[j,], X, K, Z, ngrids, llim, ulim, esp, eig.R)

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="REML")
  Memory=GAPIT.Memory(Memory=Memory,Infor="REML")

  rm(eig.R)
  gc()
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="eig.R removed")
  Memory=GAPIT.Memory(Memory=Memory,Infor="eig.R removed")

  vgs <- REMLE$vg
  ves <- REMLE$ve
  REMLs <- REMLE$REML
  REMLE_delta=REMLE$delta

  rm(REMLE)
  gc()
  }


  vids <- !is.na(ys[j,])
  yv <- ys[j, vids]

  if(!is.null(Z) & !is.null(K))  U <- eig.L$vectors * matrix(c(sqrt(1/(eig.L$values + REMLE_delta)),rep(sqrt(1/REMLE_delta),nr - tv)),nr,((nr-tv)+length(eig.L$values)),byrow=TRUE)
  if( is.null(Z) & !is.null(K))  U <- eig.L$vectors * matrix(  sqrt(1/(eig.L$values + REMLE_delta)),nr,length(eig.L$values),byrow=TRUE)

  if( !is.null(Z) & !is.null(K)) eig.full.plus.delta <- as.matrix(c((eig.L$values + REMLE_delta), rep(REMLE_delta,(nr - tv))))
  if( is.null(Z) & !is.null(K))  eig.full.plus.delta <- as.matrix((eig.L$values + REMLE_delta))

  if(!is.null(K)){
   if(length(which(eig.L$values < 0)) > 0 ){
    #print("---------------------------------------------------The group kinship matrix at this compression level is not positive semidefinite. Please select another compression level.---------------------------------------------------")
           #return(list(ps = NULL, REMLs = 999999, stats = NULL, effect.est = NULL, dfs = NULL,maf=NULL,nobs = NULL,Timmer=Timmer,Memory=Memory,
           #vgs = 1.000, ves = 1.000, BLUP = NULL, BLUP_Plus_Mean = NULL,
           #PEV = NULL, BLUE=NULL))
    }
  }
  

  #Calculate the log likelihood function for the intercept only model

   X.int <- matrix(1,nrow(as.matrix(yv)),ncol(as.matrix(yv)))
   iX.intX.int <- solve(crossprod(X.int, X.int))
   iX.intY <- crossprod(X.int, as.matrix(as.matrix(yv)))
   beta.int <- crossprod(iX.intX.int, iX.intY)  #Note: we can use crossprod here becase iXX is symmetric
   X.int.beta.int <- X.int%*%beta.int


   logL0 <- 0.5*((-length(yv))*log(((2*pi)/length(yv))
                 *crossprod((yv-X.int.beta.int),(yv-X.int.beta.int)))
                  -length(yv))

    #print(paste("The value of logL0 inside of the optonly template is is",logL0, sep = ""))




  #print(paste("The value of nrow(as.matrix(ys[!is.na(ys)])) is ",nrow(as.matrix(ys[!is.na(ys)])), sep = ""))



     if(!is.null(K)){
      yt <- yt <- crossprod(U, yv)
      X0t <- crossprod(U, X0)

     X0X0 <- crossprod(X0t, X0t)
     X0Y <- crossprod(X0t,yt)
     XY <- X0Y

     iX0X0 <- try(solve(X0X0),silent=TRUE)
     if(inherits(iX0X0, "try-error")){
     iX0X0 <- ginv(X0X0)
     print("At least two of your covariates are linearly dependent. Please reconsider the covariates you are using for GWAS and GPS")
     }
    iXX <- iX0X0
    }

      if(is.null(K)){
        iXX <- try(solve(crossprod(X,X)),silent=TRUE)
        if(inherits(iXX, "try-error"))iXX <- ginv(crossprod(X,X))
        XY = crossprod(X,yv)
      }
      beta <- crossprod(iXX,XY) #Note: we can use crossprod here because iXX is symmetric
      X.beta <- X%*%beta
      
      beta.cv=beta
      BLUE=X.beta
      
      if(!is.null(K)){
              U.times.yv.minus.X.beta <- crossprod(U,(yv-X.beta))
              logLM <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta))
                    - sum(log(eig.full.plus.delta)) - length(yv))
      }


      if(is.null(K)){
              U.times.yv.minus.X.beta <- yv-X.beta
              logLM <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta)) - length(yv))
      }

 }#End if(optOnly)



#--------------------------------------------------------------------------------------------------------------------<
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Trait")
Memory=GAPIT.Memory(Memory=Memory,Infor="Trait")

if(!is.null(K)){
  REMLE <- GAPIT.emma.REMLE(ys[j,], X, K, Z, ngrids, llim, ulim, esp, eig.R)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="REML")
Memory=GAPIT.Memory(Memory=Memory,Infor="REML")

rm(eig.R)
gc()
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="eig.R removed")
Memory=GAPIT.Memory(Memory=Memory,Infor="eig.R removed")

  vgs <- REMLE$vg
  ves <- REMLE$ve
  REMLs <- REMLE$REML
  REMLE_delta=REMLE$delta

rm(REMLE)
gc()
}
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="REMLE removed")
Memory=GAPIT.Memory(Memory=Memory,Infor="REMLE removed")

if(!is.null(Z) & !is.null(K))  U <- eig.L$vectors * matrix(c(sqrt(1/(eig.L$values + REMLE_delta)),rep(sqrt(1/REMLE_delta),nr - tv)),nr,((nr-tv)+length(eig.L$values)),byrow=TRUE)
if( is.null(Z) & !is.null(K))  U <- eig.L$vectors * matrix(  sqrt(1/(eig.L$values + REMLE_delta)),nr,length(eig.L$values),byrow=TRUE)

if( !is.null(Z) & !is.null(K)) eig.full.plus.delta <- as.matrix(c((eig.L$values + REMLE_delta), rep(REMLE_delta,(nr - tv))))
if( is.null(Z) & !is.null(K))  eig.full.plus.delta <- as.matrix((eig.L$values + REMLE_delta))



if(!is.null(K)){
if(length(which(eig.L$values < 0)) > 0 ){
 #print("---------------------------------------------------The group kinship matrix at this compression level is not positive semidefinite. Please select another compression level.---------------------------------------------------")
       #return(list(ps = NULL, REMLs = 999999, stats = NULL, effect.est = NULL, dfs = NULL,maf=NULL,nobs = NULL,Timmer=Timmer,Memory=Memory,
        #vgs = 1.000, ves = 1.000, BLUP = NULL, BLUP_Plus_Mean = NULL,
        #PEV = NULL, BLUE=NULL))
 }
}


Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="U Matrix")
Memory=GAPIT.Memory(Memory=Memory,Infor="U Matrix")

if(SNP.P3D == TRUE)rm(eig.L)
gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="eig.L removed")
Memory=GAPIT.Memory(Memory=Memory,Infor="eig.L removed")

#-------------------------------------------------------------------------------------------------------------------->

#The cases that go though multiple file once
file.stop=file.to
if(optOnly) file.stop=file.from
if(fullGD)  file.stop=file.from
if(!fullGD & !optOnly) {print("Screening SNPs from file...")}

#Add loop for genotype data files
for (file in file.from:file.stop)
{
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="New Genotype file")
Memory=GAPIT.Memory(Memory=Memory,Infor="New Genotype file")



  frag=1
  numSNP=file.fragment
  myFRG=NULL
while(numSNP==file.fragment) {     #this is problematic if the read end at the last line



  #initial previous SNP storage
  x.prev <- vector(length = 0)

  #force to skip the while loop if optOnly
  if(optOnly) numSNP=0

  #Determine the case of first file and first fragment: skip read file
  if(file==file.from & frag==1& SNP.fraction<1){
    firstFileFirstFrag=TRUE
  }else{
    firstFileFirstFrag=FALSE
  }

#In case of xs is not full GD, replace xs from file
  if(!fullGD & !optOnly & !firstFileFirstFrag )
  {

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Clean myFRG")
Memory=GAPIT.Memory(Memory=Memory,Infor="Clean myFRG")

#update xs for each file
    rm(xs)
    rm(myFRG)
    gc()
    print(paste("Current file: ",file," , Fragment: ",frag,sep=""))

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Read file fragment")
Memory=GAPIT.Memory(Memory=Memory,Infor="Read file fragment")

    myFRG=GAPIT.Fragment( file.path=file.path,  file.total=file.total,file.G=file.G,file.Ext.G=file.Ext.G,
                          seed=seed,SNP.fraction=SNP.fraction,SNP.effect=SNP.effect,SNP.impute=SNP.impute,genoFormat=genoFormat,
                          file.GD=file.GD,file.Ext.GD=file.Ext.GD,file.GM=file.GM,file.Ext.GM=file.Ext.GM,file.fragment=file.fragment,file=file,frag=frag, 
                           Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype file converted")
Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype file converted")

#print("-----------------------------------------------------------------")

      if(is.null(myFRG$GD)){
        xs=NULL
      }else{
        xs=myFRG$GD[GTindex,]
      }


        if(!is.null(myFRG$GI))    {
          colnames(myFRG$GI)=c("SNP","Chromosome","Position")
          GI=as.matrix(myFRG$GI)
        }
        

      if(!is.null(myFRG$GI))    {
        numSNP=ncol(myFRG$GD)
      }  else{
       numSNP=0
      }
      if(is.null(myFRG))numSNP=0  #force to end the while loop
  } # end of if(!fullGD)

  if(fullGD)numSNP=0  #force to end the while loop

#Skip REML if xs is from a empty fragment file
if(!is.null(xs))  {

   
  if(is.null(dim(xs)) || nrow(xs) == 1)  xs <- matrix(xs, length(xs),1)
  
  xs <- as.matrix(xs)
  
    if(length(which(is.na(xs)))>0){    #for the case where fragments are read in
     if(SNP.impute == "Major") xs[which(is.na(xs))] = 2
     if(SNP.impute == "Minor") xs[which(is.na(xs))] = 0
     if(SNP.impute == "Middle") xs[which(is.na(xs))] = 1
    }

  
  m <- ncol(xs) #number of SNPs
  t <- nrow(xs) #number of individuals
 
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Before cleaning")
Memory=GAPIT.Memory(Memory=Memory,Infor="Before cleaning")
  #allocate spaces for SNPs
  rm(dfs)
  rm(stats)
  rm(effect.est)
  rm(ps)
  rm(nobs)
  rm(maf)
  rm(rsquare_base)
  rm(rsquare)
            rm(df)
            rm(tvalue)
            rm(stderr)
  gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="After cleaning")
Memory=GAPIT.Memory(Memory=Memory,Infor="After cleaning")

  dfs <- matrix(nrow = m, ncol = g)
  stats <- matrix(nrow = m, ncol = g)
  if(!Create.indicator) effect.est <- matrix(nrow = m, ncol = g)
  if(Create.indicator) effect.est <- NULL
  ps <- matrix(nrow = m, ncol = g)
  nobs <- matrix(nrow = m, ncol = g)
  maf <- matrix(nrow = m, ncol = g)
  rsquare_base <- matrix(nrow = m, ncol = g)
  rsquare <- matrix(nrow = m, ncol = g)
            df <- matrix(nrow = m, ncol = g)
            tvalue <- matrix(nrow = m, ncol = g)
            stderr <- matrix(nrow = m, ncol = g)
  #print(paste("Memory allocated.",sep=""))
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Memory allocation")
  Memory=GAPIT.Memory(Memory=Memory,Infor="Memory allocation")

  if(optOnly)mloop=0
  if(!optOnly)mloop=m

  #Loop on SNPs
  #print(paste("Number of SNPs is ",mloop," in genotype file ",file, sep=""))

#set starting point of loop
if(file==file.from&frag==1){loopStart=0}else{loopStart=1}

for (i in loopStart:mloop){
#print(i)
#--------------------------------------------------------------------------------------------------------------------<
    normalCase=TRUE

    if((i >0)&(floor(i/1000)==i/1000)) {print(paste("Genotype file: ", file,", SNP: ",i," ",sep=""))}
    # To extract current snp. It save computation for next one in case they are identical
    if(i ==0&file==file.from&frag==1){
      #For the model without fitting SNP
      vids <- !is.na(ys[j,]) #### Feng changed
      xv <- ys[j, vids]*0+1 #### Feng changed
    }

    if(i >0 | file>file.from | frag>1){
      if(Create.indicator){ #I need create indicators and then calculate the minor allele frequency
       condition.temp <- unique(xs[vids,i])
       #Define what a bit is
       
       bit=nchar(as.character(xs[vids[1],i]))
       
       #Expand on the "which" statement below to include all instances of missing data
       
       if(bit==1)  condition <-  condition.temp[-which(condition.temp == "N")]
       if(bit==2)  condition <-  condition.temp[-which(condition.temp == "NN")]
       
       #print("condition.temp is ")
       #print(condition.temp)
                                                                                                                        
       #print("condition is")
       #print(condition)
       
       #print(paste("The value of i is ", i, sep = "")) 
        
       
       if(length(condition) <= 1){
        dfs[i, ] <- rep(NA, g)
        stats[i, ] <- rep(NA, g)
        effect.est <- rbind(effect.est, c(i,rep(NA, g), rep(NA, g)))
        ps[i, ] = rep(1, g)
        rsquare[i, ] <- rep(NA,g)
        rsquare_base[i, ]<-rep(NA,g)
        maf[i, ] <- rep(0, g)
                    df[i, ] <- rep(NA,g)
                    tvalue[i, ] <- rep(NA,g)
                    stderr[i, ] <- rep(NA,g)
        normalCase=FALSE
        x.prev= vector(length = 0)
       }
       
       }
       if(normalCase){
       #print("The head of xs[vids,i] is")
       #print(head(xs[vids,i]))
      
      if(Create.indicator){     #I need create indicators and then calculate the minor allele frequency
       
       indicator <-  GAPIT.Create.Indicator(xs[vids,i], SNP.impute = SNP.impute)
       xv <- indicator$x.ind
       vids <- !is.na(xv[,1]) #### Feng changed
      
       vids.TRUE=which(vids==TRUE)
       vids.FALSE=which(vids==FALSE)
       ns=nrow(xv)
       ss=sum(xv[,ncol(xv)])

       maf[i]=min(ss/ns,1-ss/ns)
       nobs[i]=ns
       
        q1 <- q0 + ncol(xv)    # This is done so that parameter estimates for all indicator variables are included

       
        #These two matrices need to be reinitiated for each SNP.
        Xt <- matrix(NA,nr, q1)
        iXX=matrix(NA,q1,q1)
       }       
      }
     
      if(!Create.indicator){ #### Feng changed
	   #print(xs[1:10,1:10])

       xv <- xs[vids,i]
       vids <- !is.na(xs[,i]) #### Feng changed
      
       vids.TRUE=which(vids==TRUE)
       vids.FALSE=which(vids==FALSE)
       ns=length(xv)
	   #print(xv))
       ss=sum(xv)

       maf[i]=min(.5*ss/ns,1-.5*ss/ns)
       nobs[i]=ns
      }

     nr <- sum(vids)
     if(i ==1 & file==file.from&frag==1 & !Create.indicator) {
       Xt <- matrix(NA,nr, q1)
       iXX=matrix(NA,q1,q1)
     }

    }

    #Situation of no variation for SNP except the fisrt one(synthetic for EMMAx/P3D)
    if((min(xv) == max(xv)) & (i >0 | file>file.from |frag>1))
    {
      dfs[i, ] <- rep(NA, g)
      stats[i, ] <- rep(NA, g)
      if(!Create.indicator) effect.est[i,] <- rep(NA, g)
      if(Create.indicator) effect.est <- rbind(effect.est, c(i,rep(NA, g),rep(NA, g)))
      ps[i, ] = rep(1, g)
      rsquare[i, ] <- rep(NA,g)
      rsquare_base[i, ]<-rep(NA,g)
                df[i, ] <- rep(NA,g)
                tvalue[i, ] <- rep(NA,g)
                stderr[i, ] <- rep(NA,g)
      normalCase=FALSE
    }else if(identical(x.prev, xv))     #Situation of the SNP is identical to previous
    {
      if(i >1 | file>file.from | frag>1){
        dfs[i, ] <- dfs[i - 1, ]
        stats[i, ] <- stats[i - 1, ]
        if(!Create.indicator) effect.est[i, ] <- effect.est[i - 1, ]
        if(Create.indicator) effect.est <- rbind(effect.est, c(i, rep(NA, g), rep(NA, g))) #If the previous SNP is idnetical, indicate this by "NA"
        ps[i, ] <- ps[i - 1, ]
        rsquare[i, ] <- rsquare[i - 1, ]
        rsquare_base[i, ] <-rsquare_base[i - 1, ]
                  df[i, ] <- df[i - 1, ]
                  tvalue[i, ] <- tvalue[i - 1, ]
                  stderr[i, ] <- stderr[i - 1, ]
        normalCase=FALSE
      }
    }
#-------------------------------------------------------------------------------------------------------------------->
  if(i == 0 &file==file.from &frag==1){

   #Calculate the log likelihood function for the intercept only model

   #vids <- !is.na(ys[j,])
   yv <- ys[j, vids]

   X.int <- matrix(1,nrow(as.matrix(yv)),ncol(as.matrix(yv)))
   iX.intX.int <- solve(crossprod(X.int, X.int))
   iX.intY <- crossprod(X.int, as.matrix(as.matrix(yv)))
   beta.int <- crossprod(iX.intX.int, iX.intY)  #Note: we can use crossprod here becase iXX is symmetric
   X.int.beta.int <- X.int%*%beta.int




   #X.int <- matrix(1,nrow(as.matrix(ys[!is.na(ys)])),ncol(as.matrix(ys[!is.na(ys)])))
   #iX.intX.int <- solve(crossprod(X.int, X.int))
   #iX.intY <- crossprod(X.int, as.matrix(ys[!is.na(ys)]))
   #beta.int <- crossprod(iX.intX.int, iX.intY)  #Note: we can use crossprod here becase iXX is symmetric
   #X.int.beta.int <- X.int%*%beta.int

   logL0 <- 0.5*((-length(yv))*log(((2*pi)/length(yv))
                 *crossprod((yv-X.int.beta.int),(yv-X.int.beta.int)))
                  -length(yv))


   #logL0 <- 0.5*((-nrow(as.matrix(ys[!is.na(ys)])))*log(((2*pi)/nrow(ys))
   # *crossprod(((as.matrix(ys[!is.na(ys)]))-X.int.beta.int),((as.matrix(ys[!is.na(ys)]))-X.int.beta.int)))
   # -nrow(as.matrix(ys[!is.na(ys)])))

    #print(paste("The value of logL0 inside of the calculating SNPs loop is", logL0, sep = ""))
   }

    #Normal case
    if(normalCase)
    {

#--------------------------------------------------------------------------------------------------------------------<
      #nv <- sum(vids)
      yv <- ys[j, vids] #### Feng changed
      nr <- sum(vids) #### Feng changed
      if(!is.null(Z) & !is.null(K))
      {
        r<- ncol(Z) ####Feng, add a variable to indicate the number of random effect
        vran <- vids[1:r] ###Feng, add a variable to indicate random effects with nonmissing genotype
        tv <- sum(vran)  #### Feng changed
      }



#-------------------------------------------------------------------------------------------------------------------->

#--------------------------------------------------------------------------------------------------------------------<



      if(i >0 | file>file.from|frag>1) dfs[i, j] <- nr - q1
    	if(i >0 | file>file.from|frag>1){ 
        if(!Create.indicator) X <- cbind(X0[vids, , drop = FALSE], xs[vids,i])
        if(Create.indicator){
          X <- cbind(X0[vids, , drop = FALSE], xv)
          #if(i == 1) {print("the head of X for running GWAS is")}
          #if(i == 1) {print(head(X))}
        }       
        
      } 
       #Recalculate eig and REML if not using P3D  NOTE THIS USED TO BE BEFORE the two solid lines
      if(SNP.P3D==FALSE & !is.null(K))
      {
        if(!is.null(Z)) eig.R <- emma.eigen.R.w.Z(Z, K, X) #This will be used to get REstricted ML (REML)
        if(is.null(Z)) eig.R <- emma.eigen.R.wo.Z( K, X) #This will be used to get REstricted ML (REML)
        if(!is.null(Z)) REMLE <- GAPIT.emma.REMLE(ys[j,], X, K, Z, ngrids, llim, ulim, esp, eig.R)
        if(is.null(Z)) REMLE <- GAPIT.emma.REMLE(ys[j,], X, K, Z = NULL, ngrids, llim, ulim, esp, eig.R)
        if(!is.null(Z) & !is.null(K)) U <- eig.L$vectors * matrix(c(sqrt(1/(eig.L$values + REMLE$delta)),rep(sqrt(1/REMLE$delta),nr - tv)),nr,((nr-tv)+length(eig.L$values)),byrow=TRUE)
        if(is.null(Z) & !is.null(K)) U <- eig.L$vectors * matrix( sqrt(1/(eig.L$values + REMLE$delta)),nr,length(eig.L$values),byrow=TRUE)

        vgs <- REMLE$vg
        ves <- REMLE$ve
        REMLs <- REMLE$REML
        REMLE_delta=REMLE$delta

      }

      if(n==nr)
      {
        if(!is.null(K))
        {
            yt <- crossprod(U, yv)
            if(i == 0 &file==file.from &frag==1){
             X0t <- crossprod(U, X0)
             Xt <- X0t
            }
            if(i > 0 | file>file.from |frag>1){
              #if(i ==1 & file==file.from&frag==1) Xt <- matrix(NA,nr, q1)
             
             if(Create.indicator){
                xst <- crossprod(U, X[,(q0+1):q1])
                Xt[1:nr,1:q0] <- X0t
                Xt[1:nr,(q0+1):q1] <- xst
               
             }
             
              #print(paste("i:",i,"q0:",q0,"q1:",q1,"nt:",nr,"XT row",nrow(Xt),"XT col",ncol(Xt),sep=" "))
             if(!Create.indicator){
                xst <- crossprod(U, X[,ncol(X)])
                Xt[1:nr,1:q0] <- X0t
                Xt[1:nr,q1] <- xst
             }
            }
        }else{
        yt=yv
        if(i == 0 &file==file.from &frag==1) X0t <- X0
        if(i > 0 | file>file.from |frag>1) xst <- X[,ncol(X)]
        }

        if(i == 0 &file==file.from &frag==1){
         X0X0 <- crossprod(X0t, X0t)
         #XX <- X0X0
        }
        if(i > 0 | file>file.from |frag>1){
         #if(i == 1)XX=matrix(NA,q1,q1)


         X0Xst <- crossprod(X0t,xst)
         XstX0 <- t(X0Xst)
         xstxst <- crossprod(xst, xst)
         # if(i == 1){
         # Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Calculate_X0Xst_XstX0_xstxst")
         # Memory=GAPIT.Memory(Memory=Memory,Infor="Calculate_X0Xst_XstX0_xstxst")
         # }
         #XX <- rbind(cbind(X0X0, X0Xst), cbind(XstX0, xstxst))

         #XX[1:q0,1:q0] <- X0X0
         #XX[q1,1:q0] <- X0Xst
         #XX[1:q0,q1] <- X0Xst
         #XX[q1,q1] <- xstxst


        }


        if(X0X0[1,1] == "NaN")
        {
          Xt[which(Xt=="NaN")]=0
          yt[which(yt=="NaN")]=0
          XX=crossprod(Xt, Xt)
        }
        if(i == 0 &file==file.from & frag==1){
         X0Y <- crossprod(X0t,yt)
         XY <- X0Y
        }
        if(i > 0 | file>file.from |frag>1){
         xsY <- crossprod(xst,yt)
         XY <- c(X0Y,xsY)
# if(i == 1){
# Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Calculate_xsY_X0Y")
# Memory=GAPIT.Memory(Memory=Memory,Infor="Calculate_xsY_X0Y")
# }
        }
        #XY = crossprod(Xt,yt)
      }

      #Missing SNP
      if(n>nr)
      {
       UU=crossprod(U,U)
       A11=UU[vids.TRUE,vids.TRUE]
       A12=UU[vids.TRUE,vids.FALSE]
       A21=UU[vids.FALSE,vids.TRUE]
       A22=UU[vids.FALSE,vids.FALSE]
       A22i =try(solve(A22),silent=TRUE )
       if(inherits(A22i, "try-error")) A22i <- ginv(A22)

       F11=A11-A12%*%A22i%*%A21
       XX=crossprod(X,F11)%*%X
       XY=crossprod(X,F11)%*%yv
      }
      if(i == 0 &file==file.from &frag==1){
       iX0X0 <- try(solve(X0X0),silent=TRUE)
       if(inherits(iX0X0, "try-error")){
         iX0X0 <- ginv(X0X0)
         print("At least two of your covariates are linearly dependent. Please reconsider the covariates you are using for GWAS and GPS")
       }
       iXX <- iX0X0
      }
      if(i > 0 | file>file.from |frag>1){

      #if(i ==1 &file==file.from &frag==1) iXX=matrix(NA,q1,q1)
        if(Create.indicator){
          B22 <- xstxst - XstX0%*%iX0X0%*%X0Xst
          invB22 <- solve(B22)
          B21 <- tcrossprod(XstX0, iX0X0)
          NeginvB22B21 <- crossprod(-invB22,B21)
          B11 <- iX0X0 + as.numeric(invB22)*crossprod(B21,B21)



          iXX[1:q0,1:q0]=B11
          iXX[(q0+1):q1,(q0+1):q1]=solve(B22)  
          iXX[(q0+1):q1,1:q0]=NeginvB22B21
          iXX[1:q0,(q0+1):q1]=t(NeginvB22B21)

        }

      
        if(!Create.indicator){
          B22 <- xstxst - XstX0%*%iX0X0%*%X0Xst
          invB22 <- 1/B22
          #B12 <- crossprod(iX0X0,X0Xst)
          B21 <- tcrossprod(XstX0, iX0X0)
          NeginvB22B21 <- crossprod(-invB22,B21)
          #B11 <- iX0X0 + B12%*%invB22%*%B21
          B11 <- iX0X0 + as.numeric(invB22)*crossprod(B21,B21)
          #iXX <- rbind(cbind(B11,t(NeginvB22B21)), cbind(NeginvB22B21,invB22))

          iXX[1:q0,1:q0]=B11
          iXX[q1,q1]=1/B22
          iXX[q1,1:q0]=NeginvB22B21
          iXX[1:q0,q1]=NeginvB22B21
          

        }
        #if(i == 1){
        # Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Calculate_iXX")
        # Memory=GAPIT.Memory(Memory=Memory,Infor="Calculate_iXX")
        #}

      }

      if(is.null(K)){
        iXX <- try(solve(crossprod(X,X)),silent=TRUE)
        if(inherits(iXX, "try-error"))iXX <- ginv(crossprod(X,X))
        XY = crossprod(X,yv)
      }

      #iXX <- try(solve(XX))
      #if(inherits(iXX, "try-error")) iXX <- ginv(crossprod(Xt, Xt))
      #print("The dimension if iXX is")
      #print(dim(iXX))
      #print("The length of XY is")
      #print(length(XY))
      
      beta <- crossprod(iXX,XY) #Note: we can use crossprod here becase iXX is symmetric
      #print("beta was estimated")

#-------------------------------------------------------------------------------------------------------------------->

       
#--------------------------------------------------------------------------------------------------------------------<
      if(i ==0 &file==file.from &frag==1 & !is.null(K))
      {
        Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="ReducedModel")
Memory=GAPIT.Memory(Memory=Memory,Infor="ReducdModel")

        #beta.cv=beta

        
        
        XtimesBetaHat <- X%*%beta

        YminusXtimesBetaHat <- ys[j,]- XtimesBetaHat
        vgK <- vgs*K
        Dt <- crossprod(U, YminusXtimesBetaHat)

        if(!is.null(Z)) Zt <- crossprod(U, Z)
        if(is.null(Z)) Zt <- t(U)

        if(X0X0[1,1] == "NaN")
        {
        Dt[which(Dt=="NaN")]=0
        Zt[which(Zt=="NaN")]=0
        }

        BLUP <- K %*% crossprod(Zt, Dt) #Using K instead of vgK because using H=V/Vg

#print("!!!!")
      #Clean up the BLUP starf to save memory
      Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="before Dt clean")
      Memory=GAPIT.Memory(Memory=Memory,Infor="before Dt clean")
      rm(Dt)
      gc()
      Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Dt clean")
      Memory=GAPIT.Memory(Memory=Memory,Infor="Dt clean")





        grand.mean.vector <- rep(beta[1], length(BLUP))
        BLUP_Plus_Mean <- grand.mean.vector + BLUP
    	  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="BLUP")
        Memory=GAPIT.Memory(Memory=Memory,Infor="BLUP")

        #PEV
        C11=try(vgs*solve(crossprod(Xt,Xt)),silent=TRUE)
        if(inherits(C11, "try-error")) C11=vgs*ginv(crossprod(Xt,Xt))

        C21=-K%*%crossprod(Zt,Xt)%*%C11
		Kinv=try(solve(K)  ,silent=TRUE  ) 
        if(inherits(Kinv, "try-error")) Kinv=ginv(K)
        
        if(!is.null(Z)) term.0=crossprod(Z,Z)/ves
        if(is.null(Z)) term.0=diag(1/ves,nrow(K))

        term.1=try(solve(term.0+Kinv/vgs ) ,silent=TRUE )
        if(inherits(term.1, "try-error")) term.1=ginv(term.0+Kinv/vgs )

        term.2=C21%*%crossprod(Xt,Zt)%*%K
        C22=(term.1-term.2 )
        PEV=as.matrix(diag(C22))
 #print(paste("The value of is.na(CVI) is", is.na(CVI),  sep = ""))
if(!is.na(CVI)){
		XCV=as.matrix(cbind(1,data.frame(CVI[,-1])))
	
		#CV.Inheritance specified
		beta.Inheritance=beta
		if(!is.null(CV.Inheritance)){
			XCV=XCV[,1:(1+CV.Inheritance)]
			beta.Inheritance=beta[1:(1+CV.Inheritance)]
		}
		#Interception only
		if(length(beta)==1)XCV=X
		
        BLUE=try(XCV%*%beta.Inheritance,silent=TRUE)
        if(inherits(BLUE, "try-error")) BLUE = NA
     #print("GAPIT just after BLUE")
     Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PEV")
        Memory=GAPIT.Memory(Memory=Memory,Infor="PEV")

      }#end of if(i ==0&file==file.from   & !is.null(K))
 if(is.na(CVI)) BLUE = NA
}#end if(!is.na(CVI))
#-------------------------------------------------------------------------------------------------------------------->

#--------------------------------------------------------------------------------------------------------------------<
      if(i ==0 &file==file.from &frag==1 & is.null(K))
      {
        YY=crossprod(yt, yt)
        ves=(YY-crossprod(beta,XY))/(n-q0)
        r=yt-X%*%iXX%*%XY
        REMLs=-.5*(n-q0)*log(det(ves)) -.5*n -.5*(n-q0)*log(2*pi)
# REMLs=-.5*n*log(det(ves)) -.5*log(det(iXX)/ves) -.5*crossprod(r,r)/ves -.5*(n-q0)*log(2*pi)
        vgs = 0
        BLUP = 0
        BLUP_Plus_Mean = NaN
        PEV = ves
        #print(paste("X row:",nrow(X)," col:",ncol(X)," beta:",length(beta),sep=""))
XCV=as.matrix(cbind(1,data.frame(CVI[,-1])))

#CV.Inheritance specified
beta.Inheritance=beta
if(!is.null(CV.Inheritance)){
XCV=XCV[,1:(1+CV.Inheritance)]
beta.Inheritance=beta[1:(1+CV.Inheritance)]
}
#Interception only
if(length(beta)==1)XCV=X


        #BLUE=XCV%*%beta.Inheritance   modified by jiabo wang 2016.11.21
        BLUE=try(XCV%*%beta.Inheritance,silent=TRUE)
        if(inherits(BLUE, "try-error")) BLUE = NA

      }


#Clean up the BLUP stuff to save memory
if(i ==0 &file==file.from &frag==1 & !is.null(K))
{
     Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="K normal")
        Memory=GAPIT.Memory(Memory=Memory,Infor="K normal")
if(SNP.P3D == TRUE) K=1  #NOTE: When SNP.P3D == FALSE, this line will mess up the spectral decomposition of the kinship matrix at each SNP.
rm(Dt)
rm(Zt)            
rm(Kinv)
rm(C11)
rm(C21)
rm(C22)

gc()
     Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="K set to 1")
        Memory=GAPIT.Memory(Memory=Memory,Infor="K set to 1")
}

      if(i == 0 &file==file.from & frag==1){
      beta.cv=beta
      X.beta <- X%*%beta

      if(!is.null(K)){
              U.times.yv.minus.X.beta <- crossprod(U,(yv-X.beta))
              logLM_Base <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta))
                    - sum(log(eig.full.plus.delta)) - length(yv))

      }
      if(is.null(K)){
              U.times.yv.minus.X.beta <- yv-X.beta
              logLM_Base <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta)) - length(yv))
      }
      rsquare_base_intitialized <- 1-exp(-(2/length(yv))*(logLM_Base-logL0))

      }


      #print(Create.indicator)
      #calculate t statistics and P-values
      if(i > 0 | file>file.from |frag>1)
      {
       if(!Create.indicator){
        #if(i<5)print(beta[q1])
        #if(i<5)print(iXX[q1, q1])
        if(!is.null(K)) stats[i, j] <- beta[q1]/sqrt(iXX[q1, q1] *vgs) 
        if(is.null(K)) stats[i, j] <- beta[q1]/sqrt(iXX[q1, q1] *ves)
        effect.est[i, ] <- beta[q1]
        ps[i, ] <- 2 * pt(abs(stats[i, ]), dfs[i, ],lower.tail = FALSE)
        if(is.na(ps[i,]))ps[i,]=1
        #print(c(i,ps[i,],stats[i,],beta[q1],iXX[q1, q1]))
       } 
       if(Create.indicator){
       
        F.num.first.two <- crossprod(beta[(q0+1):q1], solve(iXX[(q0+1):q1,(q0+1):q1]))
        if(!is.null(K)) stats[i, j] <- (F.num.first.two %*% beta[(q0+1):q1])/(length((q0+1):q1)*vgs)
        if(is.null(K)) stats[i, j] <- (F.num.first.two %*% beta[(q0+1):q1])/(length((q0+1):q1)*ves)
        effect.est <- rbind(effect.est, cbind(rep(i,length((q0+1):q1)), indicator$unique.SNPs, beta[(q0+1):q1])) #Replace with rbind
        ps[i, ] <- pf(stats[i, j], df1=length((q0+1):q1), df2=(nr-ncol(X)), lower.tail = FALSE) #Alex, are these denominator degrees of freedom correct?
        dfs[i,] <- nr-nrow(X)
        
       }
              #Calculate the maximum full likelihood function value and the r square

      X.beta <- X%*%beta
      if(!is.null(K)){
          U.times.yv.minus.X.beta <- crossprod(U,(yv-X.beta))
          logLM <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta))
                       - sum(log(eig.full.plus.delta))- length(yv))
      }
      if(is.null(K)){
            U.times.yv.minus.X.beta <- yv-X.beta
            logLM <- 0.5*(-length(yv)*log(((2*pi)/length(yv))*crossprod(U.times.yv.minus.X.beta,U.times.yv.minus.X.beta)) - length(yv))
      }

      rsquare_base[i, ] <- rsquare_base_intitialized
      rsquare[i, ] <- 1-exp(-(2/length(yv))*(logLM-logL0))

                  #Calculate df, t value and standard error _xiaolei changed
                  df[i,] <- dfs[i,]

                  tvalue[i,] <- stats[i, j]
                  stderr[i,] <- beta[ncol(CVI)+1]/stats[i, j]
                  #stderr[i,] <- sqrt(vgs)
                  # modified by Jiabo at 20191115
      }
      #print("!!!!!!!!!!!!!!!")
      #print(Create.indicator)
#-------------------------------------------------------------------------------------------------------------------->

    } # End of if(normalCase)
    x.prev=xv #update SNP

} # End of loop on SNPs

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Screening SNPs")
Memory=GAPIT.Memory(Memory=Memory,Infor="Screening SNPs")
# print(head(tvalue))
# print(head(stderr))
# print(head(effect.est))
#output p value for the genotype file
if(!fullGD)
{ 
  #print("!!!!!!!!!!")
  #print(dim(GI))
  write.table(GI, paste("GAPIT.TMP.GI.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = TRUE)
  write.table(ps, paste("GAPIT.TMP.ps.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(maf, paste("GAPIT.TMP.maf.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(nobs, paste("GAPIT.TMP.nobs.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(rsquare_base, paste("GAPIT.TMP.rsquare.base.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(rsquare, paste("GAPIT.TMP.rsquare.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(df, paste("GAPIT.TMP.df.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(tvalue, paste("GAPIT.TMP.tvalue.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(stderr, paste("GAPIT.TMP.stderr.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
  write.table(effect.est, paste("GAPIT.TMP.effect.est.",name.of.trait,file,".",frag,".txt",sep=""), quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
 
  #rm(dfs,stats,ps,nobs,maf,GI)   #This cause problem on return
  #gc()
}
 
    frag=frag+1   #Progress to next fragment

} #end of if(!is.null(X))

} #end of repeat on fragment



} # Ebd of loop on file
} # End of loop on traits

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS done for this Trait")
Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS done for this Trait")
#print("GAPIT.EMMAxP3D accomplished successfully!")

    return(list(ps = ps, REMLs = -2*REMLs, stats = stats, effect.est = effect.est, rsquare_base = rsquare_base, rsquare = rsquare, dfs = dfs, df = df, tvalue = tvalue, stderr = stderr,maf=maf,nobs = nobs,Timmer=Timmer,Memory=Memory,
        vgs = vgs, ves = ves, BLUP = BLUP, BLUP_Plus_Mean = BLUP_Plus_Mean,
        PEV = PEV, BLUE=BLUE, logLM = logLM,effect.snp=effect.est,effect.cv=beta.cv))

}#end of GAPIT.EMMAxP3D function
#=============================================================================================
`GAPIT.FDR.TypeI` <-
function(WS=c(1e0,1e3,1e4,1e5), GM=NULL,seqQTN=NULL,GWAS=NULL,maxOut=100,MaxBP=1e10){
    #Object: To evaluate power and FDR for the top (maxOut) positive interval defined by WS
    #Input: WS- window size
    #Input: GM - m by 3  matrix for SNP name, chromosome and BP
    #Input: seqQTN - s by 1 vecter for index of QTN on GM (+1 for GDP column wise)
    #Input: GWAS - SNP,CHR,BP,P,MAF
    #maxOut: maximum number of rows to report
    #Requirement: None
    #Output: Table and Plots
    #Authors: Xiaolei Liu & Zhiwu Zhang
    # Date  start: April 2, 2013
    # Last update: Mar 16, 2016
    ##############################################################################################
    #print("GAPIT.Power Started")
    if(is.null(seqQTN) | is.null(GM)) return(list(Power=NULL,FDR= NULL,TypeI= NULL,False= NULL,AUC.FDR= NULL,AUC.T1= NULL))
    
    #store number fdr and t1 records
    NQTN=length(seqQTN)
    table=array(NA,dim=c(NQTN,2*length(WS)))
    fdrtable=array(NA,dim=c(NQTN,2*length(WS)))
    t1table=array(NA,dim=c(NQTN,2*length(WS)))
    cutoff=array(NA,dim=c(length(WS),NQTN))
    cut=array(NA,dim=c(1,NQTN))
    #-----------------FDR and Power analysis-------------------------
    #Information needed: GWAS,myGM and QTN(r)
    GWAS=GWAS[order(GWAS[,2],GWAS[,3]),]
    GWAS[is.na(GWAS[,4]),4]=1
    QTN.list=sort(GWAS[seqQTN,4])
    powerlist=seq(1/length(QTN.list),1,length.out=length(QTN.list))
    #calculate number of false positives in each WS
    total.index=1:nrow(GM)
    
    theWS=1
    for (theWS in 1:length(WS)){
        wsws=WS[theWS]
        qtn.pool=ceiling((as.numeric(GWAS[seqQTN,2])*MaxBP+as.numeric(GWAS[seqQTN,3]))/(2*wsws))
        bonf.pool=ceiling((GWAS[total.index,2]*MaxBP+GWAS[total.index,3])/(2*wsws))
        false.number=length(levels(factor(bonf.pool[!(bonf.pool%in%qtn.pool)])))
        for(j in 1:length(qtn.pool)){
            pbin=min(GWAS[bonf.pool==qtn.pool[j],4])
            cut[,j]=pbin
        }
        if(theWS==1){
            totalfalse=false.number
        }else{
            totalfalse=c(totalfalse,false.number)
        }
        cutoff[theWS,]=sort(cut)
    }
    #Calculate FDR and T1
    for(j in 1:ncol(cutoff)){
        theWS=1
        for (theWS in 1:length(WS)){
            p.index=which(GWAS[,4]<=cutoff[theWS,j])
            wsws=WS[theWS]
            qtn.pool=ceiling((GWAS[seqQTN,2]*MaxBP+GWAS[seqQTN,3])/(2*wsws))
            bonf.pool=ceiling((GWAS[p.index,2]*MaxBP+GWAS[p.index,3])/(2*wsws))
            qtn.number=length(levels(factor(bonf.pool[bonf.pool%in%qtn.pool])))
            false.number=length(levels(factor(bonf.pool[!(bonf.pool%in%qtn.pool)])))
            if(theWS==1){
                final=false.number
                final.fdr=false.number/(qtn.number+false.number)
                final.t1=false.number/totalfalse[theWS]
            }else{
                record=false.number
                record.fdr=false.number/(qtn.number+false.number)
                record.t1=false.number/totalfalse[theWS]
                final=c(final,record)
                final.fdr=c(final.fdr,record.fdr)
                final.t1=c(final.t1,record.t1)
            }
        }
        #record FDR and T1
        if(j==1){
            number.record=final
            fdr.record=final.fdr
            t1.record=final.t1
        }else{
            number.record=rbind(number.record,final)
            fdr.record=rbind(fdr.record,final.fdr)
            t1.record=rbind(t1.record,final.t1)
        }
        
    }
    
    table=number.record
    fdrtable=fdr.record
    t1table=t1.record
    #AUC
    auc.final.fdr=NULL
    auc.final.t1=NULL
    for (theWS in 1:length(WS)){
        auc.fdr=GAPIT.AUC(beta=powerlist,alpha=fdrtable[,theWS])
        auc.t1=GAPIT.AUC(beta=powerlist,alpha=t1table[,theWS])
        auc.final.fdr=c(auc.final.fdr,auc.fdr)
        auc.final.t1=c(auc.final.t1,auc.t1)
    }
    return(list(P=cutoff,Power=powerlist,FDR=fdrtable,TypeI=t1table,False=table,AUC.FDR=auc.final.fdr,AUC.T1=auc.final.t1))
    
}#end of `GAPIT.FDR.TypeI`
#=============================================================================================



`FarmCPU.0000` <-
function(){
    #################################################################
    #FarmCPU: Fixed and random model Circuitous Probability Unification
    #This is an R package to perform GWAS and genome prediction
    #Designed by Zhiwu Zhang
    #Writen by Xiaolei Liu and Zhiwu Zhang
    #Thanks for Aaron Kusmec pointing out the bug in 'FarmCPU.Burger' function
    FarmCPU.Version="FarmCPU v1.02, Dec 21, 2016"
    return(FarmCPU.Version)
}
`FarmCPU.BIN` <-
function(Y=NULL,GDP=NULL,GM=NULL,CV=NULL,P=NULL,orientation="col",method="random",b=c(5e5,5e6,5e7),s=seq(10,100,10),theLoop=NULL,bound=NULL){
    #Input: Y - n by 2 matrix with fist column as taxa name and second as trait
    #Input: GDP - n by m+1 matrix. The first colum is taxa name. The rest are m genotype
    #Input: GM - m by 3  matrix for SNP name, chromosome and BP
    #Input: CV - n by t matrix for t covariate variables.
    #Input: P - m by 1 matrix containing probability
    #Input: method - options are "static", "optimum", and "integral"
    #Input: b - vecter of length>=1 for bin size
    #Input: s - vecter of length>=1 for size of complexity (number of QTNs)
    #Requirement: Y, GDP and CV have same taxa order. GDP and GM have the same order on SNP
    #Requirement: P and GM are in the same order
    #Requirement: No missing data
    #Output: bin - n by s matrix of genotype
    #Output: binmap - s by 3 matrix for map of bin
    #Output: seqQTN - s by 1 vecter for index of QTN on GM (+1 for GDP column wise)
    #Relationship: bin=GDP[,c(seqQTN)], binmap=GM[seqQTN,]
    #Authors: Zhiwu Zhang
    # Last update: Febuary 28, 2013
    ##############################################################################
    #print("FarmCPU.BIN Started")
    
    #print("bin size")
    #print(b)
    #print("bin selection")
    #print(s)
    
    #print("method specified:")
    #print(method)
    if(is.null(P)) return(list(bin=NULL,binmap=NULL,seqQTN=NULL))
    
    #Set upper bound for bin selection to squareroot of sample size
    
    n=nrow(Y)
    #bound=round(sqrt(n)/log10(n))
    if(is.null(bound)){
        bound=round(sqrt(n)/sqrt(log10(n)))
    }
    #bound=round(sqrt(n))
    #bound=round(n/log10(n))
    #bound=n-1
    s[s>bound]=bound
    s=unique(s[s<=bound]) #keep the within bound
    
    #print("number of bins allowed")
    #print(s)
    
    optimumable=(length(b)*length(s)>1)
    if(!optimumable & method=="optimum"){
        #print("Warning: method was changed from optimum to static")
        method="static"
    }
    
    #print("method actually used:")
    #print(method)
    
    #Method of random
    #if(method=="random") seqQTN=sample(nrow(GM),s) #this is for test only
    #Method of static
    if(method=="static"){
        #print("Via static")
        if(theLoop==2){
            b=b[3]
        }else if(theLoop==3){
            b=b[2]
        }else{
            b=b[1]
        }
        s=bound
        #b=median(b)
        #s=median(s)
        s[s>bound]=bound
        #print("Bin : bin.size, bin.selection")
        #print(c(b,s))
        print("optimizing possible QTNs...")
        GP=cbind(GM,P,NA,NA,NA)
        mySpecify=GAPIT.Specify(GI=GM,GP=GP,bin.size=b,inclosure.size=s)
        seqQTN=which(mySpecify$index==TRUE)
        #print("Bin set through static")
    }
    #Method of optimum
    #============================optimum start============================================
    if(method=="optimum"&optimumable){
        #print("optimizing bins")
        #print("c(bin.size, bin.selection, -2LL, VG, VE)")
        print("optimizing possible QTNs...")
        count=0
        for (bin in b){
            for (inc in s){
                count=count+1
                GP=cbind(GM,P,NA,NA,NA)
                #print("debug in bin 000")
                
                #print("calling Specify")
                #print(date())
                
                mySpecify=GAPIT.Specify(GI=GM,GP=GP,bin.size=bin,inclosure.size=inc)
                
                #print("calling Specify done")
                #print(date())
                
                seqQTN=which(mySpecify$index==TRUE)
                #print("seqQTN")
                #print(seqQTN)
                if(orientation=="col"){
                    if(is.big.matrix(GDP)){
                        GK=deepcopy(GDP,cols=seqQTN)
                    }else{
                        GK=GDP[,seqQTN] #GK has the first as taxa in FarmCPU.Burger. But not get uesd.
                        #GK=GDP[,seqQTN]
                    }
                }else{
                    #if(is.big.matrix(GDP)){
                    #GK=deepcopy(GDP,rows=seqQTN)
                    #GK=t(GK)
                    #}else{
                    #GK=cbind(Y[,1],t(GDP[c(1,seqQTN),])) #GK has the first as taxa in FarmCPU.Burger. But not get uesd.
                    #some problem here
                    GK=t(GDP[seqQTN,])
                    #}
                }
                
                #print("GK")
                #print(GK)
                #print("calling Burger")
                #print(date())
                
                myBurger=FarmCPU.Burger(Y=Y[,1:2],CV=CV,GK=GK)
                
                #print("calling Burger done")
                #print(date())
                
                myREML=myBurger$REMLs
                myVG=myBurger$vg #it is unused
                myVE=myBurger$ve #it is unused
                
                #print("c(bin.size, bin.selection, -2LL, VG, VE)")
                print(c(bin,inc,myREML,myVG,myVE))
                #Recoding the optimum GK
                if(count==1){
                    seqQTN.save=seqQTN
                    LL.save=myREML
                    bin.save=bin
                    inc.save=inc
                    vg.save=myVG  # for genetic variance
                    ve.save=myVE  # for residual variance
                }else{
                    if(myREML<LL.save){
                        seqQTN.save=seqQTN
                        LL.save=myREML
                        bin.save=bin
                        inc.save=inc
                        vg.save=myVG  # for genetic variance
                        ve.save=myVE  # for residual variance
                    }
                } #end of if(count==1)
            }#loop on bin number
        }#loop on bin size
        seqQTN=seqQTN.save
        #ve.save=ve.save
        #vg.save=vg.save
        #print(seqQTN)
        #print("Bin optimized: -2LL, bin.size, bin.selection")
        #print(c(LL.save,bin.save,inc.save))
        #print(LL.save)
        #print("bin.save")
        #print(bin.save)
        #print("inc.save")
        #print(inc.save)
    }
    #============================end of optimum============================================
    
    bin=NULL
    binmap=NULL
    #The following are commented out as they will be finalized in Remove function
    #if(orientation=="col"){
    #  bin=GDP[,seqQTN]
    #}else{
    #  bin=t(GDP[seqQTN,] )
    #}
    #binmap=GM[seqQTN,]
    #print(length(seqQTN))
    
    #print("FarmCPU.Bin accomplished successfully!")
    return(list(bin=bin,binmap=binmap,seqQTN=seqQTN))
}#The function FarmCPU.BIN ends here
`FarmCPU.GLM` <-
function(Y=NULL,GDP=NULL,GM=NULL,CV=NULL,orientation="row",package="FarmCPU.LM",model="A",ncpus=1,seqQTN=NULL,npc=0){
    #Object: To perform GWAS with GLM model
    #Input: Y - n by 2 matrix with fist column as taxa name and second as trait
    #Input: GDP - n by m matrix. This is Genotype Data Pure (GDP). THERE IS NOT COLUMN FOR TAXA.
    #Input: GM - m by 3  matrix for SNP name, chromosome and BP
    #Input: CV - n by t matrix for t covariate variables.
    #Requirement: Y, GDP and CV have same taxa order. GDP and GM have the same order on SNP
    #Output: P - m by 4(t+1) matrix containing estimate, tvalue, stderr and pvalue for covariates and SNP
    #Authors: Xiaolei Liu and Zhiwu Zhang
    # Last update: may 9, 2012
    ##############################################################################
    if(is.null(Y)) return(NULL)  #Y is required
    if(is.null(GDP) & is.null(CV)) return(NULL)  #Need to have either genotype of CV
    #print("FarmCPU.GLM Started")
    #print("Dimention of Y, GDP, GM, and CV")
    #print(dim(Y))
    #print(dim(GDP))
    #print(dim(GM))
    #print(dim(CV))
    #print(head(CV))
    #print("Solving equation (This may take a while)...")
    if(!is.null(CV)){
        CV=as.matrix(CV)
        nf=ncol(CV)
    }else{
        nf=0
    }
    print("number of covariates in current loop is:")
    print(nf)
    #Build model with SNP as the last variable
    #if(package!="FarmCPU.LM"){
    if(is.null(CV)) {
        myModel="Y [,2]~x"
        if(package!="fast.lm"){
            ccv=rep(1,nrow(Y))
        }
    }else{
        #CV=as.matrix(CV)
        seqCV=1:(ncol(CV))
        myModel=paste("Y[,2]~",paste("CV[,",(seqCV),"]",collapse= "+"),"+ x")
        #print(head(CV))
        #ccv=cbind(rep(1,nrow(Y)),as.matrix(CV[,2:ncol(CV)]))
        if(package!="fast.lm"){
            ccv=cbind(rep(1,nrow(Y)),as.matrix(CV))
        }
        #ccv=as.matrix(CV)
        #print("ccv")
        #print(head(ccv))
    }
    #}
    ##print("The model is: ")
    ##print(myModel)
    #===========================by lm=======================================
    if(package=="lm"){
        #Solve the  model with lm
        #P <- apply(GDP,2,function(x){
        #fmla <- formula(myModel)
        #myLM=lm(fmla)
        #lms=summary(myLM)
        #lmcoef=lms$coefficients
        #lmcoefOnly=lmcoef[-1,]  #remove intercept
        ##print(lmcoefOnly)
        #(as.numeric(lmcoefOnly))
        #In order of estimate, t, se and P
        #cbind(lmcoefOnly[,1],lmcoefOnly[,3],lmcoefOnly[,2],lmcoefOnly[,4])
        #})
        
        P<-matrix(NA,nr=nrow(GDP),nc=4*(nf+1))
        for(i in 1:nrow(GDP)){
            x <- GDP[i,]
            fmla <- formula(myModel)
            myLM=lm(fmla)
            lms=summary(myLM)
            lmcoef=lms$coefficients
            lmcoefOnly=lmcoef[-1,]  #remove intercept
            ##print(lmcoefOnly)
            #(as.numeric(lmcoefOnly))
            #In order of estimate, t, se and P
            #P[i,]=cbind(lmcoefOnly[,1],lmcoefOnly[,3],lmcoefOnly[,2],lmcoefOnly[,4])
            #P[i,1]=lmcoefOnly[1]
            #P[i,2]=lmcoefOnly[3]
            #P[i,3]=lmcoefOnly[2]
            #P[i,4]=lmcoefOnly[4]
            #print(lmcoefOnly)
            
            P[i,c(1:(nf+1))]=lmcoefOnly[1:(nf+1)]
            P[i,c((nf+2):(2*nf+2))]=lmcoefOnly[(2*nf+3):(3*nf+3)]
            P[i,c((2*nf+3):(3*nf+3))]=lmcoefOnly[(nf+2):(2*nf+2)]
            P[i,c((3*nf+4):(4*nf+4))]=lmcoefOnly[(3*nf+4):(4*nf+4)]
            
            #P[i,c(1:(nf+1))]=lmcoefOnly[1]
            #P[i,c((nf+2):(2*nf+2))]=lmcoefOnly[3]
            #P[i,c((2*nf+3):(3*nf+3))]=lmcoefOnly[2]
            #P[i,c((3*nf+4):(4*nf+4))]=lmcoefOnly[4]
            
            
        }
        #print(head(P))
        #convert list to numeric matrix
        #P=t(sapply(P, function(row, max_length) c(row, rep(NA, max_length - length(row))), max(sapply(P, length))))
        #the following two do not work
        #P=as.data.frame(do.call(rbind, P))
        #P=t(as.matrix(P))
        P0=NULL
        pred=NULL
        PF=P[,ncol(P)]
        myLM=list(P=P,P0=P0,PF=PF,Pred=pred)
    } #end of lm if statement
    #===========================by fast.lm=======================================
    if(package=="fast.lm"){
        #fast.lm does not all?ow missing values
        missing=is.na(Y[,2]) #index for missing phenotype
        Mtotal=ncol(GDP)
        Ym=Y[missing,]
        Y=Y[!missing,]
        ccv=ccv[!missing,]
        GDP=GDP[!missing,]
        
        #set index for markers with no variation
        varSNP=apply(GDP,2,var)
        indexSNP=which(varSNP!=0)
        
        P0 <- apply(GDP[,indexSNP],2,function(x){
            x = cbind(ccv,x)
            fast.lm=fastLmPure(y=Y[,2],X = x)
            tvalue=fast.lm$coefficients[-1]/fast.lm$stderr[-1]
            pvalue=2*pt(abs(tvalue),fast.lm$df.residual,lower.tail = FALSE)
            cbind(fast.lm$coefficients[-1],tvalue,fast.lm$stderr[-1],pvalue)
        })
        
        #convert list to numeric matrix, the last (t+1) columns are p values for SNPs
        P0=t(as.matrix(P0))
        #Restore in original oder
        mtotal=ncol(GDP)
        nfix=ncol(P0)
        P=matrix(NA,Mtotal,nfix)
        rownames(P)=colnames(GDP)  #This should be OK
        P[indexSNP,]=P0 #restore the order with markers without variation
        P0=NULL
        pred=NULL
        PF=P[,ncol(P)]
        myLM=list(P=P,P0=P0,PF=PF,Pred=pred)
    }# end of fast.lm if statement
    #===========================by FarmCPU.LM=======================================
    if(package=="FarmCPU.LM"){
        #print("Calling GLM")
        #print(date())
        #print("Memory used before calling LM")
        #print(memory.size())
        gc()
        theCV=NULL
        if(!is.null(CV)) {
            theCV=as.matrix(CV)#as.matrix(CV[,-1])#
            seqCV=1:(ncol(theCV))
            myModel=paste("y~",paste("w[,",(seqCV),"]",collapse= "+"),"+ x")
        }
        #print("theCV")
        #print(head(theCV))
        if(ncpus==1)myLM=FarmCPU.LM(y=Y[,2],w=theCV,GDP=GDP,orientation=orientation,model=model,ncpus=ncpus,myModel=myModel,seqQTN=seqQTN,npc=npc)
        if(ncpus>1)myLM=FarmCPU.LM.Parallel(y=Y[,2],w=theCV,x=GDP,orientation=orientation,model=model,ncpus=ncpus,npc=npc)
        #print("Memory used after calling LM")
        #print(memory.size())
        gc()
        
    }# end of FarmCPU.lm if statement
    
    #print("FarmCPU.GLM accoplished")
    #print(date())
    gc()
    #return(list(P=myLM$P,P0=myLM$P0,PF=myLM$PF,Pred=myLM$pred))
    return(myLM)
}#The function FarmCPU.GLM ends here
`FarmCPU.Inv` <- function(A){
    #Object: To invert a 2 by 2 matrix quickly
    #intput: A -  2 by 2 matrix
    #Output: Inverse
    #Authors: Zhiwu Zhang
    # Last update: March 6, 2013
    ##############################################################################################
    detA=A[1,1]*A[2,2]-A[1,2]*A[2,1]
    temp=A[1,1]
    A=-A
    A[1,1]=A[2,2]
    A[2,2]=T
    return(A/detA)
}#The function FarmCPU.Inv ends here
`FarmCPU.LM.Parallel` <-
function(y,w=NULL,x,orientation="col",model="A",ncpus=2){
    #Object: 1. To quickly sovel LM with one variable substitute multiple times
    #Object: 2. To fit additive and additive+dominace model
    #intput: y - dependent variable
    #intput: w - independent variable
    #intput: x - independent variable of substitution (GDP)
    #intput: model - genetic effects. Options are "A" and "AD"
    #Output: estimate, tvalue, stderr and pvalue ( plus the P value of F test on both A and D)
    #Straitegy: 1. Separate constant covariates (w) and dynamic coveriates (x)
    #Straitegy: 2. Build non-x related only once
    #Straitegy: 3. Use apply to iterate x
    #Straitegy: 4. Derive dominance indicate d from additive indicate (x) mathmaticaly
    #Straitegy: 5. When d is not estimable, continue to test x
    #Authors: Xiaolei Liu and Zhiwu Zhang
    #Start  date: March 1, 2013
    #Last update: March 6, 2013
    ##############################################################################################
    print("FarmCPU.LM started")
    print(date())
    print(paste("No. Obs: ",length(y),sep=""))
    print("diminsion of covariates and markers")
    if(!is.null(w))print(dim(w))
    
    print("Memory used at begining of LM")
    print(memory.size())
    gc()
    #Constant section (non individual marker specific)
    #---------------------------------------------------------
    #Configration
    nd=20 #number of markes for checking A and D dependency
    threshold=.99 # not solving d if correlation between a and d is above this
    N=length(y) #Total number of taxa, including missing ones
    direction=2
    if(orientation=="row")direction=1
    print("direction")
    print(direction)
    #Handler of non numerical y a and w
    
    if(!is.null(w)){
        nf=length(w)/N
        w=matrix(as.numeric(as.matrix(w)),N,nf  )
        w=cbind(rep(1,N),w)#add overall mean indicator
        q0=ncol(w) #Number of fixed effect excluding gnetic effects
    }else{
        w=rep(1,N)
        nf=0
        q0=1
    }
    
    y=matrix(as.numeric(as.matrix(y)),N,1  )
    
    print("Adding overall mean")
    print(date())
    
    print("Build the static section")
    print(date())
    
    #n=nrow(w) #number of taxa without missing
    n=N
    if(nd>n)nd=n #handler of samples less than nd
    k=1 #number of genetic effect: 1 and 2 for A and AD respectively
    if(model=="AD")k=2
    
    q1=(q0+1) # vecter index for the posistion of genetic effect (a)
    q2=(q0+1):(q0+2) # vecter index for the posistion of genetic effect (a and d)
    df=n-q0-k #residual df (this should be varied based on validating d)
    
    iXX=matrix(0,q0+k,q0+k) #Reserve the maximum size of inverse of LHS
    #theNA=c(rep(NA,q0),rep(0,k)) # this should not be useful anymore
    
    ww=crossprod(w,w)
    wy=crossprod(w,y)
    yy=crossprod(y,y)
    wwi=solve(ww)
    
    print("Prediction")
    print(date())
    
    #Statistics on the reduced model without marker
    rhs=wy
    beta <- crossprod(wwi,rhs)
    ve=(yy-crossprod(beta,rhs))/df
    se=sqrt(diag(wwi)*ve)
    tvalue=beta/se
    pvalue <- 2 * pt(abs(tvalue), df,lower.tail = FALSE)
    P0=c(beta[-1],tvalue[-1],se[-1],pvalue[-1])
    yp=w%*%beta
    
    print("Detecting genotype coding system")
    print(date())
    
    #Finding the middle of genotype coding (1 for 0/1/2 and 0 for -1/0/1)
    s=5 # number of taxa sampled
    t0=which(x[1:s,]<0)
    t1=which(x[1:s,]>1)
    middle=0
    if(length(t0)<length(t1)) middle=1
    
    print("Memory used after setting LM")
    print(memory.size())
    gc()
    #Dynamic section on individual marker
    print("Iterating.................")
    print(date())
    print("dimension of GD")
    print(dim(x))
    print(is(x))
    
    #sfInit(parallel=ncpus>1, cpus=ncpus)
    #print(sprintf('%s cpus are used', sfCpus()))
    
    #---------------------------------------------------------
    #P <- apply(x,direction,function(x){
    P <- sfApply(x,direction,function(x){
        print("debug sfApply")
        r=1 #initial creteria for correlation between a and d
        if(model=="AD"){
            d=1-abs(x-middle)
            r=abs(cor(x[1:nd],d[1:nd]))
            if(is.na(r))r=1
            if(r<=threshold) x=cbind(x,d) # having both a and d as marker effects
        }
        print("make some noise here")
        #Process the edge (marker effects)
        xw=crossprod(w,x)
        xy=crossprod(x,y)
        xx=crossprod(x,x)
        
        B21 <- crossprod(xw, wwi)
        #t1=crossprod(xw,wwi)
        t2=B21%*%xw #I have problem of using crossprod and tcrossprod here
        B22 <- xx - t2
        
        #B22 can a scaler (A model) or 2 by2 matrix (AD model)
        if(model=="AD"&r<=threshold){
            invB22 <- FarmCPU.Inv(B22)
        }else{
            invB22=1/B22
        }
        
        NeginvB22B21 <- crossprod(-invB22,B21)
        
        if(model=="AD"&r<=threshold){
            B11 <- wwi + crossprod(B21,B21)
        }else{
            B11 <- wwi + as.numeric(invB22)*crossprod(B21,B21)
        }
        
        #Derive inverse of LHS with partationed matrix
        iXX[1:q0,1:q0]=B11
        
        if(r>threshold){
            iXX[q1,q1]=invB22
            iXX[q1,1:q0]=NeginvB22B21
            iXX[1:q0,q1]=NeginvB22B21
        }else{
            iXX[q2,q2]=invB22
            iXX[q2,1:q0]=NeginvB22B21
            iXX[1:q0,q2]=NeginvB22B21
        }
        
        #statistics
        rhs=c(wy,xy) #the size varied automaticly by A/AD model and validated d
        
        if(abs(r)>threshold & model=="AD"){
            beta <- crossprod(iXX[-(q0+k),-(q0+k)],rhs) #the last one (d) dose not count
            df=n-q0-1
        }else{
            beta <- crossprod(iXX,rhs)   #both a and d go in
            df=n-q0-2
        }
        if(model=="A") df=n-q0-1 #change it back for model A
        
        ve=(yy-crossprod(beta,rhs))/df #this is a scaler
        
        #using iXX in the same as above to derive se
        if(abs(r)>threshold & model=="AD"){
            se=sqrt(diag(iXX[-(q0+k),-(q0+k)])*ve)
        }else{
            se=sqrt(diag(iXX)*ve)
        }
        
        tvalue=beta/se
        pvalue <- 2 * pt(abs(tvalue), df,lower.tail = FALSE)
        
        #Handler of dependency between  marker are covariate
        #if(abs(B22[1,1])<10e-8)pvalue[]=NA
        
        #Calculate P value for A+D effect
        if(model=="AD"){
            #the last bit could be d or a, the second last may be marker effect not even not
            #In either case, calculate F and P value and correct them later
            markerbits=(length(beta)-1):length(beta)
            SSM=crossprod(beta[markerbits],rhs[markerbits])
            F=(SSM/2)/ve
            PF=df(F,2,df)
            
            #correcting PF with P from t value
            if(r>threshold) PF=pvalue[length(pvalue)]
        }
        
        #in case AD model and a/d dependent, add NA column at end
        if(r>threshold & model=="AD"){
            beta=c(beta,NA)
            tvalue=c(tvalue,NA)
            se=c(se,NA)
            pvalue=c(pvalue,NA)
        }
        
        if(model=="AD"){
            result=c(beta[-1],tvalue[-1],se[-1],pvalue[-1],PF)
        }else{
            result=c(beta[-1],tvalue[-1],se[-1],pvalue[-1])
        }
    }) #end of defyning apply function
    #sfStop()
    
    print("iteration accoplished")
    print(date())
    print("Memory used after iteration")
    print(memory.size())
    gc()
    
    #Final report
    #---------------------------------------------------------
    P=t(as.matrix(P))
    
    PF=P[,ncol(P)]
    if(model=="AD")P=P[,-ncol(P)]
    
    print("FarmCPU.LM accoplished")
    print(date())
    
    
    print("Memory used at end of LM")
    print(memory.size())
    gc()
    
    return(list(P=P,P0=P0,PF=PF,Pred=yp))
}
#)#end of cmpfun(
`FarmCPU.LM` <-
#cmpfun(
function(y,w=NULL,GDP,orientation="col",model="A",ncpus=2,myModel=NULL,seqQTN=NULL,npc=0){
    #Object: 1. To quickly sovel LM with one variable substitute multiple times
    #Object: 2. To fit additive and additive+dominace model
    #intput: y - dependent variable
    #intput: w - independent variable
    #intput: GDP - independent variable of substitution (GDP)
    #intput: model - genetic effects. Options are "A" and "AD"
    #Output: estimate, tvalue, stderr and pvalue ( plus the P value of F test on both A and D)
    #Straitegy: 1. Separate constant covariates (w) and dynamic coveriates (x)
    #Straitegy: 2. Build non-x related only once
    #Straitegy: 3. Use apply to iterate x
    #Straitegy: 4. Derive dominance indicate d from additive indicate (x) mathmaticaly
    #Straitegy: 5. When d is not estimable, continue to test x
    #Authors: Xiaolei Liu and Zhiwu Zhang
    #Start  date: March 1, 2013
    #Last update: March 6, 2013
    ##############################################################################################
    #print("FarmCPU.LM started")
    #print(date())
    #print(paste("No. Obs: ",length(y),sep=""))
    #print("diminsion of covariates and markers")
    if(!is.null(w))#print(dim(w))
    
    #print("Memory used at begining of LM")
    #print(memory.size())
    gc()
    #Constant section (non individual marker specific)
    #---------------------------------------------------------
    #Configration
    nd=20 #number of markes for checking A and D dependency
    threshold=.99 # not solving d if correlation between a and d is above this
    N=length(y) #Total number of taxa, including missing ones
    direction=2
    if(orientation=="row")direction=1
    #print("direction")
    #print(direction)
    #Handler of non numerical y a and w
    
    if(!is.null(w)){
        nf=length(w)/N
        w=matrix(as.numeric(as.matrix(w)),N,nf  )
        w=cbind(rep(1,N),w)#add overall mean indicator
        q0=ncol(w) #Number of fixed effect excluding gnetic effects
    }else{
        w=rep(1,N)
        nf=0
        q0=1
    }
    
    y=matrix(as.numeric(as.matrix(y)),N,1  )
    
    #print("Adding overall mean")
    #print(date())
    #print("Build the static section")
    #print(date())
    
    #n=nrow(w) #number of taxa without missing
    n=N
    if(nd>n)nd=n #handler of samples less than nd
    k=1 #number of genetic effect: 1 and 2 for A and AD respectively
    if(model=="AD")k=2
    
    q1=(q0+1) # vecter index for the posistion of genetic effect (a)
    q2=(q0+1):(q0+2) # vecter index for the posistion of genetic effect (a and d)
    df=n-q0-k #residual df (this should be varied based on validating d)
    
    iXX=matrix(0,q0+k,q0+k) #Reserve the maximum size of inverse of LHS
    #theNA=c(rep(NA,q0),rep(0,k)) # this should not be useful anymore
    
    ww=crossprod(w,w)
    wy=crossprod(w,y)
    yy=crossprod(y,y)
    wwi=solve(ww)
    
    #print("Prediction")
    #print(date())
    
    #Statistics on the reduced model without marker
    rhs=wy
    beta <- crossprod(wwi,rhs)
    ve=(yy-crossprod(beta,rhs))/df
    se=sqrt(diag(wwi)*ve)
    tvalue=beta/se
    pvalue <- 2 * pt(abs(tvalue), df,lower.tail = FALSE)
    P0=c(beta[-1],tvalue[-1],se[-1],pvalue[-1])
    yp=w%*%beta
    
    if(npc!=0){
        betapc = beta[2:(npc+1)]
        betapred = beta[-c(1:(npc+1))]
    }else{
        betapc = NULL
        betapred = beta[-1]
    }
    #print("Detecting genotype coding system")
    #print(date())
    
    #Finding the middle of genotype coding (1 for 0/1/2 and 0 for -1/0/1)
    s=5 # number of taxa sampled
    t0=which(GDP[1:s,]<0)
    t1=which(GDP[1:s,]>1)
    middle=0
    if(length(t0)<length(t1)) middle=1
    
    #print("Memory used after setting LM")
    #print(memory.size())
    gc()
    #Dynamic section on individual marker
    #print("Iterating.................")
    #print(date())
    #print("dimension of GD")
    #print(dim(x))
    #sfInit(parallel=ncpus>1, cpus=ncpus)
    ##print(sprintf('%s cpus are used', sfCpus()))
    
    #---------------------------------------------------------
    #P <- matrix(NA,nrow=nrow(GDP),ncol=4*(nf+1))
    if(orientation=="row"){
        P <- matrix(NA,nrow=nrow(GDP),ncol=nf+1)
        ntest=nrow(GDP)
    }else{
        P <- matrix(NA,nrow=ncol(GDP),ncol=nf+1)
        ntest=ncol(GDP)
    }
    
    if(orientation=="row"){
        B <- matrix(NA,nrow=nrow(GDP),ncol=1)
    }else{
        B <- matrix(NA,nrow=ncol(GDP),ncol=1)
    }
    
    for(i in 1:ntest){
        if(orientation=="row"){
            x=GDP[i,]
        }else{
            x=GDP[,i]
        }
        
        #P <- apply(x,direction,function(x){
        #P <- sfApply(x,direction,function(x){
        r=1 #initial creteria for correlation between a and d
        if(model=="AD"){
            d=1-abs(x-middle)
            r=abs(cor(x[1:nd],d[1:nd]))
            if(is.na(r))r=1
            if(r<=threshold) x=cbind(x,d) # having both a and d as marker effects
        }
        
        #Process the edge (marker effects)
        xy=crossprod(x,y)
        xx=crossprod(x,x)
        
        if(model=="AD"&r<=threshold){
            xw=crossprod(x,w)
            wx=crossprod(w,x)
            iXX22 <- solve(xx-xw%*%wwi%*%wx)
            iXX12 <- (-wwi)%*%wx%*%iXX22
            iXX21 <- (-iXX22)%*%xw%*%wwi
            iXX11 <- wwi + wwi%*%wx%*%iXX22%*%xw%*%wwi
        }else{
            xw=crossprod(w,x)
            B21 <- crossprod(xw, wwi)
            t2=B21%*%xw #I have problem of using crossprod and tcrossprod here
            B22 <- xx - t2
            invB22=1/B22
            NeginvB22B21 <- crossprod(-invB22,B21)
            iXX11 <- wwi + as.numeric(invB22)*crossprod(B21,B21)
        }
        
        #Derive inverse of LHS with partationed matrix
        iXX[1:q0,1:q0]=iXX11
        
        if(r>threshold){
            iXX[q1,q1]=invB22
            iXX[q1,1:q0]=NeginvB22B21
            iXX[1:q0,q1]=NeginvB22B21
        }else{
            iXX[q2,q2]=iXX22
            iXX[q2,1:q0]=iXX21
            iXX[1:q0,q2]=iXX12
        }
        
        #statistics
        rhs=c(wy,xy) #the size varied automaticly by A/AD model and validated d
        
        if(abs(r)>threshold & model=="AD"){
            beta <- crossprod(iXX[-(q0+k),-(q0+k)],rhs) #the last one (d) dose not count
            df=n-q0-1
        }else{
            beta <- crossprod(iXX,rhs)   #both a and d go in
            df=n-q0-2
        }
        if(model=="A") df=n-q0-1 #change it back for model A
        
        ve=(yy-crossprod(beta,rhs))/df #this is a scaler
        
        #using iXX in the same as above to derive se
        if(abs(r)>threshold & model=="AD"){
            se=sqrt(diag(iXX[-(q0+k),-(q0+k)])*ve)
        }else{
            se=sqrt(diag(iXX)*ve)
        }
        
        tvalue=beta/se
        pvalue <- 2 * pt(abs(tvalue), df,lower.tail = FALSE)
        
        #Handler of dependency between  marker are covariate
        if(!is.na(abs(B22[1,1]))){
            if(abs(B22[1,1])<10e-8)pvalue[]=NA}
        
        #Calculate P value for A+D effect
        if(model=="AD"){
            #the last bit could be d or a, the second last may be marker effect not even not
            #In either case, calculate F and P value and correct them later
            markerbits=(length(beta)-1):length(beta)
            SSM=crossprod(beta[markerbits],rhs[markerbits])
            F=(SSM/2)/ve
            PF=df(F,2,df)
            
            #correcting PF with P from t value
            if(r>threshold) PF=pvalue[length(pvalue)]
        }
        
        #in case AD model and a/d dependent, add NA column at end
        if(r>threshold & model=="AD"){
            beta=c(beta,NA)
            tvalue=c(tvalue,NA)
            se=c(se,NA)
            pvalue=c(pvalue,NA)
        }
        
        if(model=="AD"){
            result=c(beta[-1],tvalue[-1],se[-1],pvalue[-1],PF)
        }else{
            #result=c(beta[-1],tvalue[-1],se[-1],pvalue[-1])
            #P[i,]=c(beta[-1],tvalue[-1],se[-1],pvalue[-1])
            P[i,c(1:(nf+1))]=pvalue[-1]
            B[i,]=beta[length(beta)]
            #P[i,c(1:(nf+1))]=beta[-1]
            #P[i,c((nf+2):(2*nf+2))]=pvalue[-1]
            #P[i,c((nf+2):(2*nf+2))]=tvalue[-1]
            #P[i,c((2*nf+3):(3*nf+3))]=se[-1]
            #P[i,c((3*nf+4):(4*nf+4))]=pvalue[-1]
        }
    }
    #}
    #}) #end of defyning apply function
    #sfStop()
    
    #print("iteration accoplished")
    #print(date())
    #print("Memory used after iteration")
    #print(memory.size())
    gc()
    
    #Final report
    #---------------------------------------------------------
    #P=t(as.matrix(P))
    #P=as.matrix(P)
    
    PF=P[,ncol(P)]
    if(model=="AD")P=P[,-ncol(P)]
    
    #print("FarmCPU.LM accoplished")
    #print(date())
    
    #print(dim(P))
    #print(P[1:5,])
    #print("Memory used at end of LM")
    #print(memory.size())
    gc()
    #print(head(P))
    return(list(P=P,P0=P0,PF=PF,Pred=yp,betapc=betapc,betapred=betapred,B=B))
} #end of function(
#)#end of cmpfun(
`FarmCPU.Pred` <- function(pred=NULL,ypred=NULL,name.of.trait=""){
    #Object: To display the correlation between observed phenotype and predicted phenotype
    #Input 1: pred, the first column is taxa name, the second column is observed phenotype and the third column is predicted phenotype
    #Input 2: ypred, the first column is taxa name, the second column is observed phenotype and the third column is predicted phenotype, the different between pred and ypred is that pred is to predict phenotypes with observed values already, ypred is to predict phenotype that is NA
    #Output: cor:correlation between observed phenotype and real phenotype (comment: pred is to predict phenotypes with observed values already)
    #Output: ycor:correlation between observed phenotype and real phenotype (comment: ypred is to predict phenotype that is NA)
    #Output: A table and plot (pdf)
    #Requirment: NA
    #Authors: Xiaolei Liu
    #Start date: June 26, 2014
    #Last update: June 26, 2014
    ##############################################################################################
    #print("Create prediction table..." )
    cor=NA
    ycor=NA
    if(!is.null(pred)) {
        index=!is.na(pred[,2])
        write.table(pred, paste("FarmCPU.", name.of.trait, ".Pred.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
        #pred=read.table("FarmCPU.Iteration_02.Farm-CPU.Sim1.Pred.csv",sep=",",header=T)
        
        pdf(paste("FarmCPU.", name.of.trait,".Pred.pdf" ,sep = ""), width = 5,height=5)
        par(mar = c(5,6,5,3))
        pred.lm = lm(pred[,3][index]~pred[,2][index])
        plot(pred[,3][index]~pred[,2][index],pch=20,col='black',ylab="Predicted phenotype",xlab="Observed phenotype",cex.axis=1,cex=1,cex.lab=1,las=1,bty='n',xlim=c(floor(min(pred[,2],na.rm=T)),ceiling(max(pred[,2],na.rm=T))*1.2),ylim=c(floor(min(pred[,3],na.rm=T)),ceiling(max(pred[,3],na.rm=T))*1.2),xaxs="i",yaxs="i")
        abline(pred.lm,lty=5,col='red',lwd=2)
        #legend(max(pred[,3])+1,max(pred[,2])+1, paste("R^2 = ", 0.5), col = 'black', text.col = "black", lty = 1, ncol=1, cex = 1, lwd=2, bty='o')
        cor=round(summary(pred.lm)$r.sq, 3)
        text(max(pred[,2],na.rm=T)*1, max(pred[,3],na.rm=T)*1, paste("R^2=", cor), col= "forestgreen", cex = 1, pos=3)
        #title(paste("R^2 = ", round(summary(pred.lm)$r.sq, 3)), col= "black", cex = 1)
        dev.off()
    }
    #print("Create prediction table for unknown phenotype...")
    if(!is.null(ypred)){
        yindex=!is.na(ypred[,2])
        ypredrna=ypred[,2][yindex]
        write.table(ypred, paste("FarmCPU.", name.of.trait, ".unknownY.Pred.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
        if(length(ypredrna)!=0){
            pdf(paste("FarmCPU.", name.of.trait,".unknownY.Pred.pdf" ,sep = ""), width = 5,height=5)
            par(mar = c(5,6,5,3))
            ypred.lm = lm(ypred[,3][yindex]~ypredrna)
            plot(ypred[,3][yindex]~ypredrna,pch=20,col='black',ylab="Predicted phenotype",xlab="Observed phenotype",cex.axis=1,cex=1,cex.lab=1,las=1,bty='n',xlim=c(floor(min(pred[,2],na.rm=T)),ceiling(max(ypred[,2],na.rm=T))*1.2),ylim=c(floor(min(pred[,3],na.rm=T)),ceiling(max(ypred[,3],na.rm=T))*1.2),xaxs="i",yaxs="i")
            abline(ypred.lm,lty=5,col='red',lwd=2)
            ycor=round(summary(ypred.lm)$r.sq, 3)
            text(max(ypred[,2],na.rm=T)*1,max(ypred[,3],na.rm=T)*1, paste("R^2=", ycor), col= "forestgreen", cex = 1, pos=3)
            dev.off()
        }else{
            print("There is no observed phenotype for predicted phenotype")
        }
    }
    return(list(cor=cor,ycor=ycor))
}#end of `FarmCPU.Pred`
`FarmCPU.Prior` <-
function(GM,P=NULL,Prior=NULL,kinship.algorithm="FARM-CPU"){
    #Object: Set prior on existing p value
    #Input: GM - m by 3  matrix for SNP name, chromosome and BP
    #Input: Prior - s by 4  matrix for SNP name, chromosome, BP and Pvalue
    #Input: P - m by 1 matrix containing probability
    #Requirement: P and GM are in the same order, Prior is part of GM except P value
    #Output: P - m by 1 matrix containing probability
    #Authors: Zhiwu Zhang
    # Last update: March 10, 2013
    ##############################################################################
    #print("FarmCPU.Prior Started")
    #print("dimension of GM")
    #print(dim(GM))
    
    if(is.null(Prior)& kinship.algorithm!="FARM-CPU")return(P)
    if(is.null(Prior)& is.null(P))return(P)
    
    #get prior position
    if(!is.null(Prior)) index=match(Prior[,1],GM[,1],nomatch = 0)
    
    #if(is.null(P)) P=runif(nrow(GM)) #set random p value if not provided (This is not helpful)
    #print("debug set prior  a")
    
    #Get product with prior if provided
    if(!is.null(Prior) & !is.null(P)  )P[index]=P[index]*Prior[,4]
    
    #print("debug set prior   b")
    return(P)
}#The function FarmCPU.Prior ends here
`FarmCPU` <-
function(Y=NULL,GD=NULL,GM=NULL,CV=NULL,GP=NULL,Yt=NULL,DPP=1000000,kinship.algorithm="FARM-CPU",file.output=TRUE,cutOff=0.01,method.GLM="FarmCPU.LM",method.sub="reward",method.sub.final="reward",method.bin="static",bin.size=c(5e5,5e6,5e7),bin.selection=seq(10,100,10),
memo=NULL,Prior=NULL,ncpus=1,maxLoop=10,threshold.output=.01,
WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),maxOut=100,QTN.position=NULL,
converge=1,iteration.output=FALSE,acceleration=0,model="A",MAF.calculate=FALSE,plot.style="FarmCPU",p.threshold=NA,QTN.threshold=0.01,maf.threshold=0.03,ycor=NULL,bound=NULL){
    #Object: GWAS and GS by using FarmCPU method
    #Input: Y,GD,GM,CV
    #Input: GD - n by m +1 dataframe or n by m big.matrix
    #Input: GD - n by m matrix. This is Genotype Data Pure (GD). THERE IS NOT COLUMN FOR TAXA.
    #Requirement: Y, GD and CV have same taxa order. GD and GM have the same order on SNP
    #Requirement: Y can have missing data. CV, GD and GM can not. Non-variable markers are allowed
    #Output: GWAS,GPS,Pred
    #Authors: Xiaolei Liu and Zhiwu Zhang
    # Date  start: Febuary 24, 2013
    # Last update: April 2, 2013
    ##############################################################################################
    #print("FarmCPU Started")
    #print(date())
    #print("Memory used at begining of BUS")
    #print(memory.size())
    #print(dim(GD))
    #print(dim(GM))
    print("--------------------- Welcome to FarmCPU ----------------------------")
    echo=TRUE
    FarmCPU.Version=FarmCPU.0000()
    print("FarmCPU Started...")
    if(ncol(Y)>2) stop("FarmCPU only accept single phenotype, please specify a column, like myY[,c(1,3)]")
    #Set orientation
    #Strategy: the number of rows in GD and GM are the same if GD has SNP as row
    nm=nrow(GM)
    ny=nrow(Y)
    ngd1=nrow(GD)
    ngd2=ncol(GD)
    if(!is.null(CV)){
        CV=as.matrix(CV)
        npc=ncol(CV)
    }else{
        npc=0
    }
    ngd1=abs(ngd1-nm)
    ngd2=abs(ngd2-nm)
    orientation="col"
    theSNP=2
    ns=nrow(GD)
    if(min(ngd1,ngd2)==0){
        orientation="row"
        theSNP=1
        ns=ncol(GD)
    }
    
    #acceleration
    ac=NULL
    if(acceleration!=0) ac=rep(1.0,nm)
    
    #Handler of non numeric chr
    #GM[,2]=as.numeric(GM[,2])
    
    #Handler 0 bp
    index=which(GM[,3]==0 )
    if(length(index)>0){
        #print("Warning: there is 0 bp which was set to 1")
        #print(length(index))
        GM[index,3]=1      #This is problematic
    }
    
    #handler of multiple CPU on big.matrix
    if(ncpus>1 & is.big.matrix(GD)){
        #print("Multiple CPUs are not avaiable for big.matrix. ")
        #print("The big.matrix will be converted to regular matrix which takes more memmory")
        #stop("Import the genotype as regula R matrix or set single CPU")
    }
    
    #print("number of CPU required")
    #print(ncpus)
    if(ncpus>1) sfInit(parallel=ncpus>1, cpus=ncpus)
    
    P=GP
    
    if(!is.null(GP))P=GP[,4] #get the p value
    
    #print("maxLoop")
    #print(maxLoop)
    gc()
    #print(memory.size())
    #print(date())
    #print(is(GD))
    #print(dim(GD))
    
    #handler of GD with taxa column
    if(ncol(GD)>nm & orientation=="col"){
        #print("GD has taxa column")
        if(is.big.matrix(GD)){
            #retain as bi.matrix
            GD=deepcopy(GD,rows=1:nrow(GD),cols=2:ncol(GD))  #This cause problem with multi cpu
        }else{
            GD=as.matrix(GD[,-1])
        }
    }#end of if(ncol...
    
    #Change to regula matrix for multiple CPUs
    if(ncpus>1)  GD=as.matrix(GD)
    
    #print("after remove taxa in GD")
    gc()
    #print(memory.size())
    #print(date())
    #print(is(GD))
    #print(dim(GD))
    
    if(model=="A"){
        shift=0
    }else if(model=="AD"){
        shift=1
    }else {
        print("Please choose 'A' model or 'AD' model")
    }
    #print("bin.selection")
    #print(bin.selection)
    
    #calculating MAF
    if(MAF.calculate==FALSE){
        MAF=NA
    }else{
        MAF=apply(GD,theSNP,mean)
        MAF=matrix(MAF,nrow=1)
        MAF=apply(MAF,2,function(x) min(1-x/2,x/2))
    }
    
    for (trait in 2: ncol(Y))  {
        name.of.trait=colnames(Y)[trait]
        #print(paste("Processing trait: ",name.of.trait,sep=""))
        if(!is.null(memo)) name.of.trait=paste(memo,".",name.of.trait,sep="")
        
        #===============================================================================
        #handler of missing phenotype (keep raw Y,CV and GD)
        #print(date())
        #print("Memory used before processing missing")
        #print(memory.size())
        
        #index for missing phenotype
        index=1:nm
        seqTaxa=which(!is.na(Y[,trait]))
        if(MAF.calculate==TRUE){
            if(is.na(maf.threshold)){
                if(length(seqTaxa)<=100) maf.threshold=0.05
                #if(length(seqTaxa)>100&&length(seqTaxa)<=500) maf.threshold=0.01
                #if(length(seqTaxa)>300&&length(seqTaxa)<=500) maf.threshold=0.05
                #if(length(seqTaxa)>500&&length(seqTaxa)<=1000) maf.threshold=0.01
                if(length(seqTaxa)>100) maf.threshold=0
            }else{
                maf.threshold=maf.threshold
            }
            mafindex=(1:nm)[MAF>=maf.threshold]
            MAF=MAF[mafindex]
            index=mafindex
            GM=GM[index,]
            nm=length(index)
        }
        #predict = !(length(seqTaxa)==nrow(Y))#judge whether there is NA in phenotype
        predict = !is.null(Yt)#judge whether there is two phenotypes
        PredictYt = NULL
        ypred = NULL
        #print(length(seqTaxa))
        #print(nrow(Y))
        #print("predict")
        #print(predict)
        Y1=Y[seqTaxa,]
        #if(is.numeric(CV)){CV1=CV[seqTaxa]
        #}else{
        #    CV1=CV[seqTaxa,]}
        CV1=CV[seqTaxa,]
        
        #print(head(CV1))
        if(length(seqTaxa)<1) stop("FarmCPU stoped as no data in Y")
        
        #print("Extract genotype for phenotyped taxa")
        #print(memory.size())
        #print(is(GD))
        #print(dim(GD))
        #print(length(seqTaxa))
        #print(length(index))
        
        #GD based on big.matrix and orientation
        if(orientation=="col"){
            if(is.big.matrix(GD)){
                GD1=deepcopy(GD,rows=seqTaxa,cols=index)
            }else{
                GD1=GD[seqTaxa,index]
            }
        }else{
            if(is.big.matrix(GD)){
                GD1=deepcopy(GD,rows=index,cols=seqTaxa)
            }else{
                GD1=GD[index,seqTaxa]
            }
        }# end of if orientation
        
        #prepare the data for predict NA in phenotype
        if(predict){
            seqTaxa2=which(is.na(Y[,trait]))
            
            #seqTaxa2=which(is.na(Yt[,trait]))
            #Y2=Yt[seqTaxa2,]
            PredictYt=Yt[seqTaxa2,]
            if(is.numeric(CV)){CV2=CV[seqTaxa2]
            }else{
                CV2=CV[seqTaxa2,]}
            
            #GD based on big.matrix and orientation
            if(orientation=="col"){
                if(is.big.matrix(GD)){
                    GD2=deepcopy(GD,rows=seqTaxa2,cols=index)
                }else{
                    GD2=GD[seqTaxa2,index]
                }
            }else{
                if(is.big.matrix(GD)){
                    GD2=deepcopy(GD,rows=index,cols=seqTaxa2)
                }else{
                    GD2=GD[index,seqTaxa2]
                }
            }# end of if orientation
        }
        #print("dim(GD2)")
        #print(dim(GD2))
        #Step 1: preliminary screening
        #print(date())
        #print("Memory used before 1st GLM")
        #print(memory.size())
        
        theLoop=0
        theConverge=0
        seqQTN.save=c(0)
        seqQTN.pre=c(-1)
        
        isDone=FALSE
        name.of.trait2=name.of.trait
        
        
        #while(theLoop<maxLoop & !converge ) {
        while(!isDone) {
            theLoop=theLoop+1
            print(paste("Current loop: ",theLoop," out of maximum of ", maxLoop, sep=""))
            #print(date())
            
            spacer="0"
            if(theLoop>9)spacer=""
            if(iteration.output) name.of.trait2=paste("Iteration_",spacer,theLoop,".",name.of.trait,sep="")
            if(method.bin=="NONE")maxLoop=1 #force to exit for GLM model
            
            #Step 2a: Set prior
            #print("Memory used before Prior")
            #print(memory.size())
            
            myPrior=FarmCPU.Prior(GM=GM,P=P,Prior=Prior,kinship.algorithm=kinship.algorithm)
            #Step 2b: Set bins
            
            #print(myPrior[1:5])
            
            #print("Memory used before Bin")
            #print(memory.size())
            #print(date())
            
            if(theLoop<=2){
                myBin=FarmCPU.BIN(Y=Y1[,c(1,trait)],GD=GD1,GM=GM,CV=CV1,orientation=orientation,P=myPrior,method=method.bin,b=bin.size,s=bin.selection,theLoop=theLoop,bound=bound)
            }else{
                myBin=FarmCPU.BIN(Y=Y1[,c(1,trait)],GD=GD1,GM=GM,CV=theCV,orientation=orientation,P=myPrior,method=method.bin,b=bin.size,s=bin.selection,theLoop=theLoop)
            }
            
            #Step 2c: Remove bin dependency
            #print(date())
            #print("Memory used before Remove")
            #print(memory.size())
            
            #Remove QTNs in LD
            seqQTN=myBin$seqQTN
            ve.save=myBin$ve.save
            vg.save=myBin$vg.save
            #print(seqQTN)
            #if(theLoop==2&&is.null(seqQTN)){maxLoop=2}#force to exit for GLM model while seqQTN=NULL and h2=0
            if(theLoop==2){
                #print(head(P))
                #print(min(P,na.rm=TRUE))
                if(!is.na(p.threshold)){
                    if(min(myPrior,na.rm=TRUE)>p.threshold){
                        seqQTN=NULL
                        print("Top snps have little effect, set seqQTN to NULL!")
                        #print("**********FarmCPU ACCOMPLISHED**********")
                    }
                }else{
                    if(min(myPrior,na.rm=TRUE)>0.01/nm){
                        seqQTN=NULL
                        print("Top snps have little effect, set seqQTN to NULL!")
                        #print("**********FarmCPU ACCOMPLISHED**********")
                    }
                }
            }
            
            #when FARM-CPU can not work, make a new QQ plot and manhatthan plot
            if(theLoop==2&&is.null(seqQTN)){
                #Report
                GWAS=cbind(GM,P,MAF,myGLM$B)
                #if(isDone | iteration.output){
                gc()
                pred=myGLM$Pred
                #print(pred)
                if(!is.null(pred)) pred=cbind(Y1,myGLM$Pred) #Need to be consistant to CMLM
                #print(pred)
                p.GLM=GWAS[,4]
                p.GLM.log=-log10(quantile(p.GLM,na.rm=TRUE,0.05))
                #set.seed(666)
                #bonf.log=-log10(quantile(runif(nm),0.05))
                bonf.log=1.3
                bonf.compare=p.GLM.log/bonf.log
                p.FARMCPU.log=-log10(p.GLM)/bonf.compare
                GWAS[,4]=10^(-p.FARMCPU.log)
                GWAS[,4][which(GWAS[,4]>1)]=1
                #colnames(GWAS)=c(colnames(GM),"P.value","maf","nobs","Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP","FDR_Adjusted_P-values")
                colnames(GWAS)=c(colnames(GM),"P.value","maf","effect")
                
                Vp=var(Y1[,2],na.rm=TRUE)
                
                #print("Calling Report..")
                if(file.output){
                    if(npc!=0){
                        betapc=cbind(c(1:npc),myGLM$betapc)
                        colnames(betapc)=c("CV","Effect")
                        write.csv(betapc,paste("FarmCPU.",name.of.trait2,".CVeffect.csv",sep=""),quote=F,row.names=FALSE)
                    }
                    GAPIT.Report(name.of.trait=name.of.trait2,GWAS=GWAS,pred=NULL,ypred=ypred,tvalue=NULL,stderr=stderr,Vp=Vp,DPP=DPP,cutOff=cutOff,threshold.output=threshold.output,MAF=MAF,seqQTN=QTN.position,MAF.calculate=MAF.calculate,plot.style=plot.style)
                    myPower=GAPIT.Power(WS=WS, alpha=alpha, maxOut=maxOut,seqQTN=QTN.position,GM=GM,GWAS=GWAS,MaxBP=1e10)
                }
                #} #enf of is done
                break
            }#force to exit for GLM model while seqQTN=NULL and h2=0
            
            #print("debug seqQTN")
            #print(seqQTN)
            #print(seqQTN.save)
            if(!is.null(seqQTN.save)&&theLoop>1){
                if(seqQTN.save!=0 & seqQTN.save!=-1 & !is.null(seqQTN) ) seqQTN=union(seqQTN,seqQTN.save) #Force previous QTNs in the model
                #print("**********POSSIBLE QTNs combined**********")
            }
            #if(!is.null(seqQTN.save)){
            #if(theLoop>=4 && !is.null(seqQTN.save) && (length(intersect(seqQTN.pre,seqQTN))/length(union(seqQTN.pre,seqQTN)))==1){
            #if(seqQTN.save!=0 & seqQTN.save!=-1 & !is.null(seqQTN) )
            #{seqQTN=union(seqQTN,seqQTN.save) #Force previous QTNs in the model
            #}
            if(theLoop!=1){
                seqQTN.p=myPrior[seqQTN]
                if(theLoop==2){
                    #index.p=seqQTN.p<0.01/nm
                    index.p=seqQTN.p<QTN.threshold
                    if(!is.na(p.threshold)){
                        #index.p=seqQTN.p<p.threshold
                        index.p=seqQTN.p<QTN.threshold
                    }
                    seqQTN.p=seqQTN.p[index.p]
                    seqQTN=seqQTN[index.p]
                    seqQTN.p=seqQTN.p[!is.na(seqQTN)]
                    seqQTN=seqQTN[!is.na(seqQTN)]
                }else{
                    #print("seqQTN.save")
                    #print(seqQTN.save)
                    #print("seqQTN")
                    #print(seqQTN)
                    #print(length(seqQTN.save))
                    #print(seqQTN.p[1:length(seqQTN.save)]<1)
                    #print(seqQTN.p[(length(seqQTN.save)+1):length(seqQTN)]<0.01/nm)
                    
                    #index.p=seqQTN.p<(0.01/nm)
                    index.p=seqQTN.p<QTN.threshold
                    if(!is.na(p.threshold)){
                        #index.p=seqQTN.p<p.threshold
                        index.p=seqQTN.p<QTN.threshold
                    }
                    index.p[seqQTN%in%seqQTN.save]=TRUE
                    #print(index.p)
                    seqQTN.p=seqQTN.p[index.p]
                    seqQTN=seqQTN[index.p]
                    seqQTN.p=seqQTN.p[!is.na(seqQTN)]
                    seqQTN=seqQTN[!is.na(seqQTN)]
                }
            }
            
            myRemove=FarmCPU.Remove(GD=GD1,GM=GM,seqQTN=seqQTN,seqQTN.p=seqQTN.p,orientation=orientation,threshold=.7)
            
            #Recoding QTNs history
            seqQTN=myRemove$seqQTN
            
            #if(length(setdiff(seqQTN,seqQTN.save))==0 & length(intersect(seqQTN,seqQTN.save))>0   ) converge=TRUE
            theConverge=length(intersect(seqQTN,seqQTN.save))/length(union(seqQTN,seqQTN.save))
            circle=(length(union(seqQTN,seqQTN.pre))==length(intersect(seqQTN,seqQTN.pre))  )
            
            #handler of initial status
            if(is.null(seqQTN.pre)){circle=FALSE
            }else{
                if(seqQTN.pre[1]==0) circle=FALSE
                if(seqQTN.pre[1]==-1) circle=FALSE
            }
            
            #print("circle objective")
            print("seqQTN")
            print(seqQTN)
            print("scanning...")
            if(theLoop==maxLoop){
                print(paste("Total number of possible QTNs in the model is: ", length(seqQTN),sep=""))
            }
            #print(seqQTN.save)
            #print(seqQTN.pre)
            #print(circle)
            
            #print(converge)
            #print("converge current")
            #print(theConverge)
            
            isDone=((theLoop>=maxLoop) | (theConverge>=converge)  |circle )
            
            seqQTN.pre=seqQTN.save
            seqQTN.save=seqQTN
            
            #myRemove=FarmCPU.Remove(GD=GD1,GM=GM,seqQTN=seqQTN,orientation=orientation,threshold=.7)
            #Step 3: Screen with bins
            rm(myBin)
            gc()
            #print(date())
            #print("Memory used before 2nd GLM")
            #print(memory.size())
            
            theCV=CV1
            if(!is.null(myRemove$bin)){
                if(theLoop==1){
                    theCV=cbind(CV1,myRemove$bin)
                }else{
                    #print("remove PCs since 2nd iteration")
                    theCV=cbind(CV1,myRemove$bin)
                    #theCV=myRemove$bin
                }
            }
            myGLM=FarmCPU.GLM(Y=Y1[,c(1,trait)],GDP=GD1,GM=GM,CV=theCV,orientation=orientation,package=method.GLM,ncpus=ncpus,model=model,seqQTN=seqQTN,npc=npc)
            #Step 4: Background unit substitution
            #print(date())
            #print("Memory used before SUB")
            #print(memory.size())
            
            #print("After calling SUB")
            #How about having reward during the process and mean at end?
            if(!isDone){
                myGLM=FarmCPU.SUB(GM=GM,GLM=myGLM,QTN=GM[myRemove$seqQTN,],method=method.sub,model=model)
            }else{
                myGLM=FarmCPU.SUB(GM=GM,GLM=myGLM,QTN=GM[myRemove$seqQTN,],method=method.sub.final,model=model)
            }
            #print(date())
            P=myGLM$P[,ncol(myGLM$P)-shift]
            
            #acceleration
            if(!is.null(ac)){
                ac=FarmCPU.Accelerate(ac=ac,QTN=myRemove$seqQTN,acceleration=acceleration)
                P=P/ac
            }
            #print("Acceleration in bus")
            index=which(ac>1)
            #print(cbind(index,ac[index],P[index]))
            #if P value is 0
            #if(min(P,na.rm=TRUE)==0) break
            P[P==0] <- min(P[P!=0],na.rm=TRUE)*0.01
            #Report
            if(isDone | iteration.output){
                #print("Report assemmbling...")
                #-------------------------------------------------------------------------------
                #Assemble result for report
                gc()
                pred=myGLM$Pred
                PredictY=NULL
                if(!is.null(theCV)&&predict){
                    #Statistics on the reduced model without marker
                    beta <- myGLM$betapred
                    #w=seqQTN
                    if(orientation=="row"){
                        predw=rbind(1,t(CV1),GD2[seqQTN,])
                    }else{
                        predw=cbind(1,CV1,GD2[,seqQTN])
                    }
                    #ypred=predw%*%beta
                    #if(!is.null(theCV)){
                    #nf=length(theCV)/length(seqTaxa2)
                    #theCV=matrix(as.numeric(as.matrix(theCV)),length(seqTaxa2),nf)
                    #predw=cbind(rep(1,length(seqTaxa2)),theCV)#add overall mean indicator
                    #}else{
                    #predw=rep(1,length(seqTaxa2))
                    #}
                    #print(dim(predw))
                    #print(predw)
                    #print(length(beta))
                    #print(beta)
                    PredictY=predw%*%beta
                    #print(PredictY)
                    #PredictYt[seqTaxa2,]=PredictY
                }
                if(!is.null(pred)) pred=cbind(Y1,myGLM$Pred) #Need to be consistant to CMLM
                if(!is.null(PredictY)) ypred=cbind(PredictYt,PredictY) #Need to be consistant to CMLM
                #P=myGLM$P[,ncol(myGLM$P)-shift]
                #myGLM$P is in order of estimate, tvalue, stderr and pvalue
                #nf=ncol(myGLM$P)/4
                #tvalue=myGLM$P[,nf*2-shift]
                #stderr=myGLM$P[,3*nf-shift]
                #print("MAF might cause problem")
                #print(length(MAF))
                #GWAS=cbind(GM,P,MAF,NA,NA,NA,NA)
                GWAS=cbind(GM,P,MAF,myGLM$B)
                #colnames(GWAS)=c(colnames(GM),"P.value","maf","nobs","Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP","FDR_Adjusted_P-values")
                colnames(GWAS)=c(colnames(GM),"P.value","maf","effect")
                Vp=var(Y1[,2],na.rm=TRUE)
                
                if(!is.null(ypred)){
                    yindex=!is.na(ypred[,2])
                    ypredrna=ypred[,2][yindex]
                    ypred.lm = lm(ypred[,3][yindex]~ypredrna)
                    ycor=round(summary(ypred.lm)$r.sq, 3)
                    #print(ycor)
                }
                
                
                #print("Calling Report..")
                if(file.output){
                    if(theLoop==1&&is.null(CV)){
                        
                        if(npc!=0){
                            betapc=cbind(c(1:npc),myGLM$betapc)
                            colnames(betapc)=c("CV","Effect")
                            write.csv(betapc,paste("FarmCPU.",name.of.trait2,".CVeffect.csv",sep=""),quote=F,row.names=FALSE)
                        }
                        
                        GAPIT.Report(name.of.trait=name.of.trait2,GWAS=GWAS,pred=NULL,ypred=NULL,tvalue=NULL,stderr=stderr,Vp=Vp,DPP=DPP,cutOff=cutOff,threshold.output=threshold.output,MAF=MAF,seqQTN=QTN.position,MAF.calculate=MAF.calculate,plot.style=plot.style)
                        
                    }else{
                        if(npc!=0){
                            betapc=cbind(c(1:npc),myGLM$betapc)
                            colnames(betapc)=c("CV","Effect")
                            write.csv(betapc,paste("FarmCPU.",name.of.trait2,".CVeffect.csv",sep=""),quote=F,row.names=FALSE)
                        }
                        
                        GAPIT.Report(name.of.trait=name.of.trait2,GWAS=GWAS,pred=NULL,ypred=ypred,tvalue=NULL,stderr=stderr,Vp=Vp,DPP=DPP,cutOff=cutOff,threshold.output=threshold.output,MAF=MAF,seqQTN=QTN.position,MAF.calculate=MAF.calculate,plot.style=plot.style)
                    }
                }
                #Evaluate Power vs FDR and type I error
                #print("Calling Power..")
                myPower=GAPIT.Power(WS=WS, alpha=alpha, maxOut=maxOut,seqQTN=QTN.position,GM=GM,GWAS=GWAS,MaxBP=1e10)
            } #enf of is done
            #if(length(seqQTN)==1) maxLoop=3
        } #end of while loop
        print("**********FarmCPU ACCOMPLISHED SUCCESSFULLY**********")
        #print(name.of.trait)
        #print("-----------------------------------------------------------------------")
        #===============================================================================
    }# end of loop on trait
    
    if(ncpus>1)sfStop()
    gc()
    if(ncol(Y)==2) {
        # return (list(GWAS=GWAS,GPS=NULL,Pred=pred,compression=NULL,kinship.optimum=NULL,kinship=NULL,ycor=ycor,FDR=myPower$FDR,Power=myPower$Power,Power.Alpha=myPower$Power.Alpha,alpha=myPower$alpha,betapc=myGLM$betapc,seqQTN=seqQTN))
        return (list(GWAS=GWAS,GPS=NULL,Pred=pred,compression=NULL,kinship.optimum=NULL,kinship=NULL,ycor=ycor,betapc=myGLM$betapc,seqQTN=seqQTN))

    }else{
        return (list(GWAS=NULL,GPS=NULL,Pred=NULL,compression=NULL,kinship.optimum=NULL,kinship=NULL))
    }
    
}#The FarmCPU function ends here
`FarmCPU.Remove` <-
function(GDP=NULL,GM=NULL,seqQTN=NULL,seqQTN.p=NULL,orientation="col",threshold=.99){
    #Objective: Remove bins that are highly correlated
    #Input: GDP - n by m+1 matrix. The first colum is taxa name. The rest are m genotype
    #Input: GM - m by 3  matrix for SNP name, chromosome and BP
    #Input: seqQTN - s by 1 vecter for index of QTN on GM (+1 for GDP column wise)
    #Requirement: GDP and GM have the same order on SNP
    #Output: bin - n by s0 matrix of genotype
    #Output: binmap - s0 by 3 matrix for map of bin
    #Output: seqQTN - s0 by 1 vecter for index of QTN on GM (+1 for GDP column wise)
    #Relationship: bin=GDP[,c(seqQTN)], binmap=GM[seqQTN,], s0<=s
    #Authors: Zhiwu Zhang
    # Last update: March 4, 2013
    ##############################################################################
    #print("FarmCPU.Remove Started")
    #print(date())
    
    if(is.null(seqQTN))return(list(bin=NULL,binmap=NULL,seqQTN=NULL))
    #remove seqQTN with unsignificant p values
    #index.p=seqQTN.p<0.01
    #seqQTN.p=seqQTN.p[index.p]
    #seqQTN=seqQTN[index.p]
    #sort seqQTN using p values
    seqQTN=seqQTN[order(seqQTN.p)]
    
    hugeNum=10e10
    n=length(seqQTN)
    #print("Number of bins and GDP")
    #print(n)
    #print(dim(GDP))
    #print(seqQTN)
    
    #fielter bins by physical location
    
    binmap=GM[seqQTN,]
    
    #print("binmap")
    #print(binmap)
    
    cb=as.numeric(binmap[,2])*hugeNum+as.numeric(binmap[,3])#create ID for chromosome and bp
    cb.unique=unique(cb)
    
    #print("debuge")
    #print(cb)
    #print(cb.unique)
    
    index=match(cb.unique,cb,nomatch = 0)
    seqQTN=seqQTN[index]
    
    #print("Number of bins after chr and bp fillter")
    n=length(seqQTN) #update n
    #print(n)
    #print(date())
    
    #Set sample
    ratio=.1
    maxNum=100000
    if(orientation=="col"){
        s=nrow(GDP) #sample size
        m=ncol(GDP) #number of markers
    }else{
        m=nrow(GDP) #sample size
        s=ncol(GDP) #number of markers
    }
    
    #print("Determine number of samples")
    #print(date())
    #sampled=floor(ratio*s)
    sampled=s
    if(sampled>maxNum)sampled=maxNum
    
    #print("Number of individuals sampled to test dependency of bins")
    #print(sampled)
    
    #index=sample(s,sampled)
    index=1:sampled
    
    #print("Get the samples")
    #print(date())
    
    #This section has problem of turning big.matrix to R matrix
    #It is OK as x is small
    if(orientation=="col"){
        if(is.big.matrix(GDP)){
            x=as.matrix(deepcopy(GDP,rows=index,cols=seqQTN) )
        }else{
            x=GDP[index,seqQTN]
        }
    }else{
        if(is.big.matrix(GDP)){
            x=t(as.matrix(deepcopy(GDP,rows=seqQTN,cols=index) ))
        }else{
            x=t(GDP[seqQTN,index] )
        }
    }# end of if orientation
    
    #print("Calculating r")
    #print(date())
    #print("matrix x")
    #print(is(x))
    #print(dim(x))
    #print(length(x))
    
    #x=x[,order(seqQTN.p)]
    #print("x")
    #print(head(x))
    r=cor(as.matrix(x))
    #print("r")
    #print(r)
    #print("indexing r")
    #print(date())
    index=abs(r)>threshold
    
    #print("index")
    #print(index)
    #print("Fancy algorithm")
    #print(date())
    #print("dimension of r")
    #print(dim(r))
    b=r*0
    b[index]=1
    c=1-b
    #print("for loop")
    #print(date())
    
    #for(i in 1:(n-1)){
    #  for (j in (i+1):n){
    #    b[j,j]=b[j,j]*c[i,j]
    #  }
    #}
    
    #The above are replaced by following
    c[lower.tri(c)]=1
    diag(c)=1
    bd <- apply(c,2,prod)
    
    #print("Positioning...")
    #print(date())
    
    #position=diag(b)==1
    position=(bd==1)
    seqQTN=seqQTN[position]
    #============================end of optimum============================================
    seqQTN=seqQTN[!is.na(seqQTN)]
    
    #print("Extract bin genotype data")
    #print(date())
    
    #This section has problem of turning big.matrix to R matrix
    
    if(orientation=="col"){
        if(is.big.matrix(GDP)){
            bin=as.matrix(deepcopy(GDP,cols=seqQTN) )
        }else{
            bin=GDP[,seqQTN]
        }
    }else{
        if(is.big.matrix(GDP)){
            bin=t(as.matrix(deepcopy(GDP,rows=seqQTN,) ))
        }else{
            bin=t(GDP[seqQTN,] )
        }
    }# end of if orientation
    
    
    #print("Get bin map")
    #print(date())
    
    binmap=GM[seqQTN,]
    
    #print("Number of bins left:")
    #print(length(seqQTN))
    #print("FarmCPU.Remove accomplished successfully!")
    
    return(list(bin=bin,binmap=binmap,seqQTN=seqQTN))
}#The function FarmCPU.Remove ends here
`FarmCPU.SUB` <-
function(GM=NULL,GLM=NULL,QTN=NULL,method="mean",useapply=TRUE,model="A"){
    #Input: FarmCPU.GLM object
    #Input: QTN - s by 3  matrix for SNP name, chromosome and BP
    #Input: method - options are "penalty", "reward","mean","median",and "onsite"
    #Requirement: P has row name of SNP. s<=t. covariates of QTNs are next to SNP
    #Output: GLM with the last column of P updated by the substituded p values
    #Authors: Xiaolei Liu and Zhiwu Zhang
    # Last update: Febuary 26, 2013
    ##############################################################################
    if(is.null(GLM$P)) return(NULL)  #P is required
    if(is.null(QTN)) return(NULL)  #QTN is required
    #print("FarmCPU.SUB Started")
    #print("dimension of QTN")
    #print(dim(QTN))
    #print(length(QTN))
    
    #print("debug")
    #print(QTN)
    #print(GLM)
    #position=match(QTN[,1], rownames(GLM$P), nomatch = 0)
    position=match(QTN[,1], GM[,1], nomatch = 0)
    #position=(1:nrow(GM))[GM[,1]%in%QTN[,1]]
    nqtn=length(position)
    #print("Position of QTN  on GM")
    #print(length(position))
    #print(position)
    #get position of QTNs (last nqtn columns from the second last)
    if(model=="A"){
        index=(ncol(GLM$P)-nqtn):(ncol(GLM$P)-1)
        spot=ncol(GLM$P)
    }else{
        index=(ncol(GLM$P)-nqtn-1):(ncol(GLM$P)-2)
        spot=ncol(GLM$P)-1
    }
    
    #print("Position of P value of QTN")
    #print(index)
    
    #print("Position of P value of marker")
    #print(spot)
    
    #print('ok')
    #print(ncol(GLM$P))
    #print(nqtn)
    #print((ncol(GLM$P)-nqtn))
    #print((ncol(GLM$P)-1))
    #print(min(GLM$P[,index],na.rm=TRUE))
    #print(GLM$P[position,spot])
    if(ncol(GLM$P)!=1){
        if(length(index)>1){
            if(method=="penalty") P.QTN=apply(GLM$P[,index],2,max,na.rm=TRUE)
            if(method=="reward") P.QTN=apply(GLM$P[,index],2,min,na.rm=TRUE)
            if(method=="mean") P.QTN=apply(GLM$P[,index],2,mean,na.rm=TRUE)
            if(method=="median") P.QTN=apply(GLM$P[,index],2,median,na.rm=TRUE)
            if(method=="onsite") P.QTN=GLM$P0[(length(GLM$P0)-nqtn+1):length(GLM$P0)]
        }else{
            if(method=="penalty") P.QTN=max(GLM$P[,index],na.rm=TRUE)
            if(method=="reward") P.QTN=min(GLM$P[,index],na.rm=TRUE)
            if(method=="mean") P.QTN=mean(GLM$P[,index],na.rm=TRUE)
            if(method=="median") P.QTN=median(GLM$P[,index],median,na.rm=TRUE)
            if(method=="onsite") P.QTN=GLM$P0[(length(GLM$P0)-nqtn+1):length(GLM$P0)]
        }
        
        #replace SNP pvalues with QTN pvalue
        #print("Substituting...")
        GLM$P[position,spot]=P.QTN
        #print(position)
        #print(GLM$betapred)
        GLM$B[position,]=GLM$betapred
    }
    #write.table(P,file="debuger.csv",sep=",")
    return(GLM)
}#The function FarmCPU.SUB ends here

`FarmCPU.P.Threshold` <-
function(GD=NULL,GM=NULL,Y=NULL,trait="",theRep=100){
    #Input: GD - Genotype
    #Input: GM - SNP name, chromosome and BP
    #Input: Y - phenotype, 2 columns
    #Input: trait - name of the trait
    #Input: theRep - number of replicates
    #Output: get minimum p value of each permutation and the recommend p.threshold used for FarmCPU model
    #Authors: Xiaolei Liu
    # Last update: April 6, 2015
    ##############################################################################
    
    #theRep=theRep
    #trait=trait
    if(is.null(GD))return(NULL)
    if(is.null(GM))return(NULL)
    if(is.null(Y))return(NULL)
    set.seed(12345)
    i=1
    for(i in 1:theRep){
        index=1:nrow(Y)
        index.shuffle=sample(index,length(index),replace=F)
        Y.shuffle=Y
        Y.shuffle[,2]=Y.shuffle[index.shuffle,2]
        
        #GWAS with FarmCPU...
        myFarmCPU=FarmCPU(
            Y=Y.shuffle[,c(1,2)],#Phenotype
            GD=GD,#Genotype
            GM=GM,#Map information
            file.output=FALSE,
            method.bin="optimum", #options are "static" and "optimum", default is static and this gives the fastest speed. If you want to use random model to optimize possible QTNs selection, use method.bin="optimum"
            maxLoop=1,#maxLoop is used to set the maximum iterations you want
            iteration.output=TRUE,#iteration.output=TRUE means to output results of every iteration
        )
        
        pvalue=min(myFarmCPU$GWAS[,4],na.rm=T)
        if(i==1){
            pvalue.final=pvalue
        }else{
            pvalue.final=c(pvalue.final,pvalue)
        }
    }#end of theRep
    
    write.table(pvalue.final,paste("FarmCPU.p.threshold.optimize.",trait,".txt",sep=""),sep="\t",col.names=F,quote=F,row.names=F)
    
    print("The p.threshold of this data set should be:")
    print(sort(pvalue.final)[ceiling(theRep*0.05)])
    
}#end of `FarmCPU.P.Threshold`


`FarmCPU.Burger` <-
function(Y=NULL,CV=NULL,GK=NULL){
    #Object: To calculate likelihood, variances and ratio, revised by Xiaolei based on GAPIT.Burger function from GAPIT package
    #Straitegy: NA
    #Output: P value
    #intput:
    #Y: phenotype with columns of taxa,Y1,Y2...
    #CV: covariate variables with columns of taxa,v1,v2...
    #GK: Genotype data in numerical format, taxa goes to row and snp go to columns. the first column is taxa (same as GAPIT.bread)
    #Authors: Xiaolei Liu ,Jiabo Wang and Zhiwu Zhang
    #Last update: Dec 21, 2016
    ##############################################################################################
    #print("FarmCPU.Burger in progress...")
    
    if(!is.null(CV)){
        CV=as.matrix(CV)#change CV to a matrix when it is a vector xiaolei changed here
        theCV=as.matrix(cbind(matrix(1,nrow(CV),1),CV)) ###########for FarmCPU
    }else{
        theCV=matrix(1,nrow(Y),1)
    }
    
    #handler of single column GK
    n=nrow(GK)
    m=ncol(GK)
    if(m>2){
        theGK=as.matrix(GK)#GK is pure genotype matrix
    }else{
        theGK=matrix(GK,n,1)
    }
    
    myFaSTREML=GAPIT.get.LL(pheno=matrix(Y[,-1],nrow(Y),1),geno=NULL,snp.pool=theGK,X0=theCV)
    REMLs=-2*myFaSTREML$LL
    delta=myFaSTREML$delta
    vg=myFaSTREML$vg
    ve=myFaSTREML$ve
    
    #print("FarmCPU.Burger succeed!")
    return (list(REMLs=REMLs,vg=vg,ve=ve,delta=delta))
} #end of FarmCPU.Burger
#=============================================================================================



`GAPIT.FilterByTaxa` <-
function(taxa,Data){
    #Object: To filter a data (Y, CV or GD) by taxa
    #Input: taxa - vector of taxa
    #Input: data - data frame with first column as taxa
    #Requirement: all taxa must be in data
    #Output: filtered data
    #Authors: Zhiwu Zhang
    # Last update: May 22, 2013
##############################################################################################
   #print("GAPIT.FilterByTaxa Started")

    Data=Data[match(taxa, Data[,1], nomatch = 0),]

  return (Data)

}#The function GAPIT.FilterByTaxa ends here
#=============================================================================================

`GAPIT.Fragment` <-
function(file.path=NULL,file.from=NULL, file.to=NULL,file.total=NULL,file.G=NULL,
                          file.Ext.G=NULL,seed=123,SNP.fraction=1,SNP.effect="Add",SNP.impute="Middle",
                          genoFormat=NULL, file.GD=NULL, file.Ext.GD=NULL, file.GM=NULL, file.Ext.GM=NULL, file.fragment=NULL,
                          file=1,frag=1,LD.chromosome=NULL,LD.location=NULL,LD.range=NULL, Create.indicator = FALSE, Major.allele.zero = FALSE){
#Object: To load SNPs on a (frag)ment in file (this is to replace sampler)
#Output: genotype data sampled
#Authors: Alex Lipka and Zhiwu Zhang
# Last update: August 18, 2011
##############################################################################################
#print("Fragmental reading...")
genoFormat="hapmap"
if(!is.null(file.GD)&is.null(file.G)) genoFormat="EMMA"
  
if(genoFormat=="hapmap"){
        #Initical G
        #print("Reading file...")
        G=NULL
        if(frag==1){
          skip.1=0
          G <- try(read.delim(paste(file.path,file.G,file, ".",file.Ext.G,sep=""),
                          head = FALSE,skip = skip.1, nrows = file.fragment+1),silent=TRUE)
        }else{
          skip.1 <- (frag-1)*file.fragment +1
          G <- try(read.delim(paste(file.path,file.G,file, ".",file.Ext.G,sep=""),
                          head = FALSE,skip = skip.1, nrows = file.fragment),silent=TRUE )
        }
        
        #print("processing the data...")
        if(inherits(G, "try-error"))  {
          G=NULL
          #print("File end reached for G!!!")
        }

        if(is.null(G)){
        #print("The above error indicating reading after end of file (It is OK).")
        return(list(GD=NULL,GI=NULL,GT=NULL,linesRead=NULL,GLD=NULL,heading=NULL) )
        }

        #print("Calling hapmap...")
        heading=(frag==1)
        
        #Recording number of lineas read
        if(heading){
          n= nrow(G)-1
        }else{
          n= nrow(G)
        } 
       
       linesRead=n
               
        #Sampling
       if(SNP.fraction<1){

          #print("Number of SNP in this pragment:")
          #print(n)
          
          #set.seed(seed+(file*1000)+frag)
          #mySample=sample(1:n,max(2,floor(n*as.numeric(as.vector(SNP.fraction)))))
          mySample=sample(1:n,max(2,floor(n*SNP.fraction)))
          #print("@@@@@@@@@@")
          #print(mySample)
          #print(length(mySample))
          if(heading){
            G=G[c(1,(1+mySample)),]
          }else{
            G=G[mySample,]
          }
        } #end of if(SNP.fraction<1)
        

        print("Call hapmap from fragment")      
        hm=GAPIT.HapMap(G,SNP.effect=SNP.effect,SNP.impute=SNP.impute,heading=heading, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

        #print("Extracting snps for LD plot...")
        #Extract SNPs for LD plot
        if(!is.null(LD.chromosome) & !is.null(hm$GD)){
          index=(G[,3]==LD.chromosome[1]) & abs((as.numeric(G[,4])-as.numeric(LD.location[1]))<(as.numeric(LD.range[1])/2))   
          GLD=G[index,]
        }else{
          GLD=NULL
        }
        
        #rm(G)
        #gc()
        print("hapmap called successfuly from fragment")

        return(list(GD=hm$GD,GI=hm$GI,GT=hm$GT,linesRead=linesRead,GLD=GLD,heading=heading,G=G))

          print("ERROR: It should not get here!!!")        
} #end of "hapmap"



if(genoFormat=="EMMA"){
#print("The file is a numerical format!")
        #Initial GD
        GD=NULL
        skip.1 <- (frag-1)*file.fragment
        #Skip the remaining columns
        GD.temp <- try(read.table(paste(file.path,file.GD, file, ".", file.Ext.GD,sep=""), head = TRUE, nrows = 1),silent=TRUE)
        num.SNP <- ncol(GD.temp)-1
        rm(GD.temp)
        read.in <- min(file.fragment,(num.SNP-skip.1))
        skip.2 <- max((num.SNP - (skip.1 + read.in)),0)
        print(paste(file.path,file.GD,file, ".",file.Ext.GD,sep=""))

        GD <- try(read.table(paste(file.path,file.GD,file, ".",file.Ext.GD,sep=""), head = TRUE,
                  colClasses = c("factor", rep("NULL", skip.1), rep("numeric", read.in),
                  rep("NULL", skip.2))) ,silent=TRUE)
        GI <- try(read.table(paste(file.path,file.GM,file, ".",file.Ext.GM,sep=""), head = TRUE,
                  skip=skip.1, nrows=file.fragment) ,silent=TRUE)
                  
        if(inherits(GD, "try-error"))  {
          GD=NULL
          print("File end reached for GD!!!")
        }
        if(inherits(GI, "try-error"))  {
          GI=NULL
          print("File end reached for GI!!!")
        }                          
                  
        if(is.null(GD)) return(list(GD=NULL, GI=NULL,GT=NULL,linesRead=NULL,GLD=NULL))
        
        GT=GD[,1]  #Extract infividual names

        GD=GD[,-1] #Remove individual names
#print("Numerical file read sucesfuly from fragment") 
        linesRead=ncol(GD)       
        if(SNP.fraction==1) return(list(GD=GD, GI=GI,GT=GT,linesRead=linesRead,GLD=NULL))
        
        if(SNP.fraction<1){
          n= ncol(GD)
          #set.seed(seed+file)
          sample=sample(1:n,floor(n*SNP.fraction))
          return(list(GD=GD[,sample], GI=GI[sample,],GT=GT,linesRead=linesRead,GLD=NULL))
        }
    } # end of the "EMMA"
#print("fragment ended succesfully!")
}#End of fragment
#=============================================================================================

`GAPIT.GS` <-
function(KW,KO,KWO,GAU,UW){
#Object: to derive BLUP for the individuals without phenotype
#UW:BLUP and PEV of ID with phenotyp
#Output: BLUP
#Authors: Zhiwu Zhang 
# Last update: Oct 22, 2015  by Jiabo Wang
##############################################################################################
#print(dim(UW))
UO=try(t(KWO)%*%solve(KW)%*%UW,silent=TRUE)
#print(dim(KWO)) #kinship without inference
#print(dim(KW))  #kinship within inference
#print(dim(UW))  #BLUP AND PEV of reference
if(inherits(UO, "try-error")) UO=t(KWO)%*%ginv(KW)%*%UW
n=ncol(UW) #get number of columns, add additional for individual name

BLUP=data.frame(as.matrix(GAU[,1:4]))
BLUP.W=BLUP[which(GAU[,3]<2),]
W_BLUP=BLUP.W[order(as.numeric(as.matrix(BLUP.W[,4]))),]
UW=UW[which(rownames(UW)==colnames(KW)),] # get phenotype groups order

ID.W=as.numeric(as.matrix(W_BLUP[,4]))
n.W=max(ID.W)
DS.W=diag(n.W)[ID.W,]
ind.W=DS.W%*%UW

all.W=cbind(W_BLUP,ind.W)
all=all.W

BLUP.O=BLUP[which(GAU[,3]==2),]
O_BLUP=BLUP.O[order(as.numeric(as.matrix(BLUP.O[,4]))),]
#print(dim(O_BLUP))
if(nrow(O_BLUP)>0){

ID.O=as.numeric(as.matrix(O_BLUP[,4]))
n.O=max(ID.O)
DS.O=diag(n.O)[ID.O,]
ind.O=DS.O%*%UO
all.O=cbind(O_BLUP,ind.O)
all=rbind(all.W,all.O)
}

colnames(all)=c("Taxa", "Group", "RefInf","ID","BLUP","PEV")

print("GAPIT.GS accomplished successfully!")
return(list(BLUP=all))
}#The function GAPIT.GS ends here
#=============================================================================================

`GAPIT.GS.Visualization` <-
function(gsBLUP = gsBLUP, BINS=BINS, name.of.trait = name.of.trait){
#Object: To build heat map to show distribution of BLUP and PEV
#Output: pdf
#Authors: Zhiwu Zhang 
# Last update: May 15, 2011 
##############################################################################################
nBin=BINS

BLUP= gsBLUP[,5]
PEV = gsBLUP[,6]

if(BLUP[1]=="NaN"){
  warning ("It was not converged. BLUP was not created!")
}
if(BLUP[1]!="NaN" )
{


BLUP.max=try(max(BLUP))
BLUP.min=try(min(BLUP))
if(inherits(BLUP.max, "try-error"))  return()

  range.BLUP=BLUP.max-BLUP.min
  range.PEV=max(PEV)-min(PEV)
  
  interval.BLUP=range.BLUP/nBin
  interval.PEV=range.PEV/nBin
  
  
  bin.BLUP=floor(BLUP/max(BLUP)*nBin)*max(BLUP)/nBin
  bin.PEV=floor(PEV/max(PEV)*nBin)*max(PEV)/nBin
  
  
  distinct.BLUP=unique(bin.BLUP)
  distinct.PEV=unique(bin.PEV)
  
  if((length(distinct.BLUP)<2)  | (length(distinct.PEV)<2) ) return() #nothing to plot
  
  Position.BLUP=match(bin.BLUP,distinct.BLUP,nomatch = 0)
  Position.PEV=match(bin.PEV,distinct.PEV,nomatch = 0)
  
  value=matrix(1,length(Position.BLUP))
  KG<- (tapply(as.numeric(value), list(Position.BLUP, Position.PEV), sum))
  
  rownames(KG)=round(distinct.BLUP, digits = 4)
  colnames(KG)=round(distinct.PEV, digits = 4)
  
  #Sort the rows and columns in order from smallest to largest
  
  rownames(KG) <- rownames(KG)[order(as.numeric(rownames(KG)))]
  colnames(KG) <- colnames(KG)[order(as.numeric(colnames(KG)))]
  rownames(KG) <- round(as.numeric(rownames(KG)))
  colnames(KG) <- round(as.numeric(colnames(KG)))
  #write.table(KG, "Input_Matrix_for_GS_Heat_Map.txt", quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)

  pdf(paste("GAPIT.", name.of.trait,".GPS.BLUPvsPEV", ".pdf", sep = ""),width = 9)
  #par(mfrow = c(1,1), mar = c(1,1,5,5), lab = c(5,5,7))
  par(mar = c(5,5,6,5))
  
  nba_heatmap <- heatmap.2(KG, Rowv=NA, Colv=NA,  col =  rev(heat.colors(256)), #  scale="column", 
  xlab = "PEV", ylab = "BLUP", main = " ", scale="none", symkey=FALSE, trace="none")

  #nba_heatmap <- heatmap.2(KG,  cexRow =.2, cexCol = 0.2, scale="none", symkey=FALSE, trace="none" )
 
  
  #cexRow =0.9, cexCol = 0.9)
  dev.off() 
}
#print("GAPIT.GS.Visualization accomplished successfully!")

}   #GAPIT.GS.Visualization ends here
#=============================================================================================

`GAPIT.Genotype` <-
function(G=NULL,GD=NULL,GM=NULL,KI=NULL,
  kinship.algorithm="Zhang",SNP.effect="Add",SNP.impute="Middle",PCA.total=0,PCA.col=NULL,PCA.3d=PCA.3d,seed=123, SNP.fraction =1,
  file.path=NULL,file.from=NULL, file.to=NULL, file.total=NULL, file.fragment = 1000,SNP.test=TRUE,
  file.G =NULL,file.Ext.G =NULL,
  file.GD=NULL,file.Ext.GD=NULL,
  file.GM=NULL,file.Ext.GM=NULL,
  SNP.MAF=0.05,FDR.Rate = 0.05,SNP.FDR=1,
  Timmer=NULL,Memory=NULL,
  LD.chromosome=NULL,LD.location=NULL,LD.range=NULL, SNP.CV=NULL,
  GP = NULL,GK = NULL,GTindex=NULL,  
  bin.size = 1000,inclosure.size = 100,
  sangwich.top=NULL,sangwich.bottom=NULL,
  file.output=TRUE,kinship.cluster="average",NJtree.group=NULL,NJtree.type=c("fan","unrooted"),
  Create.indicator = FALSE, Major.allele.zero = FALSE,Geno.View.output=TRUE){
#Object: To unify genotype and calculate kinship and PC if required:
#       1.For G data, convert it to GD and GI
#       2.For GD and GM data, nothing change 
#       3.Samling GD and create KI and PC
#       4.Go through multiple files
#       5.In any case, GD must be returned (for QC)
#Output: GD, GI, GT, KI and PC
#Authors: Zhiwu Zhang
#Last update: August 11, 2011
##############################################################################################

#print("Genotyping: numericalization, sampling kinship, PCs and much more...")



Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype start")
Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype start")
compress_z=NULL
#Create logical variables
byData=!is.null(G) | !is.null(GD)
byFile=!is.null(file.G) | !is.null(file.GD)
hasGenotype=(byData | byFile  )
needKinPC=(is.null(KI) | PCA.total>0 | kinship.algorithm=="Separation")

if(!is.null(KI) & !byData & !byFile & !SNP.test &kinship.algorithm!="SUPER") 
  { 
  print("It return unexpected")
  return (list(GD=NULL,GI=NULL,GT=NULL,hasGenotype=FALSE, genoFormat=NULL, KI=KI,PC=NULL,byFile=FALSE,fullGD=TRUE,Timmer=Timmer,Memory=Memory))
  }


#Set indicator for full GD
fullGD=FALSE
if(byData) fullGD=TRUE
if(byFile & SNP.fraction==1 & needKinPC) fullGD=TRUE

#SET GT to NULL in case of no genotype
if(!byData & !byFile & is.null(GK) &kinship.algorithm!="SUPER") 
  {
  if(is.null(KI) & is.null(GP) & is.null(GK)) stop("GAPIT says: Kinship has to be provided or estimated from genotype!!!")
  return (list(GD=NULL,GI=NULL,GT=NULL,hasGenotype=FALSE, genoFormat=NULL, KI=KI,PC=NULL,byFile=FALSE,fullGD=TRUE,Timmer=Timmer,Memory=Memory))
  }

genoFormat="hapmap"
if(is.null(G)&is.null(file.G)) genoFormat="EMMA"

#Multiple genotype files
#In one of the 3 situations, calculate KI with the algorithm specified, otherwise skip cit by setting algorithm to "SUPER"
kinship.algorithm.save=kinship.algorithm
kinship.algorithm="SUPER"
#Normal
if(is.null(sangwich.top) & is.null(sangwich.bottom) ) kinship.algorithm=kinship.algorithm.save
#TOP or Bottom is MLM
pass.top=FALSE
if(!is.null(sangwich.top))   pass.top=!(sangwich.top=="FaST" | sangwich.top=="SUPER" | sangwich.top=="DC")
pass.bottom=FALSE
if(!is.null(sangwich.bottom))   pass.bottom=!(sangwich.bottom=="FaST" | sangwich.bottom=="SUPER" | sangwich.bottom=="DC")
if(pass.top | pass.bottom )kinship.algorithm=kinship.algorithm.save
#Compatibility of input

#agreement among file from, to and total
if(!is.null(file.from) &!is.null(file.to) &!is.null(file.total))
  {
  if(file.total!=(file.to-file.from+1))  stop("GAPIT says: Conflict among file (from, to and total)")
  }
if(!is.null(file.from) &!is.null(file.to)) 
  {
  if(file.to<file.from)  stop("GAPIT says: file.from should smaller than file.to")
  }
#file.from and file.to must be in pair
if(is.null(file.from) &!is.null(file.to) ) stop("GAPIT says: file.from and file.to must be in pair)")
if(!is.null(file.from) &is.null(file.to) ) stop("GAPIT says: file.from and file.to must be in pair)")

#assign file.total
if(!is.null(file.from) &!is.null(file.to) ) file.total=file.to-file.from+1
if(byFile& is.null(file.total)) stop("GAPIT says: file.from and file.to must be provided!)")

if(!is.null(GP) & !is.null(GK) ) stop("GAPIT Says: You can not provide GP and GK at same time")
if(!is.null(GP) & !is.null(KI) ) stop("GAPIT Says: You can not provide GP and KI at same time")
if(!is.null(GK) & !is.null(KI))   stop("GAPIT says: You can not specify GK and KI at same time!!!")

#GP does not allow TOP
if(!is.null(GP) & !is.null(sangwich.top) ) stop("GAPIT Says: You provided GP. You can not spycify sangwich.top")

#Top require a bottom
if(!is.null(sangwich.top) & is.null(sangwich.bottom) ) stop("GAPIT Says: Top require its Bottom")

#naked bottom require GP or GK
if(is.null(sangwich.top) & !is.null(sangwich.bottom) & (is.null(GP) & is.null(GK)) ) stop("GAPIT Says: Uncovered Bottom (without TOP) requires GP or GK")

#Pseudo top (GK or GP) requires a bottom
if(is.null(sangwich.top) & is.null(sangwich.bottom) & (!is.null(GP)|!is.null(GK  ))) stop("GAPIT Says: You have provide GP or GK, you need to provide Bottom")

#if(!is.null(KI) &!is.null(kinship.algorithm))  stop("GAPIT says: You can not specify kinship.algorithm and provide kinship at same time!!!")



if(!needKinPC &SNP.fraction<1)  stop("GAPIT says: You did not require calculate kinship or PCs. SNP.fraction should not be specified!!!")
if(!SNP.test & is.null(KI) & !byData & !byFile)  stop("GAPIT says: For SNP.test optioin, please input either use KI or use genotype")

#if(is.null(file.path) & !byData & byFile) stop("GAPIT Ssays: A path for genotype data should be provided!")
if(is.null(file.total) & !byData & byFile) stop("GAPIT Ssays: Number of file should be provided: >=1")
if(!is.null(G) & !is.null(GD)) stop("GAPIT Ssays: Both hapmap and EMMA format exist, choose one only.")

if(!is.null(file.GD) & is.null(file.GM) & (!is.null(GP)|!is.null(GK)) ) stop("GAPIT Ssays: Genotype data and map files should be in pair")
if(is.null(file.GD) & !is.null(file.GM) & (!is.null(GP)|!is.null(GK)) ) stop("GAPIT Ssays: Genotype data and map files should be in pair")

if(!is.null(GD) & is.null(GM) & (is.null(GP)&is.null(GK)) &kinship.algorithm!="SUPER") stop("GAPIT Says: Genotype data and map files should be in pair")
if(is.null(GD) & !is.null(GM) & (is.null(GP)&is.null(GK)) &kinship.algorithm!="SUPER") stop("GAPIT Says: Genotype data and map files should be in pair")


#if(!byData & !byFile) stop("APIT Ssays: Either genotype data or files should be given!")
#if(byData&(!is.null(file.path))) stop ("APIT Ssays: You have provided geotype data. file.path should not be provided!")

#print("Pass compatibility of input")
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype loaded")
Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype loaded")
  
#Inital GLD
GLD=NULL
SNP.QTN=NULL #Intitial
GT=NULL

#Handler of read data in numeric format (EMMA)
#Rename GM as GI
if(!is.null(GM))GI=GM
rm(GM)
gc()
#Extract GD and GT from read data GD
if(!is.null(GD) )
  {
  GT=as.matrix(GD[,1])  #get taxa
  GD=as.matrix(GD[,-1]) #remove taxa column
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GT created from GD)")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GT created from GD")
  }

#Hapmap format
if(!is.null(G))
  {
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Before HapMap")
  Memory=GAPIT.Memory(Memory=Memory,Infor="Before HapMap")
  #Convert HapMap to numerical
  print(paste("Converting genotype...",sep=""))
  hm=GAPIT.HapMap(G,SNP.effect=SNP.effect,SNP.impute=SNP.impute, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="after HapMap")
  Memory=GAPIT.Memory(Memory=Memory,Infor="after HapMap")
  #Extracting SNP for LD plot
  if(!is.null(LD.chromosome))
    {
  #print("Extracting SNP for LD plot...")
    chromosome=(G[,3]==LD.chromosome[1])
    bp=as.numeric(as.vector(G[,4]))
    deviation=abs(bp-as.numeric(as.vector(LD.location[1])) )
    location=deviation< as.numeric(as.vector(LD.range[1])  )
    index=chromosome&location
    GLD=G[index,]
    }else{
    #print("No data in GLD")
    GLD=NULL
    }
    Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="HapMap")
    Memory=GAPIT.Memory(Memory=Memory,Infor="HapMap")
    print(paste("Converting genotype done.",sep=""))
    #rm(G)
    #gc()
    Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="G removed")
    Memory=GAPIT.Memory(Memory=Memory,Infor="G removed")
    GT=hm$GT
    GD=hm$GD
    GI=hm$GI
#
#print(unique(GI[,2]))
    rm(hm)
    gc()
    Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="hm removed")
    Memory=GAPIT.Memory(Memory=Memory,Infor="hm removed")
  }

#From files
if(!byData & byFile)
  {
  #print("Loading genotype from files...")
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="byFile")
  Memory=GAPIT.Memory(Memory=Memory,Infor="byFile")
  numFileUsed=file.to
  if(!needKinPC) numFileUsed=file.from
  #Initial GI as storage
  GD=NULL
  GT=NULL
  GI=NULL
  GLD=NULL
  #multiple fragments or files
  for (file in file.from:numFileUsed)
    {
    frag=1
    numSNP=file.fragment
    myFRG=NULL
   #print(paste("numSNP  before while is ",numSNP))
    while(numSNP==file.fragment) 
         {     #this is problematic if the read end at the last line
         print(paste("Reading file: ",file,"Fragment: ",frag))
         Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Before Fragment")
         Memory=GAPIT.Memory(Memory=Memory,Infor="Before Fragment")
         myFRG=GAPIT.Fragment( file.path=file.path,file.from=file.from, file.to=file.to,file.total=file.total,file.G=file.G,file.Ext.G=file.Ext.G,
                            seed=seed,SNP.fraction=SNP.fraction,SNP.effect=SNP.effect,SNP.impute=SNP.impute,genoFormat=genoFormat,
                            file.GD=file.GD,file.Ext.GD=file.Ext.GD,file.GM=file.GM,file.Ext.GM=file.Ext.GM,
                            file.fragment=file.fragment,file=file,frag=frag,
                            LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
         Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="After Fragment")
         Memory=GAPIT.Memory(Memory=Memory,Infor="After Fragment")
 
         if(is.null(GT) & !is.null(myFRG$GT))GT= as.matrix(myFRG$GT)

         if(is.null(GD))
           {
           GD= myFRG$GD
           }else{
           if(!is.null(myFRG$GD))
             {
             GD=cbind(GD,myFRG$GD)
             }
           }
           if(is.null(GI))
             {
             GI= myFRG$GI
             }else{
             if(!is.null(myFRG$GI)) 
               {
               colnames(myFRG$GI)=c("SNP","Chromosome","Position")
               GI=as.data.frame(rbind(as.matrix(GI),as.matrix(myFRG$GI)))
               }
             }

           if(is.null(G))
             {
             G= myFRG$G
             }else{
             if(!is.null(myFRG$G)) 
               {
               G=as.data.frame(rbind(as.matrix(G),as.matrix(myFRG$G[-1,])))
               }
             }
      
           if(is.null(GLD))
             {
             GLD= myFRG$GLD
             }else{
             if(!is.null(myFRG$GLD))
               {
               if(myFRG$heading)
                 {
                 GLD=as.data.frame(rbind(as.matrix(GLD),as.matrix(myFRG$GLD[-1,])))
                 }else{
                 GLD=as.data.frame(rbind(as.matrix(GLD),as.matrix(myFRG$GLD)))
                 }
               }
             }

            if(file==file.from & frag==1)GT=as.matrix(myFRG$GT)
            frag=frag+1
            if(!is.null(myFRG$GI))
              {
              numSNP=myFRG$linesRead[1]
              }else{
              numSNP=0
              }

            if(!needKinPC)numSNP=0  #force to end the while loop
            if(is.null(myFRG))numSNP=0  #force to end the while loop

            Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="END this Fragment")
            Memory=GAPIT.Memory(Memory=Memory,Infor="END this Fragment")



          } #end whileof repeat on fragment
   # print("This file is OK")
    } #end of file loop
  print("All files loaded")
  } #end of if(!byData&byFile)

#GM=as.matrix(GI)
#GI=GM
GM=GI

# modified by Jiabo in 20190927. sorted number of chrom by numeric and charicter

chor_taxa=as.character(unique(GM[,2]))

chor_taxa[order(gsub("([A-Z]+)([0-9]+)", "\\1", chor_taxa), as.numeric(gsub("([A-Z]+)([0-9]+)", "\\2", chor_taxa)))]
chr_letter=grep("[A-Z]|[a-z]",chor_taxa)
if(!setequal(integer(0),chr_letter))
  {     
  GI=as.matrix(GI)
      for(i in 1:(length(chor_taxa)))
        {
         index=GM[,2]==chor_taxa[i]
         GI[index,2]=i    
        }
  }

#print(chor_taxa)
#print(head(GI))
#print("@@@@@@@@@@@")
#print(GD[1:5,1:5])
#print(dim(GI))
#Follow the MAF to filter markers
if(!is.null(GD))
  { 
  #maf=apply(as.matrix(GD),2,function(one) abs(1-sum(one)/(2*nrow(GD))))
  #maf[maf>0.5]=1-maf[maf>0.5]
  ss=apply(GD,2,sum)
  maf=apply(cbind(.5*ss/(nrow(GD)),1-.5*ss/(nrow(GD))),1,min)
#print(max(maf))
#print(min(maf))
  maf_index=maf>=SNP.MAF
  print(paste("GAPIT will filter marker with MAF setting !!"))
  print(paste("The markers will be filtered by SNP.MAF: ",SNP.MAF,sep=""))
  print(table(maf_index))

#print(head(maf[!maf_index]))

  GD=GD[,maf_index]
  GI=as.data.frame(GI[maf_index,])
  GM=as.data.frame(GM[maf_index,])
  #GI=GM
  }
#print("file loaded")

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Sampling genotype")
Memory=GAPIT.Memory(Memory=Memory,Infor="Sampling genotype")
#print(KI)
#Plot third part kinship
if(!is.null(KI))
  {
  if(KI!=1) 
    {
    if(nrow(KI)<1000)
      {
      print("Plotting Kinship")
      #print(dim(KI))
      theKin=as.matrix(KI[,-1])
      line.names <- KI[,1]
      colnames(theKin)=KI[,1]
      rownames(theKin)=KI[,1]
      distance.matrix=dist(theKin,upper=TRUE)
      hc=hclust(distance.matrix,method=kinship.cluster)
      hcd = as.dendrogram(hc)
    ##plot NJtree
      if(!is.null(NJtree.group))
        {
        clusMember <- cutree(hc, k = NJtree.group)
        compress_z=table(clusMember,paste(line.names))
        type_col=rainbow(NJtree.group)
        Optimum=c(nrow(theKin),kinship.cluster,NJtree.group)
        }
      Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="set kinship")
      Memory=GAPIT.Memory(Memory=Memory,Infor="set kinship")
      if(file.output)
      {
      print("Creating heat map for kinship...")
      pdf(paste("GAPIT.Kin.thirdPart.pdf",sep=""), width = 12, height = 12)
      par(mar = c(25,25,25,25))
      Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="prepare heatmap")
      Memory=GAPIT.Memory(Memory=Memory,Infor="prepare heatmap")
      heatmap.2(theKin,  cexRow =.2, cexCol = 0.2, col=rev(heat.colors(256)), scale="none", symkey=FALSE, trace="none")
      dev.off()
      print("Kinship heat map PDF created!") 
      Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="plot heatmap")
      Memory=GAPIT.Memory(Memory=Memory,Infor="plot heatmap")
      }
## Jiabo Wang add NJ Tree of kinship at 4.5.2017
      if(!is.null(NJtree.group)&file.output)
        {            
        for(tr in 1:length(NJtree.type))
           {
           print("Creating NJ Tree for kinship...")
           pdf(paste("GAPIT.Kin.NJtree.",NJtree.type[tr],".pdf",sep=""), width = 12, height = 12)
           par(mar = c(5,5,5,5))
           Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="prepare NJ TREE")
           Memory=GAPIT.Memory(Memory=Memory,Infor="prepare NJ TREE")
           plot(as.phylo(hc), type = NJtree.type[tr], tip.color =type_col[clusMember],  use.edge.length = TRUE, col = "gray80",cex=0.8)
           legend("topright",legend=paste(c("Tatal individuals is: ","Cluster method: ","Group number: "), Optimum[c(1:3)], sep=""),lty=0,cex=1.3,bty="n",bg=par("bg"))
           dev.off()
           }
        }
        if(!is.null(compress_z))write.table(compress_z,paste("GAPIT.Kin.NJtree.compress_z.txt",sep=""),quote=F)
        print("Kinship NJ TREE PDF created!")
 
        Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="plot NJ TREE")
        Memory=GAPIT.Memory(Memory=Memory,Infor="plot NJ TREE")
    #rm(hc,clusMember)
      }#end 
## NJ Tree end    } #end of if(nrow(KI)<1000)
    } #end of if(KI!=1)
  } #end of if(!is.null(KI))

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Before SUPER")
Memory=GAPIT.Memory(Memory=Memory,Infor="Before SUPER")

#SUPER
if(!is.null(GP) & kinship.algorithm=="SUPER" & !is.null(bin.size) & !is.null(inclosure.size))
{
  mySpecify=GAPIT.Specify(GI=GI,GP=GP,bin.size=bin.size,inclosure.size=inclosure.size)
  SNP.QTN=mySpecify$index
  if(!is.null(GD))
  {
	  GK=GD[,SNP.QTN]
    SNPVar=apply(as.matrix(GK),2,var)
    GK=GK[,SNPVar>0]
    GK=cbind(as.data.frame(GT),as.data.frame(GK)) #add taxa  
  } 
}
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Before creating kinship")
Memory=GAPIT.Memory(Memory=Memory,Infor="Before creating kinship")

PC=NULL
thePCA=NULL

if(PCA.total>0 | kinship.algorithm=="Separation")
{
  thePCA=GAPIT.PCA(X = GD, taxa = GT, PC.number = PCA.total,file.output=file.output,PCA.total=PCA.total,PCA.col=PCA.col,PCA.3d=PCA.3d)
  PC=thePCA$PCs[,1:(1+PCA.total)]
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PCA")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PCA")
  print("PC created")
}
#Create kinship from genotype if not provide
if(is.null(KI) & (!is.null(GD) |!is.null(GK)) & !kinship.algorithm%in%c("FarmCPU","Blink","MLMM"))
{
  print("Calculating kinship...")
  if(!is.null(GK))
  {
    thisGD=GK[,-1]
    myGT=as.matrix(GK[,1])
    print("GK is used to create KI")
  }else{
    thisGD=GD
    myGT=GT
  }
  print(paste("Number of individuals and SNPs are ",nrow(thisGD)," and ",ncol(thisGD)))
  theKin=NULL
  #if(is.null(PCA.col)&!is.null(NJtree.group))PCA.col=rainbow(NJtree.group)[clusMember]
  if(kinship.algorithm=="EMMA")
    {
    half.thisGD = as.matrix(.5*thisGD)
    if(length(which(is.na(half.thisGD))) > 0)
      {
      print("Substituting missing values with heterozygote for kinship matrrix calculation....")
      half.thisGD[which(is.na(half.thisGD))] = 1
      }
      theKin= emma.kinship(snps=t(as.matrix(.5*thisGD)), method="additive", use="all")
    }
  if(kinship.algorithm=="Loiselle")theKin= GAPIT.kinship.loiselle(snps=t(as.matrix(.5*thisGD)), method="additive", use="all")
  if(kinship.algorithm=="VanRaden")theKin= GAPIT.kinship.VanRaden(snps=as.matrix(thisGD)) 
  if(kinship.algorithm=="Zhang")theKin= GAPIT.kinship.Zhang(snps=as.matrix(thisGD)) 
  if(kinship.algorithm=="Separation")theKin= GAPIT.kinship.separation(PCs=thePCA$PCs,EV=thePCA$EV,nPCs=PCA.total)
  if(!is.null(theKin))
    {
    colnames(theKin)=myGT
    rownames(theKin)=myGT
    line.names <- myGT
    if (!is.null(NJtree.group))
      {
      distance.matrix=dist(theKin,upper=TRUE)
      hc=hclust(distance.matrix,method=kinship.cluster)
      hcd = as.dendrogram(hc)
      clusMember <- cutree(hc, k = NJtree.group)
      compress_z=table(clusMember,paste(line.names))
      type_col=rainbow(NJtree.group)
      Optimum=c(nrow(theKin),kinship.cluster,NJtree.group)
      }
    print("kinship calculated")
    if(length(GT)<1000 &file.output)
      {
    #Create heat map for kinship
      print("Creating heat map for kinship...")
      pdf(paste("GAPIT.Kin.",kinship.algorithm,".pdf",sep=""), width = 12, height = 12)
      par(mar = c(25,25,25,25))
      heatmap.2(theKin,  cexRow =.2, cexCol = 0.2, col=rev(heat.colors(256)), scale="none", symkey=FALSE, trace="none")
      dev.off()
      print("Kinship heat map created")
    ## Jiabo Wang add NJ Tree of kinship at 4.5.2017
      if (!is.null(NJtree.group))      
        {
        print("Creating NJ Tree for kinship...")
        for(tr in 1:length(NJtree.type))
           {
           pdf(paste("GAPIT.Kin.NJtree.",NJtree.type[tr],".pdf",sep=""), width = 12, height = 12)
           par(mar = c(0,0,0,0))
           Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="prepare NJ TREE")
           Memory=GAPIT.Memory(Memory=Memory,Infor="prepare NJ TREE")   
           plot(as.phylo(hc), type = NJtree.type[tr], tip.color =type_col[clusMember],  use.edge.length = TRUE, col = "gray80",cex=0.6)
    #legend("topright",legend=c(paste("Tatal numerber of individuals is ",),lty=0,cex=1.3,bty="n",bg=par("bg"))
           legend("topright",legend=paste(c("Tatal individuals is: ","Group method: ","Group number: "), Optimum[c(1:3)], sep=""),lty=0,cex=1.3,bty="n",bg=par("bg"))
           dev.off()
           }
    # print(Optimum)   
        write.table(compress_z,paste("GAPIT.Kin.NJtree.compress_z.txt",sep=""),quote=F)
        print("Kinship NJ TREE PDF created!")  
        Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="plot NJ TREE")
        Memory=GAPIT.Memory(Memory=Memory,Infor="plot NJ TREE")
        rm(hc)
        }#end NJtree
      }
    print("Adding IDs to kinship...")
    #Write the kinship into a text file
    KI=cbind(myGT,as.data.frame(theKin)) #This require big memory. Need a way to solve it.
    print("Writing kinship to file...")
    if(file.output) write.table(KI, paste("GAPIT.Kin.",kinship.algorithm,".csv",sep=""), quote = FALSE, sep = ",", row.names = FALSE,col.names = FALSE)
    print("Kinship save as file")    
    rm(theKin)
    gc()
    }
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Estimating kinship")
  Memory=GAPIT.Memory(Memory=Memory,Infor="Estimating kinship")
  print("Kinship created!")
}  #end of if(is.null(KI)&!is.null(GD))

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="after creating kinship")
Memory=GAPIT.Memory(Memory=Memory,Infor="after creating kinship")

#LD plot
#print("LD section")
if(!is.null(GLD) &file.output)
  {
  if(nrow(GLD)>500)
    {
    GLD=GLD[1,]
    print("WARNING: The number of SNPs requested is beyond limitation. No LD plot created.")
    }
  if(nrow(GLD)>1)
    {
    print("Plot LD...")
    hapmapgeno= data.frame(as.matrix(t(GLD[,-c(1:11)])))
    hapmapgeno[hapmapgeno=="NN"]=NA
    hapmapgeno[hapmapgeno=="XX"]=NA
    hapmapgeno[hapmapgeno=="--"]=NA
    hapmapgeno[hapmapgeno=="++"]=NA
    hapmapgeno[hapmapgeno=="//"]=NA
    LDdist=as.numeric(as.vector(GLD[,4]))
    LDsnpName=GLD[,1]
    colnames(hapmapgeno)=LDsnpName
#Prune SNM names
#LDsnpName=LDsnpName[GAPIT.Pruning(LDdist,DPP=7)]
    LDsnpName=LDsnpName[c(1,length(LDsnpName))] #keep the first and last snp names only
#print(hapmapgeno)
    print("Getting genotype object")
    LDsnp=makeGenotypes(hapmapgeno,sep="",method=as.genotype)   #This need to be converted to genotype object
    print("Caling LDheatmap...")
    pdf(paste("GAPIT.LD.chromosom",LD.chromosome,"(",round(max(0,LD.location-LD.range)/1000000),"_",round((LD.location+LD.range)/1000000),"Mb)",".pdf",sep=""), width = 12, height = 12)
#pdf(paste("GAPIT.LD.pdf",sep=""), width = 12, height = 12)
    par(mar = c(25,25,25,25))
    MyHeatmap <- try(LDheatmap(LDsnp, LDdist, LDmeasure="r", add.map=TRUE,
    SNP.name=LDsnpName,color=rev(cm.colors(20)), name="myLDgrob", add.key=TRUE,geneMapLabelY=0.1) )
    if(!inherits(MyHeatmap, "try-error")) 
      {
  #Modify the plot
      grid.edit(gPath("myLDgrob", "Key", "title"), gp=gpar(cex=.5, col="blue"))  #edit key title size and color
      grid.edit(gPath("myLDgrob", "geneMap", "title"), gp=gpar(just=c("center","bottom"), cex=0.8, col="black")) #Edit gene map title
      grid.edit(gPath("myLDgrob", "geneMap","SNPnames"), gp = gpar(cex=0.3,col="black")) #Edit SNP name
      }else{
      print("Warning: error in converting genotype. No LD plot!")
      }
    dev.off()
    print("LD heatmap crated")
    }else{ # alternative of if(nrow(GLD)>1)
    print("Warning: There are less than two SNPs on the region you sepcified. No LD plot!")
    } #end of #if(nrow(GLD)>1)
  }#end of if(!is.null(GLD))

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="after LD plot")
Memory=GAPIT.Memory(Memory=Memory,Infor="after LD plot")


###output Marker density and decade of linkage disequilibrium over distance
if(!is.null(GI) & !is.null(GD) & file.output & Geno.View.output)
{
ViewGenotype<-GAPIT.Genotype.View(
myGI=GI,
myGD=GD,
)
}

#print("Genotype successfully acomplished")
return (list(G=G,GD=GD,GI=GI,GT=GT,hasGenotype=hasGenotype, genoFormat=genoFormat, KI=KI,PC=PC,byFile=byFile,fullGD=fullGD,Timmer=Timmer,Memory=Memory,SNP.QTN=SNP.QTN,chor_taxa=chor_taxa))
}
#=============================================================================================

`GAPIT.Genotype.View` <-function(myGI=NULL,myGD=NULL,chr=NULL, w1_start=NULL,w1_end=NULL,mav1=NULL){
# Object: Analysis for Genotype data:Distribution of SNP density,Accumulation,Moving Average of density,result:a pdf of the scree plot
# myG:Genotype data
# chr: chromosome value
# w1_start:Moving Average windows Start Position
# w1_end:Moving Average windows End Position
# mav1:Moving Average set value length
# Authors: You Tang and Zhiwu Zhang
# Last update: March 11, 2016 
##############################################################################################

#if(nrow(myGI)<1000) return() #Markers are not enough for this analysis
  
if(is.null(myGI)){stop("Validation Invalid. Please select read valid Genotype flies  !")}

if(is.null(myGD)){stop("Validation Invalid. Please select read valid Genotype flies  !")}

if(is.null(w1_start)){w1_start=1}

##if(is.null(w1_end)){w1_end=100}

if(is.null(mav1)){mav1=10}


if(is.null(chr)){chr=1}

#heterozygosity of individuals and SNPs (By Zhiwu Zhang)
  #print("Heterozygosity of individuals and SNPs (By Zhiwu Zhang)")
  X=myGD[,-1]
  H=1-abs(X-1)
  het.ind=apply(H,1,mean)
  het.snp=apply(H,2,mean)
  ylab.ind=paste("Frequency (out of ",length(het.ind)," individuals)",sep="")
  ylab.snp=paste("Frequency (out of ",length(het.snp)," markers)",sep="")
  pdf("GAPIT.Heterozygosity.pdf", width =10, height = 6)
  par(mfrow=c(1,2),mar=c(5,5,1,1)+0.1)
  hist(het.ind,col="gray", main="",ylab=ylab.ind, xlab="Heterozygosity of individuals")
  hist(het.snp,col="gray", main="",ylab=ylab.snp, xlab="Heterozygosity of markers")
  dev.off()
  rm(X, H, het.ind, het.snp) #Feree memory
myFig21<-myGI
myFig21<-myFig21[!is.na(as.numeric(as.matrix(myFig21[,3]))),]

n<-nrow(myFig21)
maxchr<-0
for(i in 1:n){
if(as.numeric(as.matrix(myFig21[i,2]))>maxchr){
maxchr<-as.numeric(as.matrix(myFig21[i,2]))
}
}
n_end<-maxchr
if(maxchr==0){
chr=0
}

#n_end<-as.numeric(as.matrix(myFig21[n,2]))
aaa<-NULL
for(i in 0:n_end){
#myChr<-myFig21[myFig21[,2]==i,]
myChr<-myFig21[as.numeric(as.matrix(myFig21[,2]))==i,]
index<-order(as.numeric(as.matrix(as.data.frame(myChr[,3]))))
aaa<-rbind(aaa,myChr[index,])

}
myFig2<-aaa

if(is.null(w1_end)){
if(nrow(myFig2[as.numeric(as.matrix(myFig2[,2]))==chr,])>100){
w1_end=100
}else{
w1_end=nrow(myFig2[as.numeric(as.matrix(myFig2[,2]))==chr,])
}
}


subResult<-matrix(0,n,1)
for(i in 1 :( n-1))
{
k<-as.numeric(as.matrix(myFig2[i+1,3]))-as.numeric(as.matrix(myFig2[i,3]))
if(k>0){
subResult[i]<-k
}
else{
subResult[i]<-0
}}
results<-cbind(myFig2,subResult)

#####Out  Distribution of SNP density ##########


#####Out Accumulation##########

kk0<-order(as.numeric(as.matrix(results[,4])))

myFig22<-results[kk0,]

m<-nrow(myFig22)

kk1<-matrix(1:m,m,1)
results2<-cbind(myFig22,kk1)
max2<-max(myFig22[,4])


pdf("GAPIT.Marker.Density.pdf", width =10, height = 6)
par(mar=c(5,5,4,5)+0.1)
hist(as.numeric(as.matrix(results[,4])),xlab="Density",main="Distribution of SNP",breaks=12, cex.axis=0.9,col = "dimgray",cex.lab=1.3)###,xlim=c(0,25040359))

par(new=T)
plot(results2[,4],results2[,5]/m,xaxt="n", yaxt="n",bg="lightgray",xlab="",ylab="",type="l",pch=20,col="#990000",cex=1.0,cex.lab=1.3, cex.axis=0.9, lwd=3,las=1,xlim=c(0,max2))
axis(4,col="#990000",col.ticks="#990000",col.axis="#990000")
mtext("Accumulation Frequency",side=4,line=3,font=2,font.axis=1.3,col="#990000")
abline(h=0,col="forestgreen",lty=2)
abline(h=1,col="forestgreen",lty=2)

dev.off()




#####Out Moving Average of density##########
#print(unique(myGI[,2]))
myGD0<-myGD[,as.numeric(myGI[,2])==chr]
gc()


myGM0<-myGI[myGI[,2]==chr,]


##remove invalid SNPs
#X<-myGD0[,-1]
X<-myGD0
colMax=apply(X,2,max)
colMin=apply(X,2,min)
#mono=as.numeric(colMax)-as.numeric(colMin)
mono=colMax-colMin

index=mono<10E-5
X=X[,!index]

myFig3<-myGM0[!index,]


n3<-nrow(myFig3)


kk3<-order(as.numeric(as.matrix(myFig3[,3])))

myFig23<-myFig3[kk3,]


myGD3<-X[,kk3]

##set windows long 
##w1_start<-30
##w1_end<-230
###get windows numeric snp at the same chr
#print(w1_start)
#print(w1_end)
#print(dim(myFig3))

if(nrow(myFig23)<w1_end)w1_end=nrow(myFig23)
#print(w1_start)
#print(w1_end)
results3_100<-myFig23[w1_start:w1_end,]
myGD3_100<-myGD3[,w1_start:w1_end]

km<-w1_end-w1_start+1
##get number of Density about snp
sum_number_Density <-0

for(j in 1:km)
{
sum_number_Density<-sum_number_Density+(j-1)

}

save_Density_Cor<-matrix(0.0,sum_number_Density,3)
save_Density_Cor_name<-matrix("",sum_number_Density,1)

countSDC<-1
for(j in 1:(km-1))
{
for(k in (j+1):km)
{

save_Density_Cor[countSDC,1]<-abs(as.numeric(as.matrix(results3_100[k,3]))-as.numeric(as.matrix(results3_100[j,3])))
save_Density_Cor[countSDC,2]<-cor(myGD3_100[,j],myGD3_100[,k])
#options(digits=8)
#save_Density_Cor[countSDC,3]<-as.numeric(as.matrix(format(cor(myGD3_100[,j],myGD3_100[,k])%*% cor(myGD3_100[,j],myGD3_100[,k]),digits=8)))
save_Density_Cor[countSDC,3]<-cor(myGD3_100[,j],myGD3_100[,k])%*% cor(myGD3_100[,j],myGD3_100[,k])
save_Density_Cor_name[countSDC,1]<-paste(results3_100[j,1],"::::",results3_100[k,1],seq="")
countSDC<-countSDC+1
}
}

#result3_30<-as.data.frame(cbind(save_Density_Cor_name,save_Density_Cor))

k3_3<-order(save_Density_Cor[,1])
result3_3<-save_Density_Cor[k3_3,]

##set moving average value

##mav1<-100

result_mav2<-matrix(0.0,sum_number_Density-mav1,1)

mav1_1<-floor(mav1/2)
mav1_1_end<-sum_number_Density-mav1+mav1_1

result_mav1<-result3_3[(mav1_1+1):mav1_1_end,1]

for(g in 1:(sum_number_Density-mav1)){
sum<-0
for(i in g:(g+mav1-1)){

sum<-sum+result3_3[i,3]

}
#result_mav2[g]<-sum/mav1*5
result_mav2[g]<-sum/mav1
}
result_mav<-cbind(result_mav1,result_mav2)

pdf("GAPIT.Marker.LD.pdf", width =10, height = 6)
par(mar = c(5,5,5,5))

plot(as.matrix(result3_3[,1]),as.matrix(result3_3[,3]),bg="dimgray",xlab="Distance",ylab="R Square",pch=1,cex=0.9,cex.lab=1.2, lwd=0.75,las=1)
#,ylim=c(0,round(max(result3_3[,3]))))

 lines(result_mav[,2]~result_mav[,1], lwd=6,type="l",pch=20,col="#990000")

dev.off()




print(paste("GAPIT.Genotype.View ", ".Two pdf generate.","successfully!" ,sep = ""))

#GAPIT.Genotype.View
}
#=============================================================================================
`GAPIT.HMP2Num` <-
function(nLines=n,fileHMP="hmp.txt",fileNum="num.txt",bit=1,SNP.effect="Add",SNP.impute="Middle",heading=TRUE, Create.indicator = FALSE, Major.allele.zero = FALSE){
    
#Object: To convert hmp file to numerical file
#Input: hmp genotype file
#Output: Numerical genotype file
#Authors: Zhiwu Zhang
# Last update: May 23, 2013 
##############################################################################################
#print("GAPIT.HMP2Num start")

setwd("/Users/Zhiwu/Dropbox/Current/paper/BigData/BUS/Robust/MaizeGBS")
fileHMP="NAMs26HM2.c10.imp.hmp.txt"
fileNum="NAMs26HM2.c10s.imp.num.txt"

bit=1
SNP.effect="Add"
SNP.impute="Middle"
Major.allele.zero = FALSE

system.time({
n=2000
fileHMPCon<-file(fileHMP, open="r")
#fileNumCon<-file(fileNum, open="r")
tt<-readLines(fileHMPCon, n=1) #header
for(i in 1:n){
  if(i %% 100 == 0)print(i)
  tt<-readLines(fileHMPCon, n=1) 
  #tt2<-na.omit(as.numeric(unlist(strsplit(tt, "\t")))) 
  tt2<-unlist(strsplit(tt, "\t"))
  #GM
  rs=tt2[1]
  chrom=tt2[3]
  pos=tt2[4]
  #GD
  GD= GAPIT.Numericalization(x=tt2[-c(1:11)],bit=bit,effect=SNP.effect,impute=SNP.impute, Major.allele.zero=Major.allele.zero)
  
  #Output
  #print(i)
  #print(tt2[12:52]) 
  #print(GD[1:41]) 
  #writeLines(tt2, fileNumCon,append=TRUE)
 
}
close.connection(fileHMPCon)
})

#print("GAPIT.HMP2Num accomplished successfully!")
}   #GAPIT.HMP2Num ends here
#=============================================================================================

`GAPIT.HapMap` <-
function(G,SNP.effect="Add",SNP.impute="Middle",heading=TRUE, Create.indicator = FALSE, Major.allele.zero = FALSE){
    #Object: To convert character SNP genotpe to numerical
    #Output: Coresponding numerical value
    #Authors: Feng Tian and Zhiwu Zhang
    # Last update: May 30, 2011
    ##############################################################################################
    print(paste("Converting HapMap format to numerical under model of ", SNP.impute,sep=""))
    #gc()
    #GAPIT.Memory.Object(name.of.trait="HapMap.Start")
    
    #GT=data.frame(G[1,-(1:11)])
    if(heading){
        GT= t(G[1,-(1:11)])
        GI= G[-1,c(1,3,4)]
    }else{
        GT=NULL
        GI= G[,c(1,3,4)]
    }
    
    
    #Set column names
    if(heading)colnames(GT)="taxa"
    colnames(GI)=c("SNP","Chromosome","Position")
    
    #Initial GD
    GD=NULL
    bit=nchar(as.character(G[2,12])) #to determine number of bits of genotype
    #print(paste("Number of bits for genotype: ", bit))
    
    print("Perform numericalization")
    
    if(heading){
        if(!Create.indicator) GD= apply(G[-1,-(1:11)],1,function(one) GAPIT.Numericalization(one,bit=bit,effect=SNP.effect,impute=SNP.impute, Major.allele.zero=Major.allele.zero))
        if(Create.indicator) GD= t(G[-1,-(1:11)])
    }else{
        if(!Create.indicator) GD= apply(G[  ,-(1:11)],1,function(one) GAPIT.Numericalization(one,bit=bit,effect=SNP.effect,impute=SNP.impute, Major.allele.zero=Major.allele.zero))
        if(Create.indicator) GD= t(G[ ,-(1:11)])
    }
    
    #set GT and GI to NULL in case of null GD
    if(is.null(GD)){
        GT=NULL
        GI=NULL
    }
    
    #print("The dimension of GD is:")
    #print(dim(GD))
    
    
    if(!Create.indicator) {print(paste("Succesfuly finished converting HapMap which has bits of ", bit,sep="")) }
    return(list(GT=GT,GD=GD,GI=GI))
}#end of GAPIT.HapMap function
#=============================================================================================
`GAPIT.IC` <-
function(DP=NULL){
#Object: To Intermediate Components 
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("GAPIT.IC in process...")

     Y=DP$Y
     PC=DP$PC
     CV=DP$CV
     GD=DP$GD

     noCV=FALSE
     if(is.null(CV)){
     noCV=TRUE
     CV=Y[,1:2]
     CV[,2]=1
     colnames(CV)=c("taxa","overall")
     print(paste("There is 0 Covarinces.",sep=""))

     }

     taxa_Y=as.character(Y[,1])
     taxa_GD=as.character(GD[,1])

     if(DP$PCA.total>0&!is.null(DP$CV))CV=GAPIT.CVMergePC(DP$CV,PC)
     if(DP$PCA.total>0&is.null(DP$CV))CV=PC

     taxa_comGD=as.character(GD[,1])
     taxa_comY=as.character(Y[,1])
     taxa_CV=as.character(CV[,1])
     taxa_comall=intersect(intersect(taxa_comGD,taxa_comY),taxa_CV)
     comCV=CV[taxa_CV%in%taxa_comall,]
     comGD=GD[taxa_comGD%in%taxa_comall,]
     comY=Y[taxa_comY%in%taxa_comall,]

     GT=as.matrix(as.character(taxa_comall))
     print(paste("There are ",length(GT)," common individuals in genotype , phenotype and CV files.",sep=""))

     if(nrow(comCV)!=length(GT))stop ("GAPIT says: The number of individuals in CV does not match to the number of individuals in genotype files.")

     print("The dimension of total CV is ")
     print(dim(comCV))

     print("GAPIT.IC accomplished successfully for multiple traits. Results are saved")
     if(DP$kinship.algorithm%in%c("FarmCPU","Blink","MLMM")){ 
        return (list(Y=comY,GT=GT,PCA=comCV,K=DP$KI,GD=comGD,GM=DP$GM,myallCV=CV,myallGD=GD))
     }else{
        return (list(Y=comY,GT=GT,PCA=comCV,K=DP$KI,GD=comGD,GM=DP$GM,myallCV=CV,myallGD=GD,myallY=Y))
     }
}  #end of GAPIT IC function
#=============================================================================================

`GAPIT.ID` <-
function(DP=NULL,IC=NULL,SS=NULL,RS=NULL,cutOff=0.01,
DPP=100000,Create.indicator=FALSE,
FDR.Rate = 1,QTN.position=NULL,plot.style="Oceanic",
file.output=TRUE,SNP.MAF=0,CG=NULL,plot.bin=10^9 ){
#Object: To Interpretation and Diagnoses 
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("GAPIT.ID in process...")
#Define the funcitno here

if(is.null(DP)&is.null(IC))#inputdata is other method result
{

GWAS=RS
  GI=RS[,1:3]
  GI=GI[order(GI[,2]),]
  GI=GI[order(GI[,1]),]
  #print(QTN.position)
  ps=RS[,4]
  nobs=nrow(RS)
  if(ncol(RS)>4)
   {maf=RS[,5]
    maf_pass=TRUE
   }
  if(ncol(RS)<5)
   {maf_pass=FALSE
   maf=0.5
   }
  rsquare_base=rep(NA,length(ps))
  rsquare=rep(NA,length(ps))
  df=rep(NA,length(nobs))
  tvalue=rep(NA,length(nobs))
  stderr=rep(NA,length(nobs))
  effect.est=rep(NA,length(nobs))

  if(is.na(maf[1]))  maf=matrix(.5,nrow(GWAS),1)
  print("Filtering SNPs with MAF..." )
	index=maf>=SNP.MAF	     
	PWI.Filtered=cbind(GI,ps,maf,nobs,rsquare_base,rsquare)#[index,]
	colnames(PWI.Filtered)=c("SNP","Chromosome","Position ","P.value", "maf", "nobs", "Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP")
  if(!is.null(PWI.Filtered))
  {
  print("Calculating FDR..." )
  PWIP <- GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure(PWI = PWI.Filtered, FDR.Rate = FDR.Rate, FDR.Procedure = "BH")
    print("QQ plot..." )
  if(file.output) GAPIT.QQ(P.values = ps, name.of.trait = name.of.trait,DPP=DPP)
   print("Manhattan plot (Genomewise)..." )
 if(file.output) GAPIT.Manhattan(GI.MP = cbind(GI[,-1],ps), name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=QTN.position,plot.style=plot.style,plot.bin=plot.bin)

 print("Manhattan plot (Chromosomewise)..." )

  #if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff)
 if(file.output) GAPIT.Manhattan(GI.MP = cbind(GI[,-1],ps), name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff,plot.bin=plot.bin)

  #Association Table
  print("Association table..." )
  #print(head(cbind(GI[,-1],ps)))
  #print(head)
  #GAPIT.Table(final.table = PWIP$PWIP, name.of.trait = name.of.trait,SNP.FDR=SNP.FDR)
 # GWAS=PWIP$PWIP[PWIP$PWIP[,9]<=DP$SNP.FDR,]
 # print(head(GWAS))
  print("Joining tvalue and stderr" )
  
        DTS=cbind(GI,df,tvalue,stderr,effect.est)
        colnames(DTS)=c("SNP","Chromosome","Position","DF","t Value","std Error","effect")	

  print("Creating ROC table and plot" )
if(file.output) myROC=GAPIT.ROC(t=tvalue,se=stderr,Vp=var(ys),trait=name.of.trait)
  print("ROC table and plot created" )
  print("MAF plot..." )
if(file.output&maf_pass) myMAF1=GAPIT.MAF(MAF=maf,P=ps,E=NULL,trait=name.of.trait)
  if(file.output){
   write.table(GWAS, paste("GAPIT.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   write.table(DTS, paste("GAPIT.", name.of.trait, ".Df.tValue.StdErr.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   #if(!byPass) write.table(GWAS.2, paste("GAPIT.", name.of.trait, ".Allelic_Effect_Estimates.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
  }#end file.output
  }#end DP

}else{ #inputdata is GAPIT3 result
  name.of.trait=DP$memo
	
GWAS=SS$GWAS
#print(head(GWAS))
Pred=SS$Pred
  GI=GWAS
  
  GI=GI[order(GI[,3]),]
  GI=GI[order(GI[,2]),]
  
  byPass=TRUE
  if(DP$kinship.algorithm%in%c("FarmCPU","MLMM","Blink"))byPass=FALSE
  if(byPass) 
{
 # print(head(SS$GWAS))
      ps=SS$TV$ps
      nobs=SS$TV$nobs
      maf=GWAS$maf
  #maf=SS$TV$maf
      rsquare_base=SS$TV$rsquare_base
      rsquare=SS$TV$rsquare
      df=SS$TV$df
      tvalue=SS$TV$tvalue
      stderr=SS$TV$stderr
      effect.est=SS$mc
      effect=SS$mc
      #GI=cbind(GI,effect)
     
   if(DP$file.output&!is.null(SS$Compression)&!is.na(SS$Compression[1,6])) GAPIT.Compression.Visualization(Compression = SS$Compression, name.of.trait = DP$name.of.trait)
  
}else{
  maf=GI$maf
  ps=GI$P.value
  nobs=GI$nobs
  rsquare_base=rep(NA,length(ps))
  rsquare=rep(NA,length(ps))
  df=rep(NA,length(nobs))
  tvalue=rep(NA,length(nobs))
  stderr=rep(NA,length(nobs))
  effect.est=GI$effect
  

  }
  if(is.na(maf[1]))  maf=matrix(.5,nrow(GI),1)
if(!is.null(IC$GD)&DP$SNP.test)
{ 
  
  print("Filtering SNPs with MAF..." )
	#index=maf>=DP$SNP.MAF	
	#PWI.Filtered=cbind(GI[,-5],rsquare_base,rsquare)
  PWI.Filtered=cbind(GWAS[,1:6],rsquare_base,rsquare)
	colnames(PWI.Filtered)=c("SNP","Chromosome","Position ","P.value", "maf", "nobs", "Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP")
  
  if(!is.null(PWI.Filtered))
  {
  #Run the BH multiple correction procedure of the results
  #Create PWIP, which is a table of SNP Names, Chromosome, bp Position, Raw P-values, FDR Adjusted P-values
  print("Calculating FDR..." )
  PWIP <- GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure(PWI = PWI.Filtered, FDR.Rate = FDR.Rate, FDR.Procedure = "BH")
  #print(str(PWIP))  
  print("QQ plot..." )
   if(DP$file.output) GAPIT.QQ(P.values = GI$P.value, name.of.trait = DP$name.of.trait,DPP=DP$DPP)
   print("Manhattan plot (Genomewise)..." )
   if(DP$file.output) GAPIT.Manhattan(GI.MP = GWAS[,2:4], name.of.trait = DP$name.of.trait, DPP=DP$DPP, plot.type = "Genomewise",cutOff=DP$cutOff,seqQTN=DP$QTN.position,plot.style=DP$plot.style,plot.bin=DP$plot.bin,chor_taxa=DP$chor_taxa)
   #print("@@@@@@@@@@@@@@@@@@@@@@@@")
   print("Manhattan plot (Chromosomewise)..." )

 if(DP$file.output) GAPIT.Manhattan(GI.MP = GWAS[,2:4],GD=IC$GD[,-1], CG=DP$CG,name.of.trait = DP$name.of.trait, DPP=DP$DPP, plot.type = "Chromosomewise",cutOff=DP$cutOff,plot.bin=DP$plot.bin)

  #Association Table
  print("Association table..." )
  
  print("Joining tvalue and stderr" )
  #print(head(GWAS))
  
   if(!is.null(DP$chor_taxa))
   {
     chro=as.numeric(as.matrix(GWAS[,2]))
     for(i in 1:length(chro))
     {
      chro[chro==i]=DP$chor_taxa[i]
     }
     GWAS[,2]=chro
   }
   #print(head(GWAS))
   #print(head(DP$GM))
  # print(length(tvalue))
  # print(length(stderr))
  # print(length(effect.est))
        DTS=cbind(GWAS[,1:3],df,tvalue,stderr,effect.est)
        colnames(DTS)=c("SNP","Chromosome","Position","DF","t Value","std Error","effect")	

  print("Creating ROC table and plot" )
if(DP$file.output) myROC=GAPIT.ROC(t=tvalue,se=stderr,Vp=var(as.matrix(DP$Y[,2])),trait=DP$name.of.trait)
  print("ROC table and plot created" )

  print("MAF plot..." )
if(DP$file.output) myMAF1=GAPIT.MAF(MAF=maf,P=ps,E=NULL,trait=DP$name.of.trait)

print("GAPIT.Interactive.Manhattan")
print(DP$Inter.type)
#GI=GI[order(GI[,4]),]
#print(head(GI))
if(ncol(GI)>1)
{new_GI=merge(PWIP$PWIP,GI[,c("SNP","effect")],by.x="SNP",by.y="SNP")
}else{
  new_GI=GI
}
new_GI=new_GI[order(new_GI[,4]),]

#print(head(new_GI))
if(DP$file.output&DP$Inter.Plot) GAPIT.Interactive.Manhattan(GWAS=new_GI,X_fre=maf,plot.type=DP$Inter.type,name.of.trait = DP$name.of.trait)

   if(!is.null(DP$chor_taxa))
   {
     chro=as.numeric(as.matrix(new_GI[,2]))
     for(i in 1:length(chro))
     {
      chro[chro==i]=DP$chor_taxa[i]
     }
     new_GI[,2]=chro
   }
if(DP$file.output){
   write.table(new_GI, paste("GAPIT.", DP$name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   write.table(DTS, paste("GAPIT.", DP$name.of.trait, ".Df.tValue.StdErr.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   #print(head(GWAS.2))
   #if(byPass) write.table(GWAS.2[,1:4], paste("GAPIT.", DP$name.of.trait, ".Allelic_Effect_Estimates.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
     }#end file.output
  }#PWI.Filtered
}#end IC$GD)
  print("GAPIT.ID accomplished successfully for multiple traits. Results are saved")
  return ()
}#is.null(DP)&is.null(IC)

}  #end of GAPIT.ID function
#=============================================================================================

`GAPIT.Imputation` <-
function(x,GI=NULL,impute="Middle",byRow=TRUE){
#Object: To impute NA in genome
#Output: Coresponding numerical value
#Authors: Zhiwu Zhang
#Writer:  Jiabo Wang
# Last update: April 13, 2016 
##############################################################################################
n=length(x)
lev=levels(as.factor(x))
lev=setdiff(lev,NA)
#print(lev)
len=length(lev)
count=1:len
for(i in 1:len){
	count[i]=length(x[(x==lev[i])])
}
position=order(count)
#print(position)
if(impute=="Middle") {x[is.na(x)]=1 }

if(len==3){
	if(impute=="Minor")  {x[is.na(x)]=position[1]  -1}
	if(impute=="Major")  {x[is.na(x)]=position[len]-1}

}else{
	if(impute=="Minor")  {x[is.na(x)]=2*(position[1]  -1)}
	if(impute=="Major")  {x[is.na(x)]=2*(position[len]-1)}
}

if(byRow) {
  result=matrix(x,n,1)
}else{
  result=matrix(x,1,n)  
}


return(result)
}#end of GAPIT.Numericalization function
#=============================================================================================







`GAPIT.Interactive.GS`<-
function(model_store=NULL,Y=NULL,myGD=NULL,myGM=NULL,myKI=NULL,myY=NULL,myCV=NULL,rel=NULL,h2=NULL,NQTN=NULL
  )
#model_store is the store of all model names
#Y is the real phenotype
#
{ 

# e=20
# #NQTN=100
# #h2=0.25
# taxa=as.character(myGD[,1])
# myY=Y0[Y0[,1]%in%taxa,c(1,e)]
# myGD=myGD[taxa%in%myY[,1],]
# nfold=5
# repli=1
# sets=sample(cut(1:nrow(myY ),nfold,labels=FALSE),nrow(myY ))


# j=1
# training=myY
# training[sets==j,2]=NA
# training_index=is.na(training[,2])
# testing=myY[training_index,]

# cblup_gapit=GAPIT(Y=training,CV=PC,PCA.total=0,KI=myKI,group.from=200,group.to=2000,group.by=600,SNP.test=F,file.output=F)
# gblup_gapit=GAPIT(Y=training,CV=PC,PCA.total=0,KI=myKI,group.from=2000,group.to=2000,group.by=100,SNP.test=F,file.output=F)
# sblup_gapit=GAPIT(Y=training,CV=PC,PCA.total=0,GD=myGD,GM=myGM,group.from=2000,SUPER_GS=TRUE,sangwich.top="MLM",sangwich.bottom="SUPER",LD=0.1,SNP.test=F,file.output=F,inclosure.from=200,inclosure.to=1000,inclosure.by=200,bin.from=10000,bin.to=100000,bin.by=10000)

# cblup_pred=cblup_gapit$Pred[training_index,]
# gblup_pred=gblup_gapit$Pred[training_index,]
# sblup_pred=sblup_gapit$Pred[training_index,]
# testing_index=!is.na(testing[,2])

# gblup_r_once=cor(testing[testing_index,2],gblup_pred[testing_index,8])
# cblup_r_once=cor(testing[testing_index,2],cblup_pred[testing_index,8])
# sblup_r_once=cor(testing[testing_index,2],sblup_pred[testing_index,8])
# result=cbind(testing[testing_index,],gblup_pred[testing_index,8],cblup_pred[testing_index,8],sblup_pred[testing_index,8])
# colnames(result)=c("taxa","observed","gBLUP","cBLUP","sBLUP")

# gblup_r_once
# cblup_r_once
# sblup_r_once

# write.table(result,paste("gcs_",e,".txt",sep=""))




myY=read.table(paste("gcs_",e,".txt",sep=""),head=T)
Observed=myY$observed
Predicted=myY$gBLUP
if(!require(plotly)) install.packages("plotly")
  library(plotly)

  p <- plot_ly(
    type = 'scatter',
    x = ~Observed,
    y = ~Predicted,
    data=myY,
    text = ~paste("Taxa: ",taxa,"<br>Observed: ",round(observed,4) , '<br>gBLUP:', round(gBLUP,4)),
    #size=2*y/max(y),
    color = I("red"),
    name=c("gBLUP")
    )%>%add_trace(
    type = 'scatter',
    x = ~observed,
    y = ~cBLUP,
    #data=myY,
    text = ~paste("Taxa: ",taxa,"<br>Observed: ",round(observed,4)  , '<br>cBLUP:', round(cBLUP,4)),
    #size=2*y/max(y),
    color = I("blue"),
    name=c("cBLUP")
    )%>%add_trace(
    type = 'scatter',
    x = ~observed,
    y = ~sBLUP,
    #data=myY,
    text = ~paste("Taxa: ",taxa,"<br>Observed: ",round(observed,4)  , '<br>sBLUP:', round(sBLUP,4)),
    #size=2*y/max(y),
    color = I("green"),
    name=c("sBLUP")
    )

    htmltools::save_html(p, "Interactive.GS.html")


}



`GAPIT.Interactive.Manhattan`<-
function(GWAS=NULL,MAF.threshold=seq(0,0.5,.1),cutOff=0.01,DPP=50000,X_fre=NULL,plot.type=c("m","q"),name.of.trait = "Trait"
  )
{   
    if(is.null(GWAS)) stop("Please add GWAS result in here!!!")
 
    MP=GWAS[,2:4]
    #print(head(GWAS))
    GWAS=GWAS[order(GWAS[,3]),]
    GWAS=GWAS[order(GWAS[,2]),]
    #print(GWAS[GWAS[,4]==min(GWAS[,4]),2])

    taxa=as.character(GWAS[,1])
    numMarker=nrow(GWAS)
    bonferroniCutOff01=-log10(0.01/numMarker)
    bonferroniCutOff05=-log10(0.05/numMarker)
    # deal with P value to log
    Ps=as.numeric(as.vector(GWAS[,4]))
    logPs <-  -log10(Ps)
    logPs[is.na(logPs)]=0
    
    y.lim <- ceiling(max(GWAS[,4]))
    chrom_total=as.numeric(as.character((GWAS[,2])))
    #print(GWAS[GWAS[,4]==min(GWAS[,4]),])
    #print("!!!!")
    #print(chrom_total[logPs==max(logPs)])
    POS=as.numeric(as.vector(GWAS[,3]))
    #print(head(POS))
    chm.to.analyze <- as.numeric(as.character(unique(GWAS[,2])))
    chm.to.analyze=chm.to.analyze[order(as.numeric(as.character(chm.to.analyze)))]
    #chm.to.analyze = factor(sort(chm.to.analyze))

    numCHR= length(chm.to.analyze)
    print(chm.to.analyze)

    ticks=NULL
    lastbase=0
    
        #change base position to accumulatives (ticks)
        for (i in chm.to.analyze)
        {
            index=(chrom_total==i)
            ticks <- c(ticks, lastbase+mean(POS[index]))
            POS[index]=POS[index]+lastbase
            lastbase=max(POS[index])
        }

        x0 <- POS
        y0 <- as.numeric(logPs)
        z0 <- chrom_total
        posi0<-as.numeric(as.vector(GWAS$Position))
        maf0 <- as.numeric(as.vector(GWAS$maf))
        effect0<- as.numeric(as.vector(GWAS$effect))
        #print(head(z0))
        position=order(y0,decreasing = TRUE)
        index0=GAPIT.Pruning(y0[position],DPP=DPP)
        index=position[index0]
        #order by P value
        x=x0[index]
        y=y0[index]
        z=z0[index]
        taxa=taxa[index]
        posi=posi0[index]
        maf=maf0[index]
        effect=effect0[index]
    
        plot.color=rep(c(  '#EC5f67',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5'),ceiling(numCHR/5))
    

if(c("m")%in%plot.type)
{

  Position=x
  P_value=y
  z[z<10]=paste("0",z[z<10],sep="")
  zz=paste("Chr_",z,sep="")
  #print(zz)
  if(!require(plotly)) install.packages("plotly")
  #print("!!!!!")
  #print(head(Position))
  library(plotly)
  p <- plot_ly(
    type = 'scatter',
    x = ~Position,
    y = ~P_value,
    colorscale='Viridis',
    reversescale =T,
    #symbol="circle",
    text = ~paste("SNP: ", taxa, "<br>Posi: ", posi,"<br>MAF: ", round(maf,2),"<br>Effect: ",round(effect,2)),
    color = ~as.character(zz)
    )%>%
  add_trace(y=bonferroniCutOff01,name = 'CutOff-0.01',color=I("red"),mode="line",width=1.4,text="")%>%
  add_trace(y=bonferroniCutOff05,name = 'CutOff-0.05',color=I("red"),mode="line",line=list(width=1.4,dash='dot'),text="")%>%
  layout(title = "Interactive.Manhattan.Plot",
         #showticklabels = FALSE,
         #legend = list(orientation = 'h'),
         xaxis = list(title = "Chromsome",zeroline = FALSE,showticklabels = FALSE),
         yaxis = list (title = "-Log10(p)"))

    htmltools::save_html(p, paste("Interactive.Manhattan.",name.of.trait,".html",sep=""))
}


################ for QQ plot
if(c("q")%in%plot.type)
{
        P.values=y
        p_value_quantiles <- (1:length(P.values))/(length(P.values)+1)
        log.P.values <- P.values
        log.Quantiles <- -log10(p_value_quantiles)
        
        index=GAPIT.Pruning(log.P.values,DPP=DPP)
        log.P.values=log.P.values[index ]
        log.Quantiles=log.Quantiles[index]
        N=length(P.values)
        N1=length(log.Quantiles)
        ## create the confidence intervals
        c95 <- rep(NA,N1)
        c05 <- rep(NA,N1)
        for(j in 1:N1){
            i=ceiling((10^-log.Quantiles[j])*N)
            if(i==0)i=1
            c95[j] <- qbeta(0.95,i,N-i+1)
            c05[j] <- qbeta(0.05,i,N-i+1)
            #print(c(j,i,c95[j],c05[j]))
        }
        
        #CI shade
        #plot3d(NULL, xlim = c(0,max(log.Quantiles)), zlim = c(0,max(log.P.values)), type="l",lty=5, lwd = 2, axes=FALSE, xlab="", ylab="",col="gray")
        index=length(c95):1
        zz=paste("Chr_",z,sep="")
        Expected=log.Quantiles
        Observed=log.P.values
        #abline(a = 0, b = 1, col = "red",lwd=2)
        qp <- plot_ly(
    type = 'scatter',
    x = ~Expected,
    y = ~Observed,
    text = ~paste("SNP: ", taxa,"<br>Chr: ",zz,"<br>Posi: ", posi, "<br>MAF: ", round(maf,2),"<br>Effect: ",round(effect,2)),
    #size=2*y/max(y),
    name = "SNP",
    opacity=0.5,
    )%>%add_lines(x=log.Quantiles,y=log.Quantiles,color=I("red"), 
    mode = 'lines',name="Diag",text="")%>%
    layout(title = "Interactive.QQ.Plot",
        xaxis = list(title = "Expected -Log10(p)"),
         yaxis = list (title = "Observed -Log10(p)"),
         #showticklabels = FALSE,
         showlegend = FALSE)
        htmltools::save_html(qp, paste("Interactive.QQ ",name.of.trait,".html",sep=""))


}   
print("GAPIT.Interactive.Plot has done !!!")

}#end of GAPIT.Interactive.Manhattan
#=============================================================================================





`GAPIT.Judge`<-
function(Y=Y,G=NULL,GD=NULL,KI=NULL,GM=NULL,group.to=group.to,group.from=group.from,sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,kinship.algorithm=kinship.algorithm,PCA.total=PCA.total,model="MLM",SNP.test=TRUE){
#Object: To judge Pheno and Geno data practicability
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("--------------------Phenotype and Genotype ----------------------------------")
if(ncol(Y)<2)  stop ("Phenotype should have taxa name and one trait at least. Please correct phenotype file!")
print(kinship.algorithm)
if(is.null(KI)&is.null(GD) & kinship.algorithm!="SUPER"&is.null(G)) stop ("GAPIT says: Kinship is required. As genotype is not provided, kinship can not be created.")
if(kinship.algorithm=="FarmCPU"&SNP.test==FALSE)stop("FarmCPU is only for GWAS, plase set: SNP.test= TRUE")
#if((!is.null(GD))&(!is.null(G))) stop("GAPIT Says:Please put in only one type of geno data.")
if(is.null(GD)&is.null(G)&is.null(KI))stop ("GAPIT Says:GAPIT need genotype!!!")
if(!is.null(GD) & is.null(GM) & (is.null(G)) &SNP.test) stop("GAPIT Says: Genotype data and map files should be in pair")
if(is.null(GD) & !is.null(GM) & (is.null(G)) &SNP.test) stop("GAPIT Says: Genotype data and map files should be in pair")
if (is.null(GD[,1]%in%Y[,1])|is.null(colnames(G)[-c(1:11)]%in%Y[,1]))stop("GAPIT Says: There are no common taxa between genotype and phenotype")
if (!is.null(Y)) nY=nrow(Y)
if (!is.null(Y)) ntrait=ncol(Y)-1
print(paste("There are ",ntrait," traits in phenotype data."))
print(paste("There are ",nY," individuals in phenotype data."))
if (!is.null(G)) nG=nrow(G)-11
if (!is.null(GD)) 
{nG=ncol(GD)-1
print(paste("There are ",nG," markers in genotype data."))}
print("Phenotype and Genotype are test OK !!")

print("--------------------GAPIT Logical ----------------------------------")
#if (group.to>nY&is.null(KI))group.to=nY
#if (group.from>group.to&is.null(KI)) group.from=group.to
if(!is.null(sangwich.top) & is.null(sangwich.bottom) ) stop("GAPIT Says: SUPER method need sangwich.top and bottom")
if(is.null(sangwich.top) & !is.null(sangwich.bottom) ) stop("GAPIT Says: SUPER method need sangwich.top and bottom")
 if(kinship.algorithm=="Separation"&PCA.total==0) stop ("GAPIT Says: Separation kinship need PCA.total>0")







return (list(group.to=group.to,group.from=group.from))
}#end of GAPIT.Pheno.Geno.judge function
#=============================================================================================







`GAPIT.Liner` <-
function(Y,GD,CV){
    #Object: To have Y, GD and CV the same size and order
    #Input: Y,GDP,GM,CV
    #Input: GD - n by m +1 dataframe or n by m big.matrix
    #Input: GDP - n by m matrix. This is Genotype Data Pure (GDP). THERE IS NOT COLUMN FOR TAXA. 
    #Input: orientation-Marker in GDP go colmun or row wise
    #Requirement: Y, GDP and CV have same taxa order. GDP and GM have the same order on SNP
    #Output: GWAS,GPS,Pred
    #Authors: Zhiwu Zhang
    # Last update: Febuary 24, 2013
    ##############################################################################################
    #print("GAPIT.Liner Started")
    #print(date())
    #print("Memory used at begining of BUS")
    #print(memory.size())
    #print("dimension of Y,GD and CV at begining")
    #print(dim(Y))
    #print(dim(GD))
    #print(dim(CV))
    
    if(!is.null(CV))taxa=intersect(intersect(GD[,1],Y[,1]),CV[,1])
    if(is.null(CV))taxa=intersect(GD[,1],Y[,1])

    Y=Y[match(taxa, Y[,1], nomatch = 0),]
    GD=GD[match(taxa, GD[,1], nomatch = 0),]
    
    if(!is.null(CV)) CV=CV[match(taxa, CV[,1], nomatch = 0),]
    Y = Y[order(Y[,1]),]
    GD = GD[order(GD[,1]),]
    if(!is.null(CV)) CV = CV[order(CV[,1]),]

    #print("dimension of Y,GD and CV at end")
    #print(dim(Y))
    #print(dim(GD))
    #print(dim(CV))
    
  print("GAPIT.Liner accomplished successfully")
  return (list(Y=Y,GD=GD,CV=CV))
}#The function GAPIT.Liner ends here
#=============================================================================================

`GAPIT.Log` <-
function(Y=Y,KI=KI,Z=Z,CV=CV,SNP.P3D=SNP.P3D,
				group.from = group.from ,group.to =group.to ,group.by = group.by ,kinship.cluster = kinship.cluster, kinship.group= kinship.group,
                      	ngrid = ngrid , llin = llin , ulim = ulim , esp = esp ,name.of.trait = name.of.trait){
#Object: To report model factors
#Output: Text file (GAPIT.Log.txt)
#Authors: Zhiwu Zhang
# Last update: may 16, 2011 
##############################################################################################

#Creat storage
facto <- list(NULL)
value <- list(NULL)

#collecting model factors

facto[[1]]="Trait"
value[[1]]=paste(dim(Y))

facto[[2]]="group.by "
value[[2]]=group.by 

facto[[3]]="Trait name "
value[[3]]=name.of.trait

facto[[4]]="Kinship"
value[[4]]=dim(KI)

facto[[5]]="Z Matrix"
value[[5]]=dim(Z)

facto[[6]]="Covariate"
value[[6]]=dim(CV)

facto[[7]]="SNP.P3D"
value[[7]]=SNP.P3D

facto[[8]]="Clustering algorithms"
value[[8]]=kinship.cluster

facto[[9]]="Group kinship"
value[[9]]=kinship.group

facto[[10]]="group.from "
value[[10]]=group.from 

facto[[11]]="group.to "
value[[11]]=group.to 



theLog=as.matrix(cbind(facto,value))
#theLog=as.character(as.matrix(cbind(facto,value)))
colnames(theLog)=c("Model", "Value")
file=paste("GAPIT.", name.of.trait,".Log.csv" ,sep = "")
write.table(theLog, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

return (theLog)
}
#=============================================================================================

`GAPIT.MAF` <-
function(MAF=NULL,P=NULL,E=NULL,trait="",threshold.output=.1,plot.style="rainbow"){
    #Object: To display probability and effect over MAF
    #Input: MAF vector of MAF
    #Input: P vector of P values
    #Output: A table and plot
    #Requirment: NA
    #Authors: Zhiwu Zhang
    # Start  date: April 5, 2013
    # Last update: Oct 27, 2015 by Jiabo Wang add notice for P<0.1 is empty
    ##############################################################################################
    #print("MAF plot started")
    #print(threshold.output)
    #Remove NAs and under threshold
    index= which(P<threshold.output & !is.na(MAF))
    MAF=MAF[index]
    #E=E[index]
    P=P[index]
LP=-log10(P) 
LPC=round(LP*10,digits = 0)+20
ncolors=max(LPC,na.rm=T)
if(ncolors > 1024) {ncolors=1024}
if(ncolors==-Inf) 
{
print("There are no significant gene by this method(<0.1)")
}else{
#print("MAF plot started 0001")
#print(length(P))
#print(ncolors)
#palette(rainbow(ncolors))
#palette(gray(seq(.9,0,len = ncolors)))
#print("MAF plot started 0001b")
pdf(paste("GAPIT.", trait,".MAF.pdf" ,sep = ""), width = 5,height=5) 
par(mar = c(5,6,5,3))
theColor=heat.colors(ncolors, alpha = 1)
palette(rev(theColor))
plot(MAF,LP,type="p",lty = 1,lwd=2,col=LPC,xlab="MAF",ylab =expression(Probability~~-log[10](italic(p))),main = trait, cex.axis=1.1, cex.lab=1.3)
#for(i in 2:nc){
#lines(power[,i]~FDR, lwd=2,type="o",pch=i,col=i)
#}
#legend("bottomright", colnames(power), pch = c(1:nc), lty = c(1,2),col=c(1:nc))
palette("default")      # reset back to the default
dev.off()
}
}   #GAPIT.MAF ends here
#=============================================================================================

`GAPIT.Main` <-
function(Y,G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,CV.Inheritance=NULL,SNP.P3D=TRUE,GP=NULL,GK=NULL,
                group.from=1000000 ,group.to=1,group.by=10,kinship.cluster="average", kinship.group='Mean',kinship.algorithm=NULL,DPP=50000,
               	ngrid = 100, llin = -10, ulim = 10, esp = 1e-10,GAPIT3.output=TRUE,
                file.path=NULL,file.from=NULL, file.to=NULL, file.total=NULL, file.fragment = 512, file.G=NULL, file.Ext.G=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL,
                SNP.MAF=0,FDR.Rate=1,SNP.FDR=1,SNP.effect="Add",SNP.impute="Middle",PCA.total=0,  GAPIT.Version=GAPIT.Version,
                name.of.trait, GT = NULL, SNP.fraction = 1, seed = 123, BINS = 20,SNP.test=TRUE,SNP.robust="FaST",
                LD.chromosome=NULL,LD.location=NULL,LD.range=NULL,model=model,
                bin.from=10000,bin.to=5000000,bin.by=1000,inclosure.from=10,inclosure.to=1000,inclosure.by=10,
                SNP.permutation=FALSE,SNP.CV=NULL,NJtree.group=NJtree.group,NJtree.type=NJtree.type,plot.bin=plot.bin,
                genoFormat=NULL,hasGenotype=NULL,byFile=NULL,fullGD=NULL,PC=NULL,GI=NULL, Timmer = NULL, Memory = NULL,
                sangwich.top=NULL,sangwich.bottom=NULL,QC=TRUE,GTindex=NULL,LD=0.05,
                file.output=TRUE,cutOff=0.05, Model.selection = FALSE, Create.indicator = FALSE,
				QTN=NULL, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = FALSE,
        QTN.position=NULL,SUPER_GD=NULL,SUPER_GS=SUPER_GS,plot.style="Beach",CG=CG,chor_taxa=chor_taxa){
#Object: To perform GWAS and GPS (Genomic Prediction or Selection)
#Output: GWAS table (text file), QQ plot (PDF), Manhattan plot (PDF), genomic prediction (text file), and
#        genetic and residual variance components
#Authors: Zhiwu Zhang
# Last update: Oct 23, 2015  by Jiabo Wang add REML threshold and SUPER GD KI
##############################################################################################

#Initial p3d and h2.opt temporaryly
  h2.opt=NULL
  p3d=list(
    ps=NULL,
    REMLs=NULL,
    stats=NULL,
    effect.est=NULL,
    rsquare_base=NULL,
    rsquare=NULL,
    dfs=NULL,
    df=NULL,
    tvalue=NULL,
    stderr=NULL,
    maf=NULL,
    nobs=NULL,
    Timmer=NULL,
    Memory=NULL,
    vgs=NULL,
    ves=NULL,
    BLUP=NULL,
    BLUP_Plus_Mean=NULL,
    PEV=NULL,
    BLUE=NULL,
    logLM=NULL,
    effect.snp=NULL,
    effect.cv=NULL
  )
  
  
if (SUPER_GS)
{
Compression=NULL
kinship.optimum=NULL
kinship=NULL
PC=PC
REMLs=NULL
GWAS=NULL
QTN=NULL
Timmer=GAPIT.Timmer(Infor="GAPIT.SUPER.GS")
Memory=GAPIT.Memory(Infor="GAPIT.SUPER.GS")
#print(model)
SUPER_GS_GAPIT=GAPIT.SUPER.GS(Y=Y,G=G,GD=GD,GM=GM,KI=KI,Z=Z,CV=CV,GK=GK,kinship.algorithm=kinship.algorithm,
                      bin.from=bin.from,bin.to=bin.to,bin.by=bin.by,inclosure.from=inclosure.from,inclosure.to=inclosure.to,inclosure.by=inclosure.by,
				        group.from=group.from,group.to=group.to,group.by=group.by,kinship.cluster=kinship.cluster,kinship.group=kinship.group,name.of.trait=traitname,
                        file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM, 
                        SNP.MAF= SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,PCA.total=PCA.total,GAPIT.Version=GAPIT.Version,
                        GT=GT, SNP.fraction = SNP.fraction, seed = seed, BINS = BINS,SNP.test=SNP.test,DPP=DPP, SNP.permutation=SNP.permutation,
                        LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,SNP.CV=SNP.CV,SNP.robust=SNP.robust,model=model,
                        genoFormat=genoFormat,hasGenotype=hasGenotype,byFile=byFile,fullGD=fullGD,PC=PC,GI=GI,Timmer = Timmer, Memory = Memory,
                        sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,QC=QC,GTindex=GTindex,LD=LD,file.output=file.output,cutOff=cutOff
                        )
	print("SUPER_GS_GAPIT FUNCTION DONE")	
	return (list(Compression=SUPER_GS_GAPIT$Compression,kinship.optimum=SUPER_GS_GAPIT$SUPER_kinship,kinship=SUPER_GS_GAPIT$kinship, PC=SUPER_GS_GAPIT$PC,GWAS=GWAS, GPS=SUPER_GS_GAPIT$GPS,Pred=SUPER_GS_GAPIT$Pred,Timmer=Timmer,Memory=Memory,SUPER_GD=SUPER_GS_GAPIT$SUPER_GD,GWAS=NULL,QTN=NULL))
					
}else{
#print("@@@@@@@")
#print(group.from)

#Handler of SNP.test=F
#Iniciate with two by seven NA matrix
#The seventh is for p values of SNP
DTS=rbind(rep(NA,7),rep(NA,7) )
  
  
#End imediatly in one of these situtiona
shortcut=FALSE
LL.save=1e10
#In case of null Y and null GP, sent back genotype only  
thisY=Y[,2]
thisY=thisY[!is.na(thisY)]
if(length(thisY) <3){
 shortcut=TRUE
 }else{
  if(var(thisY) ==0) shortcut=TRUE
}
        
if(shortcut){
print(paste("Y is empty. No GWAS/GS performed for ",name.of.trait,sep=""))
return (list(compression=NULL,kinship.optimum=NULL, kinship=KI,PC=PC,GWAS=NULL, GPS=NULL,Pred=NULL, REMLs=NULL,Timmer=Timmer,Memory=Memory,h2=NULL))
}

#QC
print("------------Examining data (QC)------------------------------------------")
if(is.null(Y)) stop ("GAPIT says: Phenotypes must exist.")
if(is.null(KI)&missing(GD) & kinship.algorithm!="SUPER") stop ("GAPIT says: Kinship is required. As genotype is not provided, kinship can not be created.")

#When GT and GD are missing, force to have fake ones (creating them from Y),GI is not required in this case
if(is.null(GD) & is.null(GT)) {
	GT=as.matrix(Y[,1])
	GD=matrix(1,nrow(Y),1)	
  GI=as.data.frame(matrix(0,1,3) )
  colnames(GI)=c("SNP","Chromosome","Position")
}

if(is.null(GT)) {
  GT=as.character(Y[,1])
}
#print("@@@@@@@@")
#print(GD)
#merge CV with PC: Put CV infront of PC
if(PCA.total>0&!is.null(CV))CV=GAPIT.CVMergePC(CV,PC)
if(PCA.total>0&is.null(CV))CV=PC
#for GS merge CV with GD name
if (is.null(CV))
    {my_allCV=CV
    }else{
    
    taxa_GD=rownames(GD)
    
    my_allCV=CV[order(CV[,1]),]
    my_allCV=my_allCV[my_allCV[,1]%in%taxa_GD,]
    #print(dim(my_allCV))
    }

#Handler of CV.Inheritance
if(is.null(CV) & !is.null(CV.Inheritance)){
  stop ("GAPIT says: CV.Inheritance is more than avaiable.")
}

if(!is.null(CV)& !is.null(CV.Inheritance)){  
  if(CV.Inheritance>(ncol(CV)-1)) stop ("GAPIT says: CV.Inheritance is more than avaiable.")
}

#Create Z as identity matrix from Y if it is not provided
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & is.null(Z)){
taxa=as.character(Y[,1]) #this part will make GS without CV not present all prediction
Z=as.data.frame(diag(1,nrow(Y)))
#taxa=as.character(KI[,1])
#Z=as.data.frame(diag(1,nrow(KI)))
Z=rbind(taxa,Z)
taxa=c('Taxa',as.character(taxa))
Z=cbind(taxa,Z)
}
ZI=Z

#Add the part of non proportion in Z matrix
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & !is.null(Z))
{
  if(nrow(Z)-1<nrow(Y)) Z=GAPIT.ZmatrixFormation(Z=Z,Y=Y)
}

#Create CV with all 1's if it is not provided
noCV=FALSE
if(is.null(CV)){
noCV=TRUE
CV=Y[,1:2]
CV[,2]=1
colnames(CV)=c("taxa","overall")
}

#Remove duplicat and integragation of data
print("QC is in process...")

CVI <- CV

# print(dim(Z))
if(QC)
{
  qc <- GAPIT.QC(Y=Y,KI=KI, GT=GT,CV=CV,Z=Z,GK=GK)
  GTindex=qc$GTindex
  Y=qc$Y
  KI=qc$KI
  CV=qc$CV
  Z=qc$Z
  GK=qc$GK
  if(noCV)CVI=qc$CV #this part will make GS without CV not present all prediction
  my_taxa=as.character(KI[,1])
}
#print(GTindex)

#print(dim(KI))
#Output phenotype
colnames(Y)=c("Taxa",name.of.trait)
if(file.output)
{try(write.table(Y, paste("GAPIT.", name.of.trait,".phenotype.csv" ,sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE))
}
#TDP
if(kinship.algorithm=="None" )
{
	if(min(CV[,2])==max(CV[,2])) CV=NULL
	
	theTDP=GAPIT.TDP(Y=Y,CV=CV,SNP=as.data.frame(cbind(GT[GTindex],as.matrix(as.data.frame(GD[GTindex,])))),
			QTN=QTN, Round=QTN.round,QTN.limit=QTN.limit, QTN.update=QTN.update, Method=QTN.method)
#print(dim(GM))
#print(length(theTDP$p))

theGWAS=cbind(GM,theTDP$p,NA,NA,NA)	

return (list(Compression=NULL,kinship.optimum=NULL, kinship=NULL,PC=NULL,GWAS=theGWAS, GPS=NULL,Pred=NULL,REMLs=NULL,QTN=theTDP$QTN,Timmer=Timmer,Memory=Memory,h2= NULL))
}

rm(qc)
gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="QC")
Memory=GAPIT.Memory(Memory=Memory,Infor="QC")

#Get indicator of sangwich top and bottom
byPass.top=FALSE
byPass=FALSE
NOBLUP=FALSE
if(group.from<2&group.to<2) NOBLUP=TRUE
#if(!is.null(sangwich.bottom)) byPass=((sangwich.bottom=="FaST" | sangwich.bottom=="SUPER" | sangwich.bottom=="DC" )& is.null(GP)   )
if(!is.null(sangwich.top)) byPass.top=((sangwich.top=="FaST" | sangwich.top=="SUPER" | sangwich.top=="DC" )                 )
if(!is.null(sangwich.bottom)) byPass=((sangwich.bottom=="FaST" | sangwich.bottom=="SUPER" | sangwich.bottom=="DC" )                 )

print("Try to group from and to were set to 1")

if(byPass){
print("group from and to were set to 1")
  group.from=1
  group.to=1
}

print("------------Examining data (QC) done-------------------------------------")

#Sagnwich top bun: To gep GP if it is not provided
if(!is.null(sangwich.top) & is.null(GP))
{
print("-------------------Sandwich top bun-----------------------------------")
#print(dim(GD))
#print(GD[1:5,1:5])

#Create GK if not provided
  if(is.null(GK)){
#    set.seed(1)
    nY=floor(nrow(Y)*.9)
    nG=ncol(GD)
    if(nG>nY){snpsam=sample(1:nG,nY)}else{snpsam=1:nG}
    GK=GD[GTindex,snpsam]
    SNPVar=apply(as.matrix(GK),2,var)
    GK=GK[,SNPVar>0]
    GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa
    
  }
  
  #myGD=cbind(as.data.frame(GT),as.data.frame(GD)) 
  file.output.temp=file.output
  file.output=FALSE
  #print(sangwich.top)
  GP=GAPIT.Bread(Y=Y,CV=CV,Z=Z,KI=KI,GK=GK,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,method=sangwich.top,GTindex=GTindex,LD=LD,file.output=file.output)$GWAS
  file.output=file.output.temp
  
  
  
  GK=NULL
  
print("-------------------Sagnwich top bun: done-----------------------------")  

} 

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="SagnwichTop")
Memory=GAPIT.Memory(Memory=Memory,Infor="SagnwichTop")

#Sandwich burger and dressing
print("-------------------Sandwich burger and dressing------------------------")

#Handler of group boundry
if(group.from>group.to) stop("GAPIT says: group.to should  be larger than group.from. Please correct them!")

if(is.null(CV) | (!is.null(CV) & group.to<(ncol(CV)+1))) {
#The minimum of group is 1 + number of columns in CV
  group.from=1
  group.to=1
  warning("The upper bound of groups (group.to) is not sufficient. both boundries were set to a and GLM is performed!")
}

if(!is.null(CV)& group.from<1) {
  group.from=1 #minimum of group is number of columns in CV
  warning("The lower bound of groups should be 1 at least. It was set to 1!")
}
 
nk=1000000000
if(!is.null(KI)) nk=min(nk,nrow(KI))
if(!is.null(GK)) nk=min(nk,nrow(GK))

if(!is.null(KI))
{
  if(group.to>nk) {
    #group.to=min(nrow(KI),length(GTindex)) #maximum of group is number of rows in KI
    group.to=nk #maximum of group is number of rows in KI
    warning("The upper bound of groups is too high. It was set to the size of kinship!") 
  }
	if(group.from>nk){ 
    group.from=nk
    warning("The lower bound of groups is too high. It was set to the size of kinship!") 
  } 
}

if(!is.null(CV)){
 	if(group.to<=ncol(CV)+1) {
	#The minimum of group is number of columns in CV
	  #group.from=ncol(CV)+2
	  #group.to=ncol(CV)+2
	  warning("The upper bound of groups (group.to) is not sufficient. both boundries were set to their minimum and GLM is performed!")
	}
}

#bin.fold=ceiling(log2(bin.to/bin.from))
#bin.seq=0:bin.fold
#bin.level=bin.from*2^bin.seq

#Set upper bound for inclosure.to
if(inclosure.to>nrow(Y))inclosure.to=nrow(Y)-1

#set inclosure loop levels
bin.level=seq(bin.from,bin.to,by=bin.by)
inclosure=seq(inclosure.from,inclosure.to,by=inclosure.by)

#Optimization for group number, cluster algorithm and kinship type
GROUP=seq(group.to,group.from,by=-group.by)#The reverse order is to make sure to include full model
if(missing("kinship.cluster")) kinship.cluster=c("ward", "single", "complete", "average", "mcquitty", "median", "centroid")
if(missing("kinship.group")) kinship.group=c("Mean", "Max", "Min", "Median")
numSetting=length(GROUP)*length(kinship.cluster)*length(kinship.group)*length(bin.level)*length(inclosure)

#Reform Y, GD and CV into EMMA format
ys=as.matrix(Y[,2])
X0=as.matrix(CV[,-1])
CV.taxa=CVI[,1]
#print(length(ys))
#Initial
count=0
Compression=matrix(,numSetting,6)
colnames(Compression)=c("Type","Cluster","Group","REML","VA","VE")

#add indicator of overall mean
if(min(X0[,1])!=max(X0[,1])) X0 <- cbind(1, X0) #do not add overall mean if X0 has it already at first column


Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="DataProcessing")
Memory=GAPIT.Memory(Memory=Memory,Infor="DataProcessing")

print("-------------------------Iteration in process--------------------------")
print(paste("Total iterations: ",numSetting,sep=""))

#Loop to optimize cluster algorithm, group number and kinship type
for (bin in bin.level){
for (inc in inclosure){

#Grill: update KI if GK or GP is provided
if(!byPass & (!is.null(GK) | !is.null(GP)))
{  
  print("Grilling KI...")

    myGenotype<-GAPIT.Genotype(G=NULL,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,KI=NULL,kinship.algorithm=kinship.algorithm,PCA.total=0,SNP.fraction=SNP.fraction,SNP.test=SNP.test,
                  file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                  file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                  SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,kinship.cluster=kinship.cluster,NJtree.group=NJtree.group,NJtree.type=NJtree.type,
                  LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,
                  GP=GP,GK=GK,bin.size=bin,inclosure.size=inc,SNP.CV=SNP.CV,
                  Timmer = Timmer, Memory = Memory,GTindex=GTindex,sangwich.top=NULL,sangwich.bottom=sangwich.bottom,
                  file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
   
  Timmer=myGenotype$Timmer
  Memory=myGenotype$Memory

  KI=myGenotype$KI
#update group set by new KI
  nk=nrow(KI)
GROUP=GROUP[GROUP<=nk]
}
for (ca in kinship.cluster){
for (group in GROUP){
for (kt in kinship.group){

#Do not screen SNP unless existing genotype and one combination
if(numSetting==1 & hasGenotype){
 optOnly=FALSE
}else{
optOnly=TRUE
}
if(!SNP.test) optOnly=TRUE

if(optOnly | Model.selection){
 colInclude=1
 optOnly = TRUE
}else{
 colInclude=c(1:ncol(GD))
}

if(!optOnly) {print("Compressing and Genome screening..." )}
count=count+1

#Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 1")
#Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 1")

if(!byPass)
{
if(count==1)print("-------Mixed model with Kinship-----------------------------")
if(group<ncol(X0)+1) group=1 # the emma function (emma.delta.REML.dLL.w.Z) does not allow K has dim less then CV. turn to GLM (group=1)

cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
Timmer=cp$Timmer
Memory=cp$Memory

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")

#print("BK...")

bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")

#print("ZC...")
zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")

#print("wraping...")
#Reform KW and Z into EMMA format

zrow=nrow(zc$Z)
zcol=ncol(zc$Z)-1
#Z1=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Prio PreP3D")
Memory=GAPIT.Memory(Memory=Memory,Infor="Prio PreP3D")

#Evaluating maximum likelohood
#print("Calling EMMAxP3D...")

#print("It made it to here")
#print("The dimension of xs is:")
#print("The value of SNP.impute is")
#print(SNP.impute)

#write.table(zc$Z, "Z.csv", quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

# print(head(ys))
# print(as.matrix(as.data.frame(GD[GTindex,colInclude]))[1:5,1:5])
# print(as.matrix(bk$KW)[1:5,1:5])
# print(dim(ys))
# print(dim(as.matrix(as.data.frame(GD[GTindex,colInclude]))))

p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[GTindex,colInclude])),K = as.matrix(bk$KW) ,Z=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol),X0=X0,CVI=CVI,CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
        SNP.permutation=SNP.permutation, GP=GP,SNP.fraction=SNP.fraction,
			 file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
       GTindex=GTindex,genoFormat=genoFormat,optOnly=optOnly,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

Timmer=p3d$Timmer
Memory=p3d$Memory

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Post PreP3D")
Memory=GAPIT.Memory(Memory=Memory,Infor="Post PreP3D")

#print("Cluster algorithm, kinship type, groups, VG, Ve and REML:")
print(paste(count, "of",numSetting,"--","Vg=",round(p3d$vgs,4), "VE=",round(p3d$ves,4),"-2LL=",round(p3d$REMLs,2), "  Clustering=",ca,"  Group number=", group ,"  Group kinship=",kt,sep = " "))
#print(table(GTindex))

#Recoding the optimum KI
if(count==1){
  KI.save=KI
  LL.save=p3d$REMLs
}else{
  if(p3d$REMLs<LL.save){
    KI.save=KI
    LL.save=p3d$REMLs
  }
}

#print(paste("CA is ",ca))
#print(paste("group is ",group))
#print(paste("kt is ",kt))

#recording Compression profile on array
Compression[count,1]=kt
Compression[count,2]=ca
Compression[count,3]=group
Compression[count,4]=p3d$REMLs
Compression[count,5]=p3d$vgs
Compression[count,6]=p3d$ves
#print("result saved")

}else{# end of if(!byPass)

#Set QTNs
if(count==1)print("-------The burger is SNP-----------------------------------")
  #bin.size=bin
  #inclosure.size=inc

 
#@@@This section is not useful
if(!is.null(GP))
{
  #print("Being specific...")

  myGenotype<-GAPIT.Genotype(G=NULL,GD=NULL,GM=GI,KI=NULL,kinship.algorithm="SUPER",PCA.total=0,SNP.fraction=SNP.fraction,SNP.test=SNP.test,
                    file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                    file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                    SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,
                    LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,kinship.cluster=kinship.cluster,#NJtree.group=NJtree.group,NJtree.type=NJtree.type,
                    GP=GP,GK=NULL,bin.size=bin,inclosure.size=inc,SNP.CV=SNP.CV,GTindex=GTindex,sangwich.top=NULL,sangwich.bottom=sangwich.bottom,
                    Timmer = Timmer, Memory = Memory,file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
    
  Timmer=myGenotype$Timmer
  Memory=myGenotype$Memory
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype for burger")
  Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype for burger")
  
print(paste("bin---",bin,"---inc---",inc,sep=""))
  GK=GD[GTindex,myGenotype$SNP.QTN]
  SUPER_GD=GD[,myGenotype$SNP.QTN]
  SNPVar=apply(as.matrix(GK),2,var)
  
  GK=GK[,SNPVar>0]
  SUPER_GD=SUPER_GD[,SNPVar>0]
  GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa
  SUPER_GD=cbind(as.data.frame(GT),as.data.frame(SUPER_GD)) #add taxa

  #GP=NULL
}# end of if(is.null(GK)) 


if(!is.null(GK) & numSetting>1)
{
print("-------Calculating likelihood-----------------------------------")
 # myBurger=GAPIT.Burger(Y=Y,CV=CV,GK=GK)
    myBurger=GAPIT.Burger(Y=Y,CV=NULL,GK=GK)   #########modified by Jiabo Wang

  myREML=myBurger$REMLs
  myVG=myBurger$vg
  myVE=myBurger$ve
}else{
  myREML=NA
  myVG=NA
  myVE=NA
}

#Recoding the optimum GK
if(count==1){
  GK.save=GK
  LL.save=myREML
  	SUPER_optimum_GD=SUPER_GD     ########### get SUPER GD

}else{
  if(myREML<LL.save){
    GK.save=GK
    LL.save=myREML
	SUPER_optimum_GD=SUPER_GD     ########### get SUPER GD
  }
}
  
#Put to storage
Compression[count,1]=1
Compression[count,2]=bin
Compression[count,3]=inc
Compression[count,4]=myREML
Compression[count,5]=myVG
Compression[count,6]=myVG
print(Compression[count,]) 

#print("---------------SUPER 2nd stage: calculating LL ------------------------")


}   # end of if(byPass)

}#end of for (ca in kinship.cluster)

#Skip the rest group in case group 1 is finished
if(group==1) break #To skip the rest group interations

}#end of for (group in GROUP)
}#end of for (kt in kinship.group)

  
}#end of for (inc in inclosure)
}#end of for (bin in bin.level)


if(Model.selection == TRUE){ 

  print("------------------------Model selection for optimal number of PCs and Covariates-------------------------------------------------")
  #update KI with the best likelihood
  KI=KI.save
  if(numSetting>1){
  Compression=Compression[order(as.numeric(Compression[,4]),decreasing = FALSE),]  #sort on REML
  kt=Compression[1,1]
  ca=Compression[1,2]
  group=Compression[1,3]
  }

  cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
  Timmer=cp$Timmer
  Memory=cp$Memory

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")
  
  bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")

  zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")

  z0=as.matrix(zc$Z[,-1])
  Z1=matrix(as.numeric(z0),nrow=nrow(z0),ncol=ncol(z0))


  
  BIC <- rep(NA,ncol(X0))
  LogLike <- rep(NA, ncol(X0))
  for(i in 1:ncol(X0)){#1 because the first column of X0 is the intercept

    X0.test <- as.matrix(X0[,1:i]) 
    
    #print("The dim of bk$KW is ")
    #print(dim(bk$KW))
    #print(dim(X0.test))
    #print(dim(CVI))

    p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[,1])),K = as.matrix(bk$KW) ,Z=Z1,X0=X0.test,CVI=CVI,CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
            SNP.permutation=SNP.permutation, GP=GP,
			      file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
            GTindex=GTindex,genoFormat=genoFormat,optOnly=TRUE,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

    
    
    k.num.param <- 2+i
    #k is (i-1) because we have the following parameters in the likelihood function:
    #  intercept
    #  (i-1) covariates
    #  sigma_g
    #  delta
    
    #print(paste("The value of round(p3d$REMLs,5) is ", round(p3d$REMLs,5), sep = ""))
    #print(paste("The value of log(GTindex) is ", log(GTindex), sep = ""))
    #print(paste("The value of 0.5*k.num.param*log(GTindex) is ", 0.5*k.num.param*log(nrow(Z1)), sep = ""))
    
    LogLike[i] <- p3d$logLM
    BIC[i] <- p3d$logLM -(0.5*k.num.param*log(nrow(Z1)))
    
    #print("The value of k.num.param  is: ")
    #print(k.num.param)
    
    #print(paste("The value of nrow(Z1) is ", nrow(Z1), sep = ""))  
    
    }   
    Optimum.from.BIC <- which(BIC == max(BIC))
    
    print(paste("-----------------------The optimal number of PCs/covariates is ", (Optimum.from.BIC-1)," -------------------------", sep = ""))
    
    BIC.Vector <- cbind(as.matrix(rep(0:(ncol(X0)-1))), as.matrix(BIC), as.matrix(LogLike))

           
    #print(seq(0:ncol(X0)))
    
       #print(BIC.Vector)
 
    colnames(BIC.Vector) <- c("Number of PCs/Covariates", "BIC (larger is better) - Schwarz 1978", "log Likelihood Function Value")
    
    write.table(BIC.Vector, paste("GAPIT.", name.of.trait, ".BIC.Model.Selection.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
    
    #print(BIC.Vector)
    
    X0 <- X0[,1:(Optimum.from.BIC)]
    
    if(Optimum.from.BIC == 1){
    X0 <- as.matrix(X0)
    }
    print("The dimension of X0 after model selection is:")
    print(dim(X0))
    
    print("The head of X0 after model selection is")
    print(head(X0))
    

} # where does it start: 522

print("---------------------Sandwich bottom bun-------------------------------")
print("Compression") 
print(Compression)

#Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Compression")
#Memory=GAPIT.Memory(Memory=Memory,Infor="Copmression")

if(numSetting==1)
{
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")
}
  
#Perform GWAS with the optimum setting
#This section is omited if there is only one setting
if((numSetting>1)| (!is.null(sangwich.bottom)&!byPass) | Model.selection) {
  print("Genomic screening..." )
  
optOnly=FALSE  #set default to false and change it to TRUE in these situations:
if(!hasGenotype) optOnly=TRUE
if(!SNP.test) optOnly=TRUE

if(optOnly){
 colInclude=1
}else{
 colInclude=c(1:ncol(GD))
}

if(numSetting>1){
#Find the best ca,kt and group
print(paste(as.numeric(Compression[1,4]))) ###added by Jiabo Wang 2015.7.20
print(paste(min(as.numeric(Compression[,4]),rm.na=TRUE)))
adjust_value=as.numeric(Compression[1,4])-min(as.numeric(Compression[,4]),rm.na=TRUE)
nocompress_value=as.numeric(Compression[1,4])
REML_storage=as.numeric(Compression[,4])

adjust_mean=mean(as.numeric(Compression[,4]),rm.na=TRUE)
threshold=adjust_mean*0.1       

if(adjust_value<3|nocompress_value<0)     ###added by Jiabo Wang 2015.7.20
{


kt=Compression[1,1]
ca=Compression[1,2]
group=Compression[1,3]
print(paste("Optimum: ",Compression[1,2],Compression[1,1],Compression[1,3],Compression[1,5], Compression[1,6],Compression[1,4] ,sep = " "))
}else{
Compression=Compression[order(as.numeric(Compression[,4]),decreasing = FALSE),]  #sort on REML
kt=Compression[1,1]
ca=Compression[1,2]
group=Compression[1,3]
print(paste("Optimum: ",Compression[1,2],Compression[1,1],Compression[1,3],Compression[1,5], Compression[1,6],Compression[1,4] ,sep = " "))
}
}#end  if(numSetting>1)

print("--------------  Sandwich bottom ------------------------") 

if(!byPass) 
{ 
print("--------------  Sandwich bottom with raw burger------------------------") 

 if(Model.selection == FALSE){
  #update KI with the best likelihood
  if(is.null(sangwich.bottom)) KI=KI.save

  cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
  Timmer=cp$Timmer
  Memory=cp$Memory
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")
  
  bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")
  
  zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")
  
  #Reform KW and Z into EMMA format
  
  z0=as.matrix(zc$Z[,-1])   
  Z1=matrix(as.numeric(z0),nrow=nrow(z0),ncol=ncol(z0))
 }
 
 print("--------------EMMAxP3D with the optimum setting-----------------------") 
 #print(dim(ys))
 #print(dim(as.matrix(as.data.frame(GD[GTindex,colInclude]))))
  p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[GTindex,colInclude]))   ,K = as.matrix(bk$KW) ,Z=Z1,X0=as.matrix(X0),CVI=CVI, CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
          SNP.permutation=SNP.permutation, GP=GP,
    			 file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
           GTindex=GTindex,genoFormat=genoFormat,optOnly=optOnly,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)  
    
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")  
 print("--------------EMMAxP3D with the optimum setting done------------------") 
  
}#end of if(!byPass) 
}#end of if(numSetting>1 & hasGenotype & !SNP.test)  

#print("Screening wiht the optimum setting done") 

if(byPass)
{
print("---------------Sandwich bottom with grilled burger---------------------") 
print("---------------Sandwich bottom: reload bins ---------------------------")

#SUPER: Final screening
  GK=GK.save
  myBread=GAPIT.Bread(Y=Y,CV=CV,Z=Z,GK=GK,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,method=sangwich.bottom,GTindex=GTindex,LD=LD,file.output=file.output)
  
  print("SUPER saving results...")

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")  

   
}   #end of if(byPass)

print("--------------------Final results presentations------------------------")



#Plotting optimum group kinship
if(!byPass) 
{ 
if(length(bk$KW)>1 &length(bk$KW)<length(KI) & length(bk$KW)<1000 &GAPIT3.output){
pdf(paste("GAPIT.",name.of.trait,".Kin.Optimum.pdf",sep=""), width = 12, height = 12)
par(mar = c(25,25,25,25))
heatmap.2(as.matrix(bk$KW),  cexRow =.2, cexCol = 0.2, col=rev(heat.colors(256)), scale="none", symkey=FALSE, trace="none")
dev.off()
}
}


#Merge GWAS resultss from files to update ps,maf and nobs in p3d
if(byFile&!fullGD)
{
print("Loading GWAS results from file...")
for (file in file.from:file.to)
{

#Initicalization
frag=1
numSNP=file.fragment

while(numSNP==file.fragment) {     #this is problematic if the read end at the last line  

#Initicalization GI to detect reading empty line
#theGI=NULL
#theP=NULL
#theMAF=NULL
#thenobs=NULL

 
#reload results from files
print(paste("Current file ",file,"Fragment: ",frag))

theGI <- try(read.table(paste("GAPIT.TMP.GI.",name.of.trait,file,".",frag,".txt",sep=""), head = TRUE)   ,silent=TRUE)
theP <- try(read.table(paste("GAPIT.TMP.ps.",name.of.trait,file,".",frag,".txt",sep=""), head = FALSE)   ,silent=TRUE)
theMAF <- try(read.table(paste("GAPIT.TMP.maf.",name.of.trait,file,".",frag,".txt",sep=""), head = FALSE),silent=TRUE)
thenobs <- try(read.table(paste("GAPIT.TMP.nobs.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
thersquare_base <- try(read.table(paste("GAPIT.TMP.rsquare.base.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
thersquare <- try(read.table(paste("GAPIT.TMP.rsquare.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thedf  <- try(read.table(paste("GAPIT.TMP.df.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thetvalue  <- try(read.table(paste("GAPIT.TMP.tvalue.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thestderr  <- try(read.table(paste("GAPIT.TMP.stderr.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
theeffect.est <- try(read.table(paste("GAPIT.TMP.effect.est.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)

if(inherits(theGI, "try-error"))  {
#if(nrow(theGI)<1){
  numSNP=0
  #print("This fragment is empty.")
}else{



#print("Records loaded for this fragment.")
  numSNP=nrow(theGI)  
  colnames(theP)="P"
  colnames(theMAF )="MAF"
  colnames(thenobs )="nobs"
  colnames(thersquare_base) = "Base.Model.R.square"  
  colnames(thersquare) = "Model.R.square"
            colnames(thedf) = "Model.DF"
            colnames(thetvalue) = "Model.tvalue"
            colnames(thestderr) = "Model.stderr"
  colnames(theeffect.est) = "Effect.Est"    
  colnames(theGI) = colnames(GI)
 



#Merge results  
  if(file==file.from & frag==1){

    GI=theGI  
    #print(dim(GI))
    allP=theP
    #print(head(theP))
    allMAF=theMAF
    allnobs=thenobs
    allrsquare_base=thersquare_base
    allrsquare=thersquare
              alldf=thedf
              alltvalue=thetvalue
              allstderr=thestderr
    alleffect.est=theeffect.est

  }else{
    allP=as.data.frame(rbind(as.matrix(allP),as.matrix(theP))  )
    allMAF=as.data.frame(rbind(as.matrix(allMAF),as.matrix(theMAF)) )
    allnobs=as.data.frame(rbind(as.matrix(allnobs),as.matrix(thenobs)))
    allrsquare_base=as.data.frame(rbind(as.matrix(allrsquare_base),as.matrix(thersquare_base)))
    allrsquare=as.data.frame(rbind(as.matrix(allrsquare),as.matrix(thersquare)))
              alldf=as.data.frame(rbind(as.matrix(alldf),as.matrix(thedf)))
              alltvalue=as.data.frame(rbind(as.matrix(alltvalue),as.matrix(thetvalue)))
              allstderr=as.data.frame(rbind(as.matrix(allstderr),as.matrix(thestderr)))
    alleffect.est=as.data.frame(rbind(as.matrix(alleffect.est),as.matrix(theeffect.est)))
    #print("!!!!!!!!!!!!!!!")
    #print(dim(GI))
    #print(dim(theGI))
    GI=as.data.frame(rbind(as.matrix(GI),as.matrix(theGI)))
  }

}#end of  if(inherits(theGI, "try-error")) (else section)

#setup for next fragment
frag=frag+1   #Progress to next fragment 

}#end of loop on fragment: while(numSNP==file.fragment)
}#end of loop on file

#update p3d with components from files

  p3d$ps=allP
  p3d$maf=allMAF
  p3d$nobs=allnobs
  p3d$rsquare_base=allrsquare_base
  p3d$rsquare=allrsquare
      p3d$df=alldf
      p3d$tvalue=alltvalue
      p3d$stderr=allstderr
  p3d$effect.est=alleffect.est
  
#Delete all the GAPIT.TMP files
theFile=paste("GAPIT.TMP.",name.of.trait,".*")
  system('cmd /c del "GAPIT.TMP*.*"') 
  system('cmd /c del "GAPIT.TMP*.*"') 
  print("GWAS results loaded from all files succesfully!")
} #end of if(byFile)

#--------------------------------------------------------------------------------------------------------------------#
#Final report   
print("Generating summary" )
GWAS=NULL
GPS=NULL
rm(zc)
gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Final")
Memory=GAPIT.Memory(Memory=Memory,Infor="Final")

#genomic prediction
print("Genomic Breeding Values (GBV) ..." )
#print(p3d$BLUP)
gs=NULL
if(!byPass) 
{

if(length(bk$KW)>ncol(X0)) {
    gs <- GAPIT.GS(KW=bk$KW,KO=bk$KO,KWO=bk$KWO,GAU=bk$GAU,UW=cbind(p3d$BLUP,p3d$PEV))
}

print("Writing GBV and Acc..." )

GPS=NULL
if(length(bk$KW)>ncol(X0)) GPS=gs$BLUP
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GPS")
Memory=GAPIT.Memory(Memory=Memory,Infor="GPS")

#Make heatmap for distribution of BLUP and PEV
print("GBV and accuracy distribution..." )
if(length(bk$KW)>ncol(X0) &file.output) {
  GAPIT.GS.Visualization(gsBLUP = gs$BLUP, BINS=BINS,name.of.trait = name.of.trait)
}

#Make a plot Summarzing the Compression Results, if more than one "compression level" has been assessed
print("Compression portfolios..." )
#print(Compression)
if(file.output) GAPIT.Compression.Visualization(Compression = Compression, name.of.trait = name.of.trait)
print("Compression Visualization done")

if(length(Compression)<1){
  h2.opt= NULL
}else{
if(length(Compression)<=6) Compression=t(as.matrix(Compression[which(Compression[,4]!="NULL" | Compression[,4]!="NaN"),]))
if(length(Compression)==6) Compression=matrix(Compression,1,6) 
if(length(Compression)>6) Compression=Compression[which(Compression[,4]!="NULL" | Compression[,4]!="NaN"),]
Compression.best=Compression[1,] 
variance=as.numeric(Compression.best[5:6])
varp=variance/sum(variance)
h2.opt= varp[1]
}

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Compression.Visualization")
Memory=GAPIT.Memory(Memory=Memory,Infor="Compression.Visualization")
# print("$$$$$")
# print(str(p3d))

ps=p3d$ps
nobs=p3d$nobs
maf=p3d$maf
rsquare_base=p3d$rsquare_base
rsquare=p3d$rsquare
      df=p3d$df
      tvalue=p3d$tvalue
      stderr=p3d$stderr
effect.est=p3d$effect.est
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract p3d results")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract p3d results")
print("p3d objects transfered")  

#where does it start: 936
}else{  #byPass
    #print("The head of myBread$GWAS is")
  #print(head(myBread$GWAS))
  GPS=myBread$BLUP
  ps=myBread$GWAS[,4]
  nobs=myBread$GWAS[,6]
  #print(dim(GI))
  #print(head())
  Bread_index=match(as.character(myBread$GWAS[,1]),as.character(GI[,1]))
  #print(GD[1:5,1:5])
  Bread_X=GD[,Bread_index]
  #print(dim(Bread_X))
  maf=apply(Bread_X,2,function(one) abs(1-sum(one)/(2*nrow(Bread_X))))
  maf[maf>0.5]=1-maf[maf>0.5]
  rsquare_base=rep(NA,length(ps))
  rsquare=rep(NA,length(ps))
  df=rep(NA,length(nobs))
  tvalue=rep(NA,length(nobs))
  stderr=rep(NA,length(nobs))
  effect.est=rep(NA,length(nobs))
  
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract bread results")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract bread results")
 
}
print("Merge BLUP and BLUE")
#print(head(ps))
#Merge BLUP and BLUE
Pred=NULL
if((!byPass)&(!Model.selection)){
 print("GAPIT before BLUP and BLUE")
 #print(dim(p3d$BLUE))
 BLUE=data.frame(cbind(data.frame(CV.taxa),data.frame(p3d$BLUE)))
 colnames(BLUE)=c("Taxa","BLUE")
 
 #Initial BLUP as BLUe and add additional columns
 gs.blup=cbind(BLUE,NA,NA,0,NA)
 
 if(!is.null(gs))gs.blup=gs$BLUP
 BB= merge(gs.blup, BLUE, by.x = "Taxa", by.y = "Taxa")
 if (is.null(my_allCV)){my_allX=matrix(1,length(my_taxa),1)
 }else{
     # my_allX=as.matrix(my_allCV[,-1])
     my_allX=cbind(1,as.matrix(my_allCV[,-1]))
	}
	
    #print(dim(my_allX))
    #print(head(my_allX))
    #print(dim(BB))
    #print(CV.Inheritance)
 if(is.null(CV.Inheritance))
 
   {
   Prediction=BB[,5]+BB[,7]
   Pred_Heritable=Prediction
   }
 if(!is.null(CV.Inheritance))
   {
       #inher_CV=my_allX[,1:(1+CV.Inheritance)]
       #beta.Inheritance=p3d$effect.cv[1:(1+CV.Inheritance)]
    #print(beta.Inheritance)
    #if(length(beta)==1)CV=X
    all_BLUE=try(my_allX%*%p3d$effect.cv,silent=T)
    if(inherits(BLUE, "try-error")) all_BLUE = NA
    

    Pred_Heritable=BB[,5]+BB[,7]
    Prediction=BB[,5]+all_BLUE
   }
   #print("@@@@@@@@@@")
 #print(dim(CVI))
 #print(BB)
 #CV.Inheritance
 #Pred_Heritable=p3d$effect.cv[CV.Inheritance]%*%CVI[CV.Inheritance]+BB[,7]
 Pred=data.frame(cbind(BB,data.frame(Prediction)),data.frame(Pred_Heritable))
 if(noCV)
    {
    if(NOBLUP)
    {Pred=NA
    }else{
    BLUE=Pred$BLUE[1]
    prediction=as.matrix(GPS$BLUP)+(BLUE)
    Pred=cbind(GPS,BLUE,prediction)
 colnames(Pred)=c("Taxa","Group","RefInf","ID","BLUP","PEV","BLUE","Prediction")
    }#end NOBLUP
    }#end noCV
 print("GAPIT after BLUP and BLUE")
}

#Export BLUP and PEV
if(!byPass &GAPIT3.output) 
{
print("Exporting BLUP and Pred")
  #try(write.table(gs$BLUP, paste("GAPIT.", name.of.trait,".BLUP.csv" ,sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE))
  try(write.table(Pred, paste("GAPIT.", name.of.trait,".PRED.csv" ,sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE))
}

if(byPass) 
{
  theK.back=NULL
}else{
  theK.back=cp$KG
}
if(byPass)Compression[1,4]=0 #create a fake value to aloow output of SUPER 

#Export GWAS results
PWI.Filtered=NULL
if(hasGenotype &SNP.test &!is.na(Compression[1,4]))     #require not NA REML 
{
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract GWAS start")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract GWAS start")


  #print("Filtering SNPs with MAF..." )
	#index=maf>=SNP.MAF	   
  
	PWI.Filtered=cbind(GI,ps,maf,nobs,rsquare_base,rsquare,effect.est)#[index,]
	#print(dim(PWI.Filtered))
	colnames(PWI.Filtered)=c("SNP","Chromosome","Position ","P.value", "maf", "nobs", "Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP","effect")

if(!byPass){  
   if(Create.indicator){
    #Add a counter column for GI
    GI.counter <- cbind(GI, seq(1:nrow(GI))) 
    
    #Turn GI and effect.est into data frames
    GI.counter.data.frame <- data.frame(GI.counter)
    colnames(GI.counter.data.frame) <- c("X1", "X2", "X3", "X4")
    
    effect.est.data.frame <- data.frame(effect.est)
    colnames(effect.est.data.frame) <- c("X1", "X2", "X3")
    print(head(GI.counter.data.frame))
    print(head(effect.est.data.frame))
    #Do a merge statement
    GWAS.2 <- merge(GI.counter.data.frame, effect.est.data.frame, by.x = "X4", by.y = "X1")
    
    #Remove the counter column
    GWAS.2 <- GWAS.2[,-1]
    
    #Add column names
    colnames(GWAS.2) <- c("SNP","Chromosome","Position ", "Genotype", "Allelic Effect Estimate")
    
    
   }
   if(!Create.indicator){ 
    GWAS.2 <- PWI.Filtered[,c(1:3,9)]
    colnames(GWAS.2) <- c("SNP","Chromosome","Position ", "Allelic Effect Estimate")
   } 
}
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="MAF filtered")
Memory=GAPIT.Memory(Memory=Memory,Infor="MAF filtered")
		     
  #print("SNPs filtered with MAF")
   
  
  if(!is.null(PWI.Filtered))
  {

  #Run the BH multiple correction procedure of the results
  #Create PWIP, which is a table of SNP Names, Chromosome, bp Position, Raw P-values, FDR Adjusted P-values
  #print("Calculating FDR..." )

  PWIP <- GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure(PWI = PWI.Filtered, FDR.Rate = FDR.Rate, FDR.Procedure = "BH")
  
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Multiple Correction")
Memory=GAPIT.Memory(Memory=Memory,Infor="Multiple Correction")


  #QQ plots
  #print("QQ plot..." )
  if(file.output) GAPIT.QQ(P.values = PWIP$PWIP[,4], name.of.trait = name.of.trait,DPP=DPP)


Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="QQ plot")
Memory=GAPIT.Memory(Memory=Memory,Infor="QQ plot")


  #Manhattan Plots
  
  
   #print("Manhattan plot (Genomewise)..." )
#  if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff)
#  if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=QTN.position)  #QTN does not work with sorted P
 if(file.output) GAPIT.Manhattan(GI.MP = PWI.Filtered[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=QTN.position,plot.style=plot.style,plot.bin=plot.bin,chor_taxa=chor_taxa)

 #print("Manhattan plot (Chromosomewise)..." )
 
  #if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff)
 if(file.output&SNP.fraction==1) GAPIT.Manhattan(GI.MP = PWI.Filtered[,2:4],GD=GD,CG=CG, name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff,plot.bin=plot.bin,chor_taxa=chor_taxa)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Manhattan plot")
Memory=GAPIT.Memory(Memory=Memory,Infor="Manhattan plot")


  #Association Table
  #print("Association table..." )
  #print(dim(PWIP$PWIP))
  #GAPIT.Table(final.table = PWIP$PWIP, name.of.trait = name.of.trait,SNP.FDR=SNP.FDR)
  #print(head(PWIP$PWIP))
  GWAS=PWIP$PWIP[PWIP$PWIP[,9]<=SNP.FDR,]
  #print("Joining tvalue and stderr" )
  
        DTS=cbind(GI,df,tvalue,stderr,effect.est)
        colnames(DTS)=c("SNP","Chromosome","Position","DF","t Value","std Error","effect")	

  #print("Creating ROC table and plot" )
	if(file.output) myROC=GAPIT.ROC(t=tvalue,se=stderr,Vp=var(ys),trait=name.of.trait)
  #print("ROC table and plot created" )

  #MAF plots
  #print("MAF plot..." )
   if(file.output) myMAF1=GAPIT.MAF(MAF=GWAS[,5],P=GWAS[,4],E=NULL,trait=name.of.trait)


  #print(dim(GWAS))

  if(file.output){
   write.table(GWAS, paste("GAPIT.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   write.table(DTS, paste("GAPIT.", name.of.trait, ".Df.tValue.StdErr.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   if(!byPass) write.table(GWAS.2, paste("GAPIT.", name.of.trait, ".Allelic_Effect_Estimates.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
  }


  
  } #end of if(!is.null(PWI.Filtered))
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract GWAS end")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract GWAS end")

  
} #end of if(hasGenotype )

#Log
if(GAPIT3.output) log=GAPIT.Log(Y=Y,KI=KI,Z=Z,CV=CV,SNP.P3D=SNP.P3D,
				group.from = group.from ,group.to =group.to ,group.by = group.by ,kinship.cluster = kinship.cluster, kinship.group= kinship.group,
                      	ngrid = ngrid , llin = llin , ulim = ulim , esp = esp ,name.of.trait = name.of.trait)
#Memory usage
#GAPIT.Memory.Object(name.of.trait=name.of.trait)

#Timming
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Report")
Memory=GAPIT.Memory(Memory=Memory,Infor="Report")
if(file.output){
file=paste("GAPIT.", name.of.trait,".Timming.csv" ,sep = "")
write.table(Timmer, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

file=paste("GAPIT.", name.of.trait,".Memory.Stage.csv" ,sep = "")
write.table(Memory, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
}
print(paste(name.of.trait, "has been analyzed successfully!") )
print(paste("The results are saved in the directory of ", getwd()) )



#print("==========================================================================================")
TV<-list()
TV$ps=ps
TV$nobs=nobs
TV$maf=maf
TV$rsquare_base=rsquare_base
TV$rsquare=rsquare
TV$df=df
TV$tvalue=tvalue
TV$stderr=stderr
TV$effect.est=effect.est
#print("!!!!!!!!!!!!!")
#print(head(effect.est))
#print(head(DTS[,7]))
#print(ys)
if(byPass | Model.selection) Pred <- NA
print("before ending GAPIT.Main")
#print(dim(Compression))
return (list(Timmer=Timmer,Compression=Compression,kinship.optimum=theK.back, kinship=KI,PC=PC,GWAS=PWI.Filtered, GPS=GPS,Pred=Pred,REMLs=Compression[count,4],Timmer=Timmer,Memory=Memory,SUPER_GD=SUPER_GD,P=ps,effect.snp=DTS[,7],effect.cv=p3d$effect.cv,h2= h2.opt,TV=TV))
} #end if non-SUPER.GS situation, this is a long if statement, structure needs improvement
}#The function GAPIT.Main ends here
#=============================================================================================


`GAPIT.Manhattan` <-
function(GI.MP = NULL,GD=NULL,name.of.trait = "Trait",plot.type = "Genomewise",width0=13,height0=5.75,
DPP=50000,cutOff=0.01,band=5,seqQTN=NULL,plot.style="Oceanic",CG=NULL,plot.bin=10^9,chor_taxa=NULL){
    #Object: Make a Manhattan Plot
    #Options for plot.type = "Separate_Graph_for_Each_Chromosome" and "Same_Graph_for_Each_Chromosome"
    #Output: A pdf of the Manhattan Plot
    #Authors: Alex Lipka, Zhiwu Zhang, Meng Li and Jiabo Wang
    # Last update: Oct 10, 2016
	#Add r2 between candidata SNP and other markers in on choromosome
    ##############################################################################################
    #print("Manhattan ploting...")
    
    #print(cutOff)
    #do nothing if null input
    if(is.null(GI.MP)) return
	#if(is.null(GD)) return
    #print("Dimension of GI.MP")
    #print(dim(GI.MP))
    #print(head(GI.MP))
    #print(tail(GI.MP))
    #print(CG)
    
    #seqQTN=c(300,1000,2500)
  #Handler of lable paosition only indicated by negatie position
  position.only=F
    if(!is.null(seqQTN)){
      if(seqQTN[1]<0){
        seqQTN=-seqQTN
        position.only=T
      }
      
    }
    
    #if(is.null(GD)) print ("GD is not same dim as GM")
    borrowSlot=4
    GI.MP[,borrowSlot]=0 
    GI.MP[,5]=1:(nrow(GI.MP))
    GI.MP=matrix(as.numeric(as.matrix(GI.MP) ) ,nrow(GI.MP),ncol(GI.MP))
    GI.MP=GI.MP[order(GI.MP[,2]),]
    GI.MP=GI.MP[order(GI.MP[,1]),]
    # print("@@@@@")
    # print(head(GI.MP))
    #Inicial as 0
    
    if(!is.null(seqQTN))GI.MP[seqQTN,borrowSlot]=1
    
    if(!is.null(GD))
    {  if(ncol(GD)!=nrow(GI.MP))print("GD does not mach GM in Manhattan !!!")
    }
    #print(ncol(GD))
    #print(nrow(GI.MP))
    #print(GI.MP)
    #print("!!")
    #GI.MP[,5]=1:(nrow(GI.MP))
	#print(head(GI.MP,20))
    #Remove all SNPs that do not have a choromosome, bp position and p value(NA)
    GI.MP <- GI.MP[!is.na(GI.MP[,1]),]
    GI.MP <- GI.MP[!is.na(GI.MP[,2]),]
    if(!is.null(GD)) GD=GD[,!is.na(GI.MP[,3])]
    GI.MP <- GI.MP[!is.na(GI.MP[,3]),]
    
    #Retain SNPs that have P values between 0 and 1 (not na etc)
    if(!is.null(GD)) GD=GD[,GI.MP[,3]>0]
    GI.MP <- GI.MP[GI.MP[,3]>0,]
    if(!is.null(GD)) GD=GD[,GI.MP[,3]<=1]
    GI.MP <- GI.MP[GI.MP[,3]<=1,]
    
    #Remove chr 0 and 99
    GI.MP <- GI.MP[GI.MP[,1]!=0,]
    #GI.MP <- GI.MP[GI.MP[,1]!=99,]
    #print(dim(GI.MP))
    #print("Dimension of GI.MP after QC")
    #print(dim(GI.MP))
    #print(head(GI.MP))
    numMarker=nrow(GI.MP)
    #print(numMarker)
    bonferroniCutOff=-log10(cutOff/numMarker)
    
    #Replace P the -log10 of the P-values
    if(!is.null(GD))
    {  if(ncol(GD)!=nrow(GI.MP))
    {print("GD does not match GM in Manhattan !!!")
    return
    }}
    #print(ncol(GD))
    #print(nrow(GI.MP))
    GI.MP[,3] <-  -log10(GI.MP[,3])
    index_GI=GI.MP[,3]>0
    GI.MP <- GI.MP[index_GI,]
    if(!is.null(GD)) GD=GD[,index_GI]
    
    GI.MP[,5]=1:(nrow(GI.MP))
    y.lim <- ceiling(max(GI.MP[,3]))
    chm.to.analyze <- unique(GI.MP[,1])
    #print(dim(GI.MP))
    #print(dim(GD))
    #print("name of chromosomes:")
    #print(chm.to.analyze)
    
    chm.to.analyze=chm.to.analyze[order(chm.to.analyze)]
    numCHR= length(chm.to.analyze)
    #GI.MP[,5]=1:(nrow(GI.MP))
     bin.mp=GI.MP[,1:3]
     bin.mp[,3]=0 # for r2
     bin.mp[,1]=as.numeric(as.vector(GI.MP[,2]))+as.numeric(as.vector(GI.MP[,1]))*(10^(max(GI.MP[,1])+1))
     
     
     #as.numeric(as.vector(GP[,3]))+as.numeric(as.vector(GP[,2]))*MaxBP
     #print(head(bin.mp))
     bin.mp[,2]=floor(bin.mp[,1]/plot.bin)
     if(!is.null(GD)) X=GD

     #print(head(bin.mp))
        #Chromosomewise plot
    if(plot.type == "Chromosomewise"&!is.null(GD))
    {
        #print("Manhattan ploting Chromosomewise")
        GI.MP=cbind(GI.MP,bin.mp)
        pdf(paste("GAPIT.", name.of.trait,".Manhattan.Plot.Chromosomewise.pdf" ,sep = ""), width = 10)
            #par(mar = c(5,5,4,3), lab = c(8,5,7))
        layout(matrix(c(1,1,2,1,1,1,1,1,1),3,3,byrow=TRUE), c(2,1), c(1,1), TRUE)
        for(i in 1:numCHR)
        {
            #Extract SBP on this chromosome
            subset=GI.MP[GI.MP[,1]==chm.to.analyze[i],,drop=FALSE]
            # print(head(subset))
            if(nrow(subset)==0)next #thanks to lvclark to fix it
            subset[,1]=1:(nrow(subset))
            #sub.bin.mp=bin.mp[GI.MP[,1]==chm.to.analyze[i],]
            #subset=cbind(subset,sub.bin.mp)
            sig.mp=subset[subset[,3]>bonferroniCutOff,,drop=FALSE]
            sig.index=subset[,3]>bonferroniCutOff ### index of significont SNP
            
            
            num.row=nrow(sig.mp)
            if(!is.null(dim(sig.mp)))sig.mp=sig.mp[!duplicated(sig.mp[,7]),]
            num.row=nrow(sig.mp)
            if(is.null(dim(sig.mp))) num.row=1
            bin.set=NULL
            r2_color=matrix(0,nrow(subset),2)
            #r2_color
            print(paste("select ",num.row," candidate significont markers in ",i," chromosome ",sep="") )
            #print(sig.mp)
            if(length(unique(sig.index))==2)
            {
                for(j in 1:num.row)
                {   sig.mp=matrix(sig.mp,num.row,8)
                    
                    #print(sig.mp[j,7])
                    #print(unique(subset[,7]))
                    bin.store=subset[which(subset[,7]==sig.mp[j,7]),]
                    if(is.null(dim(bin.store)))
                      {subset[which(subset[,7]==sig.mp[j,7]),8]=1
                          next
                      }
                    bin.index=unique(bin.store[,5])
                    subGD=X[,bin.store[,5]]
                    #print(dim(bin.store))
                    if(is.null(CG))candidata=bin.store[bin.store[,3]==max(bin.store[,3]),5]
                    if(length(candidata)!=1)candidata=candidata[1]
                    
                    for (k in 1:ncol(subGD))
                    {
                        r2=cor(X[,candidata],subGD[,k])^2
                        #print(r2)
                        bin.store[k,8]=r2
                        
                    }
                    #print(bin.store)
                    #r2_storage[is.na(r2_storage)]=0
                    #print(bin.store)
                    subset[bin.store[,1],8]=bin.store[,8]
                    #print()
                }###end for each sig.mp
                #sub.bin.mp=bin.mp[subset[,3]>bonferroniCutOff,]
                #print(head(bin.set))
            
            }###end if empty of sig.mp
            #print("@@@@@@@@@@@@@@@@")
            rm(sig.mp,num.row)
            #print(head(subset))
			#print(head(subset))
			#print(dim(X))
            y.lim <- ceiling(max(subset[,3]))+1  #set upper for each chr
            if(length(subset)>3){
                x <- as.numeric(subset[,2])/10^(6)
                y <- as.numeric(subset[,3])
            }else{
                x <- as.numeric(subset[2])/10^(6)
                y <- as.numeric(subset[3])
            }
            
            ##print(paste("befor prune: chr: ",i, "length: ",length(x),"max p",max(y), "min p",min(y), "max x",max(x), "Min x",min(x)))
            n_col=10
            r2_color[,2]=subset[,8]
            do_color=colorRampPalette(c("orangeRed", "blue"))(n_col)
            #Prune most non important SNPs off the plots
            order=order(y,decreasing = TRUE)
            y=y[order]
            x=x[order]
            r2_color=r2_color[order,,drop=FALSE]
            index=GAPIT.Pruning(y,DPP=round(DPP/numCHR))
            x=x[index]
            y=y[index]
			r2_color=r2_color[index,,drop=FALSE]
            r2_color[which(r2_color[,2]<=0.2),2]=do_color[n_col]
            r2_color[which(r2_color[,2]<=0.4&r2_color[,2]>0.2),2]=do_color[n_col*0.8]
            r2_color[which(r2_color[,2]<=0.6&r2_color[,2]>0.4),2]=do_color[n_col*0.6]
            r2_color[which(r2_color[,2]<=0.8&r2_color[,2]>0.6),2]=do_color[n_col*0.4]
            r2_color[which(r2_color[,2]<=1&r2_color[,2]>0.8),2]=do_color[n_col/n_col]
            
            
            #print(unique(r2_color[,2]))
            
            ##print(paste("after prune: chr: ",i, "length: ",length(x),"max p",max(y), "min p",min(y), "max x",max(x), "Min x",min(x)))
			
            par(mar=c(0,0,0,0))
            par(mar=c(5,5,2,1),cex=0.8)

            plot(y~x,type="p", ylim=c(0,y.lim), xlim = c(min(x), max(x)),
			col = r2_color[,2], xlab = expression(Base~Pairs~(x10^-6)),
			ylab = "-Log Base 10 p-value", main = 			paste("Chromosome",chm.to.analyze[i],sep=" "),
			cex.lab=1.6,pch=21,bg=r2_color[,2])
            
            abline(h=bonferroniCutOff,col="forestgreen")
            ##print("manhattan plot (chr) finished")
            #layout.show(nf)	
            #provcol <-c("darkblue","cyan","green3","brown1","brown1")
            #provcol <-heat.colors(50)
            #par(mar=c(0,0,0,0))
            par(mar=c(15,5,6,5),cex=0.5)
            
            barplot(matrix(rep(1,times=n_col),n_col,1),beside=T,col=do_color,border=do_color,axes=FALSE,)
        #legend(x=10,y=2,legend=expression(R^"2"),,lty=0,cex=1.3,bty="n",bg=par("bg"))
            axis(3,seq(11,1,by=-2),seq(0,1,by=0.2),las=1)

        }# end plot.type == "Chromosomewise"&!is.null(GD)
        dev.off()
		
        print("manhattan plot on chromosome finished")
    } #Chromosomewise plot
    
    
    #Genomewise plot
    if(plot.type == "Genomewise")
    {
        #print("Manhattan ploting Genomewise")
        #Set corlos for chromosomes
        #nchr=max(chm.to.analyze)
        nchr=length(chm.to.analyze)

    #Set color schem            
        ncycle=ceiling(nchr/band)
        ncolor=band*ncycle
        #palette(rainbow(ncolor+1))
        cycle1=seq(1,nchr,by= ncycle)
        thecolor=cycle1
        for(i in 2:ncycle){thecolor=c(thecolor,cycle1+(i-1))}
      	col.Rainbow=rainbow(ncolor+1)[thecolor]     	
     	  col.FarmCPU=rep(c("#CC6600","deepskyblue","orange","forestgreen","indianred3"),ceiling(numCHR/5))
    	  col.Rushville=rep(c("orangered","navyblue"),ceiling(numCHR/2))   	
		    col.Congress=rep(c("deepskyblue3","firebrick"),ceiling(numCHR/2))
 		    col.Ocean=rep(c("steelblue4","cyan3"),ceiling(numCHR/2)) 		
 		    col.PLINK=rep(c("gray10","gray70"),ceiling(numCHR/2)) 		
 		    col.Beach=rep(c("turquoise4","indianred3","darkolivegreen3","red","aquamarine3","darkgoldenrod"),ceiling(numCHR/5))
 		    #col.Oceanic=rep(c(	'#EC5f67',	'#F99157',	'#FAC863',	'#99C794',	'#5FB3B3',	'#6699CC',	'#C594C5',	'#AB7967'),ceiling(numCHR/8))
 		    #col.Oceanic=rep(c(	'#EC5f67',		'#FAC863',	'#99C794',		'#6699CC',	'#C594C5',	'#AB7967'),ceiling(numCHR/6))
 		    col.Oceanic=rep(c(	'#EC5f67',		'#FAC863',	'#99C794',		'#6699CC',	'#C594C5'),ceiling(numCHR/5))
 		    col.cougars=rep(c(	'#990000',		'dimgray'),ceiling(numCHR/2))
 		
        if(plot.style=="Rainbow")plot.color= col.Rainbow
        if(plot.style =="FarmCPU")plot.color= col.Rainbow
        if(plot.style =="Rushville")plot.color= col.Rushville
        if(plot.style =="Congress")plot.color= col.Congress
        if(plot.style =="Ocean")plot.color= col.Ocean
        if(plot.style =="PLINK")plot.color= col.PLINK
 		    if(plot.style =="Beach")plot.color= col.Beach
 		    if(plot.style =="Oceanic")plot.color= col.Oceanic
 		    if(plot.style =="cougars")plot.color= col.cougars
 		
		#FarmCPU uses filled dots
    	mypch=1
    	if(plot.style =="FarmCPU")mypch=20
    	        
        GI.MP <- GI.MP[order(GI.MP[,2]),]
        GI.MP <- GI.MP[order(GI.MP[,1]),]

        ticks=NULL
        lastbase=0
        
        #print("Manhattan data sorted")
        #print(chm.to.analyze)
        
        #change base position to accumulatives (ticks)
        for (i in chm.to.analyze)
        {
            index=(GI.MP[,1]==i)
            ticks <- c(ticks, lastbase+mean(GI.MP[index,2]))
            GI.MP[index,2]=GI.MP[index,2]+lastbase
            lastbase=max(GI.MP[index,2])
        }
        
        #print("Manhattan chr processed")
        #print(length(index))
        #print(length(ticks))
        #print((ticks))
        #print((lastbase))
        
        x0 <- as.numeric(GI.MP[,2])
        y0 <- as.numeric(GI.MP[,3])
        z0 <- as.numeric(GI.MP[,1])
        position=order(y0,decreasing = TRUE)
        index0=GAPIT.Pruning(y0[position],DPP=DPP)
        index=position[index0]
        
        x=x0[index]
        y=y0[index]
        z=z0[index]

        #Extract QTN
        QTN=GI.MP[which(GI.MP[,borrowSlot]==1),]
        #print(QTN)
        #Draw circles with same size and different thikness
        size=1 #1
        ratio=10 #5
        base=1 #1
        themax=ceiling(max(y))
        themin=floor(min(y))
        wd=((y-themin+base)/(themax-themin+base))*size*ratio
        s=size-wd/ratio/2
        
        #print("Manhattan XY created")
       ####xiaolei update on 2016/01/09 
        if(plot.style =="FarmCPU"){
	    pdf(paste("FarmCPU.", name.of.trait,".Manhattan.Plot.Genomewise.pdf" ,sep = ""), width = width0,height=height0)
        }else{
	    pdf(paste("GAPIT.", name.of.trait,".Manhattan.Plot.Genomewise.pdf" ,sep = ""), width = width0,height=height0)
        }
            par(mar = c(3,6,5,1))
        	plot(y~x,xlab="",ylab=expression(-log[10](italic(p))) ,
        	cex.axis=1.5, cex.lab=2, ,col=plot.color[z],axes=FALSE,type = "p",pch=mypch,lwd=wd,cex=s+.3,main = paste(name.of.trait,sep=" 			"),cex.main=2.5)
        
        #Label QTN positions
        if(is.vector(QTN)){
          if(position.only){abline(v=QTN[2], lty = 2, lwd=1.5, col = "grey")}else{
          points(QTN[2], QTN[3], type="p",pch=21, cex=2,lwd=1.5,col="dimgrey")
          points(QTN[2], QTN[3], type="p",pch=20, cex=1,lwd=1.5,col="dimgrey")
          }
        }else{
          if(position.only){abline(v=QTN[,2], lty = 2, lwd=1.5, col = "grey")}else{
          points(QTN[,2], QTN[,3], type="p",pch=21, cex=2,lwd=1.5,col="dimgrey")
          points(QTN[,2], QTN[,3], type="p",pch=20, cex=1,lwd=1.5,col="dimgrey")
          }
        }
        
        #Add a horizontal line for bonferroniCutOff
        abline(h=bonferroniCutOff,col="forestgreen")
        #print(bonferroniCutOff)
        #Set axises
        # jiabo creat chor_taxa
        #print(chor_taxa)
        if(length(chor_taxa)!=length(ticks))chor_taxa=NULL
        #print(unique(GI.MP[,1]))
        if(!is.null(chor_taxa))
        {axis(1, at=ticks,cex.axis=1.5,labels=chor_taxa,tick=F)
        }else{axis(1, at=ticks,cex.axis=1.5,labels=chm.to.analyze,tick=F)}
        axis(2, at=1:themax,cex.axis=1.5,labels=1:themax,tick=F)

        box()
        palette("default")
        dev.off()
        #print("Manhattan done Genomewise")
        
    } #Genomewise plot
    
    print("GAPIT.Manhattan accomplished successfully!zw")
} #end of GAPIT.Manhattan
#=============================================================================================
`GAPIT.Memory.Object` <-
function(name.of.trait="Trait"){
# Object: To report memoery usage
# Authors: Heuristic Andrew
# http://heuristically.wordpress.com/2010/01/04/r-memory-usage-statistics-variable/
# Modified by Zhiwu Zhang
# Last update: may 29, 2011 
############################################################################################## 
# print aggregate memory usage statistics 
print(paste('R is using', memory.size(), 'MB out of limit', memory.limit(), 'MB')) 
  
# create function to return matrix of memory consumption 
object.sizes <- function() 
{ 
    return(rev(sort(sapply(ls(envir=.GlobalEnv), function (object.name) 
        object.size(get(object.name)))))) 
} 

# export file in table format 
memory=object.sizes() 
file=paste("GAPIT.", name.of.trait,".Memory.Object.csv" ,sep = "")
write.table(memory, file, quote = FALSE, sep = ",", row.names = TRUE,col.names = TRUE)


# export file in PDF format 
pdf(paste("GAPIT.", name.of.trait,".Memory.Object.pdf" ,sep = ""))
# draw bar plot 
barplot(object.sizes(), 
    main="Memory usage by object", ylab="Bytes", xlab="Variable name", 
    col=heat.colors(length(object.sizes()))) 
# draw dot chart 
dotchart(object.sizes(), main="Memory usage by object", xlab="Bytes") 
# draw pie chart 
pie(object.sizes(), main="Memory usage by object")
dev.off()  
}
#=============================================================================================

`GAPIT.Memory` <-
function(Memory =NULL,Infor){
#Object: To report memory usage
#Output: Memory 
#Authors: Zhiwu Zhang
# Last update: June 6, 2011 
##############################################################################################
gc()
size <- memory.size()
#print(paste("Memory usage: ",size," for", Infor))
if(is.null(Memory)) {
Increased=0
Memory =cbind(Infor,size ,Increased)
}else{
Increased=0
Memory.current=cbind(Infor,size ,Increased)
Memory=rbind(Memory,Memory.current)
Memory[nrow(Memory),3]=as.numeric(as.matrix(Memory[nrow(Memory),2]))-as.numeric(as.matrix(Memory[nrow(Memory)-1,2]))
}

return (Memory)
}#end of GAPIT.Memory function
#=============================================================================================

`GAPIT.Multiple.Manhattan` <-
function(model_store,DPP=50000,cutOff=0.01,band=5,seqQTN=NULL,Y=NULL,GM=NULL,interQTN=NULL,plot.style="Oceanic",plot.line=FALSE){
    #Object: Make a Manhattan Plot
    #Options for plot.type = "Separate_Graph_for_Each_Chromosome" and "Same_Graph_for_Each_Chromosome"
    #Output: A pdf of the Manhattan Plot
    #Authors: Alex Lipka, Zhiwu Zhang, Meng Li and Jiabo Wang
    # Last update: Oct 10, 2016
	#Add r2 between candidata SNP and other markers in on choromosome
    ##############################################################################################
  Nenviron=length(model_store)*(ncol(Y)-1)
  environ_name=NULL
  new_xz=NULL
  for(i in 1:length(model_store))
  {
    for(j in 1:(ncol(Y)-1))
    {
      environ_name=c(environ_name,paste(model_store[i],".",colnames(Y)[-1][j],sep=""))
    }
  }
sig_pos=NULL
simulation=FALSE
    if(!is.null(seqQTN)){    
        #seqQTN=-seqQTN
        simulation=TRUE    
    }
for(i in 1:length(environ_name))
{
  environ_result=read.csv(paste("GAPIT.",environ_name[i],".GWAS.Results.csv",sep=""),head=T)
  environ_filter=environ_result[!is.na(environ_result[,4]),]
  y_filter=environ_filter[environ_filter[,4]<(cutOff/(nrow(environ_filter))),]
  write.table(y_filter,paste("Filter_",environ_name[i],"_GWAS_result.txt",sep=""))

  result=environ_result[,1:4]

  result=result[match(as.character(GM[,1]),as.character(result[,1])),]
  # result=result[order(result[,2]),]
  # result=result[order(result[,1]),]
  #print(head(result))
  rownames(result)=1:nrow(result)
  #print(i)
  if(i==1){
    result0=result
    colnames(result0)[4]=environ_name[i]

    }
  if(i!=1){
    result0=merge(result0,result[,c(1,4)],by.x=colnames(result0)[1],by.y=colnames(result)[1])
    colnames(result0)[i+3]=environ_name[i]
    }
  rownames(result)=1:nrow(result)
  result[is.na(result[,4]),4]=1
  sig_pos=append(sig_pos,as.numeric(rownames(result[result[!is.na(result[,4]),4]<(cutOff/nrow(result)),])))

}

#if(length(sig_pos)!=0)sig_pos=sig_pos[!duplicated(sig_pos)]
 if(length(sig_pos[!is.na(sig_pos)])!=0)
 {     x_matrix=as.matrix(table(sig_pos))
       x_matrix=cbind(as.data.frame(rownames(x_matrix)),x_matrix)
       #print(x_matrix)
       lastbase=0
       map_store=as.matrix(cbind(as.numeric(GM[,2]),as.numeric(as.vector(GM[,3]))))
       #print(head(map_store))
       #print(as.numeric(map_store[,3]))
        for (j in unique(map_store[,1]))
        {
            index=map_store[,1]==j
            #print(table(index))
            map_store[index,2]=as.numeric(map_store[index,2])+lastbase
            lastbase=max(as.numeric(map_store[index,2]))
            #print(lastbase)
        }
       
       colnames(x_matrix)=c("pos","times")
       #colnames(xz)=c("pos","col")
       new_xz=cbind(x_matrix,map_store[as.numeric(as.character(x_matrix[,1])),])
       #new_xz[,4]=0
       colnames(new_xz)=c("pos","times","chro","xlab")
       
       new_xz=new_xz[!duplicated(new_xz),]
       new_xz[new_xz[,2]>=3,2]=3
       new_xz[,2]=4-new_xz[,2]
       new_xz[new_xz[,2]==3,2]=0

       new_xz=as.matrix(new_xz)
       new_xz=new_xz[new_xz[,2]!="0",]
       new_xz=matrix(new_xz,length(as.vector(new_xz))/4,4)
       #print(new_xz)
       plot.line=TRUE
       #print(new_xz)
}
#print(as.numeric(new_xz[,4]))
#print(head(result0))
# print(as.numeric(new_xz[,1]))
pdf(paste("GAPIT.Manhattan.Mutiple.Plot",colnames(result0)[-c(1:3)],".pdf" ,sep = ""), width = 20,height=6*Nenviron)
par(mfrow=c(Nenviron,1))
for(k in 1:Nenviron)
{ if(k==Nenviron){#par(mfrow=c(Nenviron,1))
        par(mar = c(3,8,1,8))
        }else{
            #par(mfrow=c(Nenviron,1))
        par(mar = c(0,8,1,8))
        
        }
  environ_result=read.csv(paste("GAPIT.",environ_name[k],".GWAS.Results.csv",sep=""),head=T)
  #print(environ_result[as.numeric(new_xz[,1]),])
  result=environ_result[,1:4]
    result=result[match(as.character(GM[,1]),as.character(result[,1])),]
    rownames(result)=1:nrow(result)
    GI.MP=result[,c(2:4)]
    borrowSlot=4
    GI.MP[,borrowSlot]=0 #Inicial as 0
    GI.MP[,5]=1:(nrow(GI.MP))
    GI.MP[,6]=1:(nrow(GI.MP))
    
    
    GI.MP <- GI.MP[!is.na(GI.MP[,1]),]
    GI.MP <- GI.MP[!is.na(GI.MP[,2]),]
    GI.MP[is.na(GI.MP[,3]),3]=1
    
    #Retain SNPs that have P values between 0 and 1 (not na etc)
    GI.MP <- GI.MP[GI.MP[,3]>0,]
    GI.MP <- GI.MP[GI.MP[,3]<=1,]
    #Remove chr 0 and 99
    GI.MP <- GI.MP[GI.MP[,1]!=0,]
    total_chromo=max(GI.MP[,1])
    # print(dim(GI.MP))
    if(!is.null(seqQTN))GI.MP[seqQTN,borrowSlot]=1
    numMarker=nrow(GI.MP)
    bonferroniCutOff=-log10(cutOff/numMarker)
    GI.MP[,3] <-  -log10(GI.MP[,3])
    GI.MP[,5]=1:numMarker
    y.lim <- ceiling(max(GI.MP[,3]))
    
    chm.to.analyze <- unique(GI.MP[,1])
    chm.to.analyze=chm.to.analyze[order(chm.to.analyze)]
    nchr=length(chm.to.analyze)
    GI.MP[,6]=1:(nrow(GI.MP))
    MP_store=GI.MP
        index_GI=MP_store[,3]>=0
        MP_store <- MP_store[index_GI,]
        ticks=NULL
        lastbase=0
        for (i in chm.to.analyze)
        {
            index=(MP_store[,1]==i)
            ticks <- c(ticks, lastbase+mean(MP_store[index,2]))
            MP_store[index,2]=MP_store[index,2]+lastbase
            lastbase=max(MP_store[index,2])
        }
        
        x0 <- as.numeric(MP_store[,2])
        y0 <- as.numeric(MP_store[,3])
        z0 <- as.numeric(MP_store[,1])
        x1=sort(x0)

        position=order(y0,decreasing = TRUE)
        values=y0[position]
        if(length(values)<=DPP)
        {
         index=position[c(1:length(values))]
            }else{
         
        values=sqrt(values)  #This shift the weight a little bit to the low building.
        #Handler of bias plot
        rv=runif(length(values))
        values=values+rv
        values=values[order(values,decreasing = T)]

        theMin=min(values)
        theMax=max(values)
        range=theMax-theMin
        interval=range/DPP

        ladder=round(values/interval)
        ladder2=c(ladder[-1],0)
        keep=ladder-ladder2
        index=position[which(keep>=0)]
        }
        
        
        x=x0[index]
        y=y0[index]
        z=z0[index]
        # print(length(x))

        #Extract QTN
        #if(!is.null(seqQTN))MP_store[seqQTN,borrowSlot]=1
        #if(!is.null(interQTN))MP_store[interQTN,borrowSlot]=2
        QTN=MP_store[which(MP_store[,borrowSlot]==1),]
        #Draw circles with same size and different thikness
        size=1 #1
        ratio=10 #5
        base=1 #1
        numCHR=nchr
        themax=ceiling(max(y))
        themin=floor(min(y))
        wd=((y-themin+base)/(themax-themin+base))*size*ratio
        s=size-wd/ratio/2
        ncycle=ceiling(nchr/5)
        ncolor=5*ncycle
        ncolor=band*ncycle

        thecolor=seq(1,nchr,by= ncycle)
        mypch=1
        #plot.color= rainbow(ncolor+1)
        col.Rainbow=rainbow(ncolor+1)     
        col.FarmCPU=rep(c("#CC6600","deepskyblue","orange","forestgreen","indianred3"),ceiling(numCHR/5))
        col.Rushville=rep(c("orangered","navyblue"),ceiling(numCHR/2))    
        col.Congress=rep(c("deepskyblue3","firebrick"),ceiling(numCHR/2))
        col.Ocean=rep(c("steelblue4","cyan3"),ceiling(numCHR/2))    
        col.PLINK=rep(c("gray10","gray70"),ceiling(numCHR/2))     
        col.Beach=rep(c("turquoise4","indianred3","darkolivegreen3","red","aquamarine3","darkgoldenrod"),ceiling(numCHR/5))
        #col.Oceanic=rep(c( '#EC5f67',  '#F99157',  '#FAC863',  '#99C794',  '#5FB3B3',  '#6699CC',  '#C594C5',  '#AB7967'),ceiling(numCHR/8))
        #col.Oceanic=rep(c( '#EC5f67',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5',  '#AB7967'),ceiling(numCHR/6))
        col.Oceanic=rep(c(  '#EC5f67',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5'),ceiling(numCHR/5))
        col.cougars=rep(c(  '#990000',    'dimgray'),ceiling(numCHR/2))
    
        if(plot.style=="Rainbow")plot.color= col.Rainbow
        if(plot.style =="FarmCPU")plot.color= col.Rainbow
        if(plot.style =="Rushville")plot.color= col.Rushville
        if(plot.style =="Congress")plot.color= col.Congress
        if(plot.style =="Ocean")plot.color= col.Ocean
        if(plot.style =="PLINK")plot.color= col.PLINK
        if(plot.style =="Beach")plot.color= col.Beach
        if(plot.style =="Oceanic")plot.color= col.Oceanic
        if(plot.style =="cougars")plot.color= col.cougars
    
        #plot.color=rep(c( '#EC5f67',    '#FAC863',  '#99C794',    '#6699CC',  '#C594C5'),ceiling(ncolor/5))

            plot(y~x,xlab="",ylab="" ,ylim=c(0,themax),
            cex.axis=4, cex.lab=4, ,col=plot.color[z],axes=FALSE,type = "p",pch=mypch,lwd=wd,cex=s+2.5,cex.main=4)
            mtext(side=2,expression(-log[10](italic(p))),line=3, cex=2.5)
        #Label QTN positions
        #print(head(QTN))
        #print(head(interQTN))
          if(!simulation){abline(v=QTN[2], lty = 2, lwd=1.5, col = "grey")}else{
            #print("$$$$$$")
          points(QTN[,2], QTN[,3], pch=20, cex=2.5,lwd=2.5,col="black")
          #points(interQTN[,2], interQTN[,3], type="p",pch=8, cex=1,lwd=1.5,col="dimgrey")
          }
        
        #}
        if(plot.line){
          #print(x)
          #print(as.numeric(new_xz[,2]))
          # if(!is.null(nrow(new_xz)))  {abline(v=as.numeric(new_xz[,4]),col=plot.color[as.numeric(new_xz[,3])],lty=as.numeric(new_xz[,2]),untf=T,lwd=3)
          if(!is.null(nrow(new_xz)))  {abline(v=as.numeric(new_xz[,4]),col="grey",lty=as.numeric(new_xz[,2]),untf=T,lwd=3)
             }else{abline(v=as.numeric(new_xz[1]),col=plot.color[as.numeric(new_xz[3])],lty=as.numeric(new_xz[2]),untf=T,lwd=3)
             }
        }
        #Add a horizontal line for bonferroniCutOff
        abline(h=bonferroniCutOff,lty=2,untf=T,lwd=3,col="red")
        axis(2, xaxp=c(1,themax,5),cex.axis=2.5,tick=F)
        if(k==Nenviron)axis(1, at=ticks,cex.axis=2.7,labels=chm.to.analyze,tick=F)
        mtext(side=4,paste(environ_name[k],sep=""),line=3,cex=2.5)
box()



}#end of environ_name

dev.off()
print("GAPIT.Manhattan.Mutiple.Plot has done !!!")
return(list(multip_mapP=result0,xz=new_xz))
} #end of GAPIT.Manhattan
#=============================================================================================
`GAPIT.Numericalization` <-
function(x,bit=2,effect="Add",impute="None", Create.indicator = FALSE, Major.allele.zero = FALSE, byRow=TRUE){
#Object: To convert character SNP genotpe to numerical
#Output: Coresponding numerical value
#Authors: Feng Tian and Zhiwu Zhang
# Last update: May 30, 2011 
##############################################################################################
if(bit==1)  {
x[x=="X"]="N"
x[x=="-"]="N"
x[x=="+"]="N"
x[x=="/"]="N"
x[x=="K"]="Z" #K (for GT genotype)is replaced by Z to ensure heterozygose has the largest value
}

if(bit==2)  {
x[x=="XX"]="N"
x[x=="--"]="N"
x[x=="++"]="N"
x[x=="//"]="N"
x[x=="NN"]="N"
x[x=="00"]="N"

}

n=length(x)
lev=levels(as.factor(x))
lev=setdiff(lev,"N")
#print(lev)
len=length(lev)
#print(len)
#Jiabo creat this code to convert AT TT to 1 and 2. 2018.5.29
if(bit==2)
{
   inter_store=c("AT","AG","AC","TA","GA","CA","GT","TG","GC","CG","CT","TC")
   inter=intersect(lev,inter_store)
   if(length(inter)>1)
   {
     x[x==inter[2]]=inter[1]
     n=length(x)
     lev=levels(as.factor(x))
     lev=setdiff(lev,"N")
     #print(lev)
     len=length(lev)
   }
   # if(len==2)
   # { #inter=intersect(lev,inter_store)
   #   if(!setequal(character(0),inter))
   #   { 
   #     lev=union(lev,"UU")
   #     len=len+1
   #   }
   # }
   if(len==3&bit==2)
   {
     inter=intersect(lev,inter_store)
   }
}
#print(lev)
#print(len)
#Jiabo code is end here

#Genotype counts
count=1:len
for(i in 1:len){
	count[i]=length(x[(x==lev[i])])
}

#print(count)

if(Major.allele.zero){
  if(len>1 & len<=3){
    #One bit: Make sure that the SNP with the major allele is on the top, and the SNP with the minor allele is on the second position
    if(bit==1){ 
      count.temp = cbind(count, seq(1:len))
      if(len==3) count.temp = count.temp[-3,]
      count.temp <- count.temp[order(count.temp[,1], decreasing = TRUE),]
      if(len==3)order =  c(count.temp[,2],3)else order = count.temp[,2]
    }

    #Two bit: Make sure that the SNP with the major allele is on the top, and the SNP with the minor allele is on the third position
    if(bit==2){ 
      count.temp = cbind(count, seq(1:len))
      if(len==3) count.temp = count.temp[-2,]
      count.temp <- count.temp[order(count.temp[,1], decreasing = TRUE),]
      if(len==3) order =  c(count.temp[1,2],2,count.temp[2,2])else order = count.temp[,2]
    }

    count = count[order]
    lev = lev[order]

  }   #End  if(len<=1 | len> 3)
} #End  if(Major.allele.zero)

#print(x)

#make two  bit order genotype as AA,AT and TT, one bit as A(AA),T(TT) and X(AT)
if(bit==1 & len==3){
	temp=count[2]
	count[2]=count[3]
	count[3]=temp
}

#print(lev)
#print(count)
position=order(count)

#Jiabo creat this code to convert AT TT to 1 and 2.2018.5.29

lev1=lev
if(bit==2&len==3) 
{
lev1[1]=lev[count==sort(count)[1]]
lev1[2]=lev[count==sort(count)[2]]
lev1[3]=lev[count==sort(count)[3]]
position=c(1:3)
lev=lev1
}
#print(lev)
#print(position)
#print(inter)
#Jiabo code is end here
if(bit==1){
  lev0=c("R","Y","S","W","K","M") 
  inter=intersect(lev,lev0)
}

#1status other than 2 or 3
if(len<=1 | len> 3)x=0

#2 status
if(len==2)
{
  
  if(!setequal(character(0),inter))
  {
    x=ifelse(x=="N",NA,ifelse(x==inter,1,0)) 
    }else{
    x=ifelse(x=="N",NA,ifelse(x==lev[1],0,2))     # the most is set 0, the least is set 2
  }
}

#3 status
if(bit==1){
	if(len==3)x=ifelse(x=="N",NA,ifelse(x==lev[1],0,ifelse(x==lev[3],1,2)))
}else{
	if(len==3)x=ifelse(x=="N",NA,ifelse(x==lev[lev!=inter][1],0,ifelse(x==inter,1,2)))
}

#print(paste(lev,len,sep=" "))
#print(position)

#missing data imputation
if(impute=="Middle") {x[is.na(x)]=1 }

if(len==3){
	if(impute=="Minor")  {x[is.na(x)]=position[1]  -1}
	if(impute=="Major")  {x[is.na(x)]=position[len]-1}

}else{
	if(impute=="Minor")  {x[is.na(x)]=2*(position[1]  -1)}
	if(impute=="Major")  {x[is.na(x)]=2*(position[len]-1)}
}

#alternative genetic models
if(effect=="Dom") x=ifelse(x==1,1,0)
if(effect=="Left") x[x==1]=0
if(effect=="Right") x[x==1]=2

if(byRow) {
  result=matrix(x,n,1)
}else{
  result=matrix(x,1,n)  
}

return(result)
}#end of GAPIT.Numericalization function
#=============================================================================================

`GAPIT.PCA` <-
function(X,taxa, PC.number = min(ncol(X),nrow(X)),file.output=TRUE,PCA.total=0,PCA.col=NULL,PCA.3d=FALSE){
# Object: Conduct a principal component analysis, and output the prinicpal components into the workspace,
#         a text file of the principal components, and a pdf of the scree plot
# Authors: Alex Lipka and Hyun Min Kang
# Last update: May 31, 2011  
############################################################################################## 
#Conduct the PCA 
print("Calling prcomp...")
PCA.X <- prcomp(X)
eigenvalues <- PCA.X$sdev^2
evp=eigenvalues/sum(eigenvalues)
nout=min(10,length(evp))
xout=1:nout
if(is.null(PCA.col)) PCA.col="red"

print("Creating PCA graphs...")
#Create a Scree plot 
if(file.output & PC.number>1) {
pdf("GAPIT.PCA.eigenValue.pdf", width = 12, height = 12)
  par(mar=c(5,5,4,5)+.1,cex=2)
  #par(mar=c(10,9,9,10)+.1)
  plot(xout,eigenvalues[xout],type="b",col="blue",xlab="Principal components",ylab="Variance")
  par(new=TRUE)
  plot(xout,evp[xout]*100,type="n",col="red",xaxt="n",yaxt="n",xlab="",ylab="")
  axis(4)
  mtext("Percentage (%)",side=4,line=3,cex=2)
dev.off()

pdf("GAPIT.PCA.2D.pdf", width = 8, height = 8)
par(mar = c(5,5,5,5))
maxPlot=min(as.numeric(PC.number[1]),3)

for(i in 1:(maxPlot-1)){
for(j in (i+1):(maxPlot)){
plot(PCA.X$x[,i],PCA.X$x[,j],xlab=paste("PC",i,sep=""),ylab=paste("PC",j,sep=""),pch=19,col=PCA.col,cex.axis=1.3,cex.lab=1.4, cex.axis=1.2, lwd=2,las=1)

}
}
dev.off()

#output 3D plot
if(PCA.3d==TRUE)
{   
  if(1>2)
  {if(!require(lattice)) install.packages("lattice")
   library(lattice)
   pca=as.data.frame(PCA.X$x)
   
   png(file="example%03d.png", width=500, heigh=500)
    for (i in seq(10, 80 , 1)){
        print(cloud(PC1~PC2*PC3,data=pca,screen=list(x=i,y=i-40),pch=20,color="red",
        col.axis="blue",cex=1,cex.lab=1.4, cex.axis=1.2,lwd=3))
        }
    dev.off()
    system("convert -delay 40 *.png GAPIT.PCA.3D.gif")
    
    # cleaning up
    file.remove(list.files(pattern=".png"))
    }

    if(!require(rgl)) install.packages("rgl")
    if(!require(rglwidget)) install.packages("rglwidget")
    library(rgl)
    
    PCA1 <- PCA.X$x[,1]
    PCA2 <- PCA.X$x[,2]
    PCA3 <- PCA.X$x[,3]
    plot3d(PCA1, PCA2, PCA3, col = "white",radius=0.01)
    num_col=length(unique(PCA.col))
    if(num_col==1)
    { 
      sids1 <- spheres3d(PCA1, PCA2, PCA3, col = PCA.col,radius=1)
      widgets<-rglwidget(width = 900, height = 900) %>%toggleWidget(ids = sids1, label = "PCA")
    }else if(num_col==2)
    {
      index1=PCA.col==unique(PCA.col)[1]
      index2=PCA.col==unique(PCA.col)[2]
      
      sids1 <- spheres3d(PCA1[index1], PCA2[index1], PCA3[index1], col = PCA.col[index1],radius=1)
      sids2 <- spheres3d(PCA1[index2], PCA2[index2], PCA3[index2], col = PCA.col[index2],radius=1)
      widgets<-rglwidget(width = 900, height = 900) %>%toggleWidget(ids = sids1, label = "Population 1")%>%toggleWidget(ids = sids2, label = "Population 2")
    }else if(num_col==3)
    {
      index1=PCA.col==unique(PCA.col)[1]
      index2=PCA.col==unique(PCA.col)[2]
      index3=PCA.col==unique(PCA.col)[3]
      
      sids1 <- spheres3d(PCA1[index1], PCA2[index1], PCA3[index1], col = PCA.col[index1],radius=1)
      sids2 <- spheres3d(PCA1[index2], PCA2[index2], PCA3[index2], col = PCA.col[index2],radius=1)
      sids3 <- spheres3d(PCA1[index3], PCA2[index3], PCA3[index3], col = PCA.col[index3],radius=1)
      widgets<-rglwidget(width = 900, height = 900) %>%toggleWidget(ids = sids1, label = "Population 1")%>%toggleWidget(ids = sids2, label = "Population 2")%>%toggleWidget(ids = sids3, label = "Population 3")
    }else if(num_col==4)
    {
      index1=PCA.col==unique(PCA.col)[1]
      index2=PCA.col==unique(PCA.col)[2]
      index3=PCA.col==unique(PCA.col)[3]
      index4=PCA.col==unique(PCA.col)[4]
      
      sids1 <- spheres3d(PCA1[index1], PCA2[index1], PCA3[index1], col = PCA.col[index1],radius=1)
      sids2 <- spheres3d(PCA1[index2], PCA2[index2], PCA3[index2], col = PCA.col[index2],radius=1)
      sids3 <- spheres3d(PCA1[index3], PCA2[index3], PCA3[index3], col = PCA.col[index3],radius=1)
      sids4 <- spheres3d(PCA1[index4], PCA2[index4], PCA3[index4], col = PCA.col[index4],radius=1)
      widgets<-rglwidget(width = 900, height = 900) %>%toggleWidget(ids = sids1, label = "Population 1")%>%toggleWidget(ids = sids2, label = "Population 2")%>%toggleWidget(ids = sids3, label = "Population 3")%>%toggleWidget(ids = sids4, label = "Population 4")
    }
    if (interactive()) widgets
    htmltools::save_html(widgets, "Interactive.PCA.html")
}
    if(!require(scatterplot3d)) install.packages("scatterplot3d")
    library(scatterplot3d)

    pdf("GAPIT.PCA.3D.pdf", width = 7, height = 7)
    par(mar = c(5,5,5,5))
    scatterplot3d(PCA.X$x[,1],PCA.X$x[,2],PCA.X$x[,3],xlab=paste("PC",1,sep=""),ylab=paste("PC",2,sep=""),zlab=paste("PC",3,sep="") ,pch=20,color=PCA.col,col.axis="blue",cex=1,cex.lab=1.4, cex.axis=1.2,lwd=3,angle=55,scale.y=0.7)
    dev.off()
}
print("Joining taxa...")
#Extract number of PCs needed
PCs <- cbind(taxa,as.data.frame(PCA.X$x))

#Remove duplicate (This is taken care by QC)
#PCs.unique <- unique(PCs[,1])
#PCs <-PCs[match(PCs.unique, PCs[,1], nomatch = 0), ]



print("Exporting PCs...")
#Write the PCs into a text file
if(file.output) write.table(PCs[,1:(PCA.total+1)], "GAPIT.PCA.csv", quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

if(file.output) write.table(PCA.X$rotation[,1:PC.number], "GAPIT.PCA.loadings.csv", quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

if(file.output) write.table(eigenvalues, "GAPIT.PCA.eigenvalues.csv", quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

#Return the PCs
return(list(PCs=PCs,EV=PCA.X$sdev^2,nPCs=NULL))
}
#=============================================================================================

`GAPIT.PCA2Power` <-function(myGD=NULL,myGM=NULL,method="MLM",myPCA=NULL,rep=NULL,h2=NULL,NQTN=NULL,seed=123){
# Object: compare to Power against FDR for GLM,MLM,CMLM,ECMLM,SUPER
# Output: find the optimum number of PCA in model
# Authors: Jiabo Wang
# Last update: Feb 1, 2020 
############################################################################################## 
if(is.null(myGD)||is.null(myGM)){stop("Read data Invalid. Please select read valid flies !")}

if(is.null(rep))
	rep=50
if(is.null(h2))
	h2=0.7
if(is.null(NQTN))
	NQTN=20

X<-myGD[,-1]
taxa<-as.character(myGD[,1])



myGAPIT <- GAPIT(
       #Y=myY[,c(1,2)],
       GD=myGD,
       GM=myGM,
       #model=method[j],
       #memo="simu",
       PCA.total=5,
       file.output=F
       )
myPCA=myGAPIT$PC
##simulation phyenotype
##-------------------------##
n=nrow(X)
m=ncol(X)
npc=ncol(myPCA)-1
legend_text=paste("NUM of PCA~",1:npc,sep="")
nm=length(method)

if(!is.null(seed))set.seed(seed)
  
  power_npca=NULL
  fdr_npca=NULL
  Para=list(h2=h2,NQTN=NQTN)

j=1
for(k in 1:npc)
{
	wholepower=NULL
    wholefdr=NULL
    for(i in 1:rep)
    {
       mysimulation<-GAPIT(Para=Para,GD=myGD,GM=myGM)
       posi=mysimulation$QTN.position
       myY=mysimulation$Y
  
       print(paste("*****************","GWAS by GAPIT...",method[j]," model ",i,sep=""))

       myGAPIT <- GAPIT(
       Y=myY[,c(1,2)],
       GD=myGD,
       GM=myGM,
       model=method[j],
       memo="simu",
       Multi_iter=F,
       file.output=F
       )
       mypower<-GAPIT.Power(WS=c(1), maxOut=m,seqQTN=posi,GM=myGM,GWAS=myGAPIT$GWAS)
       wholepower=cbind(wholepower,mypower$Power)
       wholefdr=cbind(wholefdr,mypower$FDR)
       gc()
    }


    power_rep=apply(wholepower,1,mean)
    fdr_rep=apply(wholefdr,1,mean)
    power_npca=cbind(power_npca,power_rep)
    fdr_npca=cbind(fdr_npca,fdr_rep)

} # end of npca


write.csv(cbind(power_npca,fdr_npca),paste(h2,"_",NQTN,"_",method[j],".Power.by.FDR_rep_",rep,".csv",sep=""))
# write.csv(power_rep,paste(h2,"_",NQTN,"_",method[j],".Power.by.FDR_rep_",rep,".csv",sep=""))

    pdf(paste("GAPIT.Power_",h2,"_",NQTN,"_" ,"compare in ",method[j], ".pdf", sep = ""), width = 4.5, height = 4.5,pointsize=9)
    par(mar = c(5,6,5,3))
	#win.graph(width=6, height=4, pointsize=9)
	#palette(c("blue","red","green4","brown4","orange",rainbow(5)))
	ncol=rainbow(npc)
	palette(c("green4","red","blue","brown4","orange",rainbow(npc)))
	plot(power_npca[,1]~fdr_npca[,1],bg="lightgray",xlab="FDR",ylab="Power",ylim=c(0,1),xlim=c(0,1),main="Power against FDR",type="o",pch=20,col=ncol[1],cex=1,cex.lab=1.3, cex.axis=1, lwd=1,las=1)
    for(i in 2:npc){
    lines(power_npca[,i]~fdr_npca[,i], lwd=1,type="o",pch=20,col=ncol[i])
	}
	# lines(rep.power.CMLM[,6]~rep.FDR.CMLM[,6], lwd=2,type="o",pch=20,col=3)
	# lines(rep.power.MLM[,6]~rep.FDR.MLM[,6], lwd=2,type="o",pch=20,col=4)
	# lines(rep.power.GLM[,6]~rep.FDR.GLM[,6], lwd=2,type="o",pch=20,col=5)
	legend("bottomright",legend_text, pch = 20, lty =1,col=ncol,lwd=1,cex=1.0,bty="n")
	#

dev.off()

rm(myGAPIT)
} #end of whole function




`GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure` <-
function(PWI = PWI, FDR.Rate = 0.05, FDR.Procedure = "BH"){
#Object: Conduct the Benjamini-Hochberg FDR-Controlling Procedure
#Output: PWIP, number.of.significant.SNPs
#Authors: Alex Lipka and Zhiwu Zhang 
# Last update: May 5, 2011 
##############################################################################################
#Make sure that your compouter has the latest version of Bioconductor (the "Biobase" package) and multtest

if(is.null(PWI))
{
PWIP=NULL
number.of.significant.SNPs = 0
}

if(!is.null(PWI))
{  
 
    #library(multtest)
    
    if(dim(PWI)[1] == 1){
     PWIP <- cbind(PWI, PWI[4])
     colnames(PWIP)[9] <- "FDR_Adjusted_P-values"
    }
   
    if(dim(PWI)[1] > 1){ 
    #mt.rawp2adjp Performs the Simes procedure.  The output should be two columns, Left column: originial p-value
    #Right column: Simes corrected p-value
    res <- mt.rawp2adjp(PWI[,4], FDR.Procedure)

    #This command should order the p-values in the order of the SNPs in the data set
  adjp <- res$adjp[order(res$index), ]

  #round(adjp[1:7,],4)
    #Logical statment: 0, if Ho is not rejected; 1, if  Ho is rejected, by the Simes corrected p-value
#  temp <- mt.reject(adjp[,2], FDR.Rate)

    #Lists all number of SNPs that were rejected by the BY procedure
  #temp$r

    #Attach the FDR adjusted p-values to AS_Results

  PWIP <- cbind(PWI, adjp[,2])

    #Sort these data by lowest to highest FDR adjusted p-value
  PWIP <- PWIP[order(PWIP[,4]),]
  
  colnames(PWIP)[9] <- "FDR_Adjusted_P-values"
#  number.of.significant.SNPs = temp$r
  }
  #print("GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure accomplished successfully!")
}  
  #return(list(PWIP=PWIP, number.of.significant.SNPs = number.of.significant.SNPs))
  return(list(PWIP=PWIP))
}#GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure ends here
#=============================================================================================

`GAPIT.Phenotype.PCA.View` <-function(PC=NULL,myY=NULL){
# Object: Analysis PCA effection for Phenotype data ,result:a pdf of the scree plot
# myG:Genotype data
# myY:Phenotype data

# Authors: You Tang
# Last update: Sep 7, 2015 
############################################################################################## 
print("GAPIT.Phenotype.PCA.View")
if(is.null(PC)){stop("Validation Invalid. Please input four PC value  !")}
if(is.null(myY)){stop("Validation Invalid. Please select read valid Phenotype flies  !")}

y<-myY[!is.na(myY[,2]),c(1:2)]

traitname=colnames(y)[2]

cv1<-PC[!is.na(match(PC[,1],y[,1])),]
y1<-y[!is.na(match(y[,1],cv1[,1])),]

y2<-y1[order(y1[,1]),]
cv2<-cv1[order(cv1[,1]),]
lcor=round(cor(y2[,-1],cv2[,-1])*100)/100

y.range=max(y2[,2])-min(y2[,2])
y.mean=mean(y2[,2])
n.col=54
y.int=round(abs(y2[,2]-y.mean)/y.range*(.5*n.col-1)*2)+1
mycol=rainbow(n.col)
y.col=mycol[y.int]
y.lab=paste("PC",seq(1:4)," (r=",lcor,")",sep="")

pdf(paste("GAPIT.",traitname,"_vs_PC.pdf",sep=""), width =9, height = 6)
#par(mar = c(5,5,5,5))
par(mar = c(5,5,2,2))
par(mfrow=c(2,2))

plot(y2[,2],cv2[,2],bg="lightgray",xlab="Phenotype",ylab=y.lab[1],main="",cex.lab=1.4,col=y.col)
if(ncol(PC)>2) plot(y2[,2],cv2[,3],bg="lightgray",xlab="Phenotype",ylab=y.lab[2],main="",cex.lab=1.4,col=y.col)
if(ncol(PC)>3) plot(y2[,2],cv2[,4],bg="lightgray",xlab="Phenotype",ylab=y.lab[3],main="",cex.lab=1.4,col=y.col)
if(ncol(PC)>4) plot(y2[,2],cv2[,5],bg="lightgray",xlab="Phenotype",ylab=y.lab[4],main="",cex.lab=1.4,col=y.col)

dev.off()


print(paste("GAPIT.Phenotype.PCA.View ", ".output pdf generate.","successfully!" ,sep = ""))

#GAPIT.Phenotype.View
}
#=============================================================================================
`GAPIT.Phenotype.Simulation` <-
  function(GD,GM=NULL,h2=.75,NQTN=10,QTNDist="normal",effectunit=1,category=1,r=0.25,CV,cveff=NULL,a2=0,adim=2){
    #Object: To simulate phenotype from genotye
    #Input: GD - n by m +1 dataframe or n by m big.matrix
    #intput: h2 - heritability
    #intput: NQTN - number of QTNs
    #intput: QTNDist - Distribution of QTN, options are  "geometry", "normal"
    #intput: effectunit - effect of fitst QTN, the nect effect is its squre
    #intput: theSeed - seed for randomization
    #Output: Y,U,E,QTN.Position, and effect
    #Straitegy: NA
    #Authors: Qishan Wang and Zhiwu Zhang
    #Start  date: April 4, 2013
    #Last update: April 4, 2013    
    #Set orientation
    #Strategy: the number of rows in GD and GM are the same if GD has SNP as row
##############################################################################################   
    #print("GAPIT.Phenotype.Simulation")
    
    nm=ncol(GD)-1   #Initial by assume GD has snp in col
    if(!is.null(GM)) nm=nrow(GM)
    ngd1=nrow(GD)
    ngd2=ncol(GD)
    ngd1=abs(ngd1-nm)
    ngd2=abs(ngd2-nm)
    orientation="row"
    ns=ncol(GD)
    if(min(ngd1,ngd2)>0){
      orientation="col"
      ns=nrow(GD)
    }
    
    
    
    n= ns   #number of samples
    m=nm  #number of markers
    
    #Set QTN effects
    if (QTNDist=="normal"){ addeffect<-rnorm(NQTN,0,1)
    }else
    {addeffect=effectunit^(1:NQTN)}
    
    
    #Simulating Genetic effect
    #r=sample(2:m,NQTN,replace=F)
    QTN.position=sample(1:m,NQTN,replace=F)
    if(orientation=="col") SNPQ=as.matrix(GD[,(QTN.position+1)])
    if(orientation=="row") SNPQ=t(as.matrix(GD[QTN.position,]))
    
    #Replace non-variant QTNs  (does not work yet)
    #inComplete=TRUE
    #while(inComplete){
    #  inComplete=FALSE
    #  myVar=apply(SNPQ,2,var)
    #  index=which(myVar==0)
    #  nInVar=length(index)
    #  if(nInVar>0){
    #    inComplete=TRUE
    #    New.position=sample(1:m,nInVar,replace=F)
    #    if(orientation=="col") SNPQ[,index]=as.matrix(GD[,(New.position+1)])
    #    if(orientation=="row") SNPQ[,index]=t(as.matrix(GD[New.position,]))
    #  }
    #}#end of while
    
    
    effect=SNPQ%*%addeffect
    effectvar=var(effect)

#Interaction
cp=0*effect
nint= adim
if(a2>0&NQTN>=nint){
  for(i in nint:nint){
    Int.position=sample(NQTN,i,replace=F)
    cp=apply(SNPQ[,Int.position],1,prod)
  }

  cpvar=var(cp)
  
  intvar=(effectvar-a2*effectvar)/a2
  if(is.na(cp[1]))stop("something wrong in simulating interaction")
  if(cpvar>0){
    #print(c(effectvar,intvar,cpvar,var(cp),a2))
    #print(dim(cp))
    cp=cp/sqrt(cpvar)
    cp=cp*sqrt(intvar)
    effectvar=effectvar+intvar
  }else{cp=0*effect}
}   

#Residual variance    
    if(h2 >0){
    	residualvar=(effectvar-h2*effectvar)/h2
    	}else{
      residualvar=1
      effect= effect*0
    }
    
    #Variance explained by each SNP
    effectInd=SNPQ%*%diag(addeffect)
    varInd=apply(effectInd,2,var)
    effectSeq=order(varInd,decreasing = TRUE)
    
    #Simulating Residual and phenotype
    residual=rnorm(n,0,sqrt(residualvar))

    #environment effect
    if(!is.null(cveff)){
    #print(cveff)
    vy=effectvar+residualvar
    #print(vy)
    ev=cveff*vy/(1-cveff)
    ec=sqrt(ev)/sqrt(diag(var(CV[,-1])))    
    enveff=as.matrix(myCV[,-1])%*%ec
    
    #print(cbind(effectvar,residualvar,ev,ec))
    #print(cbind(effect,enveff,residual))
    
    residual=residual+enveff
    }
    
    #Simulating  phenotype
    y=effect+residual+cp
    
    if(orientation=="col") myY=cbind(as.data.frame(GD[,1]),as.data.frame(y))
    if(orientation=="row") myY=cbind(NA,as.data.frame(y))
    
    #Convert to category phenotype
    if(category>1){
      myQuantile =(0:category)/category
      y.num= myY[,2]
      cutoff=quantile(y.num, myQuantile)
      y.cat= .bincode(y.num,cutoff,include.lowest = T)
      myY[,2]=y.cat
    }
    
    #Binary phenotype
    if(category==0){
      #Standardization
      #print("Binary phenotype")
      #print(mean(effect))
      #print(sqrt(effectvar))
      #print(dim(effect))
      x=(effect-mean(effect))
      x=x/as.numeric(sqrt(effectvar))
      myF=GAPIT.BIPH(x,h2=h2,r=r)
      p=runif(n)
      index=p<myF
      myY[index,2]=1
      myY[!index,2]=0
    }
    
    #print("Phenotype simulation accoplished")
    return(list(Y=myY,u=effect,i=cp,e=residual,QTN.position=QTN.position,effect=addeffect))
  } #enf of phenotype simulation function
#=============================================================================================


`GAPIT.Phenotype.View` <-function(myY=NULL,traitname="_",memo="_"){
# Object: Analysis for Phenotype data:Distribution of density,Accumulation,result:a pdf of the scree plot
# myY:Phenotype data

# Authors: You Tang
# Last update: Sep 7, 2015 
############################################################################################## 
print("GAPIT.Phenotype.View in press...")
if(is.null(myY)){stop("Validation Invalid. Please select read valid Phenotype flies  !")}

y<-myY[!is.na(myY[,2]),2]
obs<-as.matrix(y)

traitname=colnames(myY)[2]

pdf(paste("GAPIT",memo,traitname,"phenotype_view.pdf",sep ="."), width =10, height = 6)
par(mar = c(5,5,5,5))

par(mfrow=c(2,2))
plot(obs,pch=1)
#hist(obs)
hist(obs,xlab="Density",main="",breaks=12, cex.axis=1,col = "gray")
boxplot(obs)
plot(ecdf(obs),col="red",bg="lightgray",xlab="Density",ylab="Accumulation",main="")

dev.off()


print(paste("GAPIT.Phenotype.View ", ".output pdf generate.","successfully!" ,sep = ""))

#GAPIT.Phenotype.View
}
#=============================================================================================
`GAPIT.Power` <-
function(WS=c(1e0,1e3,1e4,1e5,1e6,1e7), GM=NULL,seqQTN=NULL,GWAS=NULL,maxOut=100,
alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),MaxBP=1e10){
#Object: To evaluate power and FDR for the top (maxOut) positive interval defined by WS
#Input: WS- window size 
#Input: GM - m by 3  matrix for SNP name, chromosome and BP
#Input: seqQTN - s by 1 vecter for index of QTN on GM (+1 for GDP column wise)
#Input: GWAS- SNP,CHR,BP,P,MAF
#maxOut: maximum number of rows to report
#Requirement: None
#Output: Table and Plots
#Authors: Zhiwu Zhang
# Date  start: April 2, 2013
# Last update: April 2, 2013
##############################################################################################
#print("GAPIT.Power Started")
if(is.null(seqQTN) | is.null(GM) | is.null(GWAS)) return(list(FDR=NULL,Power=NULL,Power.Alpha=NULL,alpha=NULL))

#-----------------FDR and Power analysis-------------------------
#Information needed: myGAPIT$GWAS,myGM and QTN(r)
nWin=matrix(NA,length(WS),1)

format_GWAS=cbind(GWAS[,1:4],NA,NA,NA) 

names(format_GWAS)<-c("SNP","Chromosome","Position","P.value","maf","nobs","FDR_Adjusted_P-values")
myGM=GM

#loop window size here

theWS=1
for (theWS in 1:length(WS)){

ws=WS[theWS]
#Label QTN intervals
#Restore original order
#QTNList=r-1
QTNList=seqQTN
myGM2=cbind(myGM,rep(0,nrow(myGM)),1:nrow(myGM),NA) #Initial QTN status as 0


#Extract QTN positions
myGM2[,6]=floor((as.numeric(as.character(myGM2[,2]))*MaxBP+as.numeric(as.character(myGM2[,3])))/ws) #Label QTN as 1

QTNInterval=myGM2[QTNList,6]
thePosition=myGM2[,6] %in% QTNInterval

myGM2[thePosition,4]=1 #Label QTN as 1
names(myGM2) <- c("SNP","Chromosome","Position", "QTN","Seq") 

#Merge to P vlaues
#GWAS<- merge(myGAPIT$GWAS[,1:7],myGM2[,c(1,4,5)],by="SNP")
    GWAS<- merge(format_GWAS[,1:7],myGM2[,c(1,4,5)],by="SNP")#xiaoalei changed

#checking
#zw=GWAS[order(GWAS[,4],decreasing = FALSE),]
#zw=GWAS[order(GWAS[,8],decreasing = TRUE),]
#head(zw)

#Creat windows
myQTN=GAPIT.Specify(GI=GWAS[,1:3],GP=GWAS,bin.size=ws,MaxBP=MaxBP)
QTN=GWAS[myQTN$index,]

#Calculate alpha
qtnLoc=which(QTN[,8]==1) #get the position of QTN
P.QTN=QTN[qtnLoc,4] #p value of QTN
P.marker=QTN[-qtnLoc,4] #p value of non qtn (marker)
cutOff=matrix(quantile(P.marker, alpha,na.rm=TRUE),ncol=1)#xiaoalei changed
myPower.Alpha=apply(cutOff,1,function(x){
  Power=length(which(P.QTN<x))/length(P.QTN)
})

      
#Sort on P
#QTN=QTN[order(as.numeric(as.character(QTN[,3])),decreasing = FALSE),]
#QTN=QTN[order(as.numeric(as.character(QTN[,2])),decreasing = FALSE),]
QTN=QTN[order(as.numeric(as.character(QTN[,4])),decreasing = FALSE),]
names(QTN) <- c("SNP","Chromosome","Position", "P","FDR","Power","Order","QTN","Seq") 

#calculate power
QTN[,7]=1:nrow(QTN)
QTN[,5]=cumsum(1-QTN[,8])/QTN[,7]   #FDR
QTN[,6]=cumsum(QTN[,8]) /sum(QTN[,8] ) #Power

#Save results 
if (theWS==1){
nWin=matrix(NA,length(WS),1)
FDR=array(NA,dim=c(nrow(QTN),length(WS)))
Power=array(NA,dim=c(nrow(QTN),length(WS)))
Power.Alpha=array(NA,dim=c(length(alpha),length(WS)))
}

nWin[theWS]=nrow(QTN)
FDR[1:nWin[theWS],theWS]=QTN[,5]
Power[1:nWin[theWS],theWS]=QTN[,6]
Power.Alpha[,theWS]=myPower.Alpha

}#end of window size loop 
nOut=min(maxOut,max(nWin))
index=1:nOut
return(list(FDR=FDR[index,],Power=Power[index,],Power.Alpha=Power.Alpha,alpha=alpha))
}#end of GAPIT.Power
#=============================================================================================


`GAPIT.Power.compare` <-function(myG=NUll,myGD=NULL,myGM=NULL,myKI=NULL,myY=NULL,myCV=NULL,rep=NULL,h2=NULL,NQTN=NULL){
# Object: compare to Power against FDR for GLM,MLM,CMLM,ECMLM,SUPER
# rep:repetition times
# Authors: You Tang & Jiabo Wang
# Last update: Feb 1, 2020 
############################################################################################## 
if(is.null(myG)||is.null(myGD)||is.null(myGM)||is.null(myKI)){stop("Read data Invalid. Please select read valid flies !")}

if(is.null(rep))
	rep=100
if(is.null(h2))
	h2=0.85
if(is.null(NQTN))
	NQTN=5

X<-myGD[,-1]
taxa<-as.character(myGD[,1])

##simulation phyenotype
##-------------------------##
n=nrow(X)
m=ncol(X)

rep.power.GLM<-data.frame(matrix(0,rep,6))
rep.FDR.GLM<-data.frame(matrix(0,rep,6))
rep.Power.Alpha.GLM<-data.frame(matrix(0,12,6))

rep.power.MLM<-data.frame(matrix(0,100,6))
rep.FDR.MLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.MLM<-data.frame(matrix(0,12,6))

rep.power.SUPER<-data.frame(matrix(0,100,6))
rep.FDR.SUPER<-data.frame(matrix(0,100,6))
rep.Power.Alpha.SUPER<-data.frame(matrix(0,12,6))

rep.power.CMLM<-data.frame(matrix(0,100,6))
rep.FDR.CMLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.CMLM<-data.frame(matrix(0,12,6))

rep.power.ECMLM<-data.frame(matrix(0,100,6))
rep.FDR.ECMLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.ECMLM<-data.frame(matrix(0,12,6))
##PCA
##---------------------##

PCA<-prcomp(X)
PCVar<-PCA$sdev^2
myPC<-PCA$x[,1:3]
m1<-as.data.frame(myPC)

myCV<-cbind(taxa,m1)
myCV<-as.data.frame(myCV)

##-----end step 2  for tfam---###
kcv1<-matrix(1,nrow(myCV),1)
kcv<-cbind(data.frame(kcv1),myCV)
write.table(kcv,"pca.txt",row.names = FALSE,col.names = FALSE,sep="\t",quote=FALSE)

for(i in 1:rep)
{
addm<-matrix(rnorm(NQTN,0,1),NQTN,1)
QTN.position<-sample(1:m,NQTN,replace=FALSE)

SNPQ<-as.matrix(X[,QTN.position])
ge<-SNPQ%*%addm

vg<-var(ge)
ve<-vg*(1-h2)/h2
SDE<-sqrt(ve)
res<-rnorm(n,0,SDE)

y=as.data.frame(ge+res)
myY<-cbind(taxa,y)
myY<-as.data.frame(myY)

max.groups=nrow(myY)
print(paste("*****************","GWAS by GAPIT...GLM model",i," totle:",rep,sep=""))
#--------------------------
myGAPIT_GLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
PCA.total=3,
file.output=FALSE,
model="GLM",
memo="GLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("*****************","GWAS by GAPIT...MLM model",i," totle:",rep,sep=""))
#--------------------------------#
myGAPIT_MLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,
file.output=FALSE,
model="MLM",
memo="MLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("*****************","GWAS by GAPIT...SUPER model",i," totle:",rep,sep=""))
##--------------------------------#
myGAPIT_SUPER <- GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,
#PCA.total=3,
model="SUPER",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
file.output=FALSE,
)

print(paste("$$$$$$$$$$$$$$$","GWAS by GAPIT...CMLM model",i," totle:",rep,sep=""))
#--------------------------------#
myGAPIT_CMLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,
file.output=FALSE,
model="CMLM",
memo="CMLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("-------------------","GWAS by GAPIT...ECMLM model",i," totle:",rep,sep=""))
#--------------------------------#
myGAPIT_ECMLM=GAPIT(
Y=myY,
G=myG,
#GD=myGD,
#GM=myGM,
#KI=myKI,
#CV=myCV,

PCA.total=3,
kinship.cluster=c("average", "complete", "ward"),
kinship.group=c("Mean", "Max"),
file.output=FALSE,
model="ECMLM",
memo="ECMLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 
power_ecmlm<-GAPIT.Power(WS=c(1e0,1e3,1e4,1e5,1e6,1e7), alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1), maxOut=100,seqQTN=QTN.position,GM=myGM,GWAS=myGAPIT_ECMLM$GWAS)

#power #FDR #Power.Alpha
rep.power.GLM<-rep.power.GLM+myGAPIT_GLM$Power
rep.FDR.GLM<-rep.FDR.GLM+myGAPIT_GLM$FDR
rep.Power.Alpha.GLM<-rep.Power.Alpha.GLM+myGAPIT_GLM$Power.Alpha

rep.power.MLM<-rep.power.MLM+myGAPIT_MLM$Power
rep.FDR.MLM<-rep.FDR.MLM+myGAPIT_MLM$FDR
rep.Power.Alpha.MLM<-rep.Power.Alpha.MLM+myGAPIT_MLM$Power.Alpha

rep.power.SUPER<-rep.power.SUPER+myGAPIT_SUPER$Power
rep.FDR.SUPER<-rep.FDR.SUPER+myGAPIT_SUPER$FDR
rep.Power.Alpha.SUPER<-rep.Power.Alpha.SUPER+myGAPIT_SUPER$Power.Alpha
rep.power.CMLM<-rep.power.CMLM+myGAPIT_CMLM$Power
rep.FDR.CMLM<-rep.FDR.CMLM+myGAPIT_CMLM$FDR
rep.Power.Alpha.CMLM<-rep.Power.Alpha.CMLM+myGAPIT_CMLM$Power.Alpha

rep.power.ECMLM<-rep.power.ECMLM+power_ecmlm$Power
rep.FDR.ECMLM<-rep.FDR.ECMLM+power_ecmlm$FDR
rep.Power.Alpha.ECMLM<-rep.Power.Alpha.ECMLM+power_ecmlm$Power.Alpha
gc()
}
#mean
rep.power.GLM<-rep.power.GLM/rep
rep.FDR.GLM<-rep.FDR.GLM/rep
rep.Power.Alpha.GLM<-rep.Power.Alpha.GLM/rep

rep.power.MLM<-rep.power.MLM/rep
rep.FDR.MLM<-rep.FDR.MLM/rep
rep.Power.Alpha.MLM<-rep.Power.Alpha.MLM/rep

rep.power.SUPER<-rep.power.SUPER/rep
rep.FDR.SUPER<-rep.FDR.SUPER/rep
rep.Power.Alpha.SUPER<-rep.Power.Alpha.SUPER/rep

rep.power.CMLM<-rep.power.CMLM/rep
rep.FDR.CMLM<-rep.FDR.CMLM/rep
rep.Power.Alpha.CMLM<-rep.Power.Alpha.CMLM/rep

rep.power.ECMLM<-rep.power.ECMLM/rep
rep.FDR.ECMLM<-rep.FDR.ECMLM/rep
rep.Power.Alpha.ECMLM<-rep.Power.Alpha.ECMLM/rep

#ouput files power FDR for GLM,MLM,SUPER

myWS=c(1e0,1e3,1e4,1e5,1e6,1e7)
myalpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1)

colnames(rep.FDR.GLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.GLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.GLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.MLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.MLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.MLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.SUPER)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.SUPER)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.SUPER)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.CMLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.CMLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.CMLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.ECMLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.ECMLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.ECMLM)=paste("Power(",myWS,")",sep="")

write.csv(cbind(rep.FDR.GLM,rep.power.GLM),paste(h2,"_",NQTN,".Power.by.FDR.GLM",rep,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.GLM),paste(h2,"_",NQTN,".Power.by.TypeI.GLM",".csv",sep=""))

write.csv(cbind(rep.FDR.MLM,rep.power.MLM),paste(h2,"_",NQTN,".Power.by.FDR.MLM",rep,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.MLM),paste(h2,"_",NQTN,".Power.by.TypeI.MLM",".csv",sep=""))

write.csv(cbind(rep.FDR.SUPER,rep.power.SUPER),paste(h2,"_",NQTN,".Power.by.FDR.SUPER",rep,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.SUPER),paste(h2,"_",NQTN,".Power.by.TypeI.SUPER",".csv",sep=""))

write.csv(cbind(rep.FDR.CMLM,rep.power.CMLM),paste(h2,"_",NQTN,".Power.by.FDR.CMLM",rep,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.CMLM),paste(h2,"_",NQTN,".Power.by.TypeI.CMLM",".csv",sep=""))

write.csv(cbind(rep.FDR.ECMLM,rep.power.ECMLM),paste(h2,"_",NQTN,".Power.by.FDR.ECMLM",rep,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.ECMLM),paste(h2,"_",NQTN,".Power.by.TypeI.ECMLM",".csv",sep=""))

write.csv(cbind(rep.FDR.GLM[,6],rep.power.GLM[,6],rep.FDR.MLM[,6],rep.power.MLM[,6],rep.FDR.CMLM[,6],rep.power.CMLM[,6],rep.FDR.ECMLM[,6],rep.power.ECMLM[,6],rep.FDR.SUPER[,6],rep.power.SUPER[,6]),paste(h2,"_",NQTN,".Power.by.FDR.GLM.MLM.SUPER",rep,".csv",sep=""))
	name.of.trait=noquote(names(myY)[2])


pdf(paste("GAPIT.Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER.", ".pdf", sep = ""), width = 4.5, height = 4.5,pointsize=9)
par(mar = c(5,6,5,3))
	#win.graph(width=6, height=4, pointsize=9)
	#palette(c("blue","red","green4","brown4","orange",rainbow(5)))
	palette(c("green4","red","blue","brown4","orange",rainbow(5)))
	plot(rep.FDR.SUPER[,6],rep.power.SUPER[,6],bg="lightgray",xlab="FDR",ylab="Power",ylim=c(0,1),xlim=c(0,1),main="Power against FDR",type="o",pch=20,col=1,cex=1.0,cex.lab=1.3, cex.axis=1, lwd=2,las=1)
        lines(rep.power.ECMLM[,6]~rep.FDR.ECMLM[,6], lwd=2,type="o",pch=20,col=2)
	lines(rep.power.CMLM[,6]~rep.FDR.CMLM[,6], lwd=2,type="o",pch=20,col=3)
	lines(rep.power.MLM[,6]~rep.FDR.MLM[,6], lwd=2,type="o",pch=20,col=4)
	lines(rep.power.GLM[,6]~rep.FDR.GLM[,6], lwd=2,type="o",pch=20,col=5)
	legend("bottomright",c("SUPER","ECMLM","CMLM","MLM","GLM"), pch = 20, lty =1,col=c(1:5),lwd=2,cex=1.0,bty="n")
	#

dev.off()

###add type I error and power###

kkt<-cbind(rep.Power.Alpha.SUPER[,1],rep.Power.Alpha.ECMLM[,1],rep.Power.Alpha.CMLM[,1],rep.Power.Alpha.MLM[,1],rep.Power.Alpha.GLM[,1])
write.csv(cbind(myalpha,rep.Power.Alpha.SUPER[,1],rep.Power.Alpha.ECMLM[,1],rep.Power.Alpha.CMLM[,1],rep.Power.Alpha.MLM[,1],rep.Power.Alpha.GLM[,1]),paste(h2,"_",NQTN,".Type I error.Power.by.FDR.GLM.MLM.SUPER",rep,".csv",sep=""))

myalpha1<-myalpha/10

pdf(paste("GAPIT.Type I error_Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER.", ".pdf", sep = ""), width = 6, height = 4.5,pointsize=9)
par(mar = c(5,6,5,3))
	#win.graph(width=6, height=4, pointsize=9)
	#palette(c("blue","red","green4","brown4","orange",rainbow(5)))
	palette(c("green4","red","blue","brown4","orange",rainbow(5)))
	plot(myalpha1,rep.Power.Alpha.SUPER[,1],log="x",bg="lightgray",xlab="Type I error",ylab="Power",main="Power against FDR",type="o",pch=20,col=1,cex=1.0,cex.lab=1.3, cex.axis=1, lwd=2,las=1,ylim=c(min(kkt),max(kkt)))
	#plot(myalpha1,rep.Power.Alpha.SUPER[,1],bg="lightgray",xlab="Type I error",ylab="Power",ylim=c(0,1),xlim=c(0,1),main="Power against FDR",type="o",pch=20,col=1,cex=1.0,cex.lab=1.3, cex.axis=1, lwd=2,las=1)
        lines(rep.Power.Alpha.ECMLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=2)
	lines(rep.Power.Alpha.CMLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=3)
	lines(rep.Power.Alpha.MLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=4)
	lines(rep.Power.Alpha.GLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=5)
	legend("bottomright",c("SUPER","ECMLM","CMLM","MLM","GLM"), pch = 20, lty =1,col=c(1:5),lwd=2,cex=1.0,bty="n")
	#

dev.off()


print(paste("GAPIT.Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER.","successfully!" ,sep = ""))
#return(list(inf_Y_all,ref_Y_all))
}#end compare to GLM,MLM,CMLM,ECMLM,SUPER
#=============================================================================================

`GAPIT.Power.compare.plink` <-function(myG=null,myGD=NULL,myGM=NULL,myKI=NULL,myY=NULL,myCV=NULL,rel=NULL,h2=NULL,NQTN=NULL){
# Object: compare to Power against FDR for GLM,MLM,CMLM,ECMLM,SUPER,PLINK
# rel:repetition times
# Authors: You Tang 
# Last update: January 23, 2015
############################################################################################## 

if(is.null(myG)||is.null(myGD)||is.null(myGM)||is.null(myKI)){stop("Read data Invalid. Please select read valid flies !")}
if(is.null(rel))
	rel=100
if(is.null(h2))
	h2=0.85
if(is.null(NQTN))
	NQTN=5
X<-myGD[,-1]
taxa<-myGD[,1]
taxa<-as.character(taxa)

##simulation phyenotype
##-------------------------##
n=nrow(X)
m=ncol(X)

####handle plink tped output work direct####
G<-myG[-1,]
GD<-t(X)
v3<-matrix(0,nrow(G),1)
kk<-cbind(data.frame(G[,3]),data.frame(G[,1]),data.frame(v3),data.frame(G[,4]),GD)
b1<-nrow(kk)
b2<-ncol(kk)
for(i in 1:b1){
	for(j in 5:b2){
##imput number 1
	if(kk[i,j]==0)
		kk[i,j]=1
	}
}
kk4<-cbind(kk[,5],kk[,5])
for(j in 6:b2){
	kk4<-cbind(data.frame(kk4),data.frame(kk[,j]),data.frame(kk[,j]))
}
kk6<-cbind(kk[,1:4],kk4)
##output plink deal with tped
write.table(data.frame(kk6),"mdp_numeric.tped",row.names = FALSE,col.names = FALSE,sep="\t",quote=FALSE)

################----------end tped for pinlk-------------##########

rep.power.GLM<-data.frame(matrix(0,100,6))
rep.FDR.GLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.GLM<-data.frame(matrix(0,12,6))

rep.power.MLM<-data.frame(matrix(0,100,6))
rep.FDR.MLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.MLM<-data.frame(matrix(0,12,6))


rep.power.SUPER<-data.frame(matrix(0,100,6))
rep.FDR.SUPER<-data.frame(matrix(0,100,6))
rep.Power.Alpha.SUPER<-data.frame(matrix(0,12,6))

rep.power.CMLM<-data.frame(matrix(0,100,6))
rep.FDR.CMLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.CMLM<-data.frame(matrix(0,12,6))

rep.power.ECMLM<-data.frame(matrix(0,100,6))
rep.FDR.ECMLM<-data.frame(matrix(0,100,6))
rep.Power.Alpha.ECMLM<-data.frame(matrix(0,12,6))

#####------handle tfam for plink----###
rep.power.plink<-data.frame(matrix(0,100,6))
rep.FDR.plink<-data.frame(matrix(0,100,6))
rep.Power.Alpha.plink<-data.frame(matrix(0,12,6))

k1<-matrix(1,n,1)
k2<-matrix(-9,n,2)
##------step 1 end-----------##
WS=c(1e0,1e3,1e4,1e5,1e6,1e7)
alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1)
maxOut=100

##PCA
##---------------------##

PCA<-prcomp(X)
PCVar<-PCA$sdev^2
myPC<-PCA$x[,1:3]
m1<-as.data.frame(myPC)

myCV<-cbind(taxa,m1)
myCV<-as.data.frame(myCV)

##-----end step 2  for tfam---###
kcv1<-matrix(1,nrow(myCV),1)
kcv<-cbind(data.frame(kcv1),myCV)
write.table(kcv,"pca.txt",row.names = FALSE,col.names = FALSE,sep="\t",quote=FALSE)

for(i in 1:rel)
{
addm<-matrix(rnorm(NQTN,0,1),NQTN,1)
QTN.position<-sample(1:m,NQTN,replace=FALSE)

SNPQ<-as.matrix(X[,QTN.position])
ge<-SNPQ%*%addm

vg<-var(ge)
ve<-vg*(1-h2)/h2
SDE<-sqrt(ve)
res<-rnorm(n,0,SDE)

y=as.data.frame(ge+res)
myY<-cbind(taxa,y)
myY<-as.data.frame(myY)

##-----output tfam for plink----##
k3<-cbind(data.frame(k1),data.frame(taxa),data.frame(k2),data.frame(k1),data.frame(myY[,2]))
write.table(k3,paste("mdp_numeric",i,".tfam",sep=""),row.names = FALSE,col.names = FALSE,sep="\t",quote=FALSE)
 
##-----end step 2  for tfam---###

max.groups=nrow(y)
print(paste("*****************","GWAS by GAPIT...GLM model",i," totle:",rel,sep=""))
#--------------------------
myGAPIT_GLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
PCA.total=3,
file.output=FALSE,
group.from=0,
group.to=0,
group.by=0,
memo="GLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("*****************","GWAS by GAPIT...MLM model",i," totle:",rel,sep=""))
#--------------------------------#
myGAPIT_MLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,

file.output=FALSE,
group.from=max.groups,
group.to=max.groups,
group.by=10,
memo="MLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("*****************","GWAS by GAPIT...SUPER model",i," totle:",rel,sep=""))
##--------------------------------#
myGAPIT_SUPER <- GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,
#PCA.total=3,
sangwich.top="MLM", #options are GLM,MLM,CMLM, FaST and SUPER
sangwich.bottom="SUPER", #options are GLM,MLM,CMLM, FaST and SUPER
LD=0.1,
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
file.output=FALSE,
)

print(paste("$$$$$$$$$$$$$$$","GWAS by GAPIT...CMLM model",i," totle:",rel,sep=""))
#--------------------------------#
myGAPIT_CMLM=GAPIT(
Y=myY,
GD=myGD,
GM=myGM,
KI=myKI,
CV=myCV,

file.output=FALSE,
group.from=0,
group.to=max.groups,
group.by=10,
memo="CMLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

print(paste("-------------------","GWAS by GAPIT...ECMLM model",i," totle:",rel,sep=""))
#--------------------------------#
myGAPIT_ECMLM=GAPIT(
Y=myY,
G=myG,
#GD=myGD,
#GM=myGM,
#KI=myKI,
#CV=myCV,

PCA.total=3,
kinship.cluster=c("average", "complete", "ward"),
kinship.group=c("Mean", "Max"),
file.output=FALSE,
group.from=0,
group.to=max.groups,
group.by=10,
memo="ECMLM",
QTN.position=QTN.position,
threshold.output=0.001,
iteration.output=TRUE,
) 

##ecmlm power
power_ecmlm<-GAPIT.Power(WS=WS, alpha=alpha, maxOut=maxOut,seqQTN=QTN.position,GM=myGM,GWAS=myGAPIT_ECMLM$GWAS)

##-------------GAWS for plink-----##
##---output gwas.mdp_numericx.qassoc by plink.exe,so must be copy it to work path!----## 
system(paste('"plink.exe"', paste('--tped mdp_numeric.tped --tfam mdp_numeric',i,'.tfam --assoc --out gwas.mdp_numeric',i,sep='')), wait = TRUE)
##-------------GAWS for plink-----##
##---output gwas.mdp_numericx.qassoc by plink.exe,so must be copy it to work path!----## 
system(paste('"plink.exe"', paste('--tped mdp_numeric.tped --tfam mdp_numeric',i,'.tfam --covar pca.txt --linear --hide-covar  --out gwas.mdp_numeric',i,sep='')), wait = TRUE)

plinkGWAS<-read.table(paste("gwas.mdp_numeric",i,".assoc.linear",sep=""),header=T)

Format_GWAS=cbind(myGM,plinkGWAS[,9],rep(NA,nrow(myGM)),rep(NA,nrow(myGM)),rep(NA,nrow(myGM))) 
names(Format_GWAS)<-c("SNP","Chromosome","Position","P.value","maf","nobs","FDR_Adjusted_P-values")
power_plink<-GAPIT.Power(WS=WS, alpha=alpha, maxOut=maxOut,seqQTN=QTN.position,GM=myGM,GWAS=Format_GWAS)
##---end powe_plink-----###
##----end step 3 for plink----###

#power #FDR #Power.Alpha
rep.power.GLM<-rep.power.GLM+myGAPIT_GLM$Power
rep.FDR.GLM<-rep.FDR.GLM+myGAPIT_GLM$FDR
rep.Power.Alpha.GLM<-rep.Power.Alpha.GLM+myGAPIT_GLM$Power.Alpha

rep.power.MLM<-rep.power.MLM+myGAPIT_MLM$Power
rep.FDR.MLM<-rep.FDR.MLM+myGAPIT_MLM$FDR
rep.Power.Alpha.MLM<-rep.Power.Alpha.MLM+myGAPIT_MLM$Power.Alpha

rep.power.SUPER<-rep.power.SUPER+myGAPIT_SUPER$Power
rep.FDR.SUPER<-rep.FDR.SUPER+myGAPIT_SUPER$FDR
rep.Power.Alpha.SUPER<-rep.Power.Alpha.SUPER+myGAPIT_SUPER$Power.Alpha


rep.power.CMLM<-rep.power.CMLM+myGAPIT_CMLM$Power
rep.FDR.CMLM<-rep.FDR.CMLM+myGAPIT_CMLM$FDR
rep.Power.Alpha.CMLM<-rep.Power.Alpha.CMLM+myGAPIT_CMLM$Power.Alpha

rep.power.ECMLM<-rep.power.ECMLM+power_ecmlm$Power
rep.FDR.ECMLM<-rep.FDR.ECMLM+power_ecmlm$FDR
rep.Power.Alpha.ECMLM<-rep.Power.Alpha.ECMLM+power_ecmlm$Power.Alpha

##----power-fdr save for mean of plink---##
rep.power.plink<-rep.power.plink+power_plink$Power
rep.FDR.plink<-rep.FDR.plink+power_plink$FDR
rep.Power.Alpha.plink<-rep.Power.Alpha.plink+power_plink$Power.Alpha
##---end sum for power of plink ----##

gc()
}
#mean
rep.power.GLM<-rep.power.GLM/rel
rep.FDR.GLM<-rep.FDR.GLM/rel
rep.Power.Alpha.GLM<-rep.Power.Alpha.GLM/rel

rep.power.MLM<-rep.power.MLM/rel
rep.FDR.MLM<-rep.FDR.MLM/rel
rep.Power.Alpha.MLM<-rep.Power.Alpha.MLM/rel


rep.power.SUPER<-rep.power.SUPER/rel
rep.FDR.SUPER<-rep.FDR.SUPER/rel
rep.Power.Alpha.SUPER<-rep.Power.Alpha.SUPER/rel

rep.power.CMLM<-rep.power.CMLM/rel
rep.FDR.CMLM<-rep.FDR.CMLM/rel
rep.Power.Alpha.CMLM<-rep.Power.Alpha.CMLM/rel

rep.power.ECMLM<-rep.power.ECMLM/rel
rep.FDR.ECMLM<-rep.FDR.ECMLM/rel
rep.Power.Alpha.ECMLM<-rep.Power.Alpha.ECMLM/rel

rep.power.plink<-rep.power.plink/rel
rep.FDR.plink<-rep.FDR.plink/rel
rep.Power.Alpha.plink<-rep.Power.Alpha.plink/rel

#ouput files power FDR for GLM,MLM,SUPER

myWS=c(1e0,1e3,1e4,1e5,1e6,1e7)
myalpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1)

colnames(rep.FDR.GLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.GLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.GLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.MLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.MLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.MLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.SUPER)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.SUPER)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.SUPER)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.CMLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.CMLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.CMLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.ECMLM)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.ECMLM)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.ECMLM)=paste("Power(",myWS,")",sep="")

colnames(rep.FDR.plink)=  paste("FDR(",myWS,")",sep="")
colnames(rep.power.plink)=paste("Power(",myWS,")",sep="")
colnames(rep.Power.Alpha.plink)=paste("Power(",myWS,")",sep="")

write.csv(cbind(rep.FDR.GLM,rep.power.GLM),paste(h2,"_",NQTN,".Power.by.FDR.GLM",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.GLM),paste(h2,"_",NQTN,".Power.by.TypeI.GLM",".csv",sep=""))

write.csv(cbind(rep.FDR.MLM,rep.power.MLM),paste(h2,"_",NQTN,".Power.by.FDR.MLM",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.MLM),paste(h2,"_",NQTN,".Power.by.TypeI.MLM",".csv",sep=""))

write.csv(cbind(rep.FDR.SUPER,rep.power.SUPER),paste(h2,"_",NQTN,".Power.by.FDR.SUPER",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.SUPER),paste(h2,"_",NQTN,".Power.by.TypeI.SUPER",".csv",sep=""))

write.csv(cbind(rep.FDR.CMLM,rep.power.CMLM),paste(h2,"_",NQTN,".Power.by.FDR.CMLM",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.CMLM),paste(h2,"_",NQTN,".Power.by.TypeI.CMLM",".csv",sep=""))

write.csv(cbind(rep.FDR.ECMLM,rep.power.ECMLM),paste(h2,"_",NQTN,".Power.by.FDR.ECMLM",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.ECMLM),paste(h2,"_",NQTN,".Power.by.TypeI.ECMLM",".csv",sep=""))

write.csv(cbind(rep.FDR.plink,rep.power.plink),paste(h2,"_",NQTN,".Power.by.FDR.plink",rel,".csv",sep=""))
write.csv(cbind(myalpha,rep.Power.Alpha.plink),paste(h2,"_",NQTN,".Power.by.TypeI.plink",".csv",sep=""))

write.csv(cbind(rep.FDR.GLM[,6],rep.power.GLM[,6],rep.FDR.MLM[,6],rep.power.MLM[,6],rep.FDR.CMLM[,6],rep.power.CMLM[,6],rep.FDR.ECMLM[,6],rep.power.ECMLM[,6],rep.FDR.SUPER[,6],rep.power.SUPER[,6],rep.FDR.plink[,6],rep.power.plink[,6]),paste(h2,"_",NQTN,".Power.by.FDR.GLM.MLM.SUPER.plink",rel,".csv",sep=""))
	name.of.trait=noquote(names(myY)[2])

pdf(paste("GAPIT.Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER.plink", ".pdf", sep = ""), width = 4.5, height = 4,pointsize=9)
par(mar = c(5,6,5,3))
	#win.graph(width=6, height=4, pointsize=9)
	palette(c("green4","red","blue","brown4","orange","black",rainbow(6)))
	plot(rep.FDR.SUPER[,6],rep.power.SUPER[,6],bg="lightgray",xlab="FDR",ylab="Power",ylim=c(0,1),xlim=c(0,1),main="Power against FDR",type="o",pch=20,col=1,cex=1.0,cex.lab=1.3, cex.axis=1, lwd=2,las=1)
        lines(rep.power.ECMLM[,6]~rep.FDR.ECMLM[,6], lwd=2,type="o",pch=20,col=2)
	lines(rep.power.CMLM[,6]~rep.FDR.CMLM[,6], lwd=2,type="o",pch=20,col=3)
	lines(rep.power.MLM[,6]~rep.FDR.MLM[,6], lwd=2,type="o",pch=20,col=4)
	lines(rep.power.GLM[,6]~rep.FDR.GLM[,6], lwd=2,type="o",pch=20,col=5)
	lines(rep.power.plink[,6]~rep.FDR.plink[,6], lwd=2,type="o",pch=20,col=6,lty =1)
	legend("bottomright",c("SUPER","ECMLM","CMLM","MLM","GLM","PLINK"), pch =c(20,20,20,20,20,20), lty =c(1,1,1,1,1,2),col=c(1:6),lwd=2,cex=1.0,bty="n")
	#

dev.off()


###add type I error and power###

kkt<-cbind(rep.Power.Alpha.SUPER[,1],rep.Power.Alpha.ECMLM[,1],rep.Power.Alpha.CMLM[,1],rep.Power.Alpha.MLM[,1],rep.Power.Alpha.GLM[,1],rep.Power.Alpha.plink[,1])
write.csv(cbind(myalpha,rep.Power.Alpha.SUPER[,1],rep.Power.Alpha.ECMLM[,1],rep.Power.Alpha.CMLM[,1],rep.Power.Alpha.MLM[,1],rep.Power.Alpha.GLM[,1],rep.Power.Alpha.plink[,1]),paste(h2,"_",NQTN,".Type I error.Power.by.FDR.GLM.MLM.SUPER",rel,".csv",sep=""))

myalpha1<-myalpha/10

pdf(paste("GAPIT.Type I error_Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER,plink", ".pdf", sep = ""), width = 6, height = 4.5,pointsize=9)
par(mar = c(5,6,5,3))
	
	palette(c("green4","red","blue","brown4","orange","black",rainbow(6)))
	plot(myalpha1,rep.Power.Alpha.SUPER[,1],log="x",bg="lightgray",xlab="Type I error",ylab="Power",main="Power against FDR",type="o",pch=20,col=1,cex=1.0,cex.lab=1.3, cex.axis=1, lwd=2,las=1,ylim=c(min(kkt),max(kkt)))
        lines(rep.Power.Alpha.ECMLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=2)
	lines(rep.Power.Alpha.CMLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=3)
	lines(rep.Power.Alpha.MLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=4)
	lines(rep.Power.Alpha.GLM[,1]~myalpha1, lwd=2,type="o",pch=20,col=5)
	lines(rep.Power.Alpha.plink[,1]~myalpha1, lwd=2,type="o",pch=20,col=6,lty =1)
	legend("bottomright",c("SUPER","ECMLM","CMLM","MLM","GLM","PLINK"), pch =c(20,20,20,20,20,20), lty =c(1,1,1,1,1,2),col=c(1:6),lwd=2,cex=1.0,bty="n")

dev.off()

print(paste("GAPIT.Power ", name.of.trait,".compare to GLM,MLM,CMLM,ECMLM,SUPER,PLINK.","successfully!" ,sep = ""))
#return(list(inf_Y_all,ref_Y_all))
}#end compare to GLM,MLM,SUPER
#=============================================================================================

`GAPIT.Prediction` <-function(myK=NULL,y=NULL, num=NULL){
# Object: Genetic Prediction one time by cross validation and cMLM,result:a pdf of the scree plot
# myK:Kinship
# Y: phenotype with columns of taxa,Y1,Y2...
# num:folders number
# Authors: Jiabo Wang and You Tang
# Last update: December 31, 2014 
############################################################################################## 
if(is.null(myK)||is.null(y)){stop("Validation Invalid. Please select read valid flies !")}
if(is.null(num))
  {
	num=5  #not input num value,default folders number is 5
  }

y=y[,1:2]
m=nrow(y)
m.sample=round(m/num)


if(num<2||num>m){stop("Validation Invalid. Please select folders num >1 !")}

vali<-matrix(nr=m.sample,nc=num-1)
cali<-matrix(nr=m-m.sample,nc=num-1)

#vali<-list(v1=unique(as.character(sample(y$Taxa, m.sample))))
#cali<-list(c1=y[!(y$Taxa %in% as.matrix(as.data.frame(vali[1]))), 'Taxa'])

vali[,1]<-unique(as.character(sample(y$Taxa, m.sample)))
cali[,1]<-unique(as.character(y[!(y$Taxa %in% vali[,1]), 'Taxa']))

for(j in 2:num)
{
	if(j!=num)
	{
	 vali[,j]<-unique(as.character(sample(y[!(y$Taxa %in% vali[,1:j-1]), 'Taxa'], m.sample) ))
	}
	if(j==num)
	{
		valilast=unique(as.character(y[!(y$Taxa %in% vali[,1:j-1]), 'Taxa']))
	}

	if(j!=num)
		cali[,j]<-unique(as.character(y[!(y$Taxa %in% vali[,j]), 'Taxa']))
	if(j==num)
		calilast <<- y[!(y$Taxa %in% valilast), 'Taxa']
}

	i=sample(1:num, size = 1)

	if(i!=num){
		lines.vali<-vali[,i]
	  }else{
	 	lines.vali<-valilast
	 }
	 #use only genotypes that were genotyped and phenotyped
	 commonGeno_v <- lines.vali[lines.vali %in% myK[,1]]	               
	 yvali<- y[match(commonGeno_v,y$Taxa),]
    
	 if(i!=num){
		lines.cali<-cali[,i]
	 }else{
		lines.cali<-calilast
	  }
	 #use only genotypes that were genotyped and phenotyped
	 commonGeno_c <- lines.cali[lines.cali %in% myK[,1]]
	 ycali<- y[match(commonGeno_c,y$Taxa),]                
	
	Y.raw=ycali[,c(1,2)]#choos a trait

	myY=Y.raw
	myKI=myK
	max.groups=m
#Run GAPIT
#############################################
	
	blupGAPIT <- GAPIT(
	Y=myY,
	KI=myKI,
	#group.from=max.groups,
	group.from=1,
	group.to=max.groups,
	#group.by=10,
	#PCA.total=3,
	SNP.test=FALSE,
	file.output=FALSE
	)

	blup_prediction=blupGAPIT$GPS
 
	blue<-blupGAPIT$Pred$BLUE
	mean_blue<-mean(blue)

	blup_prediction.ref<-blup_prediction[match(commonGeno_c,blup_prediction$Taxa),]
	blup_prediction.inf<-blup_prediction[match(commonGeno_v,blup_prediction$Taxa),]
	inf_BLUP<-blup_prediction.inf$BLUP
	ref_BLUP<-blup_prediction.ref$BLUP

	inf_pred<-inf_BLUP+mean_blue
	ref_pred<-ref_BLUP+mean_blue


	inf_all<-cbind(blup_prediction.inf,inf_pred)
	ref_all<-cbind(blup_prediction.ref,ref_pred)

	inf_Y_all<-merge(y,inf_all,by.x="Taxa",by.y="Taxa")
	ref_Y_all<-merge(y,ref_all,by.x="Taxa",by.y="Taxa")

	name.of.trait=noquote(names(Y.raw)[2])


pdf(paste("GAPIT.Prediction ", name.of.trait,".Predict reference.pdf", sep = ""), width =6, height = 6)
par(mar = c(5,5,5,5))
plot(ref_Y_all[,2],ref_Y_all[,8],pch=1,xlab="Observed(Ref)",ylab="Predicted(Ref)",cex.lab=1.3,cex.axis=1.2,lwd=2)   #xlim=c(50,110),ylim=c(50,110),
kr<-lm(ref_Y_all[,8]~ref_Y_all[,2])
abline(a = kr$coefficients[1], b = kr$coefficients[2], col = "red",lwd=4,lty=1)
#v1<-max(ref_Y_all[,2]])*10/10
#text(v1,kr$coefficients[1]+kr$coefficients[2]*v1,paste("R^2=",format(kr$coefficients[2], digits = 3),seq=""), col = "blue", adj = c(0, -.1))
legend("bottomright",paste("R^2=",format(kr$coefficients[2], digits = 4),seq=""), col="white",text.col="blue",lwd=2,cex=1.2,bty="n")

dev.off()
pdf(paste("GAPIT.Prediction ", name.of.trait,".Predict inference.pdf", sep = ""), width = 6, height = 6)
par(mar = c(5,5,5,5))
plot(inf_Y_all[,2],inf_Y_all[,8],pch=1,xlab="Observed(Inf)",ylab="Predicted(Inf)",cex.lab=1.5,lwd=2,,cex.axis=1.2)#xlim=c(50,110),ylim=c(45,100),
ki<-lm(inf_Y_all[,8]~inf_Y_all[,2])
abline(a = ki$coefficients[1], b = ki$coefficients[2], col = "red",lwd=3,lty=1)
#v0<-max(inf_Y_all[,2])
#text(v0,ki$coefficients[1]+ki$coefficients[2]*v0,paste("R^2=",format(ki$coefficients[2], digits = 4),seq=""), col = "blue", adj = c(0, -.1))

legend("bottomright",paste("R^2=",format(ki$coefficients[2], digits = 4),seq=""), col="white",text.col="blue",lwd=2,cex=1.2,bty="n")

dev.off()
print(paste("GAPIT.Prediction ", name.of.trait,".Predict phenotype.","successfully!" ,sep = ""))
return(list(inf_Y_all,ref_Y_all))
}
#end Prediction one time
#=============================================================================================

`GAPIT.Pruning` <-
function(values,DPP=5000){
#Object: To get index of subset that evenly distribute
#Output: Index
#Authors: Zhiwu Zhang
# Last update: May 28, 2011 
##############################################################################################
#No change if below the requirement
if(length(values)<=DPP)return(c(1:length(values)))
  
#values= log.P.values
values=sqrt(values)  #This shift the weight a little bit to the low building.

#Handler of bias plot
rv=runif(length(values))
values=values+rv
values=values[order(values,decreasing = T)]

theMin=min(values)
theMax=max(values)
range=theMax-theMin
interval=range/DPP

ladder=round(values/interval)
ladder2=c(ladder[-1],0)
keep=ladder-ladder2
index=which(keep>0)


return(index)
}#end of GAPIT.Pruning 
#=============================================================================================
`GAPIT.QC` <-
function(Y=NULL,KI=NULL,GT=NULL,CV=NULL,Z=NULL,GK=NULL){
#Object: to do data quality control
#Output: Y, KI, GD, CV, Z, flag
#Authors: Zhiwu Zhang and Alex Lipka 
# Last update: April 14, 2011 
##############################################################################################
#Remove duplicates 
print("Removing duplicates...")
#print(dim(CV))
Y=GAPIT.RemoveDuplicate(Y)
CV=GAPIT.RemoveDuplicate(CV)
GK=GAPIT.RemoveDuplicate(GK)
if(!is.null(Z))Z=GAPIT.RemoveDuplicate(Z)

#Remove missing phenotype
print("Removing NaN...")
Y=Y[which(Y[,2]!="NaN"),]

# Remove duplicates for GT 
# GT row wise, Z column wise, and KI both direction.
print("Remove duplicates for GT...")
#print(dim(GT))
if(!is.null(GT))
{ 
  if(is.null(dim(GT)))taxa.kept=unique(GT)
  if(!is.null(dim(GT)))taxa.kept=unique(GT[,1])

}else{
  taxa.kept=unique(Y[,1])
}

# Remove duplicates for KI 
print("Remove duplicates for KI...")
# improve speed: remove t() and use cbind
if(!is.null(KI))
{
  taxa.all=KI[,1]
  taxa.uniqe=unique(taxa.all)
  position=match(taxa.uniqe, taxa.all,nomatch = 0)
  position.addition=cbind(1,t(1+position))
  KI=KI[position,position.addition]
}

#Sort KI
if(!is.null(KI))
{
  taxa.all=KI[,1]
  position=order(taxa.all)
  position.addition=cbind(1,t(1+position))
  KI=KI[position,position.addition]
}

# Remove duplicates for Z rowwise
print("Remove duplicates for Z (column wise)...")
if(!is.null(Z))
{
  taxa.all=as.matrix(Z[1,])
  taxa.uniqe=intersect(taxa.all,taxa.all)
  position=match(taxa.uniqe, taxa.all,nomatch = 0)
  Z=Z[,position]
}


#Remove the columns of Z if they are not in KI/GT. KI/GT are allowed to have individuals not in Z
print("Maching Z with Kinship colwise...")
if(!is.null(KI))
{
  taxa.all=KI[,1]
  taxa.kinship=unique(taxa.all)
}

if(!is.null(Z) & !is.null(KI))
{
  #get common taxe between KI and Z
  taxa.Z=as.matrix(Z[1,])
  #taxa.Z=colnames(Z) #This does not work for names starting with numerical or "-"   \
  if(is.null(KI)){
  taxa.Z_K_common=taxa.Z
  }else{
  taxa.Z_K_common=intersect(taxa.kinship,taxa.Z)
  }
  Z <-cbind(Z[,1], Z[,match(taxa.Z_K_common, taxa.Z, nomatch = 0)])
  
  #Remove the rows of Z if all the ellements sum to 0
  #@@@ improve speed: too many Zs
  print("Maching Z without origin...")
  Z1=Z[-1,-1]
  Z2=data.frame(Z1)
  Z3=as.matrix(Z2)
  Z4=as.numeric(Z3) #one dimemtion
  Z5=matrix(data = Z4, nrow = nrow(Z1), ncol = ncol(Z1))
  RS=rowSums(Z5)>0
  #The above process could be simplified!
  Z <- Z[c(TRUE,RS),]
  
  #make individuals the same in Z, Y, GT and CV
  print("Maching GT and CV...")
  if(length(Z)<=1)stop("GAPIT says: there is no place to match IDs!")
}# end of  if(!is.null(Z) & !is.null(K))

# get intersect of all the data
taxa=intersect(Y[,1],Y[,1])
if(!is.null(Z))taxa=intersect(Z[-1,1],taxa)
if(!is.null(GT))taxa=intersect(taxa,taxa.kept)
if(!is.null(CV))taxa=intersect(taxa,CV[,1])
if(!is.null(GK))taxa=intersect(taxa,GK[,1])
if(length(taxa)<=1)stop("GAPIT says: There is no individual ID matched to covariate. Please check!")


if(!is.null(Z))
{
  #Remove taxa in Z that are not in others, columnwise
  t=c(TRUE, Z[-1,1]%in%taxa)
  if(length(t)<=2)stop("GAPIT says: There is no individual ID matched among data. Please check!")
  Z <- Z[t,]
  
  #Remove the columns of Z if all the ellements sum to 0
  print("QC final process...")
  #@@@ improve speed: too many Zs
  Z1=Z[-1,-1]
  Z2=data.frame(Z1)
  Z3=as.matrix(Z2)
  Z4=as.numeric(Z3) #one dimemtion
  Z5=matrix(data = Z4, nrow = nrow(Z1), ncol = ncol(Z1))
  CS=colSums(Z5)>0
  #The above process could be simplified!
  Z <- Z[,c(TRUE,CS)]
}

#Filtering with comman taxa
Y <- Y[Y[,1]%in%taxa,]
if(!is.null(CV)) CV=CV[CV[,1]%in%taxa,]
if(!is.null(GK)) GK=GK[GK[,1]%in%taxa,]
if(!is.null(GT)) taxa.kept=data.frame(taxa.kept[taxa.kept%in%taxa])
#Y <- Y[Y[,1]%in%taxa.kept,]

#To sort Y, GT, CV and Z
Y=Y[order(Y[,1]),]
CV=CV[order(CV[,1]),]
if(!is.null(GK))GK=GK[order(GK[,1]),]
if(!is.null(Z))Z=Z[c(1,1+order(Z[-1,1])),]

#get position of taxa.kept in GT
#position=match(taxa.kept[,1], GT[,1],nomatch = 0)
if(is.null(dim(GT)))position=match(taxa.kept, GT,nomatch = 0)
if(!is.null(dim(GT)))position=match(taxa.kept[,1], GT[,1],nomatch = 0)


if(is.null(dim(taxa.kept)))order.taxa.kept=order(taxa.kept)
if(!is.null(dim(taxa.kept)))order.taxa.kept=order(taxa.kept[,1])

GTindex=position[order.taxa.kept]
flag=nrow(Y)==nrow(Z)-1&nrow(Y)==nrow(GT)&nrow(Y)==nrow(CV)

print("GAPIT.QC accomplished successfully!")

#print(dim(Y))
#print(dim(CV))
#print(dim(KI))
return(list(Y = Y, KI = KI, GT = GT, CV = CV, Z = Z, GK = GK, GTindex=GTindex, flag=flag))
}#The function GAPIT.QC ends here
#=============================================================================================

`GAPIT.QQ` <-
function(P.values, plot.type = "log_P_values", name.of.trait = "Trait",DPP=50000,plot.style="rainbow"){
    #Object: Make a QQ-Plot of the P-values
    #Options for plot.type = "log_P_values" and "P_values"
    #Output: A pdf of the QQ-plot
    #Authors: Alex Lipka and Zhiwu Zhang
    # Last update: May 9, 2011
    ##############################################################################################
    # Sort the data by the raw P-values
    #print("Sorting p values")
    #print(paste("Number of P values: ",length(P.values)))
    #remove NAs and keep the ones between between 0 and 1
    P.values=P.values[!is.na(P.values)]
    P.values=P.values[P.values>0]
    P.values=P.values[P.values<=1]
    
    if(length(P.values[P.values>0])<1) return(NULL)
    N=length(P.values)
    DPP=round(DPP/4) #Reduce to 1/4 for QQ plot
    P.values <- P.values[order(P.values)]
    
    #Set up the p-value quantiles
    #print("Setting p_value_quantiles...")
    p_value_quantiles <- (1:length(P.values))/(length(P.values)+1)
    
    
    if(plot.type == "log_P_values")
    {
        log.P.values <- -log10(P.values)
        log.Quantiles <- -log10(p_value_quantiles)
        
        index=GAPIT.Pruning(log.P.values,DPP=DPP)
        log.P.values=log.P.values[index ]
        log.Quantiles=log.Quantiles[index]
        
        if(plot.style=="FarmCPU"){
        pdf(paste("FarmCPU.", name.of.trait,".QQ-Plot.pdf" ,sep = ""),width = 5,height=5)
        par(mar = c(5,6,5,3))
        }
        if(plot.style=="rainbow"){
            pdf(paste("GAPIT.", name.of.trait,".QQ-Plot.pdf" ,sep = ""),width = 5,height=5)
            par(mar = c(5,6,5,3))
        }
        #Add conficence interval
        N1=length(log.Quantiles)
        ## create the confidence intervals
        c95 <- rep(NA,N1)
        c05 <- rep(NA,N1)
        for(j in 1:N1){
            i=ceiling((10^-log.Quantiles[j])*N)
            if(i==0)i=1
            c95[j] <- qbeta(0.95,i,N-i+1)
            c05[j] <- qbeta(0.05,i,N-i+1)
            #print(c(j,i,c95[j],c05[j]))
        }
        
        #CI Lines
        #plot(log.Quantiles, -log10(c05), xlim = c(0,max(log.Quantiles)), ylim = c(0,max(log.P.values)), type="l",lty=5, axes=FALSE, xlab="", ylab="",col="black")
        #par(new=T)
        #plot(log.Quantiles, -log10(c95), xlim = c(0,max(log.Quantiles)), ylim = c(0,max(log.P.values)), type="l",lty=5, axes=FALSE, xlab="", ylab="",col="black")
        
        #CI shade
        plot(NULL, xlim = c(0,max(log.Quantiles)), ylim = c(0,max(log.P.values)), type="l",lty=5, lwd = 2, axes=FALSE, xlab="", ylab="",col="gray")
        index=length(c95):1
        polygon(c(log.Quantiles[index],log.Quantiles),c(-log10(c05)[index],-log10(c95)),col='gray',border=NA)
        
        #Diagonal line
        abline(a = 0, b = 1, col = "red",lwd=2)
        
        #data
        par(new=T)
        if(plot.style=="FarmCPU"){
            plot(log.Quantiles, log.P.values, cex.axis=1.1, cex.lab=1.3, lty = 1,  lwd = 2, col = "Black" ,bty='l', xlab =expression(Expected~~-log[10](italic(p))), ylab = expression(Observed~~-log[10](italic(p))), main = paste(name.of.trait,sep=""),pch=20)
        }
        if(plot.style=="rainbow"){
            plot(log.Quantiles, log.P.values, xlim = c(0,max(log.Quantiles)), ylim = c(0,max(log.P.values)), cex.axis=1.1, cex.lab=1.3, lty = 1,  lwd = 2, col = "Blue" ,xlab =expression(Expected~~-log[10](italic(p))),ylab = expression(Observed~~-log[10](italic(p))), main = paste(name.of.trait,sep=""))
        }
        
        dev.off()
    }
    
    
    if(plot.type == "P_values")
    {
        pdf(paste("QQ-Plot_", name.of.trait,".pdf" ,sep = ""))
        par(mar = c(5,5,5,5))
        qqplot(p_value_quantiles, P.values, xlim = c(0,1),
        ylim = c(0,1), type = "l" , xlab = "Uniform[0,1] Theoretical Quantiles", 
        lty = 1, lwd = 1, ylab = "Quantiles of P-values from GWAS", col = "Blue",
        main = paste(name.of.trait,sep=" "))
        abline(a = 0, b = 1, col = "red")
        dev.off()   
    }
    #print("GAPIT.QQ  accomplished successfully!")
}
#=============================================================================================

`GAPIT` <-
function(Y=NULL,G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,CV.Inheritance=NULL,GP=NULL,GK=NULL,
 group.from=1000000 ,group.to=1000000,group.by=20,DPP=100000, 
 kinship.cluster="average", kinship.group='Mean',kinship.algorithm="VanRaden", 
 bin.from=10000,bin.to=10000,bin.by=10000,inclosure.from=10,inclosure.to=10,inclosure.by=10,
 SNP.P3D=TRUE,SNP.effect="Add",SNP.impute="Middle",PCA.total=0, SNP.fraction = 1, seed = NULL, BINS = 20,SNP.test=TRUE,
 SNP.MAF=0,FDR.Rate = 1, SNP.FDR=1,SNP.permutation=FALSE,SNP.CV=NULL,SNP.robust="GLM",
 file.from=1, file.to=1, file.total=NULL, file.fragment = 99999,file.path=NULL, 
 file.G=NULL, file.Ext.G=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL, 
 ngrid = 100, llim = -10, ulim = 10, esp = 1e-10,LD.chromosome=NULL,LD.location=NULL,LD.range=NULL,PCA.col=NULL,PCA.3d=FALSE,NJtree.group=NULL,NJtree.type=c("fan","unrooted"),
 sangwich.top=NULL,sangwich.bottom=NULL,QC=TRUE,GTindex=NULL,LD=0.1,plot.bin=10^5,
 file.output=TRUE,cutOff=0.01, Model.selection = FALSE,output.numerical = FALSE,
 output.hapmap = FALSE, Create.indicator = FALSE,Multi_iter=FALSE,num_regwas=10,opt="extBIC",
  QTN=NULL, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = FALSE,Random.model=FALSE,
  method.GLM="FarmCPU.LM",method.sub="reward",method.sub.final="reward",method.bin="static",bin.size=c(1000000),bin.selection=c(10,20,50,100,200,500,1000),
  memo=NULL,Prior=NULL,ncpus=1,maxLoop=3,threshold.output=.01,Inter.Plot=FALSE,Inter.type=c("m","q"),
  WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),maxOut=100,QTN.position=NULL,CG=NULL,
  converge=1,iteration.output=FALSE,acceleration=0,iteration.method="accum",PCA.View.output=TRUE,Geno.View.output=TRUE,plot.style="Oceanic",SUPER_GD=NULL,SUPER_GS=FALSE,
		    h2=NULL,NQTN=NULL,QTNDist="normal",effectunit=1,category=1,r=0.25,cveff=NULL,a2=0,adim=2,Multiple_analysis=FALSE,
  model="MLM",Para=NULL
		){
#Object: To perform GWAS and GPS (Genomic Prediction/Selection)
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("--------------------- Welcome to GAPIT ----------------------------")
echo=TRUE
GAPIT.Version=GAPIT.0000()

#
if(!is.null(model))if(!match(model,c("MLM","CMLM","SUPER","GLM","FarmCPU","Blink","MLMM","gBLUP","cBLUP","sBLUP"))) stop(paste("PLease choose one model from ","MLM","CMLM","SUPER","GLM","FarmCPU","Blink","gBLUP","cBLUP","sBLUP",sep=""))
#Allow either KI or K, but not both
if(model%in%c("gBLUP","cBLUP","sBLUP"))
  {
    SNP.test=FALSE
    SUPER_GS=TRUE
  }
if(!is.null(KI)&is.null(GD)&is.null(G)&is.null(file.G)&is.null(file.GD))SNP.test=FALSE
model_store=model

for(m in 1:length(model_store))
  {
model=model_store[m]
if(!is.null(Y))
  {
if(group.from<nrow(Y)) model="CMLM"
  }  

if(group.to!=group.from)model="CMLM"
if(group.to==1&group.from==1)model="GLM"

if(!is.null(sangwich.bottom)&!is.null(sangwich.bottom))model="SUPER"
if(model=="gBLUP") model="MLM"
if(model=="cBLUP") model="CMLM"
if(model=="sBLUP") 
  { model="MLM"
if(!is.null(inclosure.from)&is.null(Para$inclosure.from))Para$inclosure.from=inclosure.from
if(is.null(Para$inclosure.from))Para$inclosure.from=10
if(!is.null(inclosure.to)&is.null(Para$inclosure.to))Para$inclosure.to=inclosure.to
if(is.null(Para$inclosure.to))Para$inclosure.to=100
if(!is.null(inclosure.by)&is.null(Para$inclosure.by))Para$inclosure.by=inclosure.by
if(is.null(Para$inclosure.by))Para$inclosure.by=10
if(!is.null(bin.from)&is.null(Para$bin.from))Para$bin.from=bin.from  
if(is.null(Para$bin.from))Para$bin.from=10000
if(!is.null(bin.to)&is.null(Para$bin.to))Para$bin.to=bin.to  
if(is.null(Para$bin.to))Para$bin.to=10000
if(!is.null(bin.by)&is.null(Para$bin.by))Para$bin.by=bin.by  
if(is.null(Para$bin.by))Para$bin.by=10000
if(!is.null(sangwich.top)&is.null(Para$sangwich.top))Para$sangwich.top=sangwich.top  
if(is.null(Para$sangwich.top))Para$sangwich.top="MLM"
if(!is.null(sangwich.bottom)&is.null(Para$sangwich.bottom))Para$sangwich.bottom=sangwich.bottom  
if(is.null(Para$sangwich.bottom))Para$sangwich.bottom="SUPER"
}

#CMLM
if(model=="GLM")
{
Para$group.from=1
Para$group.to=1
Para$group.by=10
}
if(model=="MLM")
{
Para$group.from=1000000
Para$group.to=1000000
Para$group.by=10
}
if(model=="CMLM")
{
if(is.null(Para$group.from))Para$group.from=group.from
if(is.null(Para$group.to))Para$group.to=group.to
if(is.null(Para$group.by))Para$group.by=group.by
#if(Para$group.from==Para$group.to)Para$group.from=10
if(is.null(Para$group.by))Para$group.by=30

}
if(model=="SUPER")
{
if(!is.null(inclosure.from)&is.null(Para$inclosure.from))Para$inclosure.from=inclosure.from
if(is.null(Para$inclosure.from))Para$inclosure.from=10
if(!is.null(inclosure.to)&is.null(Para$inclosure.to))Para$inclosure.to=inclosure.to
if(is.null(Para$inclosure.to))Para$inclosure.to=100
if(!is.null(inclosure.by)&is.null(Para$inclosure.by))Para$inclosure.by=inclosure.by
if(is.null(Para$inclosure.by))Para$inclosure.by=10
if(!is.null(bin.from)&is.null(Para$bin.from))Para$bin.from=bin.from  
if(is.null(Para$bin.from))Para$bin.from=10000
if(!is.null(bin.to)&is.null(Para$bin.to))Para$bin.to=bin.to  
if(is.null(Para$bin.to))Para$bin.to=10000
if(!is.null(bin.by)&is.null(Para$bin.by))Para$bin.by=bin.by  
if(is.null(Para$bin.by))Para$bin.by=10000
if(!is.null(sangwich.top)&is.null(Para$sangwich.top))Para$sangwich.top=sangwich.top  
if(is.null(Para$sangwich.top))Para$sangwich.top="MLM"
if(!is.null(sangwich.bottom)&is.null(Para$sangwich.bottom))Para$sangwich.bottom=sangwich.bottom  
if(is.null(Para$sangwich.bottom))Para$sangwich.bottom="SUPER"
}
if(model=="FarmCPU")Para$kinship.algorithm="FarmCPU"
if(model=="MLMM")Para$kinship.algorithm="MLMM"
if(model=="Blink")Para$kinship.algorithm="Blink"
if(is.null(Para$memo)|m>1)Para$memo=model
print(Para$memo)

GAPIT_list=list(group.from=group.from ,group.to=group.to,group.by=group.by,DPP=DPP,kinship.cluster=kinship.cluster, kinship.group=kinship.group,kinship.algorithm=kinship.algorithm, 
 bin.from=bin.from,bin.to=bin.to,bin.by=bin.by,inclosure.from=inclosure.from,inclosure.to=inclosure.to,inclosure.by=inclosure.by,SNP.P3D=SNP.P3D,SNP.effect=SNP.effect,SNP.impute=SNP.impute,PCA.total=PCA.total, SNP.fraction = SNP.fraction, seed = seed, BINS = 20,SNP.test=SNP.test,
 SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate, SNP.FDR=SNP.FDR,SNP.permutation=SNP.permutation,SNP.CV=NULL,SNP.robust="GLM",file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment,file.path=file.path, 
 file.G=file.G, file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,ngrid = 100, llim = -10, ulim = 10, esp = 1e-10,Inter.Plot=Inter.Plot,Inter.type=Inter.type,
 LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,PCA.col=PCA.col,PCA.3d=PCA.3d,NJtree.group=NJtree.group,NJtree.type=NJtree.type,opt=opt,
 sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,QC=QC,GTindex=GTindex,LD=LD,plot.bin=plot.bin,file.output=file.output,cutOff=cutOff, Model.selection = Model.selection,output.numerical = output.numerical,
 output.hapmap = output.hapmap, Create.indicator = Create.indicator,QTN=QTN, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = Major.allele.zero,
 method.GLM=method.GLM,method.sub=method.sub,method.sub.final="reward",method.bin="static",bin.size=bin.size,bin.selection=bin.selection,model=model,Random.model=Random.model,
 h2=h2,NQTN=NQTN,QTNDist="normal",effectunit=effectunit,category=category,r=r,cveff=NULL,a2=0,adim=2,Multi_iter=Multi_iter,num_regwas=num_regwas,
 memo="",Prior=NULL,ncpus=1,maxLoop=maxLoop,threshold.output=threshold.output,WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=alpha,maxOut=100,QTN.position=QTN.position,CG=CG,
 converge=converge,iteration.output=iteration.output,acceleration=0,iteration.method="accum",PCA.View.output=PCA.View.output,Geno.View.output=Geno.View.output,plot.style="Oceanic",SUPER_GD=NULL,SUPER_GS=SUPER_GS,Multiple_analysis=Multiple_analysis)

G_list_M=rownames(as.matrix(GAPIT_list))
P_list_M=rownames(as.matrix(Para))

Para=c(GAPIT_list[!G_list_M%in%P_list_M],Para)
#print(Para$kinship.algorithm)

if(SUPER_GS==TRUE)Para$SNP.test=FALSE
IC=NULL
#GAPIT.Version=GAPIT.0000()
print("--------------------Processing traits----------------------------------")
if(!is.null(Y)){
print("Phenotype provided!")
if(ncol(Y)<2)  stop ("Phenotype should have taxa name and one trait at least. Please correct phenotype file!")

if(m==1)
 {
 DP=GAPIT.DP(G=G,GD=GD,GM=GM,KI=KI,Z=Z,CV=CV,CV.Inheritance=Para$CV.Inheritance,GP=GP,GK=GK,
 group.from=Para$group.from ,group.to= Para$group.to,group.by=Para$group.by,DPP= Para$DPP, 
 kinship.cluster=Para$kinship.cluster, kinship.group=Para$kinship.group,kinship.algorithm=Para$ kinship.algorithm, NJtree.group=Para$NJtree.group,NJtree.type=Para$NJtree.type,plot.bin=Para$plot.bin,PCA.col=Para$PCA.col,PCA.3d=Para$PCA.3d,
 sangwich.top=Para$sangwich.top,sangwich.bottom=Para$sangwich.bottom,LD=Para$LD,bin.from= Para$bin.from,bin.to= Para$bin.to,bin.by= Para$bin.by,inclosure.from= Para$inclosure.from,inclosure.to= Para$inclosure.to,inclosure.by= Para$inclosure.by,
 SNP.P3D= Para$SNP.P3D,SNP.effect= Para$SNP.effect,SNP.impute= Para$SNP.impute,PCA.total= Para$PCA.total, SNP.fraction = Para$SNP.fraction, seed = Para$seed, 
 BINS = Para$BINS,SNP.test=Para$SNP.test, SNP.MAF= Para$SNP.MAF,FDR.Rate = Para$FDR.Rate, SNP.FDR= Para$SNP.FDR,SNP.permutation= Para$SNP.permutation,opt=Para$opt,
 SNP.CV= Para$SNP.CV,SNP.robust= Para$SNP.robust,   Inter.Plot=Para$Inter.Plot,  Inter.type=Para$Inter.type,   
 file.from= Para$file.from, file.to=Para$file.to, file.total= Para$file.total, file.fragment = Para$file.fragment,file.path= Para$file.path, 
 file.G= Para$file.G, file.Ext.G= Para$file.Ext.G,file.GD= Para$file.GD, file.GM= Para$file.GM, file.Ext.GD= Para$file.Ext.GD,file.Ext.GM= Para$file.Ext.GM, 
 ngrid = Para$ngrid, llim = Para$llim, ulim = Para$ulim, esp = Para$esp,Multi_iter=Para$Multi_iter,num_regwas=Para$num_regwas,
 LD.chromosome= Para$LD.chromosome,LD.location= Para$LD.location,LD.range= Para$LD.range,
 QC= Para$QC,GTindex= Para$GTindex,cutOff=Para$cutOff, Model.selection = Para$Model.selection,output.numerical = Para$output.numerical,Random.model=Para$Random.model,
 Create.indicator = Para$Create.indicator,QTN= Para$QTN, QTN.round= Para$QTN.round,QTN.limit= Para$QTN.limit, QTN.update= Para$QTN.update, QTN.method= Para$QTN.method, Major.allele.zero = Para$Major.allele.zero,
 method.GLM=Para$ method.GLM,method.sub= Para$method.sub,method.sub.final= Para$method.sub.final,
 method.bin= Para$method.bin,bin.size= Para$bin.size,bin.selection= Para$bin.selection,
 memo= Para$memo,Prior= Para$Prior,ncpus=Para$ncpus,maxLoop= Para$maxLoop,threshold.output= Para$threshold.output,
 WS= Para$WS,alpha= Para$alpha,maxOut= Para$maxOut,QTN.position= Para$QTN.position, converge=Para$converge,iteration.output= Para$iteration.output,acceleration=Para$acceleration,
 iteration.method= Para$iteration.method,PCA.View.output=Para$PCA.View.output, 
 output.hapmap = Para$output.hapmap, file.output= Para$file.output,Geno.View.output=Para$Geno.View.output,plot.style=Para$plot.style,SUPER_GD= Para$SUPER_GD,SUPER_GS= Para$SUPER_GS,CG=Para$CG,model=model)
}else{ 
 DP$kinship.algorithm=Para$ kinship.algorithm
 DP$group.from=Para$group.from
 DP$group.to=Para$group.to
 DP$group.by=Para$group.by
 DP$sangwich.top=Para$sangwich.top
 DP$sangwich.bottom=Para$sangwich.bottom
 DP$bin.from= Para$bin.from
 DP$bin.to= Para$bin.to
 DP$bin.by= Para$bin.by
 DP$inclosure.from= Para$inclosure.from
 DP$inclosure.to= Para$inclosure.toDP$inclosure.by= Para$inclosure.by
}

for (trait in 2: ncol(Y))  
{
traitname=colnames(Y)[trait]
###Statistical distributions of phenotype
###Correlation between phenotype and principal components
print(paste("Processing trait: ",traitname,sep=""))
if(!is.null(Para$memo)) traitname=paste(Para$memo,".",traitname,sep="")
if(!is.null(Y) & Para$file.output)ViewPhenotype<-GAPIT.Phenotype.View(myY=Y[,c(1,trait)],traitname=traitname,memo=Para$memo)
Judge=GAPIT.Judge(Y=Y[,c(1,trait)],G=DP$G,GD=DP$GD,KI=DP$KI,GM=DP$GM,group.to=DP$group.to,group.from=DP$group.from,sangwich.top=DP$sangwich.top,sangwich.bottom=DP$sangwich.bottom,kinship.algorithm=DP$kinship.algorithm,PCA.total=DP$PCA.total,model=DP$model,SNP.test=DP$SNP.test)
DP$group.from=Judge$group.from
DP$group.to=Judge$group.to
DP$name.of.trait=traitname
DP$Y=Y[,c(1,trait)]
DP$model=model
print(Para$SNP.test)
IC=GAPIT.IC(DP=DP)
SS=GAPIT.SS(DP=DP,IC=IC)
if(Para$SNP.test==TRUE)ID=GAPIT.ID(DP=DP,IC=IC,SS=SS)

}#for loop trait
#print(SNP.test)
print("GAPIT accomplished successfully for multiple traits. Result are saved")
print("It is OK to see this: 'There were 50 or more warnings (use warnings() to see the first 50)'")
out <- list()
out$QTN<-QTN.position
out$GWAS<-SS$GWAS
out$Pred<-SS$Pred
out$QTN<-IC$QTN
out$Power<-SS$Power
out$FDR<-SS$FDR
out$Power.Alpha<-SS$Power.Alpha
out$alpha<-SS$alpha
out$mc=SS$mc
out$bc=SS$bc
out$mp=SS$mp
out$h2=SS$h2
out$PCA=IC$PCA
out$GD=DP$GD
out$GM=DP$GM
out$KI=IC$K
out$GM=DP$GM

if(Para$SNP.test==TRUE)names(out$GWAS$P.value)="mp"
if(kinship.algorithm=="FarmCPU")names(out$Pred)=c("Taxa",traitname,"Prediction")
#return (out)
}else{# is.null(Y)
  #print(Para$SNP.MAF)
out <- list()

myGenotype<-GAPIT.Genotype(G=G,GD=GD,GM=GM,KI=KI,kinship.algorithm=Para$kinship.algorithm,PCA.total=Para$PCA.total,SNP.fraction=Para$SNP.fraction,SNP.test=Para$SNP.test,
 file.path=Para$file.path,file.from=Para$file.from, file.to=Para$file.to, file.total=Para$file.total, file.fragment = Para$file.fragment, file.G=Para$file.G, 
 file.Ext.G=Para$file.Ext.G,file.GD=Para$file.GD, file.GM=Para$file.GM, file.Ext.GD=Para$file.Ext.GD,file.Ext.GM=Para$file.Ext.GM,
 SNP.MAF=Para$SNP.MAF,FDR.Rate = Para$FDR.Rate,SNP.FDR=Para$SNP.FDR,SNP.effect=Para$SNP.effect,SNP.impute=Para$SNP.impute,NJtree.group=Para$NJtree.group,NJtree.type=Para$NJtree.type,
 LD.chromosome=Para$LD.chromosome,LD.location=Para$LD.location,LD.range=Para$LD.range,GP=Para$GP,GK=Para$GK,bin.size=NULL,inclosure.size=NULL, 
 sangwich.top=NULL,sangwich.bottom=Para$sangwich.bottom,GTindex=NULL,file.output=Para$file.output, Create.indicator = Para$Create.indicator, Major.allele.zero = Para$Major.allele.zero,Geno.View.output=Para$Geno.View.output,PCA.col=Para$PCA.col,PCA.3d=Para$PCA.3d)
GD=myGenotype$GD
GI=myGenotype$GI
GT=myGenotype$GT
#G=myGenotype$G
chor_taxa=myGenotype$chor_taxa
rownames(GD)=GT
colnames(GD)=GI[,1]
taxa=GT

   if(!is.null(chor_taxa))
   {
     chro=as.numeric(as.matrix(GI[,2]))
     for(i in 1:length(chro))
     {
      chro[chro==i]=chor_taxa[i]
     }
     GI[,2]=chro
   }
#print(GD[1:5,1:5])
if(Para$output.numerical) 
{
  write.table(cbind(taxa,GD),  "GAPIT.Genotype.Numerical.txt", quote = FALSE, sep = "\t", row.names = F,col.names = T)
  write.table(GI,  "GAPIT.Genotype.map.txt", quote = FALSE, sep = "\t", row.names = F,col.names = T)
}
if(Para$output.hapmap) write.table(myGenotype$G,  "GAPIT.Genotype.hmp.txt", quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)
#GD=cbind(as.data.frame(GT),GD)
  if(!is.null(seed))set.seed(seed)
#print(Para$NQTN)
  if(!is.null(Para$NQTN)&!is.null(Para$h2))
  {
  myG_simulation<-GAPIT.Phenotype.Simulation(GD=cbind(as.data.frame(myGenotype$GT),myGenotype$GD),GM=myGenotype$GI,h2=Para$h2,NQTN=Para$NQTN,QTNDist=Para$QTNDist,effectunit=Para$effectunit,category=Para$category,r=Para$r,cveff=Para$cveff,a2=Para$a2,adim=Para$adim)
  out=c(out,myG_simulation)
  }
  out$GD=data.frame(cbind(as.data.frame(GT),as.data.frame(GD)))
  out$GM=GI
  out$G=myGenotype$G
  out$kinship=myGenotype$KI
  out$PCA=myGenotype$PC
  out$chor_taxa=chor_taxa
}# is.null(Y)
}#end of model loop
#print(tail(IC$GM))
if(!is.null(Y)&SNP.test)if(Multiple_analysis&Para$file.output&length(model_store)*(ncol(Y)-1)>1&length(model_store)*(ncol(Y)-1)<9)
{ 
  #print(DP$QTN.position)
GMM=GAPIT.Multiple.Manhattan(model_store=model_store,Y=Y,GM=IC$GM,seqQTN=DP$QTN.position,cutOff=DP$cutOff)
#print(str(GMM$multip_mapP))
GAPIT.Circle.Manhatton.Plot(band=1,r=3,GMM$multip_mapP,plot.type=c("c","q"),signal.line=1,xz=GMM$xz,threshold=DP$cutOff)
}# end of mutiple manhantton plot

return (out)
}  #end of GAPIT function
`GAPIT.ROC` <-
function(t=NULL,se=NULL,Vp=1,trait="",plot.style="rainbow"){
    #Object: To make table and plot for ROC (power vs FDR)
    #Input: t and se are the vectors of t value and their standard error
    #Input: Vp is phenotypic variance and trait is name of the phenotype
    #Output: A table and plot
    #Requirment: error df is same for all SMP or large
    #Authors: Zhiwu Zhang
    # Last update: Feb 11, 2013
    ##############################################################################################
#print("GAPIT.ROC start")
#print("Length of t se and Vp")
#print(length(t))
#print(length(se))
#print((Vp))
if(length(t)==length(t[is.na(t)]) ){
#print("NA t, No ROC plot")
return(NULL)
}
    
    #test
    #n=1000
    #trait="test"
    #t=rnorm(n)
    #se=sqrt(abs(rnorm(n))  )
    #Vp=10
    
    #Remove NAs
    index=is.na(t)
    t=t[!index]
    se=se[!index]
    #print(head(cbind(t,se)))
    #Configration
    FDR=c(0,.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1)
    coefficient=c(0,0.01,.02,.05,.1,.2,.3)
    
    #Power holder
    nf=length(FDR)
    nc=length(coefficient)
    power=matrix(NA,nf,nc)
    
    #Handler of matrix format
    if(!is.null(dim(t))) t=t[,1]
    if(!is.null(dim(se))) se=se[,1]
    
    n=length(t)
    
    #Discard negative
    t=abs(t)
    #print("@@@@@@@@@@@@@@")
    #sort t and se
    position=order(t,decreasing = TRUE)
    t=t[position]
    se=se[position]
    EFFECT=coefficient*sqrt(Vp)
    newbit=matrix(1/se,n,1)%*%EFFECT   #n by nc matrix
    tnew=newbit+t  #n by nc matrix
    
    for (i in 1:nf){
        fdr=FDR[i]
        cutpoint=floor(n*fdr)
        cutoff=t[cutpoint]
        
        
        for (j in 1:nc){
            effect= EFFECT[j]
            singnificant=tnew[,j]>cutoff
            count=length(t[singnificant])
            power[i,j]=count/n
            
        } #end of for on fdr
    } #end of for on effect
    
    #output
    rownames(power)=FDR
    tkk<-c(.3,.2,.1,.05,.02,0.01,0)
    tc1<-c(0,0.25,0.5,0.75,1.0)
    #colnames(power)=paste("QTN=",coefficient,sep="")
    colnames(power)=paste("QTN=",tkk,sep="")

    if(plot.style=="FarmCPU"){
    write.table(power,file=paste("FarmCPU.",trait,".ROC.csv",sep=""),quote = TRUE, sep = ",", row.names = TRUE,col.names = NA)
    }
    if(plot.style=="rainbow"){
        write.table(power,file=paste("GAPIT.",trait,".ROC.csv",sep=""),quote = TRUE, sep = ",", row.names = TRUE,col.names = NA)
    }
    FDR_log<-FDR/10
    #palette(c("black","red","blue","brown", "orange","cyan", "green",rainbow(nc)))
    if(plot.style=="FarmCPU"){
    pdf(paste("FarmCPU.", trait,".ROC.pdf" ,sep = ""), width = 5,height=5)
    par(mar = c(5,6,5,3))
    }
    if(plot.style=="rainbow"){
        pdf(paste("GAPIT.", trait,".ROC.pdf" ,sep = ""), width = 7,height=7)
        par(mar = c(5,5,5,3))
    }
  
 palette(c("black","red","blue","brown", "orange","cyan", "green",rainbow(nc)))
    plot(FDR_log,power[,1],log="x",type="o",yaxt="n",lwd=3,col=1,xlab="Type I error",ylab="Power",main = trait,cex.axis=1.3, cex.lab=1.3)
    axis(side=2,at=tc1,labels=tc1,cex.lab=1.3,cex.axis=1.3)
    for(i in 2:nc){
        lines(power[,i]~FDR_log, lwd=3,type="o",pch=i,col=i)
    }
    #legend("bottomright", colnames(power), pch = c(1:nc), lty = c(1,2),col=c(1:nc))
   legend("bottomright", colnames(power), pch = c(nc:1), lty = c(1,2),col=c(nc:1),lwd=2,bty="n")
    palette("default")      # reset back to the default
    #print("@@@@@@@@@@@@@@")
    #print(power)
    dev.off()
print("ROC completed!")
    
}   #GAPIT.ROC ends here
#=============================================================================================

`GAPIT.RandomModel` <-
function(GWAS,Y,CV=NULL,X,cutOff=0.01,GT=NULL,n_ran=30){
    #Object: To calculate the genetics variance ratio of Candidate Genes
    #Output: The genetics variance raito between CG and total
    #Authors: Jiabo Wang and Zhiwu Zhang
    # Last update: Nov 6, 2019
    ##############################################################################################
    if(!require(lme4))  install.packages("lme4")
    library("lme4")
    #GWAS=myGAPIT_GLM$GWAS
    #CV=myGAPIT_GLM$PCA
    #cut.set=0.01
    #return(list(GVs=NULL))
    print("GAPIT.RandomModel beginning...")
    if(is.null(GT))GT=as.character(Y[,1])
    name.of.trait=colnames(Y)[2]
    cutoff=cutOff/nrow(GWAS)
    P.value=as.numeric(GWAS[,4])
    P.value[is.na(P.value)]=1
    index=P.value<cutoff
    #index[c(1:2)]=TRUE
    
    geneGD=X[,index]

    geneGWAS=GWAS[index,]
    # print(table(index))
    # print(head(geneGD))
    # print(dim(geneGD))
    if(length(unique(index))==1)
    {
    	print("There is no significant marker for VE !!")
    	return(list(GVs=NULL))

    }
    index_T=as.matrix(table(index))
    # print(index_T)
    in_True=index_T[rownames(index_T)=="TRUE"]
    print(in_True==1)
    if(in_True!=1)
    {
    	colnames(geneGD)=paste("gene_",1:in_True,sep="")
    }


    colnames(Y)=c("taxa","trait")
    if(is.null(CV))
    {
        if(in_True>n_ran)
        {
    	print("The candidate markers are more than threshold value !")
    	return(list(GVs=NULL))
    	}     	
    	taxa_Y=as.character(Y[,1])
    	#print("!!")
        if(in_True==1)
        {
        	geneGD=geneGD[GT%in%taxa_Y]
        }else{
        	geneGD=geneGD[GT%in%taxa_Y,]
        }
     # if(!is.null(PC))PC=PC[taxa_GD%in%taxa_Y,]
        Y=Y[taxa_Y%in%GT,]
        tree2=cbind(Y,geneGD)
    	# CV[,2]=1
    }else{
    	if(ncol(CV)==1)
    	{
    		if(in_True+1>n_ran)
            {
    	    print("The candidate markers are more than threshold value !")
    	    return(list(GVs=NULL))
    	    }  
    	taxa_Y=as.character(Y[,1])
    	# print(dim(geneGD))
    	# print(head(GT))
    	# print(head(taxa_Y))
         if(in_True==1)
            {
        	geneGD=geneGD[GT%in%taxa_Y]
            }else{
        	geneGD=geneGD[GT%in%taxa_Y,]
            }     # if(!is.null(PC))PC=PC[taxa_GD%in%taxa_Y,]
        Y=Y[taxa_Y%in%GT,]
        tree2=cbind(Y,geneGD)
    	}else{
    		if(in_True+ncol(CV)-1>n_ran)
            {
    	    print("The candidate markers are more than threshold value !")
    	    return(list(GVs=NULL))
    	    }
    	colnames(CV)=c("Taxa",paste("CV",1:(ncol(CV)-1),sep=""))
    	taxa_Y=as.character(Y[,1])
    	taxa_CV=as.character(CV[,1])
        geneGD=geneGD[GT%in%taxa_Y,]
     # if(!is.null(PC))PC=PC[taxa_GD%in%taxa_Y,]
        Y=Y[taxa_Y%in%GT,]
        CV=CV[taxa_CV%in%GT,]
    	tree2=cbind(Y,CV[,-1],geneGD)
        }
    }
    if(in_True==1)colnames(tree2)[ncol(tree2)]=paste("gene_",1,sep="")

    	# print(head(tree2))
     #    print(dim(CV))
     #    print(dim(geneGD))
    n_cv=ncol(CV)-1
        # print(n_cv)
    n_gd=in_True
    n_id=nrow(Y)
    # print(n_gd)
    # print(n_cv)
    # print(n_id)
    # if((n_gd+n_cv)>n_ran)
    # {
    # 	print("The candidate markers are more than threshold value !")
    # 	return(list(GVs=NULL))
    # 	} 
if(!is.null(CV))
{
#ff <- paste("trait~1+PC1+PC2+PC3+(1|gene_1)+(1|gene_2)+(1|gene_3)+(1|gene_4)+(1|gene_5)+(1|gene_6)"
#dflme <- lmer(ff, data=tree2)
    if(ncol(CV)==1)
    {
    command0=paste("trait~1",sep="")
    command1=command0
    
    command2=command1
    for(j in 1:n_gd)
{
	command2=paste(command2,"+(1|gene_",j,")",sep="")
}

    }else{
    command0=paste("trait~1",sep="")
    command1=command0
    for(i in 1:n_cv)
{	
	command1=paste(command1,"+CV",i,sep="")
}
    command2=command1
    for(j in 1:n_gd)
{
	command2=paste(command2,"+(1|gene_",j,")",sep="")
}
    }
}else{

    command0=paste("trait~1",sep="")
    command1=command0
    
    command2=command1
    for(j in 1:n_gd)
{
	command2=paste(command2,"+(1|gene_",j,")",sep="")
}

}
#command3=paste(command2,"+(1|gene_",j,")",sep="")
    dflme <- lmer(command2, data=tree2,control=lmerControl(check.nobs.vs.nlev = "ignore",
     check.nobs.vs.rankZ = "ignore",
     check.nobs.vs.nRE="ignore"))

    carcor_matrix=as.data.frame(summary(dflme)$varcor)
    var_gene=as.numeric(carcor_matrix[1:(nrow(carcor_matrix)-1),4])
    var_res=carcor_matrix[nrow(carcor_matrix),4]

    print(paste("Candidate Genes could explain genetics variance :",sep=""))
    print(var_gene/sum(var_gene+var_res))
    v_rat=var_gene/sum(var_gene+var_res)
    gene_list=cbind(geneGWAS,v_rat)
    colnames(gene_list)[ncol(gene_list)]="Variance_Explained"

    write.csv(gene_list,paste("GAPIT.", name.of.trait,".Phenotype_Variance_Explained_by_Association_Markers.csv",sep=""),quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
#gene_list=read.csv("GAPIT.Weight.GrowthIntercept.Phenotype_Variance_Explained_by_Association_Markers.csv",head=T)
if(!is.na(sum(gene_list[1,c(4:8)])))
{
        pdf(paste("GAPIT.", name.of.trait,".Effect_VP.pdf" ,sep = ""), width = 7,height=5.75)
        par(mar=c(4,5,4,4),cex=0.8)

        gene_list=gene_list[order(gene_list$effect),]
        plot(gene_list$effect,gene_list$Variance_Explained,
        	xlab="Estimated Effect",
        	ylab="Variance Explained of Phenotype"
        	)
        dev.off()

        pdf(paste("GAPIT.", name.of.trait,".MAF_VP.pdf" ,sep = ""), width = 7,height=5.75)
        par(mar=c(4,5,4,4),cex=0.8)
        gene_list=gene_list[order(gene_list$maf),]
        plot(gene_list$maf,gene_list$Variance_Explained,xlab="MAF",ylab="Variance Explained of Phenotype")
        dev.off()

    if(n_gd>=10)
        {
        pdf(paste("GAPIT.", name.of.trait,".MAF_Effect_VP.pdf" ,sep = ""), width = 9,height=5.75)
        
        n=10
        layout(matrix(c(1,1,2,1,1,1,1,1,1),3,3,byrow=TRUE), c(2,1), c(1,1), TRUE)
        do_color=colorRampPalette(c("green", "red"))(n)

            par(mar=c(4,5,2,8),cex=0.8)
            y=gene_list$maf
            x=gene_list$effect
            x.lim=max(x)+max(x)/10
            y.lim=max(y)+max(y)/10
            z=gene_list$Variance_Explained
            quantile_cut=quantile(z)
            r2_color=rep("black",n_gd)
        for(i in 1:(n/2))
        {
        	r2_color[z<=quantile_cut[i+1]&z>=quantile_cut[i]]=do_color[2*i]
        }
            plot(y~x,type="p", ylim=c(0,y.lim), xlim = c(min(x), max(x)),col = r2_color, xlab = "",ylab = "", cex.lab=1.2,pch=21,bg=r2_color)
            mtext("Estimated Effect",side=1,line=2.5)
            mtext("MAF",side=2,line=2.5)


            par(mar=c(2,13,5,4),cex=0.5)
            
            barplot(matrix(rep(0.4,times=n),n,1),beside=T,col=do_color,border=do_color,axes=FALSE,horiz =T)
        #legend(x=10,y=2,legend=expression(R^"2"),,lty=0,cex=1.3,bty="n",bg=par("bg"))
            step=length(seq(0,round(max(z),3),by=0.01))
            small_bar=round(seq(0,round(max(z),3),by=(max(z)-min(z))/10),2)
            #main()
            mtext("Variance Explained",side=2,line=0.4,col="black",cex=0.5)

            axis(4,c(1,6,11),c(min(small_bar),median(small_bar),max(small_bar)),las=2,cex.axis = 0.9,tick=F,line=0)
        
        dev.off()
        }
}






return(list(GVs=var_gene/sum(var_gene+var_res)))

}#end of GAPIT.RandomModel function
#=============================================================================================
          



`GAPIT.RemoveDuplicate` <-
function(Y){
#Object: NA
#Output: NA
#Authors: Zhiwu Zhang 
# Last update: Augus 30, 2011 
##############################################################################################
return (Y[match(unique(Y[,1]), Y[,1], nomatch = 0), ] )
}
#=============================================================================================

`GAPIT.Report` <-
function(name.of.trait=NULL,GWAS=NULL,pred=pred,ypred=NULL,tvalue=NULL,stderr=NULL,Vp=1,
DPP=100000,cutOff=.01,threshold.output=.01,MAF=NULL,seqQTN=NULL,MAF.calculate=FALSE,plot.style="rainbow"){
#Object: Out put plots and tables
#Input: GWAS,name.of.trait, DPP 
#Requirement: None
#Output: Graphs and tables
#Output: return ycor if ypred is not null
#Authors: Zhiwu Zhang
# Date  start: April 2, 2013
# Last update: April 2, 2013
##############################################################################################
#print("GAPIT.Report Started")
#print(seqQTN)
#Manhattan Plots
#print("Manhattan plot (Genomewise)..." )
if(plot.style=="FarmCPU"){
    GAPIT.Manhattan(GI.MP = GWAS[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=seqQTN,plot.style=plot.style)
}
if(plot.style=="rainbow"){
GAPIT.Manhattan(GI.MP = GWAS[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=seqQTN,plot.style=plot.style)
    #}
#print("Manhattan plot (Chromosomewise)..." )
GAPIT.Manhattan(GI.MP = GWAS[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff,plot.style=plot.style)
}


#QQ plots
#print("QQ plotting..." )
#if(plot.style=="rainbow"){
#    GAPIT.QQ(P.values = GWAS[,4], name.of.trait = name.of.trait,DPP=DPP)
#}
#if(plot.style=="nature"){
GAPIT.QQ(P.values = GWAS[,4], name.of.trait = name.of.trait,DPP=DPP,plot.style=plot.style)
    #}
#Association Table
#print("Create association table..." )
index=1:nrow(GWAS)
if(threshold.output<1)index=which(GWAS[,4]<threshold.output)
if(plot.style=="FarmCPU"){
write.table(GWAS[index,], paste("FarmCPU.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
}
if(plot.style=="rainbow"){
write.table(GWAS[index,], paste("GAPIT.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
}

#Prediction
#print("Create prediction table..." )
#if(!is.null(pred)) write.table(pred, paste("GAPIT.", name.of.trait, ".Pred.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
#print("Create prediction table for unknown phenotype...")
#if(!is.null(ypred)) write.table(ypred, paste("GAPIT.", name.of.trait, ".unknownY.Pred.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
if(!is.null(pred) || !is.null(ypred)){
myPred=FarmCPU.Pred(pred=pred,ypred=ypred,name.of.trait=name.of.trait)
}

#ROC
#print("Creating ROC table and plot" )
myROC=GAPIT.ROC(t=tvalue,se=stderr,Vp=Vp,trait=name.of.trait,plot.style=plot.style)

#MAF
#print("Creating MAF table and plot" )
if(MAF.calculate){
    myMAF=GAPIT.MAF(MAF=MAF,P=GWAS[,4],E=NULL,trait=name.of.trait,threshold.output=threshold.output,plot.style=plot.style)}
#print("Report accomplished" )
}#The function GAPIT.Report ends here
#=============================================================================================
`GAPIT.SS` <-
function(DP=NULL,IC=NULL){
#Object: To Sufficient Statistics (SS) for GWAS and GS
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novenber 3, 2016
##############################################################################################
print("GAPIT.SS in process...")
#Define the funcitno here
Timmer=GAPIT.Timmer(Infor="GAPIT.SS")
Memory=GAPIT.Memory(Infor="GAPIT.SS")
 GR=list()
 GR$GVs=NULL

if(DP$SNP.test)
{
ic_GD=IC$GD
ic_GM=IC$GM
ic_Y=IC$Y
ic_KI=IC$K
ic_PCA=IC$PCA
Z=DP$Z

taxa_Y=as.character(ic_Y[,1])
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GAPIT.QC")
Memory=GAPIT.Memory(Memory=Memory,Infor="GAPIT.QC")

if(DP$kinship.algorithm!="None" & DP$kinship.algorithm!="SUPER" & is.null(Z))
 {
 Z=as.data.frame(diag(1,nrow(ic_Y)))
 Z=rbind(taxa_Y,Z)
 taxa=c('Taxa',as.character(taxa_Y))
 Z=cbind(taxa,Z)
 }
# print(head(ic_PCA))
# print(dim(DP$CV))
# print(head(DP$PC))
if(max(ic_PCA[,2])==min(ic_PCA[,2]))ic_PCA=NULL
#print(head(ic_PCA))
#print("@@@@@")
if (DP$SNP.test&DP$kinship.algorithm%in%c("FarmCPU","Blink","MLMM"))
 {
 Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GAPIT.FarmCPU")
 Memory=GAPIT.Memory(Memory=Memory,Infor="GAPIT.FarmCPU")
 myBus=GAPIT.Bus(Y=ic_Y,CV=ic_PCA,Z=NULL,GK=NULL,KI=ic_KI,GD=ic_GD,GM=ic_GM,GT=IC$GT,
                method=DP$kinship.algorithm,GTindex=DP$GTindex,LD=DP$LD,opt=DP$opt,
                bin.size=DP$bin.size,bin.selection=DP$bin.selection,alpha=DP$alpha,WS=DP$WS,
                cutOff=DP$cutOff,p.threshold=DP$p.threshold,QTN.threshold=DP$QTN.threshold,
                maf.threshold=DP$maf.threshold,method.GLM=DP$method.GLM,method.sub=DP$method.sub,
                method.sub.final=DP$method.sub.final,method.bin=DP$method.bin,Random.model=DP$Random.model,
				        DPP=DP$DPP,file.output=DP$file.output,Multi_iter=DP$Multi_iter,num_regwas=DP$num_regwas )
 GWAS=myBus$GWAS
 Pred=myBus$GPS
 va=myBus$vg
 ve=myBus$ve
 h2=va/(va+ve)
 mc=NULL
#mc=(exp(1)^(1/GWAS$P.value))/10000
 bc=NULL
 mp=NULL
#myP=1/(exp(10000*fm$tau2)
#print(str(GWAS))
 TV=NULL
 Compression=NULL
 GVs=myBus$GVs
 }
#print(ic_GD[1:10,1:10])



if(!DP$kinship.algorithm%in%c("FarmCPU","MLMM","Blink"))
 {
 Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GAPIT.Main")
 Memory=GAPIT.Memory(Memory=Memory,Infor="GAPIT.Main")

	GT=as.matrix(ic_GD[,1])
#print("!!!!!!!")
#print(DP$sangwich.top)
 if(DP$PCA.total==0) ic_PCA=NULL

#print(dim(ic_PCA))
 gapitMain <- GAPIT.Main(Y=ic_Y,GD=DP$GD[,-1],GM=DP$GM,KI=ic_KI,CV=DP$CV,CV.Inheritance=DP$CV.Inheritance,GP=DP$GP,GK=DP$GK,SNP.P3D=DP$SNP.P3D,kinship.algorithm=DP$kinship.algorithm,
						bin.from=DP$bin.from,bin.to=DP$bin.to,bin.by=DP$bin.by,inclosure.from=DP$inclosure.from,inclosure.to=DP$inclosure.to,inclosure.by=DP$inclosure.by,
				        group.from=DP$group.from,group.to=DP$group.to,group.by=DP$group.by,kinship.cluster=DP$kinship.cluster,kinship.group=DP$kinship.group,name.of.trait=DP$name.of.trait,
                        file.path=DP$file.path,file.from=DP$file.from, file.to=DP$file.to, file.total=DP$file.total, file.fragment = DP$file.fragment, file.G=DP$file.G,file.Ext.G=DP$file.Ext.G,file.GD=DP$file.GD, file.GM=DP$file.GM, file.Ext.GD=DP$file.Ext.GD,file.Ext.GM=DP$file.Ext.GM, 
                        SNP.MAF= DP$SNP.MAF,FDR.Rate = DP$FDR.Rate,SNP.FDR=DP$SNP.FDR,SNP.effect=DP$SNP.effect,SNP.impute=DP$SNP.impute,PCA.total=DP$PCA.total,GAPIT.Version=GAPIT.Version,
                        GT=DP$GT, SNP.fraction = DP$SNP.fraction, seed =DP$ seed, BINS = DP$BINS,SNP.test=DP$SNP.test,DPP=DP$DPP, SNP.permutation=DP$SNP.permutation,
                        LD.chromosome=DP$LD.chromosome,LD.location=LD.location,LD.range=LD.range,SNP.CV=SNP.CV,SNP.robust=DP$SNP.robust,model=DP$model,
                        genoFormat="EMMA",hasGenotype=TRUE,byFile=FALSE,fullGD=TRUE,PC=DP$PC,GI=ic_GM,Timmer = DP$Timmer, Memory = DP$Memory,
                        sangwich.top=DP$sangwich.top,sangwich.bottom=DP$sangwich.bottom,QC=DP$QC,GTindex=DP$GTindex,LD=DP$LD,file.output=FALSE,cutOff=DP$cutOff, GAPIT3.output=DP$file.output,
                        Model.selection = DP$Model.selection, Create.indicator = DP$Create.indicator,
						QTN=DP$QTN, QTN.round=DP$QTN.round,QTN.limit=DP$QTN.limit, QTN.update=QTN.update, QTN.method=DP$QTN.method, Major.allele.zero=DP$Major.allele.zero,NJtree.group=DP$NJtree.group,NJtree.type=DP$NJtree.type,plot.bin=DP$plot.bin, 
                        QTN.position=DP$QTN.position,plot.style=DP$plot.style,SUPER_GS=DP$SUPER_GS)  
#print(str(gapitMain))
 GWAS=gapitMain$GWAS
 if(DP$Random.model)GR=GAPIT.RandomModel(Y=ic_Y,X=DP$GD[,-1],GWAS=GWAS,CV=gapitMain$PC,cutOff=DP$cutOff,GT=IC$GT)
 Pred=gapitMain$Pred
#print(head(Pred))
 va=NA#gapitMain$vg
 ve=NA#gapitMain$ve
 h2=gapitMain$h2
 mc=gapitMain$effect.snp
 bc=gapitMain$effect.cv
 mp=gapitMain$P
 TV=gapitMain$TV
 Compression=gapitMain$Compression
 GVs=GR$GVs

 }
myPower=NULL
#print(head(GWAS))
#print(DP$QTN.position)
if(!is.null(GWAS))myPower=GAPIT.Power(WS=DP$WS, alpha=DP$alpha, maxOut=DP$maxOut,seqQTN=DP$QTN.position,GM=DP$GM,GWAS=GWAS)

#print(str(myPower))
  #print("GAPIT.III accomplished successfully for multiple traits. Results are saved")
  return (list(GWAS=GWAS,Pred=Pred,FDR=myPower$FDR,Power=myPower$Power,
  Power.Alpha=myPower$Power.Alpha,alpha=myPower$alpha,h2=h2,va=va,ve=ve,
  mc=mc,bc=bc,mp=mp,TV=TV,Compression=Compression,
  Timmer=Timmer,Memory=Memory,GVs=GVs))
}else{
#
# print("!!!!!!!!!")
# print(dim(DP$Y))
# print(dim(DP$GD))
# print(dim(DP$CV))
# print(dim(DP$PC))
gapitMain <- GAPIT.Main(Y=DP$Y,GD=DP$GD[,-1],GM=DP$GM,KI=DP$KI,Z=DP$Z,CV=DP$CV,CV.Inheritance=DP$CV.Inheritance,GP=DP$GP,GK=DP$GK,SNP.P3D=DP$SNP.P3D,kinship.algorithm=DP$kinship.algorithm,
            bin.from=DP$bin.from,bin.to=DP$bin.to,bin.by=DP$bin.by,inclosure.from=DP$inclosure.from,inclosure.to=DP$inclosure.to,inclosure.by=DP$inclosure.by,
                group.from=DP$group.from,group.to=DP$group.to,group.by=DP$group.by,kinship.cluster=DP$kinship.cluster,kinship.group=DP$kinship.group,name.of.trait=DP$name.of.trait,
                        file.path=DP$file.path,file.from=DP$file.from, file.to=DP$file.to, file.total=DP$file.total, file.fragment = DP$file.fragment, file.G=DP$file.G,file.Ext.G=DP$file.Ext.G,file.GD=DP$file.GD, file.GM=DP$file.GM, file.Ext.GD=DP$file.Ext.GD,file.Ext.GM=DP$file.Ext.GM, 
                        SNP.MAF= DP$SNP.MAF,FDR.Rate = DP$FDR.Rate,SNP.FDR=DP$SNP.FDR,SNP.effect=DP$SNP.effect,SNP.impute=DP$SNP.impute,PCA.total=DP$PCA.total,GAPIT.Version=GAPIT.Version,
                        GT=DP$GT, SNP.fraction = DP$SNP.fraction, seed =DP$ seed, BINS = DP$BINS,SNP.test=DP$SNP.test,DPP=DP$DPP, SNP.permutation=DP$SNP.permutation,
                        LD.chromosome=DP$LD.chromosome,LD.location=LD.location,LD.range=LD.range,SNP.CV=SNP.CV,SNP.robust=DP$SNP.robust,model=DP$model,
                        genoFormat="EMMA",hasGenotype=TRUE,byFile=FALSE,fullGD=TRUE,PC=DP$PC,GI=DP$GI,Timmer = DP$Timmer, Memory = DP$Memory,GAPIT3.output=DP$file.output,
                        sangwich.top=DP$sangwich.top,sangwich.bottom=DP$sangwich.bottom,QC=DP$QC,GTindex=DP$GTindex,LD=DP$LD,file.output=FALSE,cutOff=DP$cutOff, 
                        Model.selection = DP$Model.selection, Create.indicator = DP$Create.indicator,
            QTN=DP$QTN, QTN.round=DP$QTN.round,QTN.limit=DP$QTN.limit, QTN.update=QTN.update, QTN.method=DP$QTN.method, Major.allele.zero=DP$Major.allele.zero,NJtree.group=DP$NJtree.group,NJtree.type=DP$NJtree.type,plot.bin=DP$plot.bin, 
                        QTN.position=DP$QTN.position,plot.style=DP$plot.style,SUPER_GS=DP$SUPER_GS)  
#print(str(gapitMain))
GWAS=gapitMain$GWAS
#print(head(GWAS))
Pred=gapitMain$Pred
#print(head(Pred))
va=NA#gapitMain$vg
ve=NA#gapitMain$ve
h2=gapitMain$h2
mc=gapitMain$effect.snp
bc=gapitMain$effect.cv
mp=gapitMain$P
Compression=gapitMain$Compression

return (list(GWAS=GWAS,Pred=Pred,FDR=NULL,Power=NULL,
  Power.Alpha=NULL,alpha=NULL,h2=h2,va=va,ve=ve,Compression=Compression,
  mc=mc,bc=bc,mp=mp,TV=gapitMain$TV,
  Timmer=Timmer,Memory=Memory))
}#end of SNP.TEST

}  #end of GAPIT.SS function
#=============================================================================================

`GAPIT.SUPER.FastMLM` <-
function(ys, xs, vg, delta, Z = NULL, X0 = NULL, snp.pool=NULL,LD=0.01,method="FaST") {
#Input: ys, xs, vg, delta, Z, X0, snp.pool
#Output: GWAS
#Authors: Qishan Wang, Feng Tian and Zhiwu Zhang
#Last update: April 16, 2012
################################################################################
#print("GAPIT.SUPER.FastMLM started")
#print("dimension of ys,xs,X0 and snp.pool")
#print(length(ys))
#print(dim(xs))
#print(dim(X0))
#print(dim(snp.pool))
#print((LD))


#Set data to the require format
ys=unlist(ys)
if(is.null(dim(ys)) || ncol(ys) == 1)  ys <- matrix(ys, 1, length(ys))
if(is.null(dim(xs)) || ncol(xs) == 1)  xs <- matrix(xs, 1, length(xs))
if(is.null(X0))  X0 <- matrix(1, nrow(snp.pool), 1)

#Exract data size
g <- nrow(ys)
n <- nrow(xs)   #####  generaol nrow(xs)=nrow(U1) rivised by qishan 2012.4.16
m <- ncol(xs)
t <- nrow(xs)
q0 <- ncol(X0)
q1 <- q0 + 1

#Allocate space
dfs <- matrix(nrow = m, ncol = g)
stats <- matrix(nrow = m, ncol = g)
ps <- matrix(nrow = m, ncol = g)
betavalue <- matrix(nrow = m, ncol = g)
####################
if(method=="SUPER"){
 LDsqr=sqrt(LD)  
##################  
 
#Iteration on trait (j) and SNP (i)
for(j in 1:g)
{
 
for (i in 1:m)
{
  if((i >0)&(floor(i/500)==i/500))  print(paste("SNP: ",i," ",sep=""))


  #No variation on the SNP
  if(min(xs[,i])==max(xs[,i]))
  {
    dfs[i,j] <- n - q1
    betavalue[i,j]=0
    stats[i,j] <- 0
  }
  #The SNP has variation
  if(min(xs[,i])!=max(xs[,i]))
  {
      #SUPER
      snp.corr=cor(xs[,i],snp.pool)
      index.k=which( abs(snp.corr)<=LDsqr )
      #handler of snp correlated with all QTNs
      if(length(index.k)<2){
       index.k=1:length(snp.corr) #keep going to have them all
       #print("warning: there is a snp correlated with all QTNs")
      }   
      K.X= snp.pool[,index.k]
      ####################
      K.X.svd= svd(K.X) ###start 2012.4.16 by qishan
  
       d=K.X.svd$d
       d=d[d>1e-8]
       d=d^2

       U1=K.X.svd$u   
       U1=U1[,1:length(d)]  ### end 2012.4.16 by qishan
 
       n<-nrow(U1)

      
       I= diag(1,nrow(U1))
      
      ################ get iXX
         X <- cbind(X0, xs[,i]) ####marker by column
         U <- U1*matrix(sqrt(1/(d + delta)), nrow(U1), length(d), byrow = TRUE) 
         Xt <- crossprod(U, X) 
         XX1<- crossprod(Xt, Xt)
         XX2<- crossprod((I-tcrossprod(U1,U1))%*%X,(I-tcrossprod(U1,U1))%*%X)/delta
         #iXX<-solve(XX1+XX2) 
         
           iXX <- try(solve(XX1+XX2),silent=T)
     if(inherits(iXX, "try-error")){
     iXX <- ginv(XX1+XX2)
     }
      #################  end get ixx
      ################   begin get beta
      ################
    #######get beta compnents 1
#U1TX=t(U1)%*%X
U1TX=crossprod(U1,X)
beta1=0
for(ii in 1:length(d)){
one=matrix(U1TX[ii,], nrow=1)
dim(one)
#beta=t(one)%*%one/(d[ii]+delta)
beta=crossprod(one,one)/(d[ii]+delta)
beta1= beta1+beta
}

#######get beta components 2
#IUX=(I-U1%*%t(U1))%*%X
IUX=(I-tcrossprod(U1,U1))%*%X
beta2=0
for(ii in 1:nrow(U1)){
one=matrix(IUX[ii,], nrow=1)
dim(one)
beta=t(one)%*%one
beta2= beta2+beta
}
beta2<-beta2/delta

#######get b3
#U1TY=t(U1)%*%ys[j,]
U1TY=crossprod(U1,ys[j,])
beta3=0
for(ii in 1:length(d)){
one1=matrix(U1TX[ii,], nrow=1)
one2=matrix(U1TY[ii,], nrow=1)
beta=crossprod(one1,one2)/(d[ii]+delta)
beta3= beta3+beta
}

###########get beta4
#IUY=(I-U1%*%t(U1))%*%ys[j,]
IUY=(I-tcrossprod(U1,U1))%*%ys[j,]
beta4=0
for(ii in 1:nrow(U1)){
one1=matrix(IUX[ii,], nrow=1)
one2=matrix(IUY[ii,], nrow=1)
#beta=t(one1)%*%one2
beta=crossprod(one1,one2)
beta4= beta4+beta
}
beta4<-beta4/delta

#######get final beta
beta=ginv(beta1+beta2)%*%(beta3+beta4)
   
      ##############
      ################    end get beta

    betavalue[i,j]=beta[q1,1]
    stats[i,j] <- beta[q1,1]/sqrt(iXX[q1, q1] * vg)
    dfs[i,j] <- n - q1
  } #end of SNP variation stutus detection
} #loop for markers

#print("Calculating p-values...")
ps[,j] <- 2 * pt(abs(stats[,j]), dfs[,j],  lower.tail = FALSE)
} #end of loop on traits

return(list(beta=betavalue, ps = ps, stats = stats, dfs = dfs,effect=betavalue))
} #Enf of SUPERMLM

#######################
if(method=="FaST"){
 K.X.svd= svd(snp.pool) ###start 2012.4.16 by qishan
  
       d=K.X.svd$d
       d=d[d>1e-8]
       d=d^2

       U1=K.X.svd$u   
       U1=U1[,1:length(d)]  ### end 2012.4.16 by qishan
 
       n<-nrow(U1)
       I= diag(1,nrow(U1))
   U <- U1*matrix(sqrt(1/(d + delta)), nrow(U1), length(d), byrow = TRUE) 
################## 
 
#Iteration on trait (j) and SNP (i)
for(j in 1:g)
{
 
for (i in 1:m)
{
  if((i >0)&(floor(i/500)==i/500))  print(paste("SNP: ",i," ",sep=""))


  #No variation on the SNP
  if(min(xs[,i])==max(xs[,i]))
  {
    dfs[i,j] <- n - q1
    betavalue[i,j]=0
    stats[i,j] <- 0
  }
  #The SNP has variation
  if(min(xs[,i])!=max(xs[,i]))
  {
      #SUPER
      
      ####################
      K.X.svd= svd(snp.pool) ###start 2012.4.16 by qishan
  
       d=K.X.svd$d
       d=d[d>1e-8]
       d=d^2

       U1=K.X.svd$u   
       U1=U1[,1:length(d)]  ### end 2012.4.16 by qishan
 
       n<-nrow(U1)
       I= diag(1,nrow(U1))
      
      ################ get iXX
         X <- cbind(X0, xs[,i]) ####marker by column
         U <- U1*matrix(sqrt(1/(d + delta)), nrow(U1), length(d), byrow = TRUE) 
         Xt <- crossprod(U, X) 
         XX1<- crossprod(Xt, Xt)
         XX2<- crossprod((I-tcrossprod(U1,U1))%*%X,(I-tcrossprod(U1,U1))%*%X)/delta
                iXX <- try(solve(XX1+XX2),silent=T)
     if(inherits(iXX, "try-error")){
     iXX <- ginv(XX1+XX2)
     }
      #################  end get ixx
      ################   begin get beta
    #######get beta compnents 1
#U1TX=t(U1)%*%X
U1TX=crossprod(U1,X)
beta1=0
for(ii in 1:length(d)){
one=matrix(U1TX[ii,], nrow=1)
dim(one)
beta=crossprod(one,one)/(d[ii]+delta)
beta1= beta1+beta
}

#######get beta components 2
IUX=(I-tcrossprod(U1,U1))%*%X
beta2=0
for(ii in 1:nrow(U1)){
one=matrix(IUX[ii,], nrow=1)
dim(one)
beta=crossprod(one,one)
beta2= beta2+beta
}
beta2<-beta2/delta

#######get b3
#U1TY=t(U1)%*%ys[j,]
U1TY=crossprod(U1,ys[j,])
beta3=0
for(ii in 1:length(d)){
one1=matrix(U1TX[ii,], nrow=1)
one2=matrix(U1TY[ii,], nrow=1)
#beta=t(one1)%*%one2/(d[ii]+delta)
beta=crossprod(one1,one2)/(d[ii]+delta)
beta3= beta3+beta
}

###########get beta4
#IUY=(I-U1%*%t(U1))%*%ys[j,]
IUY=(I-tcrossprod(U1,U1))%*%ys[j,]
beta4=0
for(ii in 1:nrow(U1)){
one1=matrix(IUX[ii,], nrow=1)
one2=matrix(IUY[ii,], nrow=1)
#beta=t(one1)%*%one2
beta=crossprod(one1,one2)
beta4= beta4+beta
}
beta4<-beta4/delta

#######get final beta
beta=ginv(beta1+beta2)%*%(beta3+beta4)
   
      ##############
      ################    end get beta

    betavalue[i,j]=beta[q1,1]
    stats[i,j] <- beta[q1,1]/sqrt(iXX[q1, q1] * vg)
    dfs[i,j] <- n - q1
  } #end of SNP variation stutus detection
} #loop for markers

#print("Calculating p-values...")
ps[,j] <- 2 * pt(abs(stats[,j]), dfs[,j],  lower.tail = FALSE)
} #end of loop on traits

return(list(beta=betavalue, ps = ps, stats = stats, dfs = dfs,effect=betavalue))
} #Enf of FastMLM

}####end function
#=============================================================================================

`GAPIT.SUPER.GS`<-
function(Y=Y[,c(1,trait)],G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,GK=GK,kinship.algorithm=kinship.algorithm,
                      bin.from=bin.from,bin.to=bin.to,bin.by=bin.by,inclosure.from=inclosure.from,inclosure.to=inclosure.to,inclosure.by=inclosure.by,
				        group.from=group.from,group.to=group.to,group.by=group.by,kinship.cluster=kinship.cluster,kinship.group=kinship.group,name.of.trait=traitname,
                        file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM, 
                        SNP.MAF= SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,PCA.total=PCA.total,GAPIT.Version=GAPIT.Version,
                        GT=GT, SNP.fraction = SNP.fraction, seed = seed, BINS = BINS,SNP.test=SNP.test,DPP=DPP, SNP.permutation=SNP.permutation,
                        LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,SNP.CV=SNP.CV,SNP.robust=SNP.robust,model=model,
                        genoFormat=genoFormat,hasGenotype=hasGenotype,byFile=byFile,fullGD=fullGD,PC=PC,GI=GI,Timmer = Timmer, Memory = Memory,
                        sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,QC=QC,GTindex=GTindex,LD=LD,file.output=file.output,cutOff=cutOff
                        ){
#Object: To perform GPS with SUPER and Compress method
#Designed by Zhiwu Zhang
#Writen by Jiabo Wang
#Last update: Novber 6, 2015 		
######################################################
print("--------------------- Welcome to GAPIT SUPER GS----------------------------")
Timmer=GAPIT.Timmer(Infor="GAPIT.SUPER.GS")
Memory=GAPIT.Memory(Infor="GAPIT.SUPER.GS")
  if(!require(EMMREML)) install.packages("EMMREML")
  library(EMMREML)

shortcut=FALSE
LL.save=1e10
#In case of null Y and null GP, return genotype only  
thisY=Y[,2]
thisY=thisY[!is.na(thisY)]
if(length(thisY) <3){
 shortcut=TRUE
 }else{
  if(var(thisY) ==0) shortcut=TRUE
}
if(shortcut){
print(paste("Y is empty. No GWAS/GS performed for ",name.of.trait,sep=""))
return (list(compression=NULL,kinship.optimum=NULL, kinship=KI,PC=PC,GWAS=NULL, GPS=NULL,Pred=NULL, REMLs=NULL,Timmer=Timmer,Memory=Memory))
}
print("------------Examining data (QC)------------------------------------------")
if(is.null(Y)) stop ("GAPIT says: Phenotypes must exist.")
if(is.null(KI)&missing(GD) & kinship.algorithm!="SUPER") stop ("GAPIT says: Kinship is required. As genotype is not provided, kinship can not be created.")
if(is.null(GD) & is.null(GT)) {
	GT=as.matrix(Y[,1])
	GD=matrix(1,nrow(Y),1)	
  GI=as.data.frame(matrix(0,1,3) )
  colnames(GI)=c("SNP","Chromosome","Position")
}
#merge CV with PC
#print(dim(CV))
#if(PCA.total>0&!is.null(CV))CV=GAPIT.CVMergePC(CV,PC)
#if(PCA.total>0&is.null(CV))CV=PC
#for GS merge CV with GD name
 #print("!!!!!!")
 #print(dim(CV))
# print(head(GT))
# print(head(GI))
# if (is.null(CV))
# {my_allCV=CV
# }else{
    
#     taxa_GD=GT
    
#     my_allCV=CV[order(CV[,1]),]
#     my_allCV=my_allCV[my_allCV[,1]%in%taxa_GD,]
#     #print(dim(my_allCV))
# }
my_allCV=CV
#print(dim(my_allCV))

if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & is.null(Z)){
taxa=as.character(Y[,1])
Z=as.data.frame(diag(1,nrow(Y)))
Z=rbind(taxa,Z)
taxa=c('Taxa',as.character(taxa))
Z=cbind(taxa,Z)
}
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & !is.null(Z))
{
  if(nrow(Z)-1<nrow(Y)) Z=GAPIT.ZmatrixFormation(Z=Z,Y=Y)
}
noCV=FALSE
if(is.null(CV)){
noCV=TRUE
CV=Y[,1:2]
CV[,2]=1
colnames(CV)=c("taxa","overall")
}
#Remove duplicat and integragation of data
print("QC is in process...")
CVI <- CV
if(QC)
{
#print(colnames(KI)[53:62])

  qc <- GAPIT.QC(Y=Y,KI=KI, GT=GT,CV=CV,Z=Z,GK=GK)
  GTindex=qc$GTindex
  Y=qc$Y
  KI=qc$KI
  CV=qc$CV
  Z=qc$Z
  GK=qc$GK
my_taxa=as.character(KI[,1])
my_allKI=KI

#print(dim(CV))
}
print("The value of QC is")
print(QC)
rm(qc)
gc()
print("------------Examining data (QC) done-------------------------------------")
super_pass=FALSE
SUPER_myKI=NULL
SUPER_optimum_GD=NULL
if (!is.null(sangwich.top)) super_pass=TRUE
if(super_pass)
{
print("-------------------start SUPER BREAD-----------------------------------")
#Create GK if not provided
#print(memory.size())
  if(is.null(GK)){
    nY=floor(nrow(Y)*.9)
    nG=ncol(GD)
    if(nG>nY){snpsam=sample(1:nG,nY)}else{snpsam=1:nG}
    GK=GD[GTindex,snpsam]
    SNPVar=apply(as.matrix(GK),2,var)
	#print(snpsam)
if (snpsam==1)stop ("GAPIT says: SUPER_GS must putin GD and GM.")
    GK=GK[,SNPVar>0]
    GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa
    
  }
  #print(head(CV))
  #myGD=cbind(as.data.frame(GT),as.data.frame(GD)) 

  file.output.temp=file.output
  file.output=FALSE
#  print(memory.size())
  GP=GAPIT.Bread(Y=Y,CV=CV,Z=Z,KI=KI,GK=GK,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,method=sangwich.top,GTindex=GTindex,LD=LD,file.output=file.output)$GWAS
  file.output=file.output.temp
#  print(memory.size())

  GK=NULL

if(inclosure.to>nrow(Y))   ##########removed by Jiabo Wang ,unlimited number of inclosures
{
inclosure.to=nrow(Y)-1
print("the number of choosed inclosure is more than number of individuals")
print("Set the number of choosed incolosure max equal to individuals")
}
if(inclosure.from>inclosure.to)   ##########removed by Jiabo Wang ,unlimited number of inclosures
{
inclosure.from=inclosure.to
}
bin.level=seq(bin.from,bin.to,by=bin.by)
inclosure=seq(inclosure.from,inclosure.to,by=inclosure.by)
#print(inclosure)
e=1 #################################number of bins and inclosure
count=0
num_selection=length(bin.level)*length(inclosure)
SUPER_selection=matrix(,num_selection,6)
colnames(SUPER_selection)=c("bin","pseudo_QTNs","Max_pQTNs","REML","VA","VE")
#for (bin in bin.level){bin=bin.level[e]}
#for (inc in inclosure){inc=inclosure[e]}
for (bin in bin.level){
for (inc in inclosure){
count=count+1
  mySpecify=GAPIT.Specify(GI=GI,GP=GP,bin.size=bin,inclosure.size=inc)
  SNP.QTN=mySpecify$index
  num_pseudo_QTN=length(mySpecify$CB)
  num_bins=mySpecify$num_bins
#print(paste("bin---",bin,"---inc---",inc,sep=""))
  GK=GD[GTindex,SNP.QTN]
  SUPER_GD=GD[,SNP.QTN]
  SNPVar=apply(as.matrix(GK),2,var)
  GK=GK[,SNPVar>0]
  SUPER_GD=SUPER_GD[,SNPVar>0]
  GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa
  SUPER_GD=cbind(as.data.frame(GT),as.data.frame(SUPER_GD)) #add taxa
  myBurger=GAPIT.Burger(Y=Y,CV=CV,GK=GK)  #modifed by Jiabo Wang
  myREML=myBurger$REMLs
  myVG=myBurger$vg
  myVE=myBurger$ve
SUPER_selection[count,1]=bin
SUPER_selection[count,2]=num_pseudo_QTN
SUPER_selection[count,3]=num_bins
SUPER_selection[count,4]=myREML
SUPER_selection[count,5]=myVG
SUPER_selection[count,6]=myVE
  #print(SUPER_selection[count,])
  if(count==1){
  GK.save=GK
  LL.save=myREML
  	SUPER_optimum_GD=SUPER_GD     ########### get SUPER GD
}else{
  if(myREML<LL.save){
    GK.save=GK
    LL.save=myREML
	SUPER_optimum_GD=SUPER_GD     ########### get SUPER GD
  }
}
  if (num_bins==num_pseudo_QTN) break
  }# bin end
  }# inc end
  SUPER_selection<-SUPER_selection[!is.na(SUPER_selection[,1]),]
  print(SUPER_selection)
  print("-----select optimum pseudo QTNs from all the bins-------")
  if(is.null(dim(SUPER_selection)))
  {optimum_SUPER=SUPER_selection
  }else{
  optimum_SUPER=SUPER_selection[which(as.numeric(SUPER_selection[,4])==min(as.numeric(SUPER_selection[,4]))),]
  }
  print(optimum_SUPER)
  ########################BUILD SUPER KINSHIP
  ##########################################################
colnames(SUPER_optimum_GD)=c("taxa",colnames(SUPER_optimum_GD)[-1])
SUPER_taxa=as.character(SUPER_optimum_GD[,1])
SUPER_X=SUPER_optimum_GD[,-1]
  if(kinship.algorithm=="Loiselle")SUPER_myKI_test= GAPIT.kinship.loiselle(snps=t(as.matrix(.5*(SUPER_optimum_GD[,-1]))), method="additive", use="all")
 # if(kinship.algorithm=="VanRaden")SUPER_myKI_test= GAPIT.kinship.VanRaden(snps=as.matrix(SUPER_optimum_GD[,-1])) 
  if(kinship.algorithm=="Zhang")SUPER_myKI_test= GAPIT.kinship.Zhang(snps=as.matrix(SUPER_optimum_GD[,-1])) 
  if(!kinship.algorithm=="Loiselle"|!kinship.algorithm=="Zhang")SUPER_myKI_test= GAPIT.kinship.VanRaden(snps=as.matrix(SUPER_optimum_GD[,-1])) 

SUPER_myKI_test=GAPIT.kinship.VanRaden(snps=as.matrix(SUPER_optimum_GD[,-1]))     #  build kinship
colnames(SUPER_myKI_test)=SUPER_taxa
SUPER_myKI=cbind(SUPER_taxa,as.data.frame(SUPER_myKI_test))
print("select optimum number of marker effect in GD")
print(dim(SUPER_optimum_GD))
#print(SUPER_optimum_GD[1:5,1:5])
######################################GOIN TO NEW CBLUP
Z=NULL
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & is.null(Z)){
taxa=as.character(SUPER_optimum_GD[,1])
Z=as.data.frame(diag(1,nrow(SUPER_optimum_GD)))
Z=rbind(taxa,Z)
taxa=c('Taxa',as.character(taxa))
Z=cbind(taxa,Z)
}
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & !is.null(Z))
{
  if(nrow(Z)-1<nrow(Y)) Z=GAPIT.ZmatrixFormation(Z=Z,Y=Y)
}
print("QC is in process...")
GK=NULL
CVI <- CV
if(QC)
{
  qc <- GAPIT.QC(Y=Y,KI=SUPER_myKI, GT=GT,CV=CV,Z=Z,GK=GK)
  GTindex=qc$GTindex
  Y=qc$Y
  KI=qc$KI
  CV=qc$CV
  Z=qc$Z
  GK=qc$GK
}
rm(qc)
gc()
}# super_pass end

nk=1000000000
if(!is.null(KI)) nk=min(nk,nrow(KI))
if(!is.null(GK)) nk=min(nk,nrow(GK))
if(!is.null(KI))
{
  if(group.to>nk) {
    #group.to=min(nrow(KI),length(GTindex)) #maximum of group is number of rows in KI
    group.to=nk #maximum of group is number of rows in KI
    warning("The upper bound of groups is too high. It was set to the size of kinship!") 
  }
	if(group.from>nk){ 
    group.from=nk
    warning("The lower bound of groups is too high. It was set to the size of kinship!") 
  } 
}

if(!is.null(CV)){
 	if(group.to<=ncol(CV)+1) {
	#The minimum of group is number of columns in CV
	  group.from=ncol(CV)+2
	  group.to=ncol(CV)+2
	  warning("The upper bound of groups (group.to) is not sufficient. both boundries were set to their minimum and GLM is performed!")
	}
}

  GROUP=seq(group.to,group.from,by=-group.by)#The reverse order is to make sure to include full model
if(missing("kinship.cluster")) kinship.cluster=c("ward", "single", "complete", "average", "mcquitty", "median", "centroid")
if(missing("kinship.group")) kinship.group=c("Mean", "Max", "Min", "Median")
numSetting=length(GROUP)*length(kinship.cluster)*length(kinship.group)
ys=as.matrix(Y[2])
X0=as.matrix(CV[,-1])
if(min(X0[,1])!=max(X0[,1])) X0 <- cbind(1, X0) #do not add overall mean if X0 has it already at first column
hold_Z=Z

 # library("EMMREML")
order_count=0
storage_reml=NULL
Compression=matrix(,numSetting,6)
colnames(Compression)=c("Type","Cluster","Group","REML","VA","VE")

for (group in GROUP)
{
  for (ca in kinship.cluster)
  {
  for (kt in kinship.group)
  {
  #if(group=1) group=2
#if(!optOnly) {print("Compressing and Genome screening..." )}
order_count=order_count+1
if(order_count==1)print("-------Mixed model with Kinship-----------------------------")
if(group<ncol(X0)+1) group=2 # the emma function (emma.delta.REML.dLL.w.Z) does not allow K has dim less then CV. turn to GLM (group=1)
cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
bk <- GAPIT.Block(Z=hold_Z,GA=cp$GA,KG=cp$KG)
zc <- GAPIT.ZmatrixCompress(Z=hold_Z,GAU =bk$GA)
zrow=nrow(zc$Z)
zcol=ncol(zc$Z)-1
K = as.matrix(bk$KW)

#if (nrow(as.matrix(bk$KW))==1)
Z=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol)
if(is.null(dim(ys)) || ncol(ys) == 1)  ys <- matrix(ys, 1, length(ys))
if(is.null(X0)) X0 <- matrix(1, ncol(ys), 1)
#handler of special Z and K
if(!is.null(Z)){ if(ncol(Z) == nrow(Z)) Z = NULL }
if(!is.null(K)) {if(length(K)<= 1) K = NULL}
X <-  X0 #covariate variables such as population structure
j=1
  if (is.null(Z)) Z=diag(x=1,nrow(K),ncol(K))
  if (group==1)   K=1
  #print(head(X))
   emma_test <- emmreml(as.numeric(ys), X=as.matrix(X), K=as.matrix(K), Z=Z,varbetahat=FALSE,varuhat=FALSE, PEVuhat=FALSE, test=FALSE)  

   print(paste(order_count, "of",numSetting,"--","Vg=",round(emma_test$Vu,4), "VE=",round(emma_test$Ve,4),"-2LL=",round(-2*emma_test$loglik,2), "  Clustering=",ca,"  Group number=", group ,"  Group kinship=",kt,sep = " "))
  emma_test_reml=-2*emma_test$loglik
  storage_reml=append(storage_reml,-2*emma_test$loglik)
Compression[order_count,1]=kt
Compression[order_count,2]=ca
Compression[order_count,3]=group
Compression[order_count,4]=emma_test_reml
Compression[order_count,5]=emma_test$Vu
Compression[order_count,6]=emma_test$Ve
  if(order_count==1){
   save_remle=emma_test_reml
   optimum_group=group
   optimum_Clustering=ca
   optimum_groupK=kt
}else{
  if(emma_test_reml<save_remle){
   save_remle=emma_test_reml
   optimum_group=group
   optimum_Clustering=ca
   optimum_groupK=kt
  }
}
}   # kt end

  } # ka end
  } # group end
  print(Compression)
 if(optimum_group==1)  
{
optimum_group=2
}
#print(colnames(KI)[53:62])
cp <- GAPIT.Compress(KI=KI,kinship.cluster=optimum_Clustering,kinship.group=optimum_groupK,GN=optimum_group,Timmer=Timmer,Memory=Memory)
bk <- GAPIT.Block(Z=hold_Z,GA=cp$GA,KG=cp$KG)
zc <- GAPIT.ZmatrixCompress(Z=hold_Z,GAU =bk$GA)
zrow=nrow(zc$Z)
zcol=ncol(zc$Z)-1
K = as.matrix(bk$KW)


Z=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol)
if(is.null(dim(ys)) || ncol(ys) == 1)  ys <- matrix(ys, 1, length(ys))
if(is.null(X0)) X0 <- matrix(1, ncol(ys), 1)
  X <-  X0 #covariate variables such as population structure
  if (is.null(Z)) Z=diag(x=1,nrow(K),ncol(K))
  
  # print(my_allCV)
  if (is.null(my_allCV)){my_allX=matrix(1,length(my_taxa),1)
  }else{
   # my_allX=as.matrix(my_allCV[,-1])
       my_allX=cbind(1,as.matrix(my_allCV[,-1]))
	}
   emma_REMLE <- emmreml(y=as.numeric(ys), X=as.matrix(X), K=as.matrix(K), Z=Z,varbetahat=TRUE,varuhat=TRUE, PEVuhat=TRUE, test=TRUE)  
   #print(head(emma_REMLE$uhat))
   #print(emma_REMLE$uhat[53:62])
   
   emma_BLUE=as.matrix(my_allX)%*%as.matrix(emma_REMLE$betahat)
   emma_BLUE=as.data.frame(cbind(my_taxa,emma_BLUE))
   colnames(emma_BLUE)=c("Taxa","emma_BLUE")
gs <- GAPIT.GS(KW=bk$KW,KO=bk$KO,KWO=bk$KWO,GAU=bk$GAU,UW=cbind(emma_REMLE$uhat,emma_REMLE$PEVuhat))
 #print(head(gs$BLUP))
 #print(head(emma_BLUE))
 BB= merge(gs$BLUP, emma_BLUE, by.x = "Taxa", by.y = "Taxa")
 #print(head(BB))
prediction=as.matrix(BB$BLUP)+as.numeric(as.vector(BB$emma_BLUE))
all_gs=cbind(BB,prediction)
colnames(all_gs)=c("Taxa","Group","RefInf","ID","BLUP","PEV","BLUE","Prediction")
#print(head(all_gs))
#print(model)

write.csv(all_gs,paste("GAPIT.",model,".Pred.result.csv",sep=""), row.names = FALSE,col.names = TRUE)

  print("GAPIT SUPER GS completed successfully for multiple traits. Results are saved")
  return (list(GPS=BB,Pred=all_gs,Compression=Compression,kinship=my_allKI,SUPER_kinship=SUPER_myKI,SUPER_GD=SUPER_optimum_GD ,PC=my_allCV,Timmer=Timmer,Memory=Memory,GWAS=NULL ))

}
`GAPIT.Specify` <-
function(GI=NULL,GP=NULL,bin.size=10000000,inclosure.size=NULL,MaxBP=1e10){
    #Object: To get indicator (TURE or FALSE) for GI based on GP
    #Straitegy
    #       1.set bins for all snps in GP
    #       2.keep the snp with smallest P value in each bin, record SNP ID
    #       3.Search GI for SNP with SNP ID from above
    #       4.return the position for SNP selected
    #Input:
    #GI: Data frame with three columns (SNP name, chr and base position)
    #GP: Data frame with seven columns (SNP name, chr and base position, P, MAF,N,effect)
    #Output:
    #theIndex: a vector indicating if the SNPs in GI belong to QTN or not)
    #Authors: Zhiwu Zhang
    #Last update: September 24, 2011
    ##############################################################################################
    
    #print("Specification in process...")
    if(is.null(GP))return (list(index=NULL,BP=NULL))
    
    #set inclosure bin in GP
    
    #Create SNP ID: position+CHR*MaxBP
    ID.GP=as.numeric(as.vector(GP[,3]))+as.numeric(as.vector(GP[,2]))*MaxBP
    
    #Creat bin ID
    bin.GP=floor(ID.GP/bin.size )
    
    #Create a table with bin ID, SNP ID and p value (set 2nd and 3rd NA temporately)
    binP=as.matrix(cbind(bin.GP,NA,NA,ID.GP,as.numeric(as.vector(GP[,4])))  )
    n=nrow(binP)
    
    #Sort the table by p value and then bin ID (e.g. sort p within bin ID)
    binP=binP[order(as.numeric(as.vector(binP[,5]))),]  #sort on P alue
    binP=binP[order(as.numeric(as.vector(binP[,1]))),]  #sort on bin
    
    #set indicator (use 2nd 3rd columns)
    binP[2:n,2]=binP[1:(n-1),1]
    binP[1,2]=0 #set the first
    binP[,3]= binP[,1]-binP[,2]
    
    #Se representives of bins
    ID.GP=binP[binP[,3]>0,]
    
    
    #Choose the most influencial bins as estimated QTNs
    
    #Handler of single row
    if(is.null(dim(ID.GP))) ID.GP=matrix(ID.GP,1,length(ID.GP))
    
    ID.GP=ID.GP[order(as.numeric(as.vector(ID.GP[,5]))),]  #sort on P alue
    
    #Handler of single row (again after reshape)
    if(is.null(dim(ID.GP))) ID.GP=matrix(ID.GP,1,length(ID.GP))
    
    index=!is.na(ID.GP[,4])
    ID.GP=ID.GP[index,4] #must have chr and bp information, keep SNP ID only
    num_bins=NULL
    if(!is.null(inclosure.size)   ) {
        if(!is.na(inclosure.size)){
            avaiable=min(inclosure.size,length(ID.GP))
            #print("inclosure.size length(ID.GP) avaiable")
            #print(inclosure.size)
            #print(length(ID.GP))
			num_bins=length(ID.GP)   # create number of all bins
            #print(avaiable)
            if(avaiable==0){
                ID.GP=-1
            }else{
                ID.GP=ID.GP[1:avaiable] #keep the top ones selected
            }
            #print("ID.GP")
            #print(ID.GP)
            #problem here ID.GP[1:0]==ID.GP[1:1]
        }
    }
    
    #create index in GI
    theIndex=NULL
    if(!is.null(GI)){
        ID.GI=as.numeric(as.vector(GI[,3]))+as.numeric(as.vector(GI[,2]))*MaxBP
        #print("ID.GI")
        #print(ID.GI)
        theIndex=ID.GI %in% ID.GP
    }
    #print("Specification in process done")
    myList=list(index=theIndex,CB=ID.GP)

    return (list(index=theIndex,CB=ID.GP,num_bins=num_bins))
} #end of GAPIT.Specify
#=============================================================================================


`GAPIT.Table` <-
function(final.table = final.table, name.of.trait = name.of.trait,SNP.FDR=1){
#Object: Make and export a table of summary information from GWAS
#Output: A table summarizing GWAS results
#Authors: Alex Lipka and Zhiwu Zhang
# Last update: May 10, 2011 
##############################################################################################

#Filter SNPs by FDR
index=(final.table[,7]<=SNP.FDR)
final.table=final.table[index,]

#Export this summary table as an excel file
write.table(final.table, paste("GAPIT.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)


#print("GAPIT.Table accomplished successfully!")
  

}   #GAPIT.Table ends here
#=============================================================================================

`GAPIT.Timmer` <-
function(Timmer=NULL,Infor){
#Object: To report current time
#Output: Timmer
#Authors: Zhiwu Zhang
# Last update: may 8, 2011 
##############################################################################################
Time<- Sys.time()
if(is.null(Timmer)) {
Elapsed=0
Timmer=cbind(Infor,Time,Elapsed)
}else{
Elapsed=0
Timmer.current=cbind(Infor,Time,Elapsed)
Timmer=rbind(Timmer,Timmer.current)
Timmer[nrow(Timmer),3]=as.numeric(as.matrix(Timmer[nrow(Timmer),2]))-as.numeric(as.matrix(Timmer[nrow(Timmer)-1,2]))
}

#print(paste('Time used: ', Timmer[nrow(Timmer),3], ' seconds for ',Infor,sep="" )) 
return (Timmer)
}#end of GAPIT.Timmer function
#=============================================================================================

`GAPIT.ZmatrixCompress` <-
function(Z,GAU){
#Object: To assign the fraction of a individual belonging to a group
#Output: Z
#Authors: Zhiwu Zhang
# Last update: April 14, 2011 
##############################################################################################
#Extraction of GAU coresponding to Z, sort GAU rowwise to mach columns of Z, and make design matrix
#print("GAPIT.ZmatrixCompress")
#print(dim(Z))
#print(dim(GAU))

effect.Z=as.matrix(Z[1,-1])
effect.GAU=as.matrix(GAU[,1])
taxa=as.data.frame(Z[-1,1])

GAU0=GAU[effect.GAU%in%effect.Z,]
order.GAU=order(GAU0[,1])
GAU1 <- GAU0[order.GAU,]
#id.1=GAU1[which(GAU1[,3]==1),4]
id.1=GAU1[which(GAU1[,3]<2),4]
n=max(as.numeric(as.vector(id.1)))
x=as.numeric(as.matrix(GAU1[,4]))
DS=diag(n)[x,]

#sort Z column wise
order.Z=order(effect.Z)
Z=Z[-1,-1]
Z <- Z[,order.Z]

#Z matrix from individual to group
#Z1.numeric <- as.numeric(as.matrix(Z))
Z <- matrix(as.numeric(as.matrix(Z)), nrow = nrow(Z), ncol = ncol(Z)) 
Z=Z%*%DS

#Z3=data.frame(cbind(as.character(Z[-1,1]),Z2))
Z=data.frame(cbind(taxa,Z))

#Z=Z3[order(Z3[,1]),]

Z=Z[order(as.matrix(taxa)),]


#print("GAPIT.ZmatrixCompress accomplished successfully!")
return(list(Z=Z))
}#The function GAPIT.ZmatrixCompress ends here
#=============================================================================================

`GAPIT.ZmatrixFormation` <-
function(Z,Y){
#Object: To expande the proportion Z to final Z
#Output: Z
#Authors: Zhiwu Zhang 
# Last update: April 22, 2011 
##############################################################################################
#split individuals in Y to the ones that are given Z and the one not
taxa.Z=as.matrix(Z[-1,1])
taxa.Y=as.matrix(Y[,1])
taxa.diff=setdiff(taxa.Y,taxa.Z)
taxa.I=as.matrix(taxa.Y[match(taxa.diff,taxa.Y,nomatch = 0)])
taxa.Z.col=as.matrix(Z[1,-1])

#Create final Z with zero block and identity block
Z0=matrix(data=0,nrow=nrow(taxa.Z),ncol=nrow(taxa.I))
Z1=diag(1,nrow(taxa.I))
ZC=as.matrix(rbind(Z0,Z1))

#To label rows and columns
label.row=rbind(as.matrix(Z[,1]),taxa.I)
label.col=t(taxa.I)

#update the zero block by the given Z matrix
position=t(as.matrix(match(taxa.Z.col,taxa.I,nomatch = 0)))
ZC[1:nrow(taxa.Z),position]=as.matrix(Z[-1,-1])

#habdler of parents do not have phenotype (colums of Z are not in taxa.I)
# To do list

#To form final Z matrix
dataPart=rbind(label.col,ZC)
Z=data.frame(cbind(label.row,dataPart))

#print("GAPIT.ZmatrixFormation accomplished successfully!")
return(Z)
}#The function GAPIT.ZmatrixFormation ends here
#=============================================================================================

`GAPIT.cross_validation.compare` <-function(myGD=NULL,y=NULL, rel=NULL,tc=NULL){
# Object: GAPIT.cross validation compare to different folders by replicate Times,result:a pdf of the scree barplot and .cvs
# myGD:numeric SNP
# Y: phenotype with columns of taxa,Y1,Y2...
# rel:replications
# tc:comparation folds number and value
# Authors: You Tang,Jiabo Wang and You Zhou
# Last update: December 31, 2014 
##############################################################################################
if(is.null(myGD)||is.null(y)){stop("Validation Invalid. Please select read valid flies !")}
if(is.null(rel))
  {
	rel=10  #not input rel value,default replications number is 10
  }

if(rel<2){stop("Validation Invalid. Please select replications >1 !")}
#rel<-2 ##replications
#t<-2
y<-y[!is.na(y[,2]),] 
y<-y[,c(1,2)]
y<- na.omit(y)
#############
commonGeno <- unique(as.character(y[,1]))[unique(as.character(y[,1])) %in% myGD[,1]]
cG<-data.frame(commonGeno)
names(cG)<-"Taxa"
colnames(y)<-c("Taxa","pheno")
y2<-merge(y,cG,all.x=FALSE, all.y=TRUE, by = c("Taxa"))
Z1 <- myGD[match(y2$Taxa,myGD[,1]),]
myGD<- Z1
y<-y2
##############
X<-myGD[,-1]
k1<-as.matrix(X)
k2=GAPIT.kinship.VanRaden(snps=k1)
myKI<-as.data.frame(k2)
myKI<-cbind(myGD[,1],myKI)
write.table(y,"Y.txt",quote=F,sep="\t",row.names=F,col.names=T)
write.table(myKI,"K.txt",quote=F,row.names=F,col.names=F,sep="\t")
gc()
myK<- read.table("K.txt",head=F)
y= read.table("Y.txt",head=T)

y<- na.omit(y)
y=y[(y[,1] %in% myK[,1]),]
m=nrow(y)
if(is.null(tc))
	tc<-c(2,5,10,20,50)  ##default compare to folders num
tc1<-as.matrix(tc)
	allstorage.ref=matrix(0,rel,nrow(tc1))
	allstorage.inf=matrix(0,rel,nrow(tc1))
for(w in 1:nrow(tc1)){
num<-tc1[w,]
m.sample=floor(m/num)
	storage.ref=matrix(0,rel,num)
	storage.inf=matrix(0,rel,num)
	#storage.REML=matrix(0,rel,num)
for(k in 1:rel)
{
   #################Rand group method 1############
 sets=sample(cut(1:nrow(y),num,labels=FALSE),nrow(y))
 sets = as.data.frame(sets)
 ynew <- cbind(sets,y)

	#i=sample(1:num, size = 1)
for(i in 1:num){
	
	 #use only genotypes that were genotyped and phenotyped
    ref <- y$Taxa[!ynew$sets==i]
      
     lines.cali<- ref     
   # ycali<- y[match(ref,y$Taxa),]
    #use only genotypes that were genotyped and phenotyped

    test <- y$Taxa[ynew$sets==i]
    lines.vali<-test 
    #yvali<- y[match(test,y$Taxa),]  	
 
 #################end Rand group method############

	 #use only genotypes that were genotyped and phenotyped
	 commonGeno_v <- lines.vali[lines.vali %in% myK[,1]]	               
	 yvali<- y[match(commonGeno_v,y[,1]),]    

	 #use only genotypes that were genotyped and phenotyped
	 commonGeno_c <- lines.cali[lines.cali %in% myK[,1]]
	 ycali<- y[match(commonGeno_c,y[,1]),]               
	
	Y.raw=ycali[,c(1,2)]#choos a trait

	myY=Y.raw
	myKI=myK
	max.groups=m

#Run GAPIT
#############################################
	
	myGAPIT <- GAPIT(
	Y=myY,
	KI=myKI,
	#group.from=max.groups,
	group.from=max.groups,
	group.to=max.groups,
	#group.by=10,
	PCA.total=3,
	SNP.test=FALSE,
	file.output=FALSE
	)

prediction=myGAPIT$Pred

prediction.ref<-prediction[match(commonGeno_c,prediction$Taxa),]
prediction.inf<-prediction[match(commonGeno_v,prediction$Taxa),]

YP.ref <- merge(y, prediction.ref, by.x = 1, by.y = "Taxa")
YP.inf <- merge(y, prediction.inf, by.x = 1, by.y = "Taxa")

#Calculate correlation and store them
r.ref=cor(as.numeric(as.vector(YP.ref[,2])),as.numeric(as.vector(YP.ref[,6]) ))
r.inf=cor(as.numeric(as.vector(YP.inf[,2])),as.numeric(as.vector(YP.inf[,6]) ))

if(r.inf<0){
#r.inf=cor(as.numeric(as.vector(YP.inf[,2])),as.numeric(as.vector(YP.inf[,2]+YP.inf[,6])))
combine_output=cbind(as.numeric(as.vector(YP.inf[,2])),as.numeric(as.vector(YP.inf[,6]) ))

write.csv(combine_output, paste("Accuracy_folders",num,k,i,rel,".csv",sep=""))
#stop("...........")
}
storage.ref[k,i]=r.ref
storage.inf[k,i]=r.inf

print(paste(" rel= ", rel, " k= ",k," i= ",i,sep = ""))
}
print(paste("finish  replications k= ",k," folders= ",num,sep = ""))
}
#Find missing position-->0.0
index=is.na(storage.inf)
storage.inf[index]=0


allstorage.inf[,w]=as.matrix(rowMeans(storage.inf))
allstorage.ref[,w]=as.matrix(rowMeans(storage.ref))
#as.matrix(rowMeans(storage.ref))

##output rel times and accuracy for every folders 

combine_output=cbind(storage.inf,allstorage.inf[,w])
combine_output1=cbind(storage.ref,allstorage.ref[,w])
colnames(combine_output)=c(paste("folders",c(1:num),sep=""),"mean")
write.csv(combine_output, paste("Accuracy_folders",num,"by CMLM,rel_",rel,".csv",sep=""))
write.csv(combine_output1, paste("Accuracy_folders  ref",num,"by CMLM,rel_",rel,".csv",sep=""))

}	
sr<-nrow(tc1)
##output means accuracy by rel for every folders 
colnames(allstorage.inf)=c(paste(tc1[c(1:sr),]," folders",sep=""))
write.csv(allstorage.inf, paste("Accuracy_folders",nrow(tc1),"by CMLM,rel_",rel,".compare to means",".csv",sep=""))
write.csv(allstorage.ref, paste("Accuracy_folders  ref",nrow(tc1),"by CMLM,rel_",rel,".compare to means",".csv",sep=""))

	name.of.trait=noquote(names(Y.raw)[2])
#rrel=round(rel/2)
#ppp<-matrix(0,sr,2)
ppp<-matrix(0,sr,2)

#if(rrel!=1){
#	aarm<-colMeans(allstorage.inf[1:rrel,])
#	}else{
#	aarm<-allstorage.inf[1,]	
#	}
#aam<-colMeans(allstorage.inf)
aam<-allstorage.inf
aam<-data.frame(aam)
bbm<-allstorage.ref
bbm<-data.frame(bbm)
for(b in 1:sr){
#ppp[b,]<-as.matrix(c(aarm[b],aam[b]))
ppp[b,1]<-as.matrix(mean(aam[,b]))
#colnames(ppp)<-c(rrel,rel)
}
for(c in 1:sr){
ppp[c,2]<-as.matrix(mean(bbm[,c]))
}
ppp<-as.matrix(cbind(ppp,tc1))
#colnames(ppp)<-c(rel)
sj<-runif(1, 0, 1)
#name.of.trait="qqq"
pdf(paste("GAPIT.cross_validation ", name.of.trait,sj,".compare to different folders.", ".pdf", sep = ""),width = 4.5, height = 4,pointsize=9)
par(mar = c(5,6,5,3))
palette(c("blue","red",rainbow(2)))
plot(ppp[,3],ppp[,2],xaxt="n",ylim=c(0,1.04),xlim=c(min(tc1)-1,max(tc1)+1),bg="lightgray",xlab="Number of folds",ylab="Correlation",type="o",pch=1,col=1,cex=1.0,cex.lab=1.7, cex.axis=1.3, lwd=3,las=1,lty =2)
	axis(side=1,at=tc1,labels=tc1,cex.lab=1.7)
        lines(ppp[,1]~ppp[,3], lwd=3,type="o",pch=19,col=2,lty =1)
	legend("bottomright",horiz = FALSE,c("Reference","Inference"),pch = c(1,19), lty =c(2,1),col=c(1:2),lwd=2,cex=1.2,bty="n")
dev.off()
print(paste("GAPIT.cross validation ", name.of.trait,".compare to different folders.","successfully!" ,sep = ""))
return(list(allstorage.inf))
}#end GAPIT.cross validation compare to different folders by replicate Times
#=============================================================================================
emma.kinship <- function(snps, method="additive", use="all") {
  n0 <- sum(snps==0,na.rm=TRUE)
  nh <- sum(snps==0.5,na.rm=TRUE)                                                                                         
  n1 <- sum(snps==1,na.rm=TRUE)
  nNA <- sum(is.na(snps))

  stopifnot(n0+nh+n1+nNA == length(snps))

  if ( method == "dominant" ) {
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) > 0.5),nrow(snps),ncol(snps))
    snps[!is.na(snps) && (snps == 0.5)] <- flags[!is.na(snps) && (snps == 0.5)]
  }
  else if ( method == "recessive" ) {
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) < 0.5),nrow(snps),ncol(snps))
    snps[!is.na(snps) && (snps == 0.5)] <- flags[!is.na(snps) && (snps == 0.5)]
  }
  else if ( ( method == "additive" ) && ( nh > 0 ) ) {
    dsnps <- snps
    rsnps <- snps
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) > 0.5),nrow(snps),ncol(snps))
    dsnps[!is.na(snps) && (snps==0.5)] <- flags[is.na(snps) && (snps==0.5)]
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) < 0.5),nrow(snps),ncol(snps))
    rsnps[!is.na(snps) && (snps==0.5)] <- flags[is.na(snps) && (snps==0.5)]
    snps <- rbind(dsnps,rsnps)
  }

  if ( use == "all" ) {
    mafs <- matrix(rowMeans(snps,na.rm=TRUE),nrow(snps),ncol(snps))
    snps[is.na(snps)] <- mafs[is.na(snps)]
  }
  else if ( use == "complete.obs" ) {
    snps <- snps[rowSums(is.na(snps))==0,]
  }

  n <- ncol(snps)
  K <- matrix(nrow=n,ncol=n)
  diag(K) <- 1

  for(i in 1:(n-1)) {
    for(j in (i+1):n) {
      x <- snps[,i]*snps[,j] + (1-snps[,i])*(1-snps[,j])
      K[i,j] <- sum(x,na.rm=TRUE)/sum(!is.na(x))
      K[j,i] <- K[i,j]
    }
  }
  return(K)
}

emma.eigen.L <- function(Z,K,complete=TRUE) {
  if ( is.null(Z) ) {
    return(emma.eigen.L.wo.Z(K))
  }
  else {
    return(emma.eigen.L.w.Z(Z,K,complete))
  }
}

emma.eigen.L.wo.Z <- function(K) {
  eig <- eigen(K,symmetric=TRUE)
  return(list(values=eig$values,vectors=eig$vectors))
}

emma.eigen.L.w.Z <- function(Z,K,complete=TRUE) {
  if ( complete == FALSE ) {
    vids <- colSums(Z)>0
    Z <- Z[,vids]
    K <- K[vids,vids]
  }
  eig <- eigen(K%*%crossprod(Z,Z),symmetric=FALSE,EISPACK=TRUE)
  return(list(values=eig$values,vectors=qr.Q(qr(Z%*%eig$vectors),complete=TRUE)))
}

emma.eigen.R <- function(Z,K,X,complete=TRUE) {
  if ( is.null(Z) ) {
    return(emma.eigen.R.wo.Z(K,X))
  }
  else {
    return(emma.eigen.R.w.Z(Z,K,X,complete))
  }
}

emma.eigen.R.wo.Z <- function(K, X) {
  n <- nrow(X)
  q <- ncol(X)
  S <- diag(n)-X%*%solve(crossprod(X,X))%*%t(X)
  eig <- eigen(S%*%(K+diag(1,n))%*%S,symmetric=TRUE)
  stopifnot(!is.complex(eig$values))
  return(list(values=eig$values[1:(n-q)]-1,vectors=eig$vectors[,1:(n-q)]))
}

emma.eigen.R.w.Z <- function(Z, K, X, complete = TRUE) {
  if ( complete == FALSE ) {
    vids <-  colSums(Z) > 0
    Z <- Z[,vids]
    K <- K[vids,vids]
  }
  n <- nrow(Z)
  t <- ncol(Z)
  q <- ncol(X)
 

  
  SZ <- Z - X%*%solve(crossprod(X,X))%*%crossprod(X,Z)
  eig <- eigen(K%*%crossprod(Z,SZ),symmetric=FALSE,EISPACK=TRUE)
  if ( is.complex(eig$values) ) {
    eig$values <- Re(eig$values)
    eig$vectors <- Re(eig$vectors)    
  }
  qr.X <- qr.Q(qr(X))
  return(list(values=eig$values[1:(t-q)],
              vectors=qr.Q(qr(cbind(SZ%*%eig$vectors[,1:(t-q)],qr.X)),
                complete=TRUE)[,c(1:(t-q),(t+1):n)]))   
}

emma.delta.ML.LL.wo.Z <- function(logdelta, lambda, etas, xi) {
  n <- length(xi)
  delta <- exp(logdelta)
  return( 0.5*(n*(log(n/(2*pi))-1-log(sum((etas*etas)/(lambda+delta))))-sum(log(xi+delta))) )  
}

emma.delta.ML.LL.w.Z <- function(logdelta, lambda, etas.1, xi.1, n, etas.2.sq ) {
  t <- length(xi.1)
  delta <- exp(logdelta)
#  stopifnot(length(lambda) == length(etas.1))
  return( 0.5*(n*(log(n/(2*pi))-1-log(sum(etas.1*etas.1/(lambda+delta))+etas.2.sq/delta))-(sum(log(xi.1+delta))+(n-t)*logdelta)) )
}

emma.delta.ML.dLL.wo.Z <- function(logdelta, lambda, etas, xi) {
  n <- length(xi)
  delta <- exp(logdelta)
  etasq <- etas*etas
  ldelta <- lambda+delta
  return( 0.5*(n*sum(etasq/(ldelta*ldelta))/sum(etasq/ldelta)-sum(1/(xi+delta))) )
}

emma.delta.ML.dLL.w.Z <- function(logdelta, lambda, etas.1, xi.1, n, etas.2.sq ) {
  t <- length(xi.1)
  q <- t-length(lambda)
  delta <- exp(logdelta)
  etasq <- etas.1*etas.1
  ldelta <- lambda+delta
  return( 0.5*(n*(sum(etasq/(ldelta*ldelta))+etas.2.sq/(delta*delta))/(sum(etasq/ldelta)+etas.2.sq/delta)-(sum(1/(xi.1+delta))+(n-t)/delta) ) )
}

emma.delta.REML.LL.wo.Z <- function(logdelta, lambda, etas) {
  nq <- length(etas)
  delta <-  exp(logdelta)
  return( 0.5*(nq*(log(nq/(2*pi))-1-log(sum(etas*etas/(lambda+delta))))-sum(log(lambda+delta))) )
}

emma.delta.REML.LL.w.Z <- function(logdelta, lambda, etas.1, n, t, etas.2.sq ) {
  tq <- length(etas.1)
  nq <- n - t + tq
  delta <-  exp(logdelta)
  return( 0.5*(nq*(log(nq/(2*pi))-1-log(sum(etas.1*etas.1/(lambda+delta))+etas.2.sq/delta))-(sum(log(lambda+delta))+(n-t)*logdelta)) ) 
}

emma.delta.REML.dLL.wo.Z <- function(logdelta, lambda, etas) {
  nq <- length(etas)
  delta <- exp(logdelta)
  etasq <- etas*etas
  ldelta <- lambda+delta
  return( 0.5*(nq*sum(etasq/(ldelta*ldelta))/sum(etasq/ldelta)-sum(1/ldelta)) )
}

emma.delta.REML.dLL.w.Z <- function(logdelta, lambda, etas.1, n, t1, etas.2.sq ) {
  t <- t1
  tq <- length(etas.1)
  nq <- n - t + tq
  delta <- exp(logdelta)
  etasq <- etas.1*etas.1
  ldelta <- lambda+delta
  return( 0.5*(nq*(sum(etasq/(ldelta*ldelta))+etas.2.sq/(delta*delta))/(sum(etasq/ldelta)+etas.2.sq/delta)-(sum(1/ldelta)+(n-t)/delta)) )
}

emma.MLE <- function(y, X, K, Z=NULL, ngrids=100, llim=-10, ulim=10,
  esp=1e-10, eig.L = NULL, eig.R = NULL)
{
  n <- length(y)
  t <- nrow(K)
  q <- ncol(X)
  
#  stopifnot(nrow(K) == t)
  stopifnot(ncol(K) == t)
  stopifnot(nrow(X) == n)

  if ( det(crossprod(X,X)) == 0 ) {
    warning("X is singular")
    return (list(ML=0,delta=0,ve=0,vg=0))
  }

  if ( is.null(Z) ) {
    if ( is.null(eig.L) ) {
      eig.L <- emma.eigen.L.wo.Z(K)
    }
    if ( is.null(eig.R) ) {
      eig.R <- emma.eigen.R.wo.Z(K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
    
  
    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim
    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,n-q,m) + matrix(delta,n-q,m,byrow=TRUE)
    Xis <- matrix(eig.L$values,n,m) + matrix(delta,n,m,byrow=TRUE)
    Etasq <- matrix(etas*etas,n-q,m)
    LL <- 0.5*(n*(log(n/(2*pi))-1-log(colSums(Etasq/Lambdas)))-colSums(log(Xis)))
    dLL <- 0.5*delta*(n*colSums(Etasq/(Lambdas*Lambdas))/colSums(Etasq/Lambdas)-colSums(1/Xis))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if ( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.ML.LL.wo.Z(llim,eig.R$values,etas,eig.L$values))
    }
    if ( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.ML.LL.wo.Z(ulim,eig.R$values,etas,eig.L$values))
    }

    for( i in 1:(m-1) )
      {
        if ( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.ML.dLL.wo.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas=etas, xi=eig.L$values)
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.ML.LL.wo.Z(r$root,eig.R$values, etas, eig.L$values))
        }
      }
#    optdelta <- exp(optlogdelta)
  }
  else {
    if ( is.null(eig.L) ) {
      eig.L <- emma.eigen.L.w.Z(Z,K)
    }
    if ( is.null(eig.R) ) {
      eig.R <- emma.eigen.R.w.Z(Z,K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
    etas.1 <- etas[1:(t-q)]
    etas.2 <- etas[(t-q+1):(n-q)]
    etas.2.sq <- sum(etas.2*etas.2)

    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim

    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,t-q,m) + matrix(delta,t-q,m,byrow=TRUE)
    Xis <- matrix(eig.L$values,t,m) + matrix(delta,t,m,byrow=TRUE)
    Etasq <- matrix(etas.1*etas.1,t-q,m)
    #LL <- 0.5*(n*(log(n/(2*pi))-1-log(colSums(Etasq/Lambdas)+etas.2.sq/delta))-colSums(log(Xis))+(n-t)*log(deltas))
    dLL <- 0.5*delta*(n*(colSums(Etasq/(Lambdas*Lambdas))+etas.2.sq/(delta*delta))/(colSums(Etasq/Lambdas)+etas.2.sq/delta)-(colSums(1/Xis)+(n-t)/delta))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if ( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.ML.LL.w.Z(llim,eig.R$values,etas.1,eig.L$values,n,etas.2.sq))
    }
    if ( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.ML.LL.w.Z(ulim,eig.R$values,etas.1,eig.L$values,n,etas.2.sq))
    }

    for( i in 1:(m-1) )
      {
        if ( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.ML.dLL.w.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas.1=etas.1, xi.1=eig.L$values, n=n, etas.2.sq = etas.2.sq )
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.ML.LL.w.Z(r$root,eig.R$values, etas.1, eig.L$values, n, etas.2.sq ))
        }
      }
#    optdelta <- exp(optlogdelta)
  }
#print(optLL)
  maxdelta <- exp(optlogdelta[which.max(optLL)])
  maxLL <- max(optLL,na.rm=T)
  if ( is.null(Z) ) {
    maxva <- sum(etas*etas/(eig.R$values+maxdelta))/n    
  }
  else {
    maxva <- (sum(etas.1*etas.1/(eig.R$values+maxdelta))+etas.2.sq/maxdelta)/n
  }
  maxve <- maxva*maxdelta

  return (list(ML=maxLL,delta=maxdelta,ve=maxve,vg=maxva))
}

emma.REMLE <- function(y, X, K, Z=NULL, ngrids=100, llim=-10, ulim=10,
  esp=1e-10, eig.L = NULL, eig.R = NULL) {
  n <- length(y)
  t <- nrow(K)
  q <- ncol(X)

#  stopifnot(nrow(K) == t)
  stopifnot(ncol(K) == t)
  stopifnot(nrow(X) == n)

  if ( det(crossprod(X,X)) == 0 ) {
    warning("X is singular")
    return (list(REML=0,delta=0,ve=0,vg=0))
  }

  if ( is.null(Z) ) {
    if ( is.null(eig.R) ) {
      eig.R <- emma.eigen.R.wo.Z(K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
  
    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim
    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,n-q,m) + matrix(delta,n-q,m,byrow=TRUE)
    Etasq <- matrix(etas*etas,n-q,m)
    LL <- 0.5*((n-q)*(log((n-q)/(2*pi))-1-log(colSums(Etasq/Lambdas)))-colSums(log(Lambdas)))
    dLL <- 0.5*delta*((n-q)*colSums(Etasq/(Lambdas*Lambdas))/colSums(Etasq/Lambdas)-colSums(1/Lambdas))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if ( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.REML.LL.wo.Z(llim,eig.R$values,etas))
    }
    if ( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.REML.LL.wo.Z(ulim,eig.R$values,etas))
    }

    for( i in 1:(m-1) )
      {
        if ( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.REML.dLL.wo.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas=etas)
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.REML.LL.wo.Z(r$root,eig.R$values, etas))
        }
      }
#    optdelta <- exp(optlogdelta)
  }
  else {
    if ( is.null(eig.R) ) {
      eig.R <- emma.eigen.R.w.Z(Z,K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
    etas.1 <- etas[1:(t-q)]
    etas.2 <- etas[(t-q+1):(n-q)]
    etas.2.sq <- sum(etas.2*etas.2)
  
    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim
    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,t-q,m) + matrix(delta,t-q,m,byrow=TRUE)
    Etasq <- matrix(etas.1*etas.1,t-q,m)
    dLL <- 0.5*delta*((n-q)*(colSums(Etasq/(Lambdas*Lambdas))+etas.2.sq/(delta*delta))/(colSums(Etasq/Lambdas)+etas.2.sq/delta)-(colSums(1/Lambdas)+(n-t)/delta))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if ( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.REML.LL.w.Z(llim,eig.R$values,etas.1,n,t,etas.2.sq))
    }
    if ( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.REML.LL.w.Z(ulim,eig.R$values,etas.1,n,t,etas.2.sq))
    }

    for( i in 1:(m-1) )
      {
        if ( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.REML.dLL.w.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas.1=etas.1, n=n, t1=t, etas.2.sq = etas.2.sq )
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.REML.LL.w.Z(r$root,eig.R$values, etas.1, n, t, etas.2.sq ))
        }
      }
#    optdelta <- exp(optlogdelta)
  }  

  maxdelta <- exp(optlogdelta[which.max(optLL)])
  maxLL <- max(optLL)
  if ( is.null(Z) ) {
    maxva <- sum(etas*etas/(eig.R$values+maxdelta))/(n-q)    
  }
  else {
    maxva <- (sum(etas.1*etas.1/(eig.R$values+maxdelta))+etas.2.sq/maxdelta)/(n-q)
  }
  maxve <- maxva*maxdelta

  return (list(REML=maxLL,delta=maxdelta,ve=maxve,vg=maxva))
}

emma.ML.LRT <- function(ys, xs, K, Z=NULL, X0 = NULL, ngrids=100, llim=-10, ulim=10, esp=1e-10, ponly = FALSE) {
  if ( is.null(dim(ys)) || ncol(ys) == 1 ) {
    ys <- matrix(ys,1,length(ys))
  }
  if ( is.null(dim(xs)) || ncol(xs) == 1 ) {
    xs <- matrix(xs,1,length(xs))
  }
  if ( is.null(X0) ) {
    X0 <- matrix(1,ncol(ys),1)
  }  
  
  g <- nrow(ys)
  n <- ncol(ys)
  m <- nrow(xs)
  t <- ncol(xs)
  q0 <- ncol(X0)
  q1 <- q0 + 1

  if ( !ponly ) {
    ML1s <- matrix(nrow=m,ncol=g)
    ML0s <- matrix(nrow=m,ncol=g)
    vgs <- matrix(nrow=m,ncol=g)
    ves <- matrix(nrow=m,ncol=g)
  }
  stats <- matrix(nrow=m,ncol=g)
  ps <- matrix(nrow=m,ncol=g)
  ML0 <- vector(length=g)
  
  stopifnot(nrow(K) == t)
  stopifnot(ncol(K) == t)
  stopifnot(nrow(X0) == n)

  if ( sum(is.na(ys)) == 0 ) {
    eig.L <- emma.eigen.L(Z,K)
    eig.R0 <- emma.eigen.R(Z,K,X0)
      
    for(i in 1:g) {
      ML0[i] <- emma.MLE(ys[i,],X0,K,Z,ngrids,llim,ulim,esp,eig.L,eig.R0)$ML
    }

    x.prev <- vector(length=0)
    
    for(i in 1:m) {
      vids <- !is.na(xs[i,])
      nv <- sum(vids)
      xv <- xs[i,vids]

      if ( ( mean(xv) <= 0 ) || ( mean(xv) >= 1 ) ) {
        if (!ponly) {
          stats[i,] <- rep(NA,g)
          vgs[i,] <- rep(NA,g)
          ves[i,] <- rep(NA,g)
          ML1s[i,] <- rep(NA,g)
          ML0s[i,] <- rep(NA,g)
        }
        ps[i,] = rep(1,g)
      }
      else if ( identical(x.prev, xv) ) {
        if ( !ponly ) {
          stats[i,] <- stats[i-1,]
          vgs[i,] <- vgs[i-1,]
          ves[i,] <- ves[i-1,]
          ML1s[i,] <- ML1s[i-1,]
          ML0s[i,] <- ML0s[i-1,]
        }
        ps[i,] <- ps[i-1,]
      }
      else {
        if ( is.null(Z) ) {
          X <- cbind(X0[vids,,drop=FALSE],xs[i,vids])
          eig.R1 = emma.eigen.R.wo.Z(K[vids,vids],X)
        }
        else {
          vrows <- as.logical(rowSums(Z[,vids]))
          nr <- sum(vrows)
          X <- cbind(X0[vrows,,drop=FALSE],Z[vrows,vids]%*%t(xs[i,vids,drop=FALSE]))
          eig.R1 = emma.eigen.R.w.Z(Z[vrows,vids],K[vids,vids],X)          
        }

        for(j in 1:g) {
          if ( nv == t ) {
            MLE <- emma.MLE(ys[j,],X,K,Z,ngrids,llim,ulim,esp,eig.L,eig.R1)
#            MLE <- emma.MLE(ys[j,],X,K,Z,ngrids,llim,ulim,esp,eig.L,eig.R1)            
            if (!ponly) { 
              ML1s[i,j] <- MLE$ML
              vgs[i,j] <- MLE$vg
              ves[i,j] <- MLE$ve
            }
            stats[i,j] <- 2*(MLE$ML-ML0[j])
            
          }
          else {
            if ( is.null(Z) ) {
              eig.L0 <- emma.eigen.L.wo.Z(K[vids,vids])
              MLE0 <- emma.MLE(ys[j,vids],X0[vids,,drop=FALSE],K[vids,vids],NULL,ngrids,llim,ulim,esp,eig.L0)
              MLE1 <- emma.MLE(ys[j,vids],X,K[vids,vids],NULL,ngrids,llim,ulim,esp,eig.L0)
            }
            else {
              if ( nr == n ) {
                MLE1 <- emma.MLE(ys[j,],X,K,Z,ngrids,llim,ulim,esp,eig.L)
              }
              else {
                eig.L0 <- emma.eigen.L.w.Z(Z[vrows,vids],K[vids,vids])              
                MLE0 <- emma.MLE(ys[j,vrows],X0[vrows,,drop=FALSE],K[vids,vids],Z[vrows,vids],ngrids,llim,ulim,esp,eig.L0)
                MLE1 <- emma.MLE(ys[j,vrows],X,K[vids,vids],Z[vrows,vids],ngrids,llim,ulim,esp,eig.L0)
              }
            }
            if (!ponly) { 
              ML1s[i,j] <- MLE1$ML
              ML0s[i,j] <- MLE0$ML
              vgs[i,j] <- MLE1$vg
              ves[i,j] <- MLE1$ve
            }
            stats[i,j] <- 2*(MLE1$ML-MLE0$ML)
          }
        }
        if ( ( nv == t ) && ( !ponly ) ) {
          ML0s[i,] <- ML0
        }
        ps[i,] <- pchisq(stats[i,],1,lower.tail=FALSE)
      }
    }
  }
  else {
    eig.L <- emma.eigen.L(Z,K)
    eig.R0 <- emma.eigen.R(Z,K,X0)
      
    for(i in 1:g) {
      vrows <- !is.na(ys[i,])      
      if ( is.null(Z) ) {
        ML0[i] <- emma.MLE(ys[i,vrows],X0[vrows,,drop=FALSE],K[vrows,vrows],NULL,ngrids,llim,ulim,esp)$ML
      }
      else {
        vids <- colSums(Z[vrows,]>0)
            
        ML0[i] <- emma.MLE(ys[i,vrows],X0[vrows,,drop=FALSE],K[vids,vids],Z[vrows,vids],ngrids,llim,ulim,esp)$ML        
      }
    }

    x.prev <- vector(length=0)
    
    for(i in 1:m) {
      vids <- !is.na(xs[i,])
      nv <- sum(vids)
      xv <- xs[i,vids]

      if ( ( mean(xv) <= 0 ) || ( mean(xv) >= 1 ) ) {
        if (!ponly) {
          stats[i,] <- rep(NA,g)
          vgs[i,] <- rep(NA,g)
          ves[i,] <- rep(NA,g)
          ML1s[i,] <- rep(NA,g)
          ML0s[,i] <- rep(NA,g)
        }
        ps[i,] = rep(1,g)
      }      
      else if ( identical(x.prev, xv) ) {
        if ( !ponly ) {
          stats[i,] <- stats[i-1,]
          vgs[i,] <- vgs[i-1,]
          ves[i,] <- ves[i-1,]
          ML1s[i,] <- ML1s[i-1,]
        }
        ps[i,] = ps[i-1,]
      }
      else {
        if ( is.null(Z) ) {
          X <- cbind(X0,xs[i,])
          if ( nv == t ) {
            eig.R1 = emma.eigen.R.wo.Z(K,X)
          }          
        }
        else {
          vrows <- as.logical(rowSums(Z[,vids]))
          X <- cbind(X0,Z[,vids,drop=FALSE]%*%t(xs[i,vids,drop=FALSE]))
          if ( nv == t ) {
            eig.R1 = emma.eigen.R.w.Z(Z,K,X)
          }
        }

        for(j in 1:g) {
#          print(j)
          vrows <- !is.na(ys[j,])
          if ( nv == t ) {
            nr <- sum(vrows)
            if ( is.null(Z) ) {
              if ( nr == n ) {
                MLE <- emma.MLE(ys[j,],X,K,NULL,ngrids,llim,ulim,esp,eig.L,eig.R1)                
              }
              else {
                MLE <- emma.MLE(ys[j,vrows],X[vrows,],K[vrows,vrows],NULL,ngrids,llim,ulim,esp)
              }
            }
            else {
              if ( nr == n ) {
                MLE <- emma.MLE(ys[j,],X,K,Z,ngrids,llim,ulim,esp,eig.L,eig.R1)                
              }
              else {
                vtids <- as.logical(colSums(Z[vrows,,drop=FALSE]))
                MLE <- emma.MLE(ys[j,vrows],X[vrows,],K[vtids,vtids],Z[vrows,vtids],ngrids,llim,ulim,esp)
              }
            }
            
            if (!ponly) { 
              ML1s[i,j] <- MLE$ML
              vgs[i,j] <- MLE$vg
              ves[i,j] <- MLE$ve
            }
            stats[i,j] <- 2*(MLE$ML-ML0[j])
          }
          else {
            if ( is.null(Z) ) {
              vtids <- vrows & vids
              eig.L0 <- emma.eigen.L(NULL,K[vtids,vtids])
              MLE0 <- emma.MLE(ys[j,vtids],X0[vtids,,drop=FALSE],K[vtids,vtids],NULL,ngrids,llim,ulim,esp,eig.L0)
              MLE1 <- emma.MLE(ys[j,vtids],X[vtids,],K[vtids,vtids],NULL,ngrids,llim,ulim,esp,eig.L0)
            }
            else {
              vtids <- as.logical(colSums(Z[vrows,])) & vids
              vtrows <- vrows & as.logical(rowSums(Z[,vids]))
              eig.L0 <- emma.eigen.L(Z[vtrows,vtids],K[vtids,vtids])
              MLE0 <- emma.MLE(ys[j,vtrows],X0[vtrows,,drop=FALSE],K[vtids,vtids],Z[vtrows,vtids],ngrids,llim,ulim,esp,eig.L0)
              MLE1 <- emma.MLE(ys[j,vtrows],X[vtrows,],K[vtids,vtids],Z[vtrows,vtids],ngrids,llim,ulim,esp,eig.L0)
            }
            if (!ponly) { 
              ML1s[i,j] <- MLE1$ML
              vgs[i,j] <- MLE1$vg
              ves[i,j] <- MLE1$ve
              ML0s[i,j] <- MLE0$ML
            }
            stats[i,j] <- 2*(MLE1$ML-MLE0$ML)
          }
        }
        if ( ( nv == t ) && ( !ponly ) ) {
          ML0s[i,] <- ML0
        }
        ps[i,] <- pchisq(stats[i,],1,lower.tail=FALSE)
      }
    }    
  }
  if ( ponly ) {
    return (ps)
  }
  else {
    return (list(ps=ps,ML1s=ML1s,ML0s=ML0s,stats=stats,vgs=vgs,ves=ves))
  }  
}

emma.REML.t <- function(ys, xs, K, Z=NULL, X0 = NULL, ngrids=100, llim=-10, ulim=10, esp=1e-10, ponly = FALSE) {
  if ( is.null(dim(ys)) || ncol(ys) == 1 ) {
    ys <- matrix(ys,1,length(ys))
  }
  if ( is.null(dim(xs)) || ncol(xs) == 1 ) {
    xs <- matrix(xs,1,length(xs))
  }
  if ( is.null(X0) ) {
    X0 <- matrix(1,ncol(ys),1)
  }
  
  g <- nrow(ys)
  n <- ncol(ys)
  m <- nrow(xs)
  t <- ncol(xs)
  q0 <- ncol(X0)
  q1 <- q0 + 1
  
  stopifnot(nrow(K) == t)
  stopifnot(ncol(K) == t)
  stopifnot(nrow(X0) == n)

  if ( !ponly ) {
    REMLs <- matrix(nrow=m,ncol=g)
    vgs <- matrix(nrow=m,ncol=g)
    ves <- matrix(nrow=m,ncol=g)
  }
  dfs <- matrix(nrow=m,ncol=g)
  stats <- matrix(nrow=m,ncol=g)
  ps <- matrix(nrow=m,ncol=g)

  if ( sum(is.na(ys)) == 0 ) {
    eig.L <- emma.eigen.L(Z,K)

    x.prev <- vector(length=0)

    for(i in 1:m) {
      vids <- !is.na(xs[i,])
      nv <- sum(vids)
      xv <- xs[i,vids]

      if ( ( mean(xv) <= 0 ) || ( mean(xv) >= 1 ) ) {
        if ( !ponly ) {
          vgs[i,] <- rep(NA,g)
          ves[i,] <- rep(NA,g)
          dfs[i,] <- rep(NA,g)
          REMLs[i,] <- rep(NA,g)
          stats[i,] <- rep(NA,g)
        }
        ps[i,] = rep(1,g)
        
      }
      else if ( identical(x.prev, xv) ) {
        if ( !ponly ) {
          vgs[i,] <- vgs[i-1,]
          ves[i,] <- ves[i-1,]
          dfs[i,] <- dfs[i-1,]
          REMLs[i,] <- REMLs[i-1,]
          stats[i,] <- stats[i-1,]
        }
        ps[i,] <- ps[i-1,]
      }
      else {
        if ( is.null(Z) ) {
          X <- cbind(X0[vids,,drop=FALSE],xs[i,vids])
          eig.R1 = emma.eigen.R.wo.Z(K[vids,vids],X)
        }
        else {
          vrows <- as.logical(rowSums(Z[,vids]))              
          X <- cbind(X0[vrows,,drop=FALSE],Z[vrows,vids,drop=FALSE]%*%t(xs[i,vids,drop=FALSE]))
          eig.R1 = emma.eigen.R.w.Z(Z[vrows,vids],K[vids,vids],X)
        }
        
        for(j in 1:g) {
          if ( nv == t ) {
            REMLE <- emma.REMLE(ys[j,],X,K,Z,ngrids,llim,ulim,esp,eig.R1)
            if ( is.null(Z) ) {
              U <- eig.L$vectors * matrix(sqrt(1/(eig.L$values+REMLE$delta)),t,t,byrow=TRUE)
              dfs[i,j] <- nv - q1
            }
            else {
              U <- eig.L$vectors * matrix(c(sqrt(1/(eig.L$values+REMLE$delta)),rep(sqrt(1/REMLE$delta),n-t)),n,n,byrow=TRUE)
              dfs[i,j] <- n - q1
            }
            yt <- crossprod(U,ys[j,])
            Xt <- crossprod(U,X)
            iXX <- solve(crossprod(Xt,Xt))
            beta <- iXX%*%crossprod(Xt,yt)
            
            if ( !ponly ) {
              vgs[i,j] <- REMLE$vg
              ves[i,j] <- REMLE$ve
              REMLs[i,j] <- REMLE$REML
            }
            stats[i,j] <- beta[q1]/sqrt(iXX[q1,q1]*REMLE$vg)
          }
          else {
            if ( is.null(Z) ) {
              eig.L0 <- emma.eigen.L.wo.Z(K[vids,vids])
              nr <- sum(vids)
              yv <- ys[j,vids]
              REMLE <- emma.REMLE(yv,X,K[vids,vids,drop=FALSE],NULL,ngrids,llim,ulim,esp,eig.R1)
              U <- eig.L0$vectors * matrix(sqrt(1/(eig.L0$values+REMLE$delta)),nr,nr,byrow=TRUE)
              dfs[i,j] <- nr - q1
            }
            else {
              eig.L0 <- emma.eigen.L.w.Z(Z[vrows,vids,drop=FALSE],K[vids,vids])              
              yv <- ys[j,vrows]
              nr <- sum(vrows)
              tv <- sum(vids)
              REMLE <- emma.REMLE(yv,X,K[vids,vids,drop=FALSE],Z[vrows,vids,drop=FALSE],ngrids,llim,ulim,esp,eig.R1)
              U <- eig.L0$vectors * matrix(c(sqrt(1/(eig.L0$values+REMLE$delta)),rep(sqrt(1/REMLE$delta),nr-tv)),nr,nr,byrow=TRUE)
              dfs[i,j] <- nr - q1
            }
            yt <- crossprod(U,yv)
            Xt <- crossprod(U,X)
            iXX <- solve(crossprod(Xt,Xt))
            beta <- iXX%*%crossprod(Xt,yt)
            if (!ponly) {
              vgs[i,j] <- REMLE$vg
              ves[i,j] <- REMLE$ve
              REMLs[i,j] <- REMLE$REML
            }
            stats[i,j] <- beta[q1]/sqrt(iXX[q1,q1]*REMLE$vg)
          }
        }
        ps[i,] <- 2*pt(abs(stats[i,]),dfs[i,],lower.tail=FALSE)
      }
    }
  }
  else {
    eig.L <- emma.eigen.L(Z,K)
    eig.R0 <- emma.eigen.R(Z,K,X0)
      
    x.prev <- vector(length=0)
    
    for(i in 1:m) {
      vids <- !is.na(xs[i,])
      nv <- sum(vids)
      xv <- xs[i,vids]

      if ( ( mean(xv) <= 0 ) || ( mean(xv) >= 1 ) ) {
        if (!ponly) {
          vgs[i,] <- rep(NA,g)
          ves[i,] <- rep(NA,g)
          REMLs[i,] <- rep(NA,g)
          dfs[i,] <- rep(NA,g)
        }
        ps[i,] = rep(1,g)
      }      
      else if ( identical(x.prev, xv) ) {
        if ( !ponly ) {
          stats[i,] <- stats[i-1,]
          vgs[i,] <- vgs[i-1,]
          ves[i,] <- ves[i-1,]
          REMLs[i,] <- REMLs[i-1,]
          dfs[i,] <- dfs[i-1,]
        }
        ps[i,] = ps[i-1,]
      }
      else {
        if ( is.null(Z) ) {
          X <- cbind(X0,xs[i,])
          if ( nv == t ) {
            eig.R1 = emma.eigen.R.wo.Z(K,X)
          }
        }
        else {
          vrows <- as.logical(rowSums(Z[,vids,drop=FALSE]))
          X <- cbind(X0,Z[,vids,drop=FALSE]%*%t(xs[i,vids,drop=FALSE]))
          if ( nv == t ) {
            eig.R1 = emma.eigen.R.w.Z(Z,K,X)
          }          
        }

        for(j in 1:g) {
          vrows <- !is.na(ys[j,])
          if ( nv == t ) {
            yv <- ys[j,vrows]
            nr <- sum(vrows)
            if ( is.null(Z) ) {
              if ( nr == n ) {
                REMLE <- emma.REMLE(yv,X,K,NULL,ngrids,llim,ulim,esp,eig.R1)
                U <- eig.L$vectors * matrix(sqrt(1/(eig.L$values+REMLE$delta)),n,n,byrow=TRUE)                
              }
              else {
                eig.L0 <- emma.eigen.L.wo.Z(K[vrows,vrows,drop=FALSE])
                REMLE <- emma.REMLE(yv,X[vrows,,drop=FALSE],K[vrows,vrows,drop=FALSE],NULL,ngrids,llim,ulim,esp)
                U <- eig.L0$vectors * matrix(sqrt(1/(eig.L0$values+REMLE$delta)),nr,nr,byrow=TRUE)
              }
              dfs[i,j] <- nr-q1
            }
            else {
              if ( nr == n ) {
                REMLE <- emma.REMLE(yv,X,K,Z,ngrids,llim,ulim,esp,eig.R1)
                U <- eig.L$vectors * matrix(c(sqrt(1/(eig.L$values+REMLE$delta)),rep(sqrt(1/REMLE$delta),n-t)),n,n,byrow=TRUE)                
              }
              else {
                vtids <- as.logical(colSums(Z[vrows,,drop=FALSE]))
                eig.L0 <- emma.eigen.L.w.Z(Z[vrows,vtids,drop=FALSE],K[vtids,vtids,drop=FALSE])
                REMLE <- emma.REMLE(yv,X[vrows,,drop=FALSE],K[vtids,vtids,drop=FALSE],Z[vrows,vtids,drop=FALSE],ngrids,llim,ulim,esp)
                U <- eig.L0$vectors * matrix(c(sqrt(1/(eig.L0$values+REMLE$delta)),rep(sqrt(1/REMLE$delta),nr-sum(vtids))),nr,nr,byrow=TRUE)
              }
              dfs[i,j] <- nr-q1
            }

            yt <- crossprod(U,yv)
            Xt <- crossprod(U,X[vrows,,drop=FALSE])
            iXX <- solve(crossprod(Xt,Xt))
            beta <- iXX%*%crossprod(Xt,yt)
            if ( !ponly ) {
              vgs[i,j] <- REMLE$vg
              ves[i,j] <- REMLE$ve
              REMLs[i,j] <- REMLE$REML
            }
            stats[i,j] <- beta[q1]/sqrt(iXX[q1,q1]*REMLE$vg)
          }
          else {
            if ( is.null(Z) ) {
              vtids <- vrows & vids
              eig.L0 <- emma.eigen.L.wo.Z(K[vtids,vtids,drop=FALSE])
              yv <- ys[j,vtids]
              nr <- sum(vtids)
              REMLE <- emma.REMLE(yv,X[vtids,,drop=FALSE],K[vtids,vtids,drop=FALSE],NULL,ngrids,llim,ulim,esp)
              U <- eig.L0$vectors * matrix(sqrt(1/(eig.L0$values+REMLE$delta)),nr,nr,byrow=TRUE)
              Xt <- crossprod(U,X[vtids,,drop=FALSE])
              dfs[i,j] <- nr-q1
            }
            else {
              vtids <- as.logical(colSums(Z[vrows,,drop=FALSE])) & vids
              vtrows <- vrows & as.logical(rowSums(Z[,vids,drop=FALSE]))
              eig.L0 <- emma.eigen.L.w.Z(Z[vtrows,vtids,drop=FALSE],K[vtids,vtids,drop=FALSE])
              yv <- ys[j,vtrows]
              nr <- sum(vtrows)
              REMLE <- emma.REMLE(yv,X[vtrows,,drop=FALSE],K[vtids,vtids,drop=FALSE],Z[vtrows,vtids,drop=FALSE],ngrids,llim,ulim,esp)
              U <- eig.L0$vectors * matrix(c(sqrt(1/(eig.L0$values+REMLE$delta)),rep(sqrt(1/REMLE$delta),nr-sum(vtids))),nr,nr,byrow=TRUE)
              Xt <- crossprod(U,X[vtrows,,drop=FALSE])
              dfs[i,j] <- nr-q1
            }
            yt <- crossprod(U,yv)
            iXX <- solve(crossprod(Xt,Xt))
            beta <- iXX%*%crossprod(Xt,yt)
            if ( !ponly ) {
              vgs[i,j] <- REMLE$vg
              ves[i,j] <- REMLE$ve
              REMLs[i,j] <- REMLE$REML
            }
            stats[i,j] <- beta[q1]/sqrt(iXX[q1,q1]*REMLE$vg)
            
          }
        }
        ps[i,] <- 2*pt(abs(stats[i,]),dfs[i,],lower.tail=FALSE)        
      }
    }    
  }
  if ( ponly ) {
    return (ps)
  }
  else {
    return (list(ps=ps,REMLs=REMLs,stats=stats,dfs=dfs,vgs=vgs,ves=ves))
  }
}

`GAPIT.emma.REMLE` <-
function(y, X, K, Z=NULL, ngrids=100, llim=-10, ulim=10,
              esp=1e-10, eig.L = NULL, eig.R = NULL) {
# Authors: Hyun Min Kang
# Modified (only one line) by Zhiwu Zhang to handle non-defined LL ("NaN") by replacing it with the worst LL.
# Last update: June 8, 2011 
##############################################################################################
  n <- length(y)
  t <- nrow(K)
  q <- ncol(X)

#  stopifnot(nrow(K) == t)
  stopifnot(ncol(K) == t)
  stopifnot(nrow(X) == n)

  if( det(crossprod(X,X)) == 0 ) {
    warning("X is singular")
    return (list(REML=0,delta=0,ve=0,vg=0))
  }

  if(is.null(Z) ) {
    if(is.null(eig.R) ) {
      eig.R <- emma.eigen.R.wo.Z(K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
  
    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim
    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,n-q,m) + matrix(delta,n-q,m,byrow=TRUE)
    Etasq <- matrix(etas*etas,n-q,m)
    LL <- 0.5*((n-q)*(log((n-q)/(2*pi))-1-log(colSums(Etasq/Lambdas)))-colSums(log(Lambdas)))
    dLL <- 0.5*delta*((n-q)*colSums(Etasq/(Lambdas*Lambdas))/colSums(Etasq/Lambdas)-colSums(1/Lambdas))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.REML.LL.wo.Z(llim,eig.R$values,etas))
    }
    if( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.REML.LL.wo.Z(ulim,eig.R$values,etas))
    }

    for(i in 1:(m-1) )
      {
        if( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.REML.dLL.wo.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas=etas)
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.REML.LL.wo.Z(r$root,eig.R$values, etas))
        }
      }
#    optdelta <- exp(optlogdelta)
  }
  else {
    if(is.null(eig.R) ) {
      eig.R <- emma.eigen.R.w.Z(Z,K,X)
    }
    etas <- crossprod(eig.R$vectors,y)
    etas.1 <- etas[1:(t-q)]
    etas.2 <- etas[(t-q+1):(n-q)]
    etas.2.sq <- sum(etas.2*etas.2)
  
    logdelta <- (0:ngrids)/ngrids*(ulim-llim)+llim
    m <- length(logdelta)
    delta <- exp(logdelta)
    Lambdas <- matrix(eig.R$values,t-q,m) + matrix(delta,t-q,m,byrow=TRUE)
    Etasq <- matrix(etas.1*etas.1,t-q,m)
    dLL <- 0.5*delta*((n-q)*(colSums(Etasq/(Lambdas*Lambdas))+etas.2.sq/(delta*delta))/(colSums(Etasq/Lambdas)+etas.2.sq/delta)-(colSums(1/Lambdas)+(n-t)/delta))
    
    optlogdelta <- vector(length=0)
    optLL <- vector(length=0)
    if( dLL[1] < esp ) {
      optlogdelta <- append(optlogdelta, llim)
      optLL <- append(optLL, emma.delta.REML.LL.w.Z(llim,eig.R$values,etas.1,n,t,etas.2.sq))
    }
    if( dLL[m-1] > 0-esp ) {
      optlogdelta <- append(optlogdelta, ulim)
      optLL <- append(optLL, emma.delta.REML.LL.w.Z(ulim,eig.R$values,etas.1,n,t,etas.2.sq))
    }

    for(i in 1:(m-1) )
      {
        if( ( dLL[i]*dLL[i+1] < 0 ) && ( dLL[i] > 0 ) && ( dLL[i+1] < 0 ) ) 
        {
          r <- uniroot(emma.delta.REML.dLL.w.Z, lower=logdelta[i], upper=logdelta[i+1], lambda=eig.R$values, etas.1=etas.1, n=n, t1=t, etas.2.sq = etas.2.sq )
          optlogdelta <- append(optlogdelta, r$root)
          optLL <- append(optLL, emma.delta.REML.LL.w.Z(r$root,eig.R$values, etas.1, n, t, etas.2.sq ))
        }
      }
#    optdelta <- exp(optlogdelta)
  }
  
  maxdelta <- exp(optlogdelta[which.max(optLL)])
  
  #handler of grids with NaN log
  optLL=GAPIT.replaceNaN(optLL)   
  
  maxLL <- max(optLL)
  if(is.null(Z) ) {
    maxva <- sum(etas*etas/(eig.R$values+maxdelta))/(n-q)    
  }
  else {
    maxva <- (sum(etas.1*etas.1/(eig.R$values+maxdelta))+etas.2.sq/maxdelta)/(n-q)
  }
  maxve <- maxva*maxdelta

  return (list(REML=maxLL,delta=maxdelta,ve=maxve,vg=maxva))
}
#=============================================================================================

`GAPIT.get.LL` <-
cmpfun(function(pheno,geno=NULL,snp.pool,X0=NULL){
    # evaluation of the maximum likelihood
    #Input: ys, xs, vg, delta, Z, X0, snp.pool
    #Output: LL
    #Authors: Qishan Wang, Feng Tian and Zhiwu Zhang
    #Last update: April 16, 2012
    ################################################################################
    #print("GAPIT.get.LL started")
    #print("dimension of pheno, snpool and X0")
    #print(dim(pheno))
    #print(length(pheno))
    #print(dim(snp.pool))
    #print(length(snp.pool))
    #print(dim(X0))
    #print(length(X0))
    
    y=pheno
    p=0
    deltaExpStart = -5
    deltaExpEnd = 5
    snp.pool=snp.pool[,]
    if(!is.null(snp.pool)&&var(snp.pool)==0){
        deltaExpStart = 100
        deltaExpEnd = deltaExpStart
        #print("deltaExp change here")
    }
    if(is.null(X0)) {
        X0 = matrix(1, nrow(snp.pool), 1)
    }
    #snp.test=as.numeric(geno[,1])
    #X <- cbind(X0, snp.test)
    X=X0
    
    #########SVD of X
    K.X.svd= svd(snp.pool,LINPACK=TRUE)######rivised by Jiabo Wang 2016.1.8
    # snp.pool=NA problem occurred
    #####rivised 2012.4.15 by qishan wang
    d=K.X.svd$d
    d=d[d>1e-08]
    d=d^2
    U1=K.X.svd$u
    U1=U1[,1:length(d)] ##rivised 2012.4.15 by qishan wang
    
    #handler of single snp
    if(is.null(dim(U1))) U1=matrix(U1,ncol=1)

    
    ###################
    n=nrow(U1)
    #I= diag(1,nrow(U1)) #xiaolei removed, this costs lots of memory
    
    U1TX=crossprod(U1,X)
    U1TY=crossprod(U1,y)
    yU1TY<- y-U1%*%U1TY
    XU1TX<- X-U1%*%U1TX  ### i is out of bracket
    #xiaolei rewrite following 4 lines
    IU = -tcrossprod(U1,U1)
    diag(IU) = rep(1,n) + diag(IU)
    #IUU=(I-tcrossprod(U1,U1))
    IUX=crossprod(IU,X )
    IUY=crossprod(IU,y)
    
    #Iteration on the range of delta (-5 to 5 in glog scale)
    for (m in seq(deltaExpStart,deltaExpEnd,by=0.1))
    {
        p=p+1
        delta<- exp(m)
        
        #----------------------------calculate beta-------------------------------------
        #######get beta compnents 1
        beta1=0
        for(i in 1:length(d)){
            one=matrix(U1TX[i,], nrow=1)
            beta=crossprod(one,(one/(d[i]+delta)))  #This is not real beta, confusing
            beta1= beta1+beta
        }
        
        #######get beta components 2
        beta2=0
        for(i in 1:nrow(U1)){
            one=matrix(IUX[i,], nrow=1)
            dim(one)
            beta=crossprod(one,one)
            beta2= beta2+beta
        }
        beta2<-beta2/delta
        
        #######get b3
        beta3=0
        for(i in 1:length(d)){
            one1=matrix(U1TX[i,], nrow=1)
            one2=matrix(U1TY[i,], nrow=1)
            beta=crossprod(one1,(one2/(d[i]+delta)))  #This is not real beta, confusing
            beta3= beta3+beta
        }
        
        ###########get beta4
        beta4=0
        for(i in 1:nrow(U1)){
            one1=matrix(IUX[i,], nrow=1)
            one2=matrix(IUY[i,], nrow=1)
            beta=crossprod(one1,one2)       #This is not real beta, confusing
            beta4= beta4+beta
        }
        beta4<-beta4/delta
        
        #######get final beta
        #zw1=solve(beta1+beta2)
        zw1 <- try(solve(beta1+beta2),silent=TRUE)
        if(inherits(zw1, "try-error")){
            zw1 <- ginv(beta1+beta2)
        }
        
        #zw1=ginv(beta1+beta2)
        zw2=(beta3+beta4)
        beta=crossprod(zw1,zw2)  #This is the real beta
        
        #----------------------------calculate LL---------------------------------------
        ####part 1
        part11<-n*log(2*3.14)
        part12<-0
        for(i in 1:length(d)){
            part12_pre=log(d[i]+delta)
            part12= part12+part12_pre
        }
        part13<- (nrow(U1)-length(d))*log(delta)
        part1<- -1/2*(part11+part12+part13)
        
        ######  part2
        part21<-nrow(U1)
        ######part221
        
        part221=0
        for(i in 1:length(d)){
            one1=matrix(U1TX[i,], nrow=1)
            one2=matrix(U1TY[i,], nrow=1)
            part221_pre=(one2-one1%*%beta)^2/(d[i]+delta) ###### beta contain covariate and snp %*%
            part221= part221+part221_pre
        }
        
        ######part222
        part222=0
        
        for(i in 1:n){
            one1=matrix(XU1TX[i,], nrow=1)
            one2=matrix(yU1TY[i,], nrow=1)
            part222_pre=((one2-one1%*%beta)^2)/delta
            part222= part222+part222_pre
        }
        part22<-n*log((1/n)*(part221+part222))
        part2<- -1/2*(part21+part22)
        
        ################# likihood
        LL<-part1+part2
        part1<-0
        part2<-0
        
        #-----------------------Save the optimum---------------------------------------
        if(p==1){
            beta.save=beta
            delta.save=delta
            LL.save=LL
        }else{
            if(LL>LL.save){
                beta.save=beta
                delta.save=delta
                LL.save=LL
            }
        }
        
    } # end of Iteration on the range of delta (-5 to 5 in glog scale)
    
    #--------------------update with the optimum------------------------------------
    beta=beta.save
    delta=delta.save
    LL=LL.save
    names(delta)=NULL
    names(LL)=NULL
    
    #--------------------calculating Va and Vem-------------------------------------
    #sigma_a1
    #U1TX=crossprod(U1,X)#xiaolei removed, it is re-calculated
    #U1TY=crossprod(U1,y)#xiaolei removed, it is re-calculated
    sigma_a1=0
    for(i in 1:length(d)){
        one1=matrix(U1TX[i,], nrow=1)
        one2=matrix(U1TY[i,], nrow=1)
        sigma_a1_pre=(one2-one1%*%beta)^2/(d[i]+delta)
        sigma_a1= sigma_a1+sigma_a1_pre
    }
    
    ### sigma_a2
    #xiaolei removed following 3 lines
    #IU=I-tcrossprod(U1,U1)    #This needs to be done only once
    #IUX=crossprod(IU,X)
    #IUY=crossprod(IU,y)
    sigma_a2=0
    
    for(i in 1:nrow(U1)){
        one1=matrix(IUX[i,], nrow=1)
        one2=matrix(IUY[i,], nrow=1)
        sigma_a2_pre<-(one2-one1%*%beta)^2
        sigma_a2= sigma_a2+sigma_a2_pre
    }
    
    sigma_a2<-sigma_a2/delta
    sigma_a<- 1/n*(sigma_a1+sigma_a2)
    sigma_e<-delta*sigma_a
    
    return(list(beta=beta, delta=delta, LL=LL, vg=sigma_a,ve=sigma_e))
}
)#end of cmpfun(
#=============================================================================================

`GAPIT.kinship.VanRaden` <-
function(snps,hasInbred=TRUE) {
# Object: To calculate the kinship matrix using the method of VanRaden (2009, J. Dairy Sci. 91:4414???C4423)
# Input: snps is n individual rows by m snps columns
# Output: n by n relationship matrix
# Authors: Zhwiu Zhang
# Last update: March 2, 2016 
############################################################################################## 
print("Calculating kinship with VanRaden method...")
#Remove invariants
fa=colSums(snps)/(2*nrow(snps))
index.non=fa>=1| fa<=0
snps=snps[,!index.non]

nSNP=ncol(snps)
nInd=nrow(snps)
n=nInd 

##allele frequency of second allele
p=colSums(snps)/(2*nInd)
P=2*(p-.5) #Difference from .5, multiple by 2
snps=snps-1 #Change from 0/1/2 coding to -1/0/1 coding

print("substracting P...")
Z=t(snps)-P#operation on matrix and vector goes in direction of column
print("Getting X'X...")
#K=tcrossprod((snps), (snps))
K=crossprod((Z), (Z)) #Thanks to Peng Zheng, Meng Huang and Jiafa Chen for finding the problem

print("Adjusting...")
adj=2*sum(p*(1-p))
K=K/adj

print("Calculating kinship with VanRaden method: done")

return(K)
}
#=============================================================================================

`GAPIT.kinship.Zhang` <-
  function(snps,hasInbred=TRUE) {
    # Object: To calculate ZHANG (Zones Harbored Adjustments of Negligent Genetic) relationship
    # Authors: Zhwiu Zhang
    # Last update: october 25, 2014 
    ############################################################################################## 
    print("Calculating ZHANG relationship defined by Zhiwu Zhang...")
    #Remove invariants
    fa=colSums(snps)/(2*nrow(snps))
    index.non=fa>=1| fa<=0
    snps=snps[,!index.non]
    
    het=1-abs(snps-1)
    ind.sum=rowSums(het)
    fi=ind.sum/(2*ncol(snps))
    inbreeding=1-min(fi)
    
    nSNP=ncol(snps)
    nInd=nrow(snps)
    n=nInd 
    snpMean= apply(snps,2,mean)   #get mean for each snp
    print("substracting mean...")
    snps=t(snps)-snpMean    #operation on matrix and vector goes in direction of column
    print("Getting X'X...")
    #K=tcrossprod((snps), (snps))
    K=crossprod((snps), (snps)) 
    if(is.na(K[1,1])) stop ("GAPIT says: Missing data is not allowed for numerical genotype data")
    
    print("Adjusting...")
    #Extract diagonals
    i =1:n
    j=(i-1)*n
    index=i+j
    d=K[index]
    DL=min(d)
    DU=max(d)
    floor=min(K)
    
    
    #Set range between 0 and 2
    top=1+inbreeding
    K=top*(K-floor)/(DU-floor)
    Dmin=top*(DL-floor)/(DU-floor)
    
    #Adjust based on expected minimum diagonal (1)
    if(Dmin<1) {
      print("Adjustment by the minimum diagonal")
      K[index]=(K[index]-Dmin+1)/((top+1-Dmin)*.5)
      K[-index]=K[-index]*(1/Dmin)
    }
    
    #Limiting the maximum offdiagonal to the top
    Omax=max(K[-index])
    if(Omax>top){
      print("Adjustment by the minimum off diagonal")
      K[-index]=K[-index]*(top/Omax)
    }
    
    print("Calculating kinship with Zhang method: done")
    return(K)
  }
#=============================================================================================

`GAPIT.kinship.loiselle` <-
function(snps, method="additive", use="all") {
# Object: To calculate the kinship matrix using the method of Loiselle et al. (1995)
# Authors: Alex Lipka and Hyun Min Kang
# Last update: May 31, 2011 
############################################################################################## 
  #Number of SNP types that are 0s
  n0 <- sum(snps==0,na.rm=TRUE)
  #Number of heterozygote SNP types
  nh <- sum(snps==0.5,na.rm=TRUE)
  #Number of SNP types that are 1s
  n1 <- sum(snps==1,na.rm=TRUE)
  #Number of SNP types that are missing
  nNA <- sum(is.na(snps))
  

 
  #Self explanatory
  dim(snps)[1]*dim(snps)[2]
  #stopifnot(n0+nh+n1+nNA == length(snps))

    
  #Note that the two lines in if(method == "dominant") and if(method == "recessive") are found in
  #if(method == "additive").  Worry about this only if you have heterozygotes, which you do not.
  if( method == "dominant" ) {
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) > 0.5),nrow(snps),ncol(snps))
    snps[!is.na(snps) && (snps == 0.5)] <- flags[!is.na(snps) && (snps == 0.5)]
  }
  else if( method == "recessive" ) {
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) < 0.5),nrow(snps),ncol(snps))
    snps[!is.na(snps) && (snps == 0.5)] <- flags[!is.na(snps) && (snps == 0.5)]
  }
  else if( ( method == "additive" ) && ( nh > 0 ) ) {
    dsnps <- snps
    rsnps <- snps
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) > 0.5),nrow(snps),ncol(snps))
    dsnps[!is.na(snps) && (snps==0.5)] <- flags[is.na(snps) && (snps==0.5)]
    flags <- matrix(as.double(rowMeans(snps,na.rm=TRUE) < 0.5),nrow(snps),ncol(snps))
    rsnps[!is.na(snps) && (snps==0.5)] <- flags[is.na(snps) && (snps==0.5)]
    snps <- rbind(dsnps,rsnps)
  }

  #mafs is a (# SNPs)x(# lines) matrix.  The columns of mafs are identical, and the ij^th element is the average
  #allele frequency for the SNP in the i^th row.
  
  #if(use == "all") imputes missing SNP type values with the expected (average) allele frequency.
  if( use == "all" ) {
    mafs <- matrix(rowMeans(snps,na.rm=TRUE),nrow(snps),ncol(snps))
    snps[is.na(snps)] <- mafs[is.na(snps)]
  }
  else if( use == "complete.obs" ) {
    mafs <- matrix(rowMeans(snps,na.rm=TRUE),nrow(snps),ncol(snps))
    snps <- snps[rowSums(is.na(snps))==0,]
  }
  mafs_comp <- 1-mafs
  snps_comp <- 1-snps
  

  n <- ncol(snps)
  K <- matrix(nrow=n,ncol=n)
  diag(K) <- 1
  #Create the k term on page 1422 of Loiselle et al. (1995)

  missing <- rep(NA, dim(snps)[1])  
  for(i in 1:dim(snps)[1]) {
    missing[i] <- sum(is.na(snps[i,]))
  }
  

  for(i in 1:(n-1)) {
    for(j in (i+1):n) {
      Num_First_Term_1 <- (snps[,i]-mafs[,i])*(snps[,j]-mafs[,j])
      Num_First_Term_2 <- (snps_comp[,i]-mafs_comp[,i])*(snps_comp[,j]-mafs_comp[,j])
      First_Term <- sum(Num_First_Term_1)+sum(Num_First_Term_2)

      Num_Second_Term_1 <- mafs[,i]*(1-mafs[,i])
      Num_Second_Term_2 <- mafs_comp[,i]*(1-mafs_comp[,i])
      Num_Second_Term_Bias_Correction <- 1/((2*n)-missing - 1)
      Num_Second_Term <-  Num_Second_Term_1 + Num_Second_Term_2
      Second_Term <- sum(Num_Second_Term*Num_Second_Term_Bias_Correction)

      Third_Term <- sum(Num_Second_Term) 
      
      f <- (First_Term + Second_Term)/Third_Term

      K[i,j] <- f
      if(K[i,j]<0) K[i,j]=0
      
      K[j,i] <- K[i,j]
    }
  }
  return(K)
}
#=============================================================================================

`GAPIT.kinship.separation` <-
function(PCs=NULL,EV=NULL,nPCs=0 ){
#Object: To calculate kinship from PCS
#       PCs: the principal component as columns and individual as rows, the first column is taxa
#       EV: Eigen values
#       nPCs: the number of front PCs excluded to calculate kinship
#Output: kinship
#Authors: Huihui Li and Zhiwu Zhang
#Last update: April 17, 2012
##############################################################################################
print("Calling GAPIT.kinship.separation")  
  Total.number.PCs=ncol(PCs)
  n=nrow(PCs)
print(Total.number.PCs)
print(n)
  #Choose Total.number.PCs-nPCs PCs and EV to calculate K
  sep.PCs=PCs[, (nPCs+2):(Total.number.PCs)]  #first column is taxa
  sep.EV=EV[(nPCs+1):Total.number.PCs]

  Weighted.sep.EV=sep.EV/sum(sep.EV)
  
  #X=t(t(sep.PCs)*Weighted.sep.EV)  
  X=sep.PCs
   
  XMean= apply(X,2,mean)
  X=as.matrix(X-XMean)
  K=tcrossprod((X), (X))

  #Extract diagonals
  i =1:n
  j=(i-1)*n
  index=i+j
  d=K[index]
  DL=min(d)
  DU=max(d)
  floor=min(K)
  
  K=(K-floor)/(DL-floor)
  MD=(DU-floor)/(DL-floor)
     
  if(is.na(K[1,1])) stop ("GAPIT says: Missing data is not allowed for numerical genotype data")
  if(MD>2)K[index]=K[index]/(MD-1)+1
print("GAPIT.kinship.separation called succesfuly")
  return (K)
}
#=============================================================================================


if(!require(gplots)) install.packages("gplots")
if(!require(LDheatmap)) install.packages("LDheatmap")
if(!require(genetics)) install.packages("genetics")
if(!require(ape)) install.packages("ape")
if(!require(compiler)) install.packages("compiler")

if(!require(EMMREML)) install.packages("EMMREML")
if(!require(scatterplot3d)) install.packages("scatterplot3d")

if(!'multtest'%in% installed.packages()[,"Package"]){
	if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
    BiocManager::install("multtest")
    BiocManager::install("snpStats")
}
############################################################################################################################################## 
 ###MLMM - Multi-Locus Mixed Model 
 ###SET OF FUNCTIONS TO CARRY GWAS CORRECTING FOR POPULATION STRUCTURE WHILE INCLUDING COFACTORS THROUGH A STEPWISE-REGRESSION APPROACH 
 ####### 
 # 
 ##note: require EMMA 
 #library(emma) 
 #source('emma.r') 
 # 
 ##REQUIRED DATA & FORMAT 
 # 
 #PHENOTYPE - Y: a vector of length m, with names(Y)=individual names 
 #GENOTYPE - X: a n by m matrix, where n=number of individuals, m=number of SNPs, with rownames(X)=individual names, and colnames(X)=SNP names 
 #KINSHIP - K: a n by n matrix, with rownames(K)=colnames(K)=individual names 
 #each of these data being sorted in the same way, according to the individual name 
 # 
 ##FOR PLOTING THE GWAS RESULTS 
 #SNP INFORMATION - snp_info: a data frame having at least 3 columns: 
 # - 1 named 'SNP', with SNP names (same as colnames(X)), 
 # - 1 named 'Chr', with the chromosome number to which belong each SNP 
 # - 1 named 'Pos', with the position of the SNP onto the chromosome it belongs to. 
 ####### 
 # 
 ##FUNCTIONS USE 
 #save this file somewhere on your computer and source it! 
 #source('path/mlmm.r') 
 # 
 ###FORWARD + BACKWARD ANALYSES 
 #mygwas<-mlmm(Y,X,K,nbchunks,maxsteps) 
 #X,Y,K as described above 
 #nbchunks: an integer defining the number of chunks of X to run the analysis, allows to decrease the memory usage ==> minimum=2, increase it if you do not have enough memory 
 #maxsteps: maximum number of steps desired in the forward approach. The forward approach breaks automatically once the pseudo-heritability is close to 0, 
 #			however to avoid doing too many steps in case the pseudo-heritability does not reach a value close to 0, this parameter is also used. 
 #			It's value must be specified as an integer >= 3 
 # 
 ###RESULTS 
 # 
 ##STEPWISE TABLE 
 #mygwas$step_table 
 # 
 ##PLOTS 
 # 
 ##PLOTS FORM THE FORWARD TABLE 
 #plot_step_table(mygwas,type=c('h2','maxpval','BIC','extBIC')) 
 # 
 ##RSS PLOT 
 #plot_step_RSS(mygwas) 
 # 
 ##GWAS MANHATTAN PLOTS 
 # 
 #FORWARD STEPS 
 #plot_fwd_GWAS(mygwas,step,snp_info,pval_filt) 
 #step=the step to be plotted in the forward approach, where 1 is the EMMAX scan (no cofactor) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 # 
 #OPTIMAL MODELS 
 #Automatic identification of the optimal models within the forwrad-backward models according to the extendedBIC or multiple-bonferonni criteria 
 # 
 #plot_opt_GWAS(mygwas,opt=c('extBIC','mbonf'),snp_info,pval_filt) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 # 
 ##GWAS MANHATTAN PLOT ZOOMED IN A REGION OF INTEREST 
 #plot_fwd_region(mygwas,step,snp_info,pval_filt,chrom,pos1,pos2) 
 #step=the step to be plotted in the forward approach, where 1 is the EMMAX scan (no cofactor) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 #chrom is an integer specifying the chromosome on which the region of interest is 
 #pos1, pos2 are integers delimiting the region of interest in the same unit as Pos in snp_info 
 # 
 #plot_opt_region(mygwas,opt=c('extBIC','mbonf'),snp_info,pval_filt,chrom,pos1,pos2) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 #chrom is an integer specifying the chromosome on which the region of interest is 
 #pos1, pos2 are integers delimiting the region of interest in the same unit as Pos in snp_info 
 # 
 ##QQPLOTS of pvalues 
 #qqplot_fwd_GWAS(mygwas,nsteps) 
 #nsteps=maximum number of forward steps to be displayed 
 # 
 #qqplot_opt_GWAS(mygwas,opt=c('extBIC','mbonf')) 
 # 
 ############################################################################################################################################## 
  
 mlmm<-function(Y,X,K,nbchunks,maxsteps,thresh = NULL) { 
  
 n<-length(Y) 
 m<-ncol(X) 
  
 stopifnot(ncol(K) == n) 
 stopifnot(nrow(K) == n) 
 stopifnot(nrow(X) == n) 
 stopifnot(nbchunks >= 2) 
 stopifnot(maxsteps >= 3) 
  
 #INTERCEPT 
  
 Xo<-rep(1,n) 
  
 #K MATRIX NORMALISATION 
  
 K_norm<-(n-1)/sum((diag(n)-matrix(1,n,n)/n)*K)*K 
 rm(K) 
  
 #step 0 : NULL MODEL 
 cof_fwd<-list() 
 cof_fwd[[1]]<-as.matrix(Xo) 
 colnames(cof_fwd[[1]])<-'Xo' 
  
 mod_fwd<-list() 
 mod_fwd[[1]]<-emma.REMLE(Y,cof_fwd[[1]],K_norm) 
 herit_fwd<-list() 
 herit_fwd[[1]]<-mod_fwd[[1]]$vg/(mod_fwd[[1]]$vg+mod_fwd[[1]]$ve) 
  
 RSSf<-list() 
 RSSf[[1]]<-'NA' 
  
 RSS_H0<-list() 
 RSS_H0[[1]]<-'NA' 
  
 df1<-1 
 df2<-list() 
 df2[[1]]<-'NA' 
  
 Ftest<-list() 
 Ftest[[1]]<-'NA' 
  
 pval<-list() 
 pval[[1]]<-'NA' 
  
 fwd_lm<-list() 
  
 cat('null model done! pseudo-h=',round(herit_fwd[[1]],3),'\n') 
  
 #step 1 : EMMAX 
  
 M<-solve(chol(mod_fwd[[1]]$vg*K_norm+mod_fwd[[1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cof_fwd[[1]]) 
 fwd_lm[[1]]<-summary(lm(Y_t~0+cof_fwd_t)) 
 Res_H0<-fwd_lm[[1]]$residuals 
 Q_<-qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[1]])])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[1]])])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[1]])-1))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[2]]<-unlist(RSS) 
 RSS_H0[[2]]<-sum(Res_H0^2) 
 df2[[2]]<-n-df1-ncol(cof_fwd[[1]]) 
 Ftest[[2]]<-(rep(RSS_H0[[2]],length(RSSf[[2]]))/RSSf[[2]]-1)*df2[[2]]/df1 
 pval[[2]]<-pf(Ftest[[2]],df1,df2[[2]],lower.tail=FALSE) 
  
 cof_fwd[[2]]<-cbind(cof_fwd[[1]],X[,colnames(X) %in% names(which(RSSf[[2]]==min(RSSf[[2]]))[1])]) 
 colnames(cof_fwd[[2]])<-c(colnames(cof_fwd[[1]]),names(which(RSSf[[2]]==min(RSSf[[2]]))[1])) 
 mod_fwd[[2]]<-emma.REMLE(Y,cof_fwd[[2]],K_norm) 
 herit_fwd[[2]]<-mod_fwd[[2]]$vg/(mod_fwd[[2]]$vg+mod_fwd[[2]]$ve) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS) 
  
 cat('step 1 done! pseudo-h=',round(herit_fwd[[2]],3),'\n') 
  
 #FORWARD 
  
 for (i in 3:(maxsteps)) { 
 if (herit_fwd[[i-2]] < 0.01) break else { 
  
 M<-solve(chol(mod_fwd[[i-1]]$vg*K_norm+mod_fwd[[i-1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cof_fwd[[i-1]]) 
 fwd_lm[[i-1]]<-summary(lm(Y_t~0+cof_fwd_t)) 
 Res_H0<-fwd_lm[[i-1]]$residuals 
 Q_ <- qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[i-1]])])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[i-1]])])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[i-1]])-1))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[i]]<-unlist(RSS) 
 RSS_H0[[i]]<-sum(Res_H0^2) 
 df2[[i]]<-n-df1-ncol(cof_fwd[[i-1]]) 
 Ftest[[i]]<-(rep(RSS_H0[[i]],length(RSSf[[i]]))/RSSf[[i]]-1)*df2[[i]]/df1 
 pval[[i]]<-pf(Ftest[[i]],df1,df2[[i]],lower.tail=FALSE) 
  
 cof_fwd[[i]]<-cbind(cof_fwd[[i-1]],X[,colnames(X) %in% names(which(RSSf[[i]]==min(RSSf[[i]]))[1])]) 
 colnames(cof_fwd[[i]])<-c(colnames(cof_fwd[[i-1]]),names(which(RSSf[[i]]==min(RSSf[[i]]))[1])) 
 mod_fwd[[i]]<-emma.REMLE(Y,cof_fwd[[i]],K_norm) 
 herit_fwd[[i]]<-mod_fwd[[i]]$vg/(mod_fwd[[i]]$vg+mod_fwd[[i]]$ve) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS)} 
 cat('step ',i-1,' done! pseudo-h=',round(herit_fwd[[i]],3),'\n')} 
 rm(i) 
  
 ##gls at last forward step 
 M<-solve(chol(mod_fwd[[length(mod_fwd)]]$vg*K_norm+mod_fwd[[length(mod_fwd)]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cof_fwd[[length(mod_fwd)]]) 
 fwd_lm[[length(mod_fwd)]]<-summary(lm(Y_t~0+cof_fwd_t)) 
  
 Res_H0<-fwd_lm[[length(mod_fwd)]]$residuals 
 Q_ <- qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[length(mod_fwd)]])])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[length(mod_fwd)]])])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[length(mod_fwd)]])-1))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[length(mod_fwd)+1]]<-unlist(RSS) 
 RSS_H0[[length(mod_fwd)+1]]<-sum(Res_H0^2) 
 df2[[length(mod_fwd)+1]]<-n-df1-ncol(cof_fwd[[length(mod_fwd)]]) 
 Ftest[[length(mod_fwd)+1]]<-(rep(RSS_H0[[length(mod_fwd)+1]],length(RSSf[[length(mod_fwd)+1]]))/RSSf[[length(mod_fwd)+1]]-1)*df2[[length(mod_fwd)+1]]/df1 
 pval[[length(mod_fwd)+1]]<-pf(Ftest[[length(mod_fwd)+1]],df1,df2[[length(mod_fwd)+1]],lower.tail=FALSE) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS) 
  
 ##get max pval at each forward step 
 max_pval_fwd<-vector(mode="numeric",length=length(fwd_lm)) 
 max_pval_fwd[1]<-0 
 for (i in 2:length(fwd_lm)) {max_pval_fwd[i]<-max(fwd_lm[[i]]$coef[2:i,4])} 
 rm(i) 
  
 ##get the number of parameters & Loglikelihood from ML at each step 
 mod_fwd_LL<-list() 
 # print(emma.MLE(Y,cof_fwd[[1]],K_norm)$ML)
 # print(head(Y))
 # print(head(cof_fwd[[1]]))
 # print(K_norm[1:5,1:5])
 mod_fwd_LL[[1]]<-list(nfixed=ncol(cof_fwd[[1]]),LL=emma.MLE(Y,cof_fwd[[1]],K_norm)$ML) 
 for (i in 2:length(cof_fwd)) {mod_fwd_LL[[i]]<-list(nfixed=ncol(cof_fwd[[i]]),LL=emma.MLE(Y,cof_fwd[[i]],K_norm)$ML)} 
 rm(i) 
  
 cat('backward analysis','\n') 
  
 ##BACKWARD (1st step == last fwd step) 
  
 dropcof_bwd<-list() 
 cof_bwd<-list() 
 mod_bwd <- list() 
 bwd_lm<-list() 
 herit_bwd<-list() 
  
 dropcof_bwd[[1]]<-'NA' 
 cof_bwd[[1]]<-as.matrix(cof_fwd[[length(mod_fwd)]][,!colnames(cof_fwd[[length(mod_fwd)]]) %in% dropcof_bwd[[1]]]) 
 colnames(cof_bwd[[1]])<-colnames(cof_fwd[[length(mod_fwd)]])[!colnames(cof_fwd[[length(mod_fwd)]]) %in% dropcof_bwd[[1]]] 
 mod_bwd[[1]]<-emma.REMLE(Y,cof_bwd[[1]],K_norm) 
 herit_bwd[[1]]<-mod_bwd[[1]]$vg/(mod_bwd[[1]]$vg+mod_bwd[[1]]$ve) 
 M<-solve(chol(mod_bwd[[1]]$vg*K_norm+mod_bwd[[1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_bwd_t<-crossprod(M,cof_bwd[[1]]) 
 bwd_lm[[1]]<-summary(lm(Y_t~0+cof_bwd_t)) 
  
 rm(M,Y_t,cof_bwd_t) 
  
 for (i in 2:length(mod_fwd)) { 
 dropcof_bwd[[i]]<-(colnames(cof_bwd[[i-1]])[2:ncol(cof_bwd[[i-1]])])[which(abs(bwd_lm[[i-1]]$coef[2:nrow(bwd_lm[[i-1]]$coef),3])==min(abs(bwd_lm[[i-1]]$coef[2:nrow(bwd_lm[[i-1]]$coef),3])))] 
 cof_bwd[[i]]<-as.matrix(cof_bwd[[i-1]][,!colnames(cof_bwd[[i-1]]) %in% dropcof_bwd[[i]]]) 
 colnames(cof_bwd[[i]])<-colnames(cof_bwd[[i-1]])[!colnames(cof_bwd[[i-1]]) %in% dropcof_bwd[[i]]] 
 mod_bwd[[i]]<-emma.REMLE(Y,cof_bwd[[i]],K_norm) 
 herit_bwd[[i]]<-mod_bwd[[i]]$vg/(mod_bwd[[i]]$vg+mod_bwd[[i]]$ve) 
 M<-solve(chol(mod_bwd[[i]]$vg*K_norm+mod_bwd[[i]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_bwd_t<-crossprod(M,cof_bwd[[i]]) 
 bwd_lm[[i]]<-summary(lm(Y_t~0+cof_bwd_t)) 
 rm(M,Y_t,cof_bwd_t)} 
  
 rm(i) 
  
 ##get max pval at each backward step 
 max_pval_bwd<-vector(mode="numeric",length=length(bwd_lm)) 
 for (i in 1:(length(bwd_lm)-1)) {max_pval_bwd[i]<-max(bwd_lm[[i]]$coef[2:(length(bwd_lm)+1-i),4])} 
 max_pval_bwd[length(bwd_lm)]<-0 
  
 ##get the number of parameters & Loglikelihood from ML at each step 
 mod_bwd_LL<-list() 
 mod_bwd_LL[[1]]<-list(nfixed=ncol(cof_bwd[[1]]),LL=emma.MLE(Y,cof_bwd[[1]],K_norm)$ML) 
 for (i in 2:length(cof_bwd)) {mod_bwd_LL[[i]]<-list(nfixed=ncol(cof_bwd[[i]]),LL=emma.MLE(Y,cof_bwd[[i]],K_norm)$ML)} 
 rm(i) 
  
 cat('creating output','\n') 
  
 ##Forward Table: Fwd + Bwd Tables 
 #Compute parameters for model criteria 
 BIC<-function(x){-2*x$LL+(x$nfixed+1)*log(n)} 
 extBIC<-function(x){BIC(x)+2*lchoose(m,x$nfixed-1)} 
 # print(ncol(cof_fwd[[1]]))
 fwd_table<-data.frame(step=ncol(cof_fwd[[1]])-1,step_=paste('fwd',ncol(cof_fwd[[1]])-1,sep=''),cof='NA',ncof=ncol(cof_fwd[[1]])-1,h2=herit_fwd[[1]] 
 	,maxpval=max_pval_fwd[1],BIC=BIC(mod_fwd_LL[[1]]),extBIC=extBIC(mod_fwd_LL[[1]])) 
 for (i in 2:(length(mod_fwd))) {fwd_table<-rbind(fwd_table, 
 	data.frame(step=ncol(cof_fwd[[i]])-1,step_=paste('fwd',ncol(cof_fwd[[i]])-1,sep=''),cof=paste('+',colnames(cof_fwd[[i]])[i],sep=''),ncof=ncol(cof_fwd[[i]])-1,h2=herit_fwd[[i]] 
 	,maxpval=max_pval_fwd[i],BIC=BIC(mod_fwd_LL[[i]]),extBIC=extBIC(mod_fwd_LL[[i]])))} 
 # print(head(fwd_table))
 rm(i) 
  
 bwd_table<-data.frame(step=length(mod_fwd),step_=paste('bwd',0,sep=''),cof=paste('-',dropcof_bwd[[1]],sep=''),ncof=ncol(cof_bwd[[1]])-1,h2=herit_bwd[[1]] 
 	,maxpval=max_pval_bwd[1],BIC=BIC(mod_bwd_LL[[1]]),extBIC=extBIC(mod_bwd_LL[[1]])) 
 for (i in 2:(length(mod_bwd))) {bwd_table<-rbind(bwd_table, 
 	data.frame(step=length(mod_fwd)+i-1,step_=paste('bwd',i-1,sep=''),cof=paste('-',dropcof_bwd[[i]],sep=''),ncof=ncol(cof_bwd[[i]])-1,h2=herit_bwd[[i]] 
 	,maxpval=max_pval_bwd[i],BIC=BIC(mod_bwd_LL[[i]]),extBIC=extBIC(mod_bwd_LL[[i]])))} 
  
 rm(i,BIC,extBIC,max_pval_fwd,max_pval_bwd,dropcof_bwd) 
  
 fwdbwd_table<-rbind(fwd_table,bwd_table) 
  
 #RSS for plot 
 mod_fwd_RSS<-vector() 
 mod_fwd_RSS[1]<-sum((Y-cof_fwd[[1]]%*%fwd_lm[[1]]$coef[,1])^2) 
 for (i in 2:length(mod_fwd)) {mod_fwd_RSS[i]<-sum((Y-cof_fwd[[i]]%*%fwd_lm[[i]]$coef[,1])^2)} 
 mod_bwd_RSS<-vector() 
 mod_bwd_RSS[1]<-sum((Y-cof_bwd[[1]]%*%bwd_lm[[1]]$coef[,1])^2) 
 for (i in 2:length(mod_bwd)) {mod_bwd_RSS[i]<-sum((Y-cof_bwd[[i]]%*%bwd_lm[[i]]$coef[,1])^2)} 
 expl_RSS<-c(1-sapply(mod_fwd_RSS,function(x){x/mod_fwd_RSS[1]}),1-sapply(mod_bwd_RSS,function(x){x/mod_bwd_RSS[length(mod_bwd_RSS)]})) 
 h2_RSS<-c(unlist(herit_fwd),unlist(herit_bwd))*(1-expl_RSS) 
 unexpl_RSS<-1-expl_RSS-h2_RSS 
 plot_RSS<-t(apply(cbind(expl_RSS,h2_RSS,unexpl_RSS),1,cumsum)) 
  
 #GLS pvals at each step 
 pval_step<-list() 
 pval_step[[1]]<-list(out=data.frame("SNP"=colnames(X),"pval"=pval[[2]]),"cof"=NA, "coef"=fwd_lm[[1]]$coef) 
 for (i in 2:(length(mod_fwd))) {pval_step[[i]]<-list(out=rbind(data.frame(SNP=colnames(cof_fwd[[i]])[-1],'pval'=fwd_lm[[i]]$coef[2:i,4]), 
 	data.frame(SNP=colnames(X)[-which(colnames(X) %in% colnames(cof_fwd[[i]]))],'pval'=pval[[i+1]])),"cof"=colnames(cof_fwd[[i]])[-1], "coef"=fwd_lm[[i]]$coef)} 
  
 #GLS pvals for best models according to extBIC and mbonf 
  
 opt_extBIC<-fwdbwd_table[which(fwdbwd_table$extBIC==min(fwdbwd_table$extBIC))[1],] 
 opt_mbonf<-(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),])[which(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),]$ncof==max(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),]$ncof))[1],] 
 if(! is.null(thresh)){ 
   opt_thresh<-(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),])[which(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),]$ncof==max(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),]$ncof))[1],] 
 } 
 bestmodel_pvals<-function(model) {
 	# print(model)
  #   print(substr(model$step_,start=0,stop=3))
 	if(substr(model$step_,start=0,stop=3)=='fwd') { 
 		pval_step[[as.integer(substring(model$step_,first=4))+1]]} else if (substr(model$step_,start=0,stop=3)=='bwd') { 
 		cof<-cof_bwd[[as.integer(substring(model$step_,first=4))+1]] 
 		mixedmod<-emma.REMLE(Y,cof,K_norm) 
 		M<-solve(chol(mixedmod$vg*K_norm+mixedmod$ve*diag(n))) 
 		Y_t<-crossprod(M,Y) 
 		cof_t<-crossprod(M,cof) 
 		GLS_lm<-summary(lm(Y_t~0+cof_t)) 
 		Res_H0<-GLS_lm$residuals 
 		Q_ <- qr.Q(qr(cof_t)) 
 		RSS<-list() 
 		for (j in 1:(nbchunks-1)) { 
 		X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof)])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 		RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 		rm(X_t)} 
 		X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof)])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof)-1))]) 
 		RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 		rm(X_t,j) 
 		RSSf<-unlist(RSS) 
 		RSS_H0<-sum(Res_H0^2) 
 		df2<-n-df1-ncol(cof) 
 		Ftest<-(rep(RSS_H0,length(RSSf))/RSSf-1)*df2/df1 
 		pval<-pf(Ftest,df1,df2,lower.tail=FALSE) 
 		list('out'=rbind(data.frame(SNP=colnames(cof)[-1],'pval'=GLS_lm$coef[2:(ncol(cof)),4]), 
 		                 data.frame('SNP'=colnames(X)[-which(colnames(X) %in% colnames(cof))],'pval'=pval)), 
 		     'cof'=colnames(cof)[-1], 
 		     'coef'=GLS_lm$coef)} else {cat('error \n')}} 
 opt_extBIC_out<-bestmodel_pvals(opt_extBIC) 
 opt_mbonf_out<-bestmodel_pvals(opt_mbonf) 
 if(! is.null(thresh)){ 
   opt_thresh_out<-bestmodel_pvals(opt_thresh) 
 } 
 output <- list(step_table=fwdbwd_table,pval_step=pval_step,RSSout=plot_RSS,bonf_thresh=-log10(0.05/m),opt_extBIC=opt_extBIC_out,opt_mbonf=opt_mbonf_out) 
 if(! is.null(thresh)){ 
   output$thresh <- -log10(thresh) 
   output$opt_thresh <- opt_thresh_out 
 } 
 return(output) 
 } 
############################################################################################################################################## 
 ###MLMM_COF - Multi-Locus Mixed Model 
 ###SET OF FUNCTIONS TO CARRY GWAS CORRECTING FOR POPULATION STRUCTURE WHILE INCLUDING COFACTORS THROUGH A STEPWISE-REGRESSION APPROACH 
 ####### 
 # 
 ##note: require EMMA 
 #library(emma) 
 #source('emma.r') 
 # 
 ##REQUIRED DATA & FORMAT 
 # 
 #PHENOTYPE - Y: a vector of length m, with names(Y)=individual names 
 #GENOTYPE - X: a n by m matrix, where n=number of individuals, m=number of SNPs, with rownames(X)=individual names, and colnames(X)=SNP names 
 #KINSHIP - K: a n by n matrix, with rownames(K)=colnames(K)=individual names 
 #COVARIANCE MATRIX - cofs: a n by p matrix, where n=number of individuals, p=number of covariates in the matrix (e.g. PC axes) 
 #each of these data being sorted in the same way, according to the individual name 
 # 
 ##FOR PLOTING THE GWAS RESULTS 
 #SNP INFORMATION - snp_info: a data frame having at least 3 columns: 
 # - 1 named 'SNP', with SNP names (same as colnames(X)), 
 # - 1 named 'Chr', with the chromosome number to which belong each SNP 
 # - 1 named 'Pos', with the position of the SNP onto the chromosome it belongs to. 
 ####### 
 # 
 ##FUNCTIONS USE 
 #save this file somewhere on your computer and source it! 
 #source('path/mlmm.r') 
 # 
 ###FORWARD + BACKWARD ANALYSES 
 #mygwas<-mlmm_cof(Y,X,K,nbchunks,maxsteps) 
 #X,Y,K as described above 
 #nbchunks: an integer defining the number of chunks of X to run the analysis, allows to decrease the memory usage ==> minimum=2, increase it if you do not have enough memory 
 #maxsteps: maximum number of steps desired in the forward approach. The forward approach breaks automatically once the pseudo-heritability is close to 0, 
 #			however to avoid doing too many steps in case the pseudo-heritability does not reach a value close to 0, this parameter is also used. 
 #			It's value must be specified as an integer >= 3 
 # 
 ###RESULTS 
 # 
 ##STEPWISE TABLE 
 #mygwas$step_table 
 # 
 ##PLOTS 
 # 
 ##PLOTS FORM THE FORWARD TABLE 
 #plot_step_table(mygwas,type=c('h2','maxpval','BIC','extBIC')) 
 # 
 ##RSS PLOT 
 #plot_step_RSS(mygwas) 
 # 
 ##GWAS MANHATTAN PLOTS 
 # 
 #FORWARD STEPS 
 #plot_fwd_GWAS(mygwas,step,snp_info,pval_filt) 
 #step=the step to be plotted in the forward approach, where 1 is the EMMAX scan (no cofactor) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 # 
 #OPTIMAL MODELS 
 #Automatic identification of the optimal models within the forwrad-backward models according to the extendedBIC or multiple-bonferonni criteria 
 # 
 #plot_opt_GWAS(mygwas,opt=c('extBIC','mbonf'),snp_info,pval_filt) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 # 
 ##GWAS MANHATTAN PLOT ZOOMED IN A REGION OF INTEREST 
 #plot_fwd_region(mygwas,step,snp_info,pval_filt,chrom,pos1,pos2) 
 #step=the step to be plotted in the forward approach, where 1 is the EMMAX scan (no cofactor) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 #chrom is an integer specifying the chromosome on which the region of interest is 
 #pos1, pos2 are integers delimiting the region of interest in the same unit as Pos in snp_info 
 # 
 #plot_opt_region(mygwas,opt=c('extBIC','mbonf'),snp_info,pval_filt,chrom,pos1,pos2) 
 #snp_info as described above 
 #pval_filt=a p-value threshold for filtering the output, only p-vals below this threshold will be displayed in the plot 
 #chrom is an integer specifying the chromosome on which the region of interest is 
 #pos1, pos2 are integers delimiting the region of interest in the same unit as Pos in snp_info 
 # 
 ##QQPLOTS of pvalues 
 #qqplot_fwd_GWAS(mygwas,nsteps) 
 #nsteps=maximum number of forward steps to be displayed 
 # 
 #qqplot_opt_GWAS(mygwas,opt=c('extBIC','mbonf')) 
 # 
 ############################################################################################################################################## 
  
 mlmm_cof<-function(Y,X,cofs,K,nbchunks,maxsteps,thresh = NULL) { 
  
 n<-length(Y) 
 m<-ncol(X) 
  
 stopifnot(ncol(K) == n) 
 stopifnot(nrow(K) == n) 
 stopifnot(nrow(X) == n) 
 stopifnot(nrow(cofs) == n) 
 stopifnot(nbchunks >= 2) 
 stopifnot(maxsteps >= 3) 
  
 #INTERCEPT 
  
 Xo<-rep(1,n) 
  
 #K MATRIX NORMALISATION 
  
 K_norm<-(n-1)/sum((diag(n)-matrix(1,n,n)/n)*K)*K 
 rm(K) 
  
 #step 0 : NULL MODEL 
  
 fix_cofs<-cbind(Xo,cofs) 
 rm(cofs) 
  
 addcof_fwd<-list() 
 addcof_fwd[[1]]<-'NA' 
  
 cof_fwd<-list() 
 cof_fwd[[1]]<-as.matrix(X[,colnames(X) %in% addcof_fwd[[1]]]) 
  
 mod_fwd<-list() 
 mod_fwd[[1]]<-emma.REMLE(Y,cbind(fix_cofs,cof_fwd[[1]]),K_norm) 
  
 herit_fwd<-list() 
 herit_fwd[[1]]<-mod_fwd[[1]]$vg/(mod_fwd[[1]]$vg+mod_fwd[[1]]$ve) 
  
 RSSf<-list() 
 RSSf[[1]]<-'NA' 
  
 RSS_H0<-list() 
 RSS_H0[[1]]<-'NA' 
  
 df1<-1 
 df2<-list() 
 df2[[1]]<-'NA' 
  
 Ftest<-list() 
 Ftest[[1]]<-'NA' 
  
 pval<-list() 
 pval[[1]]<-'NA' 
  
 fwd_lm<-list() 
  
 cat('null model done! pseudo-h=',round(herit_fwd[[1]],3),'\n') 
  
 #step 1 : EMMAX 
  
 M<-solve(chol(mod_fwd[[1]]$vg*K_norm+mod_fwd[[1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cbind(fix_cofs,cof_fwd[[1]])) 
 fwd_lm[[1]]<-summary(lm(Y_t~0+cof_fwd_t)) 
 Res_H0<-fwd_lm[[1]]$residuals 
 Q_<-qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% addcof_fwd[[1]]])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% addcof_fwd[[1]]])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[1]])))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[2]]<-unlist(RSS) 
 RSS_H0[[2]]<-sum(Res_H0^2) 
 df2[[2]]<-n-df1-ncol(fix_cofs)-ncol(cof_fwd[[1]]) 
 Ftest[[2]]<-(rep(RSS_H0[[2]],length(RSSf[[2]]))/RSSf[[2]]-1)*df2[[2]]/df1 
 pval[[2]]<-pf(Ftest[[2]],df1,df2[[2]],lower.tail=FALSE) 
 addcof_fwd[[2]]<-names(which(RSSf[[2]]==min(RSSf[[2]]))[1]) 
 cof_fwd[[2]]<-cbind(cof_fwd[[1]],X[,colnames(X) %in% addcof_fwd[[2]]]) 
  colnames(cof_fwd[[2]])[ncol(cof_fwd[[2]])]<-addcof_fwd[[2]] 
 mod_fwd[[2]]<-emma.REMLE(Y,cbind(fix_cofs,cof_fwd[[2]]),K_norm) 
 herit_fwd[[2]]<-mod_fwd[[2]]$vg/(mod_fwd[[2]]$vg+mod_fwd[[2]]$ve) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS) 
  
 cat('step 1 done! pseudo-h=',round(herit_fwd[[2]],3),'\n') 
  
 #FORWARD 
  
 for (i in 3:(maxsteps)) { 
 if (herit_fwd[[i-2]] < 0.01) break else { 
  
 M<-solve(chol(mod_fwd[[i-1]]$vg*K_norm+mod_fwd[[i-1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cbind(fix_cofs,cof_fwd[[i-1]])) 
 fwd_lm[[i-1]]<-summary(lm(Y_t~0+cof_fwd_t)) 
 Res_H0<-fwd_lm[[i-1]]$residuals 
 Q_ <- qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[i-1]])])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[i-1]])])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[i-1]])))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[i]]<-unlist(RSS) 
 RSS_H0[[i]]<-sum(Res_H0^2) 
 df2[[i]]<-n-df1-ncol(fix_cofs)-ncol(cof_fwd[[i-1]]) 
 Ftest[[i]]<-(rep(RSS_H0[[i]],length(RSSf[[i]]))/RSSf[[i]]-1)*df2[[i]]/df1 
 pval[[i]]<-pf(Ftest[[i]],df1,df2[[i]],lower.tail=FALSE) 
 addcof_fwd[[i]]<-names(which(RSSf[[i]]==min(RSSf[[i]]))[1]) 
 cof_fwd[[i]]<-cbind(cof_fwd[[i-1]],X[,colnames(X) %in% addcof_fwd[[i]]]) 
 colnames(cof_fwd[[i]])[ncol(cof_fwd[[i]])]<-addcof_fwd[[i]] 
 mod_fwd[[i]]<-emma.REMLE(Y,cbind(fix_cofs,cof_fwd[[i]]),K_norm) 
 herit_fwd[[i]]<-mod_fwd[[i]]$vg/(mod_fwd[[i]]$vg+mod_fwd[[i]]$ve) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS)} 
 cat('step ',i-1,' done! pseudo-h=',round(herit_fwd[[i]],3),'\n')} 
 rm(i) 
  
 ##gls at last forward step 
 M<-solve(chol(mod_fwd[[length(mod_fwd)]]$vg*K_norm+mod_fwd[[length(mod_fwd)]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_fwd_t<-crossprod(M,cbind(fix_cofs,cof_fwd[[length(mod_fwd)]])) 
 fwd_lm[[length(mod_fwd)]]<-summary(lm(Y_t~0+cof_fwd_t)) 
  
 Res_H0<-fwd_lm[[length(mod_fwd)]]$residuals 
 Q_ <- qr.Q(qr(cof_fwd_t)) 
  
 RSS<-list() 
 for (j in 1:(nbchunks-1)) { 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[length(mod_fwd)]])])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t)} 
 X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof_fwd[[length(mod_fwd)]])])[,((j)*round(m/nbchunks)+1):(m-(ncol(cof_fwd[[length(mod_fwd)]])))]) 
 RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 rm(X_t,j) 
  
 RSSf[[length(mod_fwd)+1]]<-unlist(RSS) 
 RSS_H0[[length(mod_fwd)+1]]<-sum(Res_H0^2) 
 df2[[length(mod_fwd)+1]]<-n-df1-ncol(fix_cofs)-ncol(cof_fwd[[length(mod_fwd)]]) 
 Ftest[[length(mod_fwd)+1]]<-(rep(RSS_H0[[length(mod_fwd)+1]],length(RSSf[[length(mod_fwd)+1]]))/RSSf[[length(mod_fwd)+1]]-1)*df2[[length(mod_fwd)+1]]/df1 
 pval[[length(mod_fwd)+1]]<-pf(Ftest[[length(mod_fwd)+1]],df1,df2[[length(mod_fwd)+1]],lower.tail=FALSE) 
 rm(M,Y_t,cof_fwd_t,Res_H0,Q_,RSS) 
  
 ##get max pval at each forward step 
 max_pval_fwd<-vector(mode="numeric",length=length(fwd_lm)) 
 max_pval_fwd[1]<-0 
 for (i in 2:length(fwd_lm)) {max_pval_fwd[i]<-max(fwd_lm[[i]]$coef[(ncol(fix_cofs)+1):(ncol(fix_cofs)+ncol(cof_fwd[[i]])),4])} 
 rm(i) 
  
 ##get the number of parameters & Loglikelihood from ML at each step 
 mod_fwd_LL<-list() 
 mod_fwd_LL[[1]]<-list(nfixed=ncol(cbind(fix_cofs,cof_fwd[[1]])),LL=emma.MLE(Y,cbind(fix_cofs,cof_fwd[[1]]),K_norm)$ML) 
 for (i in 2:length(cof_fwd)) {mod_fwd_LL[[i]]<-list(nfixed=ncol(cbind(fix_cofs,cof_fwd[[i]])),LL=emma.MLE(Y,cbind(fix_cofs,cof_fwd[[i]]),K_norm)$ML)} 
 rm(i) 
  
 cat('backward analysis','\n') 
  
 ##BACKWARD (1st step == last fwd step) 
  
 dropcof_bwd<-list() 
 cof_bwd<-list() 
 mod_bwd <- list() 
 bwd_lm<-list() 
 herit_bwd<-list() 
  
 dropcof_bwd[[1]]<-'NA' 
 cof_bwd[[1]]<-as.matrix(cof_fwd[[length(mod_fwd)]][,!colnames(cof_fwd[[length(mod_fwd)]]) %in% dropcof_bwd[[1]]]) 
 colnames(cof_bwd[[1]])<-colnames(cof_fwd[[length(mod_fwd)]])[!colnames(cof_fwd[[length(mod_fwd)]]) %in% dropcof_bwd[[1]]] 
 mod_bwd[[1]]<-emma.REMLE(Y,cbind(fix_cofs,cof_bwd[[1]]),K_norm) 
 herit_bwd[[1]]<-mod_bwd[[1]]$vg/(mod_bwd[[1]]$vg+mod_bwd[[1]]$ve) 
 M<-solve(chol(mod_bwd[[1]]$vg*K_norm+mod_bwd[[1]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_bwd_t<-crossprod(M,cbind(fix_cofs,cof_bwd[[1]])) 
 bwd_lm[[1]]<-summary(lm(Y_t~0+cof_bwd_t)) 
  
 rm(M,Y_t,cof_bwd_t) 
  
  
 for (i in 2:length(mod_fwd)) { 
 dropcof_bwd[[i]]<-colnames(cof_bwd[[i-1]])[which(abs(bwd_lm[[i-1]]$coef[(ncol(fix_cofs)+1):nrow(bwd_lm[[i-1]]$coef),3])==min(abs(bwd_lm[[i-1]]$coef[(ncol(fix_cofs)+1):nrow(bwd_lm[[i-1]]$coef),3])))] 
 cof_bwd[[i]]<-as.matrix(cof_bwd[[i-1]][,!colnames(cof_bwd[[i-1]]) %in% dropcof_bwd[[i]]]) 
 colnames(cof_bwd[[i]])<-colnames(cof_bwd[[i-1]])[!colnames(cof_bwd[[i-1]]) %in% dropcof_bwd[[i]]] 
 mod_bwd[[i]]<-emma.REMLE(Y,cbind(fix_cofs,cof_bwd[[i]]),K_norm) 
 herit_bwd[[i]]<-mod_bwd[[i]]$vg/(mod_bwd[[i]]$vg+mod_bwd[[i]]$ve) 
 M<-solve(chol(mod_bwd[[i]]$vg*K_norm+mod_bwd[[i]]$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 cof_bwd_t<-crossprod(M,cbind(fix_cofs,cof_bwd[[i]])) 
 bwd_lm[[i]]<-summary(lm(Y_t~0+cof_bwd_t)) 
 rm(M,Y_t,cof_bwd_t)} 
  
 rm(i) 
  
 ##get max pval at each backward step 
 max_pval_bwd<-vector(mode="numeric",length=length(bwd_lm)) 
 for (i in 1:(length(bwd_lm)-1)) {max_pval_bwd[i]<-max(bwd_lm[[i]]$coef[(ncol(fix_cofs)+1):(ncol(fix_cofs)+ncol(cof_bwd[[i]])),4])} 
 max_pval_bwd[length(bwd_lm)]<-0 
  
 ##get the number of parameters & Loglikelihood from ML at each step 
 mod_bwd_LL<-list() 
 mod_bwd_LL[[1]]<-list(nfixed=ncol(cbind(fix_cofs,cof_bwd[[1]])),LL=emma.MLE(Y,cbind(fix_cofs,cof_bwd[[1]]),K_norm)$ML) 
 for (i in 2:length(cof_bwd)) {mod_bwd_LL[[i]]<-list(nfixed=ncol(cbind(fix_cofs,cof_bwd[[i]])),LL=emma.MLE(Y,cbind(fix_cofs,cof_bwd[[i]]),K_norm)$ML)} 
 rm(i) 
  
 cat('creating output','\n') 
  
 ##Forward Table: Fwd + Bwd Tables 
 #Compute parameters for model criteria 
 BIC<-function(x){-2*x$LL+(x$nfixed+1)*log(n)} 
 extBIC<-function(x){BIC(x)+2*lchoose(m,x$nfixed-1)} 
  
 fwd_table<-data.frame(step=ncol(cof_fwd[[1]]),step_=paste('fwd',ncol(cof_fwd[[1]]),sep=''),cof=paste('+',addcof_fwd[[1]],sep=''),ncof=ncol(cof_fwd[[1]]),h2=herit_fwd[[1]] 
 	,maxpval=max_pval_fwd[1],BIC=BIC(mod_fwd_LL[[1]]),extBIC=extBIC(mod_fwd_LL[[1]])) 
 for (i in 2:(length(mod_fwd))) {fwd_table<-rbind(fwd_table, 
 	data.frame(step=ncol(cof_fwd[[i]]),step_=paste('fwd',ncol(cof_fwd[[i]]),sep=''),cof=paste('+',addcof_fwd[[i]],sep=''),ncof=ncol(cof_fwd[[i]]),h2=herit_fwd[[i]] 
 	,maxpval=max_pval_fwd[i],BIC=BIC(mod_fwd_LL[[i]]),extBIC=extBIC(mod_fwd_LL[[i]])))} 
  
 rm(i) 
  
 bwd_table<-data.frame(step=length(mod_fwd),step_=paste('bwd',0,sep=''),cof=paste('-',dropcof_bwd[[1]],sep=''),ncof=ncol(cof_bwd[[1]]),h2=herit_bwd[[1]] 
 	,maxpval=max_pval_bwd[1],BIC=BIC(mod_bwd_LL[[1]]),extBIC=extBIC(mod_bwd_LL[[1]])) 
 for (i in 2:(length(mod_bwd))) {bwd_table<-rbind(bwd_table, 
 	data.frame(step=length(mod_fwd)+i-1,step_=paste('bwd',i-1,sep=''),cof=paste('-',dropcof_bwd[[i]],sep=''),ncof=ncol(cof_bwd[[i]]),h2=herit_bwd[[i]] 
 	,maxpval=max_pval_bwd[i],BIC=BIC(mod_bwd_LL[[i]]),extBIC=extBIC(mod_bwd_LL[[i]])))} 
  
 rm(i,BIC,extBIC,max_pval_fwd,max_pval_bwd,dropcof_bwd) 
  
 fwdbwd_table<-rbind(fwd_table,bwd_table) 
  
 #RSS for plot 
  
 #null model only with intercept 
 null<-emma.REMLE(Y,as.matrix(Xo),K_norm) 
 M<-solve(chol(null$vg*K_norm+null$ve*diag(n))) 
 Y_t<-crossprod(M,Y) 
 Xo_t<-crossprod(M,as.matrix(Xo)) 
 null_lm<-summary(lm(Y_t~0+Xo_t)) 
 rm(null,M,Y_t,Xo_t) 
 RSS_null<-sum((Y-as.matrix(Xo)%*%null_lm$coef[,1])^2) 
  
 mod_fwd_RSS<-vector() 
 mod_fwd_RSS[1]<-sum((Y-cbind(fix_cofs,cof_fwd[[1]])%*%fwd_lm[[1]]$coef[,1])^2) 
 for (i in 2:length(mod_fwd)) {mod_fwd_RSS[i]<-sum((Y-cbind(fix_cofs,cof_fwd[[i]])%*%fwd_lm[[i]]$coef[,1])^2)} 
 mod_bwd_RSS<-vector() 
 mod_bwd_RSS[1]<-sum((Y-cbind(fix_cofs,cof_bwd[[1]])%*%bwd_lm[[1]]$coef[,1])^2) 
 for (i in 2:length(mod_bwd)) {mod_bwd_RSS[i]<-sum((Y-cbind(fix_cofs,cof_bwd[[i]])%*%bwd_lm[[i]]$coef[,1])^2)} 
  
 expl_RSS<-c(1-sapply(mod_fwd_RSS,function(x){x/RSS_null}),1-sapply(mod_bwd_RSS,function(x){x/RSS_null})) 
 fix_cofs_RSS<-rep(expl_RSS[1],length(expl_RSS)) 
 cofs_RSS<-expl_RSS-fix_cofs_RSS 
 h2_RSS<-c(unlist(herit_fwd),unlist(herit_bwd))*(1-expl_RSS) 
 unexpl_RSS<-1-expl_RSS-h2_RSS 
 plot_RSS<-t(apply(cbind(fix_cofs_RSS,cofs_RSS,h2_RSS,unexpl_RSS),1,cumsum)) 
  
 #GLS pvals at each step 
 pval_step<-list() 
 pval_step[[1]]<-list(out=data.frame('SNP'=names(pval[[2]]),'pval'=pval[[2]]),cof=addcof_fwd[[1]], "coef"=fwd_lm[[1]]$coef) 
 for (i in 2:(length(mod_fwd))) { 
   pval_step[[i]]<-list('out'=rbind(data.frame('SNP'=colnames(cof_fwd[[i]]),'pval'=fwd_lm[[i]]$coef[(ncol(fix_cofs)+1):(ncol(fix_cofs)+ncol(cof_fwd[[i]])),4]), 
                                    data.frame('SNP'=names(pval[[i+1]]),'pval'=pval[[i+1]])), 
                        'cof'=colnames(cof_fwd[[i]]), 
                        'coef'=fwd_lm[[i]]$coef) 
   } 
  
 #GLS pvals for best models according to extBIC and mbonf 
  
 opt_extBIC<-fwdbwd_table[which(fwdbwd_table$extBIC==min(fwdbwd_table$extBIC))[1],] 
 opt_mbonf<-(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),])[which(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),]$ncof==max(fwdbwd_table[which(fwdbwd_table$maxpval<=0.05/m),]$ncof))[1],] 
 if(! is.null(thresh)){ 
   opt_thresh<-(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),])[which(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),]$ncof==max(fwdbwd_table[which(fwdbwd_table$maxpval<=thresh),]$ncof))[1],] 
 } 
 bestmodel_pvals<-function(model) {if(substr(model$step_,start=0,stop=3)=='fwd') { 
 		pval_step[[as.integer(substring(model$step_,first=4))+1]]} else if (substr(model$step_,start=0,stop=3)=='bwd') { 
 		cof<-cof_bwd[[as.integer(substring(model$step_,first=4))+1]] 
 		mixedmod<-emma.REMLE(Y,cbind(fix_cofs,cof),K_norm) 
 		M<-solve(chol(mixedmod$vg*K_norm+mixedmod$ve*diag(n))) 
 		Y_t<-crossprod(M,Y) 
 		cof_t<-crossprod(M,cbind(fix_cofs,cof)) 
 		GLS_lm<-summary(lm(Y_t~0+cof_t)) 
 		Res_H0<-GLS_lm$residuals 
 		Q_ <- qr.Q(qr(cof_t)) 
 		RSS<-list() 
 		for (j in 1:(nbchunks-1)) { 
 		X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof)])[,((j-1)*round(m/nbchunks)+1):(j*round(m/nbchunks))]) 
 		RSS[[j]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 		rm(X_t)} 
 		X_t<-crossprod(M %*% (diag(n)-tcrossprod(Q_,Q_)),(X[,!colnames(X) %in% colnames(cof)])[,((j)*round(m/nbchunks)+1):(m-ncol(cof))]) 
 		RSS[[nbchunks]]<-apply(X_t,2,function(x){sum(lsfit(x,Res_H0,intercept = FALSE)$residuals^2)}) 
 		rm(X_t,j) 
 		RSSf<-unlist(RSS) 
 		RSS_H0<-sum(Res_H0^2) 
 		df2<-n-df1-ncol(fix_cofs)-ncol(cof) 
 		Ftest<-(rep(RSS_H0,length(RSSf))/RSSf-1)*df2/df1 
 		pval<-pf(Ftest,df1,df2,lower.tail=FALSE) 
 		list('out'=rbind(data.frame(SNP=colnames(cof),'pval'=GLS_lm$coef[(ncol(fix_cofs)+1):(ncol(fix_cofs)+ncol(cof)),4]), 
 		                 data.frame('SNP'=names(pval),'pval'=pval)), 
 		     'cof'=colnames(cof), 
 		     'coef'=GLS_lm$coef)} else {cat('error \n')}} 
 opt_extBIC_out<-bestmodel_pvals(opt_extBIC) 
 opt_mbonf_out<-bestmodel_pvals(opt_mbonf) 
 if(! is.null(thresh)){ 
   opt_thresh_out<-bestmodel_pvals(opt_thresh) 
 } 
 output <- list(step_table=fwdbwd_table,pval_step=pval_step,RSSout=plot_RSS,bonf_thresh=-log10(0.05/m),opt_extBIC=opt_extBIC_out,opt_mbonf=opt_mbonf_out) 
 if(! is.null(thresh)){ 
   output$thresh <- -log10(thresh) 
   output$opt_thresh <- opt_thresh_out 
 } 
 return(output) 
 } 
`GAPIT.replaceNaN` <-
function(LL) {
#handler of grids with NaN log
#Authors: Zhiwu Zhang
# Last update: may 12, 2011 
##############################################################################################

#handler of grids with NaN log 
index=(LL=="NaN")
if(length(index)>0) theMin=min(LL[!index])
if(length(index)<1) theMin="NaN"
LL[index]=theMin
return(LL)    
}
#=============================================================================================
`GAPIT2` <-
function(Y=NULL,G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,CV.Inheritance=NULL,GP=NULL,GK=NULL,
                group.from=1000000 ,group.to=1000000,group.by=10,DPP=100000, 
                kinship.cluster="average", kinship.group='Mean',kinship.algorithm="VanRaden",                                                    
                bin.from=10000,bin.to=10000,bin.by=10000,inclosure.from=10,inclosure.to=10,inclosure.by=10,
                SNP.P3D=TRUE,SNP.effect="Add",SNP.impute="Middle",PCA.total=0, PCA.col=NULL,PCA.3d=FALSE,
                SNP.fraction = 1, seed = 123, BINS = 20,SNP.test=TRUE,
                SNP.MAF=0,FDR.Rate = 1, SNP.FDR=1,SNP.permutation=FALSE,SNP.CV=NULL,SNP.robust="GLM",                           
                file.from=1, file.to=1, file.total=NULL, file.fragment = 99999,file.path=NULL, 
                file.G=NULL, file.Ext.G=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL, 
                ngrid = 100, llim = -10, ulim = 10, esp = 1e-10,
                LD.chromosome=NULL,LD.location=NULL,LD.range=NULL,
                sangwich.top=NULL,sangwich.bottom=NULL,QC=TRUE,GTindex=NULL,LD=0.1,
                NJtree.group=NULL,NJtree.type=c("fan","unrooted"),plot.bin=10^5,
                file.output=TRUE,cutOff=0.01, Model.selection = FALSE,output.numerical = FALSE,
                output.hapmap = FALSE, Create.indicator = FALSE,
				        QTN=NULL, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = FALSE,
                method.GLM="fast.lm",method.sub="reward",method.sub.final="reward",method.bin="static",
                bin.size=c(1000000),bin.selection=c(10,20,50,100,200,500,1000),
                memo="",Prior=NULL,ncpus=1,maxLoop=3,threshold.output=.01,
                WS=c(1e0,1e3,1e4,1e5,1e6,1e7),alpha=c(.01,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,1),maxOut=100,QTN.position=NULL,CG=NULL,
                converge=1,iteration.output=FALSE,acceleration=0,iteration.method="accum",PCA.View.output=TRUE,Geno.View.output=TRUE,
                plot.style="Oceanic",SUPER_GD=NULL,SUPER_GS=FALSE){
#Object: To perform GWAS and GPS (Genomic Prediction/Selection)
#Designed by Zhiwu Zhang
#Writen by Alex Lipka, Feng Tian ,You Tang and Zhiwu Zhang
#Last update: Oct 23, 2015  by Jiabo Wang add REML threshold and SUPER GK
##############################################################################################
print("--------------------- Welcome to GAPIT ----------------------------")
  
echo=TRUE
#GAPIT.Version=GAPIT.0000()

Timmer=GAPIT.Timmer(Infor="GAPIT")
Memory=GAPIT.Memory(Infor="GAPIT")

#Genotype processing and calculation Kin and PC
#First call to genotype to setup genotype data

storage_PCA.total<-PCA.total
#if(PCA.total>0){
#if(PCA.total<=3){PCA.total=4}
#}

#BUS algorithm
#if(kinship.algorithm=="FARM-CPU") return (GAPIT.BUS(Y=Y,GDP=GD,GM=GM,CV=CV,
#  method.GLM=method.GLM,method.sub=method.sub,method.sub.final=method.sub.final,method.bin=method.bin,
#  bin.size=bin.size,bin.selection=bin.selection,file.output=file.output,
#  cutOff=cutOff,DPP=DPP,memo=memo,Prior=Prior,ncpus=ncpus,maxLoop=maxLoop,
#  kinship.algorithm=kinship.algorithm,GP=GP,threshold.output=threshold.output,
#  WS=WS,alpha=alpha,maxOut=maxOut,QTN.position=QTN.position,converge=converge,
 # iteration.output=iteration.output,acceleration=acceleration,iteration.method=iteration.method))

myGenotype<-GAPIT.Genotype(G=G,GD=GD,GM=GM,KI=KI,kinship.algorithm=kinship.algorithm,PCA.total=PCA.total,SNP.fraction=SNP.fraction,SNP.test=SNP.test,
                file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,NJtree.group=NJtree.group,NJtree.type=NJtree.type,
                LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,
                GP=GP,GK=GK,bin.size=NULL,inclosure.size=NULL, Timmer = Timmer,Memory=Memory,
                sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,GTindex=NULL,file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero,Geno.View.output=Geno.View.output,PCA.col=PCA.col,PCA.3d=PCA.3d)

Timmer=myGenotype$Timmer
Memory=myGenotype$Memory

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype for all")
Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype for all")


KI=myGenotype$KI
PC=myGenotype$PC


genoFormat=myGenotype$genoFormat
hasGenotype=myGenotype$hasGenotype
byFile=myGenotype$byFile
fullGD=myGenotype$fullGD
GD=myGenotype$GD
GI=myGenotype$GI
GT=myGenotype$GT
G=myGenotype$G
chor_taxa=myGenotype$chor_taxa

#print(dim(GD))
#print(dim(GI))
rownames(GD)=GT
colnames(GD)=GI[,1]

if(output.numerical) write.table(GD,  "GAPIT.Genotype.Numerical.txt", quote = FALSE, sep = "\t", row.names = TRUE,col.names = NA)
if(output.hapmap) write.table(myGenotype$G,  "GAPIT.Genotype.hmp.txt", quote = FALSE, sep = "\t", row.names = FALSE,col.names = FALSE)

#In case of null Y and null GP, return genotype only  
if(is.null(Y) & is.null(GP)) return (list(GWAS=NULL,GPS=NULL,Pred=NULL,compression=NULL,kinship.optimum=NULL,kinship=myGenotype$KI,PCA=myGenotype$PC,GD=data.frame(cbind(as.data.frame(GT),as.data.frame(GD))),GI=GI,G=myGenotype$G))

#In case of null Y, return genotype only          
if(is.null(Y)) return (list(GWAS=NULL,GPS=NULL,Pred=NULL,compression=NULL,kinship.optimum=NULL,kinship=myGenotype$KI,PCA=myGenotype$PC,GD=data.frame(cbind(as.date.frame(GT),as.data.frame(GD))),Gi=GI,G=myGenotype$G))

rm(myGenotype)
gc()


PCA.total<-storage_PCA.total

print("--------------------Processing traits----------------------------------")
if(!is.null(Y)){
print("Phenotype provided!")
if(ncol(Y)<2)  stop ("Phenotype should have taxa name and one trait at least. Please correct phenotype file!")

for (trait in 2: ncol(Y))  {
traitname=colnames(Y)[trait]

###Statistical distributions of phenotype
if(!is.null(Y) & file.output)ViewPhenotype<-GAPIT.Phenotype.View(myY=Y[,c(1,trait)],traitname=traitname,memo=memo)


###Correlation between phenotype and principal components
if(!is.null(Y)&!is.null(PC) & file.output & PCA.total>0 & PCA.View.output){

myPPV<-GAPIT.Phenotype.PCA.View(
PC=PC,
myY=Y[,c(1,trait)]
)

}
#print(SNP.fraction)
#print("!!!!")
#print(GT)
print(paste("Processing trait: ",traitname,sep=""))
if(!is.null(memo)) traitname=paste(memo,".",traitname,sep="")

#print("!!!!")
#print(dim(Z))
#print(dim(KI))
#print(group.from)
#print(group.to)

gapitMain <- GAPIT.Main(Y=Y[,c(1,trait)],G=G,GD=GD,GM=GI,KI=KI,Z=Z,CV=CV,CV.Inheritance=CV.Inheritance,GP=GP,GK=GK,SNP.P3D=SNP.P3D,kinship.algorithm=kinship.algorithm,
                      bin.from=bin.from,bin.to=bin.to,bin.by=bin.by,inclosure.from=inclosure.from,inclosure.to=inclosure.to,inclosure.by=inclosure.by,
				              group.from=group.from,group.to=group.to,group.by=group.by,kinship.cluster=kinship.cluster,kinship.group=kinship.group,name.of.trait=traitname,
                        file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM, 
                        SNP.MAF= SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,PCA.total=PCA.total,GAPIT.Version=GAPIT.Version,
                        GT=GT, SNP.fraction = SNP.fraction, seed = seed, BINS = BINS,SNP.test=SNP.test,DPP=DPP, SNP.permutation=SNP.permutation,NJtree.group=NJtree.group,NJtree.type=NJtree.type,plot.bin=plot.bin,
                        LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,SNP.CV=SNP.CV,SNP.robust=SNP.robust,
                        genoFormat=genoFormat,hasGenotype=hasGenotype,byFile=byFile,fullGD=fullGD,PC=PC,GI=GI,Timmer = Timmer, Memory = Memory,
                        sangwich.top=sangwich.top,sangwich.bottom=sangwich.bottom,QC=QC,GTindex=GTindex,LD=LD,file.output=file.output,cutOff=cutOff, 
                        Model.selection = Model.selection, Create.indicator = Create.indicator,
						            QTN=QTN, QTN.round=QTN.round,QTN.limit=QTN.limit, QTN.update=QTN.update, QTN.method=QTN.method, Major.allele.zero=Major.allele.zero,
                        QTN.position=QTN.position,plot.style=plot.style,SUPER_GS=SUPER_GS,CG=CG,chor_taxa=chor_taxa)
}# end of loop on trait

if(ncol(Y>2) &file.output)
{
Timmer=gapitMain$Timmer
Memory=gapitMain$Memory

file=paste("GAPIT.", "All",".Timming.csv" ,sep = "")
write.table(Timmer, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

file=paste("GAPIT.", "All",".Memory.Stage.csv" ,sep = "")
write.table(Memory, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
}

if(ncol(Y)==2) {

if (!SUPER_GS){
#Evaluate Power vs FDR and type I error
myPower=NULL
if(!is.null(gapitMain$GWAS))myPower=GAPIT.Power(WS=WS, alpha=alpha, maxOut=maxOut,seqQTN=QTN.position,GM=GM,GWAS=gapitMain$GWAS)


h2= as.matrix(as.numeric(as.vector(gapitMain$Compression[,5]))/(as.numeric(as.vector(gapitMain$Compression[,5]))+as.numeric(as.vector(gapitMain$Compression[,6]))),length(gapitMain$Compression[,6]),1)
colnames(h2)=c("Heritability")
  print("GAPIT accomplished successfully for single trait. Results are saved. GWAS are returned!")
  print("It is OK to see this: 'There were 50 or more warnings (use warnings() to see the first 50)'")

  return (list(QTN=gapitMain$QTN,GWAS=gapitMain$GWAS,h2=gapitMain$h2,Pred=gapitMain$Pred,compression=as.data.frame(cbind(gapitMain$Compression,h2)), 
  kinship.optimum=gapitMain$kinship.optimum,kinship=gapitMain$kinship,PCA=gapitMain$PC,
    FDR=myPower$FDR,Power=myPower$Power,Power.Alpha=myPower$Power.Alpha,alpha=myPower$alpha,SUPER_GD=gapitMain$SUPER_GD,P=gapitMain$P,effect.snp=gapitMain$effect.snp,effect.cv=gapitMain$effect.cv))
}else{
h2= as.matrix(as.numeric(as.vector(gapitMain$Compression[,5]))/(as.numeric(as.vector(gapitMain$Compression[,5]))+as.numeric(as.vector(gapitMain$Compression[,6]))),length(gapitMain$Compression[,6]),1)
colnames(h2)=c("Heritability")
  print("GAPIT accomplished successfully for single trait. Results are saved. GPS are returned!")
  print("It is OK to see this: 'There were 50 or more warnings (use warnings() to see the first 50)'")

  return (list(QTN=gapitMain$QTN,GWAS=gapitMain$GWAS,h2=gapitMain$h2,Pred=gapitMain$Pred,compression=as.data.frame(cbind(gapitMain$Compression,h2)), 
  kinship.optimum=gapitMain$kinship.optimum,kinship=gapitMain$kinship,PCA=gapitMain$PC,
    SUPER_GD=gapitMain$SUPER_GD,P=gapitMain$P,effect.snp=gapitMain$effect.snp,effect.cv=gapitMain$effect.cv))

}


}else{
  print("GAPIT accomplished successfully for multiple traits. Results are saved")
  print("It is OK to see this: 'There were 50 or more warnings (use warnings() to see the first 50)'")

  
  return (list(QTN=NULL,GWAS=NULL,h2=NULL,Pred=NULL,compression=NULL,kinship.optimum=NULL,kinship=gapitMain$KI,PCA=gapitMain$PC,P=gapitMain$P,effect.snp=gapitMain$effect.snp,effect.cv=gapitMain$effect.cv))
}

}# end ofdetecting null Y
}  #end of GAPIT function

