## ---- results='hide', message = FALSE, warning = FALSE-------------------
require(lme4)
require(car)
require(assertthat)
require(xtable)
require(ggplot2)

## ------------------------------------------------------------------------
ids = read.table("../data/participant_ids.csv")$V1
ids_monitor_first = ids[ids != 5 & ids %% 2 == 1]
ids_oculus_first = ids[ids == 5 | ids %% 2 == 0]
print(ids_monitor_first)
print(ids_oculus_first)

## ------------------------------------------------------------------------
BINARY_METRICS = c("language", "pointing", "accuracy")
QUANTITATIVE_METRICS = c("number_of_words", 
                         "attempt_times", 
                         "completion_times", 
                         "number_of_attempts")
TASK_METRICS = c(BINARY_METRICS, QUANTITATIVE_METRICS)
TM_WITH_UNITS = c(paste0(BINARY_METRICS, " (Odds)"),
                  paste0(QUANTITATIVE_METRICS, c("", " (sec)", " (sec)", "")))
TM_WITH_EFFECT_UNITS = c(paste0(BINARY_METRICS, " (% change in odds)"),
                         paste0(QUANTITATIVE_METRICS, " (% change)"))
CONDITION_NAMES = c("baseline_P1", "baseline_P2", 
                     "monitor_P1",  "monitor_P2", 
                      "oculus_P1",   "oculus_P2")
CONDITION_NAMES_SHORT = c("B_P1", "B_P2", 
                          "M_P1", "M_P2", 
                          "O_P1", "O_P2")

get_long_format_data = function(task_metric){
  #load, reshape, and give meaningful names
  fname = paste0("../data/reshaped/", task_metric, ".csv")
  
  wide_data = read.csv(file = fname, comment.char = "#")
  assertthat::assert_that(all( names(wide_data) == c("participant_id", CONDITION_NAMES) ))
  long_data = reshape2::melt(wide_data, id.vars = "participant_id") 
  long_data_nice = data.frame(task_metric = numeric(120))
  long_data_nice$task_metric = long_data$value
  long_data_nice$condition = long_data$variable
  long_data_nice$ids = long_data$participant_id
  
  #get total trials for accuracy data: 10 for P1, 5 for P2
  if(task_metric == "accuracy"){
    long_data_nice$num_commands = 
      5 *(long_data_nice$condition %in% c("baseline_P2", "monitor_P2", "oculus_P2")) +
      10*(long_data_nice$condition %in% c("baseline_P1", "monitor_P1", "oculus_P1"))
  } 
  
  #get total trials for pointing and language data
  if(task_metric %in% c("pointing", "language")){
    wide_totals = read.csv(file = paste0("../data/reshaped/", task_metric, "_totals.csv"), comment.char = "#")
    long_totals = reshape2::melt(wide_totals, id.vars = "participant_id") 
    long_data_nice$num_commands = long_totals$value
  } 
  
  #get logs for non-binary data
  if (!task_metric %in% BINARY_METRICS){
    long_data_nice$log_task_metric = log(long_data_nice$task_metric)
  } 

  # Xij = 1 if j = 3, 4 and person i used the monitor last, oculus first
  # Xij = 1 if j = 5, 6 and person i used the oculus last, monitor first
  # 0 otherwise
  long_data_nice$learning_23 = ( long_data_nice$ids %in% ids_oculus_first ) &  
    ( long_data_nice$condition %in% c("monitor_P1", "monitor_P2") )
  long_data_nice$learning_23 = ( long_data_nice$ids %in% ids_monitor_first ) & 
    ( long_data_nice$condition %in% c("oculus_P1", "oculus_P2") )
  
  # Xij' = 1 if j = 3, 4, 5, 6
  # 0 otherwise
  X_prime_ij = long_data_nice$condition %in% c("monitor_P1", "monitor_P2", "oculus_P1", "oculus_P2")
  long_data_nice$learning_123 = X_prime_ij + long_data_nice$learning_23
  
  return(long_data_nice)
}

## ------------------------------------------------------------------------
fit_reg = function(task_metric, which_analysis){

  # specify form of model, varying learning effect based on which analysis 
  # we're doing and response based on binary versus continuous
  assertthat::assert_that(which_analysis %in% 1:2)
  if(which_analysis==1){
    if(task_metric %in% BINARY_METRICS){
      my_formula = cbind(task_metric, num_commands - task_metric) ~ (1|ids) + 0 + condition + learning_23
    } else {
      my_formula =log_task_metric ~ (1|ids) + 0 + condition + learning_23
    }
  } 
  if(which_analysis==2){
    if(task_metric %in% BINARY_METRICS){
      my_formula = cbind(task_metric, num_commands - task_metric) ~ (1|ids) + 0 + condition + learning_123
    } else {
      my_formula = log_task_metric ~ (1|ids) + 0 + condition + learning_123
    }
  }   
  
  long_data = get_long_format_data(task_metric)
  
  # call either linear regression (non-binary) or binomial regression (binary)
  if(task_metric %in% BINARY_METRICS){
    fitted_mod = lme4::glmer(data = long_data, formula = my_formula, 
                            family = binomial())
  } else{
    fitted_mod = lme4::lmer (data = long_data, formula = my_formula)
  }
  
  return(fitted_mod)
}

