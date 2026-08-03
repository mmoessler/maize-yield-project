# Bootstrap and verify the reproducible R package environment.
#
# Run from the project root:
#
#   Rscript scripts/setup.R
#
# On a fresh checkout, this script installs renv if necessary and restores
# the package versions recorded in renv.lock.

source("scripts/functions.R")

project_root <- assert_project_root()
lockfile <- file.path(project_root, "renv.lock")

ensure_project_directories()

# Install renv only when it is not already available.
if (!requireNamespace("renv", quietly = TRUE)) {
  message("The renv package is not available. Installing renv...")

  install.packages(
    "renv",
    repos = "https://cloud.r-project.org"
  )
}

message("Restoring the package environment from renv.lock...")

renv::restore(
  project = project_root,
  lockfile = lockfile,
  prompt = FALSE
)

message("Checking the project environment...")

status <- renv::status(project = project_root)

if (!isTRUE(status$synchronized)) {
  stop(
    "The project library is not synchronized with renv.lock.\n",
    "Review the output from renv::status()."
  )
}

check_required_packages()

message(
  "Setup complete: the project library matches renv.lock and ",
  "required directories are available."
)
