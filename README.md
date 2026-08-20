# Maize Yield Project

This repository contains a small, instructional data science project for the **Introduction to Data Science** course in a Data Science and Food Systems
certificate.

The project uses maize production data to demonstrate a complete and reproducible analysis workflow: acquiring data, preparing a tidy analytical
dataset, integrating satellite-informed growing-season precipitation, exploring trends, fitting simple models, evaluating predictions, and communicating results in reports. It is intended as a teaching example rather than a production forecasting system or a definitive analysis of maize production.

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
- identifier crosswalks, satellite-informed precipitation integration, and join audits;
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
├── data/
│   ├── source/        # Complete external downloads (ignored)
│   ├── input/         # Fixed, tracked teaching inputs
│   └── derived/       # Generated analytical datasets (ignored)
├── docs/              # Supplementary setup documentation
├── figures/           # Generated plots
├── metadata/          # Dictionaries, crosswalks, source metadata, and provenance
├── reports/           # Quarto report source and rendered output
├── results/
│   ├── tables/        # Generated audits, summaries, and metrics
│   └── models/        # Generated fitted model objects
├── renv/              # renv bootstrap and settings
├── scripts/           # Workflow scripts and shared functions
├── Dockerfile         # Reproducible container definition
├── renv.lock          # Pinned R package versions
└── maize-yield-project.Rproj
```

The main scripts are:

| Script | Purpose |
|---|---|
| `scripts/setup.R` | Restore and verify the package environment |
| `scripts/acquire-faostat-data.R` | Download and extract FAOSTAT data |
| `scripts/acquire-country-boundaries.R` | Recreate the project-country polygons from pinned Natural Earth data |
| `scripts/acquire-chirps-data.R` | Use or deliberately refresh the CHIRPS precipitation snapshot |
| `scripts/validate-data.R` | Validate the fixed teaching extract |
| `scripts/prepare-maize-data.R` | Create the country-year maize panel |
| `scripts/integrate-data.R` | Join the maize panel to growing-season precipitation and audit the result |
| `scripts/explore-maize-data.R` | Produce summaries and a trend figure |
| `scripts/model-maize-yield.R` | Fit models and evaluate recent predictions |
| `scripts/create-faostat-data-teaching-sample.R` | Create the fixed FAOSTAT teaching extract from the bulk input |
| `scripts/run-all.R` | Run the analysis from fixed inputs through reporting |
| `scripts/functions.R` | Define reusable transformation and metric helpers |

## Further documentation

This repository keeps one implementation note per topic so students and contributors can understand how the course ideas are realized in the project:

- [Version control implementation](docs/version-control.md) — tracked/ignored artifacts, remotes, commit workflow, and review checks.
- [Reproducible-environment implementation](docs/reproducible-environment.md) — `renv`, Docker, setup checks, persistent outputs, and troubleshooting.
- [Remote-computing implementation](docs/remote-computing.md) — running the project on a remote Linux server and the current infrastructure boundary.
- [Data-management implementation](docs/data-management.md) — source identity, metadata, provenance, validation, and governance decisions.
- [Data-acquisition-and-integration implementation](docs/data-acquisition-and-integration.md) — two-source acquisition, spatial and temporal alignment, crosswalks, join audits, and lineage.

Human-readable documentation for individual data artifacts is available under
`docs/data/`:

- [FAOSTAT maize-yield teaching data](docs/data/faostat-maize-yield.md)
- [CHIRPS growing-season precipitation](docs/data/chirps-growing-season-precipitation.md)
- [Project-country boundaries](docs/data/project-country-boundaries.md)
- [Maize yield augmented with precipitation](docs/data/maize-yield-with-precipitation.md)

## Analysis workflow

```text
FAOSTAT bulk data
        │
        ▼
acquisition, validation and preparation
        │
        ├──► metadata and validation report
        │
        ▼
country-year maize yield panel
        │
        ├──── CHIRPS October-April precipitation
        │              │
        │              ▼
        ├──► integrated derived dataset and join audit
        ├──► descriptive summaries and visualization
        └──► model fitting and test-period evaluation
                         │
                         ▼
                    Quarto reports
```

The preparation script supports the normalized FAOSTAT schema. It selects maize yield, production, and harvested area; reshapes the measures into one row
per country and year; converts yield from kilograms per hectare to tonnes per hectare; and calculates log yield.

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
3. `scripts/integrate-data.R`
4. `scripts/explore-maize-data.R`
5. `scripts/model-maize-yield.R`
6. render the validation, integration, and analysis reports

Individual stages can also be run in this order. Each stage expects the outputs
of the preceding stages to exist.

The normal workflow uses fixed FAOSTAT and CHIRPS snapshots and needs no
network connection. Acquisition is a deliberate maintainer workflow because
provider revisions and API changes can alter course inputs. The CHIRPS request
uses the tracked country polygons. Recreate and verify them first when the
spatial reference needs to be audited:

```bash
Rscript scripts/acquire-country-boundaries.R --refresh
sha256sum metadata/project-country-boundaries.geojson
```

To refresh CHIRPS, run `Rscript scripts/acquire-chirps-data.R --refresh`, review the resulting
country-area October-April totals for 1990–2022, and update
`metadata/provenance.yml`. ClimateSERV limits requests to 20 years, so the
script submits two historical batches for each country and combines them only
after checking daily and seasonal completeness.

Maintainers can regenerate the compact course sample from the downloaded bulk
data. The script selects maize yield, production, and harvested area for the
nine project countries from 1990 through 2022:

```bash
Rscript scripts/acquire-faostat-data.R
Rscript scripts/create-faostat-data-teaching-sample.R
```

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
mkdir -p data/source data/derived results/tables results/models figures reports
docker run --rm \
  -v "$(pwd)/data:/work/data" \
  -v "$(pwd)/results:/work/results" \
  -v "$(pwd)/figures:/work/figures" \
  -v "$(pwd)/reports:/work/reports" \
  maize-yield-project
```

See [Reproducible-environment implementation](docs/reproducible-environment.md) for architecture, interactive use, environment updates, and troubleshooting.

## Generated outputs

After a successful run, the principal outputs are:

- `data/derived/maize-yield-panel.csv`
- `data/derived/maize-yield-with-precipitation.csv`
- `results/tables/data-integration-audit.csv`
- `results/tables/country-yield-summary.csv`
- `results/tables/maize-yield-predictions.csv`
- `results/tables/model-performance.csv`
- `results/models/country-model.rds`
- `figures/maize-yield-over-time.png`
- `reports/maize-yield-report.html`
- `reports/data-integration.html`

Complete source downloads, derived datasets, analysis results, and rendered
reports are excluded from version control because they are external or
generated workflow artifacts.

The compact FAOSTAT and CHIRPS teaching snapshots are deliberate exceptions:
they are tracked with checksums, metadata, licence/citation information, and
validation rules so that the project remains inspectable and usable offline.
See the [data-management implementation](docs/data-management.md) for the
artifact policy and the [data-acquisition-and-integration
implementation](docs/data-acquisition-and-integration.md) for the multi-source
workflow and its scientific boundary.

## Reproducibility and interpretation

The repository emphasizes reproducibility, transparent transformations, modular scripts, relative paths, version control, and a pinned package
environment. These practices are informed by recommendations from [The Turing Way](https://the-turing-way.netlify.app/).

Reproducible code does not by itself guarantee valid conclusions. Learners should consider FAOSTAT data quality and revisions, missing observations,
differences between countries, omitted variables, model simplicity, and the distinction between prediction, association, and causation.
