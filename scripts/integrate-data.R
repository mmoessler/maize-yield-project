# Integrate the maize country-year panel with CHIRPS growing-season rainfall.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("digest", "dplyr", "here", "readr", "tibble", "tidyr", "yaml"))

library(dplyr)
library(here)
library(readr)
library(tibble)

maize_file <- here("data", "derived", "maize-yield-panel.csv")
precipitation_file <- here("data", "input", "chirps-growing-season-precipitation.csv")
crosswalk_file <- here("metadata", "project-country-crosswalk.csv")
provenance_file <- here("metadata", "provenance.yml")
output_file <- here("data", "derived", "maize-yield-with-precipitation.csv")
audit_file <- here("results", "tables", "data-integration-audit.csv")

required_files <- c(maize_file, precipitation_file, crosswalk_file, provenance_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Integration input(s) not found: ", paste(missing_files, collapse = ", "), call. = FALSE)
}

maize <- read_csv(maize_file, show_col_types = FALSE)
precipitation <- read_csv(precipitation_file, show_col_types = FALSE)
crosswalk <- read_csv(crosswalk_file, show_col_types = FALSE)
provenance <- yaml::read_yaml(provenance_file)

precipitation_record <- Filter(
  function(record) identical(record$artifact_id, "chirps_precipitation_snapshot"),
  provenance$artifacts
)
if (length(precipitation_record) != 1L) {
  stop("Provenance must contain exactly one CHIRPS snapshot record.")
}

observed_checksum <- digest::digest(
  precipitation_file, algo = "sha256", serialize = FALSE, file = TRUE
)
if (!identical(observed_checksum, precipitation_record[[1]]$checksum_sha256)) {
  stop("CHIRPS snapshot checksum does not match metadata/provenance.yml.", call. = FALSE)
}

required_precipitation_columns <- c(
  "project_country_id", "year", "season_start_date", "season_end_date",
  "growing_season_precipitation_mm", "days_observed"
)
missing_columns <- setdiff(required_precipitation_columns, names(precipitation))
if (length(missing_columns) > 0) {
  stop("CHIRPS snapshot is missing column(s): ", paste(missing_columns, collapse = ", "))
}

if (anyDuplicated(crosswalk$faostat_area_label) ||
    anyDuplicated(crosswalk$project_country_id)) {
  stop("Crosswalk source labels and project identifiers must each be unique.")
}

maize_with_id <- maize |>
  left_join(
    crosswalk |> select(project_country_id, project_country_name, faostat_area_label),
    by = c("country" = "faostat_area_label"), relationship = "many-to-one"
  )
if (any(is.na(maize_with_id$project_country_id))) {
  stop("At least one FAOSTAT country label is not mapped in the crosswalk.")
}
if (anyDuplicated(maize_with_id[c("project_country_id", "year")])) {
  stop("Maize panel is not unique by project country identifier and year.")
}
if (anyDuplicated(precipitation[c("project_country_id", "year")])) {
  stop("CHIRPS snapshot is not unique by project country identifier and year.")
}

expected_keys <- tidyr::expand_grid(
  project_country_id = crosswalk$project_country_id,
  year = 1990:2022
)
missing_keys <- anti_join(
  expected_keys, precipitation |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)
unexpected_keys <- anti_join(
  precipitation |> distinct(project_country_id, year), expected_keys,
  by = c("project_country_id", "year")
)
if (nrow(missing_keys) > 0 || nrow(unexpected_keys) > 0) {
  stop("CHIRPS snapshot does not have the expected 1990-2022 coverage.")
}
if (any(precipitation$growing_season_precipitation_mm < 0, na.rm = TRUE) ||
    any(is.na(precipitation$growing_season_precipitation_mm))) {
  stop("CHIRPS seasonal precipitation must be complete and non-negative.")
}
if (any(!precipitation$days_observed %in% c(212L, 213L))) {
  stop("CHIRPS seasonal totals must contain 212 or 213 daily observations.")
}

unknown_precipitation_ids <- anti_join(
  precipitation |> distinct(project_country_id),
  crosswalk |> distinct(project_country_id), by = "project_country_id"
)
if (nrow(unknown_precipitation_ids) > 0) {
  stop("CHIRPS snapshot contains an unknown project country identifier.")
}

precipitation_for_join <- precipitation |>
  rename(precipitation_days_observed = days_observed)

maize_without_precipitation <- anti_join(
  maize_with_id |> distinct(project_country_id, year),
  precipitation_for_join |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)
precipitation_without_maize <- anti_join(
  precipitation_for_join |> distinct(project_country_id, year),
  maize_with_id |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)

integrated <- maize_with_id |>
  left_join(
    precipitation_for_join,
    by = c("project_country_id", "year"), relationship = "one-to-one"
  ) |>
  relocate(project_country_id, project_country_name, country, year) |>
  arrange(project_country_id, year)

if (nrow(integrated) != nrow(maize_with_id) ||
    anyDuplicated(integrated[c("project_country_id", "year")])) {
  stop("The integration changed row count or introduced duplicate keys.")
}

audit <- tribble(
  ~check, ~expectation, ~observed, ~status,
  "maize-input-rows", "preserved by left join", as.character(nrow(maize_with_id)), "pass",
  "precipitation-input-rows", "9 countries x 33 seasons", as.character(nrow(precipitation)),
  if_else(nrow(precipitation) == 297L, "pass", "failure"),
  "integrated-rows", as.character(nrow(maize_with_id)), as.character(nrow(integrated)), "pass",
  "duplicate-output-keys", "0", as.character(sum(duplicated(integrated[c("project_country_id", "year")]))), "pass",
  "maize-keys-without-precipitation", "0",
  as.character(nrow(maize_without_precipitation)),
  if_else(nrow(maize_without_precipitation) == 0L, "pass", "failure"),
  "precipitation-keys-without-maize", "0", as.character(nrow(precipitation_without_maize)),
  if_else(nrow(precipitation_without_maize) == 0L, "pass", "failure"),
  "missing-precipitation-in-covered-years", "0",
  as.character(sum(is.na(integrated$growing_season_precipitation_mm))),
  if_else(sum(is.na(integrated$growing_season_precipitation_mm)) == 0L,
          "pass", "failure")
)

write_csv(integrated, output_file, na = "")
write_csv(audit, audit_file, na = "")
message(
  "Integrated data written to: ", output_file, "\n",
  "Integration audit written to: ", audit_file, "\n",
  "Interpret rainfall as a country-area seasonal estimate, not maize-field exposure."
)
