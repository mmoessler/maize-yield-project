# Maize Yield Project

This repository contains a small, instructional data science project for the **Introduction to Data Science** course in a Data Science and Food Systems
certificate.

The project uses a fixed maize production sample to demonstrate a complete and
reproducible analysis workflow: validating data, preparing a tidy analytical
dataset, exploring trends, fitting simple models, evaluating predictions, and
communicating results in a report. It is intended as a teaching example rather
than a production forecasting system or a definitive analysis of maize
production.

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

The canonical analysis input is the tracked FAOSTAT Crops and Livestock
Products teaching sample. Its exact identity is recorded by checksum. Before
interpreting results, review its definitions, flags, provenance, and
limitations in `metadata/`.

## What learners practise

The project introduces:

- reproducible project organization and project-relative file paths;
- data validation and provenance;
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
├── data-raw/          # Fixed teaching input; maintainer downloads are ignored
├── data-processed/    # Analysis-ready data and outputs (generated; not tracked)
├── docs/              # Supplementary setup documentation
├── figures/           # Generated plots
├── metadata/          # Source metadata, dictionary, code lists, and provenance
├── reports/           # Quarto report source and rendered output
├── renv/              # renv bootstrap and settings
├── scripts/           # Analysis scripts, maintainer utilities, and functions
├── Dockerfile         # Reproducible container definition
├── renv.lock          # Pinned R package versions
└── maize-yield-project.Rproj
```

The main scripts are:

| Script | Purpose |
|---|---|
| `scripts/setup.R` | Restore and verify the package environment |
| `scripts/validate-data.R` | Validate the fixed teaching extract |
| `scripts/prepare-maize-data.R` | Create the country-year maize panel |
| `scripts/explore-maize-data.R` | Produce summaries and a trend figure |
| `scripts/model-maize-yield.R` | Fit models and evaluate recent predictions |
| `scripts/create-teaching-sample.R` | Regenerate the fixed teaching extract |
| `scripts/acquire-faostat-data.R` | Maintainer utility to download the FAOSTAT bulk source |
| `scripts/run-all.R` | Run validation, analysis, and reporting from the fixed sample |
| `scripts/functions.R` | Define reusable transformation and metric helpers |

## Further documentation

This repository keeps one implementation note per topic so students and contributors can understand how the course ideas are realized in the project:

- [Version control implementation](docs/version-control.md) — tracked/ignored artifacts, remotes, commit workflow, and review checks.
- [Reproducible-environment implementation](docs/reproducible-environment.md) — `renv`, Docker, setup checks, persistent outputs, and troubleshooting.
- [Remote-computing implementation](docs/remote-computing.md) — running the project on a remote Linux server and the current infrastructure boundary.
- [Data-management implementation](docs/data-management.md) — source identity, metadata, provenance, validation, and governance decisions.

## Analysis workflow

```text
fixed, checksummed teaching sample
        │
        ├──► metadata and validation report
        │
        ▼
validated preparation
        │
        ▼
analysis-ready country-year panel
        │
        ├──► descriptive summaries and visualization
        │
        └──► model fitting and test-period evaluation
                         │
                         ▼
                   Quarto report
```

The preparation script reads only the fixed sample. It checks its expected
element/unit combinations and candidate key, reshapes the measures to one row
per country and year, converts yield from kilograms per hectare to tonnes per
hectare by dividing by 1,000, and calculates log yield.

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
Rscript scripts/setup.R
```

This also verifies the project context and creates the generated-data and output directories when they are absent.

Then run the complete workflow:

```bash
Rscript scripts/run-all.R
```

`scripts/run-all.R` records the canonical execution order:

1. `scripts/validate-data.R`
2. `scripts/prepare-maize-data.R`
3. `scripts/explore-maize-data.R`
4. `scripts/model-maize-yield.R`
5. render the validation and analysis reports

Individual stages can also be run in this order. Each stage expects the outputs
of the preceding stages to exist.

The default workflow is offline and does not download or replace data. It
always validates and analyzes
`data-raw/faostat-maize-yield-sample.csv`.

Maintainers can regenerate the compact course sample from the downloaded bulk
data. The script selects maize yield, production, and harvested area for the
nine project countries from 1990 through 2022:

```bash
Rscript scripts/acquire-faostat-data.R
Rscript scripts/create-teaching-sample.R
```

These are maintenance commands, not learner prerequisites. A regenerated
sample can differ when FAOSTAT revises historical data. Review it and update
its metadata deliberately before replacing the tracked snapshot.

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

See [Reproducible-environment implementation](docs/reproducible-environment.md) for architecture, interactive use, environment updates, and troubleshooting.

## Generated outputs

After a successful run, the principal outputs are:

- `data-processed/maize-yield-panel.csv`
- `data-processed/country-yield-summary.csv`
- `data-processed/maize-yield-predictions.csv`
- `data-processed/model-performance.csv`
- `data-processed/country-model.rds`
- `figures/maize-yield-over-time.png`
- `reports/maize-yield-report.html`

Full downloaded bulk data, processed data, validation results, and rendered
reports are excluded from version control because they are external or
generated workflow artifacts.

The compact teaching sample is the deliberate exception: it is tracked with a
checksum, dictionary, provenance record, licence information, and validation
rules so that the project remains inspectable and usable offline. See the
[data-management implementation](docs/data-management.md) for the artifact
policy and maintenance workflow.

The project deliberately has no `data-interim/` directory. The fixed input is
validated and converted directly into one analysis-ready panel, so no
intermediate artifact needs to persist. Add that role only if a future workflow
creates an inspectable hand-off that is consumed by a later step.

## Reproducibility and interpretation

The repository emphasizes reproducibility, transparent transformations, modular scripts, relative paths, version control, and a pinned package
environment. These practices are informed by recommendations from [The Turing Way](https://the-turing-way.netlify.app/).

Reproducible code does not by itself guarantee valid conclusions. Learners should consider FAOSTAT data quality and revisions, missing observations,
differences between countries, omitted variables, model simplicity, and the distinction between prediction, association, and causation.
