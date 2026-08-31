# Prepared public agricultural expenditure panel

## Purpose and grain

`data/derived/public-agricultural-expenditure-panel.csv` is the analysis-ready
representation of the fixed FAOSTAT public agricultural expenditure sample.
One row represents one observed country-year. Its candidate key is:

```text
country + year
```

The table is intended for later integration with the maize-yield panel and for
teaching explanatory analysis. It is generated and ignored by Git.

## Construction

`scripts/prepare-public-agricultural-expenditure-data.R`:

1. verifies the input SHA-256 against `metadata/provenance.yml`;
2. validates the provider schema, selected item, element, and unit;
3. checks candidate-key uniqueness and percentage bounds;
4. maps provider columns to project-facing names;
5. retains the estimated-value flag and reported government level; and
6. records expected unbalanced coverage in a machine-readable audit.

No observations are imputed and no missing country-years are converted to
zero. The source sample is never overwritten.

## Variables

The panel contains:

- `country` and `year` as its key;
- `agriculture_share_government_expenditure_percent` as the proposed
  policy-related exposure;
- `source_flag` for provider status; and
- `government_level` for the government coverage represented by the value.

Detailed definitions are in
`metadata/public-agricultural-expenditure-panel-data-dictionary.csv`.

## Analytical boundary

The panel does not by itself identify a causal effect of public agricultural
expenditure on maize yield. Its values are not randomized, may respond to past
agricultural outcomes, and represent heterogeneous expenditure packages.
Government-level changes can also create measurement breaks.

Before modeling, the later explanatory-analysis stage must define an exposure
lag, inspect within-country support and missingness, record a causal diagram,
and determine which comparisons are defensible. Any initial regression result
should be described as an adjusted association unless a credible identification
strategy is established.
