# Fit explanatory and predictive models.

source("scripts/functions.R")

library(dplyr)
library(here)
library(readr)
library(tibble)

maize <- read_csv(
  here("data-processed", "maize-yield-panel.csv"),
  show_col_types = FALSE
) |>
  filter(!is.na(log_yield))

training <- maize |> filter(year <= 2017)
testing <- maize |> filter(year >= 2018)

if (nrow(testing) == 0) {
  warning("No observations in the test period; model evaluation will be empty.")
}

historical_mean <- mean(training$log_yield, na.rm = TRUE)
trend_model <- lm(log_yield ~ year, data = training)
country_model <- lm(log_yield ~ year + country, data = training)

predictions <- testing |>
  mutate(
    historical_mean = historical_mean,
    linear_trend = predict(trend_model, newdata = testing),
    country_model = predict(country_model, newdata = testing)
  )

metrics <- tibble(
  model = c("historical-mean", "linear-trend", "country-model"),
  mae = c(
    mae_vec(predictions$log_yield, predictions$historical_mean),
    mae_vec(predictions$log_yield, predictions$linear_trend),
    mae_vec(predictions$log_yield, predictions$country_model)
  ),
  rmse = c(
    rmse_vec(predictions$log_yield, predictions$historical_mean),
    rmse_vec(predictions$log_yield, predictions$linear_trend),
    rmse_vec(predictions$log_yield, predictions$country_model)
  )
)

write_csv(predictions, here("data-processed", "maize-yield-predictions.csv"))
write_csv(metrics, here("data-processed", "model-performance.csv"))
saveRDS(country_model, here("data-processed", "country-model.rds"))

message("Model outputs created.")
