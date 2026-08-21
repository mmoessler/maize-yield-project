# Data-preparation implementation

This document explains how the standalone `maize-yield-project` implements
reproducible data preparation. It is a repository-specific reference; the
learning module provides the broader motivation, concepts, and guided exercise.

## Place in the workflow

The project gives the adjacent topics distinct responsibilities:

| Topic | Project responsibility |
| --- | --- |
| Data management | Preserve, organize, describe, and validate fixed inputs |
| Data preparation | Transform the FAOSTAT input into a documented country-year panel |
| Data integration | Combine that panel with temporally aligned CHIRPS precipitation |

Preparation occurs before integration here because the FAOSTAT provider table
must first be represented at the intended country-year grain. Later analyses
may make additional purpose-specific transformations, particularly those that
must be learned from training data without seeing the test period.

## Preparation contract

| Component | Project decision |
| --- | --- |
| Purpose | Country-year exploration, integration, and modeling of maize yield |
| Input | `data/input/faostat-maize-yield-sample.csv` |
| Input grain | One area-item-element-year-unit observation |
| Input key | `area + item + element + year + unit` |
| Population | Nine selected countries, 1990-2022 |
| Output | `data/derived/maize-yield-panel.csv` |
| Output grain | One selected country and calendar year |
| Output key | `country + year` |
| Expected output | 297 rows |
| Missingness | Preserve missing measures; never replace them with zero |

The target grain determines the valid reshape. The script stops rather than
silently aggregating when the source key would produce more than one value for
an output cell.

## Executed transformations

`scripts/prepare-maize-data.R` performs a deterministic sequence:

1. verify the fixed input checksum against `metadata/provenance.yml`;
2. verify required fields, population, period, grain, and expected mappings;
3. retain maize yield, production, and harvested area;
4. rename provider concepts through explicit element-unit mappings;
5. reshape the three measures into a wide country-year panel;
6. convert yield from `kg/ha` to `t/ha`; and
7. derive `log_yield` only where yield is positive.

The source is never overwritten. Re-running the script from the same input and
code replaces only the reproducible derived artifact and audit.

## Validation and preparation

`scripts/validate-data.R` asks whether the managed FAOSTAT input is the
expected teaching artifact. `scripts/prepare-maize-data.R` asks whether the
stated transformations produce the contracted analytical representation.
These checks overlap deliberately at critical boundaries, but they do not have
the same purpose.

Run the stages in order:

```bash
Rscript scripts/validate-data.R
Rscript scripts/prepare-maize-data.R
```

The complete workflow records this order in `scripts/run-all.R`.

## Audit evidence

Preparation writes `results/tables/data-preparation-audit.csv`. Each row records
a check, its expectation, the observed result, and a calculated status. Checks
include:

- exact input identity using SHA-256;
- expected input rows, countries, and years;
- recognized element-unit mappings;
- input and output key uniqueness;
- expected output rows;
- unit-conversion equality within numeric tolerance; and
- valid log-transformation results.

If any critical audit status is `failure`, the script stops before writing the
prepared panel. The audit is generated evidence and is intentionally ignored
by Git.

## Documentation and lineage

The prepared artifact has complementary records:

| Record | File | Responsibility |
| --- | --- | --- |
| Executable transformation | `scripts/prepare-maize-data.R` | Performs and checks preparation |
| Dataset page | `docs/data/maize-yield-panel.md` | Explains purpose, construction, and limitations |
| Data dictionary | `metadata/maize-yield-panel-data-dictionary.csv` | Defines output columns and units |
| Provenance | `metadata/provenance.yml` | Connects the input, script, output, and audit |
| Audit | `results/tables/data-preparation-audit.csv` | Records observed preparation checks |

These records avoid duplicating authority: code executes transformations, CSV
defines variables, YAML records history, Markdown supports interpretation, and
the audit records runtime evidence.

## Reproducibility boundary

The preparation is deterministic and idempotent for the tracked input. It does
not establish that FAOSTAT values are accurate, comparable between countries,
or appropriate for causal inference. It also does not include
training-dependent preprocessing such as estimating imputation values or
scaling parameters. Such operations belong inside a later modeling pipeline
and must be fitted on training data only.

## Review checklist

When the input, preparation contract, or script changes:

1. review the population, grain, key, and intended purpose;
2. update explicit element-unit mappings rather than adding a catch-all;
3. update the panel dictionary and dataset page when columns or meanings change;
4. update provenance when lineage or information loss changes;
5. run validation followed by preparation;
6. inspect every audit status and the generated panel; and
7. run downstream integration and analysis to detect broken assumptions.
