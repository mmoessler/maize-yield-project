# Acquire FAOSTAT Crops and Livestock Products data.
# Downloaded data are placed in data-raw and are not committed to Git.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "readr", "stringr"))

library(dplyr)
library(here)
library(readr)
library(stringr)

raw_zip <- here("data-raw", "faostat-crops-livestock-products.csv.zip")
raw_csv <- here("data-raw", "faostat-crops-livestock-products.csv")
sample_csv <- here("data-raw", "faostat-maize-yield-sample.csv")

# FAOSTAT bulk-download URLs can change. Confirm the current endpoint before a course run.
faostat_url <- paste0(
  "https://bulks-faostat.fao.org/production/",
  "Production_Crops_Livestock_E_All_Data_(Normalized).zip"
)

use_sample <- FALSE
temporary_zip <- paste0(raw_zip, ".part")

if (file.exists(temporary_zip)) {
  unlink(temporary_zip)
}

tryCatch({
  message("Downloading FAOSTAT bulk data...")

  status <- download.file(
    faostat_url,
    temporary_zip,
    mode = "wb",
    quiet = FALSE
  )

  if (!identical(status, 0L)) {
    stop("Download returned status ", status, ".")
  }

  if (file.exists(raw_zip)) {
    unlink(raw_zip)
  }

  if (!file.rename(temporary_zip, raw_zip)) {
    stop("Could not move the completed download into place.")
  }

  extracted <- unzip(raw_zip, exdir = here("data-raw"))
  normalized_file <- extracted[str_detect(basename(extracted), "Normalized.*\\.csv$")][1]
  if (is.na(normalized_file)) stop("Normalized CSV not found in archive.")

  if (!file.copy(normalized_file, raw_csv, overwrite = TRUE)) {
    stop("Could not copy the normalized FAOSTAT CSV into place.")
  }
}, error = function(e) {
  warning("FAOSTAT download failed; using course-provided teaching sample. Reason: ", conditionMessage(e))
  use_sample <<- TRUE
}, finally = {
  if (file.exists(temporary_zip)) {
    unlink(temporary_zip)
  }
})

if (use_sample || !file.exists(raw_csv)) {
  if (!file.exists(sample_csv)) {
    stop(
      "FAOSTAT acquisition failed and the teaching sample is absent.\n",
      "Expected sample: ", sample_csv, "\n",
      "Check network access and the FAOSTAT endpoint, or provide the ",
      "course sample before running again.",
      call. = FALSE
    )
  }

  if (!file.copy(sample_csv, raw_csv, overwrite = TRUE)) {
    stop("Could not copy the teaching sample into place.")
  }
}

if (!file.exists(raw_csv) || file.info(raw_csv)$size <= 0) {
  stop("Acquisition did not produce a non-empty raw CSV.")
}

message("Raw input ready: ", raw_csv)
