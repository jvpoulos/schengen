######################################################################
# Schengen Simulations #
######################################################################

## Loading Source files
library(MCPanel)
library(NNLM)

# Setup parallel processing 
library(parallel)
library(doParallel)

cores <- parallel::detectCores()
print(paste0('cores registered: ', cores))

cl <- makePSOCKcluster(cores)

doParallel::registerDoParallel(cores) # register cores (<p)

SchengenSim <- function(outcome,sim,covars){
  
  outcomes.cbw <- readRDS(paste0("data/outcomes-cbw-",o,".rds"))
  
  # Use post-treatment (all zeros)
  outcomes.cbw.placebo <- outcomes.cbw
  outcomes.cbw.placebo$mask <- outcomes.cbw$mask[,which(colnames(outcomes.cbw$mask)=="20111"):ncol(outcomes.cbw$mask)]
  outcomes.cbw.placebo$M <- outcomes.cbw$M[,which(colnames(outcomes.cbw$mask)=="20111"):ncol(outcomes.cbw$mask)]
  outcomes.cbw.placebo$W <- outcomes.cbw$W[,which(colnames(outcomes.cbw$mask)=="20111"):ncol(outcomes.cbw$mask)]
  outcomes.cbw.placebo$X <- outcomes.cbw$X[,which(colnames(outcomes.cbw$mask)=="20111"):ncol(outcomes.cbw$mask)]
  outcomes.cbw.placebo$X.hat <- outcomes.cbw$X.hat[,which(colnames(outcomes.cbw$mask)=="20111"):ncol(outcomes.cbw$mask)]
  
  Y <- outcomes.cbw.placebo$M # NxT 
  X <- outcomes.cbw.placebo$X # NxT 
  X.hat <- outcomes.cbw.placebo$X # NxT 
  treat <- outcomes.cbw.placebo$mask # NxT masked matrix 
  
  W <- outcomes.cbw.placebo$W
  W <- W[rownames(W) %in% row.names(Y),]
  W <- W[row.names(Y),]  # ensure correct order
  W[W<=0] <- min(W[W>0]) # set floor
  W[W>=1] <- max(W[W<1]) # set ceiling
  
  ## Setting up the configuration
  N <- nrow(treat)
  T <- ncol(treat)
  T0 <- round(c(ncol(outcomes.cbw.placebo$mask)-1, ncol(outcomes.cbw.placebo$mask)/1.25, ncol(outcomes.cbw.placebo$mask)/1.5, ncol(outcomes.cbw.placebo$mask)/2))
  N_t <- ceiling(N*0.5) # no. treated units desired <=N
  num_runs <- 100
  is_simul <- sim ## Whether to simulate Simultaneus Adoption or Staggered Adoption

  ## Matrices for saving RMSE values
  
  MCPanel_RMSE_test <- matrix(0L,num_runs,length(T0))
  DID_RMSE_test <- matrix(0L,num_runs,length(T0))
  ADH_RMSE_test <- matrix(0L,num_runs,length(T0))
  
  ## Run different methods
  
  for(i in c(1:num_runs)){
    print(paste0(paste0("Run number ", i)," started"))
    ## Fix the treated units in the whole run for a better comparison
    treat_indices <- sort(sample(1:N, N_t))
    for (j in c(1:length(T0))){
      t0 <- T0[j]
      ## Simultaneuous (simul_adapt) or Staggered adoption (stag_adapt)
      if(is_simul == 1){
        treat_mat <- simul_adapt(Y, N_t, t0, treat_indices) 
      }else{
        treat_mat <- stag_adapt(Y, N_t, t0, treat_indices) 
      }
      
      rotate <- function(x) t(apply(x, 2, rev))
      
      treat_mat <- rotate(rotate(treat_mat)) # retrospective analysis
      treat_mat_NA <- treat_mat
      treat_mat_NA[treat_mat_NA==0] <- NA # zeros are NA
      
      Y_obs <- Y * treat_mat # treated are 0 
      Y_obs_NA <- Y * treat_mat_NA # treated are NA
      
      z.cbw.eastern <- c(rev(SSlogis(1:t0, Asym = 1, xmid = 0.85, scal = 8)),
                         SSlogis(1:(ncol(treat_mat)-t0), Asym = 1, xmid = 0.85, scal = 8))
      
      z.cbw.swiss <- z.cbw.eastern
  
      weights <- matrix(NA, nrow=nrow(W), ncol=ncol(W), dimnames = list(rownames(W), colnames(W)))
      weights <- (1-treat_mat) + (treat_mat)*((1-W)/(W)) 
      weights[rownames(weights) %in% outcomes.cbw$eastern,] <- weights[rownames(weights) %in% outcomes.cbw.placebo$eastern,] %*%diag(z.cbw.eastern)
      weights[rownames(weights) %in% outcomes.cbw$swiss,] <- weights[rownames(weights) %in% outcomes.cbw.placebo$swiss,] %*%diag(z.cbw.swiss)
      
      ## -----
      ## ADH
      ## -----
      est_model_ADH <- adh_mp_rows(Y_obs, treat_mat, rel_tol = 0.001)
      est_model_ADH_msk_err <- (est_model_ADH - Y)*(1-treat_mat)
      est_model_ADH_test_RMSE <- sqrt((1/sum(1-treat_mat)) * sum(est_model_ADH_msk_err^2, na.rm = TRUE))
      ADH_RMSE_test[i,j] <- est_model_ADH_test_RMSE
      print(paste("ADH RMSE:", round(est_model_ADH_test_RMSE,3),"run",i))
      
      if(covars){
        est_model_MCPanel_w <- mcnnm_wc_cv(M = Y_obs, C = X, mask = treat_mat, W = weights, to_normalize = 1, to_estimate_u = 1, to_estimate_v = 1, num_lam_L = 30, num_lam_B = 30, niter = 1000, rel_tol = 1e-05, cv_ratio = 0.8, num_folds = 3, is_quiet = 1) 
        est_model_MCPanel_w$Mhat <- est_model_MCPanel_w$L + X.hat*mean(est_model_MCPanel_w$B) + replicate(T,est_model_MCPanel_w$u) + t(replicate(N,est_model_MCPanel_w$v)) # use X with imputed endogenous values
        est_model_MCPanel_w$msk_err <- (est_model_MCPanel_w$Mhat - Y)*(1-treat_mat)
        est_model_MCPanel_w$test_RMSE <- sqrt((1/sum(1-treat_mat)) * sum(est_model_MCPanel_w$msk_err^2, na.rm = TRUE))
        MCPanel_RMSE_test[i,j] <- est_model_MCPanel_w$test_RMSE
        print(paste("MC-NNM RMSE:", round(est_model_MCPanel_w$test_RMSE,3),"run",i))
      }
      else{
        ## ------
        ## MC-NNM
        ## ------
        
        est_model_MCPanel <- mcnnm_cv(M = Y_obs, mask = treat_mat, W = weights, to_estimate_u = 1, to_estimate_v = 1, num_lam_L = 100, niter = 1000, rel_tol = 1e-05, cv_ratio = 0.8, num_folds = 5, is_quiet = 1) 
        est_model_MCPanel$Mhat <- est_model_MCPanel$L  + replicate(T,est_model_MCPanel$u) + t(replicate(N,est_model_MCPanel$v)) # use X with imputed endogenous values
        est_model_MCPanel$msk_err <- (est_model_MCPanel$Mhat - Y)*(1-treat_mat)
        est_model_MCPanel$test_RMSE <- sqrt((1/sum(1-treat_mat)) * sum(est_model_MCPanel$msk_err^2, na.rm = TRUE))
        MCPanel_RMSE_test[i,j] <- est_model_MCPanel$test_RMSE
        print(paste("MC-NNM RMSE:", round(est_model_MCPanel$test_RMSE,3),"run",i))
      }
      
      ## -----
      ## DID
      ## -----
      
      est_model_DID <- t(DID(t(Y_obs), t(treat_mat)))
      est_model_DID_msk_err <- (est_model_DID - Y)*(1-treat_mat)
      est_model_DID_test_RMSE <- sqrt((1/sum(1-treat_mat)) * sum(est_model_DID_msk_err^2, na.rm = TRUE))
      DID_RMSE_test[i,j] <- est_model_DID_test_RMSE
      print(paste("DID RMSE:", round(est_model_DID_test_RMSE,3),"run",i))
    }
  }
  
  ## Computing means and standard errors
  
  MCPanel_avg_RMSE <- apply(MCPanel_RMSE_test,2,mean)
  MCPanel_std_error <- apply(MCPanel_RMSE_test,2,sd)/sqrt(num_runs)
  
  DID_avg_RMSE <- apply(DID_RMSE_test,2,mean)
  DID_std_error <- apply(DID_RMSE_test,2,sd)/sqrt(num_runs)
  
  ADH_avg_RMSE <- apply(ADH_RMSE_test,2,mean)
  ADH_std_error <- apply(ADH_RMSE_test,2,sd)/sqrt(num_runs)
  
  ## Saving data
  
  df1 <-
    data.frame(
      "y" =  c(DID_avg_RMSE,MCPanel_avg_RMSE,ADH_avg_RMSE),
      "lb" = c(DID_avg_RMSE - 1.96*DID_std_error,
               MCPanel_avg_RMSE - 1.96*MCPanel_std_error, 
               ADH_avg_RMSE - 1.96*ADH_std_error),
      "ub" = c(DID_avg_RMSE + 1.96*DID_std_error, 
               MCPanel_avg_RMSE + 1.96*MCPanel_std_error, 
               ADH_avg_RMSE + 1.96*ADH_std_error),
      "x" = T0/T,
      "Method" = c(replicate(length(T0),"DID"), 
                   replicate(length(T0),"MC-NNM"), 
                   replicate(length(T0),"SCM")))
  
  filename<-paste0(paste0(paste0(paste0(paste0(paste0(gsub("\\.", "_", o),"_N_", N),"_T_", T),"_numruns_", num_runs), "_num_treated_", N_t), "_simultaneuous_", is_simul,"_covars_",covars),".rds")
  save(df1, file = paste0("results/",filename))

}

# Read data
outcome.vars <- c("CBWbord","CBWbordEMPL")

for(o in outcome.vars){
  for(i in c(0,1)){
    SchengenSim(outcome=o, sim=i,covars = FALSE)
  }
}