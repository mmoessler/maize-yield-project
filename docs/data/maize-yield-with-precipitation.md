# Maize yield augmented with precipitation

## What the data represent

`data/derived/maize-yield-with-precipitation.csv` is the analysis-ready table
that combines the prepared FAOSTAT country-year maize panel with CHIRPS
October-April precipitation. It is generated locally and is not tracked in
Git.

One row represents one project country and year. The candidate key is:

```text
project_country_id + year
```

The expected output has 297 rows covering nine countries from 1990 through
2022. It contains maize yield, production, harvested area, log yield, seasonal
precipitation, season dates, and precipitation completeness information.

## How integration works

`scripts/integrate-data.R` first maps the FAOSTAT country label to a stable
`project_country_id` using `metadata/project-country-crosswalk.csv`. It then
left-joins the CHIRPS table on `project_country_id + year`.

The temporal alignment is explicit: FAOSTAT observations for a calendar year
are matched to the October-April precipitation season ending in that year. The
script verifies the CHIRPS checksum, source-key uniqueness, expected country-
year coverage, non-negative precipitation, seasonal completeness, output row
count, and unmatched keys. It records the results in
`results/tables/data-integration-audit.csv`.

## Why the project uses it

The table supports teaching about joining heterogeneous sources and exploring
whether wetter or drier seasons coincide with differences in reported maize
yield. It also makes the assumptions and validation requirements of data
augmentation visible.

## Interpretation and limitations

- The join establishes alignment, not causation.
- Country-year yield and country-area precipitation operate at coarse spatial
  scales and may not describe conditions in maize-growing locations.
- The shared October-April season is a simplifying assumption.
- Irrigation, rainfall timing and intensity, temperature, soils, varieties,
  pests, inputs, and management are omitted.
- The integrated table inherits the limitations and revision risks of both
  source datasets.
- A complete join does not establish that the sources are conceptually
  comparable or fit for every analysis.

## Reproduction and related records

Run `scripts/prepare-maize-data.R` followed by `scripts/integrate-data.R`, or
run the complete workflow with `scripts/run-all.R`.

- Column definitions:
  `metadata/maize-yield-with-precipitation-data-dictionary.csv`
- Transformation lineage: `derived_artifacts` in `metadata/provenance.yml`
- Identifier mapping: `metadata/project-country-crosswalk.csv`
- Integration audit: `results/tables/data-integration-audit.csv`
- Interpretation report: `reports/data-integration.qmd`
