# Integrate the maize country-year panel with MODIS reference-pixel NPP.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(
  c("digest", "dplyr", "here", "readr", "tibble", "tidyr", "yaml")
)

library(dplyr)
library(here)
library(readr)
library(tibble)

maize_file <- here("data-processed", "maize-yield-panel.csv")
satellite_file <- here("data-raw", "modis-npp-reference-sites.csv")
crosswalk_file <- here("metadata", "country-crosswalk.csv")
source_register_file <- here("metadata", "source-register.yml")
output_file <- here("data-interim", "maize-yield-with-npp.csv")
audit_file <- here("data-processed", "data-integration-audit.csv")

required_files <- c(
  maize_file,
  satellite_file,
  crosswalk_file,
  source_register_file
)
missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Integration input(s) not found: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

maize <- read_csv(maize_file, show_col_types = FALSE)
satellite_raw <- read_csv(satellite_file, show_col_types = FALSE)
crosswalk <- read_csv(crosswalk_file, show_col_types = FALSE)
source_register <- yaml::read_yaml(source_register_file)

satellite_source <- Filter(
  function(source) identical(source$source_id, "modis_reference_site_npp"),
  source_register$sources
)

if (length(satellite_source) != 1L) {
  stop("Source register must contain exactly one MODIS NPP source record.")
}

expected_satellite_checksum <- satellite_source[[1]]$checksum_sha256
observed_satellite_checksum <- digest::digest(
  satellite_file,
  algo = "sha256",
  serialize = FALSE,
  file = TRUE
)

if (!identical(observed_satellite_checksum, expected_satellite_checksum)) {
  stop(
    "MODIS snapshot checksum does not match metadata/source-register.yml.",
    call. = FALSE
  )
}

required_satellite_columns <- c(
  "project_country_id", "year", "npp_raw", "npp_qc_percent",
  "reference_latitude", "reference_longitude", "modis_date", "tile"
)
missing_satellite_columns <- setdiff(
  required_satellite_columns,
  names(satellite_raw)
)

if (length(missing_satellite_columns) > 0) {
  stop(
    "MODIS snapshot is missing column(s): ",
    paste(missing_satellite_columns, collapse = ", "),
    call. = FALSE
  )
}

if (anyDuplicated(crosswalk$faostat_area_label)) {
  stop("FAOSTAT labels must be unique in the country crosswalk.")
}

if (anyDuplicated(crosswalk$project_country_id)) {
  stop("Project country identifiers must be unique in the crosswalk.")
}

maize_with_id <- maize |>
  left_join(
    crosswalk |>
      select(
        project_country_id,
        project_country_name,
        faostat_area_label
      ),
    by = c("country" = "faostat_area_label"),
    relationship = "many-to-one"
  )

unmapped_maize_countries <- maize_with_id |>
  filter(is.na(project_country_id)) |>
  distinct(country)

if (nrow(unmapped_maize_countries) > 0) {
  stop(
    "Unmapped FAOSTAT country label(s): ",
    paste(unmapped_maize_countries$country, collapse = ", "),
    call. = FALSE
  )
}

if (anyDuplicated(maize_with_id[c("project_country_id", "year")])) {
  stop("Maize panel is not unique by project country identifier and year.")
}

if (anyDuplicated(satellite_raw[c("project_country_id", "year")])) {
  stop("MODIS snapshot is not unique by project country identifier and year.")
}

expected_satellite_keys <- tidyr::expand_grid(
  project_country_id = crosswalk$project_country_id,
  year = 2018:2022
)
missing_satellite_keys <- anti_join(
  expected_satellite_keys,
  satellite_raw |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)
unexpected_satellite_keys <- anti_join(
  satellite_raw |> distinct(project_country_id, year),
  expected_satellite_keys,
  by = c("project_country_id", "year")
)

if (nrow(missing_satellite_keys) > 0 || nrow(unexpected_satellite_keys) > 0) {
  stop("MODIS snapshot does not have the expected 2018-2022 coverage.")
}

