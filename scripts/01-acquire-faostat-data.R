# Acquire FAOSTAT Crops and Livestock Products data.
# Downloaded data are placed in data-raw and are not committed to Git.

source("scripts/00-setup.R")

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

tryCatch({
  message("Downloading FAOSTAT bulk data...")
  download.file(faostat_url, raw_zip, mode = "wb", quiet = FALSE)
  extracted <- unzip(raw_zip, exdir = here("data-raw"))
  normalized_file <- extracted[str_detect(basename(extracted), "Normalized.*\\.csv$")][1]
  if (is.na(normalized_file)) stop("Normalized CSV not found in archive.")
  file.copy(normalized_file, raw_csv, overwrite = TRUE)
}, error = function(e) {
  warning("FAOSTAT download failed; using bundled teaching sample. Reason: ", conditionMessage(e))
  use_sample <<- TRUE
})

if (use_sample || !file.exists(raw_csv)) {
  file.copy(sample_csv, raw_csv, overwrite = TRUE)
}

message("Raw input ready: ", raw_csv)
