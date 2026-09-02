# Topic: Fit and evaluate predictive benchmark models.

# 00) Setup ----

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c(
  "dplyr", "ggplot2", "here", "readr", "tibble", "tidyr"
))

library(dplyr)
library(ggplot2)
library(here)
library(readr)
library(tibble)
library(tidyr)

# 01) Check artifacts before ----

input_file <- here("data", "derived", "maize-yield-panel.csv")

step_script <- "scripts/model-maize-yield.R"
step_topic <- "predictive-analysis"
step_inputs <- input_file
step_outputs <- c(
  file.path(
    here("results", "tables"),
    c(
      "predictive-split-audit.csv",
      "maize-yield-predictions.csv",
      "model-performance.csv",
      "predictive-performance-by-country.csv"
    )
  ),
  here("results", "models", "predictive-benchmark-models.rds"),
  here("figures", "predictive-observed-versus-predicted.png"),
  here("results", "predictive-modeling-conclusion.md")
)
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

# 02) Read and prepare analysis data ----

if (!file.exists(input_file)) {
  stop(
    "Predictive-modeling input not found: ", input_file,
    ". Run scripts/prepare-maize-data.R first.",
    call. = FALSE
  )
}

maize <- read_csv(input_file, show_col_types = FALSE)

required_columns <- c(
  "country", "year", "yield_tonnes_per_hectare", "log_yield"
)
missing_columns <- setdiff(required_columns, names(maize))

