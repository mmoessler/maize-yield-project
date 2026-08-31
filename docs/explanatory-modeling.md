# Explanatory-analysis implementation

This document explains how the standalone `maize-yield-project` implements
Explanatory Analysis as a causal-reasoning workflow. The learning module
provides the broader concepts and guided exercise.

## Place in the workflow

The stage combines separately prepared data under an explicit temporal and
causal contract:

```text
maize yield + precipitation       public agricultural expenditure
             │                                  │
             └──────────────┬───────────────────┘
                            ▼
                 lag expenditure by one year
                            │
                            ▼
       causal question, diagram and identification assessment
                            │
                            ▼
           support, model sequence and diagnostic evidence
                            │
                            ▼
                    bounded conclusion
```

The stage runs before predictive modeling. Explanatory analysis asks what an
observed relationship could mean under causal assumptions; predictive
analysis evaluates held-out predictions. Model fit cannot substitute for
either causal identification or predictive evaluation.

## Tracked causal design

`docs/causal-model.md` records before result interpretation:

- public agricultural expenditure as the exposure;
- a one-percentage-point contrast;
- the one-year exposure-outcome lag;
- subsequent national maize yield as the outcome;
- the observed, unbalanced target population;
- the causal diagram and variable roles;
- identification assumptions and judgment; and
- the planned adjustment and sensitivity sequence.

The design file is tracked because changing the question or assumptions
changes the analysis even when the regression code remains similar.

## Input and sample contract

`scripts/explain-maize-yield.R` reads:

- `data/derived/maize-yield-with-precipitation.csv`; and
- `data/derived/public-agricultural-expenditure-panel.csv`.

It requires 297 unique maize country-years and 180 unique observed expenditure
country-years. It shifts each expenditure year forward by one and joins it to
the following year's maize outcome:

```text
expenditure in t - 1 ──► maize yield in t
```

The resulting analysis has 172 unique country-years. Eight countries
contribute outcomes for 2002–2022; Zimbabwe contributes four observations
corresponding to its limited expenditure coverage. The script preserves this
selection rather than imputing missing exposures.

Annual expenditure is not a timestamped intervention, and the October–April
growing season begins during the expenditure calendar year. The lag is an
explicit alignment rule, not evidence that every represented expenditure
occurred before crop development.

`results/tables/explanatory-analysis-sample-audit.csv` records input rows,
matched rows, country coverage, year range, lag, key uniqueness, and unmatched
observations.

## Exposure and covariate roles

The focal exposure is
`prior_agriculture_expenditure_share_percent`: the prior-year percentage of
total government expenditure allocated to agriculture, forestry, fishing, and
hunting at FAOSTAT's highest available government level.

The exposure is not:

- absolute agricultural spending;
- maize-specific spending;
- a measure of implementation quality;
- the composite Agriculture Orientation Index; or
- a randomized policy assignment.

Outcome-year CHIRPS precipitation remains in the main model as an important
environmental cause of maize yield. It is no longer the focal causal exposure.
Its role does not repair unmeasured policy, fiscal, or economic confounding.

## Identification boundary

The project does not identify a causal expenditure effect credibly:

- governments may change spending in response to earlier harvests and crises;
- a one-year lag establishes order but does not eliminate reverse causality;
- equal shares can represent different budgets, programmes, and sectors;
- government-level coverage changes for some countries;
- key time-varying common causes are unmeasured;
- exposure support differs across countries; and
- Zimbabwe's four observations provide little within-country information.

Country and outcome-year indicators plus precipitation are transparent
adjustments, not a proven sufficient adjustment set. All estimates retain the
label `adjusted association; causal effect not identified`.

## Planned model sequence

| Model | Specification | Role |
| --- | --- | --- |
| `unadjusted` | Expenditure share | Pooled association |
| `country` | Expenditure share + country | Association after stable country differences |
| `country_year` | Expenditure share + country + outcome-year indicators | Add shared annual shocks |
| `country_year_weather` | Previous model + precipitation | Main adjusted association |
| `nonlinear_sensitivity` | Quadratic expenditure + country + year + precipitation | Functional-form sensitivity |

The nonlinear model reports the average modeled derivative at observed
expenditure shares. It does not interpret the polynomial's linear coefficient
as a constant effect.

## Support, diagnostics, and uncertainty

Exposure support is reported overall, by country, and by country-period. The
table includes observed expenditure-year ranges, quantiles, ranges, and the
number of represented government levels.

For every model, the script records:

- sample size and parameter count;
- residual standard deviation;
- residual-fitted and absolute-residual-fitted correlations;
- largest absolute residual;
- Cook's distance and count above `4/n`;
- R-squared and adjusted R-squared; and
- country-specific lag-one residual correlations.

These checks concern statistical specification, not unmeasured confounding or
causal direction. Default `lm` intervals are model-based; only nine countries,
an unbalanced panel, and temporal dependence limit conventional uncertainty
claims.

## Outputs

| Artifact | Purpose |
| --- | --- |
| `results/tables/explanatory-analysis-sample-audit.csv` | Records temporal matching and sample selection |
| `results/tables/explanatory-exposure-support.csv` | Reports expenditure-share support and government-level variation |
| `results/tables/explanatory-model-estimates.csv` | Stores estimates, intervals, fit, and interpretation labels |
| `results/tables/explanatory-model-diagnostics.csv` | Stores numerical model checks |
| `results/tables/explanatory-residual-dependence.csv` | Records country-specific lag-one residual evidence |
| `results/models/explanatory-country-year-weather-model.rds` | Stores the main adjusted-association model |
| `results/explanatory-modeling-conclusion.md` | Provides a generated, value-linked bounded conclusion |
| `reports/explanatory-modeling.html` | Presents the human-readable explanatory report |

Generated results and rendered HTML remain ignored. The tracked inputs,
environment, causal design, script, and report source recreate them.

## Reproducible execution

Run the necessary stages from the repository root:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/prepare-public-agricultural-expenditure-data.R
Rscript scripts/integrate-data.R
Rscript scripts/explain-maize-yield.R
quarto render reports/explanatory-modeling.qmd
```

Alternatively, `Rscript scripts/run-all.R` executes the complete workflow. The
fixed teaching inputs make the analysis available without network access.

## Bounded conclusion policy

The generated conclusion separates:

1. the causal question and provisional estimand;
2. data alignment, missingness, and measurement;
3. the identification judgment;
4. model specifications and estimates;
5. diagnostics and sensitivity;
6. the supported adjusted-association interpretation;
7. unsupported causal policy claims; and
8. evidence needed for stronger inference.

A precise, stable, or statistically significant coefficient does not override
the identification assessment in `docs/causal-model.md`.

## Maintenance checklist

When the causal question, data, or model changes:

1. revise `docs/causal-model.md` before inspecting new estimates;
2. review exposure, outcome, lag, grain, and target population;
3. update the causal diagram and identification assessment;
4. justify each adjustment variable according to its causal role and timing;
5. rerun preparation and inspect the sample audit;
6. inspect support, diagnostics, influence, and residual dependence;
7. review every estimate's causal-claim boundary;
8. render `reports/explanatory-modeling.qmd`; and
9. commit tracked design, code, report source, and documentation only.
