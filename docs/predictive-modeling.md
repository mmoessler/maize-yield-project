# Predictive-modeling implementation

This document explains how the standalone `maize-yield-project` implements
Predictive Modeling. The learning module provides the broader concepts and
guided exercise.

## Place in the workflow

The predictive stage begins after the analysis-ready maize panel and the
descriptive and explanatory stages:

```text
prepared country-year maize panel
               │
               ├──► descriptive evidence about time and stability
               ├──► separate causal analysis of precipitation and yield
               │
               ▼
prediction contract and fixed temporal split
               │
               ▼
training-only benchmark fitting
               │
               ▼
held-out predictions for 2018–2022
               │
               ├──► overall and country-level errors
               ├──► observed-versus-predicted figure
               └──► bounded conclusion and report
```

Predictive modeling asks how a complete procedure performs on relevant unseen
observations. It does not identify why yields change or whether a predictor
causes yield.

## Prediction contract

The core implementation fixes the task before evaluation:

| Component | Project decision |
| --- | --- |
| Target | Annual national `log_yield` |
| Prediction unit | One country-year |
| Target population | Nine project countries represented during training |
| Training period | 1990–2017 |
| Test period | 2018–2022 |
| Information set | Country identity and calendar year |
| Candidates | Historical mean, common linear trend, country-plus-time model |
| Evaluation | Row-level errors, MAE, RMSE, country diagnostics, and time plot |
| Intended use | Reproducible teaching benchmark |
| Excluded use | Operational forecasting, new-country transfer, causal inference, and high-stakes decisions |

The exercise does not define an operational issue date or prediction horizon.
It is therefore described as a **held-out later-period benchmark**, not as a
validated pre-season crop forecast.

Realized CHIRPS precipitation is deliberately excluded. It would be a valid
predictor only for a task issued after the relevant seasonal observations are
available. A pre-season or in-season task requires a new feature-availability
contract and potentially different precipitation information.

## Input and split contract

`scripts/predict-maize-yield.R` reads
`data/derived/maize-yield-panel.csv` and requires:

- 297 complete country-year observations;
- coverage from 1990 through 2022;
- one unique row per `country + year`;
- positive yield and complete log yield;
- 252 training observations through 2017;
- 45 test observations from 2018 through 2022; and
- every test country to occur in training.

The fixed temporal split represents learning from earlier observations and
predicting later years. It does not test transfer to countries absent from
training. A random country-year split would answer a different question and
could place temporally adjacent observations from one country on both sides.

## Candidate procedures

| Candidate | Training-only information | Question tested |
| --- | --- | --- |
| `historical-mean` | One mean log yield | Can any modeled structure beat a constant? |
| `linear-trend` | One pooled intercept and year slope | Does common temporal change improve prediction? |
| `country-model` | Country indicators and a common year slope | Do persistent country differences improve later prediction? |

The candidates are fixed transparent benchmarks. They are not selected from a
large search, tuned against the test set, or presented as an operational model.
All means and coefficients are learned from 1990–2017 only. Test outcomes enter
the workflow only after predictions have been created.

## Error measures

For observed log yield \(y_i\) and prediction \(\hat{y}_i\), the script defines
error as:

```text
error = observed - predicted
```

Positive mean error indicates underprediction and negative mean error indicates
overprediction. The implementation reports:

- mean error for direction;
- mean absolute error (MAE) for average absolute magnitude; and
- root mean squared error (RMSE), which emphasizes larger misses.

All core measures are on the log-yield scale. They must not be described as
errors in tonnes per hectare. Back-transforming mean predictions requires a
separate estimand and bias decision.

## Leakage controls

The implementation protects the evaluation by:

- defining the split directly from calendar year;
- validating the split and known-country population;
- fitting every mean and coefficient on training observations only;
- passing only country and year from test rows into `predict()`;
- keeping realized precipitation outside the core information set;
- preserving row-level predictions for metric reconstruction; and
- treating the test set as final evaluation rather than repeated tuning data.

If preprocessing that learns imputation values, scales, encodings, or selected
features is added later, it must also be fitted within training or within each
validation resample.

## Outputs

| Artifact | Purpose |
| --- | --- |
| `results/tables/predictive-split-audit.csv` | Partition, country, coverage, missing-target, and duplicate checks |
| `results/tables/maize-yield-predictions.csv` | Stable country-year keys, observed targets, and candidate predictions |
| `results/tables/model-performance.csv` | Overall sample size, bias, MAE, RMSE, and baseline improvement |
| `results/tables/predictive-performance-by-country.csv` | Country-level diagnostics with denominators |
| `results/models/predictive-benchmark-models.rds` | Fitted candidates and task metadata |
| `figures/predictive-observed-versus-predicted.png` | Held-out observed and candidate prediction paths |
| `results/predictive-modeling-conclusion.md` | Generated, value-linked bounded conclusion |
| `reports/predictive-modeling.html` | Human-readable evaluation report |

Generated results, figures, model objects, and rendered HTML remain ignored.
The tracked script, report source, fixed input, documentation, and environment
recreate them.

## Reproducible execution

Run the upstream preparation and predictive stage from the repository root:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/predict-maize-yield.R
quarto render reports/predictive-modeling.qmd
```

Alternatively, `Rscript scripts/run-all.R` executes the full teaching workflow
and renders the predictive report when Quarto is available. The fixed workflow
requires no network access.

## Interpretation boundary

The evaluation supports a narrow statement: how three predefined procedures
performed for the represented countries during 2018–2022 after fitting on
1990–2017 observations.

It does not establish:

- performance after 2022 or under unprecedented conditions;
- performance for a country absent from training;
- an operational issue-time forecast;
- an acceptable error for a specific policy decision;
- a causal effect of country, calendar year, or precipitation; or
- suitability for insurance, food-security alerts, or resource allocation.

Only five held-out observations are available per country. Country metrics are
diagnostic and must be reported with their denominators. Overall averages can
hide large errors or systematic failures in particular countries.

## Maintenance checklist

When the predictive task, data, or candidates change:

1. revise the prediction contract before inspecting new test outcomes;
2. document the issue time, horizon, population, information set, and loss;
3. preserve time, group, and feature-availability boundaries;
4. fit preprocessing and models using training data only;
5. use validation data or time-aware resampling for model selection;
6. retain an untouched final test set;
7. compare every candidate under identical rows, scale, and metrics;
8. inspect row-level, country, time, and large-error behavior;
9. rerender `reports/predictive-modeling.qmd`; and
10. commit tracked documentation, code, and report source only.
