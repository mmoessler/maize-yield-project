# Estimate and diagnose public-expenditure associations for causal analysis.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "here", "readr", "tibble"))

library(dplyr)
library(here)
library(readr)
library(tibble)

maize_file <- here(
  "data", "derived", "maize-yield-with-precipitation.csv"
)
expenditure_file <- here(
  "data", "derived", "public-agricultural-expenditure-panel.csv"
)
causal_model_file <- here("docs", "causal-model.md")

required_files <- c(maize_file, expenditure_file, causal_model_file)
missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Explanatory-analysis input(s) not found: ",
    paste(missing_files, collapse = ", "),
    call. = FALSE
  )
}

maize <- read_csv(maize_file, show_col_types = FALSE)
expenditure <- read_csv(expenditure_file, show_col_types = FALSE)

required_maize_columns <- c(
  "project_country_id",
  "project_country_name",
  "year",
  "yield_tonnes_per_hectare",
  "growing_season_precipitation_mm"
)
missing_maize_columns <- setdiff(required_maize_columns, names(maize))

if (length(missing_maize_columns) > 0) {
  stop(
    "Integrated maize data are missing column(s): ",
    paste(missing_maize_columns, collapse = ", "),
    call. = FALSE
  )
}

required_expenditure_columns <- c(
  "country",
  "year",
  "agriculture_share_government_expenditure_percent",
  "source_flag",
  "government_level"
)
missing_expenditure_columns <- setdiff(
  required_expenditure_columns,
  names(expenditure)
)

if (length(missing_expenditure_columns) > 0) {
  stop(
    "Public agricultural expenditure data are missing column(s): ",
    paste(missing_expenditure_columns, collapse = ", "),
    call. = FALSE
  )
}

if (nrow(maize) != 297L ||
    anyDuplicated(maize[c("project_country_id", "year")])) {
  stop("Expected 297 unique project-country-year maize rows.", call. = FALSE)
}

if (nrow(expenditure) != 180L ||
    anyDuplicated(expenditure[c("country", "year")])) {
  stop(
    "Expected 180 unique observed country-year expenditure rows.",
    call. = FALSE
  )
}

if (anyNA(maize[required_maize_columns]) ||
    any(maize$yield_tonnes_per_hectare < 0) ||
    any(maize$growing_season_precipitation_mm < 0)) {
  stop("Required maize and weather variables must be complete and non-negative.")
}

if (anyNA(expenditure[required_expenditure_columns]) ||
    any(expenditure$agriculture_share_government_expenditure_percent < 0) ||
    any(expenditure$agriculture_share_government_expenditure_percent > 100)) {
  stop("Required expenditure variables must be complete and within bounds.")
}

# Define temporal order explicitly: expenditure in t-1 is linked to maize yield
# and growing-season precipitation in t. A lag establishes ordering but does
# not remove reverse causality or time-varying confounding.
lagged_expenditure <- expenditure |>
  transmute(
    project_country_name = country,
    expenditure_year = year,
    year = year + 1L,
    prior_agriculture_expenditure_share_percent =
      agriculture_share_government_expenditure_percent,
    expenditure_source_flag = source_flag,
    expenditure_government_level = government_level
  )

analysis <- maize |>
  inner_join(
    lagged_expenditure,
    by = c("project_country_name", "year"),
    relationship = "one-to-one"
  ) |>
  mutate(
    country = factor(project_country_name),
    outcome_year = factor(year),
    precipitation_100mm = growing_season_precipitation_mm / 100,
    analysis_period = if_else(year <= 2012L, "2002-2012", "2013-2022")
  ) |>
  arrange(project_country_id, year)

if (nrow(analysis) != 172L ||
    anyDuplicated(analysis[c("project_country_id", "year")])) {
  stop("Expected 172 unique lagged-exposure analysis rows.", call. = FALSE)
}

if (!all(analysis$year == analysis$expenditure_year + 1L)) {
  stop("Expenditure and outcome years are not separated by exactly one year.")
}

