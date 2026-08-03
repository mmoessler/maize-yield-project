# Create exploratory summaries and figures.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "ggplot2", "here", "readr"))

library(dplyr)
library(ggplot2)
library(here)
library(readr)

data_file <- here("data-processed", "maize-yield-panel.csv")
if (!file.exists(data_file)) stop("Run scripts/02-prepare-maize-data.R first.")

maize <- read_csv(data_file, show_col_types = FALSE)

summary_table <- maize |>
  group_by(country) |>
  summarise(
    first_year = min(year, na.rm = TRUE),
    last_year = max(year, na.rm = TRUE),
    mean_yield = mean(yield_tonnes_per_hectare, na.rm = TRUE),
    missing_yield = sum(is.na(yield_tonnes_per_hectare)),
    .groups = "drop"
  ) |>
  arrange(desc(mean_yield))

write_csv(summary_table, here("data-processed", "country-yield-summary.csv"))

yield_plot <- ggplot(maize, aes(year, yield_tonnes_per_hectare, group = country)) +
  geom_line(na.rm = TRUE) +
  facet_wrap(vars(country), scales = "free_y") +
  labs(
    title = "Maize yield over time",
    subtitle = "Selected Southern African countries",
    x = NULL,
    y = "Yield (tonnes per hectare)",
    caption = "Source: FAOSTAT or course-provided teaching sample"
  ) +
  theme_minimal()

ggsave(
  here("figures", "maize-yield-over-time.png"),
  yield_plot,
  width = 10,
  height = 7,
  dpi = 300
)

message("Exploratory outputs created.")
