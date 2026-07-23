FROM rocker/verse:4.4.0

WORKDIR /work

RUN Rscript -e ' \
  options(repos = c(CRAN = "https://cloud.r-project.org")); \
  packages <- c( \
    "dplyr", "ggplot2", "here", "janitor", "readr", \
    "rsample", "stringr", "tibble", "tidyr", "yardstick" \
  ); \
  install.packages(packages, dependencies = NA); \
  missing <- packages[!vapply( \
    packages, requireNamespace, logical(1), quietly = TRUE \
  )]; \
  if (length(missing)) { \
    stop("Package installation failed for: ", paste(missing, collapse = ", ")) \
  } \
'
