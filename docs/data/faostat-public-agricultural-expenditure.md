# FAOSTAT public agricultural expenditure teaching data

## What the data represent

`data/input/faostat-public-agricultural-expenditure-sample.csv` is a fixed
extract from the FAOSTAT Government Expenditure domain. It contains the
**Agriculture share of Government Expenditure** component of SDG indicator
2.a.1 for the nine project countries and the 2001–2022 teaching period.

The indicator reports the percentage of total government expenditure allocated
to agriculture, forestry, fishing, and hunting at the highest government level
available to FAOSTAT. It is a broad expenditure-priority measure, not spending
on maize and not the composite Agriculture Orientation Index.

One row represents one reporting area, indicator, year, and unit. The candidate
key is:

```text
area + item + element + year + unit
```

## Coverage and missingness

Botswana, Eswatini, Lesotho, Malawi, Mozambique, Namibia, South Africa, and
Zambia each have 22 observations covering 2001–2022. Zimbabwe has four
observations covering 2009–2012. The tracked sample therefore contains 180
rows and is intentionally unbalanced.

An absent country-year means that this extract contains no provider
observation. It must not be interpreted as zero expenditure or filled merely
to create a balanced panel.

## Why the project uses it

The data support a general explanatory question about whether a greater public
expenditure share allocated to agriculture is associated with subsequent
national maize yield. The country-year grain is compatible with the FAOSTAT
maize-yield panel, while the incomplete and changing source context creates
realistic opportunities to teach coverage checks, temporal ordering,
confounding, and bounded causal interpretation.

## Acquisition and preparation

Maintainers download the complete normalized FAOSTAT bulk dataset with
`scripts/acquire-faostat-government-expenditure-data.R`. The script
`scripts/create-faostat-government-expenditure-teaching-sample.R` selects the
project countries, indicator, and 2001–2022 period. Students normally use the
tracked sample and do not need network access.

`scripts/prepare-public-agricultural-expenditure-data.R` verifies the fixed
sample checksum, validates its schema, key, values, and expected unbalanced
coverage, and writes:

- `data/derived/public-agricultural-expenditure-panel.csv`; and
- `results/tables/public-agricultural-expenditure-preparation-audit.csv`.

The prepared panel keeps the source flag and reported government level rather
than treating `value` as context-free.

## Interpretation and limitations

- The percentage describes budget orientation, not an absolute expenditure
  amount or implementation effectiveness.
- The expenditure category is broader than crop production and is not
  maize-specific.
- All values in the tracked extract carry FAOSTAT's `E` estimated-value flag.
- The highest available government level differs between countries and changes
  over time for Botswana, Lesotho, Mozambique, Namibia, and Zambia.
- Public expenditure may respond to poor harvests, fiscal conditions, crises,
  or political priorities; temporal ordering alone does not remove endogeneity.
- Historical observations can be revised by FAOSTAT.
- The short, unbalanced panel restricts comparisons and causal identification.

The data contain no personal or confidential information.

## Related records

- Input dictionary:
  `metadata/faostat-public-agricultural-expenditure-data-dictionary.csv`
- Prepared dictionary:
  `metadata/public-agricultural-expenditure-panel-data-dictionary.csv`
- Source description: `faostat_ig` in `metadata/source-metadata.yml`
- Artifact history: `faostat_public_agricultural_expenditure_snapshot` in
  `metadata/provenance.yml`
- Prepared-data history: `public_agricultural_expenditure_panel` in
  `metadata/provenance.yml`
