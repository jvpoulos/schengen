###################################
#  MC estimates with covariates#
###################################

## Libraries
library(MCPanel)
library(boot)
library(Matrix)

# Setup parallel processing 
library(parallel)
library(doParallel)

cores <- detectCores()

cl <- parallel::makeForkCluster(cores)

doParallel::registerDoParallel(cores) # register cores (<p)

RNGkind("L'Ecuyer-CMRG") # ensure random number generation

outcome.vars <- c("CBWbord","CBWbordEMPL")

for(o in outcome.vars){
  print(paste0("Outcome: ", o))
  
  print(paste0("Covariates + FEs, outcome:",o))
  
  outcomes.cbw <- readRDS(paste0("data/outcomes-cbw-",o,".rds"))
  
  # Get treatment effect estimates
    
  source('MCEst.R')
  mc.estimates.cbw.eastern <- MCEst(outcomes.cbw, cluster='eastern', rev=TRUE, covars=TRUE)
  saveRDS(mc.estimates.cbw.eastern, paste0("results/mc-estimates-cbw-eastern-",o,"-covars.rds"))
  
  mc.estimates.cbw.swiss <- MCEst(outcomes.cbw, cluster='swiss', rev=TRUE, covars=TRUE)
  saveRDS(mc.estimates.cbw.swiss, paste0("results/mc-estimates-cbw-swiss-",o,"-covars.rds"))
  
  print(paste0("Rank of L (Eastern): ", mc.estimates.cbw.eastern$rankL))
  print(paste0("Rank of L (Swiss): ", mc.estimates.cbw.swiss$rankL))

  # Get optimal stationary bootstrap lengths
  source("PolitisWhite.R")
  
  bopt.eastern <- b.star(t(outcomes.cbw$M[!rownames(outcomes.cbw$M)%in%outcomes.cbw$swiss,]),round=TRUE)[,1]
  bopt.swiss <- b.star(t(outcomes.cbw$M[!rownames(outcomes.cbw$M)%in%outcomes.cbw$eastern,]),round=TRUE)[,1]
  
  # Bootstrap for per-period effects
  source("MCEstBoot.R")
  
  boot.eastern <- tsboot(tseries=t(outcomes.cbw$M), MCEstBoot, mask=outcomes.cbw$mask, W=outcomes.cbw$W, X=outcomes.cbw$X, X.hat=outcomes.cbw$X.hat, 
                 z.cbw.eastern =outcomes.cbw$z.cbw.eastern, z.cbw.swiss = outcomes.cbw$z.cbw.swiss, eastern=outcomes.cbw$eastern, swiss=outcomes.cbw$swiss, est_eastern=TRUE, covars=TRUE, rev=TRUE, R=999, parallel = "multicore", l=bopt.eastern, sim = "geom", best_L=mc.estimates.cbw.eastern$best_lambda_L, best_B=mc.estimates.cbw.eastern$best_lambda_B) 
  saveRDS(boot.eastern, paste0("results/boot-cbw-eastern-",o,"-covars.rds")) 
  
  boot.swiss <- tsboot(tseries=t(outcomes.cbw$M), MCEstBoot, mask=outcomes.cbw$mask, W=outcomes.cbw$W, X=outcomes.cbw$X, X.hat=outcomes.cbw$X.hat, 
                         z.cbw.eastern =outcomes.cbw$z.cbw.eastern, z.cbw.swiss = outcomes.cbw$z.cbw.swiss, eastern=outcomes.cbw$eastern, swiss=outcomes.cbw$swiss, est_swiss=TRUE, covars=TRUE, rev=TRUE, R=999, parallel = "multicore", l=bopt.swiss, sim = "geom", best_L=mc.estimates.cbw.swiss$best_lambda_L, best_B=mc.estimates.cbw.swiss$best_lambda_B) 
  saveRDS(boot.swiss, paste0("results/boot-cbw-swiss-",o,"-covars.rds")) 
  
  # Bootstrap for trajectories
  # Resample trajectories without time component, calculate ATTs for each cluster
  source("MCEstBootTraj.R")
  
  impact.eastern <- mc.estimates.cbw.eastern$impact 
  impact.swiss <- mc.estimates.cbw.swiss$impact
  
  # eastern
  
  boot.trajectory.eastern <- boot(impact.eastern, 
                                    MCEstBootTraj, 
                                    R=999,
                                    start=which(colnames(outcomes.cbw$mask)==20051),
                                    t0.eastern=which(colnames(outcomes.cbw$mask)==20111), # t0-1 in MCEstBootTraj,
                                    eastern=outcomes.cbw$eastern,
                                    parallel = "multicore") 
  
  print(paste0("Eastern t-stat: Combined treatment effect (20051-20104): ", boot.trajectory.eastern$t0))
  print(boot.ci(boot.trajectory.eastern, type=c("norm","basic", "perc")))
  
  boot.t.eastern.null <- boot.trajectory.eastern$t - mean(boot.trajectory.eastern$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.eastern.pval <- (1+sum( abs(boot.t.eastern.null) > abs(boot.trajectory.eastern$t0)))/(999+1)

  print(paste0("Eastern p-val: Combined treatment effect (20051-20104): ", boot.trajectory.eastern.pval))
  
  print(paste0("Eastern effect share: Combined treatment effect (20051-20104): ", (boot.trajectory.eastern$t0)/mean(outcomes.cbw$M[rownames(outcomes.cbw$M)%in%outcomes.cbw$eastern,][,1:(which(colnames(outcomes.cbw$mask)==20111)-1)])))
  
  saveRDS(boot.trajectory.eastern, paste0("results/boot-cbw-trajectory-eastern-",o,"-covars.rds")) 

  # swiss
  
  boot.trajectory.swiss <- boot(impact.swiss, 
                                  MCEstBootTraj, 
                                  R=999,
                                  start=which(colnames(outcomes.cbw$mask)==20051),
                                  t0.swiss=which(colnames(outcomes.cbw$mask)==20091),
                                  swiss=outcomes.cbw$swiss,
                                  parallel = "multicore") 
  
  print(paste0("Swiss t-stat: Combined treatment effect (20051-20084): ", boot.trajectory.swiss$t0))
  print(boot.ci(boot.trajectory.swiss, type=c("norm","basic", "perc")))
  
  boot.t.swiss.null <- boot.trajectory.swiss$t - mean(boot.trajectory.swiss$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.swiss.pval <- (1+sum( abs(boot.t.swiss.null) > abs(boot.trajectory.swiss$t0)))/(999+1)
  
  print(paste0("Swiss p-val: Combined treatment effect (20051-20084): ", boot.trajectory.swiss.pval)) # p-val for percentile bootstrap
  
  print(paste0("Swiss effect share: Combined treatment effect (20051-20084): ", (boot.trajectory.swiss$t0)/mean(outcomes.cbw$M[rownames(outcomes.cbw$M)%in%outcomes.cbw$swiss,][,1:(which(colnames(outcomes.cbw$mask)==20091)-1)])))
  
  saveRDS(boot.trajectory.swiss, paste0("results/boot-cbw-trajectory-swiss-",o,"-covars.rds")) 
  
  # eastern (1)
  
  boot.trajectory.eastern.1 <- boot(impact.eastern, 
                                  MCEstBootTraj, 
                                  R=999,
                                  start=which(colnames(outcomes.cbw$mask)==20051),
                                  t0.eastern=which(colnames(outcomes.cbw$mask)==20081),
                                  eastern=outcomes.cbw$eastern,
                                  parallel = "multicore") 
  
  print(paste0("Eastern t-stat: partial treatment effect (20051-20074): ", boot.trajectory.eastern.1$t0))
  print(boot.ci(boot.trajectory.eastern.1, type=c("norm","basic", "perc")))
  
  boot.t.eastern.1.null <- boot.trajectory.eastern.1$t - mean(boot.trajectory.eastern.1$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.eastern.1.pval <- (1+sum( abs(boot.t.eastern.1.null) > abs(boot.trajectory.eastern.1$t0)))/(999+1)
  
  print(paste0("Eastern p-val: partial treatment effect (20051-20074): ", boot.trajectory.eastern.1.pval)) # p-val for percentile bootstrap
  
  saveRDS(boot.trajectory.eastern.1, paste0("results/boot-cbw-trajectory-eastern-1-",o,"-covars.rds")) 
  
  # swiss (1)
  
  boot.trajectory.swiss.1 <- boot(impact.swiss, 
                                MCEstBootTraj, 
                                start=which(colnames(outcomes.cbw$mask)==20051),
                                t0.swiss=which(colnames(outcomes.cbw$mask)==20071),
                                swiss=outcomes.cbw$swiss,
                                R=999,
                                parallel = "multicore") 
  
  print(paste0("Swiss t-stat: partial treatment effect (20051-20072): ", boot.trajectory.swiss.1$t0))
  print(boot.ci(boot.trajectory.swiss.1,type=c("norm","basic", "perc")))
  
  boot.t.swiss.1.null <- boot.trajectory.swiss.1$t - mean(boot.trajectory.swiss.1$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.swiss.1.pval <- (1+sum( abs(boot.t.swiss.1.null) > abs(boot.trajectory.swiss.1$t0)))/(999+1)
  
  print(paste0("Swiss p-val: partial treatment effect (20051-20072): ", boot.trajectory.swiss.1.pval)) # p-val for percentile bootstrap
  
  saveRDS(boot.trajectory.swiss.1, paste0("results/boot-cbw-trajectory-swiss-1-",o,"-covars.rds"))
  
  # eastern (2)
  
  boot.trajectory.eastern.2 <- boot(impact.eastern, 
                                    MCEstBootTraj, 
                                    R=999,
                                    t0.eastern=which(colnames(outcomes.cbw$mask)==20111),
                                    eastern=outcomes.cbw$eastern,
                                    start= which(colnames(outcomes.cbw$mask)==20081),
                                    parallel = "multicore") 
  
  print(paste0("Eastern t-stat: partial treatment effect (20081-20104): ", boot.trajectory.eastern.2$t0))
  print(boot.ci(boot.trajectory.eastern.2,type=c("norm","basic", "perc")))
  
  boot.t.eastern.2.null <- boot.trajectory.eastern.2$t - mean(boot.trajectory.eastern.2$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.eastern.2.pval <- (1+sum( abs(boot.t.eastern.2.null) > abs(boot.trajectory.eastern.2$t0)))/(999+1)
  
  print(paste0("Eastern p-val: partial treatment effect (20081-20104): ", boot.trajectory.eastern.2.pval)) # p-val for percentile bootstrap
  
  saveRDS(boot.trajectory.eastern.2, paste0("results/boot-cbw-trajectory-eastern-2-",o,"-covars.rds")) 
  
  # swiss (2)
  
  boot.trajectory.swiss.2 <- boot(impact.swiss, 
                                  MCEstBootTraj, 
                                  t0.swiss=which(colnames(outcomes.cbw$mask)==20091),
                                  swiss=outcomes.cbw$swiss,
                                  start= which(colnames(outcomes.cbw$mask)==20073),
                                  R=999,
                                  parallel = "multicore") 
  
  print(paste0("Swiss t-stat: partial treatment effect (20073-20084): ", boot.trajectory.swiss.2$t0))
  print(boot.ci(boot.trajectory.swiss.2,type=c("norm","basic", "perc")))
  
  boot.t.swiss.2.null <- boot.trajectory.swiss.2$t - mean(boot.trajectory.swiss.2$t,na.rm = TRUE) # center around zero
  
  boot.trajectory.swiss.2.pval <- (1+sum( abs(boot.t.swiss.2.null) > abs(boot.trajectory.swiss.2$t0)))/(999+1)
  
  print(paste0("Swiss p-val: partial treatment effect (20073-20084): ", boot.trajectory.swiss.2.pval)) # p-val for percentile bootstrap
  
  saveRDS(boot.trajectory.swiss.2, paste0("results/boot-cbw-trajectory-swiss-2-",o,"-covars.rds")) 
}