unmatched_maize <- anti_join(
  maize,
  lagged_expenditure,
  by = c("project_country_name", "year")
)
expenditure_without_outcome <- anti_join(
  lagged_expenditure,
  maize,
  by = c("project_country_name", "year")
)

sample_audit <- tribble(
  ~check, ~expectation, ~observed, ~status,
  "maize-input-rows", "297", as.character(nrow(maize)),
  if_else(nrow(maize) == 297L, "pass", "failure"),
  "expenditure-input-rows", "180", as.character(nrow(expenditure)),
  if_else(nrow(expenditure) == 180L, "pass", "failure"),
  "lagged-analysis-rows", "172", as.character(nrow(analysis)),
  if_else(nrow(analysis) == 172L, "pass", "failure"),
  "analysis-countries", "9", as.character(n_distinct(analysis$project_country_id)),
  if_else(n_distinct(analysis$project_country_id) == 9L, "pass", "failure"),
  "outcome-year-range", "2002-2022", paste(range(analysis$year), collapse = "-"),
  if_else(identical(range(analysis$year), c(2002, 2022)), "pass", "failure"),
  "exposure-outcome-lag-years", "1", paste(unique(
    analysis$year - analysis$expenditure_year
  ), collapse = ";"),
  if_else(all(analysis$year - analysis$expenditure_year == 1L), "pass", "failure"),
  "analysis-key-duplicates", "0", as.character(
    sum(duplicated(analysis[c("project_country_id", "year")]))
  ),
  if_else(
    !anyDuplicated(analysis[c("project_country_id", "year")]),
    "pass", "failure"
  ),
  "maize-rows-without-lagged-expenditure", "125",
  as.character(nrow(unmatched_maize)),
  if_else(nrow(unmatched_maize) == 125L, "pass", "failure"),
  "expenditure-rows-without-next-year-outcome", "8",
  as.character(nrow(expenditure_without_outcome)),
  if_else(nrow(expenditure_without_outcome) == 8L, "pass", "failure")
)

if (any(sample_audit$status == "failure")) {
  write_csv(
    sample_audit,
    here("results", "tables", "explanatory-analysis-sample-audit.csv")
  )
  stop("Explanatory-analysis sample audit failed.", call. = FALSE)
}

summarize_support <- function(data, scope, group_id, group_name, period) {
  tibble(
    scope = scope,
    group_id = group_id,
    group_name = group_name,
    analysis_period = period,
    n = nrow(data),
    first_expenditure_year = min(data$expenditure_year),
    last_expenditure_year = max(data$expenditure_year),
    minimum_percent = min(data$prior_agriculture_expenditure_share_percent),
    q25_percent = quantile(
      data$prior_agriculture_expenditure_share_percent, 0.25
    ),
    median_percent = median(
      data$prior_agriculture_expenditure_share_percent
    ),
    q75_percent = quantile(
      data$prior_agriculture_expenditure_share_percent, 0.75
    ),
    maximum_percent = max(data$prior_agriculture_expenditure_share_percent),
    range_percent = diff(range(
      data$prior_agriculture_expenditure_share_percent
    )),
    government_levels = n_distinct(data$expenditure_government_level)
  )
}

pooled_support <- summarize_support(
  analysis,
  "pooled",
  "all",
  "All countries",
  "all_years"
)

country_support <- analysis |>
  group_by(project_country_id, project_country_name) |>
  summarise(
    scope = "within_country",
    group_id = first(project_country_id),
    group_name = first(project_country_name),
    analysis_period = "all_years",
    n = n(),
    first_expenditure_year = min(expenditure_year),
    last_expenditure_year = max(expenditure_year),
    minimum_percent = min(prior_agriculture_expenditure_share_percent),
    q25_percent = quantile(
      prior_agriculture_expenditure_share_percent, 0.25
    ),
    median_percent = median(prior_agriculture_expenditure_share_percent),
    q75_percent = quantile(
      prior_agriculture_expenditure_share_percent, 0.75
    ),
    maximum_percent = max(prior_agriculture_expenditure_share_percent),
    range_percent = diff(range(
      prior_agriculture_expenditure_share_percent
    )),
    government_levels = n_distinct(expenditure_government_level),
    .groups = "drop"
  ) |>
  select(-project_country_id, -project_country_name)

