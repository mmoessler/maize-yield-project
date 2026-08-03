# Prepare maize yield data for selected Southern African countries.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(
  c("dplyr", "here", "janitor", "readr", "stringr", "tidyr")
)

library(dplyr)
library(here)
library(janitor)
library(readr)
library(stringr)
library(tidyr)

input_file <- here("data-raw", "faostat-crops-livestock-products.csv")
output_file <- here("data-processed", "maize-yield-panel.csv")

if (!file.exists(input_file)) {
  stop("Raw data not found. Run scripts/01-acquire-faostat-data.R first.")
}

countries <- c(
  "Botswana", "Eswatini", "Lesotho", "Malawi", "Mozambique",
  "Namibia", "South Africa", "Zambia", "Zimbabwe"
)

raw <- read_csv(input_file, show_col_types = FALSE) |> clean_names()

# Support either the FAOSTAT normalized bulk schema or the bundled sample schema.
if (all(c("area", "item", "element", "year", "unit", "value") %in% names(raw))) {
  tidy <- raw |>
    filter(area %in% countries, item == "Maize (corn)") |>
    transmute(
      country = area,
      year = as.integer(year),
      measure = case_when(
        str_detect(element, regex("yield", ignore_case = TRUE)) ~ "yield",
        str_detect(element, regex("area harvested", ignore_case = TRUE)) ~ "harvested-area",
        str_detect(element, regex("production", ignore_case = TRUE)) ~ "production",
        TRUE ~ NA_character_
      ),
      unit,
      value = as.numeric(value),
      flag = if ("flag" %in% names(raw)) flag else NA_character_
    ) |>
    filter(!is.na(measure))
} else {
  stop("Unexpected input schema. Inspect names(raw) and update the mapping.")
}

panel <- tidy |>
  distinct(country, year, measure, .keep_all = TRUE) |>
  select(country, year, measure, value) |>
  pivot_wider(names_from = measure, values_from = value) |>
  arrange(country, year) |>
  mutate(
    yield_tonnes_per_hectare = yield / 10000,
    production_tonnes = production,
    harvested_area_hectares = `harvested-area`,
    log_yield = safe_log(yield_tonnes_per_hectare)
  ) |>
  select(
    country, year, yield_tonnes_per_hectare, production_tonnes,
    harvested_area_hectares, log_yield
  )

write_csv(panel, output_file, na = "")
message("Prepared data written to: ", output_file)
