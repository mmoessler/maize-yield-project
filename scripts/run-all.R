# Topic: Run the complete teaching workflow from the repository root.

# 00) Setup ----

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages()

# 01) Run the analysis stages ----

scripts <- c(
  "scripts/validate-data.R",
  "scripts/prepare-maize-data.R",
  "scripts/integrate-data.R",
  "scripts/visualize-maize-data.R",
  "scripts/describe-maize-data.R",
  "scripts/explain-maize-yield.R",
  "scripts/model-maize-yield.R"
)

for (script in scripts) {
  message("Running ", script)
  source(script, echo = FALSE)
}

# 02) Render the reports ----

if (nzchar(Sys.which("quarto"))) {
  reports <- c(
    "reports/data-validation.qmd",
    "reports/data-integration.qmd",
    "reports/data-visualization.qmd",
    "reports/descriptive-data-analysis.qmd",
    "reports/explanatory-modeling.qmd",
    "reports/predictive-modeling.qmd",
    "reports/maize-yield-report.qmd"
  )
  report_topics <- c(
    "reports/data-validation.qmd" = "data-management",
    "reports/data-integration.qmd" = "data-integration",
    "reports/data-visualization.qmd" = "data-visualization",
    "reports/descriptive-data-analysis.qmd" = "descriptive-analysis",
    "reports/explanatory-modeling.qmd" = "explanatory-analysis",
    "reports/predictive-modeling.qmd" = "predictive-analysis",
    "reports/maize-yield-report.qmd" = "course-project"
  )

  for (report in reports) {
    report_output <- sub("\\.qmd$", ".html", report)
    check_artifact_state(
      c(report, report_output),
      report,
      phase = "before"
    )
    status <- system2("quarto", c("render", report))

    if (!identical(status, 0L)) {
      stop("Quarto failed to render: ", report, call. = FALSE)
    }
    check_artifact_state(
      report_output,
      report,
      phase = "after",
      topic = unname(report_topics[[report]])
    )
  }
} else {
  message("Quarto was not found. Render the reports in reports/ manually.")
}
