# Prepared maize-yield panel

## Purpose

`data/derived/maize-yield-panel.csv` is the analysis-ready country-year panel
created from the fixed FAOSTAT teaching input. It provides the maize measures
needed for exploration, integration, and modeling without changing the tracked
input file.

The panel is a generated artifact and is not tracked by Git. Recreate it with:

```bash
Rscript scripts/prepare-maize-data.R
```

## Population, grain, and key

The population is nine selected Southern African countries from 1990 through
2022. One row represents one selected country and calendar year. The candidate
key is:

```text
country + year
```

A successful run creates 297 rows: 9 countries multiplied by 33 years.

## Construction

The preparation script:

1. verifies the fixed input against its recorded SHA-256 checksum;
2. checks required columns, coverage, source grain, and element-unit mappings;
3. selects maize yield, production, and harvested area;
4. maps provider elements and units to explicit project variable names;
5. reshapes the long element observations to one country-year row;
6. converts yield from kilograms per hectare to tonnes per hectare; and
7. derives the natural logarithm of positive yield values.

The script preserves missing measurements as missing. It does not replace them
with zero, impute them, or remove unusual observations.

## Variables and lineage

Authoritative column definitions are in
`metadata/maize-yield-panel-data-dictionary.csv`. The principal lineage is:

| Output variable | Source | Transformation |
| --- | --- | --- |
| `country` | FAOSTAT `area` | Rename the retained label |
| `year` | FAOSTAT `year` | Parse as integer |
| `yield_tonnes_per_hectare` | Yield `value` in `kg/ha` | Divide by 1,000 |
| `production_tonnes` | Production `value` in `t` | Reshape into a column |
| `harvested_area_hectares` | Area harvested `value` in `ha` | Reshape into a column |
| `log_yield` | Prepared yield in `t/ha` | Natural log for positive values |

Item, element, unit, and flag fields are not carried into the wide panel. They
remain available in `data/input/faostat-maize-yield-sample.csv`, and their
meaning remains documented in the FAOSTAT dictionary and flag code list.

## Preparation evidence

The script writes `results/tables/data-preparation-audit.csv`. Its calculated
checks cover source identity, input and output dimensions, keys, element-unit
mappings, unit conversion, and the log transformation. A critical failure
prevents the prepared panel from being written.

The artifact history and transformation summary are recorded under
`maize_yield_panel` in `metadata/provenance.yml`.

## Intended uses

The panel supports:

- country-year summaries and visualization of maize yield;
- integration with the CHIRPS growing-season precipitation snapshot; and
- the simple explanatory and predictive teaching exercises in this project.

Analysis-ready means ready for these stated purposes. It does not mean that
the data are error-free or suitable for every agricultural question.

## Limitations

- FAOSTAT observations may be official, estimated, imputed, or revised.
- Country-level annual values hide subnational and seasonal variation.
- Readable country labels are retained here, but integration uses the project
  crosswalk and stable project identifiers.
- A log transformation changes interpretation and is undefined for
  non-positive yield.
- The panel alone cannot support causal conclusions about yield changes.

## Related files

- Input documentation: `docs/data/faostat-maize-yield.md`
- Preparation implementation: `docs/data-preparation.md`
- Script: `scripts/prepare-maize-data.R`
- Dictionary: `metadata/maize-yield-panel-data-dictionary.csv`
- Provenance: `metadata/provenance.yml`
- Audit: `results/tables/data-preparation-audit.csv`
- Downstream integrated data: `docs/data/maize-yield-with-precipitation.md`