## ------------------------------------------------------------------------
make_diagnostic_plots = function(task_metric, which_analysis){
  fitted_model = fit_reg(task_metric, which_analysis)
  long_data = fitted_model@frame
  long_data$res = resid(fitted_model)
  long_data$fitted_vals = fitted(fitted_model)
  p1 = ggplot(long_data) + 
    geom_point(aes(y = res, x = fitted_vals)) +
    ggtitle("Rsdl ~ fit values")
  p2 = ggplot(long_data) + 
    geom_boxplot(aes(y = res, x = ids, group = ids)) +
    ggtitle("Rsdl ~ participant")
  p3 = ggplot(long_data, aes(x = res)) + 
    geom_density() + 
    ggtitle("Rsdl")
  print(p1); print(p2); print(p3)
  cat("  \n")
}

## ------------------------------------------------------------------------
HYPOTHESIS_NAMES = c("H1_transp_effects_1=3=5", 
                     "H2_transp_after_effects_2=4=6",
                     "H1_transp_effects_1=3", 
                     "H2_transp_after_effects_2=4",
                     "H1_transp_effects_1=5", 
                     "H2_transp_after_effects_2=6", 
                     "H3_headset_v_monitor",
                     "H3_headset_v_monitor_aftereffect")
get_pvals = function(task_metric, which_analysis){

  fitted_model = fit_reg(task_metric, which_analysis)
  
  #Set up name/contrast corresponding to each test

  the_tests = as.list(HYPOTHESIS_NAMES); names(the_tests) = HYPOTHESIS_NAMES
  #mu1 == mu3 == mu5
  the_tests[[1]] = list(contrast_vector = rbind(c(1, 0, -1,  0,  0,  0, 0),
                                                c(1, 0,  0,  0, -1,  0, 0)))
  #mu2 == mu4 == mu6
  the_tests[[2]] = list(contrast_vector = rbind(c(0, 1,  0, -1,  0,  0, 0),
                                                c(0, 1,  0,  0,  0, -1, 0)))
  #mu1 == mu3
  the_tests[[3]] = list(contrast_vector = rbind(c(1, 0, -1,  0,  0,  0, 0)))
  #mu2 == mu4
  the_tests[[4]] = list(contrast_vector = rbind(c(0, 1,  0, -1,  0,  0, 0)))
  #mu1 == mu5
  the_tests[[5]] = list(contrast_vector = rbind(c(1, 0,  0,  0, -1,  0, 0)))
  #mu2 == mu6
  the_tests[[6]] = list(contrast_vector = rbind(c(0, 1,  0,  0,  0, -1, 0)))
  
  #mu3 == mu5
  the_tests[[7]] = list(contrast_vector = rbind(c(0, 0,  1,  0, -1,  0, 0)))
  
  #mu4 == mu6
  the_tests[[8]] = list(contrast_vector = rbind(c(0, 0,  0,  1,  0, -1, 0)))

  #Exclude some tests
  if(which_analysis == 1){ tests_to_do = 7:8 }
  if(which_analysis == 2){ tests_to_do = 1:6 }
  the_tests = the_tests[tests_to_do]
  
  for(test_ind in seq_along(the_tests)){
    contrast_temp = the_tests[[test_ind]]$contrast_vector
    test_results = car::linearHypothesis(fitted_model, hypothesis.matrix = contrast_temp)
    pval_temp = test_results$`Pr(>Chisq)`[2]
    the_tests[[test_ind]]$pval = pval_temp
    #es_temp = sum(contrast_temp * fitted_model@beta)
    #the_tests[[test_ind]]$effect_size = es_temp
    #the_tests[[test_ind]]$effect_size_se = abs( es_temp / qnorm(pval_temp/2))
  }
  return(the_tests)
}

## ------------------------------------------------------------------------
print_tests_A1A2 = function(){
  #Both analyses
  for(i in 1:2){
    cat(paste0("####Analysis ", i)[1])
    
    my_table = data.frame(matrix(NA, nrow = length(TASK_METRICS), 
                                 ncol = length(HYPOTHESIS_NAMES)))
    names(my_table) = HYPOTHESIS_NAMES
    row.names(my_table) = TASK_METRICS

    #all task metrics
    for(j in seq_along(TASK_METRICS)){
      test_results_temp = get_pvals(TASK_METRICS[j], which_analysis = i)
      for(test_name in names(test_results_temp)){
        my_table[j,test_name] = test_results_temp[[test_name]]$pval
      }
    }
    print(xtable::xtable(my_table, digits = 4), type = "html")
  }
}

