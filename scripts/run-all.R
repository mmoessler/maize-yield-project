# Run the complete teaching workflow from the repository root.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages()

scripts <- c(
  "scripts/validate-data.R",
  "scripts/prepare-maize-data.R",
  "scripts/integrate-data.R",
  "scripts/explore-maize-data.R",
  "scripts/model-maize-yield.R"
)

for (script in scripts) {
  message("Running ", script)
  source(script, echo = FALSE)
}

if (nzchar(Sys.which("quarto"))) {
  reports <- c(
    "reports/data-validation.qmd",
    "reports/data-integration.qmd",
    "reports/maize-yield-report.qmd"
  )

  for (report in reports) {
    status <- system2("quarto", c("render", report))

    if (!identical(status, 0L)) {
      stop("Quarto failed to render: ", report, call. = FALSE)
    }
  }
} else {
  message("Quarto was not found. Render the reports in reports/ manually.")
}
