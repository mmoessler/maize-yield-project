# CHIRPS growing-season precipitation teaching data

## What the data represent

`data/input/chirps-growing-season-precipitation.csv` contains project-created
country-season summaries derived from daily CHIRPS v2 precipitation estimates
served through ClimateSERV. CHIRPS combines satellite-derived infrared
rainfall estimates with rain-gauge observations.

One row represents one project country and one October-April season. The
candidate key is:

```text
project_country_id + year
```

The file covers the same nine countries and season years 1990-2022, producing
297 rows. `year` identifies the calendar year in which the season ends: for
example, 2022 represents 1 October 2021 through 30 April 2022.

## How the measure is constructed

`scripts/acquire-chirps-data.R` submits each project-country polygon to
ClimateSERV and requests the spatial average of daily CHIRPS precipitation.
The script sums those daily country-area averages over October-April. The
resulting `growing_season_precipitation_mm` is therefore a seasonal total of
daily spatial averages, expressed in millimetres.

Requests are split into 1990-2005 and 2006-2022 batches because ClimateSERV
limits the time span of one request. The script verifies country-date keys and
expects 212 or 213 daily observations in each season before writing the fixed
teaching snapshot.

## Why the project uses it

Precipitation provides a plausible environmental variable with which to
augment maize statistics. It demonstrates API acquisition, spatial
aggregation, temporal aggregation, source-specific identifiers, and explicit
alignment assumptions without making network access part of the normal lesson.

## Interpretation and limitations

- CHIRPS is a gridded estimate, not a direct measurement at every location.
- The values are country-area averages and are not weighted to maize-growing
  areas.
- National summaries hide rainfall timing, intensity, and subnational
  variation.
- A common October-April season is a teaching simplification; actual crop
  calendars differ among countries and production systems.
- Both insufficient and excessive rainfall can reduce yield, so a simple
  positive relationship should not be assumed.
- Provider revisions, API behavior, or geometry changes can alter a refreshed
  snapshot.

## Related records

- Column definitions:
  `metadata/chirps-growing-season-precipitation-data-dictionary.csv`
- Source description: `chirps_v2_climateserv` in
  `metadata/source-metadata.yml`
- Exact artifact history, parameters, and checksum:
  `chirps_precipitation_snapshot` in `metadata/provenance.yml`
- Spatial support: `metadata/project-country-boundaries.geojson`
- Acquisition implementation: `scripts/acquire-chirps-data.R`
