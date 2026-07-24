# Maize Yield Project

This repository contains a small, instructional data science project for the **Introduction to Data Science** course in a Data Science and Food Systems
certificate.

The project uses maize production data to demonstrate a complete and reproducible analysis workflow: acquiring data, preparing a tidy analytical
dataset, exploring trends, fitting simple models, evaluating predictions, and communicating results in a report. It is intended as a teaching example rather than a production forecasting system or a definitive analysis of maize production.

## Research question

How have maize yields changed across selected Southern African countries, and how well do simple statistical models predict recently observed yields?

The analysis covers:

- Botswana
- Eswatini
- Lesotho
- Malawi
- Mozambique
- Namibia
- South Africa
- Zambia
- Zimbabwe

The intended source is the FAOSTAT Crops and Livestock Products bulk dataset. Before interpreting results, confirm which version of the source data was used and review its definitions, flags, and limitations.

## What learners practise

The project introduces:

- reproducible project organization and project-relative file paths;
- data acquisition and provenance;
- cleaning, filtering, reshaping, and unit conversion;
- exploratory summaries and visualization;
- train/test splits for predictive evaluation;
- simple baseline and linear regression models;
- MAE and RMSE as prediction-error measures;
- communicating methods, findings, and limitations with Quarto; and
- dependency management with `renv` and portable execution with Docker.

The models describe associations and provide simple predictive benchmarks. They are not designed to estimate causal effects.

## Repository structure

```text
maize-yield-project/
├── data-raw/          # Downloaded source data (generated; not tracked)
├── data-processed/    # Clean data and model outputs (generated; not tracked)
├── docs/              # Supplementary setup documentation
├── figures/           # Generated plots
├── reports/           # Quarto report source and rendered output
├── renv/              # renv bootstrap and settings
├── scripts/           # Numbered analysis scripts and shared functions
├── Dockerfile         # Reproducible container definition
├── renv.lock          # Pinned R package versions
└── maize-yield-project.Rproj
```

The main scripts are:

| Script | Purpose |
|---|---|
| `scripts/00-setup.R` | Restore and verify the package environment |
| `scripts/01-acquire-faostat-data.R` | Download and extract FAOSTAT data |
| `scripts/02-prepare-maize-data.R` | Create the country-year maize panel |
| `scripts/03-explore-maize-data.R` | Produce summaries and a trend figure |
| `scripts/04-model-maize-yield.R` | Fit models and evaluate recent predictions |
| `scripts/run-all.R` | Run the analysis from acquisition through reporting |
| `scripts/functions.R` | Define reusable transformation and metric helpers |

## Analysis workflow

```text
FAOSTAT bulk data
        │
        ▼
data acquisition and preparation
        │
        ▼
country-year maize yield panel
        │
        ├──► descriptive summaries and visualization
        │
        └──► model fitting and test-period evaluation
                         │
                         ▼
                   Quarto report
```

The preparation script supports the normalized FAOSTAT schema. It selects maize yield, production, and harvested area; reshapes the measures into one row
per country and year; converts yield from FAOSTAT's `100 mg/ha` unit to tonnes per hectare; and calculates log yield.

The modeling script trains on observations through 2017 and evaluates predictions from 2018 onward. It compares:

1. a historical-mean baseline;
2. a common linear time trend; and
3. a linear time trend with country effects.

## Requirements

For local execution, install:

- R 4.3.3 (the version recorded in `renv.lock`);
- an R development environment such as RStudio, optionally; and
- Quarto, if you want `scripts/run-all.R` to render the report automatically.

Docker can be used instead of installing the R dependencies directly.

## Run locally

Run commands from the repository root.

First restore the package environment:

```bash
Rscript scripts/00-setup.R
```

Then run the complete workflow:

```bash
Rscript scripts/run-all.R
```

Individual analysis stages can also be run in numerical order. Each stage expects the outputs of the preceding stages to exist.

The acquisition step downloads a large FAOSTAT bulk archive, so it requires an internet connection and may take some time. FAOSTAT bulk-download URLs and
schemas can change; verify the endpoint before a course run.

To render only the report after the processed outputs have been created:

```bash
quarto render reports/maize-yield-report.qmd
```

## Run with Docker

Build the image:

```bash
docker build -t maize-yield-project .
```

Run the workflow while retaining data and generated outputs on the host:

```bash
docker run --rm \
  -v "$(pwd)/data-raw:/work/data-raw" \
  -v "$(pwd)/data-processed:/work/data-processed" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

See [`docs/setup-for-using-renv-with-docker.md`](docs/setup-for-using-renv-with-docker.md) for additional setup and interactive-use instructions.

## Generated outputs

After a successful run, the principal outputs are:

- `data-processed/maize-yield-panel.csv`
- `data-processed/country-yield-summary.csv`
- `data-processed/maize-yield-predictions.csv`
- `data-processed/model-performance.csv`
- `data-processed/country-model.rds`
- `figures/maize-yield-over-time.png`
- `reports/maize-yield-report.html`

Raw data, processed data, and rendered reports are excluded from version control because they are downloaded or generated by the workflow.

## Reproducibility and interpretation

The repository emphasizes reproducibility, transparent transformations, modular scripts, relative paths, version control, and a pinned package
environment. These practices are informed by recommendations from [The Turing Way](https://the-turing-way.netlify.app/).

Reproducible code does not by itself guarantee valid conclusions. Learners should consider FAOSTAT data quality and revisions, missing observations,
differences between countries, omitted variables, model simplicity, and the distinction between prediction, association, and causation.