if (any(is.na(satellite_raw$npp_raw)) ||
    any(satellite_raw$npp_raw < -30000 | satellite_raw$npp_raw > 32767)) {
  stop("MODIS NPP raw values fall outside the documented product range.")
}

if (any(is.na(satellite_raw$npp_qc_percent)) ||
    any(satellite_raw$npp_qc_percent < 0 | satellite_raw$npp_qc_percent > 100)) {
  stop("MODIS NPP quality percentages must be between 0 and 100.")
}

coordinate_mismatches <- satellite_raw |>
  distinct(
    project_country_id,
    reference_latitude,
    reference_longitude
  ) |>
  inner_join(
    crosswalk |>
      select(
        project_country_id,
        modis_reference_latitude,
        modis_reference_longitude
      ),
    by = "project_country_id",
    relationship = "one-to-one"
  ) |>
  filter(
    reference_latitude != modis_reference_latitude |
      reference_longitude != modis_reference_longitude
  )

if (nrow(coordinate_mismatches) > 0) {
  stop("MODIS snapshot coordinates do not match the reviewed crosswalk.")
}

unknown_satellite_ids <- anti_join(
  satellite_raw |> distinct(project_country_id),
  crosswalk |> distinct(project_country_id),
  by = "project_country_id"
)

if (nrow(unknown_satellite_ids) > 0) {
  stop(
    "Unknown MODIS project identifier(s): ",
    paste(unknown_satellite_ids$project_country_id, collapse = ", "),
    call. = FALSE
  )
}

satellite <- satellite_raw |>
  mutate(
    reference_site_npp_kg_c_m2_year = case_when(
      npp_raw >= 32761 ~ NA_real_,
      TRUE ~ npp_raw * 0.0001
    )
  ) |>
  select(
    project_country_id,
    year,
    reference_site_npp_kg_c_m2_year,
    npp_qc_percent,
    reference_latitude,
    reference_longitude,
    modis_date,
    tile,
    processing_timestamp
  )

maize_without_satellite <- anti_join(
  maize_with_id |> distinct(project_country_id, year),
  satellite |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)
satellite_without_maize <- anti_join(
  satellite |> distinct(project_country_id, year),
  maize_with_id |> distinct(project_country_id, year),
  by = c("project_country_id", "year")
)

integrated <- maize_with_id |>
  left_join(
    satellite,
    by = c("project_country_id", "year"),
    relationship = "one-to-one"
  ) |>
  relocate(project_country_id, project_country_name, country, year) |>
  arrange(project_country_id, year)

if (nrow(integrated) != nrow(maize_with_id)) {
  stop("The left join unexpectedly changed the maize row count.")
}

if (anyDuplicated(integrated[c("project_country_id", "year")])) {
  stop("Integrated output has duplicate project-country/year keys.")
}

audit <- tribble(
  ~check, ~expectation, ~observed, ~status,
  "maize-input-rows", "preserved by left join",
  as.character(nrow(maize_with_id)), "pass",
  "satellite-input-rows", "9 countries x 5 years",
  as.character(nrow(satellite)),
  if_else(nrow(satellite) == 45L, "pass", "failure"),
  "integrated-rows", as.character(nrow(maize_with_id)),
  as.character(nrow(integrated)),
  if_else(nrow(integrated) == nrow(maize_with_id), "pass", "failure"),
  "duplicate-output-keys", "0",
  as.character(sum(duplicated(integrated[c("project_country_id", "year")]))),
  "pass",
  "maize-keys-without-satellite", "expected before 2018",
  as.character(nrow(maize_without_satellite)),
  "information",
  "satellite-keys-without-maize", "0",
  as.character(nrow(satellite_without_maize)),
  if_else(nrow(satellite_without_maize) == 0L, "pass", "warning"),
  "missing-scaled-npp", "reported, not silently removed",
  as.character(sum(is.na(integrated$reference_site_npp_kg_c_m2_year))),
  "information"
)

write_csv(integrated, output_file, na = "")
write_csv(audit, audit_file, na = "")

message(
  "Integrated data written to: ", output_file, "\n",
  "Integration audit written to: ", audit_file, "\n",
  "Reminder: reference-pixel NPP is not a country or maize-field average."
)
