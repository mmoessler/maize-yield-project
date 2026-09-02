# Topic: Prepare the fixed FAOSTAT maize teaching sample.

# 00) Setup ----

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("digest", "dplyr", "here", "janitor", "readr", "tibble", "tidyr", "yaml"))

library(digest)
library(dplyr)
library(here)
library(janitor)
library(readr)
library(tibble)
library(tidyr)
library(yaml)

# 01) Check artifact before ----

input_file <- here("data", "input", "faostat-maize-yield-sample.csv")
output_file <- here("data", "derived", "maize-yield-panel.csv")
audit_file <- here("results", "tables", "data-preparation-audit.csv")
provenance_file <- here("metadata", "provenance.yml")

step_script <- "scripts/prepare-maize-data.R"
step_inputs <- c(input_file, provenance_file)
step_outputs <- c(output_file, audit_file)
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

# 02) Prepare data ----

required_files <- c(input_file, provenance_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Preparation input(s) not found: ", paste(missing_files, collapse = ", "), call. = FALSE)
}

provenance <- read_yaml(provenance_file)
faostat_record <- Filter(
  function(record) identical(record$artifact_id, "faostat_maize_snapshot"),
  provenance$artifacts
)
if (length(faostat_record) != 1L) {
  stop("Provenance must contain exactly one FAOSTAT snapshot record.", call. = FALSE)
}

observed_checksum <- digest(input_file, algo = "sha256", serialize = FALSE, file = TRUE)
expected_checksum <- faostat_record[[1]]$checksum_sha256
if (!identical(observed_checksum, expected_checksum)) {
  stop("FAOSTAT snapshot checksum does not match metadata/provenance.yml.", call. = FALSE)
}

raw <- read_csv(input_file, show_col_types = FALSE) |> clean_names()
required_columns <- c("area", "item", "element", "year", "unit", "value", "flag")
missing_columns <- setdiff(required_columns, names(raw))
if (length(missing_columns) > 0) {
  stop("Teaching sample is missing column(s): ", paste(missing_columns, collapse = ", "))
}

expected_element_units <- c("Area harvested|ha", "Production|t", "Yield|kg/ha")
observed_element_units <- raw |>
  distinct(element, unit) |>
  transmute(pair = paste(element, unit, sep = "|")) |>
  pull(pair)
if (!setequal(observed_element_units, expected_element_units)) {
  stop("Unexpected element/unit combinations; run validation and review the dictionary.")
}

if (!setequal(unique(raw$item), "Maize (corn)")) {
  stop("The teaching sample must contain maize observations only.")
}
if (n_distinct(raw$area) != 9L || !identical(range(raw$year), c(1990, 2022))) {
  stop("The teaching sample must cover nine countries and 1990-2022.")
}

candidate_key <- c("area", "item", "element", "year", "unit")
if (nrow(raw |> count(across(all_of(candidate_key))) |> filter(n > 1)) > 0) {
  stop("Teaching sample contains duplicate candidate keys.")
}

tidy <- raw |>
  filter(item == "Maize (corn)") |>
  transmute(
    country = area,
    year = as.integer(year),
    measure = case_when(
      element == "Yield" & unit == "kg/ha" ~ "yield_kg_per_hectare",
      element == "Area harvested" & unit == "ha" ~ "harvested_area_hectares",
      element == "Production" & unit == "t" ~ "production_tonnes",
      TRUE ~ NA_character_
    ),
    value = as.numeric(value)
  )
if (any(is.na(tidy$measure))) stop("An element/unit combination was not mapped.")

panel <- tidy |>
  pivot_wider(names_from = measure, values_from = value) |>
  arrange(country, year) |>
  mutate(
    yield_tonnes_per_hectare = yield_kg_per_hectare / 1000,
    log_yield = safe_log(yield_tonnes_per_hectare)
  ) |>
  select(
    country, year, yield_tonnes_per_hectare, production_tonnes,
    harvested_area_hectares, log_yield
  )

expected_rows <- n_distinct(raw$area) * n_distinct(raw$year)
if (nrow(panel) != expected_rows) {
  stop("Prepared panel is incomplete: expected ", expected_rows, " rows; created ", nrow(panel), ".")
}

output_key_duplicates <- panel |>
  count(country, year) |>
  filter(n > 1) |>
  nrow()
if (output_key_duplicates > 0) {
  stop("Prepared panel contains duplicate country-year keys.")
}

source_yield <- tidy |>
  filter(measure == "yield_kg_per_hectare") |>
  transmute(country, year, source_yield_kg_per_hectare = value)
conversion_difference <- panel |>
  left_join(source_yield, by = c("country", "year")) |>
  summarise(
    maximum = max(
      abs(yield_tonnes_per_hectare * 1000 - source_yield_kg_per_hectare),
      na.rm = TRUE
    )
  ) |>
  pull(maximum)
if (!is.finite(conversion_difference)) conversion_difference <- 0

missing_log_for_positive <- panel |>
  summarise(n = sum(is.na(log_yield) & yield_tonnes_per_hectare > 0, na.rm = TRUE)) |>
  pull(n)
non_finite_log_values <- sum(!is.finite(panel$log_yield[!is.na(panel$log_yield)]))

# 03) Audit prepared data ----

audit <- tribble(
  ~check, ~expectation, ~observed, ~status,
  "input-checksum", expected_checksum, observed_checksum,
  if_else(identical(observed_checksum, expected_checksum), "pass", "failure"),
  "input-rows", "891", as.character(nrow(raw)),
  if_else(nrow(raw) == 891L, "pass", "failure"),
  "input-countries", "9", as.character(n_distinct(raw$area)),
  if_else(n_distinct(raw$area) == 9L, "pass", "failure"),
  "input-year-range", "1990-2022", paste(range(raw$year), collapse = "-"),
  if_else(identical(range(raw$year), c(1990, 2022)), "pass", "failure"),
  "recognized-element-unit-pairs", "3", as.character(length(observed_element_units)),
  if_else(setequal(observed_element_units, expected_element_units), "pass", "failure"),
  "input-key-duplicates", "0",
  as.character(nrow(raw |> count(across(all_of(candidate_key))) |> filter(n > 1))),
  if_else(nrow(raw |> count(across(all_of(candidate_key))) |> filter(n > 1)) == 0L,
          "pass", "failure"),
  "prepared-rows", "297", as.character(nrow(panel)),
  if_else(nrow(panel) == 297L, "pass", "failure"),
  "output-key-duplicates", "0", as.character(output_key_duplicates),
  if_else(output_key_duplicates == 0L, "pass", "failure"),
  "yield-conversion-maximum-discrepancy", "<= 1e-10",
  format(conversion_difference, scientific = TRUE),
  if_else(isTRUE(all.equal(conversion_difference, 0, tolerance = 1e-10)), "pass", "failure"),
  "missing-log-for-positive-yield", "0", as.character(missing_log_for_positive),
  if_else(missing_log_for_positive == 0L, "pass", "failure"),
  "non-finite-retained-log-values", "0", as.character(non_finite_log_values),
  if_else(non_finite_log_values == 0L, "pass", "failure")
)

# 04) Write prepared data ----

write_csv(audit, audit_file, na = "")
if (any(audit$status == "failure")) {
  stop("Data preparation audit failed; inspect ", audit_file, call. = FALSE)
}

write_csv(panel, output_file, na = "")

# 05) Check artifact after ----

check_artifact_state(step_outputs, step_script, phase = "after")

message(
  "Prepared data written to: ", output_file, "\n",
  "Preparation audit written to: ", audit_file
)
