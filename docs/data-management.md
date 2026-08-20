# Data-management implementation

This document describes how the standalone `maize-yield-project` makes its
teaching data identifiable, understandable, organized, and auditable. It is a
repository-specific implementation reference, not a general data-management
lesson.

## Implemented evidence

| Evidence | Repository file | Purpose |
| --- | --- | --- |
| Preserved FAOSTAT input | `data/input/faostat-maize-yield-sample.csv` | Fixed, offline teaching input |
| Preserved CHIRPS input | `data/input/chirps-growing-season-precipitation.csv` | Fixed, offline multi-source integration input |
| FAOSTAT maize-yield dictionary | `metadata/faostat-maize-yield-data-dictionary.csv` | Defines fields, types, units, roles, and missing values for the fixed FAOSTAT input |
| FAOSTAT flag code list | `metadata/faostat-flag-code-list.csv` | Preserves provider meanings for FAOSTAT quality flags |
| CHIRPS precipitation dictionary | `metadata/chirps-growing-season-precipitation-data-dictionary.csv` | Defines the project-specific seasonal precipitation fields |
| Integrated-data dictionary | `metadata/maize-yield-with-precipitation-data-dictionary.csv` | Defines the augmented analysis table |
| Project country crosswalk | `metadata/project-country-crosswalk.csv` | Maps stable project identifiers to source-specific country labels |
| Source metadata | `metadata/source-metadata.yml` | Describes FAOSTAT, CHIRPS, and Natural Earth sources without duplicating artifact history |
| Multi-artifact provenance | `metadata/provenance.yml` | Records exact snapshots, checksums, parameters, and derived artifacts |
| Validation code | `scripts/validate-data.R` | Tests justified structural and semantic expectations |
| Validation report | `reports/data-validation.qmd` | Presents evidence, findings, and unresolved questions |

Generated validation results are written to
`results/tables/data-validation-results.csv`; rendered HTML is written beside
the Quarto source. Both follow the generated-output policy and are ignored by
Git.

## Artifact roles and storage

The project organizes artifacts by stable role rather than an ambiguous degree
of processing:

| Directory | Role | Git policy |
| --- | --- | --- |
| `data/source/` | Complete provider downloads used by maintainers | Ignore |
| `data/input/` | Fixed, checksummed teaching inputs used by students | Track |
| `data/derived/` | Reproducibly generated analytical datasets | Ignore |
| `results/tables/` | Generated audits, summaries, predictions, and metrics | Ignore |
| `results/models/` | Generated fitted model objects | Ignore |

The word `input` does not imply that a file is an unchanged provider artifact.
The FAOSTAT input is a project extract and the CHIRPS input is a spatially and
temporally aggregated snapshot. Their provenance records those transformations.

## Fixed-input boundary

The tracked teaching sample is an unchanged, compact extract derived from the
FAOSTAT normalized bulk download. Its SHA-256 checksum is:

```text
fd2c78cae5a5cf2f82d6b6bdc2b3637ce03b597f74e561099f9666af449605be
```

The full archive, extracted bulk tables, normalized working copy, and partial downloads
are working artifacts and remain ignored. Do not edit or resave the teaching
sample manually. Maintainers regenerate it with:

```bash
Rscript scripts/acquire-faostat-data.R
Rscript scripts/create-faostat-data-teaching-sample.R
Rscript scripts/validate-data.R
```

Regeneration can legitimately change the sample when FAOSTAT revises its data.
Review the diff and update the checksum, access information, and findings in
the provenance and validation files deliberately.

## Grain, key, and scope

One row represents one maize element for one reporting area and calendar year,
expressed in one unit. The tested candidate key is:

```text
area + item + element + year + unit
```

The snapshot contains nine Southern African countries, the years 1990–2022,
and these element/unit combinations:

| Element | Unit |
| --- | --- |
| Area harvested | `ha` |
| Production | `t` |
| Yield | `kg/ha` |

The compact sample omits FAOSTAT numeric area, item, and element codes. Labels
are sufficient for this fixed teaching exercise but should not be treated as
stable integration identifiers. Preserve provider codes in future acquisition
and integration work.

## Run validation

From the repository root:

```bash
Rscript scripts/setup.R
Rscript scripts/validate-data.R
quarto render reports/data-validation.qmd
```

The complete offline workflow runs validation before preparation:

```bash
Rscript scripts/run-all.R
```

Checks cover:

- exact source identity using SHA-256;
- required columns and row count;
- country, year, item, element, and unit coverage;
- allowed provider flags;
- candidate-key uniqueness;
- missing core values and non-negative measures;
- the approximate relationship between production, harvested area, and yield.

Statuses have distinct meanings:

- `pass`: observed data match a documented expectation;
- `warning`: investigation or interpretation is required, but evidence is kept;
- `failure`: the file is not the expected input and the workflow stops;
- `unknown`: the report documents a question that code alone cannot answer.

Validation never rewrites the fixed input or silently removes observations. Data
cleaning and analytical exclusions belong in derived preparation steps and
must be justified separately.

## Storage and version-control decisions

| Artifact | Git policy | Reason |
| --- | --- | --- |
| Fixed teaching sample | Track | Small, licensed snapshot supports reliable offline teaching |
| Fixed CHIRPS teaching snapshot | Track | Small, cited country-season summary supports reliable offline integration teaching |
| Metadata and validation source | Track | Required to interpret and audit the data |
| Full FAOSTAT download | Ignore | Large, externally retrievable, and subject to revision |
| Derived data and analysis results | Ignore | Recreated by project scripts |
| Rendered HTML | Ignore | Recreated from Quarto source and generated results |
| Secrets and local configuration | Ignore | Must not enter source control or container images |

The sample contains aggregated national statistics and no personal microdata.
This does not remove the need to reassess sensitivity, access, and retention if
different data are introduced.

## Licence, attribution, and responsible use

FAOSTAT is an FAO corporate statistical database. Unless dataset metadata state
otherwise, its datasets are licensed under CC BY 4.0 complemented by the
[FAO Statistical Database Terms of Use](https://www.fao.org/contact-us/terms/db-terms-of-use/en).
The terms require attribution and warn that third-party exceptions may apply.
They also prohibit implying FAO endorsement or misrepresenting dataset content.

The project citation and access date are recorded in `metadata/provenance.yml`.
Recheck the current terms and dataset metadata before redistributing a new
snapshot or using the data outside this teaching context.

## Fitness-for-purpose boundary

The project can establish file identity and test internal expectations. It
cannot establish provider accuracy, cross-country comparability, measurement
quality, representativeness, or causal validity from the CSV alone. Flags,
methodological changes, historical revisions, missing activities, and national
reporting differences must remain visible when interpreting results.

## Maintenance checklist

When the sample or source workflow changes:

1. preserve the previous state in Git before replacing the snapshot;
2. regenerate the sample through code rather than manual editing;
3. update its checksum and access/release information;
4. review the dictionary, code lists, licence, and citation;
5. run validation and inspect every warning or failure;
6. render and review both validation and analysis reports;
7. confirm that only intended, redistributable artifacts are staged.
