# Create reproducible descriptive summaries of maize yield and precipitation.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "readr", "tibble", "tidyr"))

library(dplyr)
library(here)
library(readr)
library(tibble)
library(tidyr)

input_file <- here(
  "data", "derived", "maize-yield-with-precipitation.csv"
)

step_script <- "scripts/describe-maize-data.R"
step_inputs <- input_file
step_outputs <- c(
  file.path(
    here("results", "tables"),
    c(
      "descriptive-coverage.csv",
      "maize-yield-summary.csv",
      "maize-yield-period-summary.csv",
      "precipitation-summary.csv",
      "yield-precipitation-association.csv",
      "stationarity-diagnostic.csv"
    )
  ),
  here("results", "descriptive-modeling-handoff.md")
)
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

if (!file.exists(input_file)) {
  stop(
    "Descriptive-analysis input not found: ", input_file,
    "\nRun preparation and integration first.",
    call. = FALSE
  )
}

maize <- read_csv(input_file, show_col_types = FALSE)

required_columns <- c(
  "project_country_id",
  "project_country_name",
  "year",
  "yield_tonnes_per_hectare",
  "growing_season_precipitation_mm"
)
missing_columns <- setdiff(required_columns, names(maize))

if (length(missing_columns) > 0) {
  stop(
    "Integrated data are missing column(s): ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

if (nrow(maize) != 297L ||
    anyDuplicated(maize[c("project_country_id", "year")])) {
  stop("Expected 297 unique project-country-year rows.", call. = FALSE)
}

if (any(maize$yield_tonnes_per_hectare < 0, na.rm = TRUE) ||
    any(maize$growing_season_precipitation_mm < 0, na.rm = TRUE)) {
  stop("Yield and precipitation must be non-negative.", call. = FALSE)
}

maize <- maize |>
  mutate(
    analysis_period = case_when(
      year <= 2005 ~ "earlier_history",
      year <= 2017 ~ "recent_training",
      TRUE ~ "later_test"
    )
  )

expected_period_counts <- tribble(
  ~analysis_period, ~expected_years,
  "earlier_history", 16L,
  "recent_training", 12L,
  "later_test", 5L
)

coverage <- maize |>
  group_by(project_country_id, project_country_name) |>
  summarise(
    total_rows = n(),
    first_year = min(year),
    last_year = max(year),
    distinct_years = n_distinct(year),
    non_missing_yield = sum(!is.na(yield_tonnes_per_hectare)),
    missing_yield = sum(is.na(yield_tonnes_per_hectare)),
    non_missing_precipitation =
      sum(!is.na(growing_season_precipitation_mm)),
    missing_precipitation =
      sum(is.na(growing_season_precipitation_mm)),
    status = if_else(
      total_rows == 33L &
        first_year == 1990L &
        last_year == 2022L &
        distinct_years == 33L &
        missing_yield == 0L &
        missing_precipitation == 0L,
      "pass",
      "review"
    ),
    .groups = "drop"
  )

yield_summary <- maize |>
  group_by(project_country_id, project_country_name) |>
  summarise(
    n = sum(!is.na(yield_tonnes_per_hectare)),
    missing = sum(is.na(yield_tonnes_per_hectare)),
    mean_t_per_ha = mean(yield_tonnes_per_hectare, na.rm = TRUE),
    median_t_per_ha = median(yield_tonnes_per_hectare, na.rm = TRUE),
    sd_t_per_ha = sd(yield_tonnes_per_hectare, na.rm = TRUE),
    q25_t_per_ha = quantile(
      yield_tonnes_per_hectare, 0.25, na.rm = TRUE
    ),
    q75_t_per_ha = quantile(
      yield_tonnes_per_hectare, 0.75, na.rm = TRUE
    ),
    iqr_t_per_ha = IQR(yield_tonnes_per_hectare, na.rm = TRUE),
    minimum_t_per_ha = min(yield_tonnes_per_hectare, na.rm = TRUE),
    maximum_t_per_ha = max(yield_tonnes_per_hectare, na.rm = TRUE),
    .groups = "drop"
  )

yield_period_summary <- maize |>
  group_by(
    project_country_id,
    project_country_name,
    analysis_period
  ) |>
  summarise(
    first_year = min(year),
    last_year = max(year),
    n = sum(!is.na(yield_tonnes_per_hectare)),
    missing = sum(is.na(yield_tonnes_per_hectare)),
    mean_t_per_ha = mean(yield_tonnes_per_hectare, na.rm = TRUE),
    median_t_per_ha = median(yield_tonnes_per_hectare, na.rm = TRUE),
    sd_t_per_ha = sd(yield_tonnes_per_hectare, na.rm = TRUE),
    iqr_t_per_ha = IQR(yield_tonnes_per_hectare, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(expected_period_counts, by = "analysis_period") |>
  mutate(
    coverage_status = if_else(
      n == expected_years & missing == 0L,
      "pass",
      "review"
    )
  )

precipitation_summary <- maize |>
  group_by(
    project_country_id,
    project_country_name,
    analysis_period
  ) |>
  summarise(
    n = sum(!is.na(growing_season_precipitation_mm)),
    missing = sum(is.na(growing_season_precipitation_mm)),
    mean_mm = mean(growing_season_precipitation_mm, na.rm = TRUE),
    median_mm = median(growing_season_precipitation_mm, na.rm = TRUE),
    sd_mm = sd(growing_season_precipitation_mm, na.rm = TRUE),
    q25_mm = quantile(
      growing_season_precipitation_mm, 0.25, na.rm = TRUE
    ),
    q75_mm = quantile(
      growing_season_precipitation_mm, 0.75, na.rm = TRUE
    ),
    iqr_mm = IQR(growing_season_precipitation_mm, na.rm = TRUE),
    .groups = "drop"
  )

safe_association <- function(data) {
  association_columns <- c(
    "yield_tonnes_per_hectare",
    "growing_season_precipitation_mm"
  )
  missing_association_columns <- setdiff(association_columns, names(data))
  if (length(missing_association_columns) > 0) {
    stop(
      "Association input is missing column(s): ",
      paste(missing_association_columns, collapse = ", "),
      call. = FALSE
    )
  }

  paired <- data |>
    filter(
      !is.na(yield_tonnes_per_hectare),
      !is.na(growing_season_precipitation_mm)
    )

  enough_variation <- nrow(paired) >= 2L &&
    sd(paired$yield_tonnes_per_hectare) > 0 &&
    sd(paired$growing_season_precipitation_mm) > 0

  covariance_value <- if (enough_variation) {
    stats::cov(
      paired[["growing_season_precipitation_mm"]],
      paired[["yield_tonnes_per_hectare"]]
    )
  } else {
    NA_real_
  }
  correlation_value <- if (enough_variation) {
    stats::cor(
      paired[["growing_season_precipitation_mm"]],
      paired[["yield_tonnes_per_hectare"]]
    )
  } else {
    NA_real_
  }

  tibble(
    n_pairs = nrow(paired),
    covariance_mm_t_per_ha = covariance_value,
    pearson_correlation = correlation_value
  )
}

pooled_association <- safe_association(maize) |>
  mutate(
    scope = "pooled",
    group_id = "all",
    group_name = "All countries and years",
    analysis_period = "all_years",
    .before = 1
  )

country_association <- maize |>
  group_by(project_country_id, project_country_name) |>
  group_modify(~ safe_association(.x)) |>
  ungroup() |>
  transmute(
    scope = "within_country",
    group_id = project_country_id,
    group_name = project_country_name,
    analysis_period = "all_years",
    n_pairs,
    covariance_mm_t_per_ha,
    pearson_correlation
  )

period_association <- maize |>
  group_by(analysis_period) |>
  group_modify(~ safe_association(.x)) |>
  ungroup() |>
  transmute(
    scope = "within_period",
    group_id = "all",
    group_name = "All countries",
    analysis_period,
    n_pairs,
    covariance_mm_t_per_ha,
    pearson_correlation
  )

country_period_association <- maize |>
  group_by(
    project_country_id,
    project_country_name,
    analysis_period
  ) |>
  group_modify(~ safe_association(.x)) |>
  ungroup() |>
  transmute(
    scope = "within_country_period",
    group_id = project_country_id,
    group_name = project_country_name,
    analysis_period,
    n_pairs,
    covariance_mm_t_per_ha,
    pearson_correlation
  )

association <- bind_rows(
  pooled_association,
  country_association,
  period_association,
  country_period_association
)

lag_one_summary <- maize |>
  arrange(project_country_id, year) |>
  group_by(project_country_id, project_country_name) |>
  mutate(
    previous_year = lag(year),
    previous_yield = lag(yield_tonnes_per_hectare),
    consecutive_pair = year - previous_year == 1L
  ) |>
  filter(
    consecutive_pair,
    !is.na(previous_yield),
    !is.na(yield_tonnes_per_hectare)
  ) |>
  summarise(
    lag_one_pairs = n(),
    lag_one_yield_correlation = if (
      n() >= 2L &&
        sd(previous_yield) > 0 &&
        sd(yield_tonnes_per_hectare) > 0
    ) {
      cor(previous_yield, yield_tonnes_per_hectare)
    } else {
      NA_real_
    },
    .groups = "drop"
  )

stationarity_diagnostic <- yield_period_summary |>
  filter(analysis_period %in% c("recent_training", "later_test")) |>
  select(
    project_country_id,
    project_country_name,
    analysis_period,
    n,
    mean_t_per_ha,
    sd_t_per_ha
  ) |>
  pivot_wider(
    names_from = analysis_period,
    values_from = c(n, mean_t_per_ha, sd_t_per_ha),
    names_sep = "__"
  ) |>
  mutate(
    mean_change_t_per_ha =
      mean_t_per_ha__later_test - mean_t_per_ha__recent_training,
    standardized_mean_change = if_else(
      sd_t_per_ha__recent_training > 0,
      mean_change_t_per_ha / sd_t_per_ha__recent_training,
      NA_real_
    ),
    sd_ratio = if_else(
      sd_t_per_ha__recent_training > 0,
      sd_t_per_ha__later_test / sd_t_per_ha__recent_training,
      NA_real_
    )
  ) |>
  left_join(
    lag_one_summary,
    by = c("project_country_id", "project_country_name")
  ) |>
  mutate(
    interpretation = paste(
      "Review period changes, lag-one correlation and the full time-series",
      "plot together; these finite-sample diagnostics do not prove",
      "stationarity."
    )
  )

output_tables <- list(
  "descriptive-coverage.csv" = coverage,
  "maize-yield-summary.csv" = yield_summary,
  "maize-yield-period-summary.csv" = yield_period_summary,
  "precipitation-summary.csv" = precipitation_summary,
  "yield-precipitation-association.csv" = association,
  "stationarity-diagnostic.csv" = stationarity_diagnostic
)

for (file_name in names(output_tables)) {
  write_csv(
    output_tables[[file_name]],
    here("results", "tables", file_name),
    na = ""
  )
}

largest_shift <- stationarity_diagnostic |>
  filter(!is.na(standardized_mean_change)) |>
  arrange(desc(abs(standardized_mean_change))) |>
  slice(1)

pooled_correlation <- pooled_association$pearson_correlation[[1]]
country_correlation_range <- range(
  country_association$pearson_correlation,
  na.rm = TRUE
)

handoff <- c(
  "# Descriptive modeling handoff",
  "",
  "## Scope and data",
  "",
  paste(
    "This evidence describes 297 annual country-level observations for nine",
    "selected countries from 1990 through 2022. Yield is measured in tonnes",
    "per hectare. CHIRPS precipitation is an October-April country-area total,",
    "not maize-field rainfall."
  ),
  "",
  "## Coverage",
  "",
  paste0(
    "All ", nrow(coverage),
    " countries pass the expected 33-year yield and precipitation coverage",
    " check. This does not establish farm-level or subnational coverage."
  ),
  "",
  "## Yield location, dispersion and shape",
  "",
  paste(
    "Country summaries report mean and median with standard deviation, IQR",
    "and range. Interpret them with the tracked country time-series figure;",
    "no single measure captures distribution shape or temporal change."
  ),
  "",
  "## Period stability",
  "",
  paste0(
    "The largest absolute recent-training to later-test standardized mean ",
    "change occurs for ", largest_shift$project_country_name[[1]], " (",
    format(round(largest_shift$standardized_mean_change[[1]], 2), nsmall = 2),
    " recent-training SDs). The later period contains only ",
    largest_shift$n__later_test[[1]],
    " observations per country. Review every period comparison and the full ",
    "series; these diagnostics neither prove nor disprove stationarity."
  ),
  "",
  "## Yield-precipitation association",
  "",
  paste0(
    "The pooled Pearson correlation is ",
    format(round(pooled_correlation, 3), nsmall = 3),
    ". Within-country correlations range from ",
    format(round(country_correlation_range[[1]], 3), nsmall = 3), " to ",
    format(round(country_correlation_range[[2]], 3), nsmall = 3),
    ". Differences between pooled, country and period results show why one ",
    "coefficient is not a complete relationship description. Correlation is ",
    "not a causal effect."
  ),
  "",
  "## Implications for explanatory modeling",
  "",
  paste(
    "Later work should decide explicitly how to represent country differences,",
    "time, possible association differences and omitted agricultural factors.",
    "Descriptive results do not identify a precipitation effect."
  ),
  "",
  "## Implications for predictive modeling",
  "",
  paste(
    "Retain a time-aware training and test split. Period changes and temporal",
    "dependence can limit transferability and make a random split optimistic."
  ),
  "",
  "## Limitations and unresolved questions",
  "",
  paste(
    "National aggregation, country-area precipitation, measurement error,",
    "short period-specific samples, trends, irrigation, temperature, inputs",
    "and other omitted variables limit interpretation."
  )
)

writeLines(
  handoff,
  here("results", "descriptive-modeling-handoff.md"),
  useBytes = TRUE
)

check_artifact_state(step_outputs, step_script, phase = "after")

if (any(coverage$status != "pass") ||
    any(yield_period_summary$coverage_status != "pass")) {
  stop(
    "Descriptive coverage requires review. Inspect the generated tables.",
    call. = FALSE
  )
}

message(
  "Descriptive-analysis tables written to: ",
  here("results", "tables"),
  "\nModeling handoff written to: ",
  here("results", "descriptive-modeling-handoff.md"),
  "\nInterpret stationarity diagnostics as evidence, not proof, and ",
  "correlations as associations, not causal effects."
)
