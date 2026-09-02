# Topic: Acquire country-average CHIRPS precipitation for the teaching integration.
#
# The tracked snapshot keeps the normal workflow available offline. Maintainers
# can pass --refresh to submit deliberate ClimateSERV zonal-statistics requests.

# 00) Setup ----

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

refresh <- "--refresh" %in% arguments

# 01) Check artifact before ----

output_file <- here("data", "input", "chirps-growing-season-precipitation.csv")
boundaries_file <- here("metadata", "project-country-boundaries.geojson")

step_script <- "scripts/acquire-chirps-data.R"
step_inputs <- boundaries_file
step_outputs <- output_file
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

# 02) Download and write data ----

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

  season_years <- 1990:2022
  season_year_batches <- list(1990:2005, 2006:2022)

  season_start <- function(year) as.Date(sprintf("%d-10-01", year - 1L))
  season_end <- function(year) as.Date(sprintf("%d-04-30", year))

  submit_daily_average <- function(feature, years) {
    country_id <- feature$properties$project_country_id
    first_date <- season_start(min(years))
    last_date <- season_end(max(years))
    message(
      "Submitting CHIRPS request for ", country_id, ", seasons ",
      min(years), "-", max(years), "..."
    )
    job <- request_json(
      "submitDataRequest",
      list(
        datatype = 0,
        begintime = format(first_date, "%m/%d/%Y"),
        endtime = format(last_date, "%m/%d/%Y"),
        intervaltype = 0,
        operationtype = 5,
        dateType_Category = "default",
        isZip_CurrentDataType = "false",
        geometry = toJSON(feature$geometry, auto_unbox = TRUE)
      )
    )
    list(
      job_id = unlist(job, use.names = FALSE)[[1]],
      project_country_id = country_id,
      first_season_year = min(years),
      last_season_year = max(years)
    )
  }

  retrieve_completed_job <- function(job) {
    result <- request_json("getDataFromRequest", list(id = job$job_id))
    if (is.null(result$data) || length(result$data) == 0) {
      stop(
        "ClimateSERV returned no daily data for ",
        job$project_country_id, ", seasons ", job$first_season_year,
        "-", job$last_season_year, "."
      )
    }

    tibble(
      project_country_id = job$project_country_id,
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

  request_tasks <- unlist(lapply(
    boundaries,
    function(feature) {
      lapply(
        season_year_batches,
        function(years) list(feature = feature, years = years)
      )
    }
  ), recursive = FALSE)

  jobs <- lapply(
    request_tasks,
    function(task) submit_daily_average(task$feature, task$years)
  )
  results <- vector("list", length(jobs))
  pending <- seq_along(jobs)

  for (attempt in seq_len(300)) {
    completed <- integer()

    for (job_index in pending) {
      progress <- unlist(
        request_json(
          "getDataRequestProgress",
          list(id = jobs[[job_index]]$job_id)
        ),
        use.names = FALSE
      )[[1]]

      if (is.numeric(progress) && progress < 0) {
        stop("ClimateSERV job failed: ", jobs[[job_index]]$job_id)
      }
      if (is.numeric(progress) && progress >= 100) {
        results[[job_index]] <- retrieve_completed_job(jobs[[job_index]])
        completed <- c(completed, job_index)
        message(
          "Completed ", jobs[[job_index]]$project_country_id, ", seasons ",
          jobs[[job_index]]$first_season_year, "-",
          jobs[[job_index]]$last_season_year, "."
        )
      }
    }

    pending <- setdiff(pending, completed)
    if (length(pending) == 0) break
    Sys.sleep(2)
  }

  if (length(pending) > 0) {
    stop(
      length(pending),
      " ClimateSERV job(s) did not finish within ten minutes."
    )
  }

  daily <- bind_rows(results)

  if (any(is.na(daily$date)) ||
      anyDuplicated(daily[c("project_country_id", "date")])) {
    stop("CHIRPS responses contain missing dates or duplicate country-date keys.")
  }

  daily <- daily |>
    mutate(
      season_year = if_else(as.integer(format(date, "%m")) >= 10L,
                            as.integer(format(date, "%Y")) + 1L,
                            as.integer(format(date, "%Y")))
    ) |>
    filter(
      season_year %in% season_years,
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
    mutate(
      expected_start_date = season_start(year),
      expected_end_date = season_end(year),
      expected_days = as.integer(expected_end_date - expected_start_date) + 1L
    ) |>
    arrange(project_country_id, year)

  expected_keys <- tidyr::expand_grid(
    project_country_id = expected_ids,
    year = season_years
  )
  if (nrow(anti_join(expected_keys, snapshot, by = c("project_country_id", "year"))) > 0 ||
      any(snapshot$season_start_date != snapshot$expected_start_date) ||
      any(snapshot$season_end_date != snapshot$expected_end_date) ||
      any(snapshot$days_observed != snapshot$expected_days)) {
    stop("The retrieved CHIRPS snapshot has incomplete country-season coverage.")
  }

  snapshot <- snapshot |>
    select(-expected_start_date, -expected_end_date, -expected_days)

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

# 03) Check artifacts after ----

check_artifact_state(
  step_outputs, 
  step_script, 
  phase = "after"
)
