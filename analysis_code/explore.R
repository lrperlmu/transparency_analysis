rm(list = ls())
PATH_TO_THIS_FILE = "~/Desktop/winter_2016/consulting/Leah Perlmutter (cs)/transparency_analysis/analysis_code/"
warning(paste("The path", PATH_TO_THIS_FILE, "should point to transparency_analysis_functions.Rmd and transparency_analysis_script.Rmd."))
setwd(PATH_TO_THIS_FILE)
require(knitr)
knitr::purl("transparency_analysis_functions.Rmd")
source("transparency_analysis_functions.R")

ggplot(data = get_long_format_data("completion_times")) + 
  geom_line(aes(y = log(task_metric), x = condition, 
                group = ids, colour = ids))

ggplot(data = get_long_format_data("number_of_attempts")) + 
  geom_boxplot(aes(y = log(task_metric), x = condition))

sigma1 = c()
sigma2 = c()
for(task_metric in QUANTITATIVE_METRICS){
  mod_p1 = fit_reg(task_metric, which_analysis = 2, part = "p1")
  mod_p2 = fit_reg(task_metric, which_analysis = 2, part = "p2")
  sigma1 = c(sigma1, sigma(mod_p1))
  sigma2 = c(sigma2, sigma(mod_p2))
}
data.frame(sigma1, sigma2)
data.frame(QUANTITATIVE_METRICS, nice_round(sigma2/sigma1))

task_metric = "attempt_times"
fit_reg(task_metric, which_analysis = 2)
