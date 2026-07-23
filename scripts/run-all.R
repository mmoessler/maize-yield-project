# Run the complete teaching workflow from the repository root.

scripts <- c(
  "scripts/01-acquire-faostat-data.R",
  "scripts/02-prepare-maize-data.R",
  "scripts/03-explore-maize-data.R",
  "scripts/04-model-maize-yield.R"
)

for (script in scripts) {
  message("Running ", script)
  source(script, echo = FALSE)
}

if (nzchar(Sys.which("quarto"))) {
  system2("quarto", c("render", "reports/maize-yield-report.qmd"))
} else {
  message("Quarto was not found. Render reports/maize-yield-report.qmd manually.")
}
