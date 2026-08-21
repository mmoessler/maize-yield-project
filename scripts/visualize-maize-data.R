# Create reproducible visualizations of maize yield and precipitation.

source("scripts/functions.R")

assert_project_root()
ensure_project_directories()
check_required_packages(c("dplyr", "ggplot2", "here", "readr", "tibble"))

library(dplyr)
library(ggplot2)
library(here)
library(readr)
library(tibble)

panel_file <- here("data", "derived", "maize-yield-panel.csv")
integrated_file <- here(
  "data", "derived", "maize-yield-with-precipitation.csv"
)
manifest_file <- here("results", "tables", "data-visualization-manifest.csv")

required_files <- c(panel_file, integrated_file)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop(
    "Visualization input(s) not found: ",
    paste(missing_files, collapse = ", "),
    "\nRun preparation and integration first.",
    call. = FALSE
  )
}

maize <- read_csv(panel_file, show_col_types = FALSE)
integrated <- read_csv(integrated_file, show_col_types = FALSE)

required_panel_columns <- c(
  "country", "year", "yield_tonnes_per_hectare"
)
required_integrated_columns <- c(
  "project_country_id", "project_country_name", "year",
  "yield_tonnes_per_hectare", "growing_season_precipitation_mm"
)

missing_panel_columns <- setdiff(required_panel_columns, names(maize))
missing_integrated_columns <- setdiff(
  required_integrated_columns, names(integrated)
)
if (length(missing_panel_columns) > 0) {
  stop(
    "Prepared maize panel is missing column(s): ",
    paste(missing_panel_columns, collapse = ", "),
    call. = FALSE
  )
}
if (length(missing_integrated_columns) > 0) {
  stop(
    "Integrated data are missing column(s): ",
    paste(missing_integrated_columns, collapse = ", "),
    call. = FALSE
  )
}

if (nrow(maize) != 297L || anyDuplicated(maize[c("country", "year")])) {
  stop("Prepared maize panel must contain 297 unique country-year rows.")
}
if (nrow(integrated) != 297L ||
    anyDuplicated(integrated[c("project_country_id", "year")])) {
  stop("Integrated data must contain 297 unique project-country-year rows.")
}
if (any(maize$yield_tonnes_per_hectare < 0, na.rm = TRUE)) {
  stop("Yield must be non-negative before visualization.")
}
if (any(integrated$growing_season_precipitation_mm < 0, na.rm = TRUE)) {
  stop("Growing-season precipitation must be non-negative before visualization.")
}

project_theme <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

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

precipitation_plot <- ggplot(
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
    title = "Growing-season precipitation distributions",
    subtitle = "October-April seasons ending in 1990-2022",
    x = "Country-area seasonal precipitation (mm)",
    y = "Seasons",
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

communication_plot <- yield_trends +
  labs(
    title = "Maize-yield trajectories differ across countries",
    subtitle = "Annual country-level observations, 1990-2022",
    caption = paste(
      "Source: fixed FAOSTAT teaching sample.",
      "National observations do not show within-country variation."
    )
  )

figure_contract <- tribble(
  ~figure, ~role, ~question, ~input, ~grain, ~width_in, ~height_in,
  "maize-yield-distribution.png", "exploratory",
  "How are annual maize-yield observations distributed?",
  "data/derived/maize-yield-panel.csv", "one binned count", 9, 6,
  "maize-yield-trends.png", "exploratory",
  "How does maize yield change within and differ across countries?",
  "data/derived/maize-yield-panel.csv", "one country-year", 10, 7,
  "growing-season-precipitation.png", "exploratory",
  "How does growing-season precipitation vary across countries?",
  "data/derived/maize-yield-with-precipitation.csv",
  "one binned country-season count", 10, 7,
  "yield-versus-precipitation.png", "exploratory",
  "How do maize yield and growing-season precipitation vary together?",
  "data/derived/maize-yield-with-precipitation.csv",
  "one country-year", 10, 7,
  "maize-yield-communication.png", "communication",
  "How do maize-yield trajectories differ across countries?",
  "data/derived/maize-yield-panel.csv", "one country-year", 10, 7
)

plots <- list(
  "maize-yield-distribution.png" = yield_distribution,
  "maize-yield-trends.png" = yield_trends,
  "growing-season-precipitation.png" = precipitation_plot,
  "yield-versus-precipitation.png" = yield_precipitation,
  "maize-yield-communication.png" = communication_plot
)

for (index in seq_len(nrow(figure_contract))) {
  figure_name <- figure_contract$figure[[index]]
  ggsave(
    filename = here("figures", figure_name),
    plot = plots[[figure_name]],
    width = figure_contract$width_in[[index]],
    height = figure_contract$height_in[[index]],
    units = "in",
    dpi = 300
  )
}

manifest <- figure_contract |>
  mutate(
    path = file.path("figures", figure),
    format = "png",
    dpi = 300L,
    size_bytes = vapply(
      path,
      function(file) as.numeric(file.info(file)$size),
      FUN.VALUE = numeric(1)
    ),
    status = if_else(!is.na(size_bytes) & size_bytes > 0, "pass", "failure")
  ) |>
  select(
    figure, role, question, input, grain, path,
    width_in, height_in, format, dpi, size_bytes, status
  )

write_csv(manifest, manifest_file, na = "")
if (any(manifest$status == "failure")) {
  stop("At least one visualization artifact was not created successfully.")
}

message(
  "Visualization artifacts written to: ", here("figures"), "\n",
  "Visualization manifest written to: ", manifest_file, "\n",
  "Interpret plotted associations as descriptive, not causal."
)