if (length(missing_columns) > 0) {
  stop(
    "Prepared maize data are missing column(s): ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

if (nrow(maize) != 297L || anyDuplicated(maize[c("country", "year")])) {
  stop("Expected 297 unique country-year rows.", call. = FALSE)
}

if (anyNA(maize[required_columns]) ||
    any(maize$yield_tonnes_per_hectare <= 0)) {
  stop(
    "Predictive target rows must be complete and yield must be positive.",
    call. = FALSE
  )
}

if (!identical(range(maize$year), c(1990, 2022))) {
  stop("Expected complete project coverage from 1990 to 2022.", call. = FALSE)
}

maize <- maize |>
  mutate(
    partition = if_else(year <= 2017, "training", "test"),
    country = factor(country)
  )

# 03) Create the temporal split ----

training <- maize |> filter(partition == "training")
testing <- maize |> filter(partition == "test")

if (nrow(training) != 252L || nrow(testing) != 45L) {
  stop(
    "Expected 252 training rows and 45 held-out test rows.",
    call. = FALSE
  )
}

if (max(training$year) != 2017L || min(testing$year) != 2018L) {
  stop("The fixed temporal split must occur after 2017.", call. = FALSE)
}

if (!all(levels(droplevels(testing$country)) %in%
    levels(droplevels(training$country)))) {
  stop("Every test country must occur during training.", call. = FALSE)
}

split_audit <- maize |>
  group_by(partition, country) |>
  summarise(
    rows = n(),
    first_year = min(year),
    last_year = max(year),
    missing_target = sum(is.na(log_yield)),
    duplicate_country_years = n() - n_distinct(year),
    .groups = "drop"
  ) |>
  mutate(country = as.character(country)) |>
  arrange(factor(partition, levels = c("training", "test")), country)

# 04) Fit predictive benchmark models ----

historical_mean <- mean(training$log_yield)
trend_model <- lm(log_yield ~ year, data = training)
country_model <- lm(log_yield ~ year + country, data = training)

# 05) Generate and evaluate predictions ----

predictions <- testing |>
  transmute(
    country = as.character(country),
    year,
    yield_tonnes_per_hectare,
    log_yield,
    historical_mean = historical_mean,
    linear_trend = predict(trend_model, newdata = testing),
    country_model = predict(country_model, newdata = testing)
  )

prediction_columns <- c(
  "historical_mean", "linear_trend", "country_model"
)

if (anyNA(predictions[c("log_yield", prediction_columns)])) {
  stop("Held-out targets and predictions must be complete.", call. = FALSE)
}

prediction_long <- predictions |>
  pivot_longer(
    cols = all_of(prediction_columns),
    names_to = "model",
    values_to = "estimate"
  ) |>
  mutate(
    model = recode(
      model,
      historical_mean = "historical-mean",
      linear_trend = "linear-trend",
      country_model = "country-model"
    ),
    error = log_yield - estimate,
    absolute_error = abs(error),
    squared_error = error^2
  )

model_order <- c(
  "historical-mean", "linear-trend", "country-model"
)

metrics <- prediction_long |>
  group_by(model) |>
  summarise(
    observations = n(),
    mean_error = mean(error),
    mae = mean(absolute_error),
    rmse = sqrt(mean(squared_error)),
    .groups = "drop"
  ) |>
  mutate(model = factor(model, levels = model_order)) |>
  arrange(model) |>
  mutate(model = as.character(model))

baseline_mae <- metrics$mae[metrics$model == "historical-mean"]
metrics <- metrics |>
  mutate(
    mae_improvement_over_baseline = baseline_mae - mae,
    mae_improvement_percent =
      100 * mae_improvement_over_baseline / baseline_mae
  )

performance_by_country <- prediction_long |>
  group_by(model, country) |>
  summarise(
    observations = n(),
    mean_error = mean(error),
    mae = mean(absolute_error),
    rmse = sqrt(mean(squared_error)),
    .groups = "drop"
  ) |>
  mutate(model = factor(model, levels = model_order)) |>
  arrange(model, country) |>
  mutate(model = as.character(model))

# 06) Create the evaluation figure and conclusion ----

prediction_plot <- ggplot(
  prediction_long |>
    mutate(model = factor(model, levels = model_order)),
  aes(x = year)
) +
  geom_line(
    aes(y = estimate, colour = model, group = model),
    linewidth = 0.7
  ) +
  geom_point(aes(y = estimate, colour = model), size = 1.5) +
  geom_line(aes(y = log_yield, group = 1), linewidth = 0.8) +
  geom_point(aes(y = log_yield), size = 1.8) +
  facet_wrap(~ country, scales = "free_y", ncol = 3) +
  scale_x_continuous(breaks = c(2018, 2020, 2022)) +
  labs(
    title = "Observed and predicted maize yield in the test period",
    subtitle = paste(
      "Black: observed log yield; colour: benchmark prediction;",
      "models fitted on 1990–2017"
    ),
    x = "Year",
    y = "Log yield",
    colour = "Model"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

best_mae <- metrics |> slice_min(mae, n = 1, with_ties = FALSE)
best_rmse <- metrics |> slice_min(rmse, n = 1, with_ties = FALSE)
largest_error <- prediction_long |>
  slice_max(absolute_error, n = 1, with_ties = FALSE)
country_range <- performance_by_country |>
  filter(model == best_mae$model) |>
  summarise(minimum = min(mae), maximum = max(mae))

conclusion <- c(
  "# Predictive-modeling conclusion",
  "",
  paste0(
    "The predefined benchmark procedures were fitted on 252 country-year ",
    "observations from 1990–2017 and evaluated on 45 held-out observations ",
    "from 2018–2022 across nine countries."
  ),
  "",
  paste0(
    "The lowest test MAE was produced by `", best_mae$model, "` (",
    format(round(best_mae$mae, 3), nsmall = 3),
    " log-yield units), an improvement of ",
    format(round(best_mae$mae_improvement_percent, 1), nsmall = 1),
    "% over the historical-mean baseline. The lowest RMSE model was `",
    best_rmse$model, "` (",
    format(round(best_rmse$rmse, 3), nsmall = 3), ")."
  ),
  "",
  paste0(
    "For the lowest-MAE candidate, country-specific MAE ranged from ",
    format(round(country_range$minimum, 3), nsmall = 3), " to ",
    format(round(country_range$maximum, 3), nsmall = 3),
    ". The largest row-level absolute error across all candidates occurred ",
    "for ", largest_error$country, " in ", largest_error$year, " under `",
    largest_error$model, "` (",
    format(round(largest_error$absolute_error, 3), nsmall = 3), ")."
  ),
  "",
  paste0(
    "This result supports a reproducible teaching benchmark for later ",
    "observations from countries represented during training. Five test ",
    "years provide limited evidence, performance differs by country, and ",
    "future distribution shifts remain possible."
  ),
  "",
  paste0(
    "The evaluation does not validate an operational crop forecast, ",
    "prediction for unseen countries, high-stakes use, or a causal claim. ",
    "Adding precipitation requires a separately defined issue date and ",
    "feature-availability contract."
  )
)

# 07) Write predictive outputs ----

write_csv(
  split_audit,
  here("results", "tables", "predictive-split-audit.csv")
)
write_csv(
  predictions,
  here("results", "tables", "maize-yield-predictions.csv")
)
write_csv(metrics, here("results", "tables", "model-performance.csv"))
write_csv(
  performance_by_country,
  here(
    "results", "tables", "predictive-performance-by-country.csv"
  )
)
saveRDS(
  list(
    historical_mean = historical_mean,
    linear_trend = trend_model,
    country_model = country_model,
    training_end_year = 2017L,
    target = "log_yield"
  ),
  here("results", "models", "predictive-benchmark-models.rds")
)
ggsave(
  here("figures", "predictive-observed-versus-predicted.png"),
  prediction_plot,
  width = 10,
  height = 8,
  dpi = 300
)
writeLines(
  conclusion,
  here("results", "predictive-modeling-conclusion.md")
)

# 08) Check artifacts after ----

check_artifact_state(
  step_outputs,
  step_script,
  phase = "after",
  topic = step_topic
)

message("Predictive-modeling outputs created.")
