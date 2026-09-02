# Explanatory-modeling implementation

This document explains how the standalone `maize-yield-project` implements
Explanatory Modeling as a causal-analysis workflow. The learning module
provides the broader concepts and guided exercise.

## Place in the workflow

The stage begins with descriptive evidence and an explicit causal model:

```text
integrated country-year data
             │
             ├──► descriptive evidence and modeling handoff
             │
             ▼
causal question, estimand, diagram and assumptions
             │
             ▼
exposure support and planned regression sequence
             │
             ├──► estimates and model diagnostics
             ├──► residual-dependence evidence
             └──► bounded conclusion and report
```

It runs before the separate predictive stage. Explanatory modeling asks what
a relationship means under causal assumptions; predictive modeling evaluates
future or held-out predictions. Model fit cannot substitute for either causal
identification or predictive evaluation.

## Tracked causal design

`docs/causal-model.md` records before result interpretation:

- target population and country-year unit;
- precipitation exposure and 100 mm contrast;
- national maize-yield outcome and timing;
- potential-outcomes estimand;
- causal diagram and variable inventory;
- identification assumptions and judgment;
- planned adjustment and sensitivity sequence; and
- evidence needed for stronger causal inference.

The file is tracked because changing an estimand or causal assumption changes
the analysis even when code and data remain unchanged.

## Input contract

`scripts/explain-maize-yield.R` reads
`data/derived/maize-yield-with-precipitation.csv` and requires:

- 297 complete rows;
- one unique row per `project_country_id + year`;
- non-negative yield and precipitation;
- national maize yield in tonnes per hectare; and
- October-April country-area precipitation in millimetres.

Precipitation is rescaled to units of 100 mm and year is centered at 1990 for
coefficient readability. These transformations do not improve causal
identification.

## Identification boundary

The implementation does not identify the proposed causal effect credibly:

- the precipitation total has multiple timing, intensity, and spatial versions;
- temperature, irrigation, inputs, management, and other changing common causes are unmeasured;
- national yield and country-area precipitation are imperfectly aligned;
- country-year units can share weather, water, market, and policy processes;
- exposure ranges differ across countries and short periods; and
- the selected nine-country teaching panel has a limited target population.

Country indicators and a common time trend are proxies, not a sufficient
adjustment set. Every estimate carries the interpretation label “adjusted
association; causal effect not identified.”

## Planned model sequence

| Model | Specification role | Interpretation boundary |
| --- | --- | --- |
| `unadjusted` | Pooled linear precipitation association | Country and time structure uncontrolled |
| `country` | Common within-country association | Changing common causes remain |
| `time` | Association conditional on common linear trend | Country differences remain |
| `country_time` | Within-country association around common trend | Main adjusted association, not causal effect |
| `nonlinear_sensitivity` | Quadratic functional-form check | Identification limitations unchanged |

The nonlinear model reports an average modeled derivative at observed
precipitation values rather than interpreting its linear polynomial coefficient
alone.

## Support, diagnostics and uncertainty

Exposure support is reported overall, by country, and by country-period. This
makes extrapolation risks visible but cannot prove conditional positivity.

For every model the script records:

- sample size and parameter count;
- residual standard deviation;
- residual-fitted and absolute-residual-fitted correlation;
- largest absolute residual;
- maximum Cook's distance and count above `4/n`;
- R-squared and adjusted R-squared; and
- country-specific lag-one residual correlations.

These diagnose aspects of statistical specification. They cannot diagnose
unmeasured confounding or exposure consistency. Default `lm` intervals are
reported as model-based evidence with an explicit warning that repeated
country observations and only nine clusters complicate uncertainty.

## Outputs

| Artifact | Purpose |
| --- | --- |
| `results/tables/explanatory-exposure-support.csv` | Overall and grouped precipitation support |
| `results/tables/explanatory-model-estimates.csv` | Planned estimates, intervals, fit, and interpretation label |
| `results/tables/explanatory-model-diagnostics.csv` | Numerical model checks |
| `results/tables/explanatory-residual-dependence.csv` | Country-specific lag-one residual evidence |
| `results/models/explanatory-country-time-model.rds` | Main fitted association model for report diagnostics |
| `results/explanatory-modeling-conclusion.md` | Generated, value-linked bounded conclusion |
| `reports/explanatory-modeling.html` | Human-readable causal-analysis report |

Generated results and rendered HTML remain ignored. The tracked causal model,
script, report source, fixed inputs, and environment recreate them.

## Reproducible execution

Run the upstream and explanatory stages from the repository root:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
Rscript scripts/integrate-data.R
Rscript scripts/visualize-maize-data.R
Rscript scripts/describe-maize-data.R
Rscript scripts/explain-maize-yield.R
quarto render reports/explanatory-modeling.qmd
```

Alternatively, `Rscript scripts/run-all.R` executes this stage before the
predictive model and renders the report when Quarto is available. The fixed
workflow requires no network access.

## Bounded conclusion policy

The generated conclusion separates:

1. causal question and estimand;
2. data and measurement;
3. identification judgment;
4. statistical specifications and estimates;
5. diagnostics and sensitivity;
6. supported adjusted-association interpretation;
7. unsupported causal interpretation; and
8. evidence needed for stronger inference.

A precise or stable regression coefficient does not override the identification
assessment in `docs/causal-model.md`.

## Relationship to predictive modeling

`scripts/predict-maize-yield.R` remains a separate predictive benchmark. It uses
a time-aware split, fits only the training period, predicts 2018–2022, and
compares MAE and RMSE. Its old header has been corrected so it no longer claims
to fit explanatory models.

The explanatory stage uses all years to characterize an observational
relationship for its stated target period. The predictive stage withholds later
outcomes to evaluate generalization. Neither result should be used as evidence
for the other objective without a new argument.

## Maintenance checklist

When the causal question, data, or model changes:

1. revise `docs/causal-model.md` before inspecting new estimates;
2. review exposure and outcome definitions, timing, grain, and target population;
3. update the DAG and identification assessment;
4. revise the planned model sequence and justify every adjustment variable;
5. rerun all upstream checks and descriptive evidence;
6. inspect support, diagnostics, influence, and residual dependence;
7. review every estimate's causal-claim boundary;
8. render `reports/explanatory-modeling.qmd`; and
9. commit tracked design, code, report source, and documentation only.
