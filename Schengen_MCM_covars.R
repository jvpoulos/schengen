###################################
#  MC estimates #
###################################

## Libraries
library(MCPanel)
library(boot)
library(glmnet)

# Setup parallel processing 
library(parallel)
library(doParallel)

cores <- 2#detectCores()

cl <- parallel::makeForkCluster(cores)

doParallel::registerDoParallel(cores) # register cores (<p)

RNGkind("L'Ecuyer-CMRG") # ensure random number generation

outcome.vars <- c("CBWbord","CBWbordEMPL","empl","Thwusual","unempl","inact","seekdur_0","seekdur_1_2","seekdur_3more")

for(o in outcome.vars){
  print(o)
  
  ## Analysis 1: ST vs AT (retrospective, X=CBW) 
  
  # Eastern cluster
  print(paste0("Estimates for Analysis 1, Eastern cluster, outcome:",o))
  
  outcomes.cbw.eastern <- readRDS(paste0("data/outcomes-cbw-eastern-",o,".rds"))
  
  outcomes.cbw.eastern$mask[rownames(outcomes.cbw.eastern$mask)%in%outcomes.cbw.eastern$treated,] <- abs(outcomes.cbw.eastern$mask[rownames(outcomes.cbw.eastern$mask)%in%outcomes.cbw.eastern$treated,]-1) # estimate Y(1)_LT,pre
  
  # Get treatment effect estimates
    
  source('MCEst.R')
  mc.estimates.cbw.eastern <- MCEst(outcomes.cbw.eastern, covars=TRUE) 
  saveRDS(mc.estimates.cbw.eastern, paste0("results/mc-estimates-cbw-eastern-",o,".rds"))
  
  # Get optimal stationary bootstrap lengths
  source("PolitisWhite.R")
  
  bopt <- b.star(t(outcomes.cbw.eastern$M),round=TRUE)[,1]
  
  # Block resampling with fixed block lengths of length l)
  source("MCEstBoot.R")
  
  boot <- tsboot(tseries=ts(t(outcomes.cbw.eastern$M)), MCEstBoot, mask=outcomes.cbw.eastern$mask, W=outcomes.cbw.eastern$W, treated=outcomes.cbw.eastern$treated, control=outcomes.cbw.eastern$control, covars=TRUE,R=1000, parallel = "multicore", l=bopt, sim = "fixed") 
  saveRDS(boot, paste0("results/boot-cbw-eastern-",o,".rds"))
  
  # Get p-values
  source("ChernoTest.R")
  
  t0 <- which(colnames(outcomes.cbw.eastern$M)=="20081")
  
  treat_indices_order <- outcomes.cbw.eastern$treated
  
  iid.block <- ChernoTest(outcomes=outcomes.cbw.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid.block",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(iid.block,paste0("results/iid-block-cbw-eastern-",o,".rds"))
  
  iid <- ChernoTest(outcomes=outcomes.cbw.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(iid,paste0("results/iid-cbw-eastern-",o,".rds"))
  
  moving.block <- ChernoTest(outcomes=outcomes.cbw.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="moving.block",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(moving.block,paste0("results/moving-block-cbw-eastern-",o,".rds"))
  
  # Swiss cluster
  print(paste0("Estimates for Analysis 1, Swiss cluster, outcome:",o))
  
  outcomes.cbw.swiss <- readRDS(paste0("data/outcomes-cbw-swiss-",o,".rds"))
  
  outcomes.cbw.swiss$mask[rownames(outcomes.cbw.swiss$mask)%in%outcomes.cbw.swiss$treated,] <- abs(outcomes.cbw.swiss$mask[rownames(outcomes.cbw.swiss$mask)%in%outcomes.cbw.swiss$treated,]-1) # estimate Y(1)_LT,pre
  
  # Get treatment effect estimates
  
  mc.estimates.cbw.swiss <- MCEst(outcomes.cbw.swiss, covars=TRUE)
  saveRDS(mc.estimates.cbw.swiss, paste0("results/mc-estimates-cbw-swiss-",o,".rds"))
  
  # Get optimal stationary bootstrap lengths
  source("PolitisWhite.R")
  
  bopt <- b.star(t(outcomes.cbw.swiss$M),round=TRUE)[,1]
  
  # Block resampling with fixed block lengths of length l)
  
  boot <- tsboot(tseries=ts(t(outcomes.cbw.swiss$M)), MCEstBoot, mask=outcomes.cbw.swiss$mask, W=outcomes.cbw.swiss$W, treated=outcomes.cbw.swiss$treated, control=outcomes.cbw.swiss$control, covars=TRUE,R=1000, parallel = "multicore", l=bopt, sim = "fixed") 
  saveRDS(boot, paste0("results/boot-cbw-swiss-",o,".rds"))
  
  # Get p-values
  
  t0 <- which(colnames(outcomes.cbw.swiss$M)=="20072")
  
  treat_indices_order <- outcomes.cbw.swiss$treated
  
  iid.block <- ChernoTest(outcomes=outcomes.cbw.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid.block",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(iid.block,paste0("results/iid-block-cbw-swiss-",o,".rds"))
  
  moving.block <- ChernoTest(outcomes=outcomes.cbw.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="moving.block",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(moving.block,paste0("results/moving-block-cbw-swiss-",o,".rds"))
  
  iid <- ChernoTest(outcomes=outcomes.cbw.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid",t0=t0,rev=TRUE,covars=TRUE)
  saveRDS(iid,paste0("results/iid-cbw-swiss-",o,".rds"))

  ## Analysis 2: ST vs NT (forward, X=LM)
  
  # Eastern cluster
  print(paste0("Estimates for Analysis 2, Eastern cluster, outcome:",o))
  
  outcomes.lm.eastern <- readRDS(paste0("data/outcomes-lm-eastern-",o,".rds"))
  
  # Get treatment effect estimates
  
  mc.estimates.lm.eastern <- MCEst(outcomes.lm.eastern, covars=TRUE) 
  saveRDS(mc.estimates.lm.eastern, paste0("results/mc-estimates-lm-eastern-",o,".rds"))
  
  # Get optimal stationary bootstrap lengths

  bopt <- b.star(t(outcomes.lm.eastern$M),round=TRUE)[,1]
  
  # Block resampling with fixed block lengths of length l)
  
  boot <- tsboot(tseries=ts(t(outcomes.lm.eastern$M)), MCEstBoot, mask=outcomes.lm.eastern$mask, W=outcomes.lm.eastern$W, treated=outcomes.lm.eastern$treated, control=outcomes.lm.eastern$control,covars=TRUE,R=1000, parallel = "multicore", l=bopt, sim = "fixed") 
  saveRDS(boot, paste0("results/boot-lm-eastern-",o,".rds"))
  
  # Get p-values

  t0 <- which(colnames(outcomes.lm.eastern$M)=="20081")
  
  treat_indices_order <- outcomes.lm.eastern$treated
  
  iid.block <- ChernoTest(outcomes=outcomes.lm.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid.block",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(iid.block,paste0("results/iid-block-lm-eastern-",o,".rds"))
  
  moving.block <- ChernoTest(outcomes=outcomes.lm.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="moving.block",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(moving.block,paste0("results/moving-block-lm-eastern-",o,".rds"))
  
  iid <- ChernoTest(outcomes=outcomes.lm.eastern[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(iid,paste0("results/iid-lm-eastern-",o,".rds"))
  
  # Swiss cluster
  print(paste0("Estimates for Analysis 2, Swiss cluster, outcome:",o))
  
  outcomes.lm.swiss <- readRDS(paste0("data/outcomes-lm-swiss-",o,".rds"))
  
  # Get treatment effect estimates
  
  mc.estimates.lm.swiss <- MCEst(outcomes.lm.swiss, covars=TRUE) 
  saveRDS(mc.estimates.lm.swiss, paste0("results/mc-estimates-lm-swiss-",o,".rds"))
  
  # Get optimal stationary bootstrap lengths
  
  bopt <- b.star(t(outcomes.lm.swiss$M),round=TRUE)[,1]
  
  # Block resampling with fixed block lengths of length l)
  
  boot <- tsboot(tseries=ts(t(outcomes.lm.swiss$M)), MCEstBoot, mask=outcomes.lm.swiss$mask, W=outcomes.lm.swiss$W, treated=outcomes.lm.swiss$treated, control=outcomes.lm.swiss$control, covars=TRUE,R=1000, parallel = "multicore", l=bopt, sim = "fixed") 
  saveRDS(boot, paste0("results/boot-lm-swiss-",o,".rds"))
  
  # Get p-values
  
  t0 <- which(colnames(outcomes.lm.swiss$M)=="20072")
  
  treat_indices_order <- outcomes.lm.swiss$treated
  
  iid.block <- ChernoTest(outcomes=outcomes.lm.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid.block",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(iid.block,paste0("results/iid-block-lm-swiss-",o,".rds"))
  
  moving.block <- ChernoTest(outcomes=outcomes.lm.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="moving.block",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(moving.block,paste0("results/moving-block-lm-swiss-",o,".rds"))
  
  iid <- ChernoTest(outcomes=outcomes.lm.swiss[c("M","mask","W")], ns=1000, treat_indices_order=treat_indices_order, permtype="iid",t0=t0,rev=FALSE,covars=TRUE)
  saveRDS(iid,paste0("results/iid-lm-swiss-",o,".rds"))
}