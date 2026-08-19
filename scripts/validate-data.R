# Validate the fixed FAOSTAT teaching extract without modifying it.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("digest", "dplyr", "here", "readr", "tidyr", "yaml"))

library(dplyr)
library(here)
library(readr)
library(tidyr)

input_file <- here("data-raw", "faostat-maize-yield-sample.csv")
output_file <- here("data-processed", "data-validation-results.csv")
provenance_file <- here("metadata", "provenance.yml")

expected_columns <- c("area", "item", "element", "year", "unit", "value", "flag")
expected_countries <- c(
  "Botswana", "Eswatini", "Lesotho", "Malawi", "Mozambique",
  "Namibia", "South Africa", "Zambia", "Zimbabwe"
)
expected_pairs <- c(
  "Area harvested|ha",
  "Production|t",
  "Yield|kg/ha"
)
expected_flags <- c("A", "E", "I", "X")
candidate_key <- c("area", "item", "element", "year", "unit")

if (!file.exists(input_file)) {
  stop("Teaching input not found: ", input_file, call. = FALSE)
}

if (!file.exists(provenance_file)) {
  stop("Provenance record not found: ", provenance_file, call. = FALSE)
}

provenance <- yaml::read_yaml(provenance_file)
faostat_records <- Filter(
  function(record) identical(record$artifact_id, "faostat_maize_snapshot"),
  provenance$artifacts
)

if (length(faostat_records) != 1L) {
  stop("Provenance must contain exactly one FAOSTAT snapshot record.", call. = FALSE)
}

faostat_record <- faostat_records[[1]]
expected_checksum <- faostat_record$checksum_sha256
expected_rows <- as.integer(faostat_record$rows_excluding_header)

if (!identical(faostat_record$artifact, "data-raw/faostat-maize-yield-sample.csv")) {
  stop("The provenance record identifies an unexpected artifact.", call. = FALSE)
}

results <- tibble(
  check = character(),
  dimension = character(),
  status = character(),
  expectation = character(),
  observed = character()
)

record_check <- function(check, dimension, passed, expectation, observed,
                         failed_status = "failure") {
  results <<- add_row(
    results,
    check = check,
    dimension = dimension,
    status = if (isTRUE(passed)) "pass" else failed_status,
    expectation = as.character(expectation),
    observed = as.character(observed)
  )
}

checksum <- digest::digest(
  input_file,
  algo = "sha256",
  serialize = FALSE,
  file = TRUE
)
record_check(
  "source-checksum", "provenance", identical(checksum, expected_checksum),
  expected_checksum, checksum
)

maize <- read_csv(input_file, show_col_types = FALSE)

record_check(
  "required-columns", "validity",
  setequal(names(maize), expected_columns),
  paste(expected_columns, collapse = ", "),
  paste(names(maize), collapse = ", ")
)
record_check(
  "row-count", "completeness", nrow(maize) == expected_rows,
  expected_rows, nrow(maize)
)
record_check(
  "country-coverage", "completeness",
  setequal(unique(maize$area), expected_countries),
  paste(expected_countries, collapse = "; "),
  paste(sort(unique(maize$area)), collapse = "; ")
)
record_check(
  "year-coverage", "completeness",
  identical(range(maize$year, na.rm = TRUE), c(1990, 2022)),
  "1990-2022", paste(range(maize$year, na.rm = TRUE), collapse = "-")
)
record_check(
  "item", "validity",
  identical(unique(maize$item), "Maize (corn)"),
  "Maize (corn)", paste(unique(maize$item), collapse = "; ")
)

observed_pairs <- maize |>
  distinct(element, unit) |>
  transmute(pair = paste(element, unit, sep = "|")) |>
  pull(pair)
record_check(
  "element-unit-pairs", "consistency",
  setequal(observed_pairs, expected_pairs),
  paste(expected_pairs, collapse = "; "),
  paste(sort(observed_pairs), collapse = "; ")
)

observed_flags <- sort(unique(stats::na.omit(maize$flag)))
record_check(
  "known-flags", "validity",
  all(observed_flags %in% expected_flags),
  paste(expected_flags, collapse = "; "),
  paste(observed_flags, collapse = "; ")
)

duplicate_keys <- maize |>
  count(across(all_of(candidate_key)), name = "records") |>
  filter(records > 1)
record_check(
  "candidate-key", "uniqueness", nrow(duplicate_keys) == 0L,
  paste(candidate_key, collapse = " + "),
  paste(nrow(duplicate_keys), "duplicated key combinations")
)

missing_core_values <- maize |>
  summarise(across(all_of(c("area", "item", "element", "year", "unit", "value")), ~ sum(is.na(.x)))) |>
  unlist(use.names = FALSE) |>
  sum()
record_check(
  "missing-core-values", "completeness", missing_core_values == 0L,
  "0 missing values in core fields", missing_core_values
)
record_check(
  "non-negative-values", "plausibility",
  all(is.na(maize$value) | maize$value >= 0),
  "all reported values are non-negative",
  paste(sum(!is.na(maize$value) & maize$value < 0), "negative values")
)

relationships <- maize |>
  select(area, year, element, value) |>
  pivot_wider(names_from = element, values_from = value) |>
  filter(`Area harvested` > 0) |>
  mutate(
    calculated_yield = Production / `Area harvested` * 1000,
    relative_difference = abs(Yield - calculated_yield) /
      pmax(abs(Yield), abs(calculated_yield), 1)
  )
relationship_warnings <- sum(relationships$relative_difference > 0.02, na.rm = TRUE)
record_check(
  "production-area-yield-relationship", "plausibility",
  relationship_warnings == 0L,
  "reported yield is within 2% of production / harvested area where area is positive",
  paste(relationship_warnings, "rows exceed the diagnostic tolerance"),
  failed_status = "warning"
)

write_csv(results, output_file, na = "")
message("Validation results written to: ", output_file)
print(results, n = Inf)

failures <- filter(results, status == "failure")

if (nrow(failures) > 0) {
  stop(
    "Data validation failed: ",
    paste(failures$check, collapse = ", "),
    call. = FALSE
  )
}
