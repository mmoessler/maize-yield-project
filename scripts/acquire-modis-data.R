# Acquire annual MODIS net primary productivity for teaching reference pixels.
#
# The tracked snapshot keeps the exercise available offline. Pass --refresh to
# replace it deliberately from the ORNL DAAC TESViS REST API.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "jsonlite", "readr", "tibble"))

library(dplyr)
library(here)
library(jsonlite)
library(readr)
library(tibble)

arguments <- commandArgs(trailingOnly = TRUE)
allowed_arguments <- c("--refresh")

if (length(setdiff(arguments, allowed_arguments)) > 0) {
  stop(
    "Usage: Rscript scripts/acquire-modis-data.R [--refresh]",
    call. = FALSE
  )
}

refresh <- "--refresh" %in% arguments
output_file <- here("data-raw", "modis-npp-reference-sites.csv")
crosswalk_file <- here("metadata", "country-crosswalk.csv")

use_snapshot <- file.exists(output_file) && !refresh

if (use_snapshot) {
  message(
    "Using tracked MODIS teaching snapshot: ", output_file, "\n",
    "Pass --refresh to retrieve a new snapshot deliberately."
  )
} else {
if (!file.exists(crosswalk_file)) {
  stop("Country crosswalk not found: ", crosswalk_file, call. = FALSE)
}

sites <- read_csv(crosswalk_file, show_col_types = FALSE)
required_site_columns <- c(
  "project_country_id", "project_country_name",
  "modis_reference_latitude", "modis_reference_longitude"
)
missing_site_columns <- setdiff(required_site_columns, names(sites))

if (length(missing_site_columns) > 0) {
  stop(
    "Country crosswalk is missing column(s): ",
    paste(missing_site_columns, collapse = ", "),
    call. = FALSE
  )
}

if (anyDuplicated(sites$project_country_id)) {
  stop("Project country identifiers must be unique in the crosswalk.")
}

endpoint <- "https://modis.ornl.gov/rst/api/v1/MOD17A3HGF/subset"
snapshot_years <- 2018:2022
year_batches <- list(snapshot_years)

encode_parameter <- function(name, value) {
  paste0(name, "=", URLencode(as.character(value), reserved = TRUE))
}

request_subset <- function(latitude, longitude, years) {
  parameters <- c(
    encode_parameter("latitude", latitude),
    encode_parameter("longitude", longitude),
    encode_parameter("startDate", paste0("A", min(years), "001")),
    encode_parameter("endDate", paste0("A", max(years), "001")),
    "kmAboveBelow=0",
    "kmLeftRight=0"
  )
  request_url <- paste0(endpoint, "?", paste(parameters, collapse = "&"))
  response <- fromJSON(request_url, simplifyVector = TRUE)

  if (is.null(response$subset) || nrow(response$subset) == 0) {
    stop("MODIS API returned no subset records for request: ", request_url)
  }

  response$subset
}

extract_single_pixel <- function(values) {
  vapply(values, function(value) as.numeric(value[[1]]), numeric(1))
}

records <- list()
record_index <- 1L

for (site_index in seq_len(nrow(sites))) {
  site <- sites[site_index, ]
  message("Retrieving MODIS NPP for ", site$project_country_name, "...")

  for (years in year_batches) {
    subset <- request_subset(
      site$modis_reference_latitude,
      site$modis_reference_longitude,
      years
    )
    subset$raw_value <- extract_single_pixel(subset$data)

    npp <- subset |>
      filter(band == "Npp_500m") |>
      transmute(
        modis_date,
        calendar_date,
        tile,
        processing_timestamp = proc_date,
        npp_raw = raw_value
      )
    quality <- subset |>
      filter(band == "Npp_QC_500m") |>
      transmute(modis_date, npp_qc_percent = raw_value)

    if (nrow(npp) != length(years) || nrow(quality) != length(years)) {
      stop(
        "Unexpected MODIS response coverage for ",
        site$project_country_name,
        call. = FALSE
      )
    }

    records[[record_index]] <- npp |>
      left_join(quality, by = "modis_date", relationship = "one-to-one") |>
      mutate(
        project_country_id = site$project_country_id,
        project_country_name = site$project_country_name,
        reference_latitude = site$modis_reference_latitude,
        reference_longitude = site$modis_reference_longitude,
        .before = 1
      )
    record_index <- record_index + 1L
  }
}

satellite <- bind_rows(records) |>
  mutate(year = as.integer(substr(modis_date, 2, 5)), .after = calendar_date) |>
  arrange(project_country_id, year)

expected_rows <- nrow(sites) * length(snapshot_years)

if (nrow(satellite) != expected_rows) {
  stop("Expected ", expected_rows, " rows; received ", nrow(satellite), ".")
}

if (anyDuplicated(satellite[c("project_country_id", "year")])) {
  stop("MODIS snapshot has duplicate project-country/year keys.")
}

temporary_file <- paste0(output_file, ".part")
write_csv(satellite, temporary_file, na = "")

if (file.exists(output_file) && !file.remove(output_file)) {
  stop("Could not replace existing MODIS snapshot: ", output_file)
}

if (!file.rename(temporary_file, output_file)) {
  stop("Could not move completed MODIS snapshot into place.")
}

message(
  "MODIS teaching snapshot written to: ", output_file, "\n",
  "Rows: ", nrow(satellite), "\n",
  "Review the snapshot and record its SHA-256 in metadata/source-register.yml."
)
}