country_period_support <- analysis |>
  group_by(project_country_id, project_country_name, analysis_period) |>
  summarise(
    scope = "within_country_period",
    group_id = first(project_country_id),
    group_name = first(project_country_name),
    n = n(),
    first_expenditure_year = min(expenditure_year),
    last_expenditure_year = max(expenditure_year),
    minimum_percent = min(prior_agriculture_expenditure_share_percent),
    q25_percent = quantile(
      prior_agriculture_expenditure_share_percent, 0.25
    ),
    median_percent = median(prior_agriculture_expenditure_share_percent),
    q75_percent = quantile(
      prior_agriculture_expenditure_share_percent, 0.75
    ),
    maximum_percent = max(prior_agriculture_expenditure_share_percent),
    range_percent = diff(range(
      prior_agriculture_expenditure_share_percent
    )),
    government_levels = n_distinct(expenditure_government_level),
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
    yield_tonnes_per_hectare ~
      prior_agriculture_expenditure_share_percent,
    data = analysis
  ),
  country = lm(
    yield_tonnes_per_hectare ~
      prior_agriculture_expenditure_share_percent + country,
    data = analysis
  ),
  country_year = lm(
    yield_tonnes_per_hectare ~
      prior_agriculture_expenditure_share_percent + country + outcome_year,
    data = analysis
  ),
  country_year_weather = lm(
    yield_tonnes_per_hectare ~
      prior_agriculture_expenditure_share_percent +
      country + outcome_year + precipitation_100mm,
    data = analysis
  ),
  nonlinear_sensitivity = lm(
    yield_tonnes_per_hectare ~
      prior_agriculture_expenditure_share_percent +
      I(prior_agriculture_expenditure_share_percent^2) +
      country + outcome_year + precipitation_100mm,
    data = analysis
  )
)

exposure_term <- "prior_agriculture_expenditure_share_percent"

extract_linear_estimate <- function(model, model_name) {
  model_summary <- summary(model)
  coefficient_table <- model_summary$coefficients
  interval <- confint(model, exposure_term, level = 0.95)
  observation_count <- nobs(model)

  tibble(
    model = model_name,
    estimand_proxy = paste(
      "constant conditional slope per percentage-point increase in",
      "the prior-year agriculture expenditure share"
    ),
    n = observation_count,
    estimate_t_per_ha_per_percentage_point =
      coefficient_table[exposure_term, "Estimate"],
    standard_error = coefficient_table[exposure_term, "Std. Error"],
    confidence_low = interval[[1]],
    confidence_high = interval[[2]],
    p_value = coefficient_table[exposure_term, "Pr(>|t|)"],
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
  exposure_term,
  "I(prior_agriculture_expenditure_share_percent^2)"
)
nonlinear_coefficients <- coef(nonlinear_model)[nonlinear_terms]
average_exposure <- mean(
  analysis$prior_agriculture_expenditure_share_percent
)
nonlinear_gradient <- c(1, 2 * average_exposure)
nonlinear_covariance <- vcov(nonlinear_model)[
  nonlinear_terms,
  nonlinear_terms,
  drop = FALSE
]
nonlinear_average_slope <- sum(
  nonlinear_gradient * nonlinear_coefficients
)
nonlinear_standard_error <- sqrt(as.numeric(
  t(nonlinear_gradient) %*%
    nonlinear_covariance %*%
    nonlinear_gradient
))

nonlinear_estimate <- tibble(
  model = "nonlinear_sensitivity",
  estimand_proxy = paste(
    "average modeled derivative at observed expenditure shares;",
    "slope varies across exposure"
  ),
  n = nobs(nonlinear_model),
  estimate_t_per_ha_per_percentage_point = nonlinear_average_slope,
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
  fitted_value <- fitted(model)
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
    residual_fitted_correlation = cor(residual, fitted_value),
    absolute_residual_fitted_correlation = cor(abs(residual), fitted_value),
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
  analysis |>
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
}))

