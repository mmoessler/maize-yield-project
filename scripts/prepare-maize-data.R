# Prepare maize yield data for selected Southern African countries.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(
  c("dplyr", "here", "janitor", "readr", "tidyr")
)

library(dplyr)
library(here)
library(janitor)
library(readr)
library(tidyr)

input_file <- here("data-raw", "faostat-maize-yield-sample.csv")
output_file <- here("data-processed", "maize-yield-panel.csv")

if (!file.exists(input_file)) {
  stop("Fixed teaching sample not found: ", input_file, call. = FALSE)
}

countries <- c(
  "Botswana", "Eswatini", "Lesotho", "Malawi", "Mozambique",
  "Namibia", "South Africa", "Zambia", "Zimbabwe"
)

raw <- read_csv(input_file, show_col_types = FALSE) |> clean_names()

required_columns <- c("area", "item", "element", "year", "unit", "value", "flag")
missing_columns <- setdiff(required_columns, names(raw))

if (length(missing_columns) > 0) {
  stop(
    "The teaching sample is missing required column(s): ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

expected_element_units <- c(
  "Area harvested|ha",
  "Production|t",
  "Yield|kg/ha"
)

observed_element_units <- raw |>
  distinct(element, unit) |>
  transmute(element_unit = paste(element, unit, sep = "|")) |>
  pull(element_unit)

if (!setequal(observed_element_units, expected_element_units)) {
  stop(
    "Unexpected element/unit combinations. Run scripts/validate-data.R and ",
    "review metadata/data-dictionary.csv.",
    call. = FALSE
  )
}

candidate_key <- c("area", "item", "element", "year", "unit")
duplicate_keys <- raw |>
  count(across(all_of(candidate_key)), name = "records") |>
  filter(records > 1)

if (nrow(duplicate_keys) > 0) {
  stop(
    "The teaching sample contains duplicate candidate keys; preparation will ",
    "not select records silently.",
    call. = FALSE
  )
}

tidy <- raw |>
  filter(area %in% countries, item == "Maize (corn)") |>
  transmute(
    country = area,
    year = as.integer(year),
    measure = case_when(
      element == "Yield" & unit == "kg/ha" ~ "yield_kg_per_hectare",
      element == "Area harvested" & unit == "ha" ~ "harvested_area_hectares",
      element == "Production" & unit == "t" ~ "production_tonnes",
      TRUE ~ NA_character_
    ),
    value = as.numeric(value)
  )

if (any(is.na(tidy$measure))) {
  stop("An element/unit combination was not mapped for preparation.", call. = FALSE)
}

panel <- tidy |>
  select(country, year, measure, value) |>
  pivot_wider(names_from = measure, values_from = value) |>
  arrange(country, year) |>
  mutate(
    yield_tonnes_per_hectare = yield_kg_per_hectare / 1000,
    log_yield = safe_log(yield_tonnes_per_hectare)
  ) |>
  select(
    country, year, yield_tonnes_per_hectare, production_tonnes,
    harvested_area_hectares, log_yield
  )

expected_rows <- n_distinct(raw$area) * n_distinct(raw$year)

if (nrow(panel) != expected_rows) {
  stop(
    "The prepared panel is incomplete: expected ", expected_rows,
    " country-year rows but created ", nrow(panel), ".",
    call. = FALSE
  )
}

write_csv(panel, output_file, na = "")
message("Prepared data written to: ", output_file)
