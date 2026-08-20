# Acquire the project-country boundary reference from a pinned Natural Earth release.
#
# The tracked GeoJSON keeps the normal workflow available offline. Maintainers
# can pass --refresh to recreate it deliberately from the verified source file.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("digest", "here", "jsonlite", "readr", "yaml"))

library(here)
library(jsonlite)
library(readr)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(setdiff(arguments, "--refresh")) > 0) {
  stop(
    "Usage: Rscript scripts/acquire-country-boundaries.R [--refresh]",
    call. = FALSE
  )
}

refresh <- "--refresh" %in% arguments
output_file <- here("metadata", "project-country-boundaries.geojson")
crosswalk_file <- here("metadata", "project-country-crosswalk.csv")
provenance_file <- here("metadata", "provenance.yml")

natural_earth_version <- "5.1.1"
source_url <- paste0(
  "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v",
  natural_earth_version,
  "/geojson/ne_110m_admin_0_countries.geojson"
)
provenance <- yaml::read_yaml(provenance_file)
boundary_record <- Filter(
  function(record) identical(record$artifact_id, "project_country_boundaries"),
  provenance$artifacts
)
if (length(boundary_record) != 1L) {
  stop("Provenance must contain exactly one boundary artifact record.", call. = FALSE)
}
expected_source_checksum <- boundary_record[[1]]$source_checksum_sha256

if (file.exists(output_file) && !refresh) {
  message(
    "Using tracked project-country boundaries: ", output_file, "\n",
    "Pass --refresh to recreate them deliberately."
  )
} else {
  if (!file.exists(crosswalk_file)) {
    stop("Country crosswalk not found: ", crosswalk_file, call. = FALSE)
  }

  crosswalk <- read_csv(crosswalk_file, show_col_types = FALSE)
  if (anyDuplicated(crosswalk$project_country_id) ||
      any(is.na(crosswalk$project_country_id))) {
    stop("Crosswalk project-country identifiers must be complete and unique.")
  }

  source_file <- tempfile(fileext = ".geojson")
  message("Downloading Natural Earth v", natural_earth_version, " boundaries...")
  status <- download.file(source_url, source_file, mode = "wb", quiet = FALSE)
  if (!identical(status, 0L)) {
    stop("Natural Earth download returned status ", status, ".")
  }

  observed_source_checksum <- digest::digest(
    source_file,
    algo = "sha256",
    serialize = FALSE,
    file = TRUE
  )
  if (!identical(observed_source_checksum, expected_source_checksum)) {
    stop(
      "Natural Earth source checksum does not match the pinned release.\n",
      "Expected: ", expected_source_checksum, "\n",
      "Observed: ", observed_source_checksum,
      call. = FALSE
    )
  }

  source_data <- fromJSON(source_file, simplifyVector = FALSE)
  unlink(source_file)
  if (!identical(source_data$type, "FeatureCollection") ||
      is.null(source_data$features)) {
    stop("Natural Earth source is not a GeoJSON FeatureCollection.")
  }

  project_ids <- crosswalk$project_country_id
  selected_features <- Filter(
    function(feature) feature$properties$ADM0_A3 %in% project_ids,
    source_data$features
  )
  selected_ids <- vapply(
    selected_features,
    function(feature) feature$properties$ADM0_A3,
    character(1)
  )
  if (!setequal(selected_ids, project_ids) || anyDuplicated(selected_ids)) {
    stop("Natural Earth features do not match the project-country crosswalk.")
  }

  project_features <- lapply(
    selected_features,
    function(feature) {
      if (!feature$geometry$type %in% c("Polygon", "MultiPolygon") ||
          length(feature$geometry$coordinates) == 0) {
        stop("A selected Natural Earth feature has invalid polygon geometry.")
      }
      list(
        type = "Feature",
        properties = list(
          project_country_id = feature$properties$ADM0_A3,
          natural_earth_name = feature$properties$NAME
        ),
        geometry = feature$geometry
      )
    }
  )

  output <- list(
    type = "FeatureCollection",
    name = "Natural Earth 1:110m project countries",
    features = project_features
  )
  temporary_file <- paste0(output_file, ".part")
  write_json(
    output,
    temporary_file,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA
  )

  written_data <- fromJSON(temporary_file, simplifyVector = FALSE)
  written_ids <- vapply(
    written_data$features,
    function(feature) feature$properties$project_country_id,
    character(1)
  )
  if (!setequal(written_ids, project_ids) || length(written_data$features) != 9L) {
    stop("Generated boundary file failed the identifier or feature-count check.")
  }

  if (file.exists(output_file) && !file.remove(output_file)) {
    stop("Could not replace existing boundary file: ", output_file)
  }
  if (!file.rename(temporary_file, output_file)) {
    stop("Could not move the completed boundary file into place.")
  }

  message(
    "Project-country boundaries written to: ", output_file, "\n",
    "Features: ", length(project_features), "\n",
    "Review the file and update metadata/provenance.yml with its SHA-256."
  )
}
