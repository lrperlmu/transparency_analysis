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
binary_metrics = c("language", "pointing", "accuracy")
task_metrics = c(binary_metrics, 
                 "number_of_words", 
                 "attempt_times", 
                 "completion_times", 
                 "number_of_attempts")
condition_names = c("baseline_P1", "baseline_P2", 
                     "monitor_P1",  "monitor_P2", 
                      "oculus_P1",   "oculus_P2")

get_long_format_data = function(task_metric){
  #load, reshape, and give meaningful names
  fname = paste0("../data/reshaped/", task_metric, ".csv")
  
  wide_data = read.csv(file = fname, comment.char = "#")
  assertthat::assert_that(all( names(wide_data) == c("participant_id", condition_names) ))
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
  if (!task_metric %in% binary_metrics){
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
    if(task_metric %in% binary_metrics){
      my_formula = cbind(task_metric, num_commands - task_metric) ~ (1|ids) + 0 + condition + learning_23
    } else {
      my_formula =log_task_metric ~ (1|ids) + 0 + condition + learning_23
    }
  } 
  if(which_analysis==2){
    if(task_metric %in% binary_metrics){
      my_formula = cbind(task_metric, num_commands - task_metric) ~ (1|ids) + 0 + condition + learning_123
    } else {
      my_formula = log_task_metric ~ (1|ids) + 0 + condition + learning_123
    }
  }   
  
  long_data = get_long_format_data(task_metric)
  
  # call either linear regression (non-binary) or binomial regression (binary)
  if(task_metric %in% binary_metrics){
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
get_pvals = function(task_metric, which_analysis, verbose = FALSE){

  fitted_model = fit_reg(task_metric, which_analysis)
  diffs_H1 = car::linearHypothesis(fitted_model, hypothesis.matrix = c(2, 0, -1,  0, -1,  0, 0)) #H1: main effects
  diffs_H2 = car::linearHypothesis(fitted_model, hypothesis.matrix = c(0, 2,  0, -1,  0, -1, 0)) #H2: aftereffects
  diffs_H3 = car::linearHypothesis(fitted_model, hypothesis.matrix = c(0, 0,  1,  0, -1,  0, 0)) #H3: oculus vs monitor
  diffs_H3_after = car::linearHypothesis(fitted_model, hypothesis.matrix = c(0, 0,  0,  1,  0, -1, 0)) #H3: oculus vs monitor aftereffects
  
  if(verbose){
    print("======================================")
    print(paste0("Running analysis ", which_analysis, " with task metric ",  task_metric))
    print("======================================")
    print("Model term corresponding to difference between oculus and monitor has p-value")
    print(diffs_H3$`Pr(>Chisq)`[2])
    print("Model term corresponding to difference between oculus and monitor aftereffects has p-value")
    print(diffs_H3_after$`Pr(>Chisq)`[2])
    if(which_analysis==2){
      print("Model term corresponding to transparency effects has p-value")
      print(diffs_H1$`Pr(>Chisq)`[2])
      print("Model term corresponding to transparency aftereffects has p-value")
      print(diffs_H2$`Pr(>Chisq)`[2])
    }
  }
  return( list(which_analysis = which_analysis, 
               fitted_model = fitted_model, 
               pH1 = diffs_H1$`Pr(>Chisq)`[2],
               pH2 = diffs_H2$`Pr(>Chisq)`[2],
               pH3 = diffs_H3$`Pr(>Chisq)`[2],
               pH3a = diffs_H3_after$`Pr(>Chisq)`[2]) )
}

## ------------------------------------------------------------------------
print_tables_A1A2 = function(){
  make_diagnostic_plots
  for(i in 1:2){
    cat(paste0("###Analysis ", i)[1])
    test_results = as.list(seq_along(task_metrics))
    my_table = data.frame(task_metric = task_metrics,
                          H3a_pval = seq_along(task_metrics),
                          H3_pval = seq_along(task_metrics),
                          H2_pval = seq_along(task_metrics),
                          H1_pval = seq_along(task_metrics) )
    
    for(j in seq_along(task_metrics)){
      test_results[[j]] = get_pvals(task_metrics[j], which_analysis = i)
      my_table$H3a_pval[j] = test_results[[j]]$pH3a
      my_table$H3_pval[j] = test_results[[j]]$pH3
      my_table$H2_pval[j] = test_results[[j]]$pH2
      my_table$H1_pval[j] = test_results[[j]]$pH1
    }
    if(i==1){
      my_table$H2_pval = NULL
      my_table$H1_pval = NULL
    }
    print(xtable::xtable(my_table), type = "html")
  }
}

## ------------------------------------------------------------------------
print_diagnostics = function(){
  for(i in 1:2){
    cat("  \n  \n")
    cat("####Analysis 1")
    for(task_metric in task_metrics){
      cat("  \n  \n")
      cat("#####Task metric", task_metric, "  \n")
      make_diagnostic_plots(task_metric, i)
    }
  }
}

