# Prepare the fixed FAOSTAT maize teaching sample.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "janitor", "readr", "tidyr"))

library(dplyr)
library(here)
library(janitor)
library(readr)
library(tidyr)

input_file <- here("data", "input", "faostat-maize-yield-sample.csv")
output_file <- here("data", "derived", "maize-yield-panel.csv")

if (!file.exists(input_file)) {
  stop("Fixed teaching sample not found: ", input_file, call. = FALSE)
}

raw <- read_csv(input_file, show_col_types = FALSE) |> clean_names()
required_columns <- c("area", "item", "element", "year", "unit", "value", "flag")
missing_columns <- setdiff(required_columns, names(raw))
if (length(missing_columns) > 0) {
  stop("Teaching sample is missing column(s): ", paste(missing_columns, collapse = ", "))
}

expected_element_units <- c("Area harvested|ha", "Production|t", "Yield|kg/ha")
observed_element_units <- raw |>
  distinct(element, unit) |>
  transmute(pair = paste(element, unit, sep = "|")) |>
  pull(pair)
if (!setequal(observed_element_units, expected_element_units)) {
  stop("Unexpected element/unit combinations; run validation and review the dictionary.")
}

candidate_key <- c("area", "item", "element", "year", "unit")
if (nrow(raw |> count(across(all_of(candidate_key))) |> filter(n > 1)) > 0) {
  stop("Teaching sample contains duplicate candidate keys.")
}

tidy <- raw |>
  filter(item == "Maize (corn)") |>
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
if (any(is.na(tidy$measure))) stop("An element/unit combination was not mapped.")

panel <- tidy |>
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
  stop("Prepared panel is incomplete: expected ", expected_rows, " rows; created ", nrow(panel), ".")
}

write_csv(panel, output_file, na = "")
message("Prepared data written to: ", output_file)
