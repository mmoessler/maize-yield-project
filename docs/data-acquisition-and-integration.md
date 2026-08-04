# Data-acquisition-and-integration implementation

This document explains how the standalone `maize-yield-project` implements the
course workflow for acquiring and integrating multiple sources. It is a
repository-specific implementation note rather than a general lesson.

## Learning application

The project combines:

1. annual FAOSTAT maize yield, production, and harvested area at country level;
2. annual MODIS/Terra net primary productivity (NPP) at one documented 500 m
   teaching reference pixel for each project country.

The satellite component is intentionally small enough to retrieve through a
public API and preserve as an offline snapshot. It exposes an important lesson:
a technically correct country–year join does not make a raster pixel spatially
representative of a country or crop.

## Implemented evidence

| Evidence | File | Purpose |
| --- | --- | --- |
| FAOSTAT acquisition | `scripts/acquire-faostat-data.R` | Retrieve bulk data or use the fixed teaching fallback |
| MODIS acquisition | `scripts/acquire-modis-data.R` | Retrieve annual reference-pixel NPP explicitly |
| Satellite snapshot | `data-raw/modis-npp-reference-sites.csv` | Preserve a compact, identified response for offline teaching |
| Source register | `metadata/source-register.yml` | Record providers, products, methods, parameters, licences, checksums, and scripts |
| Country crosswalk | `metadata/country-crosswalk.csv` | Align FAOSTAT labels, project IDs, and reference coordinates |
| Integration code | `scripts/integrate-data.R` | Validate keys, scale NPP, join sources, and write an audit |
| Output dictionary | `metadata/integration-data-dictionary.csv` | Define integrated fields, units, sources, and qualifications |
| Integration report | `reports/data-integration.qmd` | Present relationship, coverage, lineage, audit, and limitations |

## Data requirement and target grain

The exercise requires maize statistics for the nine project countries and a
second annual observation for 2018–2022. The target output retains one row per
project country and calendar year.

The expected key is:

```text
project_country_id + year
```

The integration uses a left join from the maize panel. This preserves the
complete maize study population and makes absent satellite years visible.

## Satellite source

The satellite product is:

```text
MOD17A3HGF MODIS/Terra Net Primary Production Gap-Filled
Yearly L4 Global 500 m SIN Grid V061
```

It is published through NASA EOSDIS LP DAAC and accessed through the ORNL DAAC
Terrestrial Ecology Subsetting & Visualization Services (TESViS) REST API.
The product DOI is
[10.5067/MODIS/MOD17A3HGF.061](https://doi.org/10.5067/MODIS/MOD17A3HGF.061),
and the service DOI is
[10.3334/ORNLDAAC/1600](https://doi.org/10.3334/ORNLDAAC/1600).

For each country, the script requests one pixel centered on the WGS84
coordinate recorded in the crosswalk. It retains:

- product date and calendar year;
- MODIS tile and processing timestamp;
- raw annual NPP integer;
- NPP quality-control percentage; and
- the requested reference coordinates.

The NPP scale factor is `0.0001`; the scaled unit is kg C/m²/year. Raw values
32761–32767 are provider fill categories and become missing during integration.
The quality percentage is retained rather than silently filtered.

## Acquire or use the fixed snapshot

Normal course execution uses the tracked snapshot:

```bash
Rscript scripts/acquire-modis-data.R
```

The command does not contact the service when the snapshot exists. It reports
that the fixed artifact is being used.

Maintainers can replace the snapshot deliberately:

```bash
Rscript scripts/acquire-modis-data.R --refresh
sha256sum data-raw/modis-npp-reference-sites.csv
```

After refreshing:

1. inspect the raw diff and all new quality values;
2. confirm 45 unique country–year records for 2018–2022;
3. update access information and the SHA-256 in
   `metadata/source-register.yml`;
4. run integration and inspect its audit;
5. render and review the integration report; and
6. commit the snapshot and metadata together.

The API is an external service. A successful HTTP response still requires
schema, row-count, key, and coverage validation. Do not replace a failed source
silently with a scientifically different product.

## Identifier and spatial crosswalk

`metadata/country-crosswalk.csv` maps the FAOSTAT area label to an ISO-based
project identifier. Integration uses the project identifier, not an approximate
name match.

The same file records one latitude/longitude pair per country. This is also a
spatial mapping decision. The points are approximate teaching reference sites;
they are not:

- country-level aggregates;
- representative samples;
- maize field locations;
- crop-mask summaries; or
- evidence that the surrounding pixel caused national yield changes.

Keeping these coordinates in a reviewed data file makes the choice inspectable
and replaceable. Hiding them inside code would make the spatial assumption
harder to audit.

## Integrate and audit

After preparing the maize panel, run:

```bash
Rscript scripts/integrate-data.R
quarto render reports/data-integration.qmd
```

The script checks:

- required input files and satellite columns;
- crosswalk uniqueness in both join directions;
- complete mapping of FAOSTAT country labels;
- absence of unknown satellite identifiers;
- uniqueness of both country–year inputs;
- the expected one-to-one relationship for overlapping keys;
- preservation of maize rows by the left join; and
- uniqueness of the integrated output key.

It writes:

```text
data-interim/maize-yield-with-npp.csv
data-processed/data-integration-audit.csv
```

Both are generated and ignored. The audit reports input/output row counts,
unmatched keys, duplicates, and missing scaled NPP. The report adds coverage,
quality, lineage, and interpretation.

## Lineage

| Output field group | Origin | Integration operation |
| --- | --- | --- |
| Maize measures | FAOSTAT | Filter, reshape, and explicit unit conversion during preparation |
| Project country fields | Reviewed crosswalk | Many-to-one mapping from FAOSTAT label |
| Reference-site NPP | MOD17A3HGF `Npp_500m` | Fill handling and scale factor 0.0001 |
| NPP quality | MOD17A3HGF `Npp_QC_500m` | Retained without silent filtering |
| Coordinates | Reviewed crosswalk/API request | Retained to expose spatial support |
| MODIS date, tile, processing ID | ORNL DAAC response | Retained without analytical recoding |

Field-level definitions are recorded in
`metadata/integration-data-dictionary.csv`.

## Reproducibility and interpretation boundary

The fixed snapshot makes the exercise stable and inspectable. It does not make
the one-pixel measure representative. The current output is suitable for
teaching acquisition and integration mechanics, not for drawing environmental
conclusions about national maize yield.

A defensible research extension would require:

- authoritative country or production-zone boundaries and their vintage;
- a maize or cropland mask;
- raster reprojection and partial-cell rules;
- area-weighted or production-weighted summaries;
- growing-season rather than only calendar-year alignment;
- uncertainty and missing-cell assessment; and
- a documented reason for choosing NPP over another Earth-observation product.

## References

- [ORNL DAAC TESViS web service](https://modis.ornl.gov/data/modis_webservice.html)
- [MOD17A3HGF V061 product DOI](https://doi.org/10.5067/MODIS/MOD17A3HGF.061)
- [MOD17 Collection 6.1 user guide](https://lpdaac.usgs.gov/documents/972/MOD17_User_Guide_V61.pdf)
- [The Turing Way: Research Data Management](https://book.the-turing-way.org/reproducible-research/rdm/)
- [R for Data Science: Joins](https://r4ds.hadley.nz/joins.html)
