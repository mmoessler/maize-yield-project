# Data-acquisition-and-integration implementation

## Purpose

This topic combines two sources with different origins, schemas, spatial
support, and time definitions:

1. annual country-level maize statistics from FAOSTAT; and
2. satellite-informed CHIRPS precipitation estimates summarized over country
   polygons for the October-April growing season.

The example teaches source evaluation, reproducible acquisition, explicit
identifiers, temporal alignment, validation before joining, lineage, and
responsible interpretation. It is not a crop-yield forecasting model.

## Implemented components

| Component | File | Role |
|---|---|---|
| Fixed FAOSTAT input | `data-raw/faostat-maize-yield-sample.csv` | Stable offline agricultural source |
| Fixed CHIRPS input | `data-raw/chirps-growing-season-precipitation.csv` | Stable offline environmental source |
| CHIRPS acquisition | `scripts/acquire-chirps-data.R` | Deliberately refresh country zonal summaries |
| Boundary reference | `metadata/project-country-boundaries.geojson` | Define the areas submitted to ClimateSERV |
| Identifier crosswalk | `metadata/country-crosswalk.csv` | Map FAOSTAT labels to stable project IDs |
| Source metadata | `metadata/source-metadata.yml` | Describe source products and interpretation |
| Provenance | `metadata/provenance.yml` | Identify exact artifacts, checksums, and transformations |
| Dictionaries | `metadata/*data-dictionary.csv` | Define raw and integrated columns |
| Integration | `scripts/integrate-data.R` | Validate and left-join the two sources |
| Join audit | `data-processed/data-integration-audit.csv` | Record coverage and key checks |
| Report | `reports/data-integration.qmd` | Communicate results and limitations |

Source metadata and provenance are deliberately separate. Source metadata
explains what FAOSTAT, CHIRPS, and Natural Earth mean. Provenance identifies the
exact files used here, their checksums, and how they were created. The former
should not duplicate artifact checksums; the latter should not reproduce a
provider's full conceptual documentation.

## Precipitation measure

CHIRPS combines satellite-derived infrared rainfall estimates with rain-gauge
observations. ClimateSERV calculates the spatial average of daily gridded
precipitation across each generalized Natural Earth country polygon. The
acquisition script then sums those daily averages from 1 October through 30
April and assigns the result to the calendar year in which the season ends.

Thus `year = 2022` represents 1 October 2021 through 30 April 2022. The measure
is in millimetres and is named `growing_season_precipitation_mm`.

This definition makes the temporal join teachable and transparent, but it is a
simplification. Countries and production systems have different planting and
harvest calendars. The values are country-area averages rather than summaries
weighted to maize-growing areas. Generalized boundaries and gridded estimates
also introduce spatial and measurement uncertainty.

## Normal workflow and deliberate refresh

The normal workflow uses both tracked snapshots and therefore runs offline:

```bash
Rscript scripts/run-all.R
```

Acquisition is a maintainer operation, not a hidden prerequisite. To refresh
the precipitation snapshot deliberately:

```bash
Rscript scripts/acquire-chirps-data.R --refresh
sha256sum data-raw/chirps-growing-season-precipitation.csv
```

After refreshing, review row counts, dates, completeness, distributions, and
source/API changes. Then update the corresponding checksum, date, size, and
method in `metadata/provenance.yml` in the same commit. A refresh can change
values because services and source products may be revised.

## Integration contract

The project never joins on display names alone. It maps the FAOSTAT `country`
label to `project_country_id`, validates uniqueness in both sources, and joins
on:

```text
project_country_id + year
```

The FAOSTAT panel is the left table. All 297 maize country-year rows remain;
precipitation is populated for the 45 rows from 2018 through 2022. Before
writing output, `scripts/integrate-data.R` verifies:

- the CHIRPS file checksum;
- required columns and the expected 9 x 5 key grid;
- non-negative precipitation and 212/213 daily observations per season;
- crosswalk and source-key uniqueness;
- no unknown project IDs; and
- unchanged row count and key uniqueness after the join.

## Interpretation boundary

The integrated data can illustrate whether wetter and drier country-seasons
coincide with higher or lower reported yield. It does not establish that
rainfall caused yield differences. Irrigation, rainfall timing and intensity,
heat, soils, varieties, pests, inputs, management, reporting practices, and
subnational production patterns are omitted. Both excessive and insufficient
rainfall can reduce yield, so a simple positive linear relationship should not
be assumed.

## Further resources

- [CHIRPS overview](https://www.chc.ucsb.edu/data/chirps)
- [ClimateSERV API documentation](https://climateserv.servirglobal.net/develop-api)
- [CHIRPS methods paper](https://doi.org/10.1038/sdata.2015.66)
- [FAOSTAT Crops and Livestock Products](https://www.fao.org/faostat/en/#data/QCL)
- [Natural Earth Admin 0 countries](https://www.naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries/)
- [The Turing Way: Research Data Management](https://book.the-turing-way.org/reproducible-research/rdm)
