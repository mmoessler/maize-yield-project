# Prepare the fixed FAOSTAT public agricultural expenditure teaching sample.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c(
  "digest", "dplyr", "here", "janitor", "readr", "tibble", "yaml"
))

library(digest)
library(dplyr)
library(here)
library(janitor)
library(readr)
library(tibble)
library(yaml)

input_file <- here(
  "data", "input", "faostat-public-agricultural-expenditure-sample.csv"
)
output_file <- here(
  "data", "derived", "public-agricultural-expenditure-panel.csv"
)
audit_file <- here(
  "results", "tables",
  "public-agricultural-expenditure-preparation-audit.csv"
)
provenance_file <- here("metadata", "provenance.yml")

required_files <- c(input_file, provenance_file)
missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Preparation input(s) not found: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

provenance <- read_yaml(provenance_file)
expenditure_record <- Filter(
  function(record) {
    identical(record$artifact_id, "faostat_public_agricultural_expenditure_snapshot")
  },
  provenance$artifacts
)

if (length(expenditure_record) != 1L) {
  stop(
    "Provenance must contain exactly one public agricultural expenditure ",
    "snapshot record.",
    call. = FALSE
  )
}

observed_checksum <- digest(
  input_file,
  algo = "sha256",
  serialize = FALSE,
  file = TRUE
)
expected_checksum <- expenditure_record[[1]]$checksum_sha256

if (!identical(observed_checksum, expected_checksum)) {
  stop(
    "Public agricultural expenditure snapshot checksum does not match ",
    "metadata/provenance.yml.",
    call. = FALSE
  )
}

raw <- read_csv(input_file, show_col_types = FALSE) |>
  clean_names()

required_columns <- c(
  "area", "item", "element", "year", "unit", "value", "flag", "note"
)
missing_columns <- setdiff(required_columns, names(raw))

if (length(missing_columns) > 0) {
  stop(
    "Teaching sample is missing column(s): ",
    paste(missing_columns, collapse = ", ")
  )
}

expected_item <- "SDG 2.a.1: highest government level"
expected_element <- paste(
  "SDG 2.a.1: Agriculture share of Government Expenditure"
)

if (!setequal(unique(raw$item), expected_item)) {
  stop("The teaching sample contains an unexpected FAOSTAT item.")
}

if (!setequal(unique(raw$element), expected_element)) {
  stop("The teaching sample contains an unexpected FAOSTAT element.")
}

if (!setequal(unique(raw$unit), "%")) {
  stop("The teaching sample must express the expenditure share in percent.")
}

if (n_distinct(raw$area) != 9L || !identical(range(raw$year), c(2001, 2022))) {
  stop("The sample must represent nine countries within 2001-2022.")
}

candidate_key <- c("area", "item", "element", "year", "unit")
input_key_duplicates <- raw |>
  count(across(all_of(candidate_key))) |>
  filter(n > 1) |>
  nrow()

if (input_key_duplicates > 0) {
  stop("Teaching sample contains duplicate candidate keys.")
}

panel <- raw |>
  transmute(
    country = area,
    year = as.integer(year),
    agriculture_share_government_expenditure_percent = as.numeric(value),
    source_flag = flag,
    government_level = note
  ) |>
  arrange(country, year)

output_key_duplicates <- panel |>
  count(country, year) |>
  filter(n > 1) |>
  nrow()

if (output_key_duplicates > 0) {
  stop("Prepared expenditure panel contains duplicate country-year keys.")
}

if (any(
  panel$agriculture_share_government_expenditure_percent < 0 |
    panel$agriculture_share_government_expenditure_percent > 100,
  na.rm = TRUE
)) {
  stop("Prepared expenditure shares must fall between 0 and 100 percent.")
}

country_coverage <- panel |>
  count(country, name = "observations")
complete_countries <- sum(country_coverage$observations == 22L)
zimbabwe_observations <- country_coverage |>
  filter(country == "Zimbabwe") |>
  pull(observations)

audit <- tribble(
  ~check, ~expectation, ~observed, ~status,
  "input-checksum", expected_checksum, observed_checksum,
  if_else(identical(observed_checksum, expected_checksum), "pass", "failure"),
  "input-rows", "180", as.character(nrow(raw)),
  if_else(nrow(raw) == 180L, "pass", "failure"),
  "input-countries", "9", as.character(n_distinct(raw$area)),
  if_else(n_distinct(raw$area) == 9L, "pass", "failure"),
  "observed-year-range", "2001-2022", paste(range(raw$year), collapse = "-"),
  if_else(identical(range(raw$year), c(2001, 2022)), "pass", "failure"),
  "input-key-duplicates", "0", as.character(input_key_duplicates),
  if_else(input_key_duplicates == 0L, "pass", "failure"),
  "output-key-duplicates", "0", as.character(output_key_duplicates),
  if_else(output_key_duplicates == 0L, "pass", "failure"),
  "share-range", "0-100", paste(range(
    panel$agriculture_share_government_expenditure_percent,
    na.rm = TRUE
  ), collapse = "-"),
  if_else(all(
    panel$agriculture_share_government_expenditure_percent >= 0 &
      panel$agriculture_share_government_expenditure_percent <= 100,
    na.rm = TRUE
  ), "pass", "failure"),
  "countries-with-complete-2001-2022-coverage", "8",
  as.character(complete_countries),
  if_else(complete_countries == 8L, "pass", "failure"),
  "zimbabwe-observations", "4", as.character(zimbabwe_observations),
  if_else(identical(zimbabwe_observations, 4L), "pass", "failure"),
  "missing-government-level", "0", as.character(sum(is.na(panel$government_level))),
  if_else(sum(is.na(panel$government_level)) == 0L, "pass", "failure")
)

write_csv(audit, audit_file, na = "")

if (any(audit$status == "failure")) {
  stop("Expenditure preparation audit failed; inspect ", audit_file, call. = FALSE)
}

write_csv(panel, output_file, na = "")

message(
  "Prepared public agricultural expenditure data written to: ", output_file,
  "\nPreparation audit written to: ", audit_file,
  "\nCoverage remains intentionally unbalanced."
)
