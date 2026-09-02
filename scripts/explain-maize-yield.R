# Estimate and diagnose precipitation-yield associations for causal analysis.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "readr", "tibble"))

library(dplyr)
library(here)
library(readr)
library(tibble)

input_file <- here(
  "data", "derived", "maize-yield-with-precipitation.csv"
)
causal_model_file <- here("docs", "causal-model.md")

step_script <- "scripts/explain-maize-yield.R"
step_inputs <- c(input_file, causal_model_file)
step_outputs <- c(
  file.path(
    here("results", "tables"),
    c(
      "explanatory-exposure-support.csv",
      "explanatory-model-estimates.csv",
      "explanatory-model-diagnostics.csv",
      "explanatory-residual-dependence.csv"
    )
  ),
  here("results", "models", "explanatory-country-time-model.rds"),
  here("results", "explanatory-modeling-conclusion.md")
)
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

required_files <- c(input_file, causal_model_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop(
    "Explanatory-modeling input(s) not found: ",
    paste(missing_files, collapse = ", "),
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

if (anyNA(maize[required_columns]) ||
    any(maize$yield_tonnes_per_hectare < 0) ||
    any(maize$growing_season_precipitation_mm < 0)) {
  stop(
    "Required explanatory variables must be complete and non-negative.",
    call. = FALSE
  )
}

maize <- maize |>
  mutate(
    country = factor(project_country_name),
    year_centered = year - 1990,
    precipitation_100mm = growing_season_precipitation_mm / 100,
    analysis_period = case_when(
      year <= 2005 ~ "earlier_history",
      year <= 2017 ~ "recent_training",
      TRUE ~ "later_test"
    )
  )

summarize_support <- function(data, scope, group_id, group_name, period) {
  tibble(
    scope = scope,
    group_id = group_id,
    group_name = group_name,
    analysis_period = period,
    n = nrow(data),
    minimum_100mm = min(data$precipitation_100mm),
    q25_100mm = quantile(data$precipitation_100mm, 0.25),
    median_100mm = median(data$precipitation_100mm),
    q75_100mm = quantile(data$precipitation_100mm, 0.75),
    maximum_100mm = max(data$precipitation_100mm),
    range_100mm = diff(range(data$precipitation_100mm))
  )
}

pooled_support <- summarize_support(
  maize,
  "pooled",
  "all",
  "All countries",
  "all_years"
)

country_support <- maize |>
  group_by(project_country_id, project_country_name) |>
  summarise(
    scope = "within_country",
    group_id = first(project_country_id),
    group_name = first(project_country_name),
    analysis_period = "all_years",
    n = n(),
    minimum_100mm = min(precipitation_100mm),
    q25_100mm = quantile(precipitation_100mm, 0.25),
    median_100mm = median(precipitation_100mm),
    q75_100mm = quantile(precipitation_100mm, 0.75),
    maximum_100mm = max(precipitation_100mm),
    range_100mm = diff(range(precipitation_100mm)),
    .groups = "drop"
  ) |>
  select(-project_country_id, -project_country_name)

country_period_support <- maize |>
  group_by(
    project_country_id,
    project_country_name,
    analysis_period
  ) |>
  summarise(
    scope = "within_country_period",
    group_id = first(project_country_id),
    group_name = first(project_country_name),
    n = n(),
    minimum_100mm = min(precipitation_100mm),
    q25_100mm = quantile(precipitation_100mm, 0.25),
    median_100mm = median(precipitation_100mm),
    q75_100mm = quantile(precipitation_100mm, 0.75),
    maximum_100mm = max(precipitation_100mm),
    range_100mm = diff(range(precipitation_100mm)),
    .groups = "drop"
  ) |>
  select(-project_country_id, -project_country_name) |>
  relocate(analysis_period, .after = group_name)

exposure_support <- bind_rows(
  pooled_support,
  country_support,
  country_period_support
)

models <- list(
  unadjusted = lm(
    yield_tonnes_per_hectare ~ precipitation_100mm,
    data = maize
  ),
  country = lm(
    yield_tonnes_per_hectare ~ precipitation_100mm + country,
    data = maize
  ),
  time = lm(
    yield_tonnes_per_hectare ~ precipitation_100mm + year_centered,
    data = maize
  ),
  country_time = lm(
    yield_tonnes_per_hectare ~
      precipitation_100mm + country + year_centered,
    data = maize
  ),
  nonlinear_sensitivity = lm(
    yield_tonnes_per_hectare ~
      precipitation_100mm + I(precipitation_100mm^2) +
      country + year_centered,
    data = maize
  )
)

extract_linear_estimate <- function(model, model_name) {
  model_summary <- summary(model)
  coefficient_table <- model_summary$coefficients
  interval <- confint(model, "precipitation_100mm", level = 0.95)
  observation_count <- nobs(model)

  tibble(
    model = model_name,
    estimand_proxy = "constant conditional slope per 100 mm",
    n = observation_count,
    estimate_t_per_ha_per_100mm =
      coefficient_table["precipitation_100mm", "Estimate"],
    standard_error =
      coefficient_table["precipitation_100mm", "Std. Error"],
    confidence_low = interval[[1]],
    confidence_high = interval[[2]],
    p_value = coefficient_table["precipitation_100mm", "Pr(>|t|)"],
    r_squared = model_summary$r.squared,
    adjusted_r_squared = model_summary$adj.r.squared,
    interpretation = "adjusted association; causal effect not identified"
  )
}

linear_estimates <- bind_rows(lapply(
  names(models)[1:4],
  function(name) extract_linear_estimate(models[[name]], name)
))

nonlinear_model <- models$nonlinear_sensitivity
nonlinear_terms <- c(
  "precipitation_100mm",
  "I(precipitation_100mm^2)"
)
nonlinear_coefficients <- coef(nonlinear_model)[nonlinear_terms]
average_precipitation <- mean(maize$precipitation_100mm)
nonlinear_gradient <- c(1, 2 * average_precipitation)
nonlinear_covariance <- vcov(nonlinear_model)[
  nonlinear_terms,
  nonlinear_terms,
  drop = FALSE
]
nonlinear_average_slope <- sum(
  nonlinear_gradient * nonlinear_coefficients
)
nonlinear_standard_error <- sqrt(
  as.numeric(
    t(nonlinear_gradient) %*%
      nonlinear_covariance %*%
      nonlinear_gradient
  )
)

nonlinear_estimate <- tibble(
  model = "nonlinear_sensitivity",
  estimand_proxy = paste(
    "average modeled derivative at observed precipitation;",
    "slope varies across exposure"
  ),
  n = nobs(nonlinear_model),
  estimate_t_per_ha_per_100mm = nonlinear_average_slope,
  standard_error = nonlinear_standard_error,
  confidence_low = nonlinear_average_slope -
    qt(0.975, df.residual(nonlinear_model)) * nonlinear_standard_error,
  confidence_high = nonlinear_average_slope +
    qt(0.975, df.residual(nonlinear_model)) * nonlinear_standard_error,
  p_value = NA_real_,
  r_squared = summary(nonlinear_model)$r.squared,
  adjusted_r_squared = summary(nonlinear_model)$adj.r.squared,
  interpretation = paste(
    "functional-form sensitivity; adjusted association;",
    "causal effect not identified"
  )
)

model_estimates <- bind_rows(linear_estimates, nonlinear_estimate)

diagnose_model <- function(model, model_name) {
  residual <- residuals(model)
  fitted <- fitted(model)
  cooks <- cooks.distance(model)
  observation_count <- nobs(model)
  parameter_count <- length(coef(model))
  residual_standard_deviation <- sigma(model)
  model_summary <- summary(model)

  tibble(
    model = model_name,
    n = observation_count,
    parameters = parameter_count,
    residual_sd = residual_standard_deviation,
    residual_fitted_correlation = cor(residual, fitted),
    absolute_residual_fitted_correlation = cor(abs(residual), fitted),
    maximum_absolute_residual = max(abs(residual)),
    maximum_cooks_distance = max(cooks),
    observations_above_4_over_n = sum(cooks > 4 / observation_count),
    r_squared = model_summary$r.squared,
    adjusted_r_squared = model_summary$adj.r.squared
  )
}

model_diagnostics <- bind_rows(lapply(
  names(models),
  function(name) diagnose_model(models[[name]], name)
))

residual_dependence <- bind_rows(lapply(names(models), function(name) {
  residual_data <- maize |>
    mutate(model_residual = residuals(models[[name]])) |>
    arrange(project_country_id, year) |>
    group_by(project_country_id, project_country_name) |>
    mutate(
      previous_year = lag(year),
      previous_residual = lag(model_residual)
    ) |>
    filter(year - previous_year == 1L) |>
    summarise(
      lag_one_pairs = n(),
      lag_one_residual_correlation = if (
        n() >= 2L &&
          sd(previous_residual) > 0 &&
          sd(model_residual) > 0
      ) {
        cor(previous_residual, model_residual)
      } else {
        NA_real_
      },
      .groups = "drop"
    ) |>
    mutate(model = name, .before = 1)

  residual_data
}))

output_tables <- list(
  "explanatory-exposure-support.csv" = exposure_support,
  "explanatory-model-estimates.csv" = model_estimates,
  "explanatory-model-diagnostics.csv" = model_diagnostics,
  "explanatory-residual-dependence.csv" = residual_dependence
)

for (file_name in names(output_tables)) {
  write_csv(
    output_tables[[file_name]],
    here("results", "tables", file_name),
    na = ""
  )
}

saveRDS(
  models$country_time,
  here("results", "models", "explanatory-country-time-model.rds")
)

main_estimate <- model_estimates |>
  filter(model == "country_time")
estimate_direction <- if_else(
  main_estimate$estimate_t_per_ha_per_100mm >= 0,
  "positive",
  "negative"
)
estimate_range <- range(
  linear_estimates$estimate_t_per_ha_per_100mm
)
largest_residual_dependence <- residual_dependence |>
  filter(model == "country_time") |>
  arrange(desc(abs(lag_one_residual_correlation))) |>
  slice(1)

conclusion <- c(
  "# Explanatory-modeling conclusion",
  "",
  "## Causal question and estimand",
  "",
  paste(
    "The provisional estimand is the average change in national maize yield",
    "under a 100 mm increase in October-April country-area precipitation for",
    "the nine project countries from 1990 through 2022."
  ),
  "",
  "## Data and measurement",
  "",
  paste(
    "The analysis uses 297 country-years. National FAOSTAT yield and",
    "country-area CHIRPS precipitation do not measure field-level exposure",
    "or within-country agricultural variation."
  ),
  "",
  "## Identification assessment",
  "",
  paste(
    "Consistency is doubtful because precipitation totals hide timing,",
    "intensity and location. Exchangeability is not established because",
    "temperature, irrigation, inputs, management and other changing common",
    "causes are unmeasured. Positivity is only partly assessable, and",
    "interference and measurement limitations remain."
  ),
  "",
  "## Statistical models and estimates",
  "",
  paste0(
    "Across the four planned linear specifications, precipitation",
    " coefficients range from ",
    format(round(estimate_range[[1]], 3), nsmall = 3), " to ",
    format(round(estimate_range[[2]], 3), nsmall = 3),
    " tonnes per hectare per 100 mm. The country-and-time estimate is ",
    format(
      round(main_estimate$estimate_t_per_ha_per_100mm[[1]], 3),
      nsmall = 3
    ),
    " (95% model-based interval ",
    format(round(main_estimate$confidence_low[[1]], 3), nsmall = 3),
    " to ",
    format(round(main_estimate$confidence_high[[1]], 3), nsmall = 3),
    "), a ", estimate_direction,
    " conditional association under that specification."
  ),
  "",
  "## Diagnostics and sensitivity",
  "",
  paste0(
    "The largest absolute country-specific lag-one residual correlation in",
    " the country-and-time model is ",
    format(
      round(
        largest_residual_dependence$lag_one_residual_correlation[[1]],
        3
      ),
      nsmall = 3
    ),
    " for ",
    largest_residual_dependence$project_country_name[[1]],
    ". Review this evidence with residual plots, influence measures, exposure",
    " support and the nonlinear sensitivity model."
  ),
  "",
  "## Supported interpretation",
  "",
  paste(
    "The fitted models quantify precipitation-yield associations conditional",
    "on their stated country, time and functional-form terms."
  ),
  "",
  "## Unsupported interpretations",
  "",
  paste(
    "The coefficients are not identified causal effects. Default confidence",
    "intervals describe model-based sampling uncertainty and do not include",
    "unmeasured confounding, exposure ambiguity, measurement error, selection",
    "or interference."
  ),
  "",
  "## Evidence needed for stronger causal inference",
  "",
  paste(
    "Stronger analysis requires crop-area exposure, rainfall timing and",
    "intensity, temperature, soils, irrigation, inputs and management,",
    "subnational outcomes, and a more credible assignment mechanism or",
    "research design."
  )
)

writeLines(
  conclusion,
  here("results", "explanatory-modeling-conclusion.md"),
  useBytes = TRUE
)

check_artifact_state(step_outputs, step_script, phase = "after")

message(
  "Explanatory-modeling tables written to: ",
  here("results", "tables"),
  "\nBounded conclusion written to: ",
  here("results", "explanatory-modeling-conclusion.md"),
  "\nEstimates are adjusted associations; the causal effect is not identified."
)
