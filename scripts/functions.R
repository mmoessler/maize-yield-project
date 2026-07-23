# Reusable helper functions.

safe_log <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log(x))
}

mae_vec <- function(truth, estimate) {
  mean(abs(truth - estimate), na.rm = TRUE)
}

rmse_vec <- function(truth, estimate) {
  sqrt(mean((truth - estimate)^2, na.rm = TRUE))
}
