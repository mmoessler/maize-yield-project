# Project-country boundaries

## What the data represent

`metadata/project-country-boundaries.geojson` is a project-specific spatial
reference containing one generalized polygon for each of the nine countries
in the teaching analysis. It is derived from Natural Earth Admin 0 - Countries
version 5.1.1 at 1:110 million scale.

Each feature retains a stable `project_country_id`, a Natural Earth display
name, and its geometry. The project identifier is the candidate key.

## Why the project uses it

ClimateSERV requires a geometry over which to summarize gridded CHIRPS data.
The tracked GeoJSON records the exact spatial support used for those requests
and lets maintainers audit or reproduce the precipitation acquisition.

Although stored under `metadata/`, this file is a spatial reference artifact,
not descriptive metadata or an unchanged provider download. Its location
emphasizes that it defines the acquisition scope rather than serving as an
analysis outcome.

## Acquisition and project transformations

`scripts/acquire-country-boundaries.R --refresh` downloads the version-pinned
Natural Earth GeoJSON and verifies the complete upstream file against the
SHA-256 recorded in `metadata/provenance.yml`. It selects the `ADM0_A3` values
listed in `metadata/project-country-crosswalk.csv`, retains only the fields
needed by the project, validates the nine features, and writes the reduced
GeoJSON atomically.

The resulting file is consequently reproducible from a verified source, but
it is not identical to the complete Natural Earth download.

## Interpretation and limitations

- The 1:110 million polygons are intentionally generalized and unsuitable for
  precise boundary, area, or local exposure analysis.
- National polygons conceal subnational environmental and agricultural
  variation.
- Boundary representation does not imply a project position on disputed
  territories.
- Changing the Natural Earth release or geometries changes the spatial support
  of the derived precipitation values and requires a deliberate data refresh.

## Related records

- Project/source identifier mapping: `metadata/project-country-crosswalk.csv`
- Source description: `natural_earth_admin0_110m` in
  `metadata/source-metadata.yml`
- Source and derived-file checksums: `project_country_boundaries` in
  `metadata/provenance.yml`
- Acquisition implementation: `scripts/acquire-country-boundaries.R`
