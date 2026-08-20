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
| FAOSTAT acquisition | `scripts/acquire-faostat-data.R` | Download the complete normalized bulk dataset |
| FAOSTAT sample creation | `scripts/create-faostat-data-teaching-sample.R` | Reduce the bulk input to the fixed project scope |
| Fixed FAOSTAT input | `data/input/faostat-maize-yield-sample.csv` | Stable offline agricultural input |
| Fixed CHIRPS input | `data/input/chirps-growing-season-precipitation.csv` | Stable offline environmental input |
| Dataset documentation | `docs/data/` | Explain each input, spatial reference, and integrated artifact for readers |
| Boundary acquisition | `scripts/acquire-country-boundaries.R` | Recreate project polygons from a verified Natural Earth release |
| CHIRPS acquisition | `scripts/acquire-chirps-data.R` | Deliberately refresh country zonal summaries |
| Boundary reference | `metadata/project-country-boundaries.geojson` | Define the areas submitted to ClimateSERV |
| Identifier crosswalk | `metadata/project-country-crosswalk.csv` | Map FAOSTAT labels to stable project IDs |
| Source metadata | `metadata/source-metadata.yml` | Describe source products and interpretation |
| Provenance | `metadata/provenance.yml` | Identify exact artifacts, checksums, and transformations |
| FAOSTAT dictionary | `metadata/faostat-maize-yield-data-dictionary.csv` | Define the fixed FAOSTAT input columns |
| CHIRPS dictionary | `metadata/chirps-growing-season-precipitation-data-dictionary.csv` | Define the growing-season precipitation input columns |
| Integrated dictionary | `metadata/maize-yield-with-precipitation-data-dictionary.csv` | Define the augmented analysis table columns |
| Integration | `scripts/integrate-data.R` | Validate and left-join the two sources |
| Join audit | `results/tables/data-integration-audit.csv` | Record coverage and key checks |
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
the spatial reference and then the precipitation snapshot deliberately:

```bash
Rscript scripts/acquire-country-boundaries.R --refresh
sha256sum metadata/project-country-boundaries.geojson
Rscript scripts/acquire-chirps-data.R --refresh
sha256sum data/input/chirps-growing-season-precipitation.csv
```

The boundary script downloads the version-pinned Natural Earth v5.1.1 Admin-0
GeoJSON and refuses to continue unless the complete upstream file matches its
expected SHA-256. It selects the nine `ADM0_A3` identifiers in the project
crosswalk, retains only the project identifier, Natural Earth name, and polygon
geometry, validates the result, and replaces the tracked file atomically. The
CHIRPS script passes each resulting geometry to ClimateSERV.

The CHIRPS script requests season years 1990–2022. Because ClimateSERV limits
one request to 20 years, it submits the 1990–2005 and 2006–2022 batches for
each country, monitors the 18 jobs together, and combines them only after
checking exact dates, daily completeness, and unique country-date keys.

After refreshing, review row counts, dates, completeness, distributions, and
source/API changes. Then update the corresponding checksums, dates, sizes, and
method in `metadata/provenance.yml` in the same commit. A refresh can change
values because services and source products may be revised.

## Integration contract

The project never joins on display names alone. It maps the FAOSTAT `country`
label to `project_country_id`, validates uniqueness in both sources, and joins
on:

```text
project_country_id + year
```

The FAOSTAT panel is the left table. All 297 maize country-year rows remain and
have precipitation for the corresponding 1990–2022 season. Before
writing output, `scripts/integrate-data.R` verifies:

- the CHIRPS file checksum;
- required columns and the expected 9 x 33 key grid;
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
