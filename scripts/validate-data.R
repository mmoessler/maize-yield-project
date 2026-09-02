# Topic: Validate the fixed FAOSTAT teaching extract without modifying it.

# 00) Setup ----

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("digest", "dplyr", "here", "readr", "tidyr", "yaml"))

library(dplyr)
library(here)
library(readr)
library(tidyr)

# 01) Check artifacts before ----

input_file <- here("data", "input", "faostat-maize-yield-sample.csv")
output_file <- here("results", "tables", "data-validation-results.csv")
provenance_file <- here("metadata", "provenance.yml")
dictionary_file <- here("metadata", "faostat-maize-yield-data-dictionary.csv")
flag_code_file <- here("metadata", "faostat-flag-code-list.csv")
source_metadata_file <- here("metadata", "source-metadata.yml")

step_script <- "scripts/validate-data.R"
step_topic <- "data-management"
step_inputs <- c(
  input_file,
  provenance_file,
  dictionary_file,
  flag_code_file,
  source_metadata_file
)
step_outputs <- output_file
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

# 02) Validate data ----

expected_countries <- c(
  "Botswana", "Eswatini", "Lesotho", "Malawi", "Mozambique",
  "Namibia", "South Africa", "Zambia", "Zimbabwe"
)
expected_pairs <- c(
  "Area harvested|ha",
  "Production|t",
  "Yield|kg/ha"
)
candidate_key <- c("area", "item", "element", "year", "unit")

if (!file.exists(input_file)) {
  stop("Teaching input not found: ", input_file, call. = FALSE)
}

required_metadata_files <- c(
  provenance_file,
  dictionary_file,
  flag_code_file,
  source_metadata_file
)
missing_metadata_files <- required_metadata_files[!file.exists(required_metadata_files)]

if (length(missing_metadata_files) > 0) {
  stop(
    "Required metadata file(s) not found: ",
    paste(missing_metadata_files, collapse = ", "),
    call. = FALSE
  )
}

provenance <- yaml::read_yaml(provenance_file)
source_metadata <- yaml::read_yaml(source_metadata_file)
dictionary <- read_csv(dictionary_file, show_col_types = FALSE)
flag_codes <- read_csv(flag_code_file, show_col_types = FALSE)
expected_columns <- dictionary$variable
expected_flags <- flag_codes$flag
faostat_records <- Filter(
  function(record) identical(record$artifact_id, "faostat_maize_snapshot"),
  provenance$artifacts
)

if (length(faostat_records) != 1L) {
  stop("Provenance must contain exactly one FAOSTAT snapshot record.", call. = FALSE)
}

faostat_record <- faostat_records[[1]]
faostat_sources <- Filter(
  function(source) identical(source$source_id, faostat_record$source_id),
  source_metadata$sources
)
if (length(faostat_sources) != 1L) {
  stop("Source metadata must contain exactly one linked FAOSTAT source.", call. = FALSE)
}
faostat_source <- faostat_sources[[1]]
expected_checksum <- faostat_record$checksum_sha256
expected_rows <- as.integer(faostat_record$rows_excluding_header)

if (!identical(faostat_record$artifact, "data/input/faostat-maize-yield-sample.csv")) {
  stop("The provenance record identifies an unexpected artifact.", call. = FALSE)
}

results <- tibble(
  check = character(),
  dimension = character(),
  status = character(),
  expectation = character(),
  observed = character()
)

record_status <- function(check, dimension, status, expectation, observed) {
  allowed_statuses <- c("pass", "warning", "failure", "unknown")

  if (!status %in% allowed_statuses) {
    stop("Unsupported validation status: ", status, call. = FALSE)
  }

  results <<- add_row(
    results,
    check = check,
    dimension = dimension,
    status = status,
    expectation = as.character(expectation),
    observed = as.character(observed)
  )
}

record_check <- function(check, dimension, passed, expectation, observed,
                         failed_status = "failure") {
  record_status(
    check,
    dimension,
    if (isTRUE(passed)) "pass" else failed_status,
    expectation,
    observed
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
record_check(
  "source-metadata-link", "metadata",
  identical(faostat_record$source_id, faostat_source$source_id),
  faostat_record$source_id, faostat_source$source_id
)
record_check(
  "source-yield-unit", "metadata",
  identical(faostat_source$units$Yield, "kg/ha"),
  "kg/ha", faostat_source$units$Yield
)

maize <- read_csv(input_file, show_col_types = FALSE)

columns_match <- identical(names(maize), expected_columns)
record_check(
  "required-columns", "validity",
  columns_match,
  paste(expected_columns, collapse = ", "),
  paste(names(maize), collapse = ", ")
)

if (!columns_match) {
  write_csv(results, output_file, na = "")
  stop(
    "Data validation failed: required-columns. Results written to: ",
    output_file,
    call. = FALSE
  )
}

observed_types <- vapply(
  maize,
  function(column) {
    if (is.character(column)) return("character")
    if (is.integer(column)) return("integer")
    if (is.numeric(column) && all(is.na(column) | column == floor(column))) {
      return("integer")
    }
    if (is.numeric(column)) return("double")
    class(column)[[1]]
  },
  FUN.VALUE = character(1)
)
expected_types <- setNames(dictionary$type, dictionary$variable)
type_mismatches <- names(expected_types)[observed_types[names(expected_types)] != expected_types]
record_check(
  "dictionary-types", "validity", length(type_mismatches) == 0L,
  paste(paste(names(expected_types), expected_types, sep = ": "), collapse = "; "),
  if (length(type_mismatches) == 0L) {
    "all imported types match the data dictionary"
  } else {
    paste(
      paste(
        type_mismatches,
        observed_types[type_mismatches],
        sep = ": "
      ),
      collapse = "; "
    )
  }
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

incomplete_groups <- maize |>
  count(area, year, name = "records") |>
  filter(records != length(expected_pairs))
record_check(
  "country-year-completeness", "completeness", nrow(incomplete_groups) == 0L,
  paste(length(expected_pairs), "element/unit records per country-year"),
  paste(nrow(incomplete_groups), "incomplete country-year groups")
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

record_status(
  "provider-accuracy", "fitness-for-purpose", "unknown",
  "provider values accurately represent agricultural conditions",
  "cannot be established from the teaching CSV; consult source methods and subject-matter evidence"
)
record_status(
  "cross-country-comparability", "fitness-for-purpose", "unknown",
  "definitions and reporting practices are comparable across countries and years",
  "cannot be established from internal validation alone"
)

# 03) Write validation results ----

write_csv(results, output_file, na = "")

# 04) Check artifacts after ----

check_artifact_state(
  step_outputs,
  step_script,
  phase = "after",
  topic = step_topic
)

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
