# Topic: Create visualizations of maize yield and precipitation.

# 00) Setup ----

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "ggplot2", "here", "readr"))

library(dplyr)
library(ggplot2)
library(here)
library(readr)

# 01) Check artifacts before ----

panel_file <- here(
  "data", "derived", "maize-yield-panel.csv"
)
integrated_file <- here(
  "data", "derived", "maize-yield-with-precipitation.csv"
)
figure_names <- c(
  "maize-yield-distribution.png",
  "maize-yield-distribution-by-country.png",
  "maize-yield-trends.png",
  "growing-season-precipitation-distribution-by-country.png",
  "growing-season-precipitation-trends.png",
  "yield-versus-precipitation.png"
)
figure_files <- file.path(here("figures"), figure_names)

step_script <- "scripts/visualize-maize-data.R"
step_topic <- "data-visualization"
step_inputs <- c(panel_file, integrated_file)
step_outputs <- figure_files
check_artifact_state(
  c(step_inputs, step_outputs),
  step_script,
  phase = "before"
)

# 02) Read data ----

maize <- read_csv(panel_file, show_col_types = FALSE)
integrated <- read_csv(integrated_file, show_col_types = FALSE)

project_theme <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

# 03) Create visualizations ----

yield_distribution <- ggplot(
  maize,
  aes(x = yield_tonnes_per_hectare)
) +
  geom_histogram(
    binwidth = 0.25,
    boundary = 0,
    colour = "white",
    fill = "#29508A",
    na.rm = TRUE
  ) +
  labs(
    title = "Distribution of annual maize yield",
    subtitle = "Nine selected countries, 1990-2022",
    x = "Yield (tonnes per hectare)",
    y = "Country-year observations",
    caption = paste(
      "Source: fixed FAOSTAT teaching sample.",
      "One observation represents one country-year."
    )
  ) +
  project_theme

yield_distribution_by_country <- ggplot(
  maize,
  aes(x = yield_tonnes_per_hectare)
) +
  geom_histogram(
    binwidth = 0.25,
    boundary = 0,
    colour = "white",
    fill = "#29508A",
    na.rm = TRUE
  ) +
  facet_wrap(vars(country), ncol = 3) +
  labs(
    title = "Distribution of annual maize yield by country",
    subtitle = "1990-2022",
    x = "Yield (tonnes per hectare)",
    y = "Country-year observations",
    caption = paste(
      "Source: fixed FAOSTAT teaching sample.",
      "Each panel shows annual observations for one country."
    )
  ) +
  project_theme

yield_trends <- ggplot(
  maize,
  aes(x = year, y = yield_tonnes_per_hectare)
) +
  geom_line(colour = "#29508A", linewidth = 0.5, na.rm = TRUE) +
  geom_point(colour = "#29508A", size = 0.8, na.rm = TRUE) +
  facet_wrap(vars(country), ncol = 3) +
  labs(
    title = "Maize yield over time",
    subtitle = "Panels share a common yield scale",
    x = "Year",
    y = "Yield (tonnes per hectare)",
    caption = "Source: fixed FAOSTAT teaching sample."
  ) +
  project_theme

precipitation_distribution_by_country <- ggplot(
  integrated,
  aes(x = growing_season_precipitation_mm)
) +
  geom_histogram(
    binwidth = 100,
    boundary = 0,
    colour = "white",
    fill = "#3B8B47",
    na.rm = TRUE
  ) +
  facet_wrap(vars(project_country_name), ncol = 3) +
  labs(
    title = "Distribution of growing-season precipitation by country",
    subtitle = "1990-2022",
    x = "Country-area seasonal precipitation (mm)",
    y = "Country-year observations",
    caption = paste(
      "Source: CHIRPS v2 via ClimateSERV.",
      "Each panel shows annual growing-season precipitation for one country."
    )
  ) +
  project_theme

precipitation_trends <- ggplot(
  integrated,
  aes(x = year, y = growing_season_precipitation_mm)
) +
  geom_line(colour = "#3B8B47", linewidth = 0.5, na.rm = TRUE) +
  geom_point(colour = "#3B8B47", size = 0.8, na.rm = TRUE) +
  facet_wrap(vars(project_country_name), ncol = 3) +
  labs(
    title = "Growing-season precipitation over time",
    subtitle = "Panels share a common precipitation scale",
    x = "Season-ending year",
    y = "Country-area seasonal precipitation (mm)",
    caption = paste(
      "Source: CHIRPS v2 via ClimateSERV.",
      "Country-area estimates are not maize-field exposure."
    )
  ) +
  project_theme

yield_precipitation <- ggplot(
  integrated,
  aes(
    x = growing_season_precipitation_mm,
    y = yield_tonnes_per_hectare
  )
) +
  geom_point(
    colour = "#29508A",
    alpha = 0.55,
    size = 1.3,
    na.rm = TRUE
  ) +
  facet_wrap(vars(project_country_name), ncol = 3) +
  labs(
    title = "Maize yield and growing-season precipitation",
    subtitle = "Each point represents one country-year",
    x = "Country-area seasonal precipitation (mm)",
    y = "Maize yield (tonnes per hectare)",
    caption = paste(
      "Sources: FAOSTAT and CHIRPS v2 via ClimateSERV.",
      "The graphic describes association, not causation."
    )
  ) +
  project_theme

# 04) Write outputs ----

plots <- list(
  "maize-yield-distribution.png" = yield_distribution,
  "maize-yield-distribution-by-country.png" = yield_distribution_by_country,
  "maize-yield-trends.png" = yield_trends,
  "growing-season-precipitation-distribution-by-country.png" = precipitation_distribution_by_country,
  "growing-season-precipitation-trends.png" = precipitation_trends,
  "yield-versus-precipitation.png" = yield_precipitation
)

figure_dimensions <- list(
  "maize-yield-distribution.png" = c(width = 9, height = 6),
  "maize-yield-distribution-by-country.png" = c(width = 10, height = 7),
  "maize-yield-trends.png" = c(width = 10, height = 7),
  "growing-season-precipitation-distribution-by-country.png" = c(width = 10, height = 7),
  "growing-season-precipitation-trends.png" = c(width = 10, height = 7),
  "yield-versus-precipitation.png" = c(width = 10, height = 7)
)

for (figure_name in names(plots)) {
  ggsave(
    filename = here("figures", figure_name),
    plot = plots[[figure_name]],
    width = figure_dimensions[[figure_name]][["width"]],
    height = figure_dimensions[[figure_name]][["height"]],
    units = "in",
    dpi = 300
  )
}

# 05) Check artifacts after ----

check_artifact_state(
  step_outputs,
  step_script,
  phase = "after",
  topic = step_topic
)

message(
  "Visualization artifacts written to: ", here("figures"), "\n"
)
