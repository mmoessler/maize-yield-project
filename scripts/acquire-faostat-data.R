# Acquire FAOSTAT Crops and Livestock Products data.
# Complete downloads are placed in data/source and are not committed to Git.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "readr", "stringr"))

library(dplyr)
library(here)
library(readr)
library(stringr)

raw_zip <- here("data", "source", "faostat-crops-livestock-products.csv.zip")
raw_csv <- here("data", "source", "faostat-crops-livestock-products.csv")
sample_csv <- here("data", "input", "faostat-maize-yield-sample.csv")

# FAOSTAT bulk-download URLs can change. Confirm the current endpoint before a course run.
faostat_url <- paste0(
  "https://bulks-faostat.fao.org/production/",
  "Production_Crops_Livestock_E_All_Data_(Normalized).zip"
)

temporary_zip <- paste0(raw_zip, ".part")

if (file.exists(temporary_zip)) {
  unlink(temporary_zip)
}

tryCatch(
  {
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

  extracted <- unzip(raw_zip, exdir = here("data", "source"))
  normalized_file <- extracted[str_detect(basename(extracted), "Normalized.*\\.csv$")][1]
  if (is.na(normalized_file)) stop("Normalized CSV not found in archive.")

    if (!file.copy(normalized_file, raw_csv, overwrite = TRUE)) {
      stop("Could not copy the normalized FAOSTAT CSV into place.")
    }
  },
  error = function(e) {
    stop(
      "FAOSTAT maintainer acquisition failed: ", conditionMessage(e), "\n",
      "The fixed teaching sample remains available for the default workflow. ",
      "Do not replace it unless acquisition and regeneration complete ",
      "successfully.",
      call. = FALSE
    )
  },
  finally = {
    if (file.exists(temporary_zip)) {
      unlink(temporary_zip)
    }
  }
)

if (!file.exists(raw_csv) || file.info(raw_csv)$size <= 0) {
  stop("Acquisition did not produce a non-empty raw CSV.")
}

message("Raw input ready: ", raw_csv)
