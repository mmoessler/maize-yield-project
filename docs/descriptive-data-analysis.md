# Descriptive-data-analysis implementation

This document explains how the standalone `maize-yield-project` implements
reproducible Descriptive Data Analysis. It records project-specific decisions;
the learning module provides the broader concepts and guided exercise.

## Place in the workflow

Descriptive analysis consumes the integrated country-year artifact and the
visual questions from the preceding topic:

```text
integrated maize-precipitation data
                  │
                  ├──► visual evidence
                  │
                  ▼
        descriptive-analysis script
                  │
                  ├──► coverage and distribution summaries
                  ├──► country and period comparisons
                  ├──► association summaries
                  ├──► stationarity diagnostic
                  └──► modeling handoff and report
```

The stage reads but never modifies `data/derived/`. It runs after visualization
and before modeling so that observed structure informs later assumptions and
evaluation choices.

## Input contract

`scripts/describe-maize-data.R` reads
`data/derived/maize-yield-with-precipitation.csv` and requires:

- 297 rows;
- one unique row per `project_country_id + year`;
- nine project countries observed from 1990 through 2022;
- yield in tonnes per hectare;
- October-April country-area precipitation in millimetres; and
- non-negative yield and precipitation values.

The coverage output checks the expected 33 values for each country and
variable. Equal coverage does not make the countries representative and does
not turn national observations into farm-level measurements.

## Descriptive contracts

The implementation combines complementary evidence:

| Feature | Measures | Required companion |
| --- | --- | --- |
| Coverage | Rows, years, available and missing values | Grain and population statement |
| Location | Mean, median, quartiles | Observation count and distribution plot |
| Dispersion | SD, IQR, minimum, maximum | Location and time-series plot |
| Association | Covariance and Pearson correlation | Paired count, scope, and scatterplot |
| Stability | Period mean change, SD ratio, lag-one correlation | Full series, period counts, and qualified interpretation |

No statistic is interpreted without its denominator, group, period, unit, and
claim boundary.

## Fixed period comparison

The script uses periods already implied by the predictive workflow:

| Code | Years | Role |
| --- | --- | --- |
| `earlier_history` | 1990–2005 | Earlier context |
| `recent_training` | 2006–2017 | Recent model-training history |
| `later_test` | 2018–2022 | Time-aware evaluation period |

These definitions are fixed before comparing results. The five-year test
period produces less stable estimates than the longer periods, so its SD,
IQR, and correlations must be interpreted cautiously.

## Association scopes

The association table distinguishes:

- all countries and years pooled;
- each country across all years;
- all countries within each period; and
- each country within each period.

Pooled association contains both within-country variation and differences
between country levels. Comparing scopes makes aggregation visible. The
project does not interpret covariance or correlation as a precipitation effect:
country, time, irrigation, temperature, inputs, measurement, and spatial
aggregation remain possible explanations.

## Stationarity boundary

The project does not assign `stationary = yes` or `stationary = no`. Its
diagnostic reports:

- the observed change in mean yield from recent training to later test;
- that change relative to the recent-training SD;
- the ratio of later-test to recent-training SD;
- full-series lag-one yield correlation and pair count; and
- an explicit interpretation warning.

Review these measures with the complete time-series plots, all three period
summaries, missingness, metadata, and domain knowledge. They can reveal
evidence of level change, changing variation, or temporal dependence, but a
finite dataset cannot prove a process stationary. Formal stationarity tests
are outside the core implementation.

## Outputs

The script creates:

| Artifact | Purpose |
| --- | --- |
| `results/tables/descriptive-coverage.csv` | Country coverage and missingness |
| `results/tables/maize-yield-summary.csv` | Full-period country yield descriptions |
| `results/tables/maize-yield-period-summary.csv` | Country yield descriptions by fixed period |
| `results/tables/precipitation-summary.csv` | Country precipitation descriptions by period |
| `results/tables/yield-precipitation-association.csv` | Association by analytical scope |
| `results/tables/stationarity-diagnostic.csv` | Transparent period and lag-one diagnostics |
| `results/descriptive-modeling-handoff.md` | Generated interpretation and modeling questions |
| `reports/descriptive-data-analysis.html` | Rendered, human-readable evidence |

Results and rendered reports are ignored by Git because the tracked script,
fixed inputs, environment, and report source recreate them.

## Reproducible execution

Run upstream stages, visualization, and description from the repository root:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/integrate-data.R
Rscript scripts/visualize-maize-data.R
Rscript scripts/describe-maize-data.R
quarto render reports/descriptive-data-analysis.qmd
```

Alternatively, `Rscript scripts/run-all.R` runs this stage in the recorded
order and renders its report when Quarto is available. The fixed learner
workflow requires no network access.

## Relationship to modeling

The generated handoff separates two future aims:

- explanatory modeling must state which relationship is of interest and how
  country, time, measurement, and omitted factors affect interpretation; and
- predictive modeling must preserve time order, evaluate later observations,
  and qualify transferability when levels, variation, or associations change.

Descriptive findings suggest requirements; they do not select a model or
validate its assumptions automatically.

## Maintenance checklist

When inputs, periods, or questions change:

1. review the input grain, keys, variables, units, and source limitations;
2. revise descriptive contracts before calculations;
3. rerun preparation, integration, and visualization;
4. regenerate every table and the modeling handoff;
5. compare tables with saved figures and inspect small denominators;
6. review association and stationarity claim boundaries;
7. render `reports/descriptive-data-analysis.qmd`;
8. update this document if workflow roles or outputs change; and
9. commit only tracked code, report source, and documentation.
