# Reusable helper functions.

project_directories <- c(
  "data/source",
  "data/input",
  "data/derived",
  "results/tables",
  "results/models",
  "figures",
  "reports"
)

required_project_packages <- c(
  "digest",
  "dplyr",
  "ggplot2",
  "here",
  "janitor",
  "jsonlite",
  "readr",
  "stringr",
  "tibble",
  "tidyr",
  "yaml"
)

assert_project_root <- function() {
  required_paths <- c(
    "renv.lock",
    "scripts/functions.R",
    "maize-yield-project.Rproj"
  )

  missing_paths <- required_paths[!file.exists(required_paths)]

  if (length(missing_paths) > 0) {
    stop(
      "Run this command from the maize-yield project root.\n",
      "Missing expected path(s): ",
      paste(missing_paths, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(normalizePath(".", mustWork = TRUE))
}

ensure_project_directories <- function() {
  for (directory in project_directories) {
    if (!dir.exists(directory)) {
      created <- dir.create(directory, recursive = TRUE)

      if (!isTRUE(created) && !dir.exists(directory)) {
        stop(
          "Could not create project directory: ",
          directory,
          call. = FALSE
        )
      }
    }
  }

  invisible(project_directories)
}

check_required_packages <- function(
  packages = required_project_packages
) {
  missing_packages <- packages[
    !vapply(
      packages,
      requireNamespace,
      quietly = TRUE,
      FUN.VALUE = logical(1)
    )
  ]

  if (length(missing_packages) > 0) {
    stop(
      "The project package environment is incomplete.\n",
      "Missing package(s): ",
      paste(missing_packages, collapse = ", "),
      "\nRun: Rscript scripts/setup.R",
      call. = FALSE
    )
  }

  invisible(packages)
}

safe_log <- function(x) {
  ifelse(is.na(x) | x <= 0, NA_real_, log(x))
}

mae_vec <- function(truth, estimate) {
  mean(abs(truth - estimate), na.rm = TRUE)
}

rmse_vec <- function(truth, estimate) {
  sqrt(mean((truth - estimate)^2, na.rm = TRUE))
}
