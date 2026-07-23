# Check and install packages used by the teaching project.

required_packages <- c(
  "dplyr", "ggplot2", "here", "janitor", "readr", "rsample",
  "stringr", "tibble", "tidyr", "yardstick"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages)
}

message("Setup complete. Consider running renv::init() and renv::snapshot() to record exact package versions.")
