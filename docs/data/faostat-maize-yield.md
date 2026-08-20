# FAOSTAT maize-yield teaching data

## What the data represent

`data/input/faostat-maize-yield-sample.csv` is the fixed agricultural input for
the project. It contains annual country-level observations from the FAOSTAT
Crops and Livestock Products dataset for maize (`Maize (corn)`). The included
measures are harvested area, production, and yield.

One row represents one measure for one reporting area, calendar year, and
unit. The candidate key is:

```text
area + item + element + year + unit
```

The sample covers Botswana, Eswatini, Lesotho, Malawi, Mozambique, Namibia,
South Africa, Zambia, and Zimbabwe from 1990 through 2022. It has 891 data rows
(9 countries x 33 years x 3 measures).

## Why the project uses it

The data provide a compact starting point for teaching validation, reshaping,
unit conversion, exploratory analysis, and simple predictive modelling. A
tracked snapshot makes the normal student workflow reproducible and available
offline.

## Acquisition and project transformations

Maintainers download the complete normalized FAOSTAT bulk dataset with
`scripts/acquire-faostat-data.R`. The script
`scripts/create-faostat-data-teaching-sample.R` then selects the project
countries, years, commodity, and measures. Students normally use the tracked
sample and do not need to download the bulk data.

`scripts/prepare-maize-data.R` reshapes the long input into a country-year
panel, converts yield from `kg/ha` to `t/ha`, and derives the natural logarithm
of positive yield. The raw teaching input is never edited in place.

## Interpretation and limitations

- The observations are national aggregates and hide subnational variation.
- Provider flags describe the origin or treatment of reported values and must
  remain available during validation.
- Historical observations may be revised by FAOSTAT.
- The teaching extract omits provider numeric codes and notes. Its labels are
  suitable for this fixed exercise but are not robust integration keys.
- Cross-country differences can reflect reporting practices as well as
  agricultural conditions.
- These data alone do not support causal conclusions about changes in yield.

The sample contains no personal or confidential data. Current FAOSTAT terms
and attribution requirements should nevertheless be reviewed before creating
or redistributing a new extract.

## Related records

- Column definitions: `metadata/faostat-maize-yield-data-dictionary.csv`
- Provider flag meanings: `metadata/faostat-flag-code-list.csv`
- Source description: `faostat_qcl` in `metadata/source-metadata.yml`
- Exact artifact history and checksum: `faostat_maize_snapshot` in
  `metadata/provenance.yml`
- Validation implementation: `scripts/validate-data.R` and
  `reports/data-validation.qmd`
