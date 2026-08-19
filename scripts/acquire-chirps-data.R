# Acquire country-average CHIRPS precipitation for the teaching integration.
#
# The tracked snapshot keeps the normal workflow available offline. Maintainers
# can pass --refresh to submit deliberate ClimateSERV zonal-statistics requests.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "httr", "jsonlite", "readr", "tibble", "tidyr"))

library(dplyr)
library(here)
library(httr)
library(jsonlite)
library(readr)
library(tibble)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(setdiff(arguments, "--refresh")) > 0) {
  stop("Usage: Rscript scripts/acquire-chirps-data.R [--refresh]", call. = FALSE)
}

output_file <- here("data-raw", "chirps-growing-season-precipitation.csv")
boundaries_file <- here("metadata", "project-country-boundaries.geojson")
refresh <- "--refresh" %in% arguments

if (file.exists(output_file) && !refresh) {
  message(
    "Using tracked CHIRPS teaching snapshot: ", output_file, "\n",
    "Pass --refresh to retrieve a new snapshot deliberately."
  )
} else {
  if (!file.exists(boundaries_file)) {
    stop("Project-country boundaries not found: ", boundaries_file, call. = FALSE)
  }

  boundaries <- fromJSON(boundaries_file, simplifyVector = FALSE)$features
  expected_ids <- c("BWA", "SWZ", "LSO", "MWI", "MOZ", "NAM", "ZAF", "ZMB", "ZWE")
  observed_ids <- vapply(
    boundaries,
    function(feature) feature$properties$project_country_id,
    character(1)
  )

  if (!setequal(observed_ids, expected_ids) || anyDuplicated(observed_ids)) {
    stop("Boundary identifiers do not match the nine project countries.", call. = FALSE)
  }

  endpoint <- "https://climateserv.servirglobal.net/api"
  request_json <- function(path, query) {
    response <- RETRY(
      "GET", paste0(endpoint, "/", path, "/"), query = query,
      times = 4, pause_base = 2, pause_cap = 15, terminate_on = c(400, 401, 403, 404)
    )
    stop_for_status(response)
    fromJSON(content(response, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
  }

  retrieve_daily_average <- function(feature) {
    country_id <- feature$properties$project_country_id
    message("Submitting CHIRPS request for ", country_id, "...")
    job <- request_json(
      "submitDataRequest",
      list(
        datatype = 0,
        begintime = "10/01/2017",
        endtime = "04/30/2022",
        intervaltype = 0,
        operationtype = 5,
        dateType_Category = "default",
        isZip_CurrentDataType = "false",
        geometry = toJSON(feature$geometry, auto_unbox = TRUE)
      )
    )
    job_id <- unlist(job, use.names = FALSE)[[1]]

    for (attempt in seq_len(180)) {
      progress <- unlist(
        request_json("getDataRequestProgress", list(id = job_id)),
        use.names = FALSE
      )[[1]]
      if (is.numeric(progress) && progress >= 100) break
      if (identical(progress, -1)) stop("ClimateSERV job failed: ", job_id)
      Sys.sleep(2)
    }
    if (!exists("progress") || progress < 100) {
      stop("ClimateSERV job did not finish within six minutes: ", job_id)
    }

    result <- request_json("getDataFromRequest", list(id = job_id))
    if (is.null(result$data) || length(result$data) == 0) {
      stop("ClimateSERV returned no daily data for ", country_id, ".")
    }

    tibble(
      project_country_id = country_id,
      date = as.Date(
        vapply(result$data, function(day) day$date, character(1)),
        tryFormats = c("%m/%d/%Y", "%d/%m/%Y")
      ),
      precipitation_mm = vapply(
        result$data,
        function(day) as.numeric(unlist(day$value, use.names = FALSE)[[1]]),
        numeric(1)
      )
    )
  }

  daily <- bind_rows(lapply(boundaries, retrieve_daily_average)) |>
    mutate(
      season_year = if_else(as.integer(format(date, "%m")) >= 10L,
                            as.integer(format(date, "%Y")) + 1L,
                            as.integer(format(date, "%Y")))
    ) |>
    filter(
      season_year %in% 2018:2022,
      as.integer(format(date, "%m")) %in% c(10:12, 1:4)
    )

  snapshot <- daily |>
    group_by(project_country_id, season_year) |>
    summarise(
      season_start_date = min(date),
      season_end_date = max(date),
      growing_season_precipitation_mm = sum(precipitation_mm),
      days_observed = n(),
      .groups = "drop"
    ) |>
    rename(year = season_year) |>
    arrange(project_country_id, year)

  expected_keys <- tidyr::expand_grid(
    project_country_id = expected_ids,
    year = 2018:2022
  )
  if (nrow(anti_join(expected_keys, snapshot, by = c("project_country_id", "year"))) > 0 ||
      any(snapshot$days_observed < 212 | snapshot$days_observed > 213)) {
    stop("The retrieved CHIRPS snapshot has incomplete country-season coverage.")
  }

  temporary_file <- paste0(output_file, ".part")
  write_csv(snapshot, temporary_file, na = "")
  if (file.exists(output_file) && !file.remove(output_file)) {
    stop("Could not replace existing CHIRPS snapshot: ", output_file)
  }
  if (!file.rename(temporary_file, output_file)) {
    stop("Could not move the completed CHIRPS snapshot into place.")
  }

  message(
    "CHIRPS teaching snapshot written to: ", output_file, "\n",
    "Review it and update metadata/provenance.yml with its SHA-256 checksum."
  )
}
