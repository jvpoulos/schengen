MCEst <- function(outcomes,cluster=c('eastern','swiss'),rev=TRUE,covars=TRUE,prop.model=FALSE) {
  
  if(cluster=='eastern'){
    Y <- outcomes$M[!rownames(outcomes$M)%in%outcomes$swiss,] # NxT
  }else{
    Y <- outcomes$M[!rownames(outcomes$M)%in%outcomes$eastern,] # NxT
  }
  
  treat <- outcomes$mask
  treat <- treat[rownames(treat) %in% row.names(Y),]
  
  N <- nrow(treat)
  T <- ncol(treat)
  
  treat_mat <- 1-treat
  
  Y_obs <- Y * treat_mat
  
  W <- outcomes$W
  W <- W[rownames(W) %in% row.names(Y),]
  W <- W[row.names(Y),]  # ensure correct order
  W[W<=0] <- min(W[W>0]) # set floor
  W[W>=1] <- max(W[W<1]) # set ceiling
  
  z.cbw.eastern <- outcomes$z.cbw.eastern
  z.cbw.swiss <- outcomes$z.cbw.eastern
  
  weights <- matrix(NA, nrow=nrow(W), ncol=ncol(W), dimnames = list(rownames(W), colnames(W)))
  weights <- (1-treat_mat) + (treat_mat)*((1-W)/(W)) 
  weights[rownames(weights) %in% outcomes$eastern,] <- weights[rownames(weights) %in% outcomes$eastern,] %*%diag(z.cbw.eastern)
  weights[rownames(weights) %in% outcomes$swiss,] <- weights[rownames(weights) %in% outcomes$swiss,] %*%diag(z.cbw.swiss)
  
  if(covars){
    
    X <- outcomes$X # NxT
    X.hat <- outcomes$X.hat # imputed endogenous values
    
    X <- X[rownames(X) %in% row.names(Y),]
    X.hat <- X.hat[rownames(X.hat) %in% row.names(Y),]
    ## ------
    ## MC-NNM-W
    ## ------
    
    if(prop.model){
      est_model_MCPanel_w <- mcnnm_wc_cv(M = Y_obs, C = X.hat, mask = treat_mat, W = weights, to_normalize = 1, to_estimate_u = 1, to_estimate_v = 1, num_lam_L = 30, num_lam_B = 30, niter = 1000, rel_tol = 1e-05, cv_ratio = 0.8, num_folds = 3, is_quiet = 1) # use X with imputed endogenous values
      est_model_MCPanel_w$Mhat <- est_model_MCPanel_w$L + X.hat%*%replicate(T,as.vector(est_model_MCPanel_w$B)) + replicate(T,est_model_MCPanel_w$u) + t(replicate(N,est_model_MCPanel_w$v)) # use X with imputed endogenous values
      est_model_MCPanel_w$rankL <- rankMatrix(t(est_model_MCPanel_w$L), method="qr.R")[1]
    }else{
      est_model_MCPanel_w <- mcnnm_wc_cv(M = Y_obs, C = X, mask = treat_mat, W = weights, to_normalize = 1, to_estimate_u = 1, to_estimate_v = 1, num_lam_L = 30, num_lam_B = 30, niter = 1000, rel_tol = 1e-05, cv_ratio = 0.8, num_folds = 3, is_quiet = 1) 
      est_model_MCPanel_w$Mhat <- est_model_MCPanel_w$L + X.hat%*%replicate(T,as.vector(est_model_MCPanel_w$B)) + replicate(T,est_model_MCPanel_w$u) + t(replicate(N,est_model_MCPanel_w$v)) # use X with imputed endogenous values
      est_model_MCPanel_w$rankL <- rankMatrix(t(est_model_MCPanel_w$L), method="qr.R")[1]
    }

    if(rev){
      est_model_MCPanel_w$impact <- (est_model_MCPanel_w$Mhat-Y)
    }else{
      est_model_MCPanel_w$impact <- (Y-est_model_MCPanel_w$Mhat)
    }
    
    return(est_model_MCPanel_w)
  } else{
    ## ------
    ## MC-NNM
    ## ------
    
    est_model_MCPanel <- mcnnm_cv(M = Y_obs, mask = treat_mat, W = weights, to_estimate_u = 1, to_estimate_v = 1, num_lam_L = 100, niter = 1000, rel_tol = 1e-05, cv_ratio = 0.8, num_folds = 5, is_quiet = 1)
    est_model_MCPanel$Mhat <- est_model_MCPanel$L + replicate(T,est_model_MCPanel$u) + t(replicate(N,est_model_MCPanel$v))
    est_model_MCPanel$rankL <- rankMatrix(t(est_model_MCPanel$L), method="qr.R")[1]
    
    if(rev){
      est_model_MCPanel$impact <- (est_model_MCPanel$Mhat-Y)
    }else{
      est_model_MCPanel$impact <- (Y-est_model_MCPanel$Mhat)
    }
    
    return(est_model_MCPanel)
  }
}