output_tables <- list(
  "explanatory-analysis-sample-audit.csv" = sample_audit,
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
  models$country_year_weather,
  here(
    "results", "models",
    "explanatory-country-year-weather-model.rds"
  )
)

main_estimate <- model_estimates |>
  filter(model == "country_year_weather")
estimate_direction <- if_else(
  main_estimate$estimate_t_per_ha_per_percentage_point >= 0,
  "positive",
  "negative"
)
estimate_range <- range(
  linear_estimates$estimate_t_per_ha_per_percentage_point
)
largest_residual_dependence <- residual_dependence |>
  filter(model == "country_year_weather") |>
  filter(!is.na(lag_one_residual_correlation)) |>
  arrange(desc(abs(lag_one_residual_correlation))) |>
  slice(1)

conclusion <- c(
  "# Explanatory-analysis conclusion",
  "",
  "## Causal question and estimand",
  "",
  paste(
    "The provisional estimand is the average change in subsequent national",
    "maize yield under a one-percentage-point increase in the prior-year",
    "agriculture share of government expenditure for the observed project",
    "country-years."
  ),
  "",
  "## Data and measurement",
  "",
  paste(
    "The lagged analysis uses 172 observed country-years with outcomes from",
    "2002 through 2022. The sample is unbalanced because Zimbabwe has only",
    "four expenditure observations. The exposure covers agriculture,",
    "forestry, fishing and hunting and is not maize-specific."
  ),
  "",
  "## Identification assessment",
  "",
  paste(
    "Conditional exchangeability is not established: governments can change",
    "agricultural spending in response to prior harvests, crises, fiscal",
    "conditions and political priorities. A one-year lag establishes temporal",
    "order but does not remove reverse causality. Expenditure composition,",
    "implementation and government-level measurement also differ across",
    "countries and years."
  ),
  "",
  "## Statistical models and estimates",
  "",
  paste0(
    "Across the four planned linear specifications, expenditure-share",
    " coefficients range from ",
    format(round(estimate_range[[1]], 3), nsmall = 3), " to ",
    format(round(estimate_range[[2]], 3), nsmall = 3),
    " tonnes per hectare per percentage point. The country-year-weather",
    " estimate is ",
    format(
      round(
        main_estimate$estimate_t_per_ha_per_percentage_point[[1]],
        3
      ),
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
    " the country-year-weather model is ",
    format(
      round(
        largest_residual_dependence$lag_one_residual_correlation[[1]],
        3
      ),
      nsmall = 3
    ),
    " for ",
    largest_residual_dependence$project_country_name[[1]],
    ". Review this with influence measures, exposure support, government-level",
    " changes and the nonlinear sensitivity model."
  ),
  "",
  "## Supported interpretation",
  "",
  paste(
    "The fitted models quantify associations between the prior-year public",
    "agricultural expenditure share and subsequent national maize yield,",
    "conditional on the terms stated for each specification."
  ),
  "",
  "## Unsupported interpretations",
  "",
  paste(
    "The coefficients are not identified causal policy effects. Model-based",
    "intervals do not include bias from policy response, unmeasured",
    "time-varying confounding, heterogeneous expenditure content, measurement",
    "changes, selection, or interference."
  ),
  "",
  "## Evidence needed for stronger causal inference",
  "",
  paste(
    "Stronger analysis requires detailed expenditure composition and",
    "implementation data, stable government coverage, additional policy and",
    "economic confounders, longer country coverage, and a defensible",
    "assignment mechanism such as a specific policy change or natural",
    "experiment."
  )
)

writeLines(
  conclusion,
  here("results", "explanatory-modeling-conclusion.md"),
  useBytes = TRUE
)

message(
  "Explanatory-analysis tables written to: ",
  here("results", "tables"),
  "\nBounded conclusion written to: ",
  here("results", "explanatory-modeling-conclusion.md"),
  "\nEstimates are adjusted associations; the causal effect is not identified."
)