## ------------------------------------------------------------------------
print_diagnostics = function(){
  for(i in 1:2){
    cat("  \n  \n")
    cat(paste("####Analysis", i))
    for(task_metric in TASK_METRICS){
      cat("  \n  \n")
      cat("#####Task metric", task_metric, "  \n")
      make_diagnostic_plots(task_metric, i)
    }
  }
}

## ------------------------------------------------------------------------
indicate7 = function(spot){
  indicator = rep(0, 7)
  indicator[spot] = 1
  return(indicator)
}

put_ses_in_parens = function(dirty_df){
  dirty_df = round(dirty_df, 1)
  my_cols = colnames(dirty_df)
  odds = seq_along(my_cols)[seq_along(my_cols) %% 2 == 1]
  clean_df = dirty_df[,odds]
  for(i in 1:(length(my_cols)/2)){
    clean_df[, i] = paste0(dirty_df[, 2*i - 1], "  (", dirty_df[, 2*i], ")")
  } 
  return(clean_df)
}

get_effect_sizes = function(){
  for(i in 1:2){
    cat(paste0("####Analysis ", i)[1])
    
    #Set up contrast vectors

    main_contrasts = lapply(FUN = indicate7, X = as.list(1:6))
    effect_contrasts = list(indicate7(7),
                            indicate7(3) - indicate7(1),
                            indicate7(5) - indicate7(1),
                            indicate7(5) - indicate7(3),
                            indicate7(4) - indicate7(2),
                            indicate7(6) - indicate7(2),
                            indicate7(6) - indicate7(4))
    
    #set up constrast names
    main_ests = paste0(CONDITION_NAMES_SHORT)
    effect_ests = c("LEARN", 
                    "B_to_M_P1",
                    "B_to_O_P1",
                    "M_to_O_P1", 
                    "B_to_M_P2",
                    "B_to_O_P2",
                    "M_to_O_P2")
    main_ses = paste0(main_ests, "_se")
    effect_ses = paste0(effect_ests, "_se")

    #Set up tables
    append_se = function(col_names){
      col_names_se = c()
      for(name in col_names){
        col_names_se = c(col_names_se, name, paste0(name, "_se"))
      }
      return(col_names_se)
    }
    main_colnames = append_se(main_ests)
    effect_colnames = append_se(effect_ests)
    
    main_inds = main_colnames %in% main_ests
    effect_inds = effect_colnames %in% effect_ests

    main_table = matrix(NA,      
                        nrow = length(       TM_WITH_UNITS), ncol = length(main_colnames),
                        dimnames = list(qm = TM_WITH_UNITS,           cn = main_colnames)) 
    effect_table = matrix(NA,    
                          nrow = length(       TM_WITH_EFFECT_UNITS), ncol = length(effect_colnames),
                          dimnames = list(qm = TM_WITH_EFFECT_UNITS,           cn = effect_colnames)) 
    
    #Fill tables
    
    map_to_pct = function(x) (100 * (exp(x) - 1))
    map_to_pct_se = function(listin) (100 * exp(listin$est) * listin$est_se)

    for(j in seq_along(TASK_METRICS)){
      task_j = TASK_METRICS[j]
      fitted_model = fit_reg(task_j, which_analysis = i)
      
      #Fill in estimates

      get_contrast_size = function(x) (fitted_model@beta %*% x)
      get_contrast_se = function(contrast){
        test_res = car::linearHypothesis(model = fitted_model, hypothesis.matrix = contrast)
        pval = test_res$`Pr(>Chisq)`[2]
        #pval = Pr(|z| > | estimate / se |) given z~N(0,1)
        #pval/2 = Pr(z > | estimate / se |)  by symmetry
        #quantile(pval/2) = | estimate / se | by defn of quantile
        #se = | estimate / quantile(pval/2) |
        se = abs(get_contrast_size(contrast) / qnorm(pval/2)) 
        return(list(est = get_contrast_size(contrast), est_se = se))
      } 
        
      temp = lapply(X = main_contrasts,     FUN = get_contrast_size)
      main_table[j, main_inds]     = sapply(FUN = exp, X = temp)
      temp = lapply(X = effect_contrasts,   FUN = get_contrast_size)
      effect_table[j, effect_inds] = sapply(FUN = map_to_pct, X = temp)

      temp_se = lapply(X = main_contrasts, FUN = get_contrast_se)
      main_table[j, !main_inds] = sapply(FUN = map_to_pct_se, X = temp_se)
      temp_se = lapply(X = effect_contrasts, FUN = get_contrast_se)
      effect_table[j, !effect_inds] = sapply(FUN = map_to_pct_se, X = temp_se)
      
    }
    cat(paste0("  \n#####Predictions by condition  \n"))
    print(xtable::xtable(put_ses_in_parens(main_table)), type = "html")
    cat(paste0("  \n#####Predicted effects from changing between conditions \n"))
    print(xtable::xtable(put_ses_in_parens(effect_table)), type = "html")
  }
}

