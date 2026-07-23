# Bootstrap and verify the reproducible R package environment.
#
# Run from the project root:
#
#   Rscript scripts/00-setup.R
#
# On a fresh checkout, this script installs renv if necessary and restores
# the package versions recorded in renv.lock.

project_root <- normalizePath(".", mustWork = TRUE)
lockfile <- file.path(project_root, "renv.lock")

if (!file.exists(lockfile)) {
  stop(
    "Could not find renv.lock.\n",
    "Run this script from the project root."
  )
}

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

message("Setup complete: the project library matches renv.lock.")
