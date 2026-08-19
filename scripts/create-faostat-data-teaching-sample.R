# Create a compact, repository-friendly teaching sample from FAOSTAT data.
#
# Run this script after acquiring the full normalized FAOSTAT dataset:
#   Rscript scripts/acquire-faostat-data.R
#   Rscript scripts/create-faostat-data-teaching-sample.R
#
# Optional command-line arguments override the input and output paths:
#   Rscript scripts/create-faostat-data-teaching-sample.R <input.csv> <output.csv>

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "janitor", "readr", "stringr"))

library(dplyr)
library(here)
library(janitor)
library(readr)
library(stringr)

arguments <- commandArgs(trailingOnly = TRUE)

if (length(arguments) > 2) {
  stop(
    paste0(
      "Usage: Rscript scripts/create-faostat-data-teaching-sample.R ",
      "[input.csv] [output.csv]"
    ),
    call. = FALSE
  )
}

input_file <- if (length(arguments) >= 1) {
  arguments[[1]]
} else {
  here("data-raw", "faostat-crops-livestock-products.csv")
}

output_file <- if (length(arguments) == 2) {
  arguments[[2]]
} else {
  here("data-raw", "faostat-maize-yield-sample.csv")
}

countries <- c(
  "Botswana", "Eswatini", "Lesotho", "Malawi", "Mozambique",
  "Namibia", "South Africa", "Zambia", "Zimbabwe"
)

first_year <- 1990L
last_year <- 2022L

if (!file.exists(input_file)) {
  stop(
    "FAOSTAT input not found: ", input_file, "\n",
    "Run scripts/acquire-faostat-data.R first or provide an input path.",
    call. = FALSE
  )
}

raw <- read_csv(input_file, show_col_types = FALSE) |>
  clean_names()

required_columns <- c("area", "item", "element", "year", "unit", "value")
missing_columns <- setdiff(required_columns, names(raw))

if (length(missing_columns) > 0) {
  stop(
    "The input does not have the expected normalized FAOSTAT schema.\n",
    "Missing column(s): ", paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

sample <- raw |>
  filter(
    area %in% countries,
    item == "Maize (corn)",
    year >= first_year,
    year <= last_year,
    str_detect(
      element,
      regex("^(Yield|Area harvested|Production)$", ignore_case = TRUE)
    )
  ) |>
  transmute(
    area,
    item,
    element,
    year = as.integer(year),
    unit,
    value = as.numeric(value),
    flag = if ("flag" %in% names(raw)) flag else NA_character_
  ) |>
  distinct(area, item, element, year, .keep_all = TRUE) |>
  arrange(area, year, element)

if (nrow(sample) == 0) {
  stop("The filters produced an empty teaching sample.", call. = FALSE)
}

missing_countries <- setdiff(countries, unique(sample$area))

if (length(missing_countries) > 0) {
  stop(
    "The sample is missing expected countries: ",
    paste(missing_countries, collapse = ", "),
    call. = FALSE
  )
}

output_directory <- dirname(output_file)

if (!dir.exists(output_directory)) {
  created <- dir.create(output_directory, recursive = TRUE)

  if (!isTRUE(created) && !dir.exists(output_directory)) {
    stop("Could not create output directory: ", output_directory, call. = FALSE)
  }
}

write_csv(sample, output_file, na = "")

message(
  "Teaching sample written to: ", output_file, "\n",
  "Rows: ", nrow(sample), "\n",
  "Countries: ", n_distinct(sample$area), "\n",
  "Years: ", min(sample$year), "-", max(sample$year)
